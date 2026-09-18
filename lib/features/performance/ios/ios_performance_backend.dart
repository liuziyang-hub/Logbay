import 'dart:async';
import '../../../services/tools/ios_runtime_broker.dart';
import '../../../services/tools/pymobiledevice3_launcher.dart';
import '../data/performance_metric.dart';
import '../data/performance_sample.dart';
import '../services/device_performance_backend.dart';
import 'ios_metric_parsers.dart';

abstract class IosMetricsCommandRunner {
  Future<String> run(List<String> arguments, {required String udid});

  Future<String> runFirstLine(List<String> arguments, {required String udid});
}

class Pymobiledevice3MetricsCommandRunner implements IosMetricsCommandRunner {
  Pymobiledevice3MetricsCommandRunner({IosRuntimeBroker? broker})
    : _broker = broker ?? IosRuntimeBroker.instance;

  final IosRuntimeBroker _broker;

  @override
  Future<String> run(List<String> arguments, {required String udid}) async {
    final result = await _broker.run(
      udid,
      arguments,
      timeout: const Duration(seconds: 90),
      serialize: false,
    );
    if (result.exitCode != 0) {
      final detail = result.stderr.trim();
      throw StateError(detail.isEmpty ? 'iOS 性能采集命令执行失败。' : detail);
    }
    return result.stdout;
  }

  @override
  Future<String> runFirstLine(List<String> arguments, {required String udid}) =>
      _broker.readFirstLine(udid, arguments);
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
    double? fps;
    double? temperature;
    final reasons = <PerformanceMetric, String>{};
    await Future.wait([
      () async {
        if (processName == null || processName.trim().isEmpty) {
          reasons[PerformanceMetric.cpu] = '请输入应用包名或进程名后采集。';
          reasons[PerformanceMetric.memory] = '请输入应用包名或进程名后采集。';
          return;
        }
        try {
          final filter = await _resolveProcessFilter(processName);
          final output = await _runner.run([
            'developer',
            'dvt',
            'sysmon',
            'process',
            'single',
            if (filter != null) ...['--filter', filter],
            '--key',
            'name',
            '--key',
            'cpuUsage',
            '--key',
            'physFootprint',
            '--userspace',
          ], udid: deviceId);
          process = IosMetricParsers.process(output);
        } catch (error) {
          reasons[PerformanceMetric.cpu] = 'iOS 进程指标不可用：$error';
          reasons[PerformanceMetric.memory] = 'iOS 进程指标不可用：$error';
        }
      }(),
      () async {
        try {
          final output = await _runner.run([
            'developer',
            'dvt',
            'sysmon',
            'system',
            '--fields',
            'netBytesIn,netBytesOut',
            '--userspace',
          ], udid: deviceId);
          system = IosMetricParsers.system(output);
        } catch (error) {
          reasons[PerformanceMetric.networkReceive] = 'iOS 网络指标不可用：$error';
          reasons[PerformanceMetric.networkTransmit] = 'iOS 网络指标不可用：$error';
        }
      }(),
      () async {
        try {
          final output = await _runner.runFirstLine([
            'developer',
            'dvt',
            'graphics',
            '--userspace',
          ], udid: deviceId);
          fps = IosMetricParsers.fps(output);
        } catch (error) {
          reasons[PerformanceMetric.fps] = 'iOS 帧率指标不可用：$error';
        }
      }(),
      () async {
        try {
          final output = await _runner.runFirstLine([
            'diagnostics',
            'battery',
            'monitor',
          ], udid: deviceId);
          temperature = IosMetricParsers.temperatureCelsius(output);
        } catch (error) {
          reasons[PerformanceMetric.temperature] = 'iOS 温度指标不可用：$error';
        }
      }(),
    ]);

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
    if (fps == null) {
      reasons.putIfAbsent(PerformanceMetric.fps, () => '设备未返回 Graphics 帧率数据。');
    }
    if (fps == null) {
      reasons[PerformanceMetric.frameTime] = '当前设备未提供逐帧耗时。';
    }
    if (temperature == null) {
      reasons.putIfAbsent(PerformanceMetric.temperature, () => '设备未返回电池温度数据。');
    }

    return PerformanceSample(
      timestamp: DateTime.now(),
      elapsed: elapsed,
      fps: fps,
      frameTimeMs: fps == null || fps! <= 0 ? null : 1000 / fps!,
      cpuPercent: process?.cpuPercent,
      memoryBytes: process?.memoryBytes,
      networkRxBytes: rxDelta == null ? null : (rxDelta < 0 ? 0 : rxDelta),
      networkTxBytes: txDelta == null ? null : (txDelta < 0 ? 0 : txDelta),
      temperatureCelsius: temperature,
      sourceQuality: {
        if (fps != null)
          PerformanceMetric.fps: PerformanceSourceQuality.precise,
        if (fps != null)
          PerformanceMetric.frameTime: PerformanceSourceQuality.estimated,
        if (process != null)
          PerformanceMetric.cpu: PerformanceSourceQuality.precise,
        if (process != null)
          PerformanceMetric.memory: PerformanceSourceQuality.precise,
        if (rxDelta != null)
          PerformanceMetric.networkReceive: PerformanceSourceQuality.estimated,
        if (txDelta != null)
          PerformanceMetric.networkTransmit: PerformanceSourceQuality.estimated,
        if (temperature != null)
          PerformanceMetric.temperature: PerformanceSourceQuality.precise,
      },
      unavailableReasons: reasons,
    );
  }

  Future<String?> _resolveProcessFilter(String? target) async {
    final value = target?.trim();
    if (value == null || value.isEmpty) return null;
    if (!value.contains('.')) return 'name=$value';
    final output = await _runner.run([
      'developer',
      'dvt',
      'process-id-for-bundle-id',
      value,
      '--userspace',
    ], udid: deviceId);
    final pid = RegExp(r'\b\d+\b').firstMatch(output)?.group(0);
    if (pid == null) throw StateError('目标应用尚未运行：$value');
    return 'pid=$pid';
  }

  @override
  Future<void> stop() async {
    _generation++;
  }
}
