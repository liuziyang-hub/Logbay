import 'dart:io';

import '../../../services/tools/adb_tool.dart';
import '../../../services/tools/tool_process_runner.dart';

abstract class PerfettoTransport {
  Future<ToolCommandResult> shell(
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 10),
  });

  Future<void> pushText(String content, String devicePath);

  Future<void> pull(String devicePath, String localPath);

  Future<List<int>> execOut(List<String> arguments);
}

class AdbPerfettoTransport implements PerfettoTransport {
  AdbPerfettoTransport({required AdbTool adbTool, required this.deviceId})
    : _adbTool = adbTool;

  final AdbTool _adbTool;
  final String deviceId;

  @override
  Future<ToolCommandResult> shell(
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 10),
  }) => _adbTool.runShellCommand(deviceId, arguments, timeout: timeout);

  @override
  Future<void> pushText(String content, String devicePath) async {
    final directory = await Directory.systemTemp.createTemp('logbay-perfetto-');
    final localFile = File(
      '${directory.path}${Platform.pathSeparator}config.pbtx',
    );
    try {
      await localFile.writeAsString(content, flush: true);
      final result = await _adbTool.runAdbCommand([
        '-s',
        deviceId,
        'push',
        localFile.path,
        devicePath,
      ]);
      if (!result.isSuccess) {
        throw StateError('上传 Perfetto 配置失败：${result.combinedOutput}');
      }
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  @override
  Future<void> pull(String devicePath, String localPath) async {
    final result = await _adbTool.runAdbCommand([
      '-s',
      deviceId,
      'pull',
      devicePath,
      localPath,
    ]);
    if (!result.isSuccess) {
      throw StateError('拉取 Perfetto 轨迹失败：${result.combinedOutput}');
    }
  }

  @override
  Future<List<int>> execOut(List<String> arguments) =>
      _adbTool.runAdbBytes(['-s', deviceId, 'exec-out', ...arguments]);
}

class PerfettoCaptureService {
  PerfettoCaptureService({required PerfettoTransport transport})
    : _transport = transport;

  final PerfettoTransport _transport;

  Future<PerfettoCaptureSession> start({
    required String config,
    String? applicationId,
  }) async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final configPath = '/data/local/tmp/logbay-$suffix.pbtx';
    final tracePath =
        '/data/misc/perfetto-traces/logbay-$suffix.perfetto-trace';
    await _transport.pushText(
      _prepareConfig(config, applicationId: applicationId),
      configPath,
    );

    final result = await _transport.shell([
      'perfetto',
      '--background',
      '--txt',
      '-c',
      configPath,
      '-o',
      tracePath,
    ]);
    if (!result.isSuccess) {
      await _remove(configPath);
      throw StateError('启动 Perfetto 录制失败：${result.combinedOutput}');
    }
    final pid = _parseBackgroundPid(result.combinedOutput);
    if (pid == null) {
      await _remove(configPath);
      await _remove(tracePath);
      throw StateError('Perfetto 未返回后台进程 PID，无法可靠管理录制会话。');
    }
    return PerfettoCaptureSession._(
      transport: _transport,
      pid: pid,
      configPath: configPath,
      tracePath: tracePath,
    );
  }

  static int? _parseBackgroundPid(String output) {
    final explicit = RegExp(
      r'(?:pid|process)\D+(\d+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (explicit != null) return int.tryParse(explicit.group(1)!);
    for (final line in output.trim().split(RegExp(r'\r?\n')).reversed) {
      final value = int.tryParse(line.trim());
      if (value != null && value > 0) return value;
    }
    return null;
  }

  static String _prepareConfig(String config, {String? applicationId}) {
    const placeholder = '__LOGBAY_APP_ID__';
    final appId = applicationId?.trim();
    if (appId == null || appId.isEmpty) {
      return config.replaceAll(
        RegExp(
          '^\\s*atrace_apps:\\s*"$placeholder"\\s*\\r?\\n',
          multiLine: true,
        ),
        '',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+$').hasMatch(appId)) {
      throw ArgumentError.value(applicationId, 'applicationId', '应用包名格式无效');
    }
    return config.replaceAll(placeholder, appId);
  }

  Future<void> _remove(String path) async {
    try {
      await _transport.shell(['rm', '-f', path]);
    } catch (_) {}
  }
}

class PerfettoCaptureSession {
  PerfettoCaptureSession._({
    required PerfettoTransport transport,
    required this.pid,
    required this.configPath,
    required this.tracePath,
  }) : _transport = transport;

  final PerfettoTransport _transport;
  final int pid;
  final String configPath;
  final String tracePath;
  bool _finished = false;

  Future<void> stopAndPull(String localPath) async {
    if (_finished) throw StateError('Perfetto 录制会话已经结束。');
    _finished = true;
    try {
      await _transport.shell(['kill', '-INT', '$pid']);
      await _waitUntilStopped();
      try {
        await _transport.pull(tracePath, localPath);
      } catch (_) {
        final bytes = await _transport.execOut(['cat', tracePath]);
        if (bytes.isEmpty) rethrow;
        await File(localPath).writeAsBytes(bytes, flush: true);
      }
    } finally {
      await _cleanup();
    }
  }

  Future<void> cancel() async {
    if (_finished) return;
    _finished = true;
    try {
      await _transport.shell(['kill', '-INT', '$pid']);
    } catch (_) {
      try {
        await _transport.shell(['kill', '-KILL', '$pid']);
      } catch (_) {}
    } finally {
      await _cleanup();
    }
  }

  Future<void> _waitUntilStopped() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final probe = await _transport.shell([
        'kill',
        '-0',
        '$pid',
      ], timeout: const Duration(seconds: 2));
      if (!probe.isSuccess) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    await _transport.shell(['kill', '-KILL', '$pid']);
  }

  Future<void> _cleanup() async {
    for (final path in [configPath, tracePath]) {
      try {
        await _transport.shell(['rm', '-f', path]);
      } catch (_) {}
    }
  }
}
