import 'package:flutter/foundation.dart';

@immutable
class PerformanceMetricStatistics {
  const PerformanceMetricStatistics({
    required this.count,
    required this.minimum,
    required this.maximum,
    required this.average,
    required this.p50,
    required this.p95,
  });

  final int count;
  final double minimum;
  final double maximum;
  final double average;
  final double p50;
  final double p95;
}

@immutable
class PerformanceIntervalSummary {
  const PerformanceIntervalSummary({
    required this.sampleCount,
    this.fps,
    this.frameTimeMs,
    this.cpuPercent,
    this.memoryBytes,
    this.temperatureCelsius,
    this.slowFrameCount,
    this.frozenFrameCount,
    this.lowFpsDuration = Duration.zero,
    this.networkRxBytes,
    this.networkTxBytes,
    this.temperatureChangeCelsius,
  });

  final int sampleCount;
  final PerformanceMetricStatistics? fps;
  final PerformanceMetricStatistics? frameTimeMs;
  final PerformanceMetricStatistics? cpuPercent;
  final PerformanceMetricStatistics? memoryBytes;
  final PerformanceMetricStatistics? temperatureCelsius;
  final int? slowFrameCount;
  final int? frozenFrameCount;
  final Duration lowFpsDuration;
  final int? networkRxBytes;
  final int? networkTxBytes;
  final double? temperatureChangeCelsius;
}
