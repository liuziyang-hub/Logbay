import 'package:eagly/features/flutter_scrcpy/flutter_scrcpy.dart';
import 'package:eagly/services/tools/external_scrcpy_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds official scrcpy compatibility arguments', () {
    final arguments = ExternalScrcpyTool.buildArguments(
      'emulator-5554',
      const ScrcpyVideoOptions(
        maxSize: 1280,
        maxFps: 60,
        videoBitRate: 8000000,
        control: true,
      ),
    );

    expect(arguments, contains('--serial=emulator-5554'));
    expect(arguments, contains('--no-audio'));
    expect(arguments, contains('--max-size=1280'));
    expect(arguments, contains('--max-fps=60'));
    expect(arguments, contains('--video-bit-rate=8000000'));
  });
}
