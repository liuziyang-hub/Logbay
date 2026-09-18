import 'dart:async';

import '../../session/feature_controller.dart';
import 'data/performance_sample.dart';
import 'data/performance_session.dart';
import 'services/device_performance_backend.dart';

enum PerformanceCollectionState { idle, starting, running, stopping, failed }

class PerformanceController extends FeatureController {
  PerformanceController(
    super.session, {
    required DevicePerformanceBackend backend,
  }) : _backend = backend;

  final DevicePerformanceBackend _backend;

  PerformanceCollectionState _state = PerformanceCollectionState.idle;
  PerformanceSession? _currentSession;
  StreamSubscription<PerformanceSample>? _subscription;
  String? _errorMessage;
  int _generation = 0;
  bool _disposed = false;
  double paneWidth = 760;

  PerformanceCollectionState get state => _state;
  PerformanceSession? get currentSession => _currentSession;
  List<PerformanceSample> get samples => _currentSession?.samples ?? const [];
  String? get errorMessage => _errorMessage;
  bool get isRunning => _state == PerformanceCollectionState.running;

  void setPaneWidth(double width) {
    final clamped = width.clamp(420.0, 1200.0);
    if (clamped == paneWidth) return;
    paneWidth = clamped;
    _notify();
  }

  Future<void> start({
    String? applicationId,
    Duration sampleInterval = const Duration(seconds: 1),
  }) async {
    if (_disposed || _state == PerformanceCollectionState.starting) return;
    if (!isConnected) {
      _fail('设备未连接，无法开始性能采集。');
      return;
    }

    await stop();
    if (_disposed) return;

    final generation = ++_generation;
    _state = PerformanceCollectionState.starting;
    _errorMessage = null;
    _currentSession = PerformanceSession(
      deviceId: device.id,
      applicationId: applicationId,
      startedAt: DateTime.now(),
      sampleInterval: sampleInterval,
    );
    _notify();

    try {
      final stream = _backend.start(
        PerformanceCollectionRequest(
          applicationId: applicationId,
          sampleInterval: sampleInterval,
        ),
      );
      _subscription = stream.listen(
        (sample) => _handleSample(sample, generation),
        onError: (Object error, StackTrace stackTrace) {
          _handleStreamError(error, generation);
        },
        onDone: () => _handleStreamDone(generation),
        cancelOnError: false,
      );
      if (_disposed || generation != _generation) return;
      _state = PerformanceCollectionState.running;
      _notify();
    } catch (error) {
      if (generation == _generation) _fail(_friendlyError(error));
    }
  }

  Future<void> stop() async {
    if (_state == PerformanceCollectionState.idle && _subscription == null) {
      return;
    }
    _generation++;
    _state = PerformanceCollectionState.stopping;
    _notify();
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    try {
      await _backend.stop();
    } catch (error) {
      _errorMessage = _friendlyError(error);
    }
    _currentSession?.finish();
    if (_disposed) return;
    _state = PerformanceCollectionState.idle;
    _notify();
  }

  void _handleSample(PerformanceSample sample, int generation) {
    if (_disposed || generation != _generation) return;
    _currentSession?.add(sample);
    _notify();
  }

  void _handleStreamError(Object error, int generation) {
    if (_disposed || generation != _generation) return;
    _fail(_friendlyError(error));
  }

  void _handleStreamDone(int generation) {
    if (_disposed || generation != _generation) return;
    _currentSession?.finish();
    _state = PerformanceCollectionState.idle;
    _notify();
  }

  void _fail(String message) {
    _errorMessage = message;
    _currentSession?.finish();
    _state = PerformanceCollectionState.failed;
    _notify();
  }

  String _friendlyError(Object error) {
    final message = error.toString().trim();
    return message.isEmpty ? '性能采集发生未知错误。' : message;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void onDeviceDisconnected() {
    unawaited(stop());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
    unawaited(_backend.dispose());
    _currentSession?.finish();
    super.dispose();
  }
}
