# Windows Android 镜像闪退修复计划

## 目标

修复 Windows 上 Android 镜像启动或启动失败清理时的原生访问冲突。

## 实施

- [x] 调整 `windows/runner/scrcpy_video_plugin.cpp`：停止解码线程后，先向 Flutter 注销纹理，再销毁纹理对象。
- [x] 运行 Android 镜像相关 Flutter 测试。
- [x] 重建 Windows Release，覆盖 staged payload 与 `D:\Eagly\App`。
- [ ] 在 Logbay 界面连接 Pixel 7 Pro，点击“镜像”完成最终实机验收。
- [x] 同步并审查上游 v1.3.0；确认镜像剪贴板、日志跳动与缩放优化已包含，跳过冲突性重复合入。
- [x] 升版到 `1.5.4+54`，运行全量测试、静态分析和 Windows Release 构建。
- [x] 构建并静默安装 `Logbay-1.5.4-windows-setup.exe`，验证覆盖升级与启动。
- [ ] 提交、推送、打 `v1.5.4` 标签并发布 GitHub Release。

## 验收

- 镜像创建失败或停止时不再发生 use-after-free。
- 镜像相关测试通过。
- 新构建可启动，Pixel 7 Pro 点击“镜像”不再导致 Logbay 进程退出。
