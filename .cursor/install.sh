#!/usr/bin/env bash
#
# Idempotent Cloud Agent bootstrap for Apache Log4j 1.3.
#
# This 2007-era codebase compiles at Java source 1.3 / target 1.2 (see
# build.xml) and builds with Apache Ant. Modern JDKs (11+) can no longer
# compile those obsolete source/target levels, so this script provisions
# JDK 8 (the newest JDK that still compiles this source) and Ant, then
# builds the library and the bundled example applications.
#
# It is safe to run repeatedly: the toolchain install and dependency
# downloads are guarded, and the Ant build is deterministic.
#
# Scope note: log4j-jmx.jar and log4j-nt.jar are intentionally NOT built.
# They require Sun's jmxri/jmxtools JARs (not redistributable / not on
# Maven Central) and a Windows-only native DLL, respectively.
set -euo pipefail

JDK8_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# --- 1. Provision the JDK 8 + Ant toolchain (idempotent) --------------------
if [ ! -x "${JDK8_HOME}/bin/javac" ] || ! command -v ant >/dev/null 2>&1; then
    echo "==> Installing JDK 8 + Ant toolchain"
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-8-jdk ant ant-optional curl ca-certificates unzip
fi

# Make JDK 8 the default java/javac and persist JAVA_HOME for interactive
# agent shells (login sessions read /etc/environment and /etc/profile.d).
sudo update-alternatives --install /usr/bin/java  java  "${JDK8_HOME}/bin/java"  2000
sudo update-alternatives --install /usr/bin/javac javac "${JDK8_HOME}/bin/javac" 2000
sudo update-alternatives --set java  "${JDK8_HOME}/bin/java"
sudo update-alternatives --set javac "${JDK8_HOME}/bin/javac"
if ! grep -q '^JAVA_HOME=' /etc/environment 2>/dev/null; then
    echo "JAVA_HOME=${JDK8_HOME}" | sudo tee -a /etc/environment >/dev/null
fi
printf 'export JAVA_HOME=%s\nexport PATH=$JAVA_HOME/bin:$PATH\n' "${JDK8_HOME}" \
    | sudo tee /etc/profile.d/java8.sh >/dev/null
sudo chmod +x /etc/profile.d/java8.sh

export JAVA_HOME="${JDK8_HOME}"
export PATH="${JAVA_HOME}/bin:${PATH}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# --- 2. Fetch the third-party JARs the Ant build expects --------------------
# build.xml falls back to these ~/.m2/repository coordinates.
M2="${HOME}/.m2/repository"
CENTRAL="https://repo1.maven.org/maven2"
fetch() {
    local path="$1" url="$2"
    local dest="${M2}/${path}"
    [ -f "${dest}" ] && return 0
    mkdir -p "$(dirname "${dest}")"
    echo "  downloading ${path}"
    curl -fsSL --retry 4 --retry-delay 2 -o "${dest}" "${url}"
}

echo "==> Fetching build dependencies into ${M2}"
fetch oro/oro/2.0.8/oro-2.0.8.jar                        "${CENTRAL}/oro/oro/2.0.8/oro-2.0.8.jar"
fetch javax/servlet/servlet-api/2.5/servlet-api-2.5.jar "${CENTRAL}/javax/servlet/servlet-api/2.5/servlet-api-2.5.jar"
fetch javax/mail/mail/1.4/mail-1.4.jar                  "${CENTRAL}/javax/mail/mail/1.4/mail-1.4.jar"
fetch javax/activation/activation/1.1/activation-1.1.jar "${CENTRAL}/javax/activation/activation/1.1/activation-1.1.jar"
fetch junit/junit/3.8.1/junit-3.8.1.jar                 "${CENTRAL}/junit/junit/3.8.1/junit-3.8.1.jar"
# The Ant build looks for javax.jms at javax/jms/jms/1.1; the Geronimo JMS 1.1
# spec JAR provides those API classes and is freely available on Maven Central.
fetch javax/jms/jms/1.1/jms-1.1.jar                     "${CENTRAL}/org/apache/geronimo/specs/geronimo-jms_1.1_spec/1.1.1/geronimo-jms_1.1_spec-1.1.1.jar"

# --- 3. Build the library + examples ----------------------------------------
echo "==> Building log4j (core + buildable optional JARs + examples)"
ant -q clean >/dev/null 2>&1 || true
ant -q \
    log4j.jar \
    log4j-optional.jar \
    log4j-oro.jar \
    log4j-xml.jar \
    log4j-smtp.jar \
    log4j-db.jar \
    log4j-jms.jar \
    build.examples

echo "==> Build complete."
echo "    Toolchain: $(java -version 2>&1 | head -1)"
echo "    Artifacts in dist/lib:"
ls -1 dist/lib
