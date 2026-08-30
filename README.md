# Logdeck

Logdeck 是面向 Windows 的桌面设备工作台，帮你同时管理 Android 与 iOS 设备：实时日志、屏幕镜像、文件传输与应用安装。

## 功能

- **日志**：实时查看设备日志，支持过滤、搜索与导出
- **镜像**：控制 Android 设备屏幕
- **文件**：浏览、上传与下载设备文件
- **应用**：查看已安装应用，安装 APK / IPA
- **多设备**：可同时连接多台设备并行工作

## 主题

设置 → **主题** 三选一（视频背景 + 字体 + 配色）：

| 主题 | 气质 |
|------|------|
| 湖边 | 深渊蓝 · 冰蓝 · 哈瓦那橙 |
| 森林 | 雾林灰绿 · 鼠尾草 · 暖金点缀 |
| 宇宙 | 星夜靛蓝 · 深空靛 · 星光米 |

## 开发

```bash
# 需要本机 Flutter SDK
flutter pub get
flutter run -d windows
```

发布构建：

```bash
flutter build windows --release
```

输出目录：`build/windows/x64/runner/Release/`。

## 说明

- 应用内不启用自动更新检查
- 侧栏与关于页不展示版本号
- 主题视频资源位于 `assets/videos/`
