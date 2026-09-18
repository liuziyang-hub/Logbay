import 'package:eagly/services/tools/ios_mirror_tool.dart';
import 'package:eagly/services/tools/pymobiledevice3_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks iOS versions below 27 before opening the viewer', () {
    final issue = IosMirrorTool.compatibilityIssue(
      productVersion: '26.6',
      installedVersion: const Pymobiledevice3Version(11, 15, 4),
    );

    expect(issue, contains('iOS 26.6'));
    expect(issue, contains('iOS 27'));
  });

  test('blocks unstable pymobiledevice3 versions', () {
    final issue = IosMirrorTool.compatibilityIssue(
      productVersion: '27.0',
      installedVersion: const Pymobiledevice3Version(10, 11, 5),
    );

    expect(issue, contains('10.11.5'));
    expect(issue, contains('11.15.4'));
  });

  test('maps the iOS 27 device gate to a Chinese compatibility message', () {
    final message = IosMirrorTool.friendlyServerFailure(
      'Remote control requires iOS 27.0 or later on this device.',
    );

    expect(message, contains('iOS 27'));
    expect(message, contains('截图'));
    expect(message, isNot(contains('HTTP 500')));
  });

  test('maps camera and microphone conflicts to an actionable message', () {
    final message = IosMirrorTool.friendlyServerFailure(
      'The device camera or microphone is in use',
    );

    expect(message, contains('相机或麦克风'));
    expect(message, contains('关闭'));
  });
}
