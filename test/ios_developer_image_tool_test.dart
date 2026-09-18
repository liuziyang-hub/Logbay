import 'package:eagly/services/tools/ios_developer_image_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseMounted treats empty list as not mounted', () {
    expect(IosDeveloperImageTool.parseMounted(''), isFalse);
    expect(IosDeveloperImageTool.parseMounted('[]'), isFalse);
    expect(IosDeveloperImageTool.parseMounted('  []  \n'), isFalse);
  });

  test('parseMounted treats a mounter list entry as mounted', () {
    expect(
      IosDeveloperImageTool.parseMounted(
        '[{"ImageType":"Personalized","ImageSignature":"abcd"}]',
      ),
      isTrue,
    );
  });
}
