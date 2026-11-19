# OS comparison and final choice

Requirements that disqualify candidates outright:

- **Hardware OpenGL on Intel HD 400 (Gen8, Braswell).** Software rendering is disqualified.
- **A Java 8 JVM.** 1.8.9 with OptiFine uses LaunchWrapper, which breaks on Java 9+.
- **LWJGL 2.9.4 native libraries.** Mojang only ships these for Windows, macOS and Linux
  (glibc, x86/x86_64). Every other OS would need a source port of LWJGL2.
- **Legitimate Microsoft sign-in.** Mojang only lets approved apps use its auth API.
  Prism Launcher is approved. Writing my own launcher with a new client ID is not allowed.
- **Free to redistribute in an ISO.**

| Candidate | GPU accel. on HD 400 | Java 8 | LWJGL2 natives | MS login | Wi-Fi/audio on Braswell Chromebook | Verdict |
|---|---|---|---|---|---|---|
| **Debian 13 (glibc Linux), custom minimal image** | Yes: Mesa `iris` (Gen8+); i915 KMS is mature | Temurin 8 (official build) | Official Mojang Linux natives | Prism Launcher, packaged in Debian backports | iwlwifi/ath10k firmware packaged; SOF/SST audio firmware + UCM packaged | **Chosen** |
| Arch Linux (custom image) | Same Mesa/kernel | Same | Same | Same (AUR/Flatpak) | Same | Technically equal. Rejected because it is rolling: no frozen snapshot, so builds aren't reproducible and every iteration would change many variables at once |
| Alpine Linux (musl) | Mesa iris: yes | Temurin 8 for musl exists | **No**: Mojang's natives are linked against glibc, so you need gcompat shims | Prism builds for glibc only | Yes | Rejected: glibc-compat risk on exactly the parts that matter |
| FreeBSD 14/15 | `drm-kmod` i915 covers Gen8, Mesa iris works | OpenJDK 8 port | **No official natives**. The `games/lwjgl` port exists but is old; Linux-compat mode for the game is fragile | Prism has a FreeBSD port | Braswell Chromebook audio (SST/SOF) is **not supported**. Intel Wi-Fi via `iwlwifi`/`iwm` is slower and less mature | Rejected: audio is a hard requirement |
| OpenBSD / NetBSD | inteldrm Gen8 works | No maintained Java 8 + LWJGL2 path | No | No | Partly | Rejected |
| Haiku | **No 3D acceleration** for Intel (software Mesa) | Partly | No | No | Partly | Disqualified (software rendering) |
| Custom minimal OS / unikernel | Would need a full GPU driver stack | — | — | — | — | Not viable: years of work just for i915 + Mesa |
| Windows / ChromeOS | — | — | — | — | — | Can't be redistributed in an ISO |

## Why Debian 13 "trixie" specifically

- **Reproducible.** The build pins `snapshot.debian.org` to `20261118T000000Z`, so a rebuild gets
  byte-identical package versions (`out/package-versions-v1.txt` lists them all).
- **Newest GPU stack, but not bleeding-edge.** It uses Mesa **26.1.6** from trixie-backports
  (newest `iris`).
  - Old `i965` was removed from Mesa in 22.0. It only survives in the "amber" branch, which Debian
    doesn't package. If iris turns out to be slow, building mesa-amber is a possible later test.
  - `crocus` only covers Gen4–7, so it isn't an option for HD 400.
- **Two kernels in one ISO.**
  - **6.12 LTS** is the default, because it is the most tested i915 on old hardware.
  - **7.2** (backports) can be chosen from the boot menu, so the kernel can be A/B tested with no
    new ISO.
- **Every firmware blob is redistributable** (Debian `non-free-firmware`): Intel/Atheros/Realtek/
  Broadcom Wi-Fi, SOF + SST audio DSP, i915.
- `live-boot` gives a proven squashfs + RAM-overlay live system that works from USB.

## Stack

| Layer | Choice | Notes |
|---|---|---|
| Kernel | Debian 6.12 LTS (default), 7.2 (option) | `mitigations=off` by default (see TUNING.md) |
| Init | systemd, trimmed (timers, timesyncd, ModemManager etc. masked; volatile journal) | runit/OpenRC would save a few MB RAM. Not worth it while the RAM budget is fine |
| Display | Xorg + `modesetting` (glamor) without a compositor; tiny openbox WM only for launcher dialogs | LWJGL2 is X11-only. `xf86-video-intel` (SNA) is in the benchmark suite |
| GL | Mesa 26.1 `iris` | `vblank_mode=0`, persistent shader cache on the USB stick |
| Audio | ALSA directly (UCM + softvol + dmix), no PulseAudio/PipeWire | Least CPU/RAM. OpenAL talks to ALSA |
| Network | NetworkManager + `nmtui` (text UI) | |
| JVM | Eclipse Temurin 8u512 JRE | |
| Launcher | Prism Launcher 11.0.2 (Debian backports) | Microsoft sign-in by device code / QR, so no browser is needed |
| Mods | OptiFine 1.8.9 HD U M5 | Downloaded on first boot from optifine.net (not redistributable) and patched with OptiFine's own `optifine.Patcher` |
