# gluetun (promknight)

A customised build of [qmcgaw/gluetun](https://github.com/qdm12/gluetun) with
opinionated additions for the promknight homelab stack. Sits on top of
upstream Gluetun, adds an entrypoint chain that:

1. Cleans up stale Cilium WireGuard routing rules (a recurring nuisance after
   pod restarts on this cluster)
2. Picks the lowest-load Proton servers from
   [`proton-gluetun-updater`](https://github.com/iPromKnight/proton-gluetun-updater)
   cache via `pick-servers.sh`
3. Launches a background watchdog (`watchdog.sh`) that probes through the
   tunnel and cycles Gluetun via its control server on sustained failure
4. Launches a background quality-check (`quality-check.sh`) that measures
   real TCP retransmit rate at startup and cycles to a fresh endpoint if
   it lands on a degraded server
5. Execs into upstream's `/gluetun-entrypoint`

K8s probes use `probe-status.sh` (Gluetun's own self-report, fast) and
`probe-egress.sh` (real-traffic test via `/dev/tcp`).

## Image contents

| Path                       | Purpose                                                                                              |
| -------------------------- | ---------------------------------------------------------------------------------------------------- |
| `/promknight-entrypoint.sh`| `ENTRYPOINT`. Orchestrates pick-servers, watchdog, quality-check, then execs `/gluetun-entrypoint`. |
| `/pick-servers.sh`         | Reads proton-gluetun-updater's cache, pins `SERVER_NAMES` to the top-N low-load servers.             |
| `/watchdog.sh`             | Ongoing health probe via `/dev/tcp`. Cycles Gluetun's tunnel on sustained failure.                   |
| `/quality-check.sh`        | One-shot startup probe of TCP retransmit rate. Cycles to a fresh endpoint if the rate is too high.   |
| `/probe-status.sh`         | K8s liveness/readiness — hits Gluetun's `/v1/vpn/status` control-server endpoint.                    |
| `/probe-egress.sh`         | K8s liveness — `/dev/tcp` connect through the tunnel. Honest egress test.                            |

Extra packages installed on top of upstream:

- `bash` (the scripts use bash-only features)
- `bind-tools`, `curl`, `jq`, `wireguard-tools`

## Environment variables

Inherits all upstream Gluetun env vars (see
[upstream docs](https://github.com/qdm12/gluetun-wiki/blob/main/setup/environment-variables.md)).
The additions below control the promknight-specific scripts. **All are optional**
unless marked otherwise.

### Server picker (`pick-servers.sh`)

Runs at container startup, before Gluetun reads its env. Picks the lowest-load
Proton servers from the proton-gluetun-updater cache and writes
`SERVER_NAMES="..."` to `/shared/env`, which is then sourced before exec'ing
Gluetun.

Requires the proton-gluetun-updater storage dir to be mounted at
`/gluetun/proton/` (read-only is fine — the picker doesn't write).

| Variable                | Default                | Description                                                                                                                                                                                                            |
| ----------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PICKER_DISABLED`       | unset                  | If non-empty, skip the picker entirely. Useful when `SERVER_COUNTRIES` is set to something the picker can't map, or when you want Gluetun's full server pool.                                                          |
| `PICKER_CACHE_DIR`      | `/gluetun/proton`      | Where to look for `serverlist.<epoch>.json` files written by proton-gluetun-updater.                                                                                                                                  |
| `PICKER_COUNTRY`        | derived from `SERVER_COUNTRIES` | ExitCountry code (`NL`, `CH`, `DE`, `SE`, `IS`, `UK`, `US`) the picker filters on. Auto-maps from `SERVER_COUNTRIES` for common names; falls back to `NL` if unset.                                                |
| `PICKER_TIER`           | `2`                    | Proton account tier required. `2` = Plus/paid. Lowering would include legacy basic-tier servers.                                                                                                                       |
| `PICKER_TOP_N`          | `10`                   | How many of the lowest-load servers to keep in the pin pool. Larger = more endpoint variety but includes less-optimal servers.                                                                                         |
| `PICKER_P2P_ONLY`       | `true`                 | Require the P2P feature bit (Features & 4). Set to anything other than `"true"` to allow non-P2P servers.                                                                                                              |

Cache-miss behaviour: if `serverlist.*.json` is missing or empty, the picker
logs a warning and exits 0 without pinning. Gluetun falls back to picking
randomly from `SERVER_COUNTRIES`.

### Watchdog (`watchdog.sh`)

Runs in the background for the lifetime of the container. Probes a TCP target
through the tunnel via bash's `/dev/tcp` pseudo-device every `INTERVAL` seconds.
On `MAX_FAILS` consecutive failures, cycles Gluetun via the control server
(`PUT /v1/vpn/status stopped → running`).

| Variable                  | Default                | Description                                                                                                                                |
| ------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `WATCHDOG_DISABLED`       | unset                  | If non-empty, skip the watchdog entirely.                                                                                                  |
| `WATCHDOG_PROBE_TARGET`   | `1.1.1.1:443`          | `host:port` to TCP-connect. Cloudflare anycast is cheap, reliable, and globally available.                                                 |
| `WATCHDOG_INTERVAL`       | `20`                   | Seconds between probes.                                                                                                                    |
| `WATCHDOG_MAX_FAILS`      | `3`                    | Consecutive failures before cycling. With default interval = 60s detection threshold.                                                      |
| `WATCHDOG_RECOVERY_SLEEP` | `30`                   | Quiet time after a cycle before resuming probes. Gives the new tunnel time to handshake.                                                   |
| `WATCHDOG_TIMEOUT`        | `5`                    | Per-probe timeout in seconds.                                                                                                              |
| `WATCHDOG_CONTROL_URL`    | `http://localhost:8000`| Gluetun control server base URL. Almost never needs overriding.                                                                            |
| `GLUETUN_CONTROL_APIKEY`  | unset                  | X-API-Key sent on control-server PUTs. Required when the control server's `config.toml` uses `auth = "apikey"`. Optional with `auth = "none"`. |

### Quality check (`quality-check.sh`)

Runs once at container startup, AFTER `WATCHDOG_STARTUP_WAIT` of grace.
Measures TCP retransmit rate via `/proc/net/snmp` delta during a small
download. If the rate exceeds `MAX_RETRANSMIT`, cycles Gluetun and re-tests.
Up to `MAX_CYCLES` attempts before giving up.

| Variable                          | Default                                            | Description                                                                                                                                                                |
| --------------------------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `QUALITY_CHECK_DISABLED`          | unset                                              | If non-empty, skip entirely.                                                                                                                                               |
| `QUALITY_CHECK_URL`               | `https://speed.cloudflare.com/__down?bytes=10000000` | Test download. ~10MB is enough to push real packet volume through.                                                                                                       |
| `QUALITY_CHECK_MAX_RETRANSMIT`    | `2`                                                | Retransmit-rate threshold (integer percent). Healthy WG should be <1%; >2% suggests a degraded endpoint.                                                                  |
| `QUALITY_CHECK_MAX_CYCLES`        | `3`                                                | How many times to cycle Gluetun before giving up.                                                                                                                          |
| `QUALITY_CHECK_STARTUP_WAIT`      | `15`                                               | Seconds to wait after entrypoint before the first probe. Gives the tunnel time to fully establish.                                                                         |
| `QUALITY_CHECK_RECOVERY_WAIT`     | `20`                                               | Seconds to wait after a cycle before re-measuring.                                                                                                                         |
| `QUALITY_CHECK_TIMEOUT`           | `15`                                               | `curl --max-time` for the test download.                                                                                                                                   |
| `QUALITY_CHECK_ALLOW_POOL_ESCAPE` | unset                                              | If non-empty, when all `MAX_CYCLES` attempts fail within the picker's `SERVER_NAMES` pool, drop the pin and try once more from the full `SERVER_COUNTRIES` pool. Last-resort escape hatch when the picker has landed on a uniformly bad pool (e.g. all 10 servers share a degraded peering path). |

### Probes (k8s)

These aren't configured via env, they're invoked directly from the helmrelease
`probes.liveness.spec.exec.command` / `probes.readiness.spec.exec.command`.

`/probe-status.sh` reads `GLUETUN_CONTROL_APIKEY` from env to authenticate
against Gluetun's control server (when `config.toml` uses `auth = "apikey"`).
Otherwise no auth header is sent.

`/probe-egress.sh` honours these:

| Variable           | Default                                      | Description                                                                                                              |
| ------------------ | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `PROBE_TARGETS`    | `1.1.1.1:443,8.8.8.8:443,9.9.9.9:443`        | Comma-separated `host:port` list. Exits 0 on first reachable target.                                                     |
| `PROBE_TIMEOUT`    | `4`                                          | Seconds per target.                                                                                                      |

### Pre-existing knobs

These are upstream conventions or pre-existing promknight conventions; documented
here for completeness because the entrypoint references them:

| Variable                       | Description                                                                                                                                                                       |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GLUETUN_DISABLED`             | If non-empty, the entrypoint sleeps forever instead of exec'ing Gluetun. Useful when you want a pod alive but the tunnel down (debugging, namespace placeholder, etc.).           |
| `VPN_ENDPOINT_IP` via `/shared/VPN_ENDPOINT_IP` | If the file exists, its content is exported as `VPN_ENDPOINT_IP` (overriding the env). Lets a sibling container pin Gluetun to a specific endpoint.                              |
| `/shared/env`                  | If this file exists, it's sourced before exec'ing Gluetun. The picker and quality-check both write `SERVER_NAMES` here. Other tooling could add more env via the same path.       |

## Operational behaviour

The full startup sequence:

1. Banner prints
2. Stale Cilium WG rules cleared (`ip rule del table 51820` — fails silently when no stale rules exist)
3. `pick-servers.sh` runs if executable + not disabled. Writes `/shared/env` if the cache yielded servers.
4. `/shared/VPN_ENDPOINT_IP` is read if present and exported as `VPN_ENDPOINT_IP`.
5. `/shared/env` is sourced — `SERVER_NAMES` enters this shell's environment.
6. `/watchdog.sh` is launched in the background (`&`) if executable + not disabled. Logs prefixed with `[watchdog]`.
7. `/quality-check.sh` is launched in the background if executable + not disabled. Logs prefixed with `[quality-check]`.
8. If `GLUETUN_DISABLED` is set, sleep infinity. Otherwise `exec /gluetun-entrypoint`.

Because background processes are launched before the `exec`, they share the
container's PID 1 lifecycle through Gluetun. When Gluetun exits (e.g. on pod
shutdown), the kernel reaps the background watchdog/quality-check via SIGTERM
during the container teardown.

## Building

From the parent `containers/` repo:

```sh
task APP=gluetun CHANNEL=master BASE=false test-x64
```

The `test-x64` task builds the image, runs goss smoke tests (process check +
control-server status), and emits the local tag `gluetun:master`. Publish with:

```sh
task APP=gluetun CHANNEL=master BASE=false REGISTRY=ghcr.io/ipromknight test-push
```

## Diagnostic / forensic tools

The proton-gluetun-updater + this image are part of a larger investigation
toolkit. The companion `gluetun-forensics.sh` script (in `orion/scripts/`)
runs in a gort sidecar and dumps tunnel state when probes fail. See that
script's header for usage.

## License

MIT (matches upstream).
