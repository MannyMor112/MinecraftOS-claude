# tty1 autologin -> MinecraftOS session
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$DISPLAY" ]; then
  exec /usr/local/bin/mcos-session
fi
