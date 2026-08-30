import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _gistUrl =
    'https://gist.githubusercontent.com/adamawolf/3048717/raw/b828efca2bcdca272cdb3f43e77dcff7d9eff51d/Apple_mobile_device_types.txt';

Map<String, String>? _cachedMap;

/// Attempts to load the Apple device mapping.
///
/// Behavior:
/// - If a cached copy exists in ~/.eagly/apple_device_types.txt it will be used.
/// - Otherwise the mapping is fetched from the gist URL above and cached.
/// - On any failure an empty map is returned so callers can gracefully fall back.
Future<Map<String, String>> _loadAppleDeviceMap() async {
  if (_cachedMap != null) return _cachedMap!;

  try {
    final home = Platform.environment['HOME'] ?? '';
    final cacheDir = Directory(
      home.isNotEmpty ? '$home${Platform.pathSeparator}.eagly' : '.',
    );
    final cacheFile = File(
      '${cacheDir.path}${Platform.pathSeparator}apple_device_types.txt',
    );

    String content;
    if (await cacheFile.exists()) {
      content = await cacheFile.readAsString();
    } else {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(_gistUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch Apple device mapping (status ${response.statusCode}).',
        );
      }
      content = await response.transform(utf8.decoder).join();
      try {
        await cacheDir.create(recursive: true);
        await cacheFile.writeAsString(content);
      } catch (_) {
        // Ignore cache write errors.
      }
    }

    final map = <String, String>{};
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;

      // Try common separators: ':' '=' '-' or multiple spaces/tabs.
      final m = RegExp(r'^(\S+)\s*[:=\-]\s*(.+)?').firstMatch(line);
      if (m != null) {
        map[m.group(1)!] = m.group(2)!.trim();
        continue;
      }

      // Fallback: split on two or more spaces or a tab.
      final parts = line.split(RegExp(r'\t| {2,}'));
      if (parts.length >= 2) {
        map[parts[0]] = parts.sublist(1).join(' ').trim();
      }
    }

    _cachedMap = map;
    return _cachedMap!;
  } catch (_) {
    _cachedMap = <String, String>{};
    return _cachedMap!;
  }
}

/// Returns a human-readable Apple product name for [code] (e.g. "iPhone7,2").
/// Returns null when no mapping is available.
Future<String?> getAppleDeviceName(String code) async {
  final map = await _loadAppleDeviceMap();
  return map[code];
}
