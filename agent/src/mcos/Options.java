package mcos;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/**
 * Applies fixed benchmark settings to options.txt (vanilla) and optionsof.txt (OptiFine)
 * before Minecraft reads them. Originals are backed up and restored when the JVM exits.
 * Property keys: opt.<key>=value   -> options.txt
 *                of.<key>=value    -> optionsof.txt
 */
final class Options {
    static void apply(Properties cfg) {
        File gameDir = gameDir();
        Bench.note("gameDir=" + gameDir);
        edit(new File(gameDir, "options.txt"), cfg, "opt.");
        edit(new File(gameDir, "optionsof.txt"), cfg, "of.");
    }

    /** --gameDir from the command line, else the working directory. */
    static File gameDir() {
        String cmd = System.getProperty("sun.java.command", "");
        String[] a = cmd.split(" ");
        for (int i = 0; i < a.length - 1; i++) if (a[i].equals("--gameDir")) return new File(a[i + 1]);
        return new File(System.getProperty("user.dir"));
    }

    static void edit(final File f, Properties cfg, String prefix) {
        Map<String, String> over = new LinkedHashMap<>();
        for (String k : cfg.stringPropertyNames()) if (k.startsWith(prefix)) over.put(k.substring(prefix.length()), cfg.getProperty(k));
        if (over.isEmpty()) return;
        try {
            final Path p = f.toPath();
            final Path bak = Paths.get(f.getPath() + ".mcos-backup");
            final boolean existed = Files.exists(p);
            List<String> lines = existed ? Files.readAllLines(p, StandardCharsets.UTF_8) : new ArrayList<String>();
            if (existed) Files.copy(p, bak, StandardCopyOption.REPLACE_EXISTING);
            List<String> out = new ArrayList<>();
            Set<String> done = new HashSet<>();
            for (String l : lines) {
                int c = l.indexOf(':');
                String k = c > 0 ? l.substring(0, c) : null;
                if (k != null && over.containsKey(k)) { out.add(k + ":" + over.get(k)); done.add(k); }
                else out.add(l);
            }
            for (Map.Entry<String, String> e : over.entrySet()) if (!done.contains(e.getKey())) out.add(e.getKey() + ":" + e.getValue());
            Files.createDirectories(p.getParent());
            Files.write(p, out, StandardCharsets.UTF_8);
            if (Boolean.parseBoolean(cfg.getProperty("restoreOptions", "true"))) {
                Runtime.getRuntime().addShutdownHook(new Thread() {
                    public void run() {
                        try {
                            if (existed) Files.move(bak, p, StandardCopyOption.REPLACE_EXISTING);
                            else Files.deleteIfExists(p);
                        } catch (IOException ignored) { }
                    }
                });
            }
        } catch (IOException e) {
            Bench.note("options edit failed for " + f + ": " + e);
        }
    }
}
