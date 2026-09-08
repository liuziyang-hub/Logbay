import 'package:eagly/features/logs/services/log_parsers/logcat_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = LogcatParser();

  test('parses standard threadtime lines', () {
    final entry = parser.parse(
      '09-02 10:30:49.716  1824  2013 D HBMFeatureControl: light lux=835.7272',
    );
    expect(entry, isNotNull);
    expect(entry!.tag, 'HBMFeatureControl');
    expect(entry.message, 'light lux=835.7272');
    expect(entry.level, 'D');
  });

  test('parses tags that contain colons', () {
    final cases = <(String, String, String)>[
      (
        '09-02 10:31:17.019 32496 32496 W Wth2:WeatherApplication: application return, user is not agree',
        'Wth2:WeatherApplication',
        'application return, user is not agree',
      ),
      (
        '09-02 10:31:04.371 32218 32218 E ocessService0:: Not starting debugger since process cannot load the jdwp agent.',
        'ocessService0:',
        'Not starting debugger since process cannot load the jdwp agent.',
      ),
      (
        '09-02 10:31:05.047 32270 32270 W ocessService0:2: type=1400 audit(0.0:24044): avc: denied',
        'ocessService0:2',
        'type=1400 audit(0.0:24044): avc: denied',
      ),
    ];

    for (final (line, tag, message) in cases) {
      final entry = parser.parse(line);
      expect(entry, isNotNull, reason: line);
      expect(entry!.tag, tag);
      expect(entry.message, message);
    }
  });

  test('parses buffer section markers', () {
    final entry = parser.parse('--------- beginning of events');
    expect(entry, isNotNull);
    expect(entry!.message, '缓冲区开始：events');
  });
}
