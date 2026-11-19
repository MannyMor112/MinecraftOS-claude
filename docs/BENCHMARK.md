# Benchmark

## How a run works

- **Separate instance.** Each run uses its own Prism instance (`MCOS-bench`), so your world and
  settings are never touched.
- **Same steps every run**, done by a small Java agent (`agent/`, attached with `-javaagent`):
  1. Waits for the main menu, then loads the world `mcos-bench`. The first run creates it with
     **seed 404**, Default world type, cheats on.
  2. Sets spectator mode, time 6000 (noon), daylight cycle off, weather clear, no mobs, no fire
     spread.
  3. Teleports the camera to **x=0 y=110 z=0, yaw −45, pitch 25**.
  4. **Settles for 30 s** (chunk loading, JIT warm-up). Not measured.
  5. **Static phase, 60 s:** fixed view.
  6. **Pan phase, 40 s:** the camera turns one full 360° at constant speed. This stresses
     chunk rendering and frustum changes.
  7. Writes results, then quits the game.
- **How frames are timed:** the agent adds a timestamp call at the start of
  `org.lwjgl.opengl.Display.update()`, which Minecraft calls exactly once per frame. That gives
  exact per-frame times, whatever the driver.
- **Fixed settings** (`overlay/usr/local/share/mcos/options-bench.txt` and
  `optionsof-bench.txt`), identical on MinecraftOS and Lubuntu:
  - render distance 6, Fast graphics, smooth lighting off, clouds off, VBOs on
  - vsync off, unlimited FPS
  - OptiFine: Fast Render, Fast Math, Render Regions, Lazy Chunk Loading
- **Cool-down:** before each run, the script waits until the hottest sensor is ≤ 55 °C (at most
  3 min). This matters on a fanless device.
- **The first run is a warm-up.** It generates the world's chunks and is marked
  `warmup_run=1`. It never counts.

## What gets recorded (`/data/results/<run>.txt` on the USB stick)

**From the agent (per phase `static`, `pan` and combined `all`):**
- average FPS, 1 % low and 0.1 % low FPS (mean of the worst 1 % / 0.1 % frame times)
- frame-time median, p95, p99, max and stddev
- spikes > 50 ms, > 100 ms and > 2× the median
- GC count and GC time, heap used (max/avg)
- game startup time and world load time

**From the system sampler (every 0.5 s, summarised over the measured window):**
- CPU clock per core, CPU busy %
- GPU actual and requested clock
- highest temperature
- thermal-throttle event count
- MemAvailable, swap used, zram original/compressed size
- package power (RAPL), if the firmware exposes it

**Also recorded:**
- kernel, command line, the OpenGL renderer string (a software renderer is flagged INVALID),
  all knob states, JVM flags and GL environment
- raw files: `<run>-frametimes.csv` (every frame) and `<run>-sys.csv`

## Boot entries

| Entry | What it does |
|---|---|
| Benchmark: one run | 1 run with the current defaults |
| Benchmark suite: quick | warm-up + 8 variants × 1 |
| Benchmark suite: full | warm-up + 8 variants × 2, interleaved A B C… A B C… so thermal drift hits all variants equally |
| Benchmark: mitigations ON | 1 run, CPU security mitigations enabled |
| Benchmark: newer kernel | 1 run on kernel 7.2 |

Suite variants (`overlay/usr/local/share/mcos/suite-v1.txt`). Each one changes **one** thing
compared with `base`:

`base`, `glthread`, `noerror`, `powersave`, `gpumax`, `sna`, `parallel`, `nowm`.

After a suite, `suite-<date>-summary.txt` gives the mean (min–max) per variant.

## Lubuntu baseline (to compare against)

The ISO contains a `lubuntu/` folder with `bench-baseline.sh`. It uses the same agent, world,
camera path and settings, with your current launcher and JVM flags. Your `options.txt` is backed
up and restored. Step-by-step instructions come one at a time in the chat.

## Noise rule

A difference counts only if it is larger than the spread (max − min) of the `base` repeats. Once
a factor's effect is inside that spread, it is frozen.
