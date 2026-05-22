FROM alpine:latest AS cloner

ARG VERSION

RUN apk update && apk upgrade && \
    apk add --no-cache git

RUN git clone -b $VERSION  https://github.com/Kometa-Team/ImageMaid.git /source

FROM python:3.14-slim-bookworm

ARG BRANCH_NAME=master
ENV BRANCH_NAME=${BRANCH_NAME}
ENV TINI_VERSION=v0.19.0
ENV KOMETA_DOCKER=True

COPY --from=cloner /source/requirements.txt requirements.txt

RUN echo "**** install system packages ****" \
 && apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get install -y tzdata --no-install-recommends \
 && apt-get install -y gcc g++ libxml2-dev libxslt-dev libz-dev libjpeg62-turbo-dev zlib1g-dev wget curl \
 && wget -O /tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-"$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
 && chmod +x /tini \
 && pip3 install --no-cache-dir --upgrade --requirement /requirements.txt \
 && apt-get --purge autoremove gcc g++ libxml2-dev libxslt-dev libz-dev -y \
 && apt-get clean \
 && apt-get update \
 && apt-get check \
 && apt-get -f install \
 && apt-get -y install tmux dialog \
 && apt-get autoclean \
 && rm -rf /requirements.txt /tmp/* /var/tmp/* /var/lib/apt/lists/*

COPY --from=cloner /source/. /

# Build-time smoke test: fail the build if any pinned dependency is missing
# wheels for the target arch or otherwise fails to import. Mirrors the
# top-level import block in /imagemaid.py — keep in sync if upstream changes.
RUN python3 -c "import plexapi, requests; \
from num2words import num2words; \
from kometautils import schedule, util, KometaLogger, KometaArgs, Continue, Failed; \
from kometautils.args import parse_bool; \
from PIL import Image; \
from plexapi.exceptions import Unauthorized; \
from plexapi.server import PlexServer; \
from requests.status_codes import _codes as codes; \
from retrying import retry; \
from tqdm import tqdm"

VOLUME /config

RUN mkdir -p /extra-scripts \
    && chown -R 568:568 /extra-scripts \
    && chmod -R 775 /extra-scripts

ARG TARGETARCH
RUN case "${TARGETARCH}" in \
        amd64) TTYD_SUFFIX=x86_64 ;; \
        arm64) TTYD_SUFFIX=aarch64 ;; \
        *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${TTYD_SUFFIX}" -o /usr/local/bin/ttyd && \
    chmod 0755 /usr/local/bin/ttyd
COPY --chmod=0755 --chown=568:568 apps/ubuntu/base-entrypoint.sh /entrypoint.sh
COPY --chmod=0755 --chown=568:568 apps/ubuntu/scripts /prom_scripts
COPY --chmod=0755 --chown=568:568 apps/imagemaid/root /

ARG user=notroot
RUN groupadd -g 568 $user && useradd -d /config --create-home --uid 568 --gid 568 --shell /bin/bash $user
RUN chown notroot /config
USER 568
WORKDIR /config
ENTRYPOINT ["/entrypoint.sh"]