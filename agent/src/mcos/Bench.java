package mcos;

import java.io.*;
import java.lang.management.*;
import java.lang.reflect.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * Benchmark controller. All Minecraft access is by reflection on the 1.8.9 obfuscated names
 * (verified against client.jar 1.8.9 with MCP srg mappings 1.8.9 / stable_22):
 *   ave = Minecraft, ave.A() = getMinecraft, ave.f = theWorld, ave.h = thePlayer, ave.m = currentScreen
 *   ave.a(String,String,adp) = launchIntegratedServer, ave.a(Runnable) = addScheduledTask, ave.m() = shutdown
 *   aya = GuiMainMenu, adp = WorldSettings, adp$a = GameType, adp$a.a(int) = getByID, adp.b() = enableCommands
 *   adr = WorldType, adr.b = DEFAULT, bew = EntityPlayerSP, bew.e(String) = sendChatMessage
 *   pk = Entity: y = rotationYaw, z = rotationPitch, A = prevRotationYaw, B = prevRotationPitch
 */
final class Bench implements Runnable {
    static final StringBuilder notes = new StringBuilder();
    static final long T0 = System.currentTimeMillis();

    static synchronized void note(String s) {
        String line = String.format("[+%6.1fs] %s", (System.currentTimeMillis() - T0) / 1000.0, s);
        notes.append(line).append('\n');
        System.out.println("[mcos-bench] " + line);
    }

    final Properties cfg;
    Class<?> mcCls;
    Object mc;
    Field fWorld, fPlayer, fScreen;

    Bench(Properties cfg) { this.cfg = cfg; }

    String p(String k, String d) { return cfg.getProperty(k, d); }
    int pi(String k, int d) { return Integer.parseInt(p(k, String.valueOf(d)).trim()); }
    double pd(String k, double d) { return Double.parseDouble(p(k, String.valueOf(d)).trim()); }

    public void run() {
        final long timeout = pi("timeoutSeconds", 900) * 1000L;
        Thread watchdog = new Thread("mcos-bench-watchdog") {
            public void run() {
                try { Thread.sleep(timeout); } catch (InterruptedException e) { return; }
                note("TIMEOUT after " + timeout / 1000 + "s - writing partial results and exiting");
                writeResults(null, null, null, "timeout");
                Runtime.getRuntime().halt(3);
            }
        };
        watchdog.setDaemon(true);
        watchdog.start();
        try {
            bench();
        } catch (Throwable t) {
            StringWriter sw = new StringWriter();
            t.printStackTrace(new PrintWriter(sw));
            note("ERROR: " + sw);
            writeResults(null, null, null, "error: " + t);
            quit(4);
        }
    }

    void bench() throws Exception {
        if (FrameLog.hookError != null) note("frame hook error: " + FrameLog.hookError);
        // 1. wait for the Minecraft instance
        while (mc == null) {
            Thread.sleep(250);
            if (mcCls == null) for (Class<?> c : Agent.inst.getAllLoadedClasses()) if (c.getName().equals("ave")) { mcCls = c; break; }
            if (mcCls != null) {
                try { mc = mcCls.getMethod("A").invoke(null); } catch (Throwable ignored) { }
            }
        }
        note("Minecraft instance found (loader " + mcCls.getClassLoader() + ")");
        fWorld = mcCls.getField("f");
        fPlayer = mcCls.getField("h");
        fScreen = mcCls.getField("m");

        // 2. wait for the main menu
        long tMenu0 = System.currentTimeMillis();
        while (true) {
            Object s = fScreen.get(mc);
            if (s != null && s.getClass().getName().equals("aya")) break;
            if (s != null && System.currentTimeMillis() - tMenu0 > 90000) { note("no GuiMainMenu, continuing on " + s.getClass().getName()); break; }
            Thread.sleep(250);
        }
        long startupMs = System.currentTimeMillis() - T0;
        note("main menu reached, startup " + startupMs + " ms; frames so far " + FrameLog.totalFrames);
        Thread.sleep(1500);

        // 3. load (or create on first run) the fixed benchmark world
        final ClassLoader cl = mcCls.getClassLoader();
        Class<?> wsCls = Class.forName("adp", true, cl);
        Class<?> gtCls = Class.forName("adp$a", true, cl);
        Class<?> wtCls = Class.forName("adr", true, cl);
        Object gameType = gtCls.getMethod("a", int.class).invoke(null, 3); // spectator: no falling, no collisions
        Object worldType = wtCls.getField("b").get(null);
        long seed = Long.parseLong(p("seed", "404"));
        final Object settings = wsCls.getConstructor(long.class, gtCls, boolean.class, boolean.class, wtCls)
                .newInstance(seed, gameType, true, false, worldType);
        wsCls.getMethod("b").invoke(settings); // enable commands (cheats)
        final String world = p("world", "mcos-bench");
        final Method launch = mcCls.getMethod("a", String.class, String.class, wsCls);
        final long tLoad0 = System.currentTimeMillis();
        onMain(new Runnable() { public void run() {
            try { launch.invoke(mc, world, world, settings); } catch (Exception e) { note("launchIntegratedServer failed: " + e.getCause()); }
        }});
        note("loading world '" + world + "' seed " + seed);

        // 4. wait until in-game (player exists, no loading screen)
        while (fPlayer.get(mc) == null || fScreen.get(mc) != null || fWorld.get(mc) == null) Thread.sleep(200);
        long worldLoadMs = System.currentTimeMillis() - tLoad0;
        note("in world after " + worldLoadMs + " ms");
        Thread.sleep(2000);

        // 5. fixed, deterministic scene
        double x = pd("x", 0), y = pd("y", 100), z = pd("z", 0);
        float yaw = (float) pd("yaw", 0), pitch = (float) pd("pitch", 20);
        String[] cmds = {
            "/gamemode 3", "/gamerule doDaylightCycle false", "/time set 6000", "/weather clear 1000000",
            "/gamerule doMobSpawning false", "/gamerule doFireTick false", "/kill @e[type=!Player]",
            String.format(Locale.ROOT, "/tp @p %.1f %.1f %.1f %.1f %.1f", x, y, z, yaw, pitch)
        };
        for (final String c : cmds) { chat(c); Thread.sleep(400); }
        final Object player = fPlayer.get(mc);
        Class<?> ent = Class.forName("pk", true, cl);
        final Field rY = ent.getField("y"), rP = ent.getField("z"), pY = ent.getField("A"), pP = ent.getField("B");

        // 6. let chunks load / JIT warm up
        int loadS = pi("loadSeconds", 30);
        note("settling for " + loadS + " s");
        Thread.sleep(loadS * 1000L);

        // 7. measured phases
        int staticS = pi("staticSeconds", 60), panS = pi("panSeconds", 40);
        GcSnap g0 = new GcSnap();
        MemPoller mem = new MemPoller(); mem.start();
        long staticStart = System.currentTimeMillis();
        FrameLog.start();
        Thread.sleep(staticS * 1000L);
        long[] fStatic = FrameLog.stop();
        long staticEnd = System.currentTimeMillis();
        GcSnap g1 = new GcSnap();

        final float yaw0 = yaw, pitch0 = pitch;
        final double degPerNs = 360.0 / (panS * 1e9);
        final long panT0 = System.nanoTime();
        FrameLog.perFrame = new Runnable() { public void run() {
            try {
                float a = (float) (yaw0 + (System.nanoTime() - panT0) * degPerNs);
                rY.setFloat(player, a); pY.setFloat(player, a);
                rP.setFloat(player, pitch0); pP.setFloat(player, pitch0);
            } catch (IllegalAccessException e) { throw new RuntimeException(e); }
        }};
        long panStart = System.currentTimeMillis();
        FrameLog.start();
        Thread.sleep(panS * 1000L);
        long[] fPan = FrameLog.stop();
        FrameLog.perFrame = null;
        long panEnd = System.currentTimeMillis();
        GcSnap g2 = new GcSnap();
        mem.stop = true;

        Map<String, String> extra = new LinkedHashMap<>();
        extra.put("startup_ms", String.valueOf(startupMs));
        extra.put("world_load_ms", String.valueOf(worldLoadMs));
        extra.put("phase_static_unix_ms", staticStart + "-" + staticEnd);
        extra.put("phase_pan_unix_ms", panStart + "-" + panEnd);
        extra.put("gc_static", g1.minus(g0));
        extra.put("gc_pan", g2.minus(g1));
        extra.put("heap_used_max_mb", String.valueOf(mem.maxUsed >> 20));
        extra.put("heap_used_avg_mb", String.valueOf(mem.samples == 0 ? 0 : (mem.sumUsed / mem.samples) >> 20));
        extra.put("heap_committed_mb", String.valueOf(Runtime.getRuntime().totalMemory() >> 20));
        extra.put("heap_max_mb", String.valueOf(Runtime.getRuntime().maxMemory() >> 20));
        extra.put("debug_string", debugString());
        writeResults(fStatic, fPan, extra, "ok");
        quit(0);
    }

    void chat(final String msg) throws Exception {
        final Object pl = fPlayer.get(mc);
        final Method send = pl.getClass().getMethod("e", String.class);
        onMain(new Runnable() { public void run() {
            try { send.invoke(pl, msg); } catch (Exception e) { note("chat failed: " + e); }
        }});
        note("cmd " + msg);
    }

    void onMain(Runnable r) throws Exception {
        mcCls.getMethod("a", Runnable.class).invoke(mc, r);
    }

    String debugString() {
        try {
            Field f = mcCls.getField("C"); // Minecraft.debug (String): "NN fps, NN chunk updates"
            Object v = f.get(mc);
            return v == null ? "" : v.toString();
        } catch (Throwable t) { return "n/a"; }
    }

    void quit(int code) {
        try {
            onMain(new Runnable() { public void run() {
                try { mcCls.getMethod("m").invoke(mc); } catch (Exception e) { note("shutdown failed " + e); }
            }});
        } catch (Throwable ignored) { }
        try { Thread.sleep(30000); } catch (InterruptedException ignored) { }
        Runtime.getRuntime().halt(code); // if the game did not exit by itself
    }

    // ------------------------------------------------------------------ output
    synchronized void writeResults(long[] fStatic, long[] fPan, Map<String, String> extra, String status) {
        String out = p("out", "mcos-bench-agent.txt");
        try (PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(out), StandardCharsets.UTF_8))) {
            w.println("agent_status=" + status);
            w.println("java=" + System.getProperty("java.vm.name") + " " + System.getProperty("java.runtime.version"));
            w.println("jvm_args=" + ManagementFactory.getRuntimeMXBean().getInputArguments());
            w.println("total_frames_since_start=" + FrameLog.totalFrames);
            if (extra != null) for (Map.Entry<String, String> e : extra.entrySet()) w.println(e.getKey() + "=" + e.getValue());
            if (fStatic != null) stats(w, "static", fStatic);
            if (fPan != null) stats(w, "pan", fPan);
            if (fStatic != null && fPan != null) {
                long[] all = new long[0];
                // combined numbers = frame-weighted over both phases
                stats(w, "all", concatDeltas(fStatic, fPan));
            }
            w.println("--- agent log ---");
            w.print(notes);
        } catch (IOException e) {
            System.err.println("[mcos-bench] cannot write " + out + ": " + e);
        }
        String raw = p("rawOut", "");
        if (!raw.isEmpty() && fStatic != null) {
            try (PrintWriter w = new PrintWriter(raw, "UTF-8")) {
                w.println("phase,frametime_ms");
                dumpRaw(w, "static", fStatic);
                if (fPan != null) dumpRaw(w, "pan", fPan);
            } catch (IOException ignored) { }
        }
    }

    static void dumpRaw(PrintWriter w, String ph, long[] t) {
        for (int i = 1; i < t.length; i++) w.printf(Locale.ROOT, "%s,%.3f%n", ph, (t[i] - t[i - 1]) / 1e6);
    }

    /** Returns a pseudo timestamp array whose deltas are those of a followed by those of b. */
    static long[] concatDeltas(long[] a, long[] b) {
        if (a.length < 2 || b.length < 2) return a;
        long[] r = new long[a.length + b.length - 1];
        System.arraycopy(a, 0, r, 0, a.length);
        long off = a[a.length - 1];
        for (int i = 1; i < b.length; i++) { off += b[i] - b[i - 1]; r[a.length + i - 1] = off; }
        return r;
    }

    static void stats(PrintWriter w, String ph, long[] t) {
        int n = t.length - 1;
        if (n < 10) { w.println(ph + "_frames=" + Math.max(n, 0)); return; }
        double[] d = new double[n];
        for (int i = 0; i < n; i++) d[i] = (t[i + 1] - t[i]) / 1e6;
        double durMs = (t[n] - t[0]) / 1e6;
        double[] s = d.clone();
        Arrays.sort(s);
        double median = s[n / 2];
        int k1 = Math.max(1, n / 100), k01 = Math.max(1, n / 1000);
        double worst1 = 0, worst01 = 0;
        for (int i = 0; i < k1; i++) worst1 += s[n - 1 - i];
        for (int i = 0; i < k01; i++) worst01 += s[n - 1 - i];
        worst1 /= k1; worst01 /= k01;
        int over50 = 0, over100 = 0, over2x = 0;
        double sumSq = 0, mean = durMs / n;
        for (double v : d) {
            if (v > 50) over50++;
            if (v > 100) over100++;
            if (v > 2 * median) over2x++;
            sumSq += (v - mean) * (v - mean);
        }
        w.printf(Locale.ROOT, "%s_frames=%d%n", ph, n);
        w.printf(Locale.ROOT, "%s_duration_s=%.2f%n", ph, durMs / 1000);
        w.printf(Locale.ROOT, "%s_avg_fps=%.2f%n", ph, n / (durMs / 1000));
        w.printf(Locale.ROOT, "%s_1pct_low_fps=%.2f%n", ph, 1000 / worst1);
        w.printf(Locale.ROOT, "%s_0.1pct_low_fps=%.2f%n", ph, 1000 / worst01);
        w.printf(Locale.ROOT, "%s_frametime_median_ms=%.2f%n", ph, median);
        w.printf(Locale.ROOT, "%s_frametime_p95_ms=%.2f%n", ph, s[(int) (n * 0.95)]);
        w.printf(Locale.ROOT, "%s_frametime_p99_ms=%.2f%n", ph, s[(int) (n * 0.99)]);
        w.printf(Locale.ROOT, "%s_frametime_max_ms=%.2f%n", ph, s[n - 1]);
        w.printf(Locale.ROOT, "%s_frametime_stddev_ms=%.2f%n", ph, Math.sqrt(sumSq / n));
        w.printf(Locale.ROOT, "%s_spikes_over_50ms=%d%n", ph, over50);
        w.printf(Locale.ROOT, "%s_spikes_over_100ms=%d%n", ph, over100);
        w.printf(Locale.ROOT, "%s_spikes_over_2x_median=%d%n", ph, over2x);
    }

    static final class GcSnap {
        final long count, timeMs;
        GcSnap() {
            long c = 0, t = 0;
            for (GarbageCollectorMXBean b : ManagementFactory.getGarbageCollectorMXBeans()) { c += Math.max(0, b.getCollectionCount()); t += Math.max(0, b.getCollectionTime()); }
            count = c; timeMs = t;
        }
        String minus(GcSnap o) { return (count - o.count) + " collections, " + (timeMs - o.timeMs) + " ms"; }
    }

    static final class MemPoller extends Thread {
        volatile boolean stop;
        long maxUsed, sumUsed, samples;
        MemPoller() { super("mcos-bench-mem"); setDaemon(true); }
        public void run() {
            Runtime r = Runtime.getRuntime();
            while (!stop) {
                long u = r.totalMemory() - r.freeMemory();
                maxUsed = Math.max(maxUsed, u); sumUsed += u; samples++;
                try { Thread.sleep(500); } catch (InterruptedException e) { return; }
            }
        }
    }
}
