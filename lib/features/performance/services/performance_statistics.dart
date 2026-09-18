import '../data/performance_interval_summary.dart';
import '../data/performance_sample.dart';

class PerformanceStatistics {
  PerformanceStatistics._();

  static PerformanceIntervalSummary summarize(
    Iterable<PerformanceSample> samples, {
    DateTime? start,
    DateTime? end,
  }) {
    final selected = samples
        .where((sample) {
          if (start != null && sample.timestamp.isBefore(start)) return false;
          if (end != null && sample.timestamp.isAfter(end)) return false;
          return true;
        })
        .toList(growable: false);

    if (selected.isEmpty) {
      return const PerformanceIntervalSummary(sampleCount: 0);
    }

    final slowFrames = _sumNullable(
      selected.map((sample) => sample.slowFrameCount),
    );
    final frozenFrames = _sumNullable(
      selected.map((sample) => sample.frozenFrameCount),
    );
    final temperatures = selected
        .map((sample) => sample.temperatureCelsius)
        .whereType<double>()
        .toList(growable: false);

    return PerformanceIntervalSummary(
      sampleCount: selected.length,
      fps: _statistics(selected.map((sample) => sample.fps)),
      frameTimeMs: _statistics(selected.map((sample) => sample.frameTimeMs)),
      cpuPercent: _statistics(selected.map((sample) => sample.cpuPercent)),
      memoryBytes: _statistics(
        selected.map((sample) => sample.memoryBytes?.toDouble()),
      ),
      temperatureCelsius: _statistics(
        selected.map((sample) => sample.temperatureCelsius),
      ),
      slowFrameCount: slowFrames,
      frozenFrameCount: frozenFrames,
      lowFpsDuration: _lowFpsDuration(selected),
      networkRxBytes: _counterDelta(
        selected.map((sample) => sample.networkRxBytes),
      ),
      networkTxBytes: _counterDelta(
        selected.map((sample) => sample.networkTxBytes),
      ),
      temperatureChangeCelsius: temperatures.length < 2
          ? null
          : temperatures.last - temperatures.first,
    );
  }

  static PerformanceMetricStatistics? _statistics(Iterable<double?> source) {
    final values = source.whereType<double>().toList()..sort();
    if (values.isEmpty) return null;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return PerformanceMetricStatistics(
      count: values.length,
      minimum: values.first,
      maximum: values.last,
      average: total / values.length,
      p50: _percentile(values, 0.5),
      p95: _percentile(values, 0.95),
    );
  }

  static double _percentile(List<double> sorted, double percentile) {
    if (sorted.length == 1) return sorted.single;
    final position = (sorted.length - 1) * percentile;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final fraction = position - lower;
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
  }

  static int? _sumNullable(Iterable<int?> source) {
    var found = false;
    var total = 0;
    for (final value in source) {
      if (value == null) continue;
      found = true;
      total += value;
    }
    return found ? total : null;
  }

  static int? _counterDelta(Iterable<int?> source) {
    final values = source.whereType<int>().toList(growable: false);
    if (values.length < 2) return null;
    var total = 0;
    for (var index = 1; index < values.length; index++) {
      final previous = values[index - 1];
      final current = values[index];
      total += current >= previous ? current - previous : current;
    }
    return total;
  }

  static Duration _lowFpsDuration(List<PerformanceSample> samples) {
    var duration = Duration.zero;
    for (var index = 0; index < samples.length - 1; index++) {
      final fps = samples[index].fps;
      if (fps != null && fps < 30) {
        duration += samples[index + 1].timestamp.difference(
          samples[index].timestamp,
        );
      }
    }
    return duration;
  }
}
