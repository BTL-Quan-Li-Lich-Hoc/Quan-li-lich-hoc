FROM ghcr.io/cirruslabs/android-sdk:36

USER root

ARG FLUTTER_VERSION=3.47.2
ENV FLUTTER_HOME=/opt/flutter \
    FLUTTER_ROOT=/opt/flutter \
    PUB_CACHE=/root/.pub-cache
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      unzip \
      zip \
      jq \
      xz-utils \
      openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter.tar.xz \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics --enable-web --enable-android \
    && dart --disable-analytics \
    && yes | flutter doctor --android-licenses \
    && flutter precache --web --android \
    && flutter --version \
    && dart --version \
    && java -version

WORKDIR /workspaces/Quan-li-lich-hoc
