class AndroidAppMemoryStats {
  const AndroidAppMemoryStats({
    required this.pssKb,
    this.rssKb,
    this.javaHeapKb,
    this.nativeHeapKb,
  });

  final int pssKb;
  final int? rssKb;
  final int? javaHeapKb;
  final int? nativeHeapKb;
}

class AndroidMeminfoParser {
  AndroidMeminfoParser._();

  static AndroidAppMemoryStats? parse(String output) {
    int? pss;
    int? rss;
    int? javaHeap;
    int? nativeHeap;

    final totalPss = RegExp(
      r'TOTAL\s+PSS:\s*(\d+).*?TOTAL\s+RSS:\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (totalPss != null) {
      pss = int.tryParse(totalPss.group(1)!);
      rss = int.tryParse(totalPss.group(2)!);
    }

    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      final columns = line.split(RegExp(r'\s+'));
      if (columns.isEmpty) continue;
      if (line.startsWith('TOTAL ') && pss == null && columns.length > 1) {
        pss = int.tryParse(columns[1]);
      } else if (line.startsWith('Java Heap:')) {
        javaHeap = _lastNumber(line);
      } else if (line.startsWith('Native Heap:')) {
        nativeHeap = _lastNumber(line);
      }
    }

    if (pss == null) return null;
    return AndroidAppMemoryStats(
      pssKb: pss,
      rssKb: rss,
      javaHeapKb: javaHeap,
      nativeHeapKb: nativeHeap,
    );
  }

  static int? _lastNumber(String line) {
    final matches = RegExp(r'\d+').allMatches(line).toList(growable: false);
    return matches.isEmpty ? null : int.tryParse(matches.last.group(0)!);
  }
}
