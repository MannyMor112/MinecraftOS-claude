# Writing the USB stick and booting it

In the chat you get these steps **one at a time**. This file is the full reference.

You need a USB stick of **at least 4 GB** (8 GB+ recommended; game files are ~300 MB, and
results, backups and the shader cache grow over time). **Everything on the stick is erased.**

## A. Write the ISO (on your current Lubuntu)

1. Download `minecraftos-v1.iso` and `minecraftos-v1.iso.sha256` into `~/Downloads`.
2. Check the download:
   ```
   cd ~/Downloads && sha256sum -c minecraftos-v1.iso.sha256
   ```
   It must print `minecraftos-v1.iso: OK`.
3. Plug in the stick and find its name:
   ```
   lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINT
   ```
   The stick is the line with `usb` in the TRAN column and the right size, e.g. `sdb`.
   **The internal eMMC is `mmcblk0`. Never use that.**
4. Unmount it (replace `sdX` with your stick, e.g. `sdb`):
   ```
   sudo umount /dev/sdX?* 2>/dev/null; true
   ```
5. Write it:
   ```
   sudo dd if=minecraftos-v1.iso of=/dev/sdX bs=4M conv=fsync status=progress
   ```
6. `sync`, then unplug the stick.

GUI alternatives such as balenaEtcher or GNOME Disks "Restore Disk Image" also work.
Ventoy does **not** work, because the data partition must be on the stick itself.

## B. Boot it on the Chromebook

Which keys you use depends on the firmware. The first chat step finds this out.

- **MrChromebox UEFI Full ROM:** plug in the stick, power on, press **Esc** at the rainbow
  bunny / coreboot logo, then choose the USB stick in the Boot Manager menu.
- **RW_LEGACY (SeaBIOS):** at the white "OS verification is off" screen press **Ctrl+L**. Then
  at "Press ESC for boot menu" press **Esc**, and pick the USB stick by its number.

The MinecraftOS menu then appears. **Play Minecraft** starts automatically after 5 s.

## First boot

1. The data partition on the stick grows to fill the stick. This takes a few seconds, once.
2. Wi-Fi setup: in `nmtui`, choose "Activate a connection", pick your network, then type the
   password.
3. OptiFine is downloaded from optifine.net.
4. Prism Launcher opens for the Microsoft sign-in. Scan the QR code with your phone, or open
   `microsoft.com/link` and type the code.
5. Close Prism. The first **Play** downloads Minecraft 1.8.9 (~200 MB) from Mojang.

## Keys in-game (Chromebook top row)

- Top row = F1…F10.
  - F1 hides the HUD, F2 takes a screenshot, F3 opens the debug screen, F5 changes perspective.
  - F6/F7 change brightness, F9/F10 change volume.
  - Search+F8 mutes. Plain F8 is Minecraft's smooth camera.
- Quit the game normally (Esc → Save and Quit → Quit Game) to get back to the MinecraftOS menu.
- Results, backups and the game live on the stick's **MCOSDATA** partition. Lubuntu mounts it
  automatically when you plug the stick in.
