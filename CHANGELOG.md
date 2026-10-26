# Changelog

本项目所有值得注意的改动都会记录在这里。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.1] - 2026-10-26

### 变更（破坏性）
- **包名由 `com.wbai.miuibackfix` 改为 `io.github.a1175815821.miuibackfix`**
  - 原因：LSPosed 官方模块仓库要求应用 ID 使用**自己拥有的域名**，或使用 `io.github.{用户名}` 前缀。
    原包名 `com.wbai.*` 无法验证域名归属，提交会被拒。
  - ⚠️ 包名变了等于换了一个 App：**需要先卸载旧版（`com.wbai.miuibackfix`）**，再安装新版，
    然后在 LSPosed 里重新启用并勾选作用域 `com.miui.home`，最后重启手机。
  - 功能代码本身**没有任何改动**。

### 构建
- 构建脚本改用**固定签名密钥** `keystore/miuibackfix.jks`（不再每次构建重新生成）
  - 此前每次构建都会新建密钥，导致版本之间无法覆盖升级
  - 该密钥不纳入版本控制，**请自行备份**

### 兼容性
- Android 15+ 无此问题，模块不会产生副作用（原逻辑会正常通过）

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

[1.1]: https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases/tag/2-1.1
[1.0]: https://github.com/a1175815821/MIUI-Back-Gesture-Fix/releases/tag/v1.0
