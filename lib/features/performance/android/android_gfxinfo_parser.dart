class AndroidFrameStats {
  const AndroidFrameStats({
    required this.fps,
    required this.averageFrameTimeMs,
    required this.frameTimesMs,
    required this.slowFrameCount,
    required this.frozenFrameCount,
  });

  final double fps;
  final double averageFrameTimeMs;
  final List<double> frameTimesMs;
  final int slowFrameCount;
  final int frozenFrameCount;
}

class AndroidGfxinfoParser {
  AndroidGfxinfoParser._();

  static AndroidFrameStats? parse(String output) {
    final lines = output.split(RegExp(r'\r?\n'));
    var inProfileData = false;
    final frameTimes = <double>[];
    int? firstIntendedVsync;
    int? lastFrameCompleted;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line == '---PROFILEDATA---') {
        inProfileData = !inProfileData;
        continue;
      }
      if (!inProfileData || line.isEmpty || line.startsWith('Flags,')) {
        continue;
      }
      final columns = line.split(',');
      if (columns.length < 14) continue;
      final intendedVsync = int.tryParse(columns[1].trim());
      final frameCompleted = int.tryParse(columns[13].trim());
      if (intendedVsync == null || frameCompleted == null) continue;
      if (intendedVsync <= 0 || frameCompleted <= intendedVsync) continue;

      final durationMs = (frameCompleted - intendedVsync) / 1000000;
      frameTimes.add(durationMs);
      firstIntendedVsync ??= intendedVsync;
      lastFrameCompleted = frameCompleted;
    }

    if (frameTimes.isEmpty) return null;
    final average =
        frameTimes.fold<double>(0, (sum, value) => sum + value) /
        frameTimes.length;
    final windowSeconds =
        firstIntendedVsync == null || lastFrameCompleted == null
        ? 0.0
        : (lastFrameCompleted - firstIntendedVsync) / 1000000000;
    final fps = windowSeconds > 0
        ? (frameTimes.length / windowSeconds).clamp(0, 240).toDouble()
        : (1000 / average).clamp(0, 240).toDouble();

    return AndroidFrameStats(
      fps: fps,
      averageFrameTimeMs: average,
      frameTimesMs: List.unmodifiable(frameTimes),
      slowFrameCount: frameTimes.where((value) => value > 16.67).length,
      frozenFrameCount: frameTimes.where((value) => value > 700).length,
    );
  }
}
