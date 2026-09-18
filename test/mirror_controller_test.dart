import 'package:eagly/data/device.dart';
import 'package:eagly/features/mirror/mirror_controller.dart';
import 'package:eagly/services/preferences_service.dart';
import 'package:eagly/session/device_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/session_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSessionService service;
  late Device device;
  DeviceSessionController? session;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  setUp(() {
    MirrorController.iosRestartBackoff = const [
      Duration.zero,
      Duration.zero,
      Duration.zero,
      Duration.zero,
    ];
    MirrorController.iosHealthInterval = const Duration(hours: 1);
  });

  MirrorController createMirror({Device? withDevice}) {
    device =
        withDevice ??
        Device(
          'emulator-5554',
          'device',
          platform: DevicePlatform.android,
          brand: 'Google',
          model: 'Pixel 8',
        );
    service = FakeSessionService(device);
    session = DeviceSessionController(device: device, service: service);
    return session!.mirrorController;
  }

  tearDown(() {
    session?.dispose();
    session = null;
  });

  tearDownAll(() {
    MirrorController.iosRestartBackoff = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ];
    MirrorController.iosHealthInterval = const Duration(seconds: 2);
  });

  test('mirror starts for a connected Android device', () async {
    final mirror = createMirror();

    await mirror.start();

    expect(mirror.screenMirrorState, ScreenMirrorState.running);
    expect(mirror.isScreenMirrorRunning, isTrue);
    expect(service.startedMirrorCount, 1);
  });

  test('mirror starts for a connected iOS device', () async {
    final mirror = createMirror(
      withDevice: Device.ios('00008110-001234567890801E', 'device'),
    );

    await mirror.start();

    expect(mirror.screenMirrorState, ScreenMirrorState.running);
    expect(mirror.iosViewerUrl, 'http://127.0.0.1:9/');
    expect(service.startedIosMirrorCount, 1);
    expect(service.startedMirrorCount, 0);
  });

  test(
    'unexpected iOS mirror exit triggers a bounded automatic restart',
    () async {
      final mirror = createMirror(
        withDevice: Device.ios('00008110-001234567890801E', 'device'),
      );
      await mirror.start();

      service.iosMirrorExit!.complete(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.startedIosMirrorCount, 2);
      expect(mirror.screenMirrorState, ScreenMirrorState.running);
    },
  );

  test('mirror stops when the device disconnects', () async {
    final mirror = createMirror();

    await mirror.start();
    expect(mirror.isScreenMirrorRunning, isTrue);

    session!.updateDevice(
      device.copyWith(connectionState: DeviceConnectionState.disconnected),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(mirror.screenMirrorState, ScreenMirrorState.stopped);
    expect(service.stoppedMirrorCount, 1);
  });

  test('opening the mirror via the session starts the stream', () async {
    final mirror = createMirror();

    session!.openMirror();
    expect(session!.isMirrorOpen, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(mirror.isScreenMirrorRunning, isTrue);
    expect(service.startedMirrorCount, 1);

    session!.closeMirror();
    expect(session!.isMirrorOpen, isFalse);
  });

  test('changing quality restarts a running mirror', () async {
    final mirror = createMirror();

    await mirror.start();
    expect(service.startedMirrorCount, 1);

    await mirror.setQuality(MirrorQuality.high);

    expect(mirror.mirrorQuality, MirrorQuality.high);
    expect(service.startedMirrorCount, 2);
  });
}
