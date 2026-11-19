#!/bin/bash
# Runs as root at boot: find the MCOSDATA partition, grow it to fill the USB stick on
# first boot, and mount it at /data. On an internal install /data is a normal directory.
set -u
. /usr/local/lib/mcos/common.sh
mkdir -p /data
log() { echo "mcos-data: $*"; echo "mcos-data: $*" > /dev/kmsg 2>/dev/null; }

# The hybrid ISO's MBR has partition 1 starting at sector 0 (normal for isohybrid), which sfdisk/
# growpart refuse to touch. So we set the size field of our own (last) MBR entry directly:
# entry N lives at byte 446+16*(N-1); its 32-bit little-endian sector count is at +12.
grow_mbr_partition() {  # disk dev partnum
  local disk=$1 dev=$2 n=$3 start disksz new cur off le
  [ "$(dd if="$disk" bs=1 skip=510 count=2 2>/dev/null | od -An -tx1 | tr -d ' ')" = 55aa ] || return 1
  [ "$(dd if="$disk" bs=1 skip=$((446+16*(n-1)+4)) count=1 2>/dev/null | od -An -tx1 | tr -d ' ')" = 83 ] || return 1
  start=$(cat /sys/class/block/$(basename "$dev")/start)
  disksz=$(cat /sys/class/block/$(basename "$disk")/size)
  cur=$(cat /sys/class/block/$(basename "$dev")/size)
  new=$(( (disksz - start) / 2048 * 2048 ))      # whole MiB
  [ $new -gt $cur ] && [ $new -lt 4294967296 ] || return 1
  e2fsck -fy "$dev" >/dev/null 2>&1
  off=$((446 + 16*(n-1) + 12)); le=$(printf '%08x' $new)
  printf "\\x${le:6:2}\\x${le:4:2}\\x${le:2:2}\\x${le:0:2}" | dd of="$disk" bs=1 seek=$off conv=notrunc,fsync status=none || return 1
  resizepart "$disk" "$n" "$new" 2>/dev/null || partx -u -n "$n" "$disk" 2>/dev/null
  udevadm settle -t 10 || true
  [ "$(cat /sys/class/block/$(basename "$dev")/size)" = "$new" ]
}

if [ -f /etc/mcos-installed ]; then
  log "installed system, /data is on the root filesystem"
else
  udevadm settle -t 10 || true
  dev=$(blkid -L MCOSDATA 2>/dev/null | head -1)
  if [ -z "$dev" ]; then
    log "no MCOSDATA partition found - using RAM (nothing will be saved!)"
    mount -t tmpfs -o size=1500M,mode=0755 tmpfs /data
    touch /data/.ram-only
  else
    disk=/dev/$(lsblk -no PKNAME "$dev" | head -1)
    partnum=$(cat /sys/class/block/$(basename "$dev")/partition)
    size=$(blockdev --getsize64 "$dev")
    if [ "$size" -lt $((512*1024*1024)) ]; then
      log "first boot: growing $dev to fill $disk (this takes a moment)"
      grow_mbr_partition "$disk" "$dev" "$partnum" && resize2fs "$dev" >/dev/null 2>&1 \
        && log "resized to $(( $(blockdev --getsize64 "$dev") / 1024 / 1024 )) MiB" || log "grow failed - continuing with the small partition"
    fi
    mount -o noatime,commit=60 "$dev" /data || mount -o noatime "$dev" /data || { log "mount failed"; mount -t tmpfs tmpfs /data; touch /data/.ram-only; }
  fi
fi
mkdir -p "$PRISM_DIR" "$RESULTS" "$DATA/backup" "$DATA/cache"
chown 1000:1000 "$DATA" "$PRISM_DIR" "$RESULTS" "$DATA/backup" "$DATA/cache"
exit 0
