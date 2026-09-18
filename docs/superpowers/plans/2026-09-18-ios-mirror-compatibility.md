# iOS 镜像兼容与错误展示实施计划

## 执行方式

采用当前任务内联执行。所有改动在现有 `logdeck-public` 分支完成，按测试先行顺序实施。

## 任务 1：补齐结构化诊断测试

- [ ] 在 `test/ios_mirror_tool_test.dart` 增加混合 traceback 用例：同时含音频启动失败与 CoreDevice 9021，期望归类为 `unsupportedSystem`。
- [ ] 增加 9022/相机麦克风占用用例，确保仍归类为 `mediaInUse`。
- [ ] 增加用户文案清洁断言：不得包含 `Traceback`、`site-packages`、用户目录或 UDID。
- [ ] 运行该测试，确认新用例先失败。

## 任务 2：修复错误分类与用户文案

- [ ] 调整 `lib/services/tools/ios_mirror_diagnostics.dart` 的匹配优先级，先处理 9021/iOS 27 版本限制，再处理媒体、隧道等宽泛错误。
- [ ] 为 9021 返回专业中文标题、原因和下一步说明。
- [ ] 增加用户可见文本清洗，保证 `userMessage` 永远不拼接原始 traceback。
- [ ] 在 `lib/services/tools/ios_mirror_tool.dart` 中让进程提前退出、端口未启动和 HTTP 探测失败都通过同一诊断入口。
- [ ] 保持完整原始错误仅供内部日志使用，并对用户目录和设备标识做脱敏。
- [ ] 运行诊断测试并提交。

## 任务 3：实现 iOS 不支持状态的截图回退

- [ ] 扩展 `MirrorController` 保存最近一次 iOS 截图、截图加载态与截图错误。
- [ ] 增加截图方法，复用现有 `captureScreenshot()`，成功后通知界面刷新。
- [ ] 在停止、设备断开和重新启动实时镜像时清理临时截图状态。
- [ ] 更新 `PaneBody`：unsupported + iOS 时显示“截取当前画面”和“重新检测”，截图成功后在面板内按比例展示。
- [ ] 普通错误仍只显示重试，不错误展示截图回退。
- [ ] 增加控制器和组件测试。

## 任务 4：回归、版本与发布包

- [ ] 运行 `fvm dart format`（本机按仓库可用 Flutter/Dart 路径执行）。
- [ ] 运行相关测试、全量单线程测试和 `dart analyze lib test`。
- [ ] 实机复现 iOS 26.6.2，确认不再显示 traceback/乱码，并进入不支持状态。
- [ ] 更新版本号与 CHANGELOG。
- [ ] 构建 Windows Release 与 Inno 覆盖安装包，计算 SHA-256。
- [ ] 覆盖安装并核对唯一安装项、文件版本、运行状态。
- [ ] 提交并推送 GitHub，创建新版本 Release。
