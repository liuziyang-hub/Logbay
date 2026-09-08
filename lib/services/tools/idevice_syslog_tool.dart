import 'dart:async';
import 'dart:io';

import '../../features/logs/data/models/log_entry.dart';
import '../../utils/utils.dart';
import '../../features/logs/services/log_parsers/ios_syslog_parser.dart';
import 'tool_process_runner.dart';

class IdeviceSyslogTool extends ToolProcessRunner {
  IdeviceSyslogTool({super.executablePath})
    : super(executableName: 'idevicesyslog');

  ToolStreamSession<LogEntry> start({
    required String deviceId,
    required String processName,
  }) {
    Process? process;
    var stopRequested = false;
    var stopFuture = Future<void>.value();
    late final StreamController<LogEntry> controller;
    final IosSyslogParser parser = IosSyslogParser();

    Future<void> stop() {
      if (stopRequested) {
        return stopFuture;
      }
      stopRequested = true;
      stopFuture = stopProcess(process);
      return stopFuture;
    }

    controller = StreamController<LogEntry>(
      onListen: () async {
        logInfo('Starting idevicesyslog for $processName');
        try {
          // Disable ANSI colors — escape codes break the header regex and
          // cause lines to be dropped before any entry is buffered.
          // Decode path (shared with Android UI fonts): UTF-8 stdout → strip
          // ANSI → decode cat-v \M- escapes → IosSyslogParser.
          process = await startProcess([
            '-u',
            deviceId,
            '--no-colors',
          ]);
          final stderrFuture = stderrText(process!);
          var emittedLogs = false;

          await for (final line in stdoutLines(process!)) {
            for (final entry in parser.addLine(line)) {
              emittedLogs = true;
              controller.add(entry);
            }
          }

          final trailingEntry = parser.flush();
          if (trailingEntry != null) {
            emittedLogs = true;
            controller.add(trailingEntry);
          }

          final stderrOutput = (await stderrFuture).trim();
          if (!emittedLogs && stderrOutput.isNotEmpty) {
            controller.add(
              buildToolErrorEntry(
                stderrOutput,
                tag: 'idevicesyslog',
                processName: processName,
              ),
            );
          }
        } on ProcessException catch (error) {
          logError('Failed to start idevicesyslog for $processName', error);
          controller.add(
            buildToolErrorEntry(
              '启动 idevicesyslog 失败：${describeError(error)}',
              tag: 'idevicesyslog',
              processName: processName,
            ),
          );
        } catch (error) {
          logError(
            'Unexpected error while streaming idevicesyslog for $processName',
            error,
          );
          controller.add(
            buildToolErrorEntry(
              'idevicesyslog 错误：${describeError(error)}',
              tag: 'idevicesyslog',
              processName: processName,
            ),
          );
        } finally {
          logInfo('idevicesyslog stream ended for $processName');
          await stop();
          await controller.close();
        }
      },
      onCancel: stop,
    );

    return ToolStreamSession(stream: controller.stream, onStop: stop);
  }
}
