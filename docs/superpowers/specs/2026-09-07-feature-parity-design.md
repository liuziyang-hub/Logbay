# Logbay 功能补齐设计（分批 A）

日期：2026-09-07（修订：纳入无线 iOS；优先采用公开开源方案）  
范围：对齐上游 Eagly 稳定补丁 + WIP 能力，并强化 iOS 镜像差异化与无线 iOS。  
明确不做：多机群控、键位映射；不承诺「从未插线」的纯零接触无线配对。

## 开源方案选型（优先 GitHub / 线上）

原则：**能复用成熟开源协议栈就封装，不自研协议。**

| 能力 | 首选开源方案 | 仓库 / 文档 | Logbay 接法 |
|------|--------------|-------------|--------------|
| 批次 1 补丁 / Utilities / Terminal / 选区 | 上游 Eagly | [ShreyashKore/eagly](https://github.com/ShreyashKore/eagly)（`main` + `utilities-tools` / `feature/terminal` / `feature/selection-enhancements`） | 手工移植，保留中文与主题 |
| Android 投屏控制 | scrcpy（已集成） | Genymobile/scrcpy | 保持现有 `flutter_scrcpy` |
| Android 工具命令参考（可选对照） | adb_kit / ADB Vision | [sbrsubuvga/ADB](https://github.com/sbrsubuvga/ADB)、[pub.dev/adb_kit](https://pub.dev/packages/adb_kit) | **不替换**现有层；Utilities 优先用上游 catalog，命令表可对照补缺 |
| iOS 设备层 / 无线开关 / 隧道 / 镜像 | **pymobiledevice3** | [doronz88/pymobiledevice3](https://github.com/doronz88/pymobiledevice3)；[iOS17 tunnels](https://doronz88.github.io/pymobiledevice3/guides/ios17-tunnels/)；[cli recipes](https://github.com/doronz88/pymobiledevice3/blob/master/docs/guides/cli-recipes.md) | 已有 `Pymobiledevice3Launcher`；扩展 wifi-connections、usbmux list、serve-web、截图/录流 |
| iOS USB/日志（存量） | libimobiledevice | libimobiledevice + Windows Apple Mobile Device Support | 保持 `idevice_*`；无线发现 Windows 上依赖 AMDS 的 Wi‑Fi sync |
| Linux 无线 usbmux（非 Windows 主路径） | netmuxd / usbmuxd2 | [jkcoxson/netmuxd](https://github.com/jkcoxson/netmuxd)、tihmstar/usbmuxd2 | **Windows 主路径不捆绑**；文档注明 Linux 可自备 |
| iOS 镜像画面 | pmd3 `display serve-web`（浏览器 WebCodecs） | 同上 cli-recipes | 应用内 WebView 加载 loopback；失败回退系统浏览器 |
| iOS 截图 / 录流 | pmd3 developer APIs / `start-video-stream` | 同上 | 封装为 tool，不自写 RTP |

### 无线 iOS（Windows 优先）推荐流程（pmd3 官方路径）

1. USB 插线一次：信任电脑、配对。  
2. `pymobiledevice3 lockdown wifi-connections on`（开启 lockdown Wi‑Fi）。  
3. 同网；拔线后由 **Apple Mobile Device Support（usbmuxd 等价）** 发现 network 设备（`usbmux list` / `idevice_id`）。  
4. 普通 syslog / lockdown：走 usbmux network。  
5. 镜像等 developer 服务（iOS 17.4+）：`serve-web --userspace`（或 `--tunnel`）走官方 no-root userspace 隧道；17.0–17.3.1 提示需 `tunneld`（管理员）。  

参考：[Understanding protocol layers](https://github.com/doronz88/pymobiledevice3/blob/master/misc/understanding_idevice_protocol_layers.md)、[issue #1076 无线备份讨论](https://github.com/doronz88/pymobiledevice3/issues/1076)。

## 目标

在不破坏现有 Logbay 增量（氛围主题、异常托盘、Windows 应用内更新、iOS serve-web、ostrace 等）的前提下，按批次补齐先前盘点的缺口，每批可编译、可测、可部署到 `D:\Eagly\App`。

## 批次 1 — 上游已合入稳定补丁

从 `upstream/main`（约 1.3.0）移植/对齐：

1. **日志列表跳动修复**（#61）— 滚动/拖选时列表位置稳定。
2. **App zoom 与固定 chrome 缩放** — 缩放偏好下标题栏、侧栏、状态条等跟着缩放（仓库已有 `app_zoom.dart` 迹象时以现有实现为准，补齐遗漏控件）。
3. **libimobiledevice 新命令语法** — `ideviceinstaller` / syslog 等与新版 bundled 工具参数对齐。
4. **日志过滤性能** — 过滤路径降 CPU/RAM；默认行数上限保持与上游一致量级（约 10 万，可配置）。

策略：优先 cherry-pick / 手工移植冲突文件，保留 Logbay 中文文案与主题扩展。

## 批次 2 — 上游 WIP 功能移植

来源分支（未全部进 upstream main）：

1. **Utilities**（`utilities-tools`）— 设备常用命令 GUI（电源、信息、屏幕/输入等），接入 feature rail / 快捷入口 / 命令面板。命令表以 Eagly 为准；缺项可对照 adb_kit 补 Android 侧。
2. **Terminal**（`feature/terminal`）— 与现有 `adb_shell` 协调：
   - 推荐：以 upstream Terminal 会话模型增强/替换体验薄弱处；Android 保留 shell，iOS 按上游能力接可用工具。
   - 避免双入口重复：UI 只保留一个「终端」入口。
3. **全局搜索 / 命令面板模糊搜** — 随 Utilities/Terminal 一并移植。
4. **日志选区增强**（`feature/selection-enhancements`）— 选区与复制体验。

策略：从上游分支导出相关 `lib/features/{utilities,terminal,...}` 与测试，适配 `DeviceSessionController` / feature rail 命名与中文标签。

## 批次 3 — iOS 镜像产品化 + 无线

在现有 `IosMirrorTool`（`serve-web`）之上：

1. **应用内嵌入查看器** — 桌面 WebView 加载 `http://127.0.0.1:<port>/`（pmd3 官方 viewer）；失败回退系统浏览器。
2. **iOS 截图** — 优先 pmd3 / libimobiledevice 已有截图命令封装；与 Android 截图入口对齐。
3. **iOS 录屏** — MVP：pmd3 `start-video-stream` 落文件或明确降级文案。
4. **镜像音频** — serve-web 默认有声；UI 开关（若 CLI 支持 `--no-audio`）。
5. **无线 iOS** — 按上文「pmd3 官方路径」：
   - UI：无线面板增加 iOS 分段（一键 `wifi-connections on`、刷新发现、中文步骤）。
   - 发现：`pymobiledevice3 usbmux list` + 现有 `idevice_id`（区分 USB/network）。
   - 隧道：镜像等走 `--userspace`；老系统提示 tunneld。
   - MVP：已配对机拔 USB 后仍出现在列表并可拉 syslog。

约束：需主机安装 `pymobiledevice3`；iOS 17.4+ 体验最佳；Windows 需 Apple Mobile Device Support。

## 验收标准

| 批次 | 验收 |
|------|------|
| 1 | `flutter analyze` 相关文件干净；日志滚动不跳；zoom 下 chrome 同步；iOS 工具命令不因旧语法失败 |
| 2 | Utilities / Terminal 可从 rail 打开并对真机执行至少 2 条命令；选区复制正常；有基础测试 |
| 3 | 有 iOS 设备时：应用内可见镜像；可截图；音频可开关或明确不可用文案；无线拔线后仍可发现并拉日志（或可读失败原因） |

## 风险与缓解

- 工作区已有大量未提交改动：移植时避免 `git restore` 误伤；冲突手工合并。
- Terminal 与 `adb_shell` 重叠：合并为单一入口。
- WebView 插件体积/权限：失败回退浏览器，不阻塞镜像启动。
- iOS 录屏协议复杂：批次 3 允许截图先于完整录屏落地。
- 无线 iOS 依赖 AMDS + 同网 + 至少一次 USB：UI 必须区分「未发现」与「已发现但服务不可用」。

## 非目标

- QtScrcpy 式群控 / 键位映射
- 重写 Android scrcpy 管线
- 捆绑 netmuxd 替代 Windows AMDS（仅文档提及 Linux 方案）
- 无需首次 USB 的纯零接触无线配对
