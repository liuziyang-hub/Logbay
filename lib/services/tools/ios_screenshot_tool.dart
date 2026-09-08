import 'dart:io';
import 'dart:typed_data';

import '../../features/app_log/app_logger.dart';
import '../../utils/tools_path.dart';
import 'pymobiledevice3_launcher.dart';

/// Captures an iOS framebuffer PNG via pymobiledevice3 (preferred) or
/// bundled `idevicescreenshot`.
class IosScreenshotTool {
  IosScreenshotTool({AppLogger? logger})
    : _logger = logger ?? AppLogger(source: 'IosScreenshotTool');

  final AppLogger _logger;

  /// Returns PNG bytes, or throws [IosScreenshotException].
  Future<Uint8List> capture({required String udid}) async {
    final tempDir = await Directory.systemTemp.createTemp('eagly-ios-shot-');
    final outPath = '${tempDir.path}${Platform.pathSeparator}screen.png';
    try {
      final pmd3Error = await _tryPymobiledevice3(udid: udid, outPath: outPath);
      if (pmd3Error == null && await File(outPath).exists()) {
        return await File(outPath).readAsBytes();
      }

      final ideviceError = await _tryIdeviceScreenshot(
        udid: udid,
        outPath: outPath,
      );
      if (ideviceError == null && await File(outPath).exists()) {
        return await File(outPath).readAsBytes();
      }

      final detail = [
        if (pmd3Error != null) pmd3Error,
        if (ideviceError != null) ideviceError,
      ].join('\n');
      throw IosScreenshotException(
        detail.isEmpty ? '无法截取 iOS 屏幕。' : '无法截取 iOS 屏幕：\n$detail',
      );
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Tries DVT screenshot first, then core-device screen-capture.
  Future<String?> _tryPymobiledevice3({
    required String udid,
    required String outPath,
  }) async {
    final command = await Pymobiledevice3Launcher.resolve();
    if (command == null) {
      return '未安装 pymobiledevice3';
    }

    final attempts = <List<String>>[
      // Classic DVT path (needs Developer Disk Image / developer mode).
      ['developer', 'dvt', 'screenshot', outPath, '--udid', udid],
      // iOS 17+ CoreDevice path (needs userspace/RSD tunnel in some setups).
      [
        'developer',
        'core-device',
        'screen-capture',
        'screenshot',
        outPath,
        '--udid',
        udid,
      ],
      [
        'developer',
        'core-device',
        'screen-capture',
        'screenshot',
        outPath,
        '--tunnel',
        udid,
        '--userspace',
      ],
    ];

    String? lastError;
    for (final argv in attempts) {
      final args = command.args(argv);
      _logger.info('iOS screenshot: ${command.executable} ${args.join(' ')}');
      final result = await Process.run(
        command.executable,
        args,
        runInShell: Platform.isWindows,
      );
      if (result.exitCode == 0 && await File(outPath).exists()) {
        return null;
      }
      lastError = _combined(result).trim();
      if (lastError.isEmpty) {
        lastError = 'exit ${result.exitCode}';
      }
    }
    return lastError;
  }

  Future<String?> _tryIdeviceScreenshot({
    required String udid,
    required String outPath,
  }) async {
    final executable =
        resolveBundledExecutablePath('idevicescreenshot') ??
        'idevicescreenshot';
    try {
      final result = await Process.run(executable, [
        '-u',
        udid,
        outPath,
      ], runInShell: Platform.isWindows);
      if (result.exitCode == 0 && await File(outPath).exists()) {
        return null;
      }
      final detail = _combined(result).trim();
      return detail.isEmpty
          ? 'idevicescreenshot 失败（exit ${result.exitCode}）'
          : detail;
    } catch (error) {
      return 'idevicescreenshot 不可用：$error';
    }
  }

  static String _combined(ProcessResult result) {
    final out = result.stdout is String ? result.stdout as String : '';
    final err = result.stderr is String ? result.stderr as String : '';
    if (out.isEmpty) return err;
    if (err.isEmpty) return out;
    return '$out\n$err';
  }
}

class IosScreenshotException implements Exception {
  IosScreenshotException(this.message);
  final String message;

  @override
  String toString() => message;
}
