import 'package:eagly/features/performance/android/android_gfxinfo_parser.dart';
import 'package:eagly/features/performance/android/android_meminfo_parser.dart';
import 'package:eagly/features/performance/android/android_network_parser.dart';
import 'package:eagly/features/performance/android/android_proc_cpu_parser.dart';
import 'package:eagly/features/performance/android/android_temperature_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses gfxinfo frame timeline and classifies slow/frozen frames', () {
    const output = '''
---PROFILEDATA---
Flags,IntendedVsync,Vsync,OldestInputEvent,NewestInputEvent,HandleInputStart,AnimationStart,PerformTraversalsStart,DrawStart,SyncQueued,SyncStart,IssueDrawCommandsStart,SwapBuffers,FrameCompleted
0,1000000000,0,0,0,0,0,0,0,0,0,0,0,1010000000
0,1016666667,0,0,0,0,0,0,0,0,0,0,0,1050000000
0,1066666667,0,0,0,0,0,0,0,0,0,0,0,1800000000
---PROFILEDATA---
''';
    final stats = AndroidGfxinfoParser.parse(output);

    expect(stats, isNotNull);
    expect(stats!.frameTimesMs, hasLength(3));
    expect(stats.slowFrameCount, 2);
    expect(stats.frozenFrameCount, 1);
    expect(stats.averageFrameTimeMs, closeTo(258.889, 0.01));
    expect(stats.fps, greaterThan(0));
  });

  test('returns null for gfxinfo without valid frame rows', () {
    expect(AndroidGfxinfoParser.parse('No process found'), isNull);
  });

  test('calculates target process CPU from consecutive proc snapshots', () {
    final first = AndroidProcCpuParser.parse(
      systemStat: 'cpu  100 20 30 850 0 0 0 0 0 0',
      processStat: '123 (app process) S 1 1 1 0 0 0 0 0 0 0 10 5 0 0 0 0',
    );
    final second = AndroidProcCpuParser.parse(
      systemStat: 'cpu  140 20 40 900 0 0 0 0 0 0',
      processStat: '123 (app process) S 1 1 1 0 0 0 0 0 0 0 20 10 0 0 0 0',
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second!.usageSince(first!), closeTo(15, 0.001));
  });

  test('parses modern dumpsys meminfo summary', () {
    const output = '''
 App Summary
                       Pss(KB)                        Rss(KB)
                        ------                         ------
           Java Heap:     8012                          12000
         Native Heap:     4000                           9000
           TOTAL PSS:    24576            TOTAL RSS:    45000
''';
    final stats = AndroidMeminfoParser.parse(output);

    expect(stats?.pssKb, 24576);
    expect(stats?.rssKb, 45000);
    expect(stats?.javaHeapKb, 12000);
    expect(stats?.nativeHeapKb, 9000);
  });

  test('aggregates qtaguid rows belonging to the target uid', () {
    const output = '''
idx iface acct_tag_hex uid_tag_int cnt_set rx_bytes rx_packets tx_bytes tx_packets
2 wlan0 0x0 10123 0 100 1 40 1
3 rmnet0 0x0 10123 0 300 2 90 2
4 wlan0 0x0 10124 0 999 9 999 9
''';
    final stats = AndroidNetworkParser.parseQtaguid(output, uid: 10123);

    expect(stats?.receiveBytes, 400);
    expect(stats?.transmitBytes, 130);
  });

  test('prefers the hottest valid thermal reading', () {
    const output = '''
Temperature{mValue=36.2, mType=2, mName=BATTERY}
Temperature{mValue=42.8, mType=3, mName=SKIN}
''';
    expect(AndroidTemperatureParser.parseThermalService(output), 42.8);
  });

  test('parses battery temperature in tenths of a degree', () {
    expect(AndroidTemperatureParser.parseBattery('temperature: 327'), 32.7);
  });
}
