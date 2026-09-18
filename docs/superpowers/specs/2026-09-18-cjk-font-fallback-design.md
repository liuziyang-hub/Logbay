# Logbay 中文字体回退修复设计

## 背景

Logbay 的湖边、森林、宇宙主题分别使用 DM Sans、Nunito、Outfit 等主题字体。Windows Release 中这些字体不包含完整中文字符，而当前 Material `TextTheme` 没有显式配置中文回退字体，导致正文中的中文显示为方框。标题、按钮等采用其他字重或样式，因字体匹配路径不同，可能仍能正常显示。

## 目标

- 保留三套主题现有字体风格与颜色配置。
- Windows 上所有 Material 正文、标题、标签和按钮文字都能可靠显示简体中文。
- macOS、Linux 使用各自可用的系统中文字体回退。
- 不改变日志专用等宽字体、布局尺寸、字号和交互逻辑。

## 方案

在 `ThemeTypography` 中集中定义平台相关的 CJK 字体回退列表，并将其应用到 `materialTextTheme` 返回的每一种非空 `TextStyle`。

- Windows：`Microsoft YaHei UI`、`Microsoft YaHei`、`Segoe UI`、`SimSun`。
- macOS：`PingFang SC`、`Hiragino Sans GB`、`Helvetica Neue`。
- Linux：`Noto Sans CJK SC`、`Noto Sans SC`、`WenQuanYi Micro Hei`、`DejaVu Sans`。

主题主字体仍排在第一位；只有主字体不含对应字符时，Flutter 才使用回退字体，因此英文和数字的视觉风格保持不变。

## 影响范围

- 修改 `lib/presentation/theme/theme_typography.dart`。
- 增加主题字体测试，覆盖湖边、森林、宇宙三种主题。
- 镜像页和性能页不做局部硬编码，避免相同问题在其他页面重复出现。

## 测试与验收

- 单元测试验证三套主题的正文、标题、标签样式均包含平台 CJK 回退字体。
- 运行主题相关测试、完整测试和静态分析。
- 构建 Windows Release 并覆盖安装。
- 验收镜像说明与性能页说明不再出现方框；英文主题字体和现有布局保持不变。

## 非目标

- 不更换三套主题的主字体。
- 不调整字号、颜色、间距或页面结构。
- 不修改日志区域已有的专用 CJK/Emoji 字体策略。
