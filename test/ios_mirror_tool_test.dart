import 'package:eagly/services/tools/ios_mirror_diagnostics.dart';
import 'package:eagly/services/tools/ios_mirror_tool.dart';
import 'package:eagly/services/tools/pymobiledevice3_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows modern iOS versions without a fabricated iOS 27 gate', () {
    final issue = IosMirrorTool.compatibilityIssue(
      productVersion: '18.6',
      installedVersion: const Pymobiledevice3Version(11, 15, 0),
    );

    expect(issue, isNull);
  });

  test('only blocks systems older than the CoreDevice generation', () {
    final issue = IosMirrorTool.compatibilityIssue(
      productVersion: '16.7',
      installedVersion: const Pymobiledevice3Version(11, 15, 0),
    );

    expect(issue, contains('iOS 16.7'));
    expect(issue, contains('iOS 17'));
  });

  test('does not use the package version as the only capability gate', () {
    final issue = IosMirrorTool.compatibilityIssue(
      productVersion: '18.0',
      installedVersion: const Pymobiledevice3Version(10, 11, 5),
    );

    expect(issue, isNull);
  });

  test('classifies developer image failures', () {
    final diagnostic = IosMirrorDiagnostic.classify(
      'Developer Disk Image is not mounted',
    );

    expect(diagnostic.kind, IosMirrorFailureKind.developerImage);
    expect(diagnostic.userMessage, contains('开发者镜像'));
  });

  test('classifies tunnel failures', () {
    final diagnostic = IosMirrorDiagnostic.classify(
      'RemoteXPC tunnel connection closed',
    );

    expect(diagnostic.kind, IosMirrorFailureKind.tunnel);
    expect(diagnostic.userMessage, contains('调试隧道'));
  });

  test('maps camera and microphone conflicts to an actionable message', () {
    final diagnostic = IosMirrorDiagnostic.classify(
      'The device camera or microphone is in use',
    );

    expect(diagnostic.kind, IosMirrorFailureKind.mediaInUse);
    expect(diagnostic.userMessage, contains('相机或麦克风'));
    expect(diagnostic.userMessage, contains('关闭'));
  });

  test('classifies codec and port failures separately', () {
    expect(
      IosMirrorDiagnostic.classify('HEVC codec unavailable').kind,
      IosMirrorFailureKind.codec,
    );
    expect(
      IosMirrorDiagnostic.classify(
        'WinError 10048 address already in use',
      ).kind,
      IosMirrorFailureKind.portConflict,
    );
  });

  test('unknown HTTP 500 still returns useful Chinese guidance', () {
    final message = IosMirrorTool.friendlyServerFailure(
      'HTTP 500 internal server error: unexpected upstream failure',
    );

    expect(message, contains('iOS 投屏启动失败'));
    expect(message, contains('复制诊断信息'));
  });
}
