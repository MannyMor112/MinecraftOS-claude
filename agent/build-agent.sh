#!/bin/bash
# Builds mcos-bench-agent.jar with a Java 8 JDK (uses the ASM copy that ships inside the JDK8 runtime).
set -euo pipefail
OUTDIR="${1:-$(dirname "$0")/out}"
SRC="$(cd "$(dirname "$0")" && pwd)/src"
JAVAC="${JAVAC:-$(ls /usr/lib/jvm/java-8-openjdk-*/bin/javac 2>/dev/null | head -1)}"
JAR="$(dirname "$JAVAC")/jar"
rm -rf "$OUTDIR/classes"; mkdir -p "$OUTDIR/classes"
env -u JAVA_TOOL_OPTIONS -u _JAVA_OPTIONS "$JAVAC" -XDignore.symbol.file -source 8 -target 8 -nowarn -d "$OUTDIR/classes" $(find "$SRC" -name '*.java')
cat > "$OUTDIR/MANIFEST.MF" <<M
Manifest-Version: 1.0
Premain-Class: mcos.Agent
Boot-Class-Path: mcos-bench-agent.jar
Can-Retransform-Classes: false
M
(cd "$OUTDIR/classes" && env -u JAVA_TOOL_OPTIONS -u _JAVA_OPTIONS "$JAR" cfm ../mcos-bench-agent.jar ../MANIFEST.MF mcos)
touch -d @"${SOURCE_DATE_EPOCH:-0}" "$OUTDIR/mcos-bench-agent.jar" 2>/dev/null || true
echo "built $OUTDIR/mcos-bench-agent.jar"
