# Tuning: what v1 does, and what is still a hypothesis

Rule: every optimisation is a **hypothesis** until the benchmark on the real Chromebook shows a
gain bigger than run-to-run noise. Noise is measured by repeating the `base` variant in the suite.
Once a factor's gain is inside the noise, it is frozen and no longer tested.

## Overclocking / undervolting: not possible, dropped

- **Celeron N3060 (Braswell/Airmont) is fully locked.** It has no unlocked multiplier and no
  BCLK control.
- **Undervolting** uses the voltage-offset interface (MSR 0x150), which only exists on Core CPUs
  (Haswell to Comet Lake). Atom-class Airmont doesn't have it.
- **Firmware:** MrChromebox coreboot has no overclocking or voltage options.
- **Conclusion:** no overclocking or undervolting is possible. **Dropped.**
- **The one related knob is the package power limit (RAPL PL1/PL2)**, if the firmware exposes it
  (`System info` shows the values).
  - Raising it doesn't bypass thermal protection: the CPU still throttles at its maximum
    temperature (TjMax / PROCHOT).
  - On a fanless laptop it would make the case hotter, and sustained FPS might not even improve.
  - v1 does **not** touch it. I'll only propose it if the results show the chip is power-limited
    (GPU clock below its max while temperatures are low), and then you decide.

## What v1 sets (and why)

| Area | v1 setting | Reason / status |
|---|---|---|
| CPU mitigations | `mitigations=off` | Airmont isn't affected by Meltdown/L1TF, so the expected gain is small (only Spectre v2/MDS paths). **Security trade-off:** a malicious program (or JavaScript, but there's no browser) could read other processes' memory. The only network-facing code here is Minecraft and the launcher. A "mitigations ON" boot entry measures the actual difference. |
| CPU governor | `performance` | Braswell has short boost windows and the power limit decides anyway. Suite variant `powersave` tests this. |
| GPU clock | driver default (dynamic) | Suite variant `gpumax` pins the minimum clock to the maximum. That gives more consistent frame times but more heat. |
| Watchdogs | `nowatchdog nmi_watchdog=0` | Fewer timer interrupts. Gain is tiny but costs nothing. |
| Display path | Xorg modesetting/glamor, no compositor, openbox (no effects) | Suite variants `sna` (xf86-video-intel) and `nowm` (no window manager) |
| GL driver | Mesa 26.1 iris, `vblank_mode=0`, persistent shader cache | Suite variants `glthread` (`mesa_glthread=true`, moves GL driver work to a 2nd thread, which could help or hurt on 2 cores) and `noerror` (`MESA_NO_ERROR=1`) |
| JVM | Temurin 8, `-Xms1G -Xmx1G`, G1 with the official launcher's flags | Matches the baseline. Suite variant `parallel` (ParallelGC: fewer GC threads competing with the game on 2 cores) |
| Memory | zram swap ram/2 with lz4, swappiness 100, page-cluster 0 | lz4 costs less CPU than zstd on a 2-core Atom. Later test: zstd, smaller zram |
| Services | ~10 processes at idle; journal in RAM; apt/timers/time sync/modem masked | Measured idle RAM goes into System info |
| I/O | `none` scheduler on eMMC/USB, `noatime`, `commit=60`, dirty writeback 15 s | Fewer small writes to slow flash |
| Wi-Fi | power-save off | Fewer multiplayer latency spikes. Costs a little battery |
| Audio | ALSA directly (no sound server) | Saves ~30 MB RAM and a constantly running process |

## Queue of hypotheses for later versions (not in v1)

- Kernel: `preempt=full` vs `voluntary`; custom kernel (HZ=1000, `-march=silvermont`, trimmed
  config). Only if the 6.12 vs 7.2 comparison shows the kernel matters at all.
- Launch path: Prism stays resident (~100 MB RAM) while the game runs. A lighter wrapper that
  hands off to the game after sign-in, if RAM shows up as a limit.
- JVM: heap 768M vs 1G vs 1.5G; `-XX:+AlwaysPreTouch`; a newer Java 8 build (Zulu).
- OptiFine settings sweep (render regions, chunk updates, fast render).
- Other 1.8.9 mods: Forge + Patcher / BetterFPS. Forge adds RAM and startup time, so it only
  goes in if it beats OptiFine alone.
- zram: zstd, size ram/4, or no zram at all if swap is never touched.
- mesa-amber (`i965`) built from source, only if iris turns out slow.
