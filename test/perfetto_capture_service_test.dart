import 'dart:io';

import 'package:eagly/features/performance/android/perfetto_capture_service.dart';
import 'package:eagly/services/tools/tool_process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePerfettoTransport implements PerfettoTransport {
  final List<List<String>> shellCommands = [];
  String? pushedContent;
  String? pushedPath;
  bool failPull = false;
  List<int> fallbackBytes = const [1, 2, 3, 4];
  int runningProbes = 0;

  @override
  Future<ToolCommandResult> shell(
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    shellCommands.add(List.of(arguments));
    if (arguments.first == 'perfetto') {
      return const ToolCommandResult(
        exitCode: 0,
        stdout: 'Tracing session started. PID: 2468',
        stderr: '',
      );
    }
    if (arguments.length >= 2 &&
        arguments[0] == 'kill' &&
        arguments[1] == '-0') {
      return ToolCommandResult(
        exitCode: runningProbes++ == 0 ? 0 : 1,
        stdout: '',
        stderr: '',
      );
    }
    return const ToolCommandResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<void> pushText(String content, String devicePath) async {
    pushedContent = content;
    pushedPath = devicePath;
  }

  @override
  Future<void> pull(String devicePath, String localPath) async {
    if (failPull) throw StateError('pull unavailable');
    await File(localPath).writeAsBytes(const [9, 8, 7]);
  }

  @override
  Future<List<int>> execOut(List<String> arguments) async => fallbackBytes;
}

void main() {
  test('starts in background and records the returned pid', () async {
    final transport = _FakePerfettoTransport();
    final service = PerfettoCaptureService(transport: transport);

    final session = await service.start(
      config: 'atrace_apps: "__LOGBAY_APP_ID__"\nbuffers: { size_kb: 1024 }',
      applicationId: 'com.example.app',
    );

    expect(session.pid, 2468);
    expect(transport.pushedContent, contains('size_kb'));
    expect(transport.pushedContent, contains('com.example.app'));
    expect(transport.pushedPath, endsWith('.pbtx'));
    expect(transport.shellCommands.single, contains('--background'));
    expect(transport.shellCommands.single, isNot(contains('--alert-id')));
  });

  test(
    'removes the optional app selector when no package is provided',
    () async {
      final transport = _FakePerfettoTransport();
      final service = PerfettoCaptureService(transport: transport);

      await service.start(
        config: 'atrace_apps: "__LOGBAY_APP_ID__"\nbuffers: {}',
      );

      expect(transport.pushedContent, isNot(contains('__LOGBAY_APP_ID__')));
      expect(transport.pushedContent, isNot(contains('atrace_apps')));
    },
  );

  test('stops, waits, pulls and cleans device files', () async {
    final transport = _FakePerfettoTransport();
    final service = PerfettoCaptureService(transport: transport);
    final session = await service.start(config: 'config');
    final directory = await Directory.systemTemp.createTemp('perfetto-test-');
    final output = '${directory.path}${Platform.pathSeparator}trace.bin';
    addTearDown(() => directory.delete(recursive: true));

    await session.stopAndPull(output);

    expect(await File(output).readAsBytes(), [9, 8, 7]);
    expect(
      transport.shellCommands,
      contains(
        predicate<List<String>>((args) => args.join(' ') == 'kill -INT 2468'),
      ),
    );
    expect(
      transport.shellCommands.where((args) => args.first == 'rm'),
      hasLength(2),
    );
  });

  test('falls back to exec-out cat when adb pull is unavailable', () async {
    final transport = _FakePerfettoTransport()..failPull = true;
    final service = PerfettoCaptureService(transport: transport);
    final session = await service.start(config: 'config');
    final directory = await Directory.systemTemp.createTemp('perfetto-test-');
    final output = '${directory.path}${Platform.pathSeparator}trace.bin';
    addTearDown(() => directory.delete(recursive: true));

    await session.stopAndPull(output);

    expect(await File(output).readAsBytes(), transport.fallbackBytes);
  });

  test('cancel terminates the process and removes temporary files', () async {
    final transport = _FakePerfettoTransport();
    final session = await PerfettoCaptureService(
      transport: transport,
    ).start(config: 'config');

    await session.cancel();

    expect(
      transport.shellCommands,
      contains(
        predicate<List<String>>((args) => args.join(' ') == 'kill -INT 2468'),
      ),
    );
    expect(
      transport.shellCommands.where((args) => args.first == 'rm'),
      hasLength(2),
    );
  });
}
