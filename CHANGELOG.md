# Logbay 更新日志

## Unreleased

## 1.5.0 — 2026-09-18

本版本新增跨平台性能分析工作区，并进一步提升 iOS 实时投屏与开发者服务的稳定性。

### 新增
- **跨平台性能分析**：Android 与 iOS 均可按应用查看 FPS、帧耗时、CPU、内存、网络和温度；设备未提供的指标会显示原因，不再以 0 伪装有效数据
- **区间统计**：实时汇总平均 FPS、P95 帧耗时、CPU/内存峰值与低帧持续时间
- **性能数据导出**：支持导出带版本信息的 JSON 会话和便于 Excel/脚本处理的 CSV 数据
- **Android Perfetto**：可在性能页面一键开始录制并保存 `.perfetto-trace`，录制使用 Google 官方 Perfetto 配置与 Trace Processor
- **iOS DVT 指标**：接入 pymobiledevice3 官方 Sysmontap、Graphics 与电池诊断通道，支持应用 Bundle ID 自动解析进程 PID

### 改进
- iOS 镜像与性能命令统一通过运行时 Broker 管理；命令超时后会终止残留子进程，同设备的一次性 DVT 命令按序执行
- 安装包优先使用固定版本的轻量 `uv` 引导器管理 pymobiledevice3 11.15.4，开发环境仍可回退到主机安装版本
- iOS 投屏继续复用上游 `serve-web`，保留内嵌 WebView2、系统浏览器与截图降级路径
- 修正 iOS `sysmon system` 键值行解析，补齐 `CoreAnimationFramesPerSecond` 和电池温度字段
- 新增第三方组件声明、运行时清单、SHA-256 校验及官方来源下载脚本

### 兼容性与说明
- iOS 17+ 的 DVT 与实时投屏需要开启开发者模式、信任此电脑并准备 Developer Disk Image；首次使用托管运行时需要联网完成上游组件初始化
- iOS 网络数据来自系统级 Sysmontap 计数器，界面按估算来源标记；逐帧耗时不可用时由实时 FPS 推算平均帧间隔
- 安装程序沿用固定 AppId，可直接覆盖旧版安装，不会生成第二套程序目录

## 1.4.1 — 2026-09-18

本版本重点提升 iOS 镜像的兼容性、错误诊断和 Windows 稳定性。

### 新增
- **iOS 镜像内嵌**：Windows 可在镜像面板内通过 WebView2 显示 `serve-web` 画面，同时保留系统浏览器备用入口
- **开发者镜像自动准备**：启动 iOS 镜像前自动检查并挂载 DDI，必要时尝试 Cryptex 安装
- **镜像兼容性预检**：在打开播放页前检查 iOS 和 pymobiledevice3 版本，避免直接显示 HTTP 500 黑屏

### 改进
- pymobiledevice3 建议版本升级至 `11.15.4`，并兼容 `uv tool` 的 Windows 安装路径
- 对 iOS 27 系统限制、摄像头/麦克风占用和服务启动失败提供专业中文提示
- 无线 iOS 设备发现与单元测试完全隔离，避免真机干扰自动化测试
- 清理未使用的原始视频和临时文件，并完善 Git 忽略规则

### 测试
- Windows 全量测试 350 项通过；5 项 POSIX 脚本夹具在 Windows 上按设计跳过
- Windows x64 Release 构建通过

### 已知限制
- iOS 实时远程控制受 Apple 系统版本限制；iOS 27 以下设备会显示兼容性说明，可继续使用截图等功能
- iOS 镜像需要主机安装 pymobiledevice3，Windows 还需 Apple 设备驱动服务

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
- iOS 镜像建议 **17.4+** 并开启开发者模式；Windows 优先在应用内播放，也可打开系统浏览器
- 应用内更新资源名：`Logbay-1.4.0-windows-setup.exe`

### 已知限制
- iOS 录屏尚未提供与 Android 对等的一键落盘
- 命令面板全局模糊搜索暂未接入
