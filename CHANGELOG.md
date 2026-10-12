# Changelog

本项目所有值得注意的改动都会记录在这里。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0] - 2026-10-12

首个版本。

### 修复
- 修复 HyperOS / MIUI 上**侧滑返回手势失效**的问题（Chrome、Mihon 等支持预测性返回的 App 均受影响）
  - 主 hook：`android.window.BackMotionEventProvider.getInstance(FFFFFILjava/lang/Object;)`
    —— 改用框架里真实存在的构造函数构造 `BackMotionEvent`，不再因 Android 15 专属签名反射失败而返回 `null`
  - 兜底 hook：`com.miui.launcher.utils.ReflectUtils.createNewInstance`

### 说明
- 构造函数通过**枚举 + 参数匹配**选取，不硬编码签名；Android 15+ 上会自动让原逻辑通过
- 作用域：`com.miui.home`（系统桌面）

### 已验证
- Redmi K50G（`22041216UC`）/ HyperOS 2.0 `OS2.0.12.0.ULOCNXM` / Android 14 / LSPosed (Zygisk)

[1.0]: https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases/tag/v1.0
