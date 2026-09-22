import '../../../../data/device.dart';
import '../../../../utils/log_entry_id_generator.dart';

enum LogEntryType {
  log('日志'),
  started('已开始'),
  resumed('已恢复'),
  paused('已暂停'),
  stopped('已停止'),
  error('发生错误'),
  notice('通知');

  const LogEntryType(this.label);

  final String label;

  bool get isSpecial => this != LogEntryType.log;
}

final RegExp _fullTimestampPattern = RegExp(
  r'^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})(?:\.(\d+))?$',
);

final RegExp _shortTimestampPattern = RegExp(
  r'^(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})(?:\.(\d+))?$',
);

class LogEntry {
  final int id;
  final LogEntryType type;
  final DevicePlatform platform;
  final String timestamp;
  final String pid;
  final String tid;
  final String level;
  final String tag;
  final String message;
  String? packageName;
  String? processName;
  /// iOS unified logging (`os_trace`) subsystem, when present.
  final String? subsystem;
  /// iOS unified logging category, when present.
  final String? category;
  final DateTime? _referenceTime;

  LogEntry({
    int? id,
    this.type = LogEntryType.log,
    this.platform = DevicePlatform.android,
    required this.timestamp,
    required this.pid,
    required this.tid,
    required this.level,
    required this.tag,
    required this.message,
    this.packageName,
    this.processName,
    this.subsystem,
    this.category,
    DateTime? now,
  }) : id = id ?? LogEntryIdGenerator.instance.next(),
       _referenceTime = now;

  /// [timestamp] parsed into a local [DateTime], or null when the format
  /// isn't recognised. Dispatches on [platform]: iOS syslog timestamps are
  /// always normalised to the full `YYYY-MM-DD HH:MM:SS.mmm` form before
  /// reaching [LogEntry], while Android logcat's `MM-DD HH:MM:SS.mmm` form
  /// carries no year — inferred from [now] (the wall clock at first access
  /// if not supplied), stepping back a year for a date that would otherwise
  /// sit in the future across a Dec→Jan boundary.
  late final DateTime? parsedTimestamp = _parseTimestamp();

  DateTime? _parseTimestamp() {
    final trimmed = timestamp.trim();
    if (trimmed.isEmpty) return null;

    int millisFrom(String? fraction) {
      if (fraction == null || fraction.isEmpty) return 0;
      final padded = fraction.padRight(3, '0').substring(0, 3);
      return int.parse(padded);
    }

    final full = _fullTimestampPattern.firstMatch(trimmed);
    if (full != null) {
      return DateTime(
        int.parse(full.group(1)!),
        int.parse(full.group(2)!),
        int.parse(full.group(3)!),
        int.parse(full.group(4)!),
        int.parse(full.group(5)!),
        int.parse(full.group(6)!),
        millisFrom(full.group(7)),
      );
    }

    // Only Android logcat emits the year-less short form; iOS timestamps are
    // always pre-normalised to the full form above.
    if (platform != DevicePlatform.android) return null;

    final short = _shortTimestampPattern.firstMatch(trimmed);
    if (short == null) return null;

    final reference = _referenceTime ?? DateTime.now();
    final month = int.parse(short.group(1)!);
    final day = int.parse(short.group(2)!);
    final hour = int.parse(short.group(3)!);
    final minute = int.parse(short.group(4)!);
    final second = int.parse(short.group(5)!);
    final millis = millisFrom(short.group(6));
    var candidate = DateTime(
      reference.year,
      month,
      day,
      hour,
      minute,
      second,
      millis,
    );
    if (candidate.isAfter(reference.add(const Duration(days: 1)))) {
      candidate = DateTime(
        reference.year - 1,
        month,
        day,
        hour,
        minute,
        second,
        millis,
      );
    }
    return candidate;
  }

  @override
  String toString() {
    return 'LogEntry(id: $id, type: ${type.name}, timestamp: $timestamp, pid: $pid, tid: $tid, level: $level, tag: $tag, message: $message, packageName: $packageName, processName: $processName)';
  }

  @override
  int get hashCode {
    return Object.hash(
      timestamp,
      type,
      platform,
      pid,
      tid,
      level,
      tag,
      message,
      packageName,
      processName,
      subsystem,
      category,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogEntry &&
        other.timestamp == timestamp &&
        other.type == type &&
        other.platform == platform &&
        other.pid == pid &&
        other.tid == tid &&
        other.level == level &&
        other.tag == tag &&
        other.message == message &&
        other.packageName == packageName &&
        other.processName == processName &&
        other.subsystem == subsystem &&
        other.category == category;
  }
}
