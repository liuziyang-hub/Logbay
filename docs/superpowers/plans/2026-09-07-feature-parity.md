# Logbay 功能补齐实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按设计 `docs/superpowers/specs/2026-09-07-feature-parity-design.md` 分三批落地：上游稳定补丁 → Utilities/Terminal/搜索/选区 → iOS 镜像产品化（含无线 iOS）。

**Architecture:** 保持现有分层（tools → DeviceSessionRepository → DeviceSessionController → FeatureController → FeatureView）。上游代码以手工移植为主，保留 Logbay 中文与主题。iOS 无线复用 `DevicesRepository` 发现环 + `Pymobiledevice3Launcher`。

**Tech Stack:** Flutter/Dart（fvm/本地 flutter）、pymobiledevice3（主机）、现有 scrcpy / libimobiledevice 绑定。

---

## 批次 1 — 上游稳定补丁

### Task 1.1：对齐 AppZoom + 日志跳动修复

- [x] 对比 `upstream/main` 的 `lib/presentation/theme/app_zoom.dart`、`lib/features/logs/presentation/components/log_viewer.dart`、`log_controller.dart`、`home_page.dart`、`main.dart` 与本地差异
- [x] 合并 #61 滚动稳定逻辑（保留 Logbay 异常托盘/ostrace 改动）
- [x] 确认 zoom 应用到 header / rail / status bar；跑 `test/app_zoom_test.dart` 与相关 log 测试
- [x] `flutter analyze` 触及文件无新增 error

### Task 1.2：libimobiledevice 新语法

- [x] 对齐 `ideviceinstaller_tool.dart` 与 `bb75b4f` / upstream；更新测试 `ideviceinstaller_tool_test.dart`
- [x] 检查 `idevice_syslog_tool.dart` 是否需同步参数

### Task 1.3：日志过滤性能

- [x] 对比 `4ddebfe` / `1059fc5` 中 filter/search/buffer 改动并移植
- [x] 确认 `PreferencesService.defaultLogLinesLimit` 合理（≥100000）
- [x] 跑 `advanced_filter_test` / parser tests

---

## 批次 2 — Utilities / Terminal / 搜索 / 选区

### Task 2.1：Utilities

- [x] 从 `upstream/utilities-tools` 导出 `lib/features/utilities/**` + tests
- [x] 接入 `DeviceSessionController` / feature rail / quick access；中文标签
- [x] 命令执行走 `device_tool_runner`；至少重启探测 + battery/info 类命令可跑

### Task 2.2：Terminal 与 adb_shell 合并

- [x] 从 `upstream/feature/terminal` 导出 terminal 功能
- [x] UI 单一「终端」入口；Android 映射现有 shell 能力，避免双 pane
- [x] 基础 widget/controller 测试

### Task 2.3：命令面板模糊搜 + 选区增强

- [ ] 移植 global search / command palette fuzzy（本地无命令面板骨架，暂缓）
- [x] 移植 `feature/selection-enhancements` 到 log viewer 选区

---

## 批次 3 — iOS 镜像 + 无线

### Task 3.1：应用内 WebView 镜像

- [ ] 选型并接入 Windows WebView 插件；`MirrorController` iOS 路径嵌入 URL
- [ ] 失败回退系统浏览器；保留「在浏览器打开」按钮

### Task 3.2：截图 / 录屏 / 音频

- [ ] iOS 截图 API + UI（与 Android 入口对齐）
- [ ] 录屏 MVP（pmd3 stream 或明确降级）
- [ ] serve-web 音频默认开 + UI 开关

### Task 3.3：无线 iOS（优先 pymobiledevice3 官方路径）

参考：https://doronz88.github.io/pymobiledevice3/guides/ios17-tunnels/ 、`lockdown wifi-connections`、`usbmux list`

- [ ] Tool：封装 `lockdown wifi-connections on|off` + `usbmux list`（解析 ConnectionType USB/Network）
- [ ] `DevicesRepository`：合并 network iOS 进设备列表（标记无线）
- [ ] 无线面板 iOS 分段：步骤说明、一键开启 Wi‑Fi lockdown、刷新
- [ ] 镜像等走已有 serve-web `--userspace`；17.0–17.3.1 提示 tunneld
- [ ] MVP：拔 USB 后仍可发现并拉 syslog；失败文案可读
- [ ] 不捆绑 netmuxd（仅 Linux 文档备注）

---

## 执行约定

- **不** `git restore` 用户未提交改动；冲突手工合并。
- 每批结束：analyze + 相关 test +（可选）覆盖 `D:\Eagly\App`。
- 提交仅在用户明确要求时创建。

## 执行方式

- **Inline（推荐本次）**：本对话按 Task 顺序直接改。
- Subagent-Driven：大批次可并行探索，但合并成本高。
