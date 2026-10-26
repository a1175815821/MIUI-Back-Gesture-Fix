# MIUI Back Gesture Fix

An **LSPosed module** that fixes the broken **edge-swipe-to-go-back gesture** on **HyperOS / MIUI**.

> **Symptom:** In apps like Chrome or Mihon, swiping from the screen edge does **nothing** — you can't go back.
> The hardware/software back key works fine, and the gesture works in system Settings.
> Nothing is broken on disk — the system just fails while **forwarding the gesture event** to the app.

[![Release](https://img.shields.io/badge/release-v1.1-blue)](https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

| Field | Value |
|---|---|
| Package | `io.github.a1175815821.miuibackfix` |
| Latest | `1.1` (versionCode `2`) |
| Scope | `com.miui.home` (system launcher) |
| Target | HyperOS / MIUI on Android 14 |

---

## Root cause

The HyperOS / MIUI launcher (`com.miui.home`) forwards the back-gesture event to the foreground app.
Before forwarding, it builds an `android.window.BackMotionEvent`. Decompiling the launcher APK shows:

```
android.window.BackMotionEventProvider.getInstance:(FFFFFILjava/lang/Object;)Ljava/lang/Object;
```

It **hardcodes the 8-argument constructor that only exists on Android 15**:

```
BackMotionEvent.<init>(float, float, float, float, float, boolean, int, RemoteAnimationTarget)
```

but **Android 14's framework only has the 7-argument version** (no `boolean isAnimationCallback`).
So the reflective lookup always fails:

```
ReflectUtils: java.lang.NoSuchMethodException: android.window.BackMotionEvent.<init> [...]
    at android.window.BackMotionEventProvider.getInstance(BackMotionEventProvider.java:30)
    at com.miui.home.recents.GestureStubView$OnBackInvokedCallbackImplU.onBackStart(GestureStubView.java:1522)
    at com.miui.home.recents.GestureStubView.onBackStart(GestureStubView.java:1446)
```

It returns `null`, yet MIUI still passes that `null` to the app:

```
WindowOnBackDispatcher: onBackStarted error, backEvent is null
    at android.window.WindowOnBackInvokedDispatcher$OnBackInvokedCallbackWrapper.onBackStarted
```

The app aborts the back navigation — so the swipe does nothing.

### Why only some apps are affected

This code path is only taken for apps that register a **predictive-back animation callback**
(`mIsAnimationCallback=true`):

| App | Predictive back | Edge-swipe back |
|---|:---:|:---:|
| Chrome | ✅ | ❌ broken |
| Mihon | ✅ | ❌ broken |
| Settings | ❌ | ✅ works |
| Via | ❌ | ✅ works |

In other words, **every app that supports Android's predictive back gesture is affected**.

---

## How it works

The module is injected into the `com.miui.home` process and hooks the failing entry point,
rebuilding the `BackMotionEvent` with a constructor that actually exists:

```java
XposedBridge.hookAllMethods(
        XposedHelpers.findClass("android.window.BackMotionEventProvider", cl),
        "getInstance",
        new XC_MethodHook() {
            @Override
            protected void beforeHookedMethod(MethodHookParam param) {
                Object ev = buildBackMotionEvent(param.args, cl);
                if (ev != null) param.setResult(ev);
            }
        });
```

Details:

- It **enumerates all declared constructors** of `BackMotionEvent` and picks one whose parameters
  match, so it does **not** depend on any hardcoded signature.
- On Android 15+, the 8-arg constructor exists and the original logic succeeds — the hook stays out of the way.
- A fallback hook on `com.miui.launcher.utils.ReflectUtils.createNewInstance` is also installed.

---

## Requirements

- **Android 14** (Android 15+ does not have this bug)
- **LSPosed** (Zygisk) installed
- HyperOS / MIUI

---

## Installation

1. Download `miuibackfix.apk` from [**Releases**](https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases) and install it
2. Open **LSPosed** → Modules → enable **MIUI Back Gesture Fix**
3. Make sure the scope includes **System launcher (`com.miui.home`)**
4. **Reboot**
5. Try swiping back in Chrome / Mihon 🎉

---

## Building from source

**No Gradle required** — it builds offline with the Android SDK build-tools:

```bash
bash build.sh
# output: build/miuibackfix.apk
```

Requirements: **JDK 17** + **Android SDK** (`build-tools`, `platforms/android-34`).
Adjust `SDK` and `JAVA_HOME_WIN` at the top of `build.sh` for your environment.

> ⚠️ Two gotchas:
> 1. `d8` / `aapt2` / `apksigner` are Windows binaries — pass them **`C:/`-style paths**;
> 2. The build directory **must not contain spaces** (the `$(find ...)` expansion breaks otherwise).

`lib/api82.jar` is the Xposed API needed for compilation (`de.robv.android.xposed:api:82`).

---

## Logging

The module logs to the LSPosed log (`/data/adb/lspd/log/`):

```
(com.miui.home)[io.github.a1175815821.miuibackfix] [MiuiBackFix] built BackMotionEvent via 7-arg ctor
(com.miui.home)[io.github.a1175815821.miuibackfix] [MiuiBackFix] getInstance -> fixed
```

If it's too noisy, comment out the `log(...)` calls in `BackFix.java` and rebuild.

---

## Verified on

| | |
|---|---|
| Device | Redmi K50G (`22041216UC` / `xagapro`) |
| ROM | HyperOS 2.0 `OS2.0.12.0.ULOCNXM` |
| Android | 14 |
| LSPosed | Zygisk |

If you confirm it on another HyperOS / MIUI build (working or not), feel free to open an issue.

---

## Disclaimer

This project is for learning and research purposes only. Modifying system behaviour carries risk —
evaluate it yourself and **keep a backup**.

## License

[MIT](LICENSE)
