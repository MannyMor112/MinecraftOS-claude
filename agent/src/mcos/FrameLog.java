package mcos;

/** Called on the render thread once per frame (start of Display.update). Must stay cheap. */
public final class FrameLog {
    static final int CAP = 1 << 20;               // ~1M frames, 8 MB
    static final long[] t = new long[CAP];
    static volatile int n = 0;
    static volatile boolean recording = false;
    static volatile long totalFrames = 0;
    static volatile String hookError = null;
    /** optional per-frame callback (camera pan), runs on the render thread */
    static volatile Runnable perFrame = null;

    public static void frame() {
        long now = System.nanoTime();
        totalFrames++;
        if (recording) {
            int i = n;
            if (i < CAP) { t[i] = now; n = i + 1; }
        }
        Runnable r = perFrame;
        if (r != null) {
            try { r.run(); } catch (Throwable e) { perFrame = null; Bench.note("perFrame error: " + e); }
        }
    }

    static void start() { n = 0; recording = true; }
    static long[] stop() {
        recording = false;
        long[] out = new long[n];
        System.arraycopy(t, 0, out, 0, n);
        return out;
    }
}
