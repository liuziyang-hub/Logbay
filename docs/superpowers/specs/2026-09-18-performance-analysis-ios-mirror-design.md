# Logbay 完整性能分析与 iOS 镜像稳定化设计

- 日期：2026-09-18
- 目标版本：Logbay 1.5.x
- 状态：设计已确认，等待实施计划

## 1. 背景与目标

Logbay 当前能够采集 Android 的基础 CPU、内存信息，并通过外部安装的
`pymobiledevice3` 提供 iOS CoreDevice 实时镜像。现有能力不足以完成完整的性能
问题定位：缺少 FPS、帧耗时、网络、温度和可选择时间区间的统计，也无法在软件内
解析 Perfetto 轨迹。iOS 镜像还会受到 DDI、RSD 隧道、媒体能力协商、WebView2
和设备端相机/麦克风占用影响，部分失败最终表现为无差别的 HTTP 500。

本项目选择完整内置方案：随 Logbay 分发 Android Perfetto 解析能力和 iOS 运行时，
用户安装 Logbay 后不再自行安装 Python 或其他命令行工具。实现后的目标如下：

1. Android 和 iOS 共用一个性能分析入口和数据模型。
2. 展示 FPS、帧耗时、卡顿、CPU、内存、网络和温度的实时曲线。
3. 支持在时间线上选择区间并计算平均值、峰值、P95 和异常计数。
4. Android 能录制、解析、浏览并导出完整 Perfetto 轨迹。
5. iOS 镜像具备能力预检、自修复、健康检测、有限重连和多级降级。
6. 所有外部运行时版本固定、校验完整性，并随安装包提供许可证信息。

## 2. 范围与非目标

### 2.1 本期范围

- Android 实时性能采集和 Perfetto 深度轨迹。
- iOS sysmontap、Graphics、NetworkMonitor 和电池温度采集。
- 实时图表、区间分析、异常标记、会话保存和数据导出。
- Windows 安装包内置必需运行时；macOS/Linux 保持同一抽象并预留打包清单。
- iOS CoreDevice 镜像运行时内置化和稳定性治理。
- 多设备隔离：每台设备拥有独立性能会话和镜像会话。

### 2.2 非目标

- 不重新实现 Perfetto 的二进制解析格式；使用官方 `trace_processor_shell`。
- 不实现 Android Studio 全部 Profiler 能力，例如 Java 堆对象引用图和原生火焰图编辑器。
- 不绕过 Apple 的开发者模式、信任、DDI 或系统媒体权限限制。
- 不承诺所有 iOS 版本都支持实时镜像；能力由实际设备预检结果决定。
- 不把性能数据上传到云端，所有采集与分析默认仅保存在本机。

## 3. 总体架构

新增 `PerformanceController`，沿用现有 `FeatureController` 和
`DeviceSessionController` 生命周期。控制器只依赖统一接口
`DevicePerformanceBackend`，具体平台实现如下：

```text
PerformanceFeatureView
  └─ PerformanceController
       ├─ AndroidPerformanceBackend
       │    ├─ AndroidLiveMetricsCollector
       │    ├─ PerfettoCaptureService
       │    └─ PerfettoTraceProcessor
       └─ IosPerformanceBackend
            ├─ IosRuntimeBroker
            ├─ IosSysmonCollector
            ├─ IosGraphicsCollector
            ├─ IosNetworkCollector
            └─ IosThermalCollector

MirrorController
  └─ IosRuntimeBroker
       ├─ bundled pymobiledevice3 runtime
       ├─ bundled go-ios helper
       └─ IosTransportLease / health monitor
```

`IosRuntimeBroker` 是每台 iOS 设备的共享协调器。它负责运行时发现、RSD/DDI
状态、子进程生命周期、端口分配、超时和互斥规则。性能采集与镜像不得各自绕过
Broker 启动独立隧道，避免多个 DVT/RemoteXPC 会话互相抢占。

## 4. 统一性能数据模型

### 4.1 采样点

`PerformanceSample` 包含：

- `timestamp`：单调时钟与墙上时间。
- `fps`：当前显示帧率。
- `frameTimeMs`：采样周期内的代表性帧耗时。
- `slowFrameCount`：超过平台阈值的帧数。
- `frozenFrameCount`：严重卡顿帧数。
- `cpuPercent`：目标应用 CPU 使用率。
- `memoryBytes`：目标应用实际内存占用。
- `networkRxBytes`、`networkTxBytes`：累计收发字节。
- `temperatureCelsius`：设备或电池温度。
- `sourceQuality`：`precise`、`estimated`、`fallback`。
- `unavailableReasons`：单项指标不可用的专业中文原因。

缺失值必须保存为 `null`，界面显示“不可用”及原因，禁止使用 `0` 伪装采集结果。

### 4.2 会话与区间

`PerformanceSession` 保存设备、目标应用、采样配置、开始/结束时间、采样点和事件
标记。内存中使用有上限的环形缓冲区，默认保留 30 分钟；用户主动记录时同步写入
临时会话文件，避免长时间采集导致内存增长。

区间分析输出：

- 平均值、最小值、最大值、P50、P95。
- 慢帧数、严重卡顿数、低于 30 FPS 的持续时间。
- CPU/内存峰值发生时间。
- 网络增量和平均吞吐量。
- 温度变化量及高温区间。

## 5. Android 性能实现

### 5.1 实时轻量采集

- FPS/帧耗时：优先解析 `dumpsys gfxinfo <package> framestats`；设备不支持时降级
  到 SurfaceFlinger 延迟信息，并标记为估算值。
- CPU：按目标 PID 读取进程时间与系统 CPU 时间差值，不再用系统 load average
  推算应用 CPU。
- 内存：使用 `dumpsys meminfo <package>`，保留 PSS/RSS 和主要分类。
- 网络：解析目标应用 UID 的网络统计；受系统权限限制时显示不可用原因。
- 温度：优先 thermalservice，降级到 `dumpsys battery` 电池温度。

默认采样间隔 1 秒。单轮采集超时时放弃该轮，不并发堆积下一轮命令。

### 5.2 Perfetto 录制

`PerfettoCaptureService` 通过仓库内置 ADB 启动设备自带 Perfetto。配置包含：

- CPU scheduling/frequency/idle。
- process stats 和内存计数器。
- gfx/view/window manager/input 事件。
- frame timeline 与 SurfaceFlinger 数据源（设备支持时）。
- 电源、热状态和电池计数器（设备支持时）。
- 目标应用 atrace 标记与 logcat。

停止录制必须采用可可靠结束的后台 PID 方式，随后拉取轨迹。Android 10 以下设备
不能直接 pull 时，使用 `adb exec-out cat` 降级读取。

### 5.3 内置解析器

Windows 包内附官方 `trace_processor_shell.exe`。Flutter 通过 JSON/CSV 查询接口执行
固定 SQL 模板，不允许用户输入任意系统命令。首批查询覆盖：

- 进程/线程 CPU 时间。
- FrameTimeline 预期帧、实际帧、jank 类型和帧耗时。
- 内存计数器。
- 网络与电源计数器（轨迹包含时）。
- 时间范围内的 slice、logcat 和用户交互事件。

解析过程在独立进程执行，可取消，有最大运行时间和最大输出限制。原始轨迹始终可
导出，并可选择在 `ui.perfetto.dev` 打开；打开外部网站前明确提示轨迹可能包含应用
与设备信息。

## 6. iOS 性能实现

### 6.1 内置运行时

Windows 安装包包含：

- 固定版本的 go-ios 静态二进制，用于 JSON 化的 sysmontap、FPS 和网络采集。
- 独立目录形式的嵌入式 CPython 与固定版本 pymobiledevice3，用于 CoreDevice
  镜像、DDI/cryptex 和 go-ios 尚未覆盖的开发者服务。
- `runtime-manifest.json`，记录版本、来源、许可证和 SHA-256。

选择独立目录而非单文件 PyInstaller，避免每次启动解压导致镜像启动慢和临时目录
残留。运行时只监听 loopback，不开放局域网端口。

### 6.2 指标采集

- CPU/内存：sysmontap 按目标 PID/进程名采集。
- FPS/帧耗时：Instruments Graphics 服务。只有 FPS 而没有逐帧耗时时，明确标记
  `estimated`，不伪造帧耗时。
- 网络：NetworkMonitor 按进程聚合上下行字节。
- 温度：battery diagnostics 1 Hz 监控；字段缺失时不阻塞其他指标。

go-ios 输出统一转换为 NDJSON。每个采集器单独解析，但子进程启动、停止和重连由
`IosRuntimeBroker` 统一管理。连续两个采样周期无数据视为停滞，Broker 先重建对应
通道，再按指数退避重建整个性能会话。

### 6.3 与镜像并发

Broker 对设备能力执行一次并发探测：

- 支持并行 DVT 通道时，性能与镜像同时运行。
- 设备或系统版本存在 DVT 排他限制时，镜像运行期间保留温度等非 DVT 指标，暂停
  sysmontap/Graphics，并在界面显示原因；停止镜像后自动恢复。
- XCUITest 或其他工具占用 DVT 导致 sysmon 空输出时，必须判定失败并提示占用，
  不能依据退出码 0 判定成功。

## 7. iOS 镜像稳定化

### 7.1 启动预检

启动顺序固定为：

1. 检查设备在线、已配对且已信任。
2. 检查开发者模式。
3. 检查 DDI；未挂载时先 `mounter auto-mount`，失败后尝试 cryptex。
4. 建立或复用 RSD 传输租约。
5. 调用媒体支持信息和 DisplayService 状态预检。
6. 检查相机/麦克风占用错误。
7. 分配端口并启动 `serve-web`。
8. HTTP 根页面与 codec 端点均通过后，才把状态切换为“运行中”。

版本号仅作为已知缺陷提示，不作为唯一门禁。当前硬编码的 `11.15.4` 门槛改为：
最低修复版本检查、实际命令能力检查和媒体服务预检三者结合，避免官方可用版本被
错误拦截。

### 7.2 运行时健康检测

- 每 2 秒检查子进程、HTTP 服务和最后视频活动时间。
- HTTP 正常但视频停滞时先请求关键帧/刷新；仍无恢复再重启会话。
- 自动重启采用 1、2、4、8 秒退避，10 分钟内最多 4 次。
- 稳定运行 60 秒后清零失败计数。
- 用户主动停止、设备断开和应用退出时不触发自动重连。
- 所有 stdout/stderr 订阅跟随会话释放，避免重复启动后的监听泄漏。

### 7.3 500 错误分类

错误解析至少区分：

- DDI/cryptex 未就绪。
- RSD tunnel 建立失败或断开。
- DisplayService 不存在或系统版本不支持。
- 相机/麦克风正被占用。
- HEVC/WebCodecs 不支持。
- WebView2 页面加载错误。
- 本地端口冲突。
- 未知上游异常。

每类错误提供专业中文说明、建议操作、原始错误折叠区和“一键复制诊断”。

### 7.4 降级链

降级顺序：

1. Windows 内嵌 WebView2。
2. 系统 Chrome/Edge 打开 loopback viewer。
3. 连续截图观察模式，默认 2 FPS，窗口不可见时暂停。
4. 单次截图。

降级不隐藏原因；界面必须说明当前模式不具备实时控制或声音。

## 8. 界面设计

侧栏新增“性能分析”入口。主布局包含：

- 顶部：设备、目标应用、采样间隔、开始/停止和记录 Perfetto。
- 摘要条：当前 FPS、P95 帧耗时、CPU、内存、网络速率、温度。
- 时间线：指标按组显示，可隐藏单项、缩放和拖选区间。
- 区间详情：统计值、异常列表和跳转时间点。
- 事件轨：应用启动/停止、安装、设备重连、Crash/ANR、截图与用户标记。
- 导出：CSV、JSON、PNG 和原始 trace。

图表使用现有主题令牌。颜色语义固定：正常使用主题主色，警告使用 warning，超过阈值
使用橙色，严重异常使用 error；不为每条曲线随意分配高饱和颜色。

## 9. 错误处理与资源控制

- 每个外部进程必须有超时、取消、退出码和 stderr 捕获。
- 子进程意外退出不得导致 Flutter UI 卡死。
- 采集器失败彼此隔离；FPS 失败不应停止 CPU/内存。
- 设备断开时停止采集并保留最后会话，重连后由用户确认是否继续。
- 默认会话写入临时目录，正常退出后清理未保存数据；崩溃恢复时询问是否恢复。
- 限制 trace 文件、解析输出和图表采样点规模，防止磁盘或内存无限增长。

## 10. 打包、许可与安全

- 所有运行时使用固定版本和 SHA-256，构建脚本拒绝未校验下载。
- 安装包提供第三方许可证页及源码链接。
- Perfetto 按 Apache-2.0 要求保留版权和许可证。
- go-ios 按 MIT 要求保留版权和许可证。
- pymobiledevice3 按 GPL-3.0 要求提供对应源码获取方式、许可证和修改说明；其运行时
  与 Flutter 主程序通过独立进程协议通信。
- 不写入或导出 pairing record；日志中对 UDID 和用户路径做脱敏。
- 本地 HTTP 服务仅绑定 `127.0.0.1`/`localhost`，使用随机空闲端口。

预计 Windows 安装包增加 40–100 MB。构建完成后输出各运行时体积清单，再决定是否对
调试符号和非必要 Python 包做安全裁剪，功能文件不得删除。

## 11. 测试策略

### 11.1 单元测试

- Android gfxinfo、meminfo、CPU、网络和温度解析。
- Perfetto SQL 查询结果解析、空结果和超时。
- go-ios/pymobiledevice3 NDJSON、乱码、缺字段和异常行解析。
- 区间统计、P95、计数器回绕和会话截断。
- iOS 镜像错误分类、退避、重试上限和降级决策。

### 11.2 组件测试

- 性能入口、目标应用选择、开始/停止和导出按钮。
- 指标不可用状态与专业中文文案。
- 图表缩放、区间选择和异常跳转。
- 镜像内嵌、浏览器和连续截图三种呈现模式。

### 11.3 集成与兼容性测试

- Android 9、10、12、14、16；覆盖无法直接 pull Perfetto 的旧设备。
- iOS 17、18、26、27 的可用能力矩阵；不支持镜像的版本验证截图降级。
- USB、无线、多设备、断线重连、端口占用、WebView2 缺失。
- 镜像与性能采集并行，验证 DVT 占用降级。
- Windows 覆盖安装、卸载和运行时文件完整性。

## 12. 实施顺序与验收标准

### 阶段一：Android Perfetto

- 性能入口和统一数据模型落地。
- Android 七类实时指标可采集或明确说明不可用。
- 可录制、内置解析和导出 Perfetto 轨迹。
- 30 分钟采集无明显内存持续增长。

### 阶段二：iOS 性能

- 安装后无需用户另装 Python/go-ios。
- iOS CPU、内存、FPS、网络和温度进入同一时间线。
- 无输出、DVT 占用和设备断开都能在限定时间内识别并恢复或给出说明。

### 阶段三：iOS 镜像稳定化

- 启动前完成全部能力预检。
- 已知 500 错误可以分类，不再只显示 HTTP 状态码。
- 视频停滞能有限自动恢复，且不存在无限重启。
- 内嵌失败可自动进入浏览器或连续截图模式。
- 软件退出后无残留运行时进程和占用端口。

三个阶段分别通过格式化、静态分析、完整测试和 Windows Release 打包后再合并。最终
安装包必须支持覆盖安装，并在更新日志中列出新增能力、兼容范围、体积变化和第三方
运行时许可证。

## 13. 参考资料

- Perfetto CLI：https://perfetto.dev/docs/reference/perfetto-cli
- Perfetto 系统跟踪：https://perfetto.dev/docs/getting-started/system-tracing
- pymobiledevice3：https://github.com/doronz88/pymobiledevice3
- pymobiledevice3 Releases：https://github.com/doronz88/pymobiledevice3/releases
- go-ios：https://github.com/danielpaulus/go-ios

