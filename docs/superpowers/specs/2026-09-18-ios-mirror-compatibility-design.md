# iOS 镜像兼容与错误展示修复设计

## 目标

修复 iOS 镜像失败时显示乱码和完整 Python traceback 的问题，并依据设备实际能力选择可用操作。iOS 27 及以上继续使用 `pymobiledevice3 display serve-web` 提供实时画面与控制；iOS 17–26 在上游返回 CoreDevice 错误 9021 时停止无效重试，改为清晰说明限制并提供单次截图。

## 兼容策略

- 不再仅凭“iOS 17+ 支持 CoreDevice”推断实时镜像可用。
- 启动实时镜像后，如上游输出包含错误码 `9021`、`Remote control requires iOS 27.0 or later` 或同义提示，统一分类为 `unsupportedSystem`。
- 错误码 9022 或明确包含 camera/microphone in use 时，分类为媒体通道占用。
- 分类必须优先匹配明确的系统版本错误，再匹配音频、相机、隧道等宽泛关键词，避免 traceback 中的旁支错误覆盖根因。
- 不对未知未来系统硬编码拒绝；iOS 27+ 仍以实际服务探测结果为准。

## 用户界面

- 错误正文只显示简短、专业的中文说明和可执行建议，不渲染 traceback、文件路径、UDID 或 Python 包内部信息。
- iOS 17–26 的版本限制提示为：当前系统暂不支持可控制实时镜像；该能力由设备系统服务限制，并非连接故障。
- 不支持实时镜像时显示“截取当前画面”按钮。点击后调用现有 iOS 截图能力，并在镜像面板内显示最新截图。
- 保留“重新检测”入口，便于系统升级或运行时更新后再次探测。
- 详细原始输出仅写入应用日志，并在写入前清理用户目录、UDID 等敏感字段；界面不直接展示。

## 数据流与错误处理

1. `IosMirrorTool` 收集进程标准输出和标准错误。
2. `IosMirrorDiagnostic` 从完整原始输出中提取稳定的错误特征，并产生结构化类型、标题、说明与建议。
3. `IosMirrorTool` 抛出带结构化诊断的 `IosMirrorException`；系统版本不支持时转换为 `UnsupportedError`。
4. `MirrorController` 将不支持状态与普通启动失败分开保存；不触发自动重连。
5. `PaneBody` 根据状态显示精简说明，并在不支持的 iOS 设备上提供截图回退。

## 测试与验收

- 单元测试覆盖错误码 9021、iOS 27 文案、错误码 9022、媒体占用、隧道、DDI 和未知错误。
- 含 `audio start failed` 与 `Remote control requires iOS 27` 的混合 traceback 必须归类为系统不支持。
- 用户可见字符串不得包含 `Traceback`、`site-packages`、本机用户目录或 UDID。
- 控制器测试确认 `UnsupportedError` 进入 unsupported 状态且不自动重连。
- 组件测试确认不支持状态显示“截取当前画面”，普通错误状态不显示该按钮。
- 完成格式化、静态分析、相关测试和全量测试后重新构建 Windows 覆盖安装包。

## 暂不纳入

- 不集成需要替换 Windows USB 驱动的 Valeria 私有协议实现。
- 不引入 GPL 镜像引擎或更改 Logbay 的分发许可。
- 不使用循环截图伪装成实时视频。
- 不承诺绕过 Apple 对 iOS 26 远程控制服务的系统限制。
