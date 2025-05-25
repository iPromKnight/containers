FROM alpine:latest AS cloner
ARG VERSION

RUN apk update && apk upgrade && \
    apk add --no-cache git

RUN git clone -b $VERSION  https://github.com/Kometa-Team/Kometa.git /source

FROM python:3.11-slim-buster

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

RUN mkdir -p /extra-scripts \
    && chown -R 568:568 /extra-scripts \
    && chmod -R 775 /extra-scripts

ADD --chmod=0755 https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 /usr/local/bin/ttyd
COPY --chmod=0755 --chown=568:568 apps/ubuntu/base-entrypoint.sh /entrypoint.sh
COPY --chmod=0755 --chown=568:568 apps/ubuntu/scripts /scripts
COPY --chmod=0755 --chown=568:568 apps/kometa/root /

VOLUME /config

ARG user=notroot
RUN groupadd -g 568 $user && useradd --create-home --uid 568 --gid 568 --shell /bin/bash $user
RUN chown notroot /config
USER 568

ENTRYPOINT ["/entrypoint.sh"]