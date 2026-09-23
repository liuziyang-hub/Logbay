import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/flutter_scrcpy/flutter_scrcpy.dart';

class ExternalScrcpySession {
  ExternalScrcpySession({
    required this.exitCode,
    required Future<void> Function() onStop,
  }) : _onStop = onStop;

  final Future<int> exitCode;
  final Future<void> Function() _onStop;
  bool _stopped = false;

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _onStop();
  }
}

/// Starts the official scrcpy desktop client as a crash-isolated fallback.
class ExternalScrcpyTool {
  const ExternalScrcpyTool({
    required this.executablePath,
    required this.serverPath,
  });

  final String executablePath;
  final String serverPath;

  static List<String> buildArguments(
    String serial,
    ScrcpyVideoOptions options,
  ) => [
    '--serial=$serial',
    '--no-audio',
    '--window-title=Logbay 兼容镜像',
    if (options.maxSize != null) '--max-size=${options.maxSize}',
    if (options.maxFps != null) '--max-fps=${options.maxFps}',
    if (options.videoBitRate != null)
      '--video-bit-rate=${options.videoBitRate}',
  ];

  Future<ExternalScrcpySession> start(
    String serial, {
    required ScrcpyVideoOptions options,
    void Function(String message)? onLog,
  }) async {
    final executable = File(executablePath);
    if (!await executable.exists()) {
      throw StateError('兼容镜像组件缺失，请重新安装 Logbay。');
    }
    final appDirectory = File(Platform.resolvedExecutable).parent.path;
    final process = await Process.start(
      executable.path,
      buildArguments(serial, options),
      workingDirectory: appDirectory,
      environment: {'SCRCPY_SERVER_PATH': serverPath},
    );
    unawaited(process.stdout.drain<void>());
    if (onLog == null) {
      unawaited(process.stderr.drain<void>());
    } else {
      unawaited(
        process.stderr
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())
            .forEach(onLog),
      );
    }
    return ExternalScrcpySession(
      exitCode: process.exitCode,
      onStop: () async {
        process.kill();
        try {
          await process.exitCode.timeout(const Duration(seconds: 3));
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
        }
      },
    );
  }
}
