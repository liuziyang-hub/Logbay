import 'package:eagly/services/tools/bundled_runtime_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a versioned runtime manifest', () {
    final manifest = BundledRuntimeManifest.parse('''
      {"schemaVersion":1,"entries":[{
        "name":"pymobiledevice3","version":"11.15.4",
        "file":"ios-runtime/pymobiledevice3.exe",
        "sha256":"${'a' * 64}",
        "source":"https://github.com/doronz88/pymobiledevice3"
      }]}
    ''');

    expect(manifest.find('pymobiledevice3')?.version, '11.15.4');
  });

  test('rejects malformed component hashes', () {
    expect(
      () => BundledRuntimeManifest.parse('''
        {"schemaVersion":1,"entries":[{
          "name":"pymobiledevice3","version":"11.15.4",
          "file":"pymobiledevice3.exe","sha256":"bad","source":"upstream"
        }]}
      '''),
      throwsFormatException,
    );
  });
}
