class AndroidNetworkStats {
  const AndroidNetworkStats({
    required this.receiveBytes,
    required this.transmitBytes,
  });

  final int receiveBytes;
  final int transmitBytes;
}

class AndroidNetworkParser {
  AndroidNetworkParser._();

  static AndroidNetworkStats? parseQtaguid(String output, {required int uid}) {
    var found = false;
    var receiveBytes = 0;
    var transmitBytes = 0;
    for (final rawLine in output.split(RegExp(r'\r?\n'))) {
      final columns = rawLine.trim().split(RegExp(r'\s+'));
      if (columns.length < 8 || columns.first == 'idx') continue;
      final rowUid = int.tryParse(columns[3]);
      final rx = int.tryParse(columns[5]);
      final tx = int.tryParse(columns[7]);
      if (rowUid != uid || rx == null || tx == null) continue;
      found = true;
      receiveBytes += rx;
      transmitBytes += tx;
    }
    return found
        ? AndroidNetworkStats(
            receiveBytes: receiveBytes,
            transmitBytes: transmitBytes,
          )
        : null;
  }
}
