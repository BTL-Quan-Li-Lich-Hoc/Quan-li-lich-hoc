FROM ghcr.io/cirruslabs/flutter:3.47.2

USER root

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git \
      curl \
      unzip \
      zip \
      jq \
      openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"
ENV PUB_CACHE=/root/.pub-cache

RUN flutter config --no-analytics \
    && dart --disable-analytics \
    && flutter --version \
    && dart --version \
    && java -version

WORKDIR /workspaces/Quan-li-lich-hoc
