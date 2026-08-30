import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xterm/xterm.dart';

import '../../data/device.dart';
import '../../services/app_breadcrumbs.dart';
import '../../session/feature_controller.dart';
import '../../utils/utils.dart';

enum AdbShellState { idle, connecting, ready, disconnected, error, unsupported }

/// Interactive Android `adb shell` backed by [xterm] Terminal (MIT).
class AdbShellController extends FeatureController {
  AdbShellController(super.session);

  final Terminal terminal = Terminal(maxLines: 10000);

  AdbShellState state = AdbShellState.idle;
  String? error;
  double paneWidth = 480;

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;
  bool _disposed = false;
  bool _startedOnce = false;
  bool _inputBound = false;

  bool get isAndroid => device is AndroidDevice;
  bool get canShell => isAndroid && isConnected;
  bool get isReady => state == AdbShellState.ready;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> ensureStarted() async {
    if (_startedOnce && _process != null) return;
    await restart();
  }

  Future<void> restart() async {
    if (_disposed) return;
    if (!isAndroid) {
      state = AdbShellState.unsupported;
      error = '终端仅支持已连接的 Android 设备。';
      _notify();
      return;
    }
    if (!isConnected) {
      state = AdbShellState.disconnected;
      error = '设备已断开连接。请重新连接后再打开终端。';
      _notify();
      return;
    }

    await _tearDownProcess();
    terminal.buffer.clear();
    terminal.setCursor(0, 0);

    state = AdbShellState.connecting;
    error = null;
    _notify();

    try {
      _bindInputIfNeeded();
      final process = await service.startInteractiveShell();
      if (_disposed) {
        process.kill();
        return;
      }
      _process = process;
      _startedOnce = true;

      _stdoutSub = process.stdout.listen(
        (chunk) {
          terminal.write(utf8.decode(chunk, allowMalformed: true));
        },
        onDone: () {
          if (_disposed) return;
          if (state == AdbShellState.ready) {
            state = AdbShellState.disconnected;
            error = 'Shell 已结束。可点「重连」再次打开。';
            _notify();
          }
        },
        onError: (Object err) {
          if (_disposed) return;
          state = AdbShellState.error;
          error = describeError(err);
          _notify();
        },
      );

      _stderrSub = process.stderr.listen((chunk) {
        terminal.write(utf8.decode(chunk, allowMalformed: true));
      });

      unawaited(
        process.exitCode.then((code) {
          if (_disposed) return;
          if (identical(_process, process)) {
            _process = null;
            state = AdbShellState.disconnected;
            error = 'Shell 已退出（代码 $code）。可点「重连」。';
            _notify();
          }
        }),
      );

      terminal.write('\r\n# adb shell — ${device.displayName}\r\n');
      state = AdbShellState.ready;
      AppBreadcrumbs.action(
        'Started adb shell for ${device.displayName}',
        category: 'adb_shell',
      );
      _notify();
    } catch (err) {
      if (_disposed) return;
      state = AdbShellState.error;
      error = describeError(err);
      _notify();
    }
  }

  void _bindInputIfNeeded() {
    if (_inputBound) return;
    _inputBound = true;
    terminal.onOutput = (data) {
      final process = _process;
      if (process == null) return;
      try {
        process.stdin.add(utf8.encode(data));
      } catch (_) {}
    };
  }

  Future<void> _tearDownProcess() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    final process = _process;
    _process = null;
    if (process != null) {
      try {
        process.kill();
      } catch (_) {}
    }
  }

  void setPaneWidth(double width) {
    final clamped = width.clamp(320.0, 900.0);
    if (paneWidth == clamped) return;
    paneWidth = clamped;
    _notify();
  }

  @override
  void onDeviceDisconnected() {
    unawaited(_tearDownProcess());
    state = AdbShellState.disconnected;
    error = '设备已断开连接。';
    _notify();
  }

  @override
  void onDeviceConnected() {
    if (_startedOnce) {
      unawaited(restart());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_tearDownProcess());
    super.dispose();
  }
}
