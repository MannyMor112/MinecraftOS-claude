package mcos;

import java.io.*;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;
import java.util.*;

import jdk.internal.org.objectweb.asm.*;

/**
 * MinecraftOS benchmark agent for Minecraft 1.8.9 (vanilla or OptiFine).
 *
 *  -javaagent:/path/mcos-bench-agent.jar=/path/to/bench.properties
 *
 * 1. Inserts a call to FrameLog.frame() at the start of org.lwjgl.opengl.Display.update(),
 *    which Minecraft calls exactly once per rendered frame -> exact per-frame timestamps,
 *    independent of the GPU driver.
 * 2. Optionally overrides options.txt / optionsof.txt (backed up and restored afterwards).
 * 3. Starts Bench, which loads a fixed world, positions the camera, records, writes results, quits.
 *
 * Without a properties argument it only logs frame times (no automation) - useful for normal play.
 */
public final class Agent {
    static Instrumentation inst;
    static Properties cfg = new Properties();

    public static void premain(String args, Instrumentation instrumentation) {
        inst = instrumentation;
        try {
            if (args != null && !args.isEmpty()) {
                try (InputStream in = new FileInputStream(args)) { cfg.load(in); }
            }
        } catch (IOException e) {
            System.err.println("[mcos-bench] cannot read config " + args + ": " + e);
        }
        inst.addTransformer(new DisplayHook());
        if (Boolean.parseBoolean(cfg.getProperty("bench", "false"))) {
            Options.apply(cfg);
            Thread t = new Thread(new Bench(cfg), "mcos-bench");
            t.setDaemon(true);
            t.start();
        }
        System.out.println("[mcos-bench] agent loaded, bench=" + cfg.getProperty("bench", "false"));
    }

    /** Adds FrameLog.frame() at the top of Display.update() (both overloads). */
    static final class DisplayHook implements ClassFileTransformer {
        public byte[] transform(ClassLoader loader, String name, Class<?> cls, ProtectionDomain pd, byte[] bytes) {
            if (!"org/lwjgl/opengl/Display".equals(name)) return null;
            try {
                ClassReader cr = new ClassReader(bytes);
                ClassWriter cw = new ClassWriter(cr, 0);
                cr.accept(new ClassVisitor(Opcodes.ASM5, cw) {
                    @Override
                    public MethodVisitor visitMethod(int acc, String mname, String desc, String sig, String[] exc) {
                        MethodVisitor mv = super.visitMethod(acc, mname, desc, sig, exc);
                        // update(boolean processMessages) is the one doing the swap; update() delegates to it
                        if ("update".equals(mname) && "(Z)V".equals(desc)) {
                            return new MethodVisitor(Opcodes.ASM5, mv) {
                                @Override public void visitCode() {
                                    super.visitCode();
                                    super.visitMethodInsn(Opcodes.INVOKESTATIC, "mcos/FrameLog", "frame", "()V", false);
                                }
                            };
                        }
                        return mv;
                    }
                }, 0);
                System.out.println("[mcos-bench] hooked org.lwjgl.opengl.Display.update(Z)V");
                return cw.toByteArray();
            } catch (Throwable t) {
                System.err.println("[mcos-bench] failed to hook Display: " + t);
                FrameLog.hookError = String.valueOf(t);
                return null;
            }
        }
    }
}
