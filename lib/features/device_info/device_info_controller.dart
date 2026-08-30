import 'dart:async';

import '../../services/app_breadcrumbs.dart';
import '../../session/feature_controller.dart';
import '../../utils/utils.dart';
import 'data/device_details.dart';

enum DeviceInfoLoadState { idle, loading, ready, error }

/// Per-device 「详情」pane: identity, OS, battery, storage, performance.
class DeviceInfoController extends FeatureController {
  DeviceInfoController(super.session);

  DeviceInfoLoadState loadState = DeviceInfoLoadState.idle;
  String? error;
  DeviceDetailsSnapshot? snapshot;
  double paneWidth = 380;
  bool _disposed = false;
  bool _loadedOnce = false;

  bool get isLoading => loadState == DeviceInfoLoadState.loading;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (_loadedOnce) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (!isConnected) {
      loadState = DeviceInfoLoadState.error;
      error = '设备已断开连接。请重新连接以查看详情。';
      _notify();
      return;
    }
    if (isLoading) return;

    _loadedOnce = true;
    loadState = DeviceInfoLoadState.loading;
    error = null;
    _notify();

    try {
      final next = await service.fetchDeviceDetails();
      if (_disposed) return;
      snapshot = next;
      if (next.error != null && next.isEmpty) {
        loadState = DeviceInfoLoadState.error;
        error = next.error;
      } else {
        loadState = DeviceInfoLoadState.ready;
        error = next.error;
      }
      AppBreadcrumbs.action(
        'Loaded device details for ${device.displayName}',
        category: 'device_info',
      );
      _notify();
    } catch (err) {
      if (_disposed) return;
      loadState = DeviceInfoLoadState.error;
      error = describeError(err);
      _notify();
    }
  }

  void setPaneWidth(double width) {
    final clamped = width.clamp(300.0, 720.0);
    if (paneWidth == clamped) return;
    paneWidth = clamped;
    _notify();
  }

  @override
  void onDeviceConnected() {
    unawaited(refresh());
  }

  @override
  void onDeviceDisconnected() {
    error = '设备已断开连接。';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
