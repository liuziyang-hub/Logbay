import 'dart:async';
import 'dart:io';

import '../../../services/tools/pymobiledevice3_launcher.dart';
import '../data/performance_metric.dart';
import '../data/performance_sample.dart';
import '../services/device_performance_backend.dart';
import 'ios_metric_parsers.dart';

abstract class IosMetricsCommandRunner {
  Future<String> run(List<String> arguments, {required String udid});
}

class Pymobiledevice3MetricsCommandRunner implements IosMetricsCommandRunner {
  @override
  Future<String> run(List<String> arguments, {required String udid}) async {
    final command = await Pymobiledevice3Launcher.resolve();
    if (command == null) throw StateError('未找到 iOS 性能采集运行时。');
    final result = await Process.run(
      command.executable,
      command.args(arguments),
      runInShell: Platform.isWindows,
      environment: {...Platform.environment, 'PYMOBILEDEVICE3_UDID': udid},
    ).timeout(const Duration(seconds: 15));
    if (result.exitCode != 0) {
      final detail = '${result.stderr}'.trim();
      throw StateError(detail.isEmpty ? 'iOS 性能采集命令执行失败。' : detail);
    }
    return '${result.stdout}';
  }
}

class IosPerformanceBackend extends DevicePerformanceBackend {
  IosPerformanceBackend({
    required this.deviceId,
    IosMetricsCommandRunner? runner,
  }) : _runner = runner ?? Pymobiledevice3MetricsCommandRunner();

  final String deviceId;
  final IosMetricsCommandRunner _runner;
  int _generation = 0;
  int _emptyRounds = 0;
  int? _previousRx;
  int? _previousTx;

  @override
  Stream<PerformanceSample> start(PerformanceCollectionRequest request) async* {
    final generation = ++_generation;
    final stopwatch = Stopwatch()..start();
    while (generation == _generation) {
      final started = stopwatch.elapsed;
      yield await _collect(request.applicationId, started);
      final spent = stopwatch.elapsed - started;
      final delay = request.sampleInterval - spent;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
    }
  }

  Future<PerformanceSample> _collect(
    String? processName,
    Duration elapsed,
  ) async {
    IosProcessMetrics? process;
    IosSystemMetrics? system;
    final reasons = <PerformanceMetric, String>{};
    try {
      final output = await _runner.run([
        'developer',
        'dvt',
        'sysmon',
        'process',
        'single',
        if (processName != null && processName.trim().isNotEmpty) ...[
          '--filter',
          'name=${processName.trim()}',
        ],
        '--key',
        'name',
        '--key',
        'cpuUsage',
        '--key',
        'physFootprint',
      ], udid: deviceId);
      process = IosMetricParsers.process(
        output,
        processName: processName?.trim(),
      );
    } catch (error) {
      reasons[PerformanceMetric.cpu] = 'iOS 进程指标不可用：$error';
      reasons[PerformanceMetric.memory] = 'iOS 进程指标不可用：$error';
    }
    try {
      final output = await _runner.run([
        'developer',
        'dvt',
        'sysmon',
        'system',
        '--fields',
        'netBytesIn,netBytesOut',
      ], udid: deviceId);
      system = IosMetricParsers.system(output);
    } catch (error) {
      reasons[PerformanceMetric.networkReceive] = 'iOS 网络指标不可用：$error';
      reasons[PerformanceMetric.networkTransmit] = 'iOS 网络指标不可用：$error';
    }

    if (process == null && system == null) {
      _emptyRounds++;
      if (_emptyRounds >= 2) Pymobiledevice3Launcher.resetCache();
    } else {
      _emptyRounds = 0;
    }
    if (process == null) {
      reasons.putIfAbsent(PerformanceMetric.cpu, () => '目标进程未运行或未返回 CPU 数据。');
      reasons.putIfAbsent(PerformanceMetric.memory, () => '目标进程未运行或未返回内存数据。');
    }
    final rx = system?.networkRxBytes;
    final tx = system?.networkTxBytes;
    final rxDelta = rx == null || _previousRx == null
        ? null
        : rx - _previousRx!;
    final txDelta = tx == null || _previousTx == null
        ? null
        : tx - _previousTx!;
    _previousRx = rx;
    _previousTx = tx;
    reasons[PerformanceMetric.fps] = '当前设备未提供稳定的 Graphics 帧率流。';
    reasons[PerformanceMetric.frameTime] = '当前设备未提供逐帧耗时。';
    reasons[PerformanceMetric.temperature] = '温度需设备支持电池诊断通道。';

    return PerformanceSample(
      timestamp: DateTime.now(),
      elapsed: elapsed,
      cpuPercent: process?.cpuPercent,
      memoryBytes: process?.memoryBytes,
      networkRxBytes: rxDelta == null ? null : (rxDelta < 0 ? 0 : rxDelta),
      networkTxBytes: txDelta == null ? null : (txDelta < 0 ? 0 : txDelta),
      sourceQuality: {
        if (process != null)
          PerformanceMetric.cpu: PerformanceSourceQuality.precise,
        if (process != null)
          PerformanceMetric.memory: PerformanceSourceQuality.precise,
        if (rxDelta != null)
          PerformanceMetric.networkReceive: PerformanceSourceQuality.estimated,
        if (txDelta != null)
          PerformanceMetric.networkTransmit: PerformanceSourceQuality.estimated,
      },
      unavailableReasons: reasons,
    );
  }

  @override
  Future<void> stop() async {
    _generation++;
  }
}
