import 'package:flutter_test/flutter_test.dart';
import 'package:eagly/data/device.dart';
import 'package:eagly/features/logs/data/models/log_entry.dart';
import 'package:eagly/features/logs/services/log_signal_detector.dart';

void main() {
  const detector = LogSignalDetector();

  LogEntry entry(String message, {String tag = 'AndroidRuntime'}) {
    return LogEntry(
      timestamp: '09-03 12:00:00.000',
      pid: '1234',
      tid: '1',
      level: 'E',
      tag: tag,
      message: message,
      platform: DevicePlatform.android,
    );
  }

  test('detects FATAL EXCEPTION as crash', () {
    final issue = detector.detect(
      entry('FATAL EXCEPTION: main'),
    );
    expect(issue, isNotNull);
    expect(issue!.kind, LogIssueKind.crash);
  });

  test('detects ANR', () {
    final issue = detector.detect(entry('ANR in com.demo.app'));
    expect(issue?.kind, LogIssueKind.anr);
  });

  test('detects Fatal signal', () {
    final issue = detector.detect(
      entry('Fatal signal 11 (SIGSEGV)', tag: 'libc'),
    );
    expect(issue?.kind, LogIssueKind.native);
  });

  test('ignores normal lines', () {
    expect(detector.detect(entry('hello world', tag: 'OkHttp')), isNull);
  });
}
