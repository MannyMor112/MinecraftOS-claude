# Honest summary (updated after every iteration)

## Status: v1, not yet measured on your hardware

No real numbers exist yet. Everything below is an **expectation**, to be replaced by measured
results.

### Verified in the build environment
- The ISO builds reproducibly from pinned sources.
- It boots in a virtual machine with legacy BIOS and with UEFI.
- The data partition grows and mounts, and the menu and first-run flow appear.
- The OptiFine download and `optifine.Patcher` step work, using the same commands as the
  scripts.
- The benchmark agent compiles. The Minecraft classes, fields and methods it uses were checked
  against the real 1.8.9 `client.jar` and the MCP 1.8.9 mappings.

### Not verifiable without your Chromebook
- The real game launch through Prism, Microsoft sign-in, and the agent's world automation inside
  a running game. I can't run the game here without an account, and I won't use offline mode.
- iris on HD 400, Wi-Fi, audio routing (codec/UCM), touchpad, brightness keys.

v1 can fail in ways only your hardware shows. That is why each step comes back to me with a
results file.

### Realistic expectations
- **The hardware sets the ceiling.** HD Graphics 400 is a 12-EU Gen8 GPU sharing a 6 W power
  budget with two Atom-class cores, and Minecraft 1.8.9 is mostly limited by single-thread CPU
  speed and draw calls.
- OS-level work (driver stack, no compositor, fewer services, JVM/GC, governor) typically gives
  **single-digit to ~20 %** more average FPS, and usually a larger improvement in
  **1 % lows / stutter** (GC, background tasks, swap).
- It will **not** double your FPS. If a single change claims +50 %, I'll treat it as a
  measurement error until it repeats.
- The final "FPS you should expect in normal play" will come from the measured `base` numbers
  of the best version. Normal play has mobs, movement and chunk generation, so expect it to be
  somewhat below the static-view number.

### What made the biggest difference / what didn't help
*To be filled from measurements.*
