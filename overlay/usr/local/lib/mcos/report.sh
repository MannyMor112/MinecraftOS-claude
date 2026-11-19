#!/bin/bash
# Summarises sampler CSV over the measured window of an agent result.
# usage: report.sh agent.txt sys.csv     -> prints key=value lines
agent=$1; csv=$2
win=$(sed -n 's/^phase_static_unix_ms=//p' "$agent"); win2=$(sed -n 's/^phase_pan_unix_ms=//p' "$agent")
t0=${win%-*}; t1=${win2#*-}
[ -z "$t0" ] || [ -z "$t1" ] && { echo "sys_window=unknown (agent did not finish)"; t0=0; t1=99999999999999; }
awk -F, -v t0="$t0" -v t1="$t1" '
NR==1 { next }
$1>=t0 && $1<=t1 {
  n++; for (c=2;c<=14;c++) if (c!=8) { s[c]+=$c; if (n==1||$c<mn[c]) mn[c]=$c; if (n==1||$c>mx[c]) mx[c]=$c }
  if (n==1) { th0=$9; e0=$14; te0=$1 } th1=$9; e1=$14; te1=$1
}
END {
  if (n==0) { print "sys_samples=0"; exit }
  name[2]="cpu0_mhz"; name[3]="cpu1_mhz"; name[4]="cpu_busy_pct"; name[5]="gpu_act_mhz"; name[6]="gpu_req_mhz";
  name[7]="temp_max_c"; name[10]="mem_avail_mb"; name[11]="swap_used_mb"; name[12]="zram_orig_mb"; name[13]="zram_compr_mb"
  printf "sys_samples=%d\n", n
  for (c=2;c<=13;c++) if (c in name) printf "sys_%s_avg_min_max=%.0f/%.0f/%.0f\n", name[c], s[c]/n, mn[c], mx[c]
  printf "sys_throttle_events_during_run=%d\n", th1-th0
  if (e1>e0 && te1>te0) printf "sys_package_power_avg_w=%.2f\n", (e1-e0)/((te1-te0)*1000)
  else print "sys_package_power_avg_w=n/a"
}' "$csv"
