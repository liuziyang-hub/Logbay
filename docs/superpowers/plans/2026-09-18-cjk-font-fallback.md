# Logbay 中文字体回退实施计划

## 执行方式

按用户要求在当前任务内联执行，保持 `logdeck-public` 分支和现有主题视觉不变。

## 任务 1：增加字体回退测试

- [x] 新建或扩展主题字体测试，遍历湖边、森林、宇宙三套主题。
- [x] 验证 `bodyMedium`、`titleMedium`、`labelLarge` 均保留主题主字体。
- [x] 验证这些样式包含当前平台对应的中文系统字体回退。
- [x] 运行测试并确认在实现前失败。

## 任务 2：集中实现跨平台 CJK 回退

- [x] 在 `ThemeTypography` 定义 Windows、macOS、Linux 的 CJK 回退列表。
- [x] 为 `materialTextTheme` 的全部非空样式复制 `fontFamilyFallback` 与中文 locale。
- [x] 保持 DM Sans、Nunito、Outfit 为主字体，不修改字号、字重或颜色。
- [x] 运行主题字体测试并确认通过。

## 任务 3：回归验证

- [x] 运行镜像、性能和主题相关组件测试。
- [x] 运行完整单线程测试。
- [x] 运行 `dart analyze lib test` 与格式化检查。
- [x] 检查变更仅影响字体回退配置和测试。

## 任务 4：构建与覆盖安装

- [x] 更新补丁版本号和 CHANGELOG。
- [x] 构建 Windows Release 与 Inno 覆盖安装包。
- [x] 覆盖安装并核对唯一安装项、文件版本与运行状态。
- [ ] 提交、推送并发布 GitHub Release。
