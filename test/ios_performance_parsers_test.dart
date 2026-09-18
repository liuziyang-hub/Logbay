import 'package:eagly/features/performance/ios/ios_metric_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses pymobiledevice3 process JSON', () {
    final metrics = IosMetricParsers.process(
      '[{"name":"Demo","cpuUsage":2.056,"physFootprint":123456,'
      '"diskBytesRead":10,"diskBytesWritten":20}]',
      processName: 'Demo',
    );

    expect(metrics?.cpuPercent, 2.056);
    expect(metrics?.memoryBytes, 123456);
    expect(metrics?.diskReadBytes, 10);
  });

  test('accepts Python-style battery and system dictionaries', () {
    expect(
      IosMetricParsers.temperatureCelsius(
        "{'Temperature': 3980, 'IsCharging': False}",
      ),
      39.8,
    );
    final system = IosMetricParsers.system(
      "{'netBytesIn': 5117, 'netBytesOut': 3543}",
    );
    expect(system?.networkRxBytes, 5117);
    expect(system?.networkTxBytes, 3543);
  });

  test('parses graphics output but never invents missing metrics', () {
    expect(IosMetricParsers.fps('{"fps":59.94}'), 59.94);
    expect(IosMetricParsers.fps('garbled output'), isNull);
    expect(IosMetricParsers.process('[{"cpuUsage":1.0}]'), isNull);
    expect(IosMetricParsers.system('{}'), isNull);
  });
}
