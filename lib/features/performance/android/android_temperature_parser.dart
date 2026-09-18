class AndroidTemperatureParser {
  AndroidTemperatureParser._();

  static double? parseThermalService(String output) {
    final values = <double>[];
    final patterns = [
      RegExp(r'mValue\s*=\s*(-?\d+(?:\.\d+)?)'),
      RegExp(r'value\s*[=:]\s*(-?\d+(?:\.\d+)?)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(output)) {
        final value = double.tryParse(match.group(1)!);
        if (value != null && value > -30 && value < 150) values.add(value);
      }
      if (values.isNotEmpty) break;
    }
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left > right ? left : right);
  }

  static double? parseBattery(String output) {
    final match = RegExp(
      r'temperature\s*:\s*(-?\d+)',
      caseSensitive: false,
    ).firstMatch(output);
    final raw = match == null ? null : int.tryParse(match.group(1)!);
    return raw == null ? null : raw / 10;
  }
}
