import '../data/performance_metric.dart';
import '../data/performance_sample.dart';

class PerformanceCollectionRequest {
  const PerformanceCollectionRequest({
    this.applicationId,
    this.sampleInterval = const Duration(seconds: 1),
  });

  final String? applicationId;
  final Duration sampleInterval;
}

abstract class DevicePerformanceBackend {
  const DevicePerformanceBackend();

  Stream<PerformanceSample> start(PerformanceCollectionRequest request);

  Future<void> stop();

  Future<void> dispose() => stop();
}

class UnavailableDevicePerformanceBackend extends DevicePerformanceBackend {
  const UnavailableDevicePerformanceBackend(this.reason);

  final String reason;

  @override
  Stream<PerformanceSample> start(PerformanceCollectionRequest request) {
    final now = DateTime.now();
    return Stream<PerformanceSample>.value(
      PerformanceSample(
        timestamp: now,
        elapsed: Duration.zero,
        unavailableReasons: {
          for (final metric in PerformanceMetric.values) metric: reason,
        },
      ),
    );
  }

  @override
  Future<void> stop() async {}
}
