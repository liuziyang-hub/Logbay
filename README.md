# Logdeck

桌面日志与设备工作台（基于 [eagly](https://github.com/ShreyashKore/eagly) 定制）：Android / iOS 日志、镜像、文件与应用管理。

## 主题

设置 → **主题** 三选一（含视频背景、字体与配色）：

| 主题 | 气质 |
|------|------|
| 湖边 | 暖珊瑚 · Cormorant / DM Sans |
| 森林 | 苔藓绿 · Fraunces / Nunito |
| 宇宙 | 星雾蓝 · Italiana / Outfit |

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

- **自动更新已关闭**（不检查上游 GitHub Releases）。
- 侧栏与关于页不展示版本号。
- 视频资源在 `assets/videos/`（往返无缝循环素材）。

## License

上游 eagly 协议以原仓库为准；本仓库为定制分支用途。
