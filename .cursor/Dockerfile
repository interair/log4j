# Cloud Agent base image for Apache Log4j 1.3 (BRANCH_1_3_ABANDONED).
#
# This is a 2007-era codebase that targets the Java 1.1/1.2 bytecode/source
# levels (see build.xml: source=1.3, target=1.2) and is built with Apache Ant.
# Modern JDKs (11+) can no longer compile these obsolete source/target levels
# and reject legacy constructs, so we pin the toolchain to JDK 8, which is the
# newest JDK that still compiles this source.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-8-jdk \
        ant \
        ant-optional \
        git \
        curl \
        ca-certificates \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Make JDK 8 the toolchain Ant uses (JAVA_HOME) for every shell.
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=${JAVA_HOME}/bin:${PATH}

# The default Cursor Cloud Agent runtime user.
USER ubuntu
