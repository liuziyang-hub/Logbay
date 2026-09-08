import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/app_log/app_logger.dart';
import '../../features/logs/data/models/log_entry.dart';
import '../../features/logs/data/models/log_level.dart';
import '../../features/logs/services/log_parsers/ios_ostrace_parser.dart';
import '../../utils/log_entry_utils.dart';
import '../../utils/utils.dart';
import 'tool_process_runner.dart';

/// Streams iOS unified logging via `pymobiledevice3 syslog live --format json`
/// (os_trace_relay). Callers fall back to `idevicesyslog` when unavailable.
class IosUnifiedLogTool {
  IosUnifiedLogTool({AppLogger? logger})
    : _logger = logger ?? AppLogger(source: 'IosUnifiedLogTool');

  final AppLogger _logger;
  final IosOstraceParser _parser = const IosOstraceParser();

  /// Cached probe of whether pymobiledevice3 can be launched on this machine.
  static Future<bool>? _availabilityFuture;

  /// True when `pymobiledevice3` (or `python -m pymobiledevice3`) is runnable.
  static Future<bool> isAvailable() {
    return _availabilityFuture ??= _probeAvailability();
  }

  /// Clears the cached availability probe (tests / after install).
  @visibleForTesting
  static void resetAvailabilityCache() {
    _availabilityFuture = null;
  }

  static Future<bool> _probeAvailability() async {
    final command = await _resolveCommand();
    return command != null;
  }

  static Future<_PymobileCommand?> _resolveCommand() async {
    for (final candidate in _candidateCommands()) {
      try {
        final result = await Process.run(
          candidate.executable,
          [...candidate.prefixArgs, '--help'],
          runInShell: Platform.isWindows,
        );
        final out = '${result.stdout}\n${result.stderr}'.toLowerCase();
        if (result.exitCode == 0 ||
            out.contains('syslog') ||
            out.contains('usage') ||
            out.contains('pymobiledevice3')) {
          return candidate;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static List<_PymobileCommand> _candidateCommands() {
    if (Platform.isWindows) {
      return const [
        _PymobileCommand('pymobiledevice3', []),
        _PymobileCommand('py', ['-3', '-m', 'pymobiledevice3']),
        _PymobileCommand('python', ['-m', 'pymobiledevice3']),
        _PymobileCommand('python3', ['-m', 'pymobiledevice3']),
      ];
    }
    return const [
      _PymobileCommand('pymobiledevice3', []),
      _PymobileCommand('python3', ['-m', 'pymobiledevice3']),
      _PymobileCommand('python', ['-m', 'pymobiledevice3']),
    ];
  }

  LogEntry _toolError(
    String message, {
    required String tag,
    required String processName,
  }) {
    return LogEntryUtils.buildToolError(
      message: message,
      tag: tag,
      processName: processName,
    );
  }

  ToolStreamSession<LogEntry> start({
    required String deviceId,
    required String processName,
  }) {
    Process? process;
    var stopRequested = false;
    var stopFuture = Future<void>.value();
    late final StreamController<LogEntry> controller;

    Future<void> stop() {
      if (stopRequested) return stopFuture;
      stopRequested = true;
      stopFuture = _stopProcess(process);
      return stopFuture;
    }

    controller = StreamController<LogEntry>(
      onListen: () async {
        _logger.info('Starting pymobiledevice3 syslog live for $processName');
        try {
          final command = await _resolveCommand();
          if (command == null) {
            controller.add(
              _toolError(
                '未找到 pymobiledevice3。请安装后重试，或关闭「iOS 统一日志」以使用 idevicesyslog。\n'
                'pip install -U pymobiledevice3',
                tag: 'os_trace',
                processName: processName,
              ),
            );
            return;
          }

          final args = [
            ...command.prefixArgs,
            'syslog',
            'live',
            '--udid',
            deviceId,
            '--format',
            'json',
          ];

          process = await Process.start(
            command.executable,
            args,
            runInShell: Platform.isWindows,
          );

          controller.add(
            LogEntryUtils.buildSpecial(
              type: LogEntryType.notice,
              timestamp: '',
              tag: 'os_trace',
              level: LogLevel.info.code,
              message: '已使用统一日志通道（pymobiledevice3 / os_trace_relay）',
              processName: processName,
            ),
          );

          final stderrFuture = process!.stderr
              .transform(const Utf8Decoder(allowMalformed: true))
              .join();
          var emittedLogs = false;

          await for (final line
              in process!.stdout
                  .transform(const Utf8Decoder(allowMalformed: true))
                  .transform(const LineSplitter())) {
            final parsed = _parser.parseLine(line);
            if (parsed == null) continue;
            emittedLogs = true;
            controller.add(parsed);
          }

          final stderrOutput = (await stderrFuture).trim();
          if (!emittedLogs && stderrOutput.isNotEmpty) {
            controller.add(
              _toolError(
                stderrOutput,
                tag: 'os_trace',
                processName: processName,
              ),
            );
          }
        } on ProcessException catch (error) {
          _logger.error(
            'Failed to start pymobiledevice3 syslog',
            detail: error.toString(),
          );
          controller.add(
            _toolError(
              '启动统一日志失败：${describeError(error)}',
              tag: 'os_trace',
              processName: processName,
            ),
          );
        } catch (error) {
          _logger.error(
            'Unexpected os_trace stream error',
            detail: error.toString(),
          );
          controller.add(
            _toolError(
              '统一日志错误：${describeError(error)}',
              tag: 'os_trace',
              processName: processName,
            ),
          );
        } finally {
          _logger.info('os_trace stream ended for $processName');
          await stop();
          await controller.close();
        }
      },
      onCancel: stop,
    );

    return ToolStreamSession(stream: controller.stream, onStop: stop);
  }

  Future<void> _stopProcess(Process? process) async {
    if (process == null) return;
    if (process.kill(ProcessSignal.sigterm)) {
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }
}

class _PymobileCommand {
  const _PymobileCommand(this.executable, this.prefixArgs);

  final String executable;
  final List<String> prefixArgs;
}
