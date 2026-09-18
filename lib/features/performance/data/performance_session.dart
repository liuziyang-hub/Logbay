import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'performance_sample.dart';

class PerformanceSession {
  PerformanceSession({
    required this.deviceId,
    required this.applicationId,
    required this.startedAt,
    this.sampleInterval = const Duration(seconds: 1),
    this.maxSamples = 1800,
  }) : assert(maxSamples > 0);

  final String deviceId;
  final String? applicationId;
  final DateTime startedAt;
  final Duration sampleInterval;
  final int maxSamples;

  final Queue<PerformanceSample> _samples = Queue<PerformanceSample>();
  DateTime? endedAt;
  int droppedSampleCount = 0;

  List<PerformanceSample> get samples =>
      List<PerformanceSample>.unmodifiable(_samples);

  bool get isRunning => endedAt == null;

  void add(PerformanceSample sample) {
    if (!isRunning) {
      throw StateError('性能采集会话已经结束，不能继续写入采样点。');
    }
    _samples.addLast(sample);
    while (_samples.length > maxSamples) {
      _samples.removeFirst();
      droppedSampleCount++;
    }
  }

  void finish([DateTime? at]) {
    endedAt ??= at ?? DateTime.now();
  }

  @visibleForTesting
  void clear() {
    _samples.clear();
    droppedSampleCount = 0;
  }
}
