#!/bin/bash
# Lubuntu BASELINE benchmark - run on your current Lubuntu install, using your usual launcher.
# It uses the same benchmark agent, world, camera path and settings as MinecraftOS, so the
# numbers are directly comparable. Your options.txt is backed up and restored automatically.
#   bash bench-baseline.sh
set -e
SRC=$(cd "$(dirname "$0")" && pwd)
W=$HOME/mcos-bench; mkdir -p "$W"
cp "$SRC/mcos-bench-agent.jar" "$SRC/sampler.sh" "$SRC/report.sh" "$SRC/options-bench.txt" "$SRC/optionsof-bench.txt" "$W/"
RUN=lubuntu-baseline-$(date +%Y%m%d-%H%M%S)
T=$W/$RUN; mkdir -p "$T"
cat > "$T/bench.properties" <<P
bench=true
out=$T/agent.txt
rawOut=$T/frametimes.csv
world=mcos-bench
seed=404
x=0
y=110
z=0
yaw=-45
pitch=25
loadSeconds=30
staticSeconds=60
panSeconds=40
timeoutSeconds=900
restoreOptions=true
$(sed 's/^/opt./; s/:/=/' "$W/options-bench.txt")
$(sed 's/^/of./; s/:/=/' "$W/optionsof-bench.txt")
P
ARG="-javaagent:$W/mcos-bench-agent.jar=$T/bench.properties"
echo "$ARG" > "$W/JVM-ARGUMENT.txt"
cat <<M

=====================================================================
1. In your launcher, open the settings of your 1.8.9 OptiFine profile
   and ADD this to the JVM arguments (keep your existing ones, e.g. -Xmx1G):

   $ARG

   (it is also saved in $W/JVM-ARGUMENT.txt so you can copy-paste it)
2. Close other programs (browser!).
3. Start the game and DON'T touch anything. The world loads by itself,
   the camera turns by itself, and the game closes by itself after ~3 minutes.
   (The first run creates the test world: run it a 2nd time for the real number.)
4. Afterwards REMOVE the argument again from your launcher.
=====================================================================
Waiting for the game... (Ctrl+C to cancel)
M
sudo -v 2>/dev/null && SUDO=sudo || SUDO=""
$SUDO bash "$W/sampler.sh" "$T/sys.csv" & SPID=$!
trap '$SUDO kill $SPID 2>/dev/null' EXIT
while ! grep -qs '^agent_status=' "$T/agent.txt"; do sleep 2; done
sleep 3
$SUDO kill $SPID 2>/dev/null || true
OUTF=$T/$RUN.txt
{
  echo "# Lubuntu baseline benchmark result"
  echo "run=$RUN"; echo "label=lubuntu-baseline"
  echo "date=$(date -Is)"; echo "os=$(lsb_release -ds 2>/dev/null)"; echo "kernel=$(uname -r)"
  echo "cmdline=$(cat /proc/cmdline)"
  echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')"
  echo "mem_total_mb=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 ))"
  echo "gl_renderer=$(glxinfo -B 2>/dev/null | sed -n 's/.*OpenGL renderer string: //p')"
  echo "gl_version=$(glxinfo -B 2>/dev/null | sed -n 's/.*OpenGL version string: //p')"
  echo "mesa_package=$(dpkg-query -W -f='${Version}' libgl1-mesa-dri 2>/dev/null)"
  echo "governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
  echo "swap=$(swapon --show=NAME,TYPE,SIZE --noheadings 2>/dev/null | tr '\n' ';')"
  echo "swappiness=$(cat /proc/sys/vm/swappiness)"
  echo "## agent"; cat "$T/agent.txt"
  echo "## system (measured window)"; bash "$W/report.sh" "$T/agent.txt" "$T/sys.csv"
} > "$OUTF"
DEST=$(findmnt -rno TARGET -S LABEL=MCOSDATA 2>/dev/null | head -1)
if [ -n "$DEST" ]; then
  $SUDO mkdir -p "$DEST/results"; $SUDO cp "$OUTF" "$DEST/results/"; $SUDO cp "$T/frametimes.csv" "$DEST/results/$RUN-frametimes.csv"
  echo "Copied to the USB stick: $DEST/results/$RUN.txt"
fi
echo; grep -E "^(gl_renderer|agent_status|all_avg_fps|all_1pct_low_fps|static_avg_fps|pan_avg_fps)" "$OUTF"
echo "Result: $OUTF"
