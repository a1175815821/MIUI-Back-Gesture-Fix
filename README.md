# MIUI 侧滑返回修复

**侧滑返回坏了？装这个就好了。**

一个 LSPosed 模块，修复 **HyperOS / MIUI 上「从屏幕边缘侧滑」完全没反应** 的问题 —— Chrome、Mihon 等一大批 App 都中招，但返回键又是好的。

[![Release](https://img.shields.io/badge/release-1.1-blue?style=flat-square)](https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Android](https://img.shields.io/badge/Android-14-3ddc84?style=flat-square&logo=android&logoColor=white)](#兼容性)
[![LSPosed](https://img.shields.io/badge/requires-LSPosed-orange?style=flat-square)](https://github.com/LSPosed/LSPosed)

> 只适用于 **Android 14** 的 HyperOS / MIUI。Android 15 及以上系统没有这个 bug，不用装。

---

## 1️⃣ 先花 30 秒确认你要不要装

三条都符合，那就是它：

- [ ] 系统是 **HyperOS / MIUI**，且版本为 **Android 14**
- [ ] 侧滑返回**没反应**，但按**返回键正常**
- [ ] 出问题的是 **Chrome、Mihon** 这类较新的 App；在「系统设置」里侧滑是好的

如果**所有 App** 侧滑都不行，那不是这个问题 —— 先去检查系统的全面屏手势设置。

---

## 2️⃣ 安装（3 步，1 分钟）

| 步骤 | 做什么 |
|---|---|
| **1** | 到 [**Releases**](https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases/latest) 下载 `miuibackfix.apk` 并安装 |
| **2** | 打开 **LSPosed** → 模块 → 启用「**MIUI 侧滑返回修复**」→ 确认作用域勾选了 **系统桌面 `com.miui.home`** |
| **3** | **重启手机** |

重启后随便找个 App 侧滑一下，成了 🎉

> 也可以从 **LSPosed 官方仓库** 安装：仓库收录后，在 LSPosed 的「仓库」页搜「**侧滑返回**」即可。

---

## 3️⃣ 装完还是不行？

按顺序排查：

1. **作用域勾对了吗** —— 必须勾 **系统桌面（`com.miui.home`）**，勾成浏览器是没用的。
2. **重启了吗** —— 桌面进程常驻，不重启不会重新加载模块。
3. **模块真的生效了吗** —— 看 LSPosed 日志（`/data/adb/lspd/log/`），应该出现：
   ```
   (com.miui.home)[io.github.a1175815821.miuibackfix] [MiuiBackFix] built BackMotionEvent via 7-arg ctor
   (com.miui.home)[io.github.a1175815821.miuibackfix] [MiuiBackFix] getInstance -> fixed
   ```
   没这两行 → 模块没被加载（作用域 / 重启问题）。
   有这两行但还是不行 → 说明是别的原因，欢迎开 Issue 带上机型 + ROM 版本。

---

## 为什么只有部分 App 中招

这条出错路径**只在 App 注册了「预测性返回动画回调」（`mIsAnimationCallback=true`）时才会走**：

| App | 支持预测性返回 | 侧滑返回 |
|---|:---:|:---:|
| Chrome | ✅ | ❌ 失效 |
| Mihon | ✅ | ❌ 失效 |
| 系统设置 | ❌ | ✅ 正常 |
| Via | ❌ | ✅ 正常 |

判据只有一条：**App 有没有注册「预测性返回动画回调」**。注册了就中招，没注册就正常。

所以受影响的不只是浏览器 —— **所有支持 Android 预测性返回的 App 都会坏**，而且新版 App 越来越多，你会陆续在别的地方也遇到。

---

## 常见问题

<details>
<summary><b>会不会有副作用？会不会更耗电？</b></summary>

模块只改了 `BackMotionEventProvider.getInstance` 这一个入口，每次侧滑多几次对象构造，开销可以忽略，也不会常驻后台。

在 **Android 15+** 上，8 参数构造函数本来就存在、原逻辑不会失败，hook 直接放行，等于不生效。
</details>

<details>
<summary><b>为什么不用 Shizuku / 无障碍 / 换桌面？</b></summary>

- 换桌面：**没用**。我对比过系统自带桌面（5.39.31）和侧载更新版（5.39.35），两版这段代码完全一样，是 ROM 自身的问题。
- 改「预测性返回手势动画」开关：**也没用**。那个开关只管动画播不播，转发代码照跑，照样失败。
- 停用 Xposed 模块：实测无效，不是模块冲突。
- 用 Shizuku / 无障碍：改不了桌面进程内部的这段反射逻辑。

只有 hook 那个失败点才能修好。
</details>

<details>
<summary><b>会和 HyperCeiler 等模块冲突吗？</b></summary>

本模块只 hook 一个方法，并且用 `beforeHookedMethod` 设结果，不修改原方法的其他行为。实测与 HyperCeiler、搞机助手等共存正常。如果真遇到冲突，把日志发到 Issue。
</details>

<details>
<summary><b>从 1.0 升级到 1.1 要注意什么？</b></summary>

包名变了（`com.wbai.miuibackfix` → `io.github.a1175815821.miuibackfix`），等于换了一个 App：

**先卸载旧版**，再装新版，然后重新在 LSPosed 里启用 + 勾作用域 + 重启。
</details>

---

## 技术细节

### 一图看懂

<img src="docs/why.svg" alt="修复前后对比：桌面用 Android 15 的构造函数反射失败返回 null，App 收到空事件后中止返回；模块改用真实存在的构造函数后恢复正常" width="900">

### 问题原因

桌面（`com.miui.home`）在把系统手势**转发**给当前 App 之前，要先构造一个 `android.window.BackMotionEvent`。反编译桌面 APK 可以看到：

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

### 修复原理

注入 `com.miui.home` 进程，**hook 上面那个失败点**，改用框架里真实存在的构造函数来构造 `BackMotionEvent`，让转发流程恢复正常：

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

实现要点：

- **枚举 `BackMotionEvent` 的全部构造函数**，挑参数能对上的来调用，因此**不依赖硬编码签名**；
- 在 Android 15+ 上，8 参数构造函数本来就存在、原逻辑不会失败，hook 不会干预；
- 另有兜底 hook：`com.miui.launcher.utils.ReflectUtils.createNewInstance`。

---

## 兼容性

**已验证：**

| 机型 | 系统 | Android | 结果 |
|---|---|---|---|
| Redmi K50G（`22041216UC` / `xagapro`） | HyperOS 2.0 `OS2.0.12.0.ULOCNXM` | 14 | ✅ |

在别的 HyperOS / MIUI 版本上验证成功或失败，都欢迎开 Issue 反馈 —— 我会把结果补到这张表里。

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

## 项目信息

| 项 | 值 |
|---|---|
| 包名 | `io.github.a1175815821.miuibackfix` |
| 最新版本 | `1.1`（versionCode `2`） |
| 作用域 | `com.miui.home`（系统桌面） |
| 适用 | Android 14 上的 HyperOS / MIUI |
| LSPosed 仓库 | [Xposed-Modules-Repo/io.github.a1175815821.miuibackfix](https://github.com/Xposed-Modules-Repo/io.github.a1175815821.miuibackfix) |

---

## 免责声明

本项目仅供学习与技术研究使用。修改系统行为有一定风险，请自行评估并**做好备份**。

## License

[MIT](LICENSE)

---

<div align="center">

**如果它修好了你的手机，点个 ⭐ 吧**

这能让下一个遇到同样问题的人更容易找到它。

</div>
