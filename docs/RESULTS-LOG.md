# Benchmark results log

Benchmark profile: fixed. See BENCHMARK.md (seed 404, x0 y110 z0, 60 s static + 40 s pan,
render distance 6, Fast, unlimited FPS). "all" means both phases combined, weighted by frame.

| Version | System / variant | Runs | Avg FPS (all) | 1 % low | Static FPS | Pan FPS | Max temp | Notes |
|---|---|---|---|---|---|---|---|---|
| — | Lubuntu 20.04 baseline (your launcher, OptiFine M5, your JVM flags) | — | *pending* | | | | | run `lubuntu/bench-baseline.sh` |
| v1 | MinecraftOS v1 defaults (`base`) | — | *pending* | | | | | |

## Version changelog

### v1 (2026-11-19)
- First build: Debian 13 + backports, kernel 6.12 LTS (7.2 optional), Mesa 26.1 iris, Xorg
  modesetting, Temurin 8u512, Prism 11.0.2, OptiFine M5 downloaded at first boot.
- Defaults: mitigations=off, governor performance, zram lz4 ram/2, G1 1 G heap,
  vblank_mode=0, openbox.
- Suite variables tested in v1: glthread, MESA_NO_ERROR, powersave governor, GPU min=max,
  SNA driver, ParallelGC, no WM. Separate reboots test mitigations ON and kernel 7.2.
- **Not yet verified on real hardware.** The game launch, the agent's automation and audio
  routing can only be tested on the Chromebook.
