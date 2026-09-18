import 'dart:async';

import '../../../services/tools/adb_tool.dart';
import '../data/performance_sample.dart';
import '../services/device_performance_backend.dart';
import 'android_live_metrics_collector.dart';

class AndroidPerformanceBackend extends DevicePerformanceBackend {
  AndroidPerformanceBackend({
    required AdbTool adbTool,
    required String deviceId,
  }) : _collector = AndroidLiveMetricsCollector(
         adbTool: adbTool,
         deviceId: deviceId,
       );

  final AndroidLiveMetricsCollector _collector;
  int _generation = 0;

  @override
  Stream<PerformanceSample> start(PerformanceCollectionRequest request) async* {
    final generation = ++_generation;
    final stopwatch = Stopwatch()..start();
    while (generation == _generation) {
      final roundStarted = stopwatch.elapsed;
      yield await _collector.collect(
        applicationId: request.applicationId,
        elapsed: roundStarted,
      );
      final spent = stopwatch.elapsed - roundStarted;
      final remaining = request.sampleInterval - spent;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
  }
}
