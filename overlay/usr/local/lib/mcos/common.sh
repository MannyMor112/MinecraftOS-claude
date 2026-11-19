# shellcheck shell=bash
# Shared helpers for MinecraftOS scripts.
DATA=/data
PRISM_DIR=$DATA/prism
RESULTS=$DATA/results
JAVA=/opt/java8/bin/java
AGENT=/opt/mcos/mcos-bench-agent.jar
MCOS_VERSION=$(cat /etc/mcos-version 2>/dev/null || echo dev)
INSTANCE=MCOS
BENCH_INSTANCE=MCOS-bench

# value of kernel command line option mcos.<name>=..., or $2 as default
cmdline() {
  local v
  v=$(tr ' ' '\n' < /proc/cmdline | sed -n "s/^mcos\.$1=//p" | tail -1)
  echo "${v:-$2}"
}
die() { echo "ERROR: $*" >&2; exit 1; }
have_net() { curl -fsS -m 8 -o /dev/null https://piston-meta.mojang.com/mc/game/version_manifest_v2.json; }
pause() { read -r -p "${1:-Press Enter to continue...}" _; }
