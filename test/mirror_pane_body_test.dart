import 'package:eagly/data/device.dart';
import 'package:eagly/features/mirror/components/pane_body.dart';
import 'package:eagly/features/mirror/mirror_controller.dart';
import 'package:eagly/services/preferences_service.dart';
import 'package:eagly/session/device_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/session_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  testWidgets('unsupported iOS mirror offers screenshot and retry', (
    tester,
  ) async {
    final device = Device.ios('00008110-001234567890801E', 'device');
    final session = DeviceSessionController(
      device: device,
      service: FakeSessionService(device),
    );
    addTearDown(session.dispose);
    final controller = session.mirrorController
      ..screenMirrorState = ScreenMirrorState.unsupported
      ..screenMirrorError = 'Apple 的远程控制服务要求 iOS 27 或以上。';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PaneBody(controller: controller)),
      ),
    );

    expect(find.text('截取当前画面'), findsOneWidget);
    expect(find.text('重新检测'), findsOneWidget);
    expect(find.textContaining('iOS 27'), findsOneWidget);
  });

  testWidgets('ordinary mirror error does not offer screenshot fallback', (
    tester,
  ) async {
    final device = Device.ios('00008110-001234567890801E', 'device');
    final session = DeviceSessionController(
      device: device,
      service: FakeSessionService(device),
    );
    addTearDown(session.dispose);
    final controller = session.mirrorController
      ..screenMirrorState = ScreenMirrorState.error
      ..screenMirrorError = '连接失败。';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PaneBody(controller: controller)),
      ),
    );

    expect(find.text('截取当前画面'), findsNothing);
    expect(find.text('开始镜像'), findsOneWidget);
  });
}
