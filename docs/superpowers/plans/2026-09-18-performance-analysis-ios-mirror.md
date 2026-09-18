# Logbay 性能分析与 iOS 镜像稳定化实施计划

> 依据：`docs/superpowers/specs/2026-09-18-performance-analysis-ios-mirror-design.md`
>
> 执行方式：当前任务内联实施；每个任务先写失败测试，再实现，再运行定向测试。

## 总体交付

- 新增 Android/iOS 共用的“性能分析”功能入口。
- Android 支持实时 FPS、帧耗时、CPU、内存、网络、温度以及 Perfetto 录制和内置解析。
- iOS 支持 sysmontap、Graphics、Network、温度采集，并以内置运行时执行。
- iOS 镜像增加能力预检、健康监控、错误分类、有限重连和降级模式。
- Windows 安装包包含固定版本的 Perfetto、go-ios 和 pymobiledevice3 运行时及许可证。
- 完成格式化、静态分析、单元/组件测试、Release 构建和覆盖安装验证。

## Task 1：统一性能领域模型与区间统计

**Files**

- Create: `lib/features/performance/data/performance_metric.dart`
- Create: `lib/features/performance/data/performance_sample.dart`
- Create: `lib/features/performance/data/performance_session.dart`
- Create: `lib/features/performance/data/performance_interval_summary.dart`
- Create: `lib/features/performance/services/performance_statistics.dart`
- Test: `test/performance_statistics_test.dart`

**Steps**

- [ ] 先覆盖空数据、缺失值、P50/P95、计数器回绕和任意时间区间的失败测试。
- [ ] 定义 `PerformanceSourceQuality`、单项不可用原因和可空指标。
- [ ] 实现有界采样会话；默认上限等价于 30 分钟、1 秒采样。
- [ ] 实现平均值、峰值、P50/P95、低 FPS 持续时间、慢帧/冻结帧计数、网络增量和温升统计。
- [ ] 运行 `fvm flutter test test/performance_statistics_test.dart`。
- [ ] Commit: `feat: add performance session model and interval statistics`

## Task 2：采集后端接口与控制器生命周期

**Files**

- Create: `lib/features/performance/services/device_performance_backend.dart`
- Create: `lib/features/performance/performance_controller.dart`
- Modify: `lib/session/device_session_controller.dart`
- Modify: `test/support/session_test_support.dart`
- Test: `test/performance_controller_test.dart`

**Steps**

- [ ] 测试开始、停止、设备断开、采集器局部失败、轮次超时和缓冲上限。
- [ ] 后端以流输出统一样本和事件；控制器不得依赖具体平台命令。
- [ ] 每轮超时后跳过而非堆积；停止时关闭订阅和临时会话写入。
- [ ] 将控制器懒加载到每设备 `DeviceSessionController` 并正确释放。
- [ ] Commit: `feat: add performance controller lifecycle`

## Task 3：Android 轻量实时指标解析器

**Files**

- Create: `lib/features/performance/android/android_gfxinfo_parser.dart`
- Create: `lib/features/performance/android/android_proc_cpu_parser.dart`
- Create: `lib/features/performance/android/android_meminfo_parser.dart`
- Create: `lib/features/performance/android/android_network_parser.dart`
- Create: `lib/features/performance/android/android_temperature_parser.dart`
- Test: `test/android_performance_parsers_test.dart`

**Steps**

- [ ] 使用不同 Android 版本、中文/英文输出、空输出和异常行建立夹具。
- [ ] 解析 gfxinfo framestats，计算 FPS、帧耗时、慢帧和冻结帧。
- [ ] 通过进程/系统 CPU tick 差值计算目标应用 CPU，避免 load average 估算。
- [ ] 解析 meminfo 的 PSS/RSS 和主要分类。
- [ ] 按 UID 解析网络累计字节，并处理计数器回绕。
- [ ] 解析 thermalservice，失败时回退 battery 温度。
- [ ] Commit: `feat: parse Android performance metrics`

## Task 4：Android 实时采集后端

**Files**

- Create: `lib/features/performance/android/android_live_metrics_collector.dart`
- Create: `lib/features/performance/android/android_performance_backend.dart`
- Modify: `lib/services/tools/adb_tool.dart`
- Modify: `lib/services/device_session_repository.dart`
- Test: `test/android_performance_backend_test.dart`

**Steps**

- [ ] 在 FakeAdbTool 上验证命令参数、超时、PID/UID 变化和降级逻辑。
- [ ] 默认每秒串行采集；不允许前一轮未完成时启动下一轮。
- [ ] 单项命令失败只将对应字段标为不可用。
- [ ] 应用重启导致 PID 改变时自动重新解析 PID/UID。
- [ ] Commit: `feat: collect live Android performance metrics`

## Task 5：Perfetto 录制与文件生命周期

**Files**

- Create: `lib/features/performance/android/perfetto_capture_service.dart`
- Create: `assets/perfetto/default_android_config.pbtx`
- Modify: `pubspec.yaml`
- Test: `test/perfetto_capture_service_test.dart`

**Steps**

- [ ] 测试能力探测、后台 PID、正常停止、强制停止、旧系统 exec-out 回退和断线清理。
- [ ] 使用内置 ADB 调用设备端 Perfetto，配置覆盖 CPU、gfx、FrameTimeline、内存、电源、热状态和目标应用 atrace。
- [ ] 轨迹先写设备临时目录，停止后安全拉取到本地会话目录。
- [ ] 确保取消和设备断开不会遗留设备端录制进程。
- [ ] Commit: `feat: record Android Perfetto traces`

## Task 6：内置 Perfetto 解析器

**Files**

- Create: `lib/services/tools/perfetto_trace_processor.dart`
- Create: `lib/features/performance/android/perfetto_queries.dart`
- Create: `scripts/download_perfetto_tools.ps1`
- Modify: `lib/utils/tools_path.dart`
- Modify: `scripts/download_platform_tools.sh`
- Test: `test/perfetto_trace_processor_test.dart`

**Steps**

- [ ] 为 JSON/CSV、空结果、超时、大输出和取消建立测试。
- [ ] 固定 SQL 模板覆盖 CPU、FrameTimeline、内存、网络、电源和 slice。
- [ ] `trace_processor_shell` 只接收受控参数，不拼接 shell 字符串。
- [ ] 下载脚本固定版本和 SHA-256，并生成运行时清单。
- [ ] Commit: `feat: parse Perfetto traces in app`

## Task 7：性能分析界面与导航入口

**Files**

- Create: `lib/features/performance/performance_feature_view.dart`
- Create: `lib/features/performance/components/performance_summary_bar.dart`
- Create: `lib/features/performance/components/performance_timeline.dart`
- Create: `lib/features/performance/components/performance_interval_panel.dart`
- Create: `lib/features/performance/components/performance_toolbar.dart`
- Modify: `lib/session/device_session_controller.dart`
- Modify: `lib/features/home_screen/components/device_screen_content.dart`
- Modify: relevant device rail/navigation component discovered during implementation
- Test: `test/performance_feature_view_test.dart`
- Test: `test/device_session_controller_test.dart`

**Steps**

- [ ] 先测试入口、平台状态、开始/停止、应用选择、区间选择和导出按钮。
- [ ] 使用主题令牌实现摘要条、可缩放时间线、区间详情和事件轨。
- [ ] 不可用指标必须显示原因，不得显示为 0。
- [ ] 多设备分别保留会话状态，关闭面板不误停其他设备。
- [ ] Commit: `feat: add performance analysis workspace`

## Task 8：本地会话保存与导出

**Files**

- Create: `lib/features/performance/services/performance_session_store.dart`
- Create: `lib/features/performance/services/performance_export_service.dart`
- Test: `test/performance_session_store_test.dart`
- Test: `test/performance_export_service_test.dart`

**Steps**

- [ ] 测试增量写入、崩溃恢复、保存、丢弃、CSV/JSON 和图表 PNG 导出。
- [ ] 临时会话采用版本化格式与原子重命名，避免半写文件。
- [ ] 正常退出清理未保存临时数据，异常退出后提示恢复。
- [ ] Commit: `feat: persist and export performance sessions`

## Task 9：iOS 运行时 Broker 与清单

**Files**

- Create: `lib/services/tools/ios_runtime_broker.dart`
- Create: `lib/services/tools/bundled_runtime_manifest.dart`
- Create: `assets/runtime/runtime-manifest.json`
- Modify: `lib/services/tools/pymobiledevice3_launcher.dart`
- Modify: `lib/utils/tools_path.dart`
- Test: `test/ios_runtime_broker_test.dart`
- Test: `test/pymobiledevice3_launcher_test.dart`

**Steps**

- [ ] 测试内置优先、主机回退、哈希错误、端口分配、租约复用和并发互斥。
- [ ] `Pymobiledevice3Launcher` 优先解析安装包内置运行时；开发环境允许主机安装版本回退。
- [ ] Broker 按设备管理 RSD/DDI、子进程、超时、退出和诊断日志。
- [ ] 仅绑定 loopback，诊断输出脱敏 UDID 和用户路径。
- [ ] Commit: `feat: add bundled iOS runtime broker`

## Task 10：iOS 性能采集后端

**Files**

- Create: `lib/features/performance/ios/ios_metric_parsers.dart`
- Create: `lib/features/performance/ios/ios_sysmon_collector.dart`
- Create: `lib/features/performance/ios/ios_graphics_collector.dart`
- Create: `lib/features/performance/ios/ios_network_collector.dart`
- Create: `lib/features/performance/ios/ios_thermal_collector.dart`
- Create: `lib/features/performance/ios/ios_performance_backend.dart`
- Test: `test/ios_performance_parsers_test.dart`
- Test: `test/ios_performance_backend_test.dart`

**Steps**

- [ ] 用 go-ios/pymobiledevice3 的正常、缺字段、乱码、退出码 0 但无数据输出建立测试。
- [ ] CPU/内存、FPS、网络和温度采集器独立失败、统一输出。
- [ ] 连续两轮无数据判为停滞，并由 Broker 重建通道。
- [ ] 检测 DVT 排他占用；镜像期间按能力暂停并在停止后恢复。
- [ ] Commit: `feat: collect iOS performance metrics`

## Task 11：iOS 镜像预检与结构化错误

**Files**

- Create: `lib/services/tools/ios_mirror_diagnostics.dart`
- Modify: `lib/services/tools/ios_mirror_tool.dart`
- Modify: `lib/services/tools/ios_developer_image_tool.dart`
- Modify: `lib/services/tools/pymobiledevice3_launcher.dart`
- Test: `test/ios_mirror_diagnostics_test.dart`
- Modify: `test/ios_mirror_tool_test.dart`

**Steps**

- [ ] 覆盖 DDI、RSD、DisplayService、媒体占用、编解码、端口和未知 500 分类。
- [ ] 移除 iOS 27 和 `11.15.4` 的单一硬门禁，改为最低已知修复提示 + 命令能力 + 服务预检。
- [ ] 根页面和 codec 均通过后才返回运行中会话。
- [ ] 错误对象包含专业中文摘要、建议操作、原始输出和可复制诊断。
- [ ] Commit: `fix: classify and preflight iOS mirror failures`

## Task 12：iOS 镜像健康监控、有限重连与降级

**Files**

- Modify: `lib/features/mirror/mirror_controller.dart`
- Modify: `lib/features/mirror/components/ios_mirror_webview.dart`
- Modify: `lib/features/mirror/components/pane_body.dart`
- Modify: `lib/features/mirror/components/mirror_control_strip.dart`
- Modify: `lib/services/tools/ios_mirror_tool.dart`
- Test: `test/mirror_controller_test.dart`
- Create: `test/ios_mirror_webview_state_test.dart`

**Steps**

- [ ] 测试 1/2/4/8 秒退避、十分钟上限、稳定 60 秒复位和主动停止不重连。
- [ ] 会话每 2 秒检查进程、HTTP 和视频活动；停滞先刷新，再重建。
- [ ] WebView2 初始化和导航失败上报控制器，禁止永远转圈。
- [ ] 降级顺序为 WebView2、系统浏览器、2 FPS 连续截图、单次截图。
- [ ] 连续截图在窗口不可见时暂停，并明确提示不支持实时触控/声音。
- [ ] Commit: `fix: stabilize iOS mirror and add fallbacks`

## Task 13：下载、打包、许可证和体积控制

**Files**

- Create: `scripts/download_ios_runtime.ps1`
- Create: `scripts/verify_runtime_manifest.ps1`
- Create: `THIRD_PARTY_NOTICES.md`
- Modify: `pubspec.yaml`
- Modify: Windows installer/Fastforge configuration discovered during implementation
- Modify: release workflow/configuration discovered during implementation
- Test: `test/bundled_runtime_manifest_test.dart`

**Steps**

- [ ] 固定 Perfetto、go-ios、CPython 和 pymobiledevice3 版本及 SHA-256。
- [ ] 构建前校验所有二进制；缺失或哈希不一致时明确失败。
- [ ] 打包 Apache-2.0、MIT、GPL-3.0 许可证、来源和对应源码链接。
- [ ] 清理调试符号、缓存和不需要的 Python 包，但保留所有运行功能。
- [ ] 输出各运行时体积清单和安装包总大小。
- [ ] Commit: `build: bundle performance and iOS runtimes`

## Task 14：全量回归、版本与 Release

**Files**

- Modify: `pubspec.yaml`
- Modify: changelog/release notes file discovered during implementation
- Add/Modify: compatibility documentation under `docs/`

**Steps**

- [ ] 运行 `fvm dart format` 覆盖所有新增/修改 Dart 文件。
- [ ] 运行 `fvm flutter analyze lib test`。
- [ ] 运行 `fvm flutter test`。
- [ ] 在可用 Android/iOS 真机上验证性能采集、镜像、断线、重连、多设备和导出。
- [ ] 构建 Windows Release，验证覆盖安装和卸载无运行时残留。
- [ ] 更新版本号和专业中文更新说明。
- [ ] 提交并推送当前分支；创建带安装包、校验值、兼容矩阵和许可证说明的 GitHub Release。
- [ ] Commit: `release: ship performance analysis and stable iOS mirror`

