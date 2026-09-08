import 'package:eagly/features/logs/data/models/log_entry.dart';
import 'package:eagly/features/logs/services/log_formats/log_formats.dart';
import 'package:eagly/features/logs/services/log_parsers/ios_syslog_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _format = AndroidLogcatFormat();

void main() {
  group('IosSyslogParser', () {
    test('groups multi-line syslog entries and normalizes timestamps', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 4, 23));
      final logs = <LogEntry>[];
      final lines = <String>[
        'Apr 23 17:09:37.903010 AssetCacheLocatorService[5255] <Debug>: #65bb95e7 [AssetCacheLocatorService.queue] cachedServersForNetworkIdentifiers -> {',
        '    networkIdentifiers =     (',
        '                {',
        '            digest = {length = 32, bytes = 0x1d8fb5e2 db885c3e b017d2f5 975905c1 ... 34c8a741 9d740d68 };',
        '            key = {length = 32, bytes = 0x03b513c1 96e49751 3c732bde c480c8e9 ... 475638f0 5fd07b5d };',
        '        }',
        '    );',
        '    servers =     (',
        '    );',
        '    validUntil = "2026-04-24 04:39:46 +0000";',
        '} validityInterval=61208.097',
        'Apr 23 17:09:37.903030 AssetCacheLocatorService[5255] <Debug>: #65bb95e7 [AssetCacheLocatorService.queue] local cached servers=(',
        ') early hit=YES',
      ];

      for (final line in lines) {
        logs.addAll(parser.addLine(line));
      }
      final trailingEntry = parser.flush();
      if (trailingEntry != null) {
        logs.add(trailingEntry);
      }

      expect(logs, hasLength(2));
      expect(logs.first.id, greaterThanOrEqualTo(0));
      expect(logs.last.id, logs.first.id + 1);
      expect(logs.first.id, isNot(logs.last.id));
      expect(logs.first.timestamp, '2026-04-23 17:09:37.903');
      expect(logs.first.level, 'debug');
      expect(logs.first.tag, 'AssetCacheLocatorService');
      expect(logs.first.packageName, 'AssetCacheLocatorService');
      expect(logs.first.processName, 'AssetCacheLocatorService');
      expect(
        logs.first.message,
        contains('cachedServersForNetworkIdentifiers -> {'),
      );
      expect(
        logs.first.message,
        contains('validUntil = "2026-04-24 04:39:46 +0000";'),
      );
      expect(logs.first.message, contains('\n    servers =     ('));
      expect(
        logs.last.message,
        '#65bb95e7 [AssetCacheLocatorService.queue] local cached servers=(\n) early hit=YES',
      );
    });

    test('captures process labels with spaces and parentheses', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 4, 23));
      final logs = <LogEntry>[];

      logs.addAll(
        parser.addLine(
          'Apr 23 17:10:40.588177 novio (R14)(Flutter)[5727] <Notice>: flutter: ╟ x-xss-protection: [1; mode=block]',
        ),
      );
      final trailingEntry = parser.flush();
      if (trailingEntry != null) {
        logs.add(trailingEntry);
      }

      expect(logs, hasLength(1));
      expect(logs.single.timestamp, '2026-04-23 17:10:40.588');
      expect(logs.single.level, 'default');
      // Tag is the last bracketed value (the iOS subsystem/category); the bare
      // process name and the full label are kept separately.
      expect(logs.single.tag, 'Flutter');
      expect(logs.single.packageName, 'novio');
      expect(logs.single.processName, 'novio (R14)(Flutter)');
      expect(
        logs.single.message,
        'flutter: ╟ x-xss-protection: [1; mode=block]',
      );
    });

    test('extracts process name and category from labels with parentheses', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 6, 9));
      final logs = <LogEntry>[];
      final lines = <String>[
        'Jun  9 15:06:06.533981 novio (R14)(CoreFoundation)[2768] <Debug>: looked up value',
        'Jun  9 15:06:06.534469 runningboardd(RunningBoard)[33] <Info>: PERF: Received request',
      ];
      for (final line in lines) {
        logs.addAll(parser.addLine(line));
      }
      final trailing = parser.flush();
      if (trailing != null) logs.add(trailing);

      expect(logs, hasLength(2));

      // "novio (R14)(CoreFoundation)" → process "novio", category "CoreFoundation".
      expect(logs.first.packageName, 'novio');
      expect(logs.first.tag, 'CoreFoundation');
      expect(logs.first.processName, 'novio (R14)(CoreFoundation)');
      // TID is never available in idevicesyslog output; PID is captured.
      expect(logs.first.pid, '2768');
      expect(logs.first.tid, '0');

      // "runningboardd(RunningBoard)" → process "runningboardd", category "RunningBoard".
      expect(logs.last.packageName, 'runningboardd');
      expect(logs.last.tag, 'RunningBoard');
      expect(logs.last.processName, 'runningboardd(RunningBoard)');
    });

    test('decodes cat-v style meta escapes emitted by piped iOS syslog', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 4, 26));

      parser
          .addLine(
            r'Apr 26 20:54:02.025982 novio (R14)(Flutter)[1800] <Notice>: flutter: \M-b\M^U\M^T Query Parameters',
          )
          .toList();

      final entry = parser.flush();
      expect(entry, isNotNull);
      expect(entry!.message, 'flutter: ╔ Query Parameters');
    });

    test('export round-trips parsed iOS log entries', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 4, 23));
      parser
          .addLine(
            'Apr 23 17:10:40.588246 novio (R14)(Flutter)[5727] <Notice>: flutter: ╟ server: [None]',
          )
          .toList();

      final entry = parser.flush();
      expect(entry, isNotNull);

      final exported = _format.export([entry!]).content;
      final restored = _format.parse(exported).logs.firstOrNull;

      expect(exported.contains('"id"'), isFalse);
      expect(restored, isNotNull);
      expect(restored!.id, isNot(entry.id));
      expect(restored.timestamp, entry.timestamp);
      expect(restored.level, entry.level);
      expect(restored.tag, entry.tag);
      expect(restored.packageName, entry.packageName);
      expect(restored.processName, entry.processName);
      expect(restored.message, entry.message);
    });

    test('preserves unknown iOS raw level values', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 4, 23));

      parser
          .addLine(
            'Apr 23 17:10:40.588246 novio[5727] <Panic>: flutter: something unexpected happened',
          )
          .toList();

      final entry = parser.flush();
      expect(entry, isNotNull);
      expect(entry!.level, 'panic');
    });

    test('strips ANSI colors and keeps unmatched preamble lines', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 9, 2));
      final logs = <LogEntry>[];

      logs.addAll(parser.addLine('\x1B[32mConnecting to device...\x1B[0m'));
      logs.addAll(
        parser.addLine(
          '\x1B[0mSep  2 10:41:00.123456 SpringBoard[100] <Notice>: unlocked\x1B[0m',
        ),
      );
      final trailing = parser.flush();
      if (trailing != null) logs.add(trailing);

      expect(logs, hasLength(2));
      expect(logs.first.tag, 'idevicesyslog');
      expect(logs.first.message, 'Connecting to device...');
      expect(logs.last.tag, 'SpringBoard');
      expect(logs.last.message, 'unlocked');
      expect(logs.last.timestamp, '2026-09-02 10:41:00.123');
    });

    test('decodes NetShort MaiyaAdManager ad lines from live syslog', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 9, 2));
      parser
          .addLine(
            r'Sep  2 12:13:04 NetShort[5929] <Error>: 2026-09-02 12:13:04:152-\M-b\M^]\M^L[ERROR]-[MaiyaAdManager-concurrentRequestGenerator(with:retryLimit:retryInterval:requestTaskTag:realtime:extraInfo:)]: \M-e\M-9\M-?\M-e\M^Q\M^J\M-g\M-.\M-!\M-g\M^P\M^F -> \M-e\M-9\M-6\M-h\M-!\M^L\M-g\M^@\M^Q\M-e\M-8\M^C\M-f\M-5\M^A\M-d\M-;\M-;\M-e\M^J\M-!tag=waterfall&token=13&adUnitId=ca-app-pub-6880728595184927/3074847987 \M-p\M^_\M^Q\M^I admob interstitial ad\M-e\M-9\M-?\M-e\M^Q\M^Jca-app-pub-6880728595184927/3074847987\M-g\M-,\M-,3\M-f\M^]\M-!\M-g\M-,\M-,2\M-f\M-,\M-!\M-h\M-/\M-7\M-f\M-1\M^B\M-e\M-<\M^B\M-e\M-8\M-8\M-o\M-<\M^Zcode=101',
          )
          .toList();

      final entry = parser.flush();
      expect(entry, isNotNull);
      expect(entry!.level, 'error');
      expect(entry.packageName, 'NetShort');
      expect(entry.message, contains('广告'));
      expect(entry.message, contains('MaiyaAdManager'));
      expect(entry.message, isNot(contains('竞价')));
    });

    test('decodes meta escapes mixed with already-decoded Unicode', () {
      final parser = IosSyslogParser(now: () => DateTime(2026, 9, 2));
      // "物资" as UTF-8 bytes 0xE7 0x89 0xA9 0xE8 0xB5 0x84 via \M- escapes,
      // after an already-decoded Chinese prefix.
      parser
          .addLine(
            r'Sep  2 10:41:00.000001 App[1] <Notice>: 缓存\M-g\M-^I\M-)未命中',
          )
          .toList();

      final entry = parser.flush();
      expect(entry, isNotNull);
      expect(entry!.message, contains('缓存'));
      expect(entry.message, contains('未命中'));
      // 物 = U+7269 from UTF-8 E7 89 A9
      expect(entry.message, contains('物'));
    });
  });
}
