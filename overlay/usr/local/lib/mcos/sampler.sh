#!/bin/bash
# System sampler: writes one CSV line every 0.5 s until killed.  Portable (also used on Lubuntu).
# usage: sampler.sh out.csv   (run as root to include RAPL power)
out=$1; interval=${2:-0.5}
cpus=(/sys/devices/system/cpu/cpu[0-9]*)
gpu=""; for d in /sys/class/drm/card*; do [ -f "$d/gt_act_freq_mhz" ] && { gpu=$d; break; }; done
zones=(); for z in /sys/class/thermal/thermal_zone*; do [ -f "$z/temp" ] && zones+=("$z"); done
hw=(); for h in /sys/class/hwmon/hwmon*/temp*_input; do [ -f "$h" ] && hw+=("$h"); done
rapl=""; for r in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl/intel-rapl:0; do [ -r "$r/energy_uj" ] && { rapl=$r/energy_uj; break; }; done
rd() { local v; { read -r v < "$1"; } 2>/dev/null; echo "${v:-0}"; }
echo "t_ms,cpu0_mhz,cpu1_mhz,cpu_busy_pct,gpu_act_mhz,gpu_req_mhz,temp_max_c,temp_zones,throttle_count,mem_avail_mb,swap_used_mb,zram_orig_mb,zram_compr_mb,energy_uj" > "$out"
read -r _ u n s i w q sq rest < /proc/stat; prev_tot=$((u+n+s+i+w+q+sq)); prev_idle=$((i+w))
while :; do
  t=${EPOCHREALTIME/./}; t=${t:0:13}
  f0=$(( $(rd ${cpus[0]}/cpufreq/scaling_cur_freq) / 1000 ))
  f1=$(( $(rd ${cpus[1]:-${cpus[0]}}/cpufreq/scaling_cur_freq) / 1000 ))
  read -r _ u n s i w q sq rest < /proc/stat; tot=$((u+n+s+i+w+q+sq)); idle=$((i+w))
  dt=$((tot-prev_tot)); busy=0; [ $dt -gt 0 ] && busy=$(( 100*(dt-(idle-prev_idle))/dt )); prev_tot=$tot; prev_idle=$idle
  ga=0; gr=0; [ -n "$gpu" ] && { ga=$(rd $gpu/gt_act_freq_mhz); gr=$(rd $gpu/gt_cur_freq_mhz); }
  tmax=0; tz=""
  for z in "${zones[@]}" "${hw[@]}"; do
    if [ -f "$z/temp" ]; then v=$(rd $z/temp); else v=$(rd $z); fi
    v=$((v/1000)); tz="$tz$v;"; [ $v -gt $tmax ] && tmax=$v
  done
  th=0; for c in "${cpus[@]}"; do for x in $c/thermal_throttle/core_throttle_count $c/thermal_throttle/package_throttle_count; do [ -f $x ] && th=$((th+$(rd $x))); done; done
  ma=0; st=0; sf=0
  while read -r k v _; do case $k in MemAvailable:) ma=$v;; SwapTotal:) st=$v;; SwapFree:) sf=$v;; esac; done < /proc/meminfo
  zo=0; zc=0; [ -f /sys/block/zram0/mm_stat ] && read -r zo zc _ < /sys/block/zram0/mm_stat
  e=0; [ -n "$rapl" ] && e=$(rd $rapl)
  echo "$t,$f0,$f1,$busy,$ga,$gr,$tmax,${tz%;},$th,$((ma/1024)),$(((st-sf)/1024)),$((zo/1048576)),$((zc/1048576)),$e" >> "$out"
  sleep "$interval"
done
