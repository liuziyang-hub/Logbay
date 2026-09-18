import 'package:flutter/foundation.dart';

import 'performance_metric.dart';

@immutable
class PerformanceSample {
  const PerformanceSample({
    required this.timestamp,
    required this.elapsed,
    this.fps,
    this.frameTimeMs,
    this.slowFrameCount,
    this.frozenFrameCount,
    this.cpuPercent,
    this.memoryBytes,
    this.networkRxBytes,
    this.networkTxBytes,
    this.temperatureCelsius,
    this.sourceQuality = const {},
    this.unavailableReasons = const {},
  });

  final DateTime timestamp;
  final Duration elapsed;
  final double? fps;
  final double? frameTimeMs;
  final int? slowFrameCount;
  final int? frozenFrameCount;
  final double? cpuPercent;
  final int? memoryBytes;
  final int? networkRxBytes;
  final int? networkTxBytes;
  final double? temperatureCelsius;
  final Map<PerformanceMetric, PerformanceSourceQuality> sourceQuality;
  final Map<PerformanceMetric, String> unavailableReasons;
}
