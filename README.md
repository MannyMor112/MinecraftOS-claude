# MinecraftOS

A single-purpose live OS: **boot → Minecraft Java 1.8.9 + OptiFine**. It is tuned for one device,
an Intel Celeron N3060 Chromebook (Braswell, HD Graphics 400, 4 GB RAM). It has a built-in
benchmark so every change is measured on the real hardware.

- Runs fully from a USB stick. Installing to the internal drive is a separate option that
  erases the drive.
- Boots with legacy BIOS (SeaBIOS / RW_LEGACY) and with UEFI (MrChromebox Full ROM), using a
  hybrid ISO.
- No Minecraft files are in the ISO. You sign in with your own Microsoft account in Prism
  Launcher, and the game is downloaded from Mojang. OptiFine is downloaded from optifine.net at
  first boot.

## Documents

| | |
|---|---|
| [docs/USB-GUIDE.md](docs/USB-GUIDE.md) | Write the USB stick and boot it |
| [docs/OS-COMPARISON.md](docs/OS-COMPARISON.md) | Candidate OSes and why Debian was chosen |
| [docs/TUNING.md](docs/TUNING.md) | Every setting, why it's there, overclocking verdict, hypotheses |
| [docs/BENCHMARK.md](docs/BENCHMARK.md) | What the benchmark does and records |
| [docs/RESULTS-LOG.md](docs/RESULTS-LOG.md) | Results across versions vs. the Lubuntu baseline |
| [docs/RECOVERY.md](docs/RECOVERY.md) | Getting back to a normal Linux |
| [docs/SUMMARY.md](docs/SUMMARY.md) | Honest summary: what helped, what didn't, what FPS to expect |

## Build from source

You need an x86_64 Debian/Ubuntu host, root, ~6 GB of disk and internet access.

```
sudo apt-get install debootstrap xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin \
     mtools dosfstools e2fsprogs openjdk-8-jdk-headless zstd curl
sudo ./build/build.sh          # -> out/minecraftos-<version>.iso + .sha256
```

All inputs are pinned in `build/config.env`:
- the Debian snapshot date
- the Temurin URL and SHA-256
- OptiFine's SHA-256, inside `mcos-optifine`

Behind a TLS-intercepting proxy, pass `BUILD_CA=/path/ca.crt`. It is only used during the build
and is removed from the image.

## Layout

- `build/`: build script, package lists, GRUB menu
- `overlay/`: files copied into the image (`/usr/local/bin/mcos-*`, systemd units, configs)
- `agent/`: benchmark Java agent (frame timing + automation)
- `lubuntu/`: scripts to run on the current Lubuntu (save backup, baseline benchmark)
- `results/`: benchmark result files received from the device
