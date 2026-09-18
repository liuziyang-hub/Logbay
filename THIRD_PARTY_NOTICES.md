# 第三方组件声明

Logbay 通过独立进程调用以下上游工具。各组件仍遵循其原始许可证，
Logbay 不宣称拥有这些项目的著作权。

## Android Platform Tools (ADB)

- 来源：https://developer.android.com/tools/releases/platform-tools
- 许可证：Android SDK License / Apache-2.0（按组件适用）
- 用途：Android 设备发现、日志、安装、文件和性能命令。

## Perfetto Trace Processor

- 版本：55.3
- 来源：https://github.com/google/perfetto
- 许可证：Apache-2.0
- 用途：录制并解析 Android Perfetto 性能轨迹。

## pymobiledevice3

- 固定版本：11.15.4
- 来源：https://github.com/doronz88/pymobiledevice3
- 许可证：GPL-3.0
- 用途：iOS 17+ 调试隧道、DVT 性能数据、Developer Disk Image 和实时投屏。
- 分发方式：由独立的 `uv` 运行时管理器从 PyPI 获取固定版本，程序仅通过命令行调用。
  对应源码可从上述仓库及 PyPI 版本页面取得。

## uv

- 固定版本：0.11.28
- 来源：https://github.com/astral-sh/uv
- 许可证：Apache-2.0 OR MIT
- 用途：按固定版本获取并隔离 pymobiledevice3，不把完整 Python 环境塞入安装包。

## libimobiledevice

- 来源：https://github.com/libimobiledevice/libimobiledevice
- 许可证：LGPL-2.1-or-later
- 用途：传统 iOS 设备发现、日志、安装、截图和文件访问。

完整许可证文本和依赖清单应随 Release 源代码一并提供；发布前由
`scripts/verify_runtime_manifest.ps1` 校验运行时文件完整性。
