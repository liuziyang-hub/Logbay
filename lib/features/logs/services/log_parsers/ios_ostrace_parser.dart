import 'dart:convert';

import '../../../../data/device.dart';
import '../../data/models/log_entry.dart';
import '../../data/models/log_level.dart';

/// Parses `pymobiledevice3 syslog live --format json` NDJSON lines into
/// [LogEntry] objects (os_trace_relay / unified logging).
class IosOstraceParser {
  const IosOstraceParser();

  /// Returns a parsed entry, or `null` when [line] is blank / not JSON.
  LogEntry? parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    late final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;
      json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }

    final pid = '${json['pid'] ?? ''}'.trim();
    final tid = '${json['thread_id'] ?? json['tid'] ?? '0'}'.trim();
    final rawLevel = '${json['level'] ?? 'NOTICE'}';
    final level = LogLevel.normalizeIosStoredLevel(rawLevel);
    final message = '${json['message'] ?? ''}'.trim();
    final processName = _processNameFrom(json);
    final parts = _subsystemCategory(json);
    final subsystem = parts.$1;
    final category = parts.$2;
    final tag = _tagFrom(subsystem, category, processName);
    final timestamp = _formatTimestamp(json['timestamp']);

    return LogEntry(
      timestamp: timestamp,
      pid: pid,
      tid: tid.isEmpty ? '0' : tid,
      level: level,
      tag: tag,
      message: message,
      packageName: processName,
      processName: processName,
      subsystem: subsystem.isEmpty ? null : subsystem,
      category: category.isEmpty ? null : category,
      platform: DevicePlatform.ios,
    );
  }

  static String _processNameFrom(Map<String, dynamic> json) {
    final filename = '${json['filename'] ?? ''}'.trim();
    if (filename.isNotEmpty) {
      final slash = filename.replaceAll('\\', '/');
      final base = slash.split('/').last;
      if (base.isNotEmpty) return base;
    }
    final image = '${json['image_name'] ?? ''}'.trim();
    if (image.isNotEmpty) {
      final slash = image.replaceAll('\\', '/');
      final base = slash.split('/').last;
      if (base.isNotEmpty) return base;
    }
    return '';
  }

  static (String, String) _subsystemCategory(Map<String, dynamic> json) {
    final label = json['label'];
    if (label is! Map) return ('', '');
    return (
      '${label['subsystem'] ?? ''}'.trim(),
      '${label['category'] ?? ''}'.trim(),
    );
  }

  static String _tagFrom(
    String subsystem,
    String category,
    String processName,
  ) {
    if (subsystem.isNotEmpty && category.isNotEmpty) {
      return '$subsystem/$category';
    }
    if (subsystem.isNotEmpty) return subsystem;
    if (category.isNotEmpty) return category;
    return processName.isNotEmpty ? processName : 'os_trace';
  }

  static String _formatTimestamp(Object? raw) {
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    try {
      final dt = DateTime.parse(text).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      final ms = dt.millisecond.toString().padLeft(3, '0');
      return '$y-$mo-$d $h:$mi:$s.$ms';
    } catch (_) {
      return text;
    }
  }
}
