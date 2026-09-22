#!/usr/bin/env bash
#
# Idempotent repository bootstrap for Apache Log4j 1.3.
#
# Downloads the third-party JARs the Ant build expects (build.xml falls back to
# ~/.m2/repository coordinates), then compiles the core library, the buildable
# optional JARs, and the bundled example applications.
#
# Notes on scope:
#   * log4j-jmx.jar and log4j-nt.jar are intentionally NOT built. They require
#     Sun's jmxri/jmxtools JARs (never redistributable / not on Maven Central)
#     and a Windows-only native DLL, respectively. Everything else builds.
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk-amd64}"
export PATH="${JAVA_HOME}/bin:${PATH}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

M2="${HOME}/.m2/repository"
CENTRAL="https://repo1.maven.org/maven2"

# fetch <m2-relative-path> <download-url>
fetch() {
    local path="$1" url="$2"
    local dest="${M2}/${path}"
    if [ -f "${dest}" ]; then
        return 0
    fi
    mkdir -p "$(dirname "${dest}")"
    echo "  downloading ${path}"
    curl -fsSL --retry 4 --retry-delay 2 -o "${dest}" "${url}"
}

echo "==> Fetching build dependencies into ${M2}"
fetch oro/oro/2.0.8/oro-2.0.8.jar                                   "${CENTRAL}/oro/oro/2.0.8/oro-2.0.8.jar"
fetch javax/servlet/servlet-api/2.5/servlet-api-2.5.jar            "${CENTRAL}/javax/servlet/servlet-api/2.5/servlet-api-2.5.jar"
fetch javax/mail/mail/1.4/mail-1.4.jar                             "${CENTRAL}/javax/mail/mail/1.4/mail-1.4.jar"
fetch javax/activation/activation/1.1/activation-1.1.jar          "${CENTRAL}/javax/activation/activation/1.1/activation-1.1.jar"
fetch junit/junit/3.8.1/junit-3.8.1.jar                            "${CENTRAL}/junit/junit/3.8.1/junit-3.8.1.jar"
# The Ant build looks for javax.jms at javax/jms/jms/1.1; the Geronimo JMS 1.1
# spec JAR provides those API classes and is freely available on Maven Central.
fetch javax/jms/jms/1.1/jms-1.1.jar                                "${CENTRAL}/org/apache/geronimo/specs/geronimo-jms_1.1_spec/1.1.1/geronimo-jms_1.1_spec-1.1.1.jar"

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

echo "==> Build complete. Artifacts in dist/lib:"
ls -1 dist/lib
