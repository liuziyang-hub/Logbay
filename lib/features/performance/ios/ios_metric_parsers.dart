import 'dart:convert';

class IosProcessMetrics {
  const IosProcessMetrics({
    required this.cpuPercent,
    required this.memoryBytes,
    this.diskReadBytes,
    this.diskWrittenBytes,
  });

  final double cpuPercent;
  final int memoryBytes;
  final int? diskReadBytes;
  final int? diskWrittenBytes;
}

class IosSystemMetrics {
  const IosSystemMetrics({
    required this.networkRxBytes,
    required this.networkTxBytes,
  });

  final int networkRxBytes;
  final int networkTxBytes;
}

abstract final class IosMetricParsers {
  static IosProcessMetrics? process(String line, {String? processName}) {
    final decoded = _decode(line);
    final candidates = decoded is List ? decoded : [decoded];
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final map = candidate.map((key, value) => MapEntry('$key', value));
      final name = '${map['name'] ?? map['comm'] ?? ''}';
      if (processName != null && name != processName) continue;
      final cpu = _number(map['cpuUsage']);
      final memory = _integer(
        map['physFootprint'] ?? map['physicalFootprint'] ?? map['residentSize'],
      );
      if (cpu == null || memory == null) continue;
      return IosProcessMetrics(
        cpuPercent: cpu,
        memoryBytes: memory,
        diskReadBytes: _integer(map['diskBytesRead']),
        diskWrittenBytes: _integer(map['diskBytesWritten']),
      );
    }
    return null;
  }

  static IosSystemMetrics? system(String line) {
    final decoded = _decode(line);
    final map = decoded is Map
        ? decoded.map((key, value) => MapEntry('$key', value))
        : _keyValueLines(line);
    final rx = _integer(map['netBytesIn']);
    final tx = _integer(map['netBytesOut']);
    if (rx == null || tx == null) return null;
    return IosSystemMetrics(networkRxBytes: rx, networkTxBytes: tx);
  }

  static double? temperatureCelsius(String line) {
    final decoded = _decode(line);
    if (decoded is! Map) return null;
    final raw = _number(decoded['Temperature'] ?? decoded['temperature']);
    if (raw == null) return null;
    return raw > 200 ? raw / 100 : raw;
  }

  static double? fps(String line) {
    final decoded = _decode(line);
    if (decoded is num) return decoded.toDouble();
    if (decoded is! Map) return null;
    return _number(
      decoded['fps'] ??
          decoded['FPS'] ??
          decoded['frameRate'] ??
          decoded['CoreAnimationFramesPerSecond'],
    );
  }

  static Map<String, Object?> _keyValueLines(String source) {
    final result = <String, Object?>{};
    for (final line in const LineSplitter().convert(source)) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      result[key] = num.tryParse(value) ?? value;
    }
    return result;
  }

  static Object? _decode(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      final normalized = trimmed
          .replaceAll("'", '"')
          .replaceAllMapped(
            RegExp(r'([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)'),
            (match) => '${match.group(1)}"${match.group(2)}"${match.group(3)}',
          )
          .replaceAll(': True', ': true')
          .replaceAll(': False', ': false')
          .replaceAll(': None', ': null');
      try {
        return jsonDecode(normalized);
      } catch (_) {
        return null;
      }
    }
  }

  static double? _number(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };

  static int? _integer(Object? value) => switch (value) {
    int number => number,
    num number => number.round(),
    String text => num.tryParse(text)?.round(),
    _ => null,
  };
}
