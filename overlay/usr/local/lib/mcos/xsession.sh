#!/bin/bash
# X client for all MinecraftOS graphical sessions.  usage: xsession.sh play|bench|launcher [glxinfo-out]
. /usr/local/lib/mcos/common.sh
. /etc/mcos/defaults.conf; [ -f /data/mcos.conf ] && . /data/mcos.conf
[ -f /run/user/1000/mcos-run.env ] && . /run/user/1000/mcos-run.env   # per-run overrides (benchmark suite)
xset s off -dpms s noblank 2>/dev/null
xsetroot -solid black -cursor_name left_ptr 2>/dev/null
mkdir -p /data/cache/mesa
export MESA_SHADER_CACHE_DIR=/data/cache/mesa MESA_SHADER_CACHE_MAX_SIZE=512M
for kv in $GL_ENV; do export "$kv"; done
[ -n "${2:-}" ] && glxinfo -B > "$2" 2>&1
wm_pid=""
if [ "$1" = launcher ] || [ "$GAME_WM" = openbox ]; then openbox & wm_pid=$!; sleep 0.5; fi
case "$1" in
  launcher) prismlauncher --dir "$PRISM_DIR" ;;
  play)     prismlauncher --dir "$PRISM_DIR" --launch "$INSTANCE" ;;
  bench)    prismlauncher --dir "$PRISM_DIR" --launch "$BENCH_INSTANCE" ;;
esac
rc=$?
[ -n "$wm_pid" ] && kill "$wm_pid" 2>/dev/null
exit $rc
