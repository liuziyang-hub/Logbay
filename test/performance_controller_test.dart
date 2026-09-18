import 'dart:async';

import 'package:eagly/data/device.dart';
import 'package:eagly/features/performance/android/perfetto_capture_service.dart';
import 'package:eagly/features/performance/data/performance_sample.dart';
import 'package:eagly/features/performance/performance_controller.dart';
import 'package:eagly/features/performance/services/device_performance_backend.dart';
import 'package:eagly/session/device_session_controller.dart';
import 'package:eagly/services/tools/tool_process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/session_test_support.dart';

class _FakePerformanceBackend extends DevicePerformanceBackend {
  StreamController<PerformanceSample>? controller;
  PerformanceCollectionRequest? request;
  int startCount = 0;
  int stopCount = 0;
  Object? startError;

  @override
  Stream<PerformanceSample> start(PerformanceCollectionRequest request) {
    startCount++;
    this.request = request;
    final error = startError;
    if (error != null) throw error;
    controller = StreamController<PerformanceSample>();
    return controller!.stream;
  }

  void emit(PerformanceSample sample) => controller?.add(sample);

  Future<void> fail(Object error) async => controller?.addError(error);

  Future<void> finish() async => controller?.close();

  @override
  Future<void> stop() async {
    stopCount++;
    await controller?.close();
    controller = null;
  }
}

class _PerfettoTransport implements PerfettoTransport {
  final List<List<String>> shellCalls = [];
  String? pulledTo;

  @override
  Future<List<int>> execOut(List<String> arguments) async => const [];

  @override
  Future<void> pull(String devicePath, String localPath) async {
    pulledTo = localPath;
  }

  @override
  Future<void> pushText(String content, String devicePath) async {}

  @override
  Future<ToolCommandResult> shell(
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    shellCalls.add(arguments);
    if (arguments.first == 'perfetto') {
      return const ToolCommandResult(
        exitCode: 0,
        stdout: 'pid: 42',
        stderr: '',
      );
    }
    if (arguments.first == 'kill' && arguments[1] == '-0') {
      return const ToolCommandResult(exitCode: 1, stdout: '', stderr: '');
    }
    return const ToolCommandResult(exitCode: 0, stdout: '', stderr: '');
  }
}

void main() {
  late Device device;
  late FakeSessionService service;
  late DeviceSessionController session;
  late _FakePerformanceBackend backend;
  late PerformanceController controller;

  setUp(() {
    device = Device('device-1', 'device', platform: DevicePlatform.android);
    service = FakeSessionService(device);
    session = DeviceSessionController(device: device, service: service);
    backend = _FakePerformanceBackend();
    controller = PerformanceController(session, backend: backend);
  });

  tearDown(() async {
    controller.dispose();
    session.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  test('starts a bounded session and receives samples', () async {
    await controller.start(
      applicationId: 'com.example.app',
      sampleInterval: const Duration(seconds: 2),
    );
    backend.emit(
      PerformanceSample(
        timestamp: DateTime.utc(2026, 9, 18),
        elapsed: Duration.zero,
        fps: 60,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, PerformanceCollectionState.running);
    expect(controller.samples.single.fps, 60);
    expect(backend.request?.applicationId, 'com.example.app');
    expect(backend.request?.sampleInterval, const Duration(seconds: 2));
  });

  test('stops collection when the device disconnects', () async {
    await controller.start();
    session.updateDevice(
      device.copyWith(connectionState: DeviceConnectionState.disconnected),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.stopCount, 1);
    expect(controller.state, PerformanceCollectionState.idle);
    expect(controller.currentSession?.endedAt, isNotNull);
  });

  test(
    'keeps samples and exposes a professional error on stream failure',
    () async {
      await controller.start();
      backend.emit(
        PerformanceSample(
          timestamp: DateTime.utc(2026, 9, 18),
          elapsed: Duration.zero,
          cpuPercent: 12,
        ),
      );
      await backend.fail(StateError('采集通道已断开'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.samples, hasLength(1));
      expect(controller.state, PerformanceCollectionState.failed);
      expect(controller.errorMessage, contains('采集通道已断开'));
    },
  );

  test('does not start while disconnected', () async {
    session.updateDevice(
      device.copyWith(connectionState: DeviceConnectionState.disconnected),
    );
    await controller.start();

    expect(backend.startCount, 0);
    expect(controller.state, PerformanceCollectionState.failed);
    expect(controller.errorMessage, '设备未连接，无法开始性能采集。');
  });

  test(
    'stream completion ends the session without discarding samples',
    () async {
      await controller.start();
      backend.emit(
        PerformanceSample(
          timestamp: DateTime.utc(2026, 9, 18),
          elapsed: Duration.zero,
          memoryBytes: 1024,
        ),
      );
      await backend.finish();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state, PerformanceCollectionState.idle);
      expect(controller.samples.single.memoryBytes, 1024);
      expect(controller.currentSession?.endedAt, isNotNull);
    },
  );

  test('records and saves an Android Perfetto trace', () async {
    final transport = _PerfettoTransport();
    controller.dispose();
    controller = PerformanceController(
      session,
      backend: backend,
      perfettoCaptureService: PerfettoCaptureService(transport: transport),
      loadPerfettoConfig: () async => 'buffers: {}',
    );

    await controller.startPerfettoTrace(applicationId: 'com.example.app');
    expect(controller.isTraceRecording, isTrue);

    await controller.stopPerfettoTrace('C:\\temp\\demo.perfetto-trace');
    expect(controller.isTraceRecording, isFalse);
    expect(transport.pulledTo, 'C:\\temp\\demo.perfetto-trace');
  });
}
