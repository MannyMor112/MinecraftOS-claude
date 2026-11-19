#!/bin/bash
# MinecraftOS build script. Run as root on a Debian/Ubuntu x86_64 host:
#   sudo apt-get install debootstrap xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin \
#        mtools dosfstools e2fsprogs openjdk-8-jdk-headless zstd curl
#   sudo ./build/build.sh            # full build -> out/minecraftos-<ver>.iso
#   sudo ./build/build.sh iso        # only re-pack the ISO from an existing rootfs
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$HERE")"
. "$HERE/config.env"
WORK="${WORK:-$ROOT_DIR/work}"
OUT="${OUT:-$ROOT_DIR/out}"
ROOTFS="$WORK/rootfs"
STAGE="$WORK/iso"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT_DIR" log -1 --format=%ct 2>/dev/null || date +%s)}"
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8

log() { echo -e "\n=== $* ==="; }

mount_chroot() {
  mountpoint -q "$ROOTFS/proc" || mount -t proc proc "$ROOTFS/proc"
  mountpoint -q "$ROOTFS/sys"  || mount -t sysfs sys "$ROOTFS/sys"
  mountpoint -q "$ROOTFS/dev"  || mount --bind /dev "$ROOTFS/dev"
  mountpoint -q "$ROOTFS/dev/pts" || mount --bind /dev/pts "$ROOTFS/dev/pts"
}
umount_chroot() {
  for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done
}
trap umount_chroot EXIT
in_chroot() { chroot "$ROOTFS" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive "$@"; }

stage_bootstrap() {
  log "debootstrap $DEBIAN_SUITE from snapshot $SNAPSHOT"
  rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
  debootstrap --variant=minbase --components=main,contrib,non-free-firmware \
    --include=ca-certificates "$DEBIAN_SUITE" "$ROOTFS" "$MIRROR"
}

stage_packages() {
  log "install packages"
  cat > "$ROOTFS/etc/apt/sources.list" <<EOF
deb [check-valid-until=no] $MIRROR $DEBIAN_SUITE main contrib non-free-firmware
deb [check-valid-until=no] $MIRROR $DEBIAN_SUITE-updates main contrib non-free-firmware
deb [check-valid-until=no] $MIRROR $DEBIAN_SUITE-backports main contrib non-free-firmware
deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/$SNAPSHOT $DEBIAN_SUITE-security main contrib non-free-firmware
EOF
  cat > "$ROOTFS/etc/apt/apt.conf.d/90mcos" <<EOF
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Retries "5";
EOF
  # no firmware license prompts; keep the live initramfs generic
  echo 'firmware-ipw2x00 firmware-ipw2x00/license/accepted boolean true' | in_chroot debconf-set-selections
  # Optional extra CA for build hosts behind a TLS-inspecting proxy (removed again in stage_strip)
  if [ -n "${BUILD_CA:-}" ] && [ -f "$BUILD_CA" ]; then
    cp "$BUILD_CA" "$ROOTFS/etc/ssl/mcos-build-ca.crt"
    echo 'Acquire::https::CaInfo "/etc/ssl/mcos-build-ca.crt";' > "$ROOTFS/etc/apt/apt.conf.d/99mcos-build-ca"
  fi
  mount_chroot
  in_chroot apt-get update
  mapfile -t PKGS < <(grep -vE '^\s*(#|$)' "$HERE/packages.list" | grep -vx prismlauncher)
  in_chroot apt-get install -y "${PKGS[@]}"
  # From backports: Prism Launcher, newest Mesa (iris) and the newest kernel. The stable 6.12 LTS
  # kernel stays installed too; GRUB offers both (A/B test without a new ISO).
  in_chroot apt-get install -y -t "$DEBIAN_SUITE-backports" $(grep -vE '^\s*(#|$)' "$HERE/packages-backports.list")
  in_chroot dpkg-query -W -f='${Package} ${Version}\n' > "$WORK/package-versions.txt"
}

stage_java() {
  log "install Java 8 ($JAVA_URL)"
  mkdir -p "$WORK/dl"
  local tgz="$WORK/dl/$(basename "$JAVA_URL")"
  [ -f "$tgz" ] || curl -fL --retry 5 -o "$tgz" "$JAVA_URL"
  echo "$JAVA_SHA256  $tgz" | sha256sum -c -
  rm -rf "$ROOTFS/opt/java8"; mkdir -p "$ROOTFS/opt/java8"
  tar -xzf "$tgz" -C "$ROOTFS/opt/java8" --strip-components=1
}

stage_agent() {
  log "build benchmark agent"
  "$ROOT_DIR/agent/build-agent.sh" "$WORK/agent"
  mkdir -p "$ROOTFS/opt/mcos"
  cp "$WORK/agent/mcos-bench-agent.jar" "$ROOTFS/opt/mcos/"
}

stage_configure() {
  log "configure system"
  # overlay: our scripts and configs
  cp -a "$ROOT_DIR/overlay/." "$ROOTFS/"
  chmod 0755 "$ROOTFS"/usr/local/bin/* "$ROOTFS"/usr/local/lib/mcos/*.sh 2>/dev/null || true
  echo "$MCOS_VERSION" > "$ROOTFS/etc/mcos-version"
  echo minecraftos > "$ROOTFS/etc/hostname"
  printf '127.0.0.1 localhost\n127.0.1.1 minecraftos\n' > "$ROOTFS/etc/hosts"
  ln -sf /usr/share/zoneinfo/UTC "$ROOTFS/etc/localtime"
  mount_chroot
  # the player account (no password; autologin on tty1)
  in_chroot id mc >/dev/null 2>&1 || in_chroot useradd -m -s /bin/bash -G audio,video,input,netdev mc
  in_chroot chown -R mc:mc /home/mc
  in_chroot passwd -d mc
  in_chroot passwd -l root
  # services: only what we need
  in_chroot systemctl enable NetworkManager mcos-data.service mcos-tune.service mcos-hotkeys.service mcos-audio.service
  for u in apt-daily.timer apt-daily-upgrade.timer dpkg-db-backup.timer e2scrub_all.timer fstrim.timer \
           e2scrub_reap.service systemd-timesyncd.service ModemManager.service wpa_supplicant-wired@.service \
           triggerhappy.service triggerhappy.socket NetworkManager-wait-online.service \
           systemd-networkd.service systemd-networkd-wait-online.service; do
    in_chroot systemctl mask "$u" 2>/dev/null || true
  done
  in_chroot systemctl set-default multi-user.target
  # live-boot: rebuild initramfs with live hooks
  in_chroot update-initramfs -u -k all
}

stage_strip() {
  log "strip rootfs"
  in_chroot apt-get clean
  rm -f "$ROOTFS/etc/ssl/mcos-build-ca.crt" "$ROOTFS/etc/apt/apt.conf.d/99mcos-build-ca"
  rm -rf "$ROOTFS"/var/lib/apt/lists/* "$ROOTFS"/var/cache/apt/*.bin \
         "$ROOTFS"/usr/share/man/* "$ROOTFS"/usr/share/info/* \
         "$ROOTFS"/var/log/*.log "$ROOTFS"/tmp/* "$ROOTFS"/root/.bash_history
  # keep only English locales/translations
  find "$ROOTFS/usr/share/locale" -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} + 2>/dev/null || true
  find "$ROOTFS/usr/share/prismlauncher/translations" -name '*.qm' ! -name '*en*' -delete 2>/dev/null || true
  # docs go, but every package's license/copyright file stays (redistribution requirement)
  find "$ROOTFS/usr/share/doc" -type f ! -name copyright -delete 2>/dev/null || true
  find "$ROOTFS/usr/share/doc" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  : > "$ROOTFS/etc/machine-id"
  umount_chroot
}

stage_iso() {
  log "build ISO"
  rm -rf "$STAGE"; mkdir -p "$STAGE/live" "$STAGE/boot/grub" "$STAGE/EFI/BOOT" "$OUT"
  # both kernels: 6.12 LTS (default) and the newest from backports (A/B option in the menu)
  KLTS=$(ls "$ROOTFS/boot" | sed -n 's/^vmlinuz-\(6\.12\..*\)/\1/p' | sort -V | tail -1)
  KNEW=$(ls "$ROOTFS/boot" | sed -n 's/^vmlinuz-//p' | sort -V | tail -1)
  for k in $KLTS $KNEW; do
    cp "$ROOTFS/boot/vmlinuz-$k" "$ROOTFS/boot/initrd.img-$k" "$STAGE/live/"
  done
  # installed-system GRUB template gets the same kernel versions
  sed -i "s/@KLTS@/$KLTS/g; s/@KNEW@/$KNEW/g; s/@VERSION@/$MCOS_VERSION/g" "$ROOTFS/usr/local/share/mcos/grub-installed.cfg"
  # squashfs (zstd: good ratio, fast decompression on slow CPUs)
  mksquashfs "$ROOTFS" "$STAGE/live/filesystem.squashfs" -comp zstd -Xcompression-level 15 -b 1M \
    -noappend -wildcards -e 'boot/*' 'proc/*' 'sys/*' 'dev/*' 'run/*' -mkfs-time "$SOURCE_DATE_EPOCH" -all-time "$SOURCE_DATE_EPOCH"
  echo "$MCOS_VERSION" > "$STAGE/MCOS_VERSION"
  cp -a "$ROOT_DIR/docs" "$STAGE/docs"
  cp -a "$ROOT_DIR/lubuntu" "$STAGE/lubuntu"
  cp "$ROOTFS/opt/mcos/mcos-bench-agent.jar" "$ROOT_DIR/overlay/usr/local/lib/mcos/sampler.sh" \
     "$ROOT_DIR/overlay/usr/local/lib/mcos/report.sh" "$ROOT_DIR/overlay/usr/local/share/mcos/options-bench.txt" \
     "$ROOT_DIR/overlay/usr/local/share/mcos/optionsof-bench.txt" "$STAGE/lubuntu/"
  sed "s/@VERSION@/$MCOS_VERSION/g; s/@KLTS@/$KLTS/g; s/@KNEW@/$KNEW/g" "$HERE/grub.cfg" > "$STAGE/boot/grub/grub.cfg"
  touch "$STAGE/MCOS_LIVE_MEDIUM"

  # GRUB for legacy BIOS (SeaBIOS / RW_LEGACY)
  local mods="part_msdos part_gpt iso9660 fat ext2 search search_label search_fs_file normal linux echo all_video gfxterm test configfile loopback ls cat sleep"
  cat > "$WORK/grub-embed.cfg" <<'EOF'
search --no-floppy --set=root --file /MCOS_LIVE_MEDIUM
set prefix=($root)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EOF
  grub-mkimage -O i386-pc-eltorito -o "$STAGE/boot/grub/bios.img" -p /boot/grub -c "$WORK/grub-embed.cfg" biosdisk $mods
  # GRUB for UEFI (MrChromebox UEFI Full ROM)
  grub-mkimage -O x86_64-efi -o "$WORK/BOOTX64.EFI" -p /boot/grub -c "$WORK/grub-embed.cfg" $mods efi_gop efi_uga
  cp "$WORK/BOOTX64.EFI" "$STAGE/EFI/BOOT/BOOTX64.EFI"
  rm -f "$WORK/efiboot.img"
  mkfs.msdos -C -n MCOSEFI "$WORK/efiboot.img" 4096 >/dev/null
  mmd -i "$WORK/efiboot.img" ::/EFI ::/EFI/BOOT
  mcopy -i "$WORK/efiboot.img" "$WORK/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI

  # Small ext4 data partition appended after the ISO. On first boot it is grown
  # to fill the rest of the USB stick (game files, saves, benchmark results).
  rm -f "$WORK/data.img"; truncate -s 32M "$WORK/data.img"
  mkfs.ext4 -q -F -L MCOSDATA -E root_owner=1000:1000 -J size=4 "$WORK/data.img"

  local iso="$OUT/minecraftos-$MCOS_VERSION.iso"
  xorriso -as mkisofs -iso-level 3 -rational-rock -joliet -full-iso9660-filenames \
    -volid "MCOS_${MCOS_VERSION^^}" \
    -eltorito-boot boot/grub/bios.img -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot \
    -append_partition 2 0xef "$WORK/efiboot.img" \
    -append_partition 3 0x83 "$WORK/data.img" \
    -output "$iso" "$STAGE"
  (cd "$OUT" && sha256sum "$(basename "$iso")" > "$(basename "$iso").sha256")
  cp "$WORK/package-versions.txt" "$OUT/package-versions-$MCOS_VERSION.txt" 2>/dev/null || true
  ls -la "$OUT"; cat "$OUT/$(basename "$iso").sha256"
}

case "${1:-all}" in
  all) stage_bootstrap; stage_packages; stage_java; stage_agent; stage_configure; stage_strip; stage_iso ;;
  rootfs) stage_bootstrap; stage_packages ;;
  finish) stage_java; stage_agent; stage_configure; stage_strip; stage_iso ;;
  repack) stage_agent; stage_configure; stage_strip; stage_iso ;;
  iso) stage_iso ;;
  *) "stage_$1" ;;
esac
