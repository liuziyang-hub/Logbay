import 'package:eagly/services/tools/pymobiledevice3_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses and compares pymobiledevice3 versions', () {
    final parsed = Pymobiledevice3Version.parse(
      'pymobiledevice3 version 11.15.4',
    );

    expect(parsed.toString(), '11.15.4');
    expect(
      parsed!.compareTo(const Pymobiledevice3Version(11, 15, 3)),
      greaterThan(0),
    );
    expect(Pymobiledevice3Version.parse('unknown'), isNull);
  });
}
