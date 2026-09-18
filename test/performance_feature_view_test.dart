import 'dart:async';

import 'package:eagly/data/device.dart';
import 'package:eagly/features/performance/data/performance_sample.dart';
import 'package:eagly/features/performance/performance_feature_view.dart';
import 'package:eagly/features/performance/services/device_performance_backend.dart';
import 'package:eagly/presentation/theme/app_theme.dart';
import 'package:eagly/session/device_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/session_test_support.dart';

class _ViewBackend extends DevicePerformanceBackend {
  final StreamController<PerformanceSample> controller =
      StreamController<PerformanceSample>();

  @override
  Stream<PerformanceSample> start(PerformanceCollectionRequest request) =>
      controller.stream;

  @override
  Future<void> stop() async {}
}

class _ViewService extends FakeSessionService {
  _ViewService(super.device, this.backend);

  final _ViewBackend backend;

  @override
  DevicePerformanceBackend createPerformanceBackend() => backend;
}

void main() {
  testWidgets(
    'shows professional Chinese metric labels and starts collection',
    (tester) async {
      final device = Device(
        'device-1',
        'device',
        platform: DevicePlatform.android,
      );
      final backend = _ViewBackend();
      final session = DeviceSessionController(
        device: device,
        service: _ViewService(device, backend),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: PerformanceFeatureView(
              controller: session.performanceController,
            ),
          ),
        ),
      );

      expect(find.text('性能分析'), findsOneWidget);
      expect(find.text('应用包名或进程名'), findsOneWidget);
      expect(find.text('开始采集'), findsOneWidget);
      expect(find.textContaining('FPS'), findsWidgets);
      expect(find.textContaining('帧耗时'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'com.example.app');
      await tester.tap(find.text('开始采集'));
      await tester.pump();

      expect(find.text('实时采集中'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      unawaited(backend.controller.close());
    },
  );
}
