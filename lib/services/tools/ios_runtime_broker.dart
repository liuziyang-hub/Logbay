import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'pymobiledevice3_launcher.dart';

abstract class IosRuntimeChildProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

class _SystemIosRuntimeChildProcess implements IosRuntimeChildProcess {
  const _SystemIosRuntimeChildProcess(this.process);

  final Process process;

  @override
  Stream<List<int>> get stdout => process.stdout;

  @override
  Stream<List<int>> get stderr => process.stderr;

  @override
  Future<int> get exitCode => process.exitCode;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) =>
      process.kill(signal);
}

class IosRuntimeResult {
  const IosRuntimeResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Coordinates pymobiledevice3 invocations per device and makes timeouts
/// terminate the upstream child process instead of leaving it behind.
class IosRuntimeBroker {
  IosRuntimeBroker({
    Future<Pymobiledevice3Command?> Function()? resolveCommand,
    Future<IosRuntimeChildProcess> Function(
      String executable,
      List<String> arguments, {
      required Map<String, String> environment,
    })?
    startProcess,
  }) : _resolveCommand = resolveCommand ?? Pymobiledevice3Launcher.resolve,
       _startProcess = startProcess ?? _defaultStartProcess;

  static final IosRuntimeBroker instance = IosRuntimeBroker();

  final Future<Pymobiledevice3Command?> Function() _resolveCommand;
  final Future<IosRuntimeChildProcess> Function(
    String executable,
    List<String> arguments, {
    required Map<String, String> environment,
  })
  _startProcess;
  final Map<String, Future<void>> _deviceQueues = {};

  Future<IosRuntimeResult> run(
    String udid,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final previous = _deviceQueues[udid] ?? Future<void>.value();
    final completer = Completer<void>();
    _deviceQueues[udid] = completer.future;
    return previous.catchError((_) {}).then((_) async {
      try {
        final process = await start(udid, arguments);
        final stdoutFuture = process.stdout
            .transform(const Utf8Decoder(allowMalformed: true))
            .join();
        final stderrFuture = process.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .join();
        int exitCode;
        try {
          exitCode = await process.exitCode.timeout(timeout);
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          throw TimeoutException('iOS 运行时命令执行超时。', timeout);
        }
        return IosRuntimeResult(
          exitCode: exitCode,
          stdout: await stdoutFuture,
          stderr: await stderrFuture,
        );
      } finally {
        completer.complete();
        if (identical(_deviceQueues[udid], completer.future)) {
          _deviceQueues.remove(udid);
        }
      }
    });
  }

  Future<String> readFirstLine(
    String udid,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final process = await start(udid, arguments);
    final errors = StringBuffer();
    final errorSubscription = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(errors.writeln);
    try {
      return await process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .firstWhere((line) => line.trim().isNotEmpty)
          .timeout(timeout);
    } on StateError {
      final detail = errors.toString().trim();
      throw StateError(detail.isEmpty ? 'iOS 运行时未返回采样数据。' : detail);
    } finally {
      process.kill(ProcessSignal.sigterm);
      await errorSubscription.cancel();
    }
  }

  Future<IosRuntimeChildProcess> start(
    String udid,
    List<String> arguments,
  ) async {
    final command = await _resolveCommand();
    if (command == null) throw StateError('未找到 iOS 运行时。请重新安装 Logbay。');
    final environment = {...Platform.environment, 'PYMOBILEDEVICE3_UDID': udid};
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      environment.putIfAbsent(
        'UV_CACHE_DIR',
        () => '$localAppData\\Logbay\\uv-cache',
      );
    }
    return _startProcess(
      command.executable,
      command.args(arguments),
      environment: environment,
    );
  }

  static Future<IosRuntimeChildProcess> _defaultStartProcess(
    String executable,
    List<String> arguments, {
    required Map<String, String> environment,
  }) {
    return Process.start(
      executable,
      arguments,
      runInShell: Platform.isWindows,
      environment: environment,
    ).then(_SystemIosRuntimeChildProcess.new);
  }
}
