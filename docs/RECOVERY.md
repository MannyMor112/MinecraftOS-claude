# Recovery guide

## Running from USB (the default): nothing to recover

The live USB never writes to the internal drive. The only exception is the explicit
**Install** option.
- Unplug the stick and reboot: the Chromebook boots Lubuntu exactly as before.
- **Back up saves** mounts the internal drive **read-only**.

## The USB stick misbehaves

- **It doesn't boot / black screen:** pick "Safe mode without graphics driver" in the boot menu.
  That gives the text menu for backup and shell.
- **Start fresh, keeping nothing:** rewrite the ISO (USB-GUIDE.md, part A). This also wipes the
  stick's data partition, including results! Copy `MCOSDATA/results` and `MCOSDATA/backup` off
  the stick first (plug it into Lubuntu; it mounts automatically).
- **Start fresh, but keep results and saves:** delete `prism/` and `cache/` on MCOSDATA from
  Lubuntu. MinecraftOS then runs the first-time setup again.

## After installing MinecraftOS to the internal drive

Your saves backup is on the USB stick (`MCOSDATA/backup/saves-*.tar.gz`). Unpack it with
`tar -xzf file.tar.gz`.

Back to a normal Linux (e.g. Lubuntu or Xubuntu):
1. On any other computer, write a Linux installer USB, e.g. the Lubuntu 24.04 ISO from
   lubuntu.me. Use the same `dd` command as USB-GUIDE.md, or balenaEtcher.
2. Boot it on the Chromebook the same way as the MinecraftOS stick:
   - UEFI firmware: Esc, then Boot Manager.
   - SeaBIOS: Ctrl+L, then Esc.
3. Choose "Install" and "Erase disk". MinecraftOS's GPT layout is handled normally by every
   installer.

**If the Chromebook won't boot at all** (no firmware screen; very unlikely, because MinecraftOS
never touches the firmware):
- MrChromebox firmware: MrChromebox.tech → "Unbricking".
- Stock ChromeOS recovery: Esc+Refresh+Power, plus a recovery USB made with Google's
  "Chromebook Recovery Utility" on another computer.

## Firmware

MinecraftOS **never modifies the firmware**. Nothing here needs firmware changes. If a firmware
change would ever help, it will be explained with its risk, and you decide.
