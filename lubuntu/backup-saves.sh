#!/bin/bash
# Run on your CURRENT Lubuntu, with the MinecraftOS USB stick plugged in.
# Copies ~/.minecraft/saves (+ options, screenshots, servers) into a .tar.gz on the stick's
# MCOSDATA partition (or into your home folder if that partition is not mounted).
set -e
MC=${1:-$HOME/.minecraft}
[ -d "$MC/saves" ] || { echo "No saves folder at $MC/saves"; exit 1; }
DEST=$(findmnt -rno TARGET -S LABEL=MCOSDATA 2>/dev/null | head -1)
if [ -n "$DEST" ]; then DEST=$DEST/backup; sudo mkdir -p "$DEST"; sudo chown "$(id -u):$(id -g)" "$DEST"; else DEST=$HOME; fi
OUT=$DEST/saves-$(whoami)-$(date +%Y%m%d-%H%M%S).tar.gz
cd "$MC"
tar -czf "$OUT" saves $(ls -d options.txt optionsof.txt screenshots servers.dat 2>/dev/null)
tar -tzf "$OUT" > /dev/null
sync
echo "Backed up $(ls saves | wc -l) world(s) to: $OUT ($(du -h "$OUT" | cut -f1))"
echo "Archive verified OK."
