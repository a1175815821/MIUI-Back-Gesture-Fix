# MIUI 侧滑返回修复 (MIUI Back Gesture Fix)

一个 **LSPosed 模块**，修复 **HyperOS / MIUI 上「侧滑返回」手势失效** 的问题。

> **现象**：在 Chrome、Mihon 等 App 里从屏幕边缘侧滑，页面**完全不动**，返回不到上一层。
> 但按**返回键**正常，在「系统设置」里侧滑也正常。
> 文件/系统本身没坏 —— 是系统在**转发手势事件**时挂了。

[![Release](https://img.shields.io/badge/release-v1.1-blue)](https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

| 项 | 值 |
|---|---|
| 包名 | `io.github.a1175815821.miuibackfix` |
| 最新版本 | `1.1`（versionCode `2`） |
| 作用域 | `com.miui.home`（系统桌面） |
| 适用 | Android 14 上的 HyperOS / MIUI |
| LSPosed 仓库 | [Xposed-Modules-Repo/io.github.a1175815821.miuibackfix](https://github.com/Xposed-Modules-Repo/io.github.a1175815821.miuibackfix) |

---

## 问题原因

HyperOS / MIUI 的桌面（`com.miui.home`）在处理侧滑返回时，需要把系统的手势事件**转发**给当前 App。
转发前它要先构造一个 `android.window.BackMotionEvent`，反编译桌面 APK 可以看到：

```
android.window.BackMotionEventProvider.getInstance:(FFFFFILjava/lang/Object;)Ljava/lang/Object;
```

它**硬编码**使用了 **Android 15 才有的 8 参数构造函数**：

```
BackMotionEvent.<init>(float, float, float, float, float, boolean, int, RemoteAnimationTarget)
```

而 **Android 14 的框架只有 7 参数版本**（没有那个 `boolean isAnimationCallback`），于是必然失败：

```
ReflectUtils: java.lang.NoSuchMethodException: android.window.BackMotionEvent.<init> [...]
    at android.window.BackMotionEventProvider.getInstance(BackMotionEventProvider.java:30)
    at com.miui.home.recents.GestureStubView$OnBackInvokedCallbackImplU.onBackStart(GestureStubView.java:1522)
    at com.miui.home.recents.GestureStubView.onBackStart(GestureStubView.java:1446)
    at com.miui.home.recents.GestureStubView.onTouchEvent(GestureStubView.java:1026)
```

构造失败返回 `null`，但 MIUI 仍然把这个 `null` 传给了 App：

```
WindowOnBackDispatcher: onBackStarted error, backEvent is null
    at android.window.WindowOnBackInvokedDispatcher$OnBackInvokedCallbackWrapper.onBackStarted
```

App 收到空事件后**中止返回流程** —— 侧滑自然就没反应了。

### 为什么只有部分 App 中招

这条出错路径**只在 App 注册了「预测性返回动画回调」（`mIsAnimationCallback=true`）时才会走**：

| App | 支持预测性返回 | 侧滑返回 |
|---|:---:|:---:|
| Chrome | ✅ | ❌ 失效 |
| Mihon | ✅ | ❌ 失效 |
| 系统设置 | ❌ | ✅ 正常 |
| Via | ❌ | ✅ 正常 |

所以**所有支持 Android 预测性返回的 App 都会中招**（新版 App 越来越多），不只是浏览器。

---

## 原理

本模块注入 `com.miui.home` 进程，**hook 上面那个失败点**，改用框架里真实存在的构造函数来构造 `BackMotionEvent`，让 MIUI 的转发流程恢复正常：

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

实现细节：

- 会**枚举 `BackMotionEvent` 的全部构造函数**，挑一个参数能对上的来调用，因此**不依赖硬编码签名**；
- 在 Android 15+ 上，8 参数构造函数本来就存在、原逻辑不会失败，hook 不会干预；
- 另外兜底 hook 了 `com.miui.launcher.utils.ReflectUtils.createNewInstance`。

---

## 环境要求

- **Android 14**（Android 15+ 本身没有这个问题）
- 已安装 **LSPosed**（Zygisk 版）
- HyperOS / MIUI 系统

---

## 安装

1. 到 [**Releases**](https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases) 下载 `miuibackfix.apk` 并安装
2. 打开 **LSPosed** → 模块 → 启用「**MIUI 侧滑返回修复**」
3. 确认作用域勾选了 **系统桌面（`com.miui.home`）**
4. **重启手机**
5. 在 Chrome / Mihon 里侧滑试试 🎉

---

## 自行编译

**不需要 Gradle**，直接用 Android SDK 的 build-tools 离线打包：

```bash
bash build.sh
# 产物：build/miuibackfix.apk
```

依赖：**JDK 17** + **Android SDK**（`build-tools` 与 `platforms/android-34`）。
首次使用请按你的环境修改 `build.sh` 顶部的 `SDK` 与 `JAVA_HOME_WIN` 路径。

> ⚠️ 两个容易踩的坑：
> 1. `d8` / `aapt2` / `apksigner` 是 Windows 程序，**必须传 `C:/` 形式的路径**；
> 2. 构建目录**不能带空格**（`$(find ...)` 展开会被空格打断）。

`lib/api82.jar` 是编译所需的 Xposed API（来源：`de.robv.android.xposed:api:82`）。

### 关于签名

构建脚本使用**固定密钥** `keystore/miuibackfix.jks`（首次构建时自动生成，密码见脚本内 `KS_PASS`）。

- 该文件**没有**提交到仓库（见 `.gitignore`）—— 它是本项目的发布签名密钥，泄露后他人就能伪造同包名的「更新」。
- **请务必备份它。** 一旦丢失，后续版本无法覆盖升级，所有用户只能先卸载再装新版。
- 如果你是 fork 后自行构建，用你自己的密钥即可，但**不能**用于给本项目的用户推送更新。

---

## 日志

模块会在 LSPosed 日志（`/data/adb/lspd/log/`）里输出：

```
(com.miui.home)[io.github.a1175815821.miuibackfix] [MiuiBackFix] built BackMotionEvent via 7-arg ctor
(com.miui.home)[io.github.a1175815821.miuibackfix] [MiuiBackFix] getInstance -> fixed
```

觉得刷屏的话，把 `BackFix.java` 里的 `log(...)` 调用注释掉，重新 `bash build.sh` 即可。

---

## 已验证环境

| 项 | 值 |
|---|---|
| 机型 | Redmi K50G（`22041216UC` / `xagapro`） |
| 系统 | HyperOS 2.0 `OS2.0.12.0.ULOCNXM` |
| Android | 14 |
| LSPosed | Zygisk 版 |

如果你在别的 HyperOS / MIUI 版本上验证成功（或失败），欢迎开 Issue 反馈。

---

## 免责声明

本项目仅供学习与技术研究使用。修改系统行为有一定风险，请自行评估并**做好备份**。

## License

[MIT](LICENSE)
