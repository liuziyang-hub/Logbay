# Logbay 更新日志

## 1.4.0 — 2026-09-08

本版本对齐上游稳定补丁，并补齐工具 / 终端 / iOS 镜像与无线调试等能力。

### 新增
- **工具面板**：常用设备命令 GUI（电源、信息、屏幕输入、应用权限等），支持中文检索与结果输出
- **终端**：统一「终端」入口（adb / idevice 命令与内置 help、devices、use 等）
- **iOS 屏幕镜像**：基于 pymobiledevice3 `serve-web`（浏览器 HEVC）；支持静音开关、打开/复制镜像地址
- **iOS 无线调试**：无线连接对话框新增 iOS 页（开启无线调试、刷新发现、无线/有线标记）
- **iOS 截图**：主页与镜像条可截图保存
- **日志异常托盘**：崩溃 / ANR / 原生崩溃检测与跳转
- **iOS ostrace**：支持 subsystem / category 列

### 改进
- 日志列表跳动修复、界面缩放（App Zoom）与过滤性能
- ideviceinstaller 兼容新版 libimobiledevice 命令语法
- Android 镜像剪贴板同步 / 粘贴（延续既有能力）
- 面向用户的中文文案打磨（减少 CLI 黑话外露）
- 安装包体积优化相关构建配置（延续 1.2.x 瘦身策略）

### 说明与依赖
- iOS 镜像 / 无线调试需主机安装 **pymobiledevice3**；Windows 需 **Apple 设备 / iTunes** 驱动栈
- iOS 镜像建议 **17.4+** 并开启开发者模式；画面暂在系统浏览器中播放
- 应用内更新资源名：`Logbay-1.4.0-windows-setup.exe`

### 已知限制
- iOS 镜像尚未嵌入应用内 WebView
- iOS 录屏尚未提供与 Android 对等的一键落盘
- 命令面板全局模糊搜索暂未接入
