import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../data/device.dart';
import 'data/wireless_debug_models.dart';
import '../../services/devices_repository.dart';

class WirelessPairResult {
  const WirelessPairResult({
    required this.paired,
    this.autoConnected = false,
    this.connectAddresses = const [],
    this.message,
    this.error,
  });

  final bool paired;
  final bool autoConnected;
  final List<String> connectAddresses;
  final String? message;
  final String? error;

  bool get isSuccess => error == null;
  bool get shouldShowConnectAction =>
      paired && !autoConnected && connectAddresses.isNotEmpty;

  factory WirelessPairResult.failure({required String error}) {
    return WirelessPairResult(paired: false, error: error);
  }

  factory WirelessPairResult.paired({
    String? message,
    List<String> connectAddresses = const [],
  }) {
    return WirelessPairResult(
      paired: true,
      message: message,
      connectAddresses: connectAddresses,
    );
  }

  factory WirelessPairResult.autoConnected({required String message}) {
    return WirelessPairResult(
      paired: true,
      autoConnected: true,
      message: message,
    );
  }
}

/// Holds the credentials encoded in a wireless debugging pairing QR code.
///
/// The Android device scans [payload] and then advertises an mDNS pairing
/// service whose name equals [serviceName]; pairing is completed against that
/// service using [password].
class WirelessQrPairingSession {
  const WirelessQrPairingSession({
    required this.serviceName,
    required this.password,
  });

  final String serviceName;
  final String password;

  /// The `WIFI:T:ADB;...` string rendered as a QR code for the device to scan.
  String get payload => 'WIFI:T:ADB;S:$serviceName;P:$password;;';
}

class WirelessConnectionController extends ChangeNotifier {
  WirelessConnectionController({
    required DevicesRepository devicesRepository,
    required Future<void> Function(List<Device> devices) onDevicesApplied,
    required Future<void> Function(Device device) onActivateDevice,
    this.isDeviceSelectedInAnotherTab,
    this.selectedDeviceIdProvider,
    this.isRunningProvider,
  }) : _devicesRepository = devicesRepository,
       _onDevicesApplied = onDevicesApplied,
       _onActivateDevice = onActivateDevice;

  final DevicesRepository _devicesRepository;
  final Future<void> Function(List<Device> devices) _onDevicesApplied;
  final Future<void> Function(Device device) _onActivateDevice;
  final bool Function(String deviceId)? isDeviceSelectedInAnotherTab;
  final String? Function()? selectedDeviceIdProvider;
  final bool Function()? isRunningProvider;

  var _discoveringWireless = false;
  var _pairingWireless = false;
  var _connectingWireless = false;
  var _hasAttemptedWirelessDiscovery = false;
  var _wirelessServices = <WirelessDebugService>[];
  String? _wirelessMessage;
  String? _wirelessError;
  var _disposed = false;
  WirelessQrPairingSession? _qrSession;
  var _waitingForQrScan = false;
  var _qrCancelled = false;

  static const Duration _qrScanPollInterval = Duration(milliseconds: 1200);
  static const Duration _qrScanTimeout = Duration(minutes: 3);

  bool get isDiscoveringWireless => _discoveringWireless;
  bool get isPairingWireless => _pairingWireless;
  bool get isConnectingWireless => _connectingWireless;
  bool get isWaitingForQrScan => _waitingForQrScan;
  WirelessQrPairingSession? get qrSession => _qrSession;
  bool get isWirelessBusy =>
      _discoveringWireless ||
      _pairingWireless ||
      _connectingWireless ||
      _waitingForQrScan;
  bool get hasAttemptedWirelessDiscovery => _hasAttemptedWirelessDiscovery;
  List<WirelessDebugService> get wirelessServices =>
      List.unmodifiable(_wirelessServices);
  List<WirelessDebugService> get wirelessPairingServices => _wirelessServices
      .where((service) => service.type == WirelessDebugServiceType.pairing)
      .toList(growable: false);
  List<WirelessDebugService> get wirelessConnectServices => _wirelessServices
      .where((service) => service.type == WirelessDebugServiceType.connect)
      .toList(growable: false);
  String? get wirelessMessage => _wirelessMessage;
  String? get wirelessError => _wirelessError;
  String? get suggestedWirelessPairingAddress =>
      wirelessPairingServices.firstOrNull?.address;
  String? get suggestedWirelessConnectAddress =>
      wirelessConnectServices.firstOrNull?.address;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<WirelessServiceDiscoveryResult> discoverWirelessServices() async {
    if (_pairingWireless || _connectingWireless || _waitingForQrScan) {
      const error =
          '请先完成当前无线 ADB 操作，再开始新的操作。';
      _wirelessError = error;
      _wirelessMessage = null;
      _notify();
      return WirelessServiceDiscoveryResult.failure(error: error);
    }

    _discoveringWireless = true;
    _hasAttemptedWirelessDiscovery = true;
    _wirelessMessage = null;
    _wirelessError = null;
    _notify();

    try {
      final result = await _devicesRepository.discoverMdnsServices();
      if (_disposed) return result;

      if (result.isSuccess) {
        _wirelessServices = result.services;
        _wirelessError = null;
        _wirelessMessage = result.services.isEmpty
            ? '在本地网络未发现无线 ADB 服务。'
            : '发现 ${result.services.length} 个无线 ADB 服务。';
      } else {
        _wirelessServices = [];
        _wirelessMessage = null;
        _wirelessError = result.error;
      }

      return result;
    } finally {
      _discoveringWireless = false;
      _notify();
    }
  }

  Future<WirelessPairResult> pairWirelessDevice({
    required String address,
    required String pairingCode,
    Iterable<String> connectAddresses = const [],
  }) async {
    final normalizedAddress = address.trim();
    final normalizedCode = pairingCode.trim();
    if (normalizedAddress.isEmpty) {
      const error = '请输入配对地址，例如 192.168.0.104:45673。';
      _wirelessError = error;
      _wirelessMessage = null;
      _notify();
      return WirelessPairResult.failure(error: error);
    }
    if (normalizedCode.isEmpty) {
      const error = '请输入设备上显示的无线配对码。';
      _wirelessError = error;
      _wirelessMessage = null;
      _notify();
      return WirelessPairResult.failure(error: error);
    }
    if (_discoveringWireless || _connectingWireless || _waitingForQrScan) {
      const error =
          '请先完成当前无线 ADB 操作，再进行配对。';
      _wirelessError = error;
      _wirelessMessage = null;
      _notify();
      return WirelessPairResult.failure(error: error);
    }

    _pairingWireless = true;
    _wirelessMessage = null;
    _wirelessError = null;
    _notify();

    try {
      final result = await _devicesRepository.pairWirelessAndroidDevice(
        address: normalizedAddress,
        pairingCode: normalizedCode,
      );
      if (_disposed) {
        return result.isSuccess
            ? WirelessPairResult.paired(message: result.message)
            : WirelessPairResult.failure(
                error:
                    result.error ?? '与 $normalizedAddress 配对失败。',
              );
      }

      if (!result.isSuccess) {
        final error = result.error ?? '与 $normalizedAddress 配对失败。';
        _wirelessMessage = null;
        _wirelessError = error;
        return WirelessPairResult.failure(error: error);
      }

      _pairingWireless = false;
      _notify();

      final resolvedConnectAddresses = await _resolveWirelessConnectAddresses(
        pairingAddress: normalizedAddress,
        candidateAddresses: connectAddresses,
      );
      if (_disposed) {
        return WirelessPairResult.paired(
          message: result.message,
          connectAddresses: resolvedConnectAddresses,
        );
      }

      if (resolvedConnectAddresses.isEmpty) {
        final message =
            '${result.message ?? '配对成功。'} 未能自动发现连接端点。';
        _wirelessMessage = message;
        _wirelessError = null;
        return WirelessPairResult.paired(message: message);
      }

      final connectResult = await _connectWirelessDeviceInternal(
        candidateAddresses: resolvedConnectAddresses,
        host: _wirelessHostFromAddress(normalizedAddress),
        suppressFailureState: true,
      );
      if (_disposed) {
        return connectResult.isSuccess
            ? WirelessPairResult.autoConnected(
                message:
                    connectResult.message ??
                    '配对并连接成功。',
              )
            : WirelessPairResult.paired(
                message: connectResult.error,
                connectAddresses: resolvedConnectAddresses,
              );
      }

      if (connectResult.isSuccess) {
        final message =
            connectResult.message ?? '配对并连接成功。';
        _wirelessMessage = message;
        _wirelessError = null;
        return WirelessPairResult.autoConnected(message: message);
      }

      final message =
          '${result.message ?? '配对成功。'} 自动连接未能完成，您可以手动重试连接。';
      _wirelessMessage = message;
      _wirelessError = null;
      return WirelessPairResult.paired(
        message: message,
        connectAddresses: resolvedConnectAddresses,
      );
    } finally {
      _pairingWireless = false;
      _notify();
    }
  }

  /// Generates a fresh pairing QR code and waits for an Android device to scan
  /// it. Once the device starts advertising the matching mDNS pairing service,
  /// pairing (and automatic connection) proceeds through [pairWirelessDevice].
  ///
  /// The returned future completes with the pairing result, or `null` when the
  /// session is cancelled via [cancelQrPairing] or the controller is disposed.
  /// [qrSession] is populated synchronously before the first suspension so the
  /// UI can render the code immediately.
  Future<WirelessPairResult?> startQrPairing() {
    if (isWirelessBusy) {
      const error =
          '请先完成当前无线 ADB 操作，再使用 QR 码配对。';
      _wirelessError = error;
      _wirelessMessage = null;
      _notify();
      return Future.value(WirelessPairResult.failure(error: error));
    }

    final session = WirelessQrPairingSession(
      serviceName: _generateQrServiceName(),
      password: _generateQrPassword(),
    );
    _qrSession = session;
    _waitingForQrScan = true;
    _qrCancelled = false;
    _wirelessMessage =
        '请使用 Android 设备扫描 QR 码：'
        '无线调试 → 使用 QR 码配对设备。';
    _wirelessError = null;
    _notify();

    return _runQrPairingLoop(session);
  }

  void cancelQrPairing() {
    if (!_waitingForQrScan) return;
    _qrCancelled = true;
    _waitingForQrScan = false;
    _qrSession = null;
    _wirelessMessage = null;
    _wirelessError = null;
    _notify();
  }

  void cancelAllOperations() {
    cancelQrPairing();
  }

  Future<WirelessPairResult?> _runQrPairingLoop(
    WirelessQrPairingSession session,
  ) async {
    final deadline = DateTime.now().add(_qrScanTimeout);
    try {
      while (!_qrCancelled && !_disposed && DateTime.now().isBefore(deadline)) {
        final discovery = await _devicesRepository.discoverMdnsServices();
        if (_qrCancelled || _disposed) return null;

        final pairingService = discovery.services.firstWhereOrNull(
          (service) =>
              service.type == WirelessDebugServiceType.pairing &&
              service.name == session.serviceName,
        );

        if (pairingService != null) {
          // Hand off to the regular pairing flow, which also resolves a
          // connect endpoint and auto-connects when one is available.
          _waitingForQrScan = false;
          _qrSession = null;
          _notify();
          return await pairWirelessDevice(
            address: pairingService.address,
            pairingCode: session.password,
          );
        }

        await Future<void>.delayed(_qrScanPollInterval);
      }

      if (_qrCancelled || _disposed) return null;

      const error =
          '等待扫描 QR 码超时。请生成新码后重试。';
      _wirelessMessage = null;
      _wirelessError = error;
      return WirelessPairResult.failure(error: error);
    } finally {
      if (!_disposed && _waitingForQrScan) {
        _waitingForQrScan = false;
        _qrSession = null;
        _notify();
      }
    }
  }

  String _generateQrServiceName() => 'logbay-${_randomAlphaNumeric(10)}';

  String _generateQrPassword() => _randomAlphaNumeric(12);

  String _randomAlphaNumeric(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ),
    );
  }

  Future<DeviceCommandResult> connectWirelessDevice({
    String? address,
    Iterable<String> candidateAddresses = const [],
  }) async {
    final normalizedAddresses = <String>[];
    void addAddress(String raw) {
      final normalized = raw.trim();
      if (normalized.isEmpty || normalizedAddresses.contains(normalized)) {
        return;
      }
      normalizedAddresses.add(normalized);
    }

    if (address != null) {
      addAddress(address);
    }
    for (final candidate in candidateAddresses) {
      addAddress(candidate);
    }

    if (normalizedAddresses.isEmpty) {
      const error = '请输入连接地址，例如 192.168.0.117:37251。';
      _wirelessError = error;
      _wirelessMessage = null;
      _notify();
      return DeviceCommandResult.failure(error: error);
    }
    if (_discoveringWireless || _pairingWireless || _waitingForQrScan) {
      const error =
          '请先完成当前无线 ADB 操作，再连接设备。';
      _wirelessError = error;
      _wirelessMessage = null;
      _notify();
      return DeviceCommandResult.failure(error: error);
    }

    return _connectWirelessDeviceInternal(
      candidateAddresses: normalizedAddresses,
      host: _wirelessHostFromAddress(normalizedAddresses.first),
    );
  }

  Future<Device?> _awaitWirelessDevice({
    String? exactAddress,
    String? host,
  }) async {
    const attempts = 5;
    for (var attempt = 0; attempt < attempts; attempt++) {
      await _devicesRepository.refreshDevices(force: true);
      if (_disposed) return null;

      final fetchedDevices = _devicesRepository.devices;
      await _onDevicesApplied(fetchedDevices);
      final matchedDevice = fetchedDevices.firstWhereOrNull(
        (device) => _matchesConnectedWirelessDevice(
          device,
          exactAddress: exactAddress,
          host: host,
        ),
      );
      if (matchedDevice != null) {
        return matchedDevice;
      }

      if (attempt < attempts - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    return null;
  }

  Future<DeviceCommandResult> _connectWirelessDeviceInternal({
    required Iterable<String> candidateAddresses,
    String? host,
    bool suppressFailureState = false,
  }) async {
    final addresses = <String>[];
    for (final candidate in candidateAddresses) {
      final normalized = candidate.trim();
      if (normalized.isEmpty || addresses.contains(normalized)) continue;
      addresses.add(normalized);
    }

    if (addresses.isEmpty) {
      const error = '请输入连接地址，例如 192.168.0.117:37251。';
      if (!suppressFailureState) {
        _wirelessError = error;
        _wirelessMessage = null;
        _notify();
      }
      return DeviceCommandResult.failure(error: error);
    }

    _connectingWireless = true;
    _wirelessMessage = null;
    _wirelessError = null;
    _notify();

    try {
      final existingDevice = await _findConnectedWirelessDevice(
        exactAddresses: addresses,
        host: host,
      );
      if (_disposed) {
        return DeviceCommandResult.success(
          message: '使用现有无线连接。',
        );
      }
      if (existingDevice != null) {
        final reusedResult = await _activateConnectedWirelessDevice(
          existingDevice,
          prefixMessage: '无线设备已连接。',
        );
        if (!suppressFailureState || reusedResult.isSuccess) {
          _wirelessMessage = reusedResult.message;
          _wirelessError = reusedResult.error;
        }
        return reusedResult;
      }

      final failures = <String>[];
      for (final candidate in addresses) {
        final result = await _devicesRepository.connectWirelessAndroidDevice(
          candidate,
        );
        if (_disposed) {
          return result;
        }

        if (!result.isSuccess) {
          failures.add(result.error ?? '连接 $candidate 失败。');
          continue;
        }

        final matchedDevice = await _awaitWirelessDevice(
          exactAddress: candidate,
          host: host,
        );
        if (_disposed) {
          return result;
        }

        if (matchedDevice == null) {
          final message =
              '${result.message ?? '已连接 $candidate。'} 设备尚未出现在设备列表中。';
          if (!suppressFailureState) {
            _wirelessMessage = message;
            _wirelessError = null;
          }
          return DeviceCommandResult.success(message: message);
        }

        final activatedResult = await _activateConnectedWirelessDevice(
          matchedDevice,
          prefixMessage: result.message ?? '已连接 ${matchedDevice.id}。',
        );
        if (!suppressFailureState || activatedResult.isSuccess) {
          _wirelessMessage = activatedResult.message;
          _wirelessError = activatedResult.error;
        }
        return activatedResult;
      }

      final error = _describeWirelessConnectFailures(addresses, failures);
      if (!suppressFailureState) {
        _wirelessMessage = null;
        _wirelessError = error;
      }
      return DeviceCommandResult.failure(error: error);
    } finally {
      _connectingWireless = false;
      _notify();
    }
  }

  Future<List<String>> _resolveWirelessConnectAddresses({
    required String pairingAddress,
    Iterable<String> candidateAddresses = const [],
  }) async {
    final providedAddresses = <String>[];
    for (final candidate in candidateAddresses) {
      final normalized = candidate.trim();
      if (normalized.isEmpty || providedAddresses.contains(normalized)) {
        continue;
      }
      providedAddresses.add(normalized);
    }
    if (providedAddresses.isNotEmpty) {
      return providedAddresses;
    }

    final host = _wirelessHostFromAddress(pairingAddress);
    final cachedAddresses = _pickWirelessConnectAddresses(
      services: _wirelessServices,
      host: host,
    );
    if (cachedAddresses.isNotEmpty) {
      return cachedAddresses;
    }

    final refreshedDiscovery = await _refreshWirelessServicesSnapshot();
    if (_disposed || !refreshedDiscovery.isSuccess) {
      return cachedAddresses;
    }

    return _pickWirelessConnectAddresses(
      services: refreshedDiscovery.services,
      host: host,
    );
  }

  Future<WirelessServiceDiscoveryResult>
  _refreshWirelessServicesSnapshot() async {
    _hasAttemptedWirelessDiscovery = true;
    final result = await _devicesRepository.discoverMdnsServices();
    if (_disposed) return result;
    if (result.isSuccess) {
      _wirelessServices = result.services;
      _notify();
    }
    return result;
  }

  List<String> _pickWirelessConnectAddresses({
    required List<WirelessDebugService> services,
    required String? host,
  }) {
    final addresses = <String>[];
    final connectServices = services.where(
      (service) => service.type == WirelessDebugServiceType.connect,
    );

    for (final service in connectServices) {
      if (host != null && service.host != host) continue;
      if (!addresses.contains(service.address)) {
        addresses.add(service.address);
      }
    }

    if (addresses.isNotEmpty || host != null) {
      return addresses;
    }

    final allConnectAddresses = connectServices
        .map((service) => service.address)
        .toSet()
        .toList(growable: false);
    return allConnectAddresses.length == 1 ? allConnectAddresses : const [];
  }

  Future<Device?> _findConnectedWirelessDevice({
    required List<String> exactAddresses,
    required String? host,
  }) async {
    await _devicesRepository.refreshDevices(force: true);
    if (_disposed) return null;

    final fetchedDevices = _devicesRepository.devices;
    await _onDevicesApplied(fetchedDevices);
    return fetchedDevices.firstWhereOrNull(
      (device) => _matchesConnectedWirelessDevice(
        device,
        exactAddresses: exactAddresses,
        host: host,
      ),
    );
  }

  bool _matchesConnectedWirelessDevice(
    Device device, {
    String? exactAddress,
    List<String> exactAddresses = const [],
    String? host,
  }) {
    if (!device.isConnected || device.status != 'device') {
      return false;
    }
    if (exactAddress != null && device.id == exactAddress) {
      return true;
    }
    if (exactAddresses.contains(device.id)) {
      return true;
    }
    final deviceHost = _wirelessHostFromAddress(device.id);
    return host != null && deviceHost == host;
  }

  Future<DeviceCommandResult> _activateConnectedWirelessDevice(
    Device matchedDevice, {
    String? prefixMessage,
  }) async {
    final selectedDeviceId = selectedDeviceIdProvider?.call();
    if ((isDeviceSelectedInAnotherTab?.call(matchedDevice.id) ?? false) &&
        selectedDeviceId != matchedDevice.id) {
      final message =
          '${prefixMessage ?? '无线设备已连接。'} 该设备已在其他标签页中打开。';
      return DeviceCommandResult.success(message: message);
    }

    await _onActivateDevice(matchedDevice);
    if (_disposed) {
      return DeviceCommandResult.success(
        message: prefixMessage ?? '已连接 ${matchedDevice.id}。',
      );
    }

    final isActivatedInTab =
        selectedDeviceIdProvider?.call() == matchedDevice.id &&
        (isRunningProvider?.call() ?? false);
    final message = isActivatedInTab
        ? '${prefixMessage ?? '已连接 ${matchedDevice.id}。'} 此标签页中的实时日志已就绪。'
        : '已连接 ${matchedDevice.id}，并在此标签页中启动实时日志。';
    return DeviceCommandResult.success(message: message);
  }

  String _describeWirelessConnectFailures(
    List<String> addresses,
    List<String> failures,
  ) {
    if (addresses.length == 1) {
      return failures.isNotEmpty
          ? failures.last
          : '连接 ${addresses.single} 失败。';
    }

    final summary = failures.isNotEmpty
        ? failures.last
        : '所有已发现的连接端口均未成功。';
    return '已尝试 ${addresses.length} 个连接端口（${addresses.join(', ')}），均未成功。$summary';
  }

  String? _wirelessHostFromAddress(String? address) {
    if (address == null) return null;
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    final separatorIndex = trimmed.lastIndexOf(':');
    if (separatorIndex <= 0) return null;
    return trimmed.substring(0, separatorIndex);
  }

  @override
  void dispose() {
    _disposed = true;
    _qrCancelled = true;
    super.dispose();
  }
}
