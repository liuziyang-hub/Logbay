import '../data/models/log_entry.dart';

enum LogIssueKind { crash, anr, native }

/// A detected crash / ANR / native-fault signal in the log buffer.
class LogIssue {
  const LogIssue({
    required this.id,
    required this.kind,
    required this.summary,
    required this.logEntryId,
    required this.timestamp,
  });

  final String id;
  final LogIssueKind kind;
  final String summary;
  final int logEntryId;
  final String timestamp;

  String get kindLabel => switch (kind) {
    LogIssueKind.crash => '崩溃',
    LogIssueKind.anr => 'ANR',
    LogIssueKind.native => '原生崩溃',
  };
}

/// Regex catalog that flags Crash / ANR / Native lines (Android-focused;
/// harmless on iOS lines that don't match).
class LogSignalDetector {
  const LogSignalDetector();

  static final _rules = <({LogIssueKind kind, RegExp pattern, String label})>[
    (
      kind: LogIssueKind.crash,
      pattern: RegExp(r'FATAL EXCEPTION', caseSensitive: false),
      label: 'FATAL EXCEPTION',
    ),
    (
      kind: LogIssueKind.crash,
      pattern: RegExp(r'AndroidRuntime:\s*FATAL', caseSensitive: false),
      label: 'AndroidRuntime FATAL',
    ),
    (
      kind: LogIssueKind.anr,
      pattern: RegExp(r'\bANR in\b', caseSensitive: false),
      label: 'ANR',
    ),
    (
      kind: LogIssueKind.anr,
      pattern: RegExp(r'Input dispatching timed out', caseSensitive: false),
      label: '输入超时',
    ),
    (
      kind: LogIssueKind.native,
      pattern: RegExp(r'Fatal signal\s+\d+', caseSensitive: false),
      label: 'Fatal signal',
    ),
    (
      kind: LogIssueKind.native,
      pattern: RegExp(r'\bSIG(SEGV|ABRT|BUS|ILL|FPE|TRAP)\b'),
      label: 'Fatal signal name',
    ),
    (
      kind: LogIssueKind.native,
      pattern: RegExp(r'libc\s*:\s*Fatal signal', caseSensitive: false),
      label: 'libc Fatal signal',
    ),
    (
      kind: LogIssueKind.crash,
      pattern: RegExp(r'Process:[\s\S]*?PID:', caseSensitive: false),
      label: 'Process crash header',
    ),
  ];

  /// Returns an issue when [entry] matches a signal rule, else null.
  LogIssue? detect(LogEntry entry) {
    if (entry.type != LogEntryType.log) return null;
    final haystack = '${entry.tag} ${entry.message}';
    for (final rule in _rules) {
      final match = rule.pattern.firstMatch(haystack);
      if (match == null) continue;
      final snippet = entry.message.trim();
      final summary = snippet.isEmpty
          ? rule.label
          : (snippet.length <= 120 ? snippet : '${snippet.substring(0, 117)}…');
      return LogIssue(
        id: '${entry.id}-${rule.kind.name}',
        kind: rule.kind,
        summary: summary,
        logEntryId: entry.id,
        timestamp: entry.timestamp,
      );
    }
    return null;
  }
}
