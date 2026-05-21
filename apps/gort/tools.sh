#!/usr/bin/env bash
set -euo pipefail

get_latest_release() {
  # Use TOKEN if available — anonymous calls hit GitHub's 60/hr rate limit
  # within a couple of releases on this script's call pattern and the empty
  # tag_name then propagates as wrong URLs / exit 1 via `set -o pipefail`.
  local auth_header=()
  if [ -n "${TOKEN:-}" ]; then
    auth_header=(-H "Authorization: token ${TOKEN}")
  fi
  local response tag
  response=$(curl --silent --fail "${auth_header[@]}" "https://api.github.com/repos/$1/releases/latest" || true)
  tag=$(echo "$response" | grep -m1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)
  if [ -z "$tag" ]; then
    echo "ERROR: failed to resolve latest release for $1" >&2
    echo "Response was: $(echo "$response" | head -c 200)" >&2
    return 1
  fi
  printf '%s' "$tag"
}


ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH=amd64
        ;;
    aarch64)
        ARCH=arm64
        ;;
esac

perform_sleep() {
  sleep 5
}

# Extract a tarball into a fresh temp dir to avoid LICENSE/README.md collisions
# between successive tools' archives. Echoes the temp dir path so the caller can
# pick out its binary and clean up afterwards.
extract_to_tmp() {
  local tarball="$1"
  local dir
  dir=$(mktemp -d)
  tar -xzf "$tarball" -C "$dir"
  echo "$dir"
}

get_ctop() {
  VERSION=$(get_latest_release bcicen/ctop | sed -e 's/^v//')
  LINK="https://github.com/bcicen/ctop/releases/download/v${VERSION}/ctop-${VERSION}-linux-${ARCH}"
  wget "$LINK" -O /tmp/gort-tools/ctop && \
  chmod +x /tmp/gort-tools/ctop
  perform_sleep
}

get_calicoctl() {
  VERSION=$(get_latest_release projectcalico/calicoctl)
  LINK="https://github.com/projectcalico/calicoctl/releases/download/${VERSION}/calicoctl-linux-${ARCH}"
  wget "$LINK" -O /tmp/gort-tools/calicoctl && \
  chmod +x /tmp/gort-tools/calicoctl
}

get_termshark() {
  if [ "$ARCH" == "amd64" ]; then
    TERM_ARCH=x64
  else
    TERM_ARCH="$ARCH"
  fi
  VERSION=$(get_latest_release gcla/termshark | sed -e 's/^v//')
  LINK="https://github.com/gcla/termshark/releases/download/v${VERSION}/termshark_${VERSION}_linux_${TERM_ARCH}.tar.gz"
  wget "$LINK" -O /tmp/termshark.tar.gz
  WORK=$(extract_to_tmp /tmp/termshark.tar.gz)
  mv "${WORK}/termshark_${VERSION}_linux_${TERM_ARCH}/termshark" /tmp/gort-tools/termshark
  chmod +x /tmp/gort-tools/termshark
  rm -rf "$WORK" /tmp/termshark.tar.gz
  perform_sleep
}

get_grpcurl() {
  if [ "$ARCH" == "amd64" ]; then
    TERM_ARCH=x86_64
  else
    TERM_ARCH="$ARCH"
  fi
  VERSION=$(get_latest_release fullstorydev/grpcurl | sed -e 's/^v//')
  LINK="https://github.com/fullstorydev/grpcurl/releases/download/v${VERSION}/grpcurl_${VERSION}_linux_${TERM_ARCH}.tar.gz"
  wget "$LINK" -O /tmp/grpcurl.tar.gz
  WORK=$(extract_to_tmp /tmp/grpcurl.tar.gz)
  mv "${WORK}/grpcurl" /tmp/gort-tools/grpcurl
  chmod +x /tmp/gort-tools/grpcurl
  chown root:root /tmp/gort-tools/grpcurl
  rm -rf "$WORK" /tmp/grpcurl.tar.gz
  perform_sleep
}

get_fortio() {
  if [ "$ARCH" == "amd64" ]; then
    TERM_ARCH=x86_64
  else
    TERM_ARCH="$ARCH"
  fi
  VERSION=$(get_latest_release fortio/fortio | sed -e 's/^v//')
  LINK="https://github.com/fortio/fortio/releases/download/v${VERSION}/fortio-linux_${ARCH}-${VERSION}.tgz"
  wget "$LINK" -O /tmp/fortio.tgz
  WORK=$(extract_to_tmp /tmp/fortio.tgz)
  mv "${WORK}/usr/bin/fortio" /tmp/gort-tools/fortio
  chmod +x /tmp/gort-tools/fortio
  rm -rf "$WORK" /tmp/fortio.tgz
  perform_sleep
}

get_cilium() {
  VERSION=$(get_latest_release cilium/cilium-cli | sed -e 's/^v//')
  LINK="https://github.com/cilium/cilium-cli/releases/download/v${VERSION}/cilium-linux-${ARCH}.tar.gz"
  wget "$LINK" -O /tmp/cilium.tar.gz
  WORK=$(extract_to_tmp /tmp/cilium.tar.gz)
  mv "${WORK}/cilium" /tmp/gort-tools/cilium
  chmod +x /tmp/gort-tools/cilium
  rm -rf "$WORK" /tmp/cilium.tar.gz
  perform_sleep
}

get_tetragon() {
  VERSION=$(get_latest_release cilium/tetragon | sed -e 's/^v//')
  LINK="https://github.com/cilium/tetragon/releases/download/v${VERSION}/tetra-linux-${ARCH}.tar.gz"
  wget "$LINK" -O /tmp/tetra.tar.gz
  WORK=$(extract_to_tmp /tmp/tetra.tar.gz)
  mv "${WORK}/tetra" /tmp/gort-tools/tetra
  chmod +x /tmp/gort-tools/tetra
  rm -rf "$WORK" /tmp/tetra.tar.gz
  perform_sleep
}

get_k9s() {
  VERSION=$(get_latest_release derailed/k9s | sed -e 's/^v//')
  LINK="https://github.com/derailed/k9s/releases/download/v${VERSION}/k9s_Linux_${ARCH}.tar.gz"
  wget "$LINK" -O /tmp/k9s.tar.gz
  WORK=$(extract_to_tmp /tmp/k9s.tar.gz)
  mv "${WORK}/k9s" /tmp/gort-tools/k9s
  chmod +x /tmp/gort-tools/k9s
  rm -rf "$WORK" /tmp/k9s.tar.gz
  perform_sleep
}

get_flux() {
  VERSION=$(get_latest_release fluxcd/flux2 | sed -e 's/^v//')
  LINK="https://github.com/fluxcd/flux2/releases/download/v${VERSION}/flux_${VERSION}_linux_${ARCH}.tar.gz"
  wget "$LINK" -O /tmp/flux.tar.gz
  WORK=$(extract_to_tmp /tmp/flux.tar.gz)
  mv "${WORK}/flux" /tmp/gort-tools/flux
  chmod +x /tmp/gort-tools/flux
  rm -rf "$WORK" /tmp/flux.tar.gz
  perform_sleep
}

get_cloudflare_speed_cli() {
  case "$ARCH" in
    amd64) CFS_TRIPLE=x86_64-unknown-linux-musl ;;
    arm64) CFS_TRIPLE=aarch64-unknown-linux-musl ;;
    *)
      echo "Unsupported architecture for cloudflare-speed-cli: $ARCH"
      return 0
      ;;
  esac
  VERSION=$(get_latest_release kavehtehrani/cloudflare-speed-cli | sed -e 's/^v//')
  LINK="https://github.com/kavehtehrani/cloudflare-speed-cli/releases/download/v${VERSION}/cloudflare-speed-cli-${CFS_TRIPLE}.tar.xz"
  wget "$LINK" -O /tmp/cloudflare-speed-cli.tar.xz
  WORK=$(mktemp -d)
  tar -xJf /tmp/cloudflare-speed-cli.tar.xz -C "$WORK"
  mv "${WORK}/cloudflare-speed-cli-${CFS_TRIPLE}/cloudflare-speed-cli" /tmp/gort-tools/cloudflare-speed-cli
  chmod +x /tmp/gort-tools/cloudflare-speed-cli
  rm -rf "$WORK" /tmp/cloudflare-speed-cli.tar.xz
  perform_sleep
}

get_go_speedtest_net() {
  if [ "$ARCH" == "amd64" ]; then
    TERM_ARCH=x86_64
  else
    TERM_ARCH="$ARCH"
  fi
  VERSION=$(get_latest_release showwin/speedtest-go | sed -e 's/^v//')
  LINK="https://github.com/showwin/speedtest-go/releases/download/v${VERSION}/speedtest-go_1.7.10_Linux_${TERM_ARCH}.tar.gz"
  wget "$LINK" -O /tmp/speedtest.tar.gz
  WORK=$(extract_to_tmp /tmp/speedtest.tar.gz)
  mv "${WORK}/speedtest-go" /tmp/gort-tools/speedtest-go
  chmod +x /tmp/gort-tools/speedtest-go
  rm -rf "$WORK" /tmp/speedtest.tar.gz
  perform_sleep
}

get_yabs() {
  LINK="https://raw.githubusercontent.com/masonr/yet-another-bench-script/refs/heads/master/yabs.sh"
  wget "$LINK" -O /tmp/gort-tools/yabs && \
  chmod +x /tmp/gort-tools/yabs
  perform_sleep
}

mkdir -p /tmp/gort-tools

get_ctop
get_calicoctl
get_termshark
get_grpcurl
get_fortio
get_cilium
get_tetragon
get_flux
get_k9s
get_cloudflare_speed_cli
get_go_speedtest_net
get_yabs
