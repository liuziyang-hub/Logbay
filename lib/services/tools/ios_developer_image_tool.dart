import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/app_log/app_logger.dart';
import 'pymobiledevice3_launcher.dart';

/// Mounts the Developer Disk Image / DDI cryptex so CoreDevice display
/// (`serve-web`) can advertise `com.apple.coredevice.displayservice`.
class IosDeveloperImageTool {
  IosDeveloperImageTool({AppLogger? logger})
    : _logger = logger ?? AppLogger(source: 'IosDeveloperImageTool');

  final AppLogger _logger;

  static const Duration _attemptTimeout = Duration(minutes: 4);

  /// True when `mounter list` reports at least one mounted image.
  Future<bool> isMounted({required String udid}) async {
    final result = await _run(
      ['mounter', 'list'],
      udid: udid,
      timeout: const Duration(seconds: 30),
    );
    return parseMounted(result.stdout);
  }

  /// Downloads (if needed) and mounts DDI. Tries `mounter auto-mount` twice,
  /// then `cryptex auto-install`.
  Future<void> ensureMounted({
    required String udid,
    void Function(String message)? onProgress,
  }) async {
    if (await isMounted(udid: udid)) return;

    final errors = <String>[];
    for (var i = 1; i <= 2; i++) {
      onProgress?.call('正在挂载开发者镜像（$i/2，可能需要几分钟）…');
      _logger.info('mounter auto-mount attempt $i for $udid');
      final result = await _run(
        ['mounter', 'auto-mount'],
        udid: udid,
        timeout: _attemptTimeout,
      );
      if (await isMounted(udid: udid)) return;
      final detail = _combined(result).trim();
      if (detail.isNotEmpty) errors.add(detail);
    }

    onProgress?.call('改用 cryptex 安装开发者镜像…');
    _logger.info('cryptex auto-install for $udid');
    final cryptex = await _run(
      ['cryptex', 'auto-install'],
      udid: udid,
      timeout: _attemptTimeout,
    );
    if (await isMounted(udid: udid)) return;
    final cryptexDetail = _combined(cryptex).trim();
    if (cryptexDetail.isNotEmpty) errors.add(cryptexDetail);

    throw IosDeveloperImageException(_friendlyFailure(errors.join('\n')));
  }

  @visibleForTesting
  static bool parseMounted(String stdout) {
    final text = stdout.trim();
    if (text.isEmpty || text == '[]') return false;
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded.isNotEmpty;
    } catch (_) {}
    return text.contains('ImageSignature') ||
        text.contains('Personalized') ||
        text.contains('Developer');
  }

  Future<_CmdResult> _run(
    List<String> argv, {
    required String udid,
    required Duration timeout,
  }) async {
    final command = await Pymobiledevice3Launcher.resolve();
    if (command == null) {
      throw IosDeveloperImageException(
        '未找到 pymobiledevice3。请先安装：pip install -U pymobiledevice3',
      );
    }
    final args = command.args(argv);
    _logger.info('${command.executable} ${args.join(' ')}');
    final process = await Process.start(
      command.executable,
      args,
      runInShell: Platform.isWindows,
      environment: {...Platform.environment, 'PYMOBILEDEVICE3_UDID': udid},
    );
    final stdout = StringBuffer();
    final stderr = StringBuffer();
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stdout.write);
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stderr.write);
    final code = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill(ProcessSignal.sigterm);
        return -1;
      },
    );
    final result = _CmdResult(
      exitCode: code,
      stdout: stdout.toString(),
      stderr: stderr.toString(),
    );
    _logger.info(
      'exit $code stdout=${result.stdout.trim()} '
      'stderr=${result.stderr.trim()}',
    );
    return result;
  }

  static String _combined(_CmdResult result) =>
      '${result.stderr}\n${result.stdout}';

  static String _friendlyFailure(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('connection') ||
        lower.contains('urlerror') ||
        lower.contains('timeout') ||
        lower.contains('aborted') ||
        lower.contains('远程主机') ||
        lower.contains('无法连接')) {
      return '无法下载开发者镜像（网络被中断）。\n'
          '请确认可以访问 Apple / GitHub，或配置系统代理后重试。\n'
          '镜像会缓存到用户目录 .pymobiledevice3，成功一次后下次会快很多。\n'
          '原始输出：\n$raw';
    }
    if (raw.trim().isEmpty) {
      return '未能挂载开发者镜像。请开启开发者模式后重试，'
          '并确认网络可下载 Personalized DDI。';
    }
    return '未能挂载开发者镜像：\n$raw';
  }
}

class _CmdResult {
  const _CmdResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class IosDeveloperImageException implements Exception {
  IosDeveloperImageException(this.message);
  final String message;

  @override
  String toString() => message;
}
