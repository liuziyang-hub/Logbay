import 'dart:convert';
import 'dart:io';

import '../../features/app_log/app_logger.dart';
import 'pymobiledevice3_launcher.dart';

/// One usbmux entry from `pymobiledevice3 usbmux list`.
class UsbmuxDeviceEntry {
  const UsbmuxDeviceEntry({
    required this.udid,
    required this.connectionType,
    this.deviceName,
    this.productType,
    this.productVersion,
  });

  final String udid;

  /// `USB` or `Network` (pymobiledevice3 / usbmuxd).
  final String connectionType;
  final String? deviceName;
  final String? productType;
  final String? productVersion;

  bool get isNetwork =>
      connectionType.toLowerCase() == 'network' ||
      connectionType.toLowerCase() == 'wifi';

  bool get isUsb => connectionType.toLowerCase() == 'usb';
}

/// pymobiledevice3 helpers for Wi‑Fi lockdown + usbmux discovery.
class IosWirelessTool {
  IosWirelessTool({AppLogger? logger})
    : _logger = logger ?? AppLogger(source: 'IosWirelessTool');

  final AppLogger _logger;

  static Future<bool> isAvailable() => Pymobiledevice3Launcher.isAvailable();

  /// Enables or disables lockdown Wi‑Fi connections (`wifi-connections on|off`).
  ///
  /// Requires a paired USB (or already-network) lockdown session. On success
  /// the device can reappear over usbmux Network after unplugging (same Wi‑Fi,
  /// Apple Mobile Device Support on Windows).
  Future<void> setWifiConnections({required bool enabled, String? udid}) async {
    final command = await _requireCommand();
    final args = command.args([
      'lockdown',
      'wifi-connections',
      enabled ? 'on' : 'off',
      if (udid != null && udid.isNotEmpty) ...['--udid', udid],
    ]);
    _logger.info(
      'lockdown wifi-connections ${enabled ? 'on' : 'off'}'
      '${udid == null ? '' : ' ($udid)'}',
    );
    final result = await Process.run(
      command.executable,
      args,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      final detail = _combined(result).trim();
      throw IosWirelessException(
        detail.isEmpty
            ? '开启/关闭 Wi‑Fi lockdown 失败（exit ${result.exitCode}）。'
            : '开启/关闭 Wi‑Fi lockdown 失败：\n$detail',
      );
    }
  }

  /// Reads current EnableWifiConnections when [enabled] is omitted by CLI.
  Future<bool?> getWifiConnections({String? udid}) async {
    final command = await Pymobiledevice3Launcher.resolve();
    if (command == null) return null;
    final args = command.args([
      'lockdown',
      'wifi-connections',
      if (udid != null && udid.isNotEmpty) ...['--udid', udid],
    ]);
    final result = await Process.run(
      command.executable,
      args,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) return null;
    final out = _combined(result);
    final match = RegExp(
      r'EnableWifiConnections["\s:]+(true|false|True|False|1|0)',
      caseSensitive: false,
    ).firstMatch(out);
    if (match == null) return null;
    final raw = match.group(1)!.toLowerCase();
    return raw == 'true' || raw == '1';
  }

  /// Lists USB + Network devices known to usbmuxd via pymobiledevice3.
  Future<List<UsbmuxDeviceEntry>> listUsbmuxDevices() async {
    final command = await Pymobiledevice3Launcher.resolve();
    if (command == null) return const [];

    final args = command.args(['usbmux', 'list']);
    final result = await Process.run(
      command.executable,
      args,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      _logger.info('usbmux list failed: ${_combined(result).trim()}');
      return const [];
    }
    return parseUsbmuxListOutput(_combined(result));
  }

  /// Parses `usbmux list` JSON (list of lockdown short_info dicts, or UDIDs).
  static List<UsbmuxDeviceEntry> parseUsbmuxListOutput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];

    // Prefer the last JSON array/object in the blob (pmd3 may log before JSON).
    final jsonStart = trimmed.indexOf('[');
    final jsonObjStart = trimmed.indexOf('{');
    String candidate = trimmed;
    if (jsonStart >= 0 && (jsonObjStart < 0 || jsonStart <= jsonObjStart)) {
      candidate = trimmed.substring(jsonStart);
    } else if (jsonObjStart >= 0) {
      candidate = trimmed.substring(jsonObjStart);
    }

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is List) {
        return decoded
            .map(_entryFromJson)
            .whereType<UsbmuxDeviceEntry>()
            .toList(growable: false);
      }
      if (decoded is Map) {
        final entry = _entryFromJson(decoded);
        return entry == null ? const [] : [entry];
      }
    } catch (_) {
      // Fall through to line-oriented salvage.
    }

    // --simple style: one UDID per line (unknown connection → treat as USB).
    return trimmed
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('{'))
        .where((line) => RegExp(r'^[0-9A-Fa-f-]{8,}$').hasMatch(line))
        .map((udid) => UsbmuxDeviceEntry(udid: udid, connectionType: 'USB'))
        .toList(growable: false);
  }

  static UsbmuxDeviceEntry? _entryFromJson(Object? value) {
    if (value is String) {
      final udid = value.trim();
      if (udid.isEmpty) return null;
      return UsbmuxDeviceEntry(udid: udid, connectionType: 'USB');
    }
    if (value is! Map) return null;
    final map = value.map((k, v) => MapEntry(k.toString(), v));
    final udid = _stringField(map, const [
      'UniqueDeviceID',
      'Identifier',
      'SerialNumber',
      'udid',
      'serial',
    ]);
    if (udid == null || udid.isEmpty) return null;
    final connectionType =
        _stringField(map, const [
          'ConnectionType',
          'connection_type',
          'connectionType',
        ]) ??
        'USB';
    return UsbmuxDeviceEntry(
      udid: udid,
      connectionType: connectionType,
      deviceName: _stringField(map, const ['DeviceName', 'deviceName', 'name']),
      productType: _stringField(map, const ['ProductType', 'productType']),
      productVersion: _stringField(map, const [
        'ProductVersion',
        'productVersion',
      ]),
    );
  }

  static String? _stringField(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Future<Pymobiledevice3Command> _requireCommand() async {
    final command = await Pymobiledevice3Launcher.resolve();
    if (command == null) {
      throw IosWirelessException(
        '未找到 pymobiledevice3。请先安装：\n'
        'pip install -U pymobiledevice3',
      );
    }
    return command;
  }

  static String _combined(ProcessResult result) {
    final out = result.stdout is String ? result.stdout as String : '';
    final err = result.stderr is String ? result.stderr as String : '';
    if (out.isEmpty) return err;
    if (err.isEmpty) return out;
    return '$out\n$err';
  }
}

class IosWirelessException implements Exception {
  IosWirelessException(this.message);
  final String message;

  @override
  String toString() => message;
}
