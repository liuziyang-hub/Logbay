import 'package:eagly/data/device.dart';
import 'package:eagly/features/logs/data/models/log_entry.dart';
import 'package:eagly/features/logs/data/models/log_filters.dart';
import 'package:eagly/features/logs/data/models/log_level.dart';
import 'package:eagly/features/logs/services/filter_utils.dart';
import 'package:eagly/features/logs/services/log_parsers/ios_ostrace_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IosOstraceParser', () {
    const parser = IosOstraceParser();

    test('parses NDJSON unified-log lines', () {
      final entry = parser.parseLine(
        '{"pid":4242,"thread_id":7,"timestamp":"2026-09-03T02:15:30.123456",'
        '"level":"DEBUG","filename":"/private/var/containers/Bundle/Application/'
        'ABC/NetShort.app/NetShort","image_name":"/usr/lib/libobjc.A.dylib",'
        '"message":"ad bid request","label":{"subsystem":"com.netshort.abroad",'
        '"category":"Ads"}}',
      );

      expect(entry, isNotNull);
      expect(entry!.pid, '4242');
      expect(entry.tid, '7');
      expect(entry.level, 'debug');
      expect(entry.packageName, 'NetShort');
      expect(entry.tag, 'com.netshort.abroad/Ads');
      expect(entry.subsystem, 'com.netshort.abroad');
      expect(entry.category, 'Ads');
      expect(entry.message, 'ad bid request');
      expect(entry.platform, DevicePlatform.ios);
      expect(entry.timestamp, contains('2026-09-03'));
    });

    test('returns null for non-json', () {
      expect(parser.parseLine('not json'), isNull);
      expect(parser.parseLine(''), isNull);
    });
  });

  group('packageFollowPids', () {
    LogEntry log({
      required String packageName,
      required String pid,
      String message = 'hello',
    }) {
      return LogEntry(
        timestamp: '09-03 10:00:00.000',
        pid: pid,
        tid: '1',
        level: 'D',
        tag: 'Tag',
        message: message,
        packageName: packageName,
        platform: DevicePlatform.android,
      );
    }

    test('matches by followed PID when package column differs', () {
      final filters = LogFilters.empty(LogLevel.verbose).copyWithPackage('com.demo.app');
      final entry = log(packageName: '', pid: '999');

      expect(
        matchesLogFilters(
          entry,
          filters,
          LogLevel.verbose,
          packageFollowPids: {'999'},
        ),
        isTrue,
      );
      expect(
        matchesLogFilters(
          entry,
          filters,
          LogLevel.verbose,
          packageFollowPids: {'111'},
        ),
        isFalse,
      );
    });
  });
}

extension on LogFilters {
  LogFilters copyWithPackage(String packageText) {
    return LogFilters(
      messageText: messageText,
      packageText: packageText,
      pidTidText: pidTidText,
      tagText: tagText,
      messageTerms: messageTerms,
      rawTerms: rawTerms,
      packageTerms: packageText.isEmpty
          ? const []
          : [FilterTerm(packageText)],
      pidTidTerms: pidTidTerms,
      tagTerms: tagTerms,
      level: level,
      maxAge: maxAge,
    );
  }
}
