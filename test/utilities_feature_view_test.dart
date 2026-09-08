import 'package:eagly/data/device.dart';
import 'package:eagly/features/utilities/components/utility_output_panel.dart';
import 'package:eagly/features/utilities/data/utility_command.dart';
import 'package:eagly/features/utilities/utilities_controller.dart';
import 'package:eagly/features/utilities/utilities_feature_view.dart';
import 'package:eagly/presentation/theme/app_theme.dart';
import 'package:eagly/services/preferences_service.dart';
import 'package:eagly/services/tools/tool_process_runner.dart';
import 'package:eagly/session/device_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/session_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSessionService service;
  DeviceSessionController? session;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  UtilitiesController createController({
    DevicePlatform platform = DevicePlatform.android,
  }) {
    final device = platform == DevicePlatform.android
        ? Device(
            'emulator-5554',
            'device',
            platform: DevicePlatform.android,
            brand: 'Google',
            model: 'Pixel 8',
          )
        : Device(
            '00008030-001',
            'device',
            platform: DevicePlatform.ios,
            model: 'iPhone 15',
          );
    service = FakeSessionService(device);
    session = DeviceSessionController(device: device, service: service);
    return session!.utilitiesController;
  }

  tearDown(() {
    session?.dispose();
    session = null;
  });

  Widget host(UtilitiesController controller) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: UtilitiesFeatureView(controller: controller, onClose: () {}),
      ),
    );
  }

  useTallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders grouped commands for the device platform', (
    tester,
  ) async {
    useTallWindow(tester);
    await tester.pumpWidget(host(createController()));

    expect(find.text('工具'), findsOneWidget);
    expect(find.text('电源与连接'), findsOneWidget);
    expect(find.text('重启设备'), findsOneWidget);
    // iOS-only commands stay hidden on an Android device.
    expect(find.text('取消配对'), findsNothing);
  });

  testWidgets('tapping a command runs it and shows its output', (tester) async {
    useTallWindow(tester);
    final controller = createController();
    service.utilityResult = const ToolCommandResult(
      exitCode: 0,
      stdout: '  Physical size: 1080x2400',
      stderr: '',
    );
    await tester.pumpWidget(host(controller));

    await tester.tap(find.text('屏幕尺寸与密度'));
    await tester.pumpAndSettle();

    expect(service.utilityRequests.single.arguments, [
      'shell',
      'wm size; wm density',
    ]);
    expect(find.byType(UtilityOutputPanel), findsOneWidget);
    expect(find.textContaining('Physical size: 1080x2400'), findsOneWidget);
  });

  testWidgets('a parameterised command collects input before running', (
    tester,
  ) async {
    useTallWindow(tester);
    final controller = createController();
    await tester.pumpWidget(host(controller));

    await tester.tap(find.text('打开链接 / 深链'));
    await tester.pumpAndSettle();

    // Nothing runs until the dialog is filled in and submitted.
    expect(service.utilityRequests, isEmpty);
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      'myapp://home',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('运行'));
    await tester.tap(find.text('运行'));
    await tester.pumpAndSettle();

    expect(service.utilityRequests.single.arguments, [
      'shell',
      "am start -a android.intent.action.VIEW -d 'myapp://home'",
    ]);
  });

  testWidgets('a destructive command asks for confirmation first', (
    tester,
  ) async {
    useTallWindow(tester);
    final controller = createController();
    await tester.pumpWidget(host(controller));

    await tester.tap(find.text('重启设备'));
    await tester.pumpAndSettle();

    expect(find.text('重启设备?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(service.utilityRequests, isEmpty);

    await tester.tap(find.text('重启设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '重启设备'));
    await tester.pumpAndSettle();

    expect(service.utilityRequests.single.arguments, ['reboot']);
  });

  testWidgets('an iOS device runs the libimobiledevice equivalent', (
    tester,
  ) async {
    useTallWindow(tester);
    final controller = createController(platform: DevicePlatform.ios);
    service.utilityResult = const ToolCommandResult(
      exitCode: 0,
      stdout: 'CurrentCapacity: 87',
      stderr: '',
    );
    await tester.pumpWidget(host(controller));

    // Android-only commands are gone; the shared ones stay.
    expect(find.text('输入文本'), findsNothing);
    await tester.tap(find.text('电池状态'));
    await tester.pumpAndSettle();

    expect(service.utilityRequests.single.tool, UtilityTool.idevicediagnostics);
    expect(service.utilityRequests.single.arguments, [
      'diagnostics',
      'GasGauge',
    ]);
    expect(find.textContaining('CurrentCapacity: 87'), findsOneWidget);
  });

  testWidgets('search filters the list', (tester) async {
    useTallWindow(tester);
    await tester.pumpWidget(host(createController()));

    await tester.enterText(find.byType(TextField).first, 'monkey');
    await tester.pumpAndSettle();

    expect(find.text('Monkey 压力测试'), findsOneWidget);
    expect(find.text('重启设备'), findsNothing);
  });
}
