#!/usr/bin/env bash
set -euo pipefail

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
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
  wget "$LINK" -O /tmp/termshark.tar.gz && \
  tar -zxvf /tmp/termshark.tar.gz && \
  mv "termshark_${VERSION}_linux_${TERM_ARCH}/termshark" /tmp/gort-tools/termshark && \
  chmod +x /tmp/gort-tools/termshark
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
  wget "$LINK" -O /tmp/grpcurl.tar.gz  && \
  tar --no-same-owner -zxvf /tmp/grpcurl.tar.gz && \
  mv "grpcurl" /tmp/gort-tools/grpcurl && \
  chmod +x /tmp/gort-tools/grpcurl
  chown root:root /tmp/gort-tools/grpcurl
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
  wget "$LINK" -O /tmp/fortio.tgz  && \
  tar -zxvf /tmp/fortio.tgz && \
  mv "usr/bin/fortio" /tmp/gort-tools/fortio && \
  chmod +x /tmp/gort-tools/fortio
  perform_sleep
}

get_cilium() {
  VERSION=$(get_latest_release cilium/cilium-cli | sed -e 's/^v//')
  LINK="https://github.com/cilium/cilium-cli/releases/download/v${VERSION}/cilium-linux-${ARCH}.tar.gz"
  wget "$LINK" -O /tmp/cilium.tar.gz  && \
  tar -zxvf /tmp/cilium.tar.gz && \
  mv "cilium" /tmp/gort-tools/cilium && \
  chmod +x /tmp/gort-tools/cilium
  perform_sleep
}

get_tetragon() {
  VERSION=$(get_latest_release cilium/tetragon | sed -e 's/^v//')
  LINK="https://github.com/cilium/tetragon/releases/download/v${VERSION}/tetra-linux-${ARCH}.tar.gz"
  wget "$LINK" -O /tmp/tetra.tar.gz  && \
  tar -zxvf /tmp/tetra.tar.gz && \
  mv "tetra" /tmp/gort-tools/tetra && \
  chmod +x /tmp/gort-tools/tetra
  perform_sleep
}

get_k9s() {
  VERSION=$(get_latest_release derailed/k9s | sed -e 's/^v//')
  LINK="https://github.com/derailed/k9s/releases/download/v${VERSION}/k9s_Linux_${ARCH}.tar.gz"
  wget "$LINK" -O /tmp/k9s.tar.gz  && \
  tar -zxvf /tmp/k9s.tar.gz && \
  mv "k9s" /tmp/gort-tools/k9s && \
  chmod +x /tmp/gort-tools/k9s
  perform_sleep
}

get_flux() {
  VERSION=$(get_latest_release fluxcd/flux2 | sed -e 's/^v//')
  LINK="https://github.com/fluxcd/flux2/releases/download/v${VERSION}/flux_${VERSION}_linux_${ARCH}.tar.gz"
  wget "$LINK" -O /tmp/flux.tar.gz  && \
  tar -zxvf /tmp/flux.tar.gz && \
  mv "flux" /tmp/gort-tools/flux && \
  chmod +x /tmp/gort-tools/flux
  perform_sleep
}

get_go_cloudflare_speedtest() {
  case "$ARCH" in
    amd64)
      VERSION=$(get_latest_release zoonderkins/go-speed-cloudflare-cli | sed -e 's/^v//')
      LINK="https://github.com/zoonderkins/go-speed-cloudflare-cli/releases/download/v${VERSION}/go-speed-cloudflare-cli-linux-amd64"
      wget "$LINK" -O /tmp/gort-tools/cloudflare-speedtest  && \
      chmod +x /tmp/gort-tools/cloudflare-speedtest
      perform_sleep
      ;;
    *)
      echo "Unsupported architecture for go-speed-cloudflare-cli: $ARCH"
      ;;
  esac
}

get_go_speedtest_net() {
  if [ "$ARCH" == "amd64" ]; then
    TERM_ARCH=x86_64
  else
    TERM_ARCH="$ARCH"
  fi
  VERSION=$(get_latest_release showwin/speedtest-go | sed -e 's/^v//')
  LINK="https://github.com/showwin/speedtest-go/releases/download/v${VERSION}/speedtest-go_1.7.10_Linux_${TERM_ARCH}.tar.gz"
  wget "$LINK" -O /tmp/speedtest.tar.gz  && \
  tar -zxvf /tmp/speedtest.tar.gz && \
  mv "speedtest-go" /tmp/gort-tools/speedtest-go && \
  chmod +x /tmp/gort-tools/speedtest-go
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
get_go_cloudflare_speedtest
get_go_speedtest_net
get_yabs