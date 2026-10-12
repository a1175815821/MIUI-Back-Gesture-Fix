package com.wbai.miuibackfix;

import java.lang.reflect.Constructor;
import java.util.ArrayList;
import java.util.List;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * 修复 HyperOS / MIUI 桌面侧滑返回失效。
 *
 * 原因：MIUI 桌面 (com.miui.home) 的
 *   android.window.BackMotionEventProvider.getInstance(FFFFFILjava/lang/Object;)
 * 硬编码用「Android 15 的 8 参数构造函数」去反射创建 android.window.BackMotionEvent，
 * 而 Android 14 的框架只有 7 参数版本 → NoSuchMethodException → 返回 null →
 * 桌面把 null 传给 App 的 onBackStarted() → App 端 WindowOnBackInvokedDispatcher 报
 * "backEvent is null" 并中止返回手势。
 *
 * 修复：在本进程内 hook 上述入口，改用框架里真实存在的构造函数来构造 BackMotionEvent。
 */
public class BackFix implements IXposedHookLoadPackage {

    private static final String TAG = "[MiuiBackFix] ";
    private static final String TARGET_PKG = "com.miui.home";
    private static final String CLS_BME = "android.window.BackMotionEvent";

    private static void log(String s) {
        XposedBridge.log(TAG + s);
    }

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) throws Throwable {
        if (!TARGET_PKG.equals(lpparam.packageName)) return;
        final ClassLoader cl = lpparam.classLoader;
        log("loaded in " + lpparam.packageName);

        // 先打印一下 BackMotionEvent 到底有哪些构造函数，方便诊断
        try {
            Class<?> bme = XposedHelpers.findClassIfExists(CLS_BME, cl);
            if (bme != null) {
                for (Constructor<?> c : bme.getDeclaredConstructors()) {
                    StringBuilder sb = new StringBuilder("ctor(");
                    Class<?>[] pt = c.getParameterTypes();
                    for (int i = 0; i < pt.length; i++) {
                        if (i > 0) sb.append(", ");
                        sb.append(pt[i].getSimpleName());
                    }
                    log(sb.append(")").toString());
                }
            } else {
                log("BackMotionEvent NOT FOUND");
            }
        } catch (Throwable t) {
            log("dump ctor err: " + t);
        }

        // Hook 1（主）：BackMotionEventProvider.getInstance(float,float,float,float,float,int,Object)
        try {
            Class<?> provider = XposedHelpers.findClassIfExists("android.window.BackMotionEventProvider", cl);
            if (provider != null) {
                XposedBridge.hookAllMethods(provider, "getInstance", new XC_MethodHook() {
                    @Override
                    protected void beforeHookedMethod(MethodHookParam param) {
                        Object ev = buildFromProviderArgs(param.args, cl);
                        if (ev != null) {
                            param.setResult(ev);
                            log("getInstance -> fixed");
                        }
                    }
                });
                log("hooked BackMotionEventProvider.getInstance");
            } else {
                log("BackMotionEventProvider NOT found");
            }
        } catch (Throwable t) {
            log("hook provider err: " + t);
        }

        // Hook 2（兜底）：com.miui.launcher.utils.ReflectUtils.createNewInstance(...)
        try {
            Class<?> ru = XposedHelpers.findClassIfExists("com.miui.launcher.utils.ReflectUtils", cl);
            if (ru != null) {
                XposedBridge.hookAllMethods(ru, "createNewInstance", new XC_MethodHook() {
                    @Override
                    protected void afterHookedMethod(MethodHookParam param) {
                        if (!param.hasThrowable()) return;
                        Object ev = buildFromReflectArgs(param.args, cl);
                        if (ev != null) {
                            param.setThrowable(null);
                            param.setResult(ev);
                            log("createNewInstance -> fixed");
                        }
                    }
                });
                log("hooked ReflectUtils.createNewInstance");
            } else {
                log("ReflectUtils NOT found");
            }
        } catch (Throwable t) {
            log("hook ReflectUtils err: " + t);
        }
    }

    /* ---------- 构造 BackMotionEvent ---------- */

    private static Object buildFromProviderArgs(Object[] args, ClassLoader cl) {
        try {
            Class<?> bme = XposedHelpers.findClassIfExists(CLS_BME, cl);
            if (bme == null) return null;
            List<Object> vals = flatten(args);
            Object ev = build(bme, vals);
            if (ev == null) ev = build(bme, dropBooleans(vals));
            return ev;
        } catch (Throwable t) {
            log("buildFromProviderArgs err: " + t);
            return null;
        }
    }

    private static Object buildFromReflectArgs(Object[] args, ClassLoader cl) {
        try {
            Class<?> target = null;
            List<Object> vals = new ArrayList<Object>();
            for (Object a : args) {
                if (a instanceof Class) {
                    if (target == null) target = (Class<?>) a;
                    continue;
                }
                if (a instanceof Class[]) continue;
                if (a instanceof Object[]) {
                    for (Object x : (Object[]) a) vals.add(x);
                    continue;
                }
                vals.add(a);
            }
            if (target == null || !CLS_BME.equals(target.getName())) return null;
            Object ev = build(target, vals);
            if (ev == null) ev = build(target, dropBooleans(vals));
            return ev;
        } catch (Throwable t) {
            log("buildFromReflectArgs err: " + t);
            return null;
        }
    }

    private static List<Object> flatten(Object[] args) {
        List<Object> vals = new ArrayList<Object>();
        for (Object a : args) {
            if (a instanceof Class) continue;
            if (a instanceof Class[]) continue;
            if (a instanceof Object[]) {
                for (Object x : (Object[]) a) vals.add(x);
                continue;
            }
            vals.add(a);
        }
        return vals;
    }

    private static List<Object> dropBooleans(List<Object> in) {
        List<Object> out = new ArrayList<Object>();
        for (Object o : in) {
            if (o instanceof Boolean) continue;
            out.add(o);
        }
        return out;
    }

    private static Object build(Class<?> bme, List<Object> vals) {
        for (Constructor<?> c : bme.getDeclaredConstructors()) {
            Class<?>[] pt = c.getParameterTypes();
            if (pt.length != vals.size()) continue;
            boolean ok = true;
            for (int i = 0; i < pt.length; i++) {
                if (!compatible(pt[i], vals.get(i))) { ok = false; break; }
            }
            if (!ok) continue;
            try {
                c.setAccessible(true);
                Object o = c.newInstance(vals.toArray());
                log("built BackMotionEvent via " + pt.length + "-arg ctor");
                return o;
            } catch (Throwable t) {
                log("ctor(" + pt.length + ") invoke failed: " + t);
            }
        }
        return null;
    }

    private static boolean compatible(Class<?> p, Object v) {
        if (v == null) return !p.isPrimitive();
        if (p == float.class || p == Float.class) return v instanceof Float;
        if (p == int.class || p == Integer.class) return v instanceof Integer;
        if (p == boolean.class || p == Boolean.class) return v instanceof Boolean;
        if (p == long.class || p == Long.class) return v instanceof Long;
        if (p == double.class || p == Double.class) return v instanceof Double;
        return p.isInstance(v);
    }
}
