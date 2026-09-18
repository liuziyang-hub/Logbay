class AndroidCpuSnapshot {
  const AndroidCpuSnapshot({
    required this.totalTicks,
    required this.processTicks,
  });

  final int totalTicks;
  final int processTicks;

  double? usageSince(AndroidCpuSnapshot previous) {
    final totalDelta = totalTicks - previous.totalTicks;
    final processDelta = processTicks - previous.processTicks;
    if (totalDelta <= 0 || processDelta < 0) return null;
    return (processDelta / totalDelta * 100).clamp(0, 100).toDouble();
  }
}

class AndroidProcCpuParser {
  AndroidProcCpuParser._();

  static AndroidCpuSnapshot? parse({
    required String systemStat,
    required String processStat,
  }) {
    final cpuLine = systemStat
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.startsWith('cpu '))
        .firstOrNull;
    if (cpuLine == null) return null;
    final cpuColumns = cpuLine.split(RegExp(r'\s+')).skip(1);
    var totalTicks = 0;
    var systemValues = 0;
    for (final column in cpuColumns) {
      final value = int.tryParse(column);
      if (value == null) break;
      totalTicks += value;
      systemValues++;
    }
    if (systemValues < 4) return null;

    final closingParen = processStat.lastIndexOf(')');
    if (closingParen < 0 || closingParen + 2 >= processStat.length) return null;
    final processColumns = processStat
        .substring(closingParen + 2)
        .trim()
        .split(RegExp(r'\s+'));
    if (processColumns.length <= 14) return null;
    final ticks = <int>[];
    for (final index in const [11, 12, 13, 14]) {
      final value = int.tryParse(processColumns[index]);
      if (value == null) return null;
      ticks.add(value);
    }

    return AndroidCpuSnapshot(
      totalTicks: totalTicks,
      processTicks: ticks.fold(0, (sum, value) => sum + value),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
