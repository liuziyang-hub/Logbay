import 'package:eagly/features/performance/data/performance_sample.dart';
import 'package:eagly/features/performance/data/performance_session.dart';
import 'package:eagly/features/performance/services/performance_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime.utc(2026, 9, 18, 8);

  PerformanceSample sample(
    int second, {
    double? fps,
    double? frameTimeMs,
    int? slowFrames,
    int? frozenFrames,
    double? cpu,
    int? memory,
    int? rx,
    int? tx,
    double? temperature,
  }) {
    return PerformanceSample(
      timestamp: base.add(Duration(seconds: second)),
      elapsed: Duration(seconds: second),
      fps: fps,
      frameTimeMs: frameTimeMs,
      slowFrameCount: slowFrames,
      frozenFrameCount: frozenFrames,
      cpuPercent: cpu,
      memoryBytes: memory,
      networkRxBytes: rx,
      networkTxBytes: tx,
      temperatureCelsius: temperature,
    );
  }

  test('returns an empty summary when no samples are in the interval', () {
    final summary = PerformanceStatistics.summarize(
      const [],
      start: base,
      end: base.add(const Duration(seconds: 10)),
    );

    expect(summary.sampleCount, 0);
    expect(summary.fps, isNull);
    expect(summary.networkRxBytes, isNull);
    expect(summary.temperatureChangeCelsius, isNull);
  });

  test(
    'ignores unavailable values and calculates interpolated percentiles',
    () {
      final summary = PerformanceStatistics.summarize([
        sample(0, fps: 10, cpu: 10),
        sample(1, fps: null, cpu: 20),
        sample(2, fps: 30, cpu: 30),
        sample(3, fps: 50, cpu: 40),
      ]);

      expect(summary.fps?.count, 3);
      expect(summary.fps?.average, closeTo(30, 0.001));
      expect(summary.fps?.p50, closeTo(30, 0.001));
      expect(summary.fps?.p95, closeTo(48, 0.001));
      expect(summary.cpuPercent?.maximum, 40);
    },
  );

  test('uses only samples inside the selected wall-clock interval', () {
    final summary = PerformanceStatistics.summarize(
      [sample(0, cpu: 1), sample(1, cpu: 2), sample(2, cpu: 99)],
      start: base,
      end: base.add(const Duration(seconds: 1)),
    );

    expect(summary.sampleCount, 2);
    expect(summary.cpuPercent?.maximum, 2);
  });

  test('sums frame anomalies and low-fps duration', () {
    final summary = PerformanceStatistics.summarize([
      sample(0, fps: 25, slowFrames: 2, frozenFrames: 0),
      sample(1, fps: 28, slowFrames: 3, frozenFrames: 1),
      sample(3, fps: 60, slowFrames: 0, frozenFrames: 0),
    ]);

    expect(summary.slowFrameCount, 5);
    expect(summary.frozenFrameCount, 1);
    expect(summary.lowFpsDuration, const Duration(seconds: 3));
  });

  test('handles network counter reset without producing a negative delta', () {
    final summary = PerformanceStatistics.summarize([
      sample(0, rx: 1000, tx: 400),
      sample(1, rx: 1600, tx: 800),
      sample(2, rx: 120, tx: 50),
      sample(3, rx: 420, tx: 100),
    ]);

    expect(summary.networkRxBytes, 1020);
    expect(summary.networkTxBytes, 500);
  });

  test('reports temperature change from first to last available sample', () {
    final summary = PerformanceStatistics.summarize([
      sample(0, temperature: 31.2),
      sample(1),
      sample(2, temperature: 34.7),
    ]);

    expect(summary.temperatureChangeCelsius, closeTo(3.5, 0.001));
  });

  test('performance session evicts oldest samples at its bound', () {
    final session = PerformanceSession(
      deviceId: 'device-1',
      applicationId: 'com.example.app',
      startedAt: base,
      maxSamples: 2,
    );

    session
      ..add(sample(0, fps: 60))
      ..add(sample(1, fps: 59))
      ..add(sample(2, fps: 58));

    expect(session.samples.map((item) => item.fps), [59, 58]);
    expect(session.droppedSampleCount, 1);
  });
}
