import 'dart:io';

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

  test('uses bundled uv to run the pinned upstream package', () async {
    final directory = await Directory.systemTemp.createTemp('logbay-uv-test-');
    addTearDown(() => directory.delete(recursive: true));
    final runtime = Directory('${directory.path}\\ios-runtime')..createSync();
    File('${runtime.path}\\uv.exe').writeAsBytesSync(const [0]);

    final command = Pymobiledevice3Launcher.bundledWindowsCommandIn(directory);

    expect(command?.executable, endsWith('ios-runtime\\uv.exe'));
    expect(command?.prefixArgs.join(' '), contains('pymobiledevice3==11.15.4'));
  });
}
