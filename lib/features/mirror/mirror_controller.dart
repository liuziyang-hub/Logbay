import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../data/device.dart';
import '../../services/app_breadcrumbs.dart';
import '../../services/device_session_repository.dart';
import '../../services/tools/ios_mirror_tool.dart';
import '../../session/feature_controller.dart';
import '../../utils/utils.dart';
import '../flutter_scrcpy/flutter_scrcpy.dart';

enum ScreenMirrorState { stopped, starting, running, unsupported, error }

/// Encoder quality presets for the screen mirror. Higher quality streams more
/// pixels/bits, which increases latency.
enum MirrorQuality {
  fastest('最快', '最低画质，最低延迟'),
  fast('快速', '较低画质，较低延迟'),
  normal('标准', '画质与延迟均衡'),
  high('高清', '最佳画质，较高延迟');

  const MirrorQuality(this.label, this.description);

  final String label;
  final String description;

  ScrcpyVideoOptions toOptions() => switch (this) {
    MirrorQuality.fastest => const ScrcpyVideoOptions(
      maxSize: 480,
      maxFps: 30,
      videoBitRate: 800000,
      control: true,
    ),
    MirrorQuality.fast => const ScrcpyVideoOptions(
      maxSize: 720,
      maxFps: 60,
      videoBitRate: 3000000,
      control: true,
    ),
    MirrorQuality.normal => const ScrcpyVideoOptions(
      maxSize: 1280,
      maxFps: 60,
      videoBitRate: 8000000,
      control: true,
    ),
    MirrorQuality.high => const ScrcpyVideoOptions(
      maxSize: 1920,
      maxFps: 60,
      videoBitRate: 16000000,
      control: true,
    ),
  };
}

/// Per-device screen-mirroring feature. Owns the live scrcpy session, encoder
/// quality, on-device recording, and pane width. Pane *visibility* lives on the
/// owning [DeviceSessionController]; this controller only manages the session.
class MirrorController extends FeatureController {
  MirrorController(super.session);

  var screenMirrorState = ScreenMirrorState.stopped;
  String? screenMirrorError;
  MirrorQuality mirrorQuality = MirrorQuality.normal;
  double paneWidth = 340;

  ScrcpyMirrorSession? _session;
  IosMirrorSession? _iosSession;
  ScreenRecordingSession? _recordingSession;
  bool _disposed = false;
  int _startGeneration = 0;

  /// Whether device→desktop clipboard changes are mirrored automatically.
  bool clipboardSyncEnabled = true;
  StreamSubscription<String>? _clipboardSub;

  /// When true, iOS serve-web is started with `--no-audio` (viewer muted).
  /// Default false = audio on (CLI does not pass `--no-audio`).
  bool iosAudioMuted = false;

  /// Live status while iOS DDI mount / serve-web is starting.
  String? iosPrepareHint;

  /// Number of consecutive automatic restarts (e.g. from rotation desyncs).
  /// Reset once a stream has survived longer than [_restartCooldown]; caps a
  /// restart storm from an app that bounces orientation before settling.
  int _autoRestarts = 0;
  DateTime? _sessionStartedAt;
  static const int _maxAutoRestarts = 6;
  static const Duration _restartCooldown = Duration(seconds: 4);

  ScrcpyMirrorSession? get screenMirrorSession => _session;

  /// iOS serve-web session (in-pane WebView on Windows), if running.
  IosMirrorSession? get iosMirrorSession => _iosSession;

  /// Viewer URL for iOS mirror, or null when not running.
  String? get iosViewerUrl => _iosSession?.viewerUrl;

  bool get isIosMirror => device is IosDevice;

  /// Native texture id of the live mirror, or null when not running.
  int? get textureId => _session?.textureId;

  bool get isScreenMirrorRunning =>
      screenMirrorState == ScreenMirrorState.running ||
      screenMirrorState == ScreenMirrorState.starting;

  bool get canStart => session.canMirror;

  bool get isRecording => _recordingSession != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Ensures the mirror is running (used when the pane is opened).
  Future<void> show() async {
    if (isScreenMirrorRunning) return;
    await start();
  }

  Future<void> start() async {
    if (device is AndroidDevice) {
      await _startAndroid();
      return;
    }
    if (device is IosDevice) {
      await _startIos();
      return;
    }
    screenMirrorError = '此设备类型不支持屏幕镜像。';
    screenMirrorState = ScreenMirrorState.unsupported;
    _notify();
  }

  Future<void> _startAndroid() async {
    if (!isConnected) {
      screenMirrorError = '所选设备已断开连接。';
      screenMirrorState = ScreenMirrorState.error;
      _notify();
      return;
    }

    await stop(notify: false);
    if (_disposed) return;

    final generation = ++_startGeneration;
    screenMirrorState = ScreenMirrorState.starting;
    screenMirrorError = null;
    AppBreadcrumbs.action(
      'Starting screen mirror for ${device.displayName}',
      category: 'mirror',
      data: {'quality': mirrorQuality.name},
    );
    _notify();

    try {
      final mirror = await service.startScreenMirror(
        options: mirrorQuality.toOptions(),
      );
      if (_disposed || generation != _startGeneration) {
        await mirror.stop();
        return;
      }

      _session = mirror;
      _sessionStartedAt = DateTime.now();
      screenMirrorState = ScreenMirrorState.running;
      AppBreadcrumbs.action(
        'Screen mirror running for ${device.displayName}',
        category: 'mirror',
      );
      _notify();
      unawaited(_watchExit(mirror));
      unawaited(_watchStream(mirror));
      _watchClipboard(mirror);
    } on ScrcpyMirrorException catch (error) {
      if (generation != _startGeneration || _disposed) return;
      screenMirrorState = ScreenMirrorState.error;
      screenMirrorError = error.message;
      AppBreadcrumbs.action(
        'Screen mirror failed for ${device.displayName}',
        category: 'mirror',
        level: SentryLevel.error,
        data: {'error': error.message},
      );
      _notify();
    } on UnsupportedError catch (error) {
      if (generation != _startGeneration || _disposed) return;
      screenMirrorState = ScreenMirrorState.unsupported;
      screenMirrorError = error.message;
      _notify();
    } catch (error) {
      if (generation != _startGeneration || _disposed) return;
      screenMirrorState = ScreenMirrorState.error;
      screenMirrorError = describeError(error);
      AppBreadcrumbs.action(
        'Screen mirror failed for ${device.displayName}',
        category: 'mirror',
        level: SentryLevel.error,
        data: {'error': describeError(error)},
      );
      _notify();
    }
  }

  Future<void> _startIos() async {
    if (!isConnected) {
      screenMirrorError = '所选设备已断开连接。';
      screenMirrorState = ScreenMirrorState.error;
      _notify();
      return;
    }

    await stop(notify: false);
    if (_disposed) return;

    final generation = ++_startGeneration;
    screenMirrorState = ScreenMirrorState.starting;
    screenMirrorError = null;
    iosPrepareHint = '正在检查开发者镜像…';
    AppBreadcrumbs.action(
      'Starting iOS screen mirror for ${device.displayName}',
      category: 'mirror',
    );
    _notify();

    try {
      final mirror = await service.startIosScreenMirror(
        noAudio: iosAudioMuted,
        onProgress: (message) {
          iosPrepareHint = message;
          _notify();
        },
      );
      if (_disposed || generation != _startGeneration) {
        await mirror.stop();
        return;
      }

      _iosSession = mirror;
      _sessionStartedAt = DateTime.now();
      iosPrepareHint = null;
      screenMirrorState = ScreenMirrorState.running;
      AppBreadcrumbs.action(
        'iOS screen mirror running for ${device.displayName}',
        category: 'mirror',
      );
      _notify();

      // Windows embeds the viewer in-pane. Other desktops still open
      // the system browser (no WebView2 embed there).
      if (!Platform.isWindows) {
        try {
          await mirror.openViewer();
        } catch (_) {
          // Viewer open is best-effort; session stays alive.
        }
      }

      unawaited(_watchIosExit(mirror, generation));
    } on IosMirrorException catch (error) {
      if (generation != _startGeneration || _disposed) return;
      iosPrepareHint = null;
      screenMirrorState = ScreenMirrorState.error;
      screenMirrorError = error.message;
      _notify();
    } on UnsupportedError catch (error) {
      if (generation != _startGeneration || _disposed) return;
      iosPrepareHint = null;
      screenMirrorState = ScreenMirrorState.unsupported;
      screenMirrorError = error.message;
      _notify();
    } catch (error) {
      if (generation != _startGeneration || _disposed) return;
      iosPrepareHint = null;
      screenMirrorState = ScreenMirrorState.error;
      screenMirrorError = describeError(error);
      _notify();
    }
  }

  Future<void> openIosViewer() async {
    final session = _iosSession;
    if (session == null) return;
    await session.openViewer();
  }

  /// Toggles iOS mirror mute (`--no-audio`). Restarts a live session so the
  /// CLI flag takes effect.
  Future<void> setIosAudioMuted(bool muted) async {
    if (iosAudioMuted == muted) return;
    iosAudioMuted = muted;
    _notify();
    if (isIosMirror && isScreenMirrorRunning) {
      await start();
    }
  }

  Future<void> _watchIosExit(IosMirrorSession mirror, int generation) async {
    final code = await mirror.exitCode;
    if (_disposed || generation != _startGeneration) return;
    if (!identical(_iosSession, mirror)) return;
    _iosSession = null;
    if (screenMirrorState == ScreenMirrorState.running ||
        screenMirrorState == ScreenMirrorState.starting) {
      screenMirrorState = ScreenMirrorState.error;
      screenMirrorError = 'iOS 镜像进程已退出（退出码 $code）。';
      _notify();
    }
  }

  Future<void> stop({bool notify = true}) async {
    _startGeneration++;
    final mirror = _session;
    _session = null;
    final ios = _iosSession;
    _iosSession = null;
    await _clipboardSub?.cancel();
    _clipboardSub = null;

    if (mirror != null) {
      await mirror.stop();
      AppBreadcrumbs.action(
        'Stopped screen mirror for ${device.displayName}',
        category: 'mirror',
      );
    }
    if (ios != null) {
      await ios.stop();
      AppBreadcrumbs.action(
        'Stopped iOS screen mirror for ${device.displayName}',
        category: 'mirror',
      );
    }

    if (_recordingSession != null) {
      await cancelRecording();
    }

    screenMirrorState = ScreenMirrorState.stopped;
    screenMirrorError = null;
    if (notify) _notify();
  }

  /// Restarts the mirror when its video stream dies unexpectedly. On this
  /// scrcpy build a device rotation perturbs the stream framing and there's no
  /// way to recover in place without visible corruption, so we reconnect for a
  /// clean handshake + keyframe. A cooldown-reset counter caps a restart storm
  /// (e.g. an app that bounces orientation a few times before settling).
  Future<void> _watchStream(ScrcpyMirrorSession mirror) async {
    await mirror.streamEnded;
    if (_disposed || !identical(_session, mirror)) return;
    if (screenMirrorState != ScreenMirrorState.running) return;

    // A stream that ran longer than the cooldown is a one-off, not a storm.
    final startedAt = _sessionStartedAt;
    if (startedAt != null &&
        DateTime.now().difference(startedAt) > _restartCooldown) {
      _autoRestarts = 0;
    }

    if (_autoRestarts >= _maxAutoRestarts) {
      _session = null;
      await mirror.stop();
      if (_disposed) return;
      screenMirrorState = ScreenMirrorState.error;
      screenMirrorError = '镜像流持续重置，已停止。';
      _notify();
      return;
    }

    _autoRestarts++;
    // Brief settle so a multi-step rotation finishes before we reconnect.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_disposed || !identical(_session, mirror)) return;
    await start();
  }

  Future<void> _watchExit(ScrcpyMirrorSession mirror) async {
    final exitCode = await mirror.exitCode;
    if (_disposed || !identical(_session, mirror)) return;
    _session = null;
    screenMirrorState = exitCode == 0
        ? ScreenMirrorState.stopped
        : ScreenMirrorState.error;
    screenMirrorError = exitCode == 0 ? null : '屏幕镜像已停止（退出码 $exitCode）。';
    _notify();
  }

  /// Forwards a pointer interaction on the mirror surface to the device.
  /// [nx]/[ny] are normalized (0..1) positions within the video rect.
  void handleTouch(ScrcpyTouchAction action, double nx, double ny) {
    final mirror = _session;
    final control = mirror?.control;
    if (mirror == null || control == null) return;
    final x = (nx.clamp(0.0, 1.0) * mirror.width).round();
    final y = (ny.clamp(0.0, 1.0) * mirror.height).round();
    control.touch(
      action,
      x: x,
      y: y,
      videoWidth: mirror.width,
      videoHeight: mirror.height,
    );
  }

  /// Injects a hardware / navigation key into the mirrored device. No-op when
  /// the control channel is unavailable.
  void handleKey(ScrcpyKey key) {
    _session?.control?.key(key);
  }

  /// Listens for device clipboard changes and mirrors them to the desktop
  /// clipboard, while [clipboardSyncEnabled] is on.
  void _watchClipboard(ScrcpyMirrorSession mirror) {
    final control = mirror.control;
    if (control == null) return;
    _clipboardSub = control.onDeviceClipboardChanged.listen((text) {
      if (!clipboardSyncEnabled || text.isEmpty) return;
      unawaited(Clipboard.setData(ClipboardData(text: text)));
    });
  }

  /// Toggles automatic device→desktop clipboard mirroring.
  void setClipboardSyncEnabled(bool enabled) {
    if (enabled == clipboardSyncEnabled) return;
    clipboardSyncEnabled = enabled;
    _notify();
  }

  /// Whether pasting from the desktop clipboard is currently possible.
  bool get canPasteToDevice =>
      isScreenMirrorRunning && _session?.control != null;

  /// Sends the desktop clipboard's text to the mirrored device and pastes it
  /// into the focused field. No-op when there's no live control channel or
  /// the clipboard has no text.
  Future<void> pasteFromClipboard() async {
    final control = _session?.control;
    if (control == null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    control.setClipboard(text, paste: true);
  }

  /// Switches the encoder quality preset. Restarts the live stream so the new
  /// resolution/bitrate take effect.
  Future<void> setQuality(MirrorQuality quality) async {
    if (quality == mirrorQuality) return;
    mirrorQuality = quality;
    _notify();
    if (isScreenMirrorRunning) {
      await start();
    }
  }

  /// Captures a PNG screenshot (Android screencap or iOS pmd3 / idevice).
  Future<Uint8List?> captureScreenshot() async {
    if (!isConnected) return null;
    if (device is! AndroidDevice && device is! IosDevice) return null;
    return service.captureScreenshot();
  }

  /// Cycles the mirrored device's display orientation.
  Future<void> rotate() async {
    if (device is! AndroidDevice || !isConnected) return;
    await service.rotateDevice();
  }

  /// Begins on-device screenrecord (does not require an active mirror session).
  Future<void> startRecording() async {
    if (device is! AndroidDevice || !isConnected || _recordingSession != null) {
      return;
    }
    _recordingSession = await service.startScreenRecording();
    _notify();
  }

  /// Stops recording and saves the finalized mp4 to [localPath].
  Future<void> stopRecording(String localPath) async {
    final recording = _recordingSession;
    _recordingSession = null;
    _notify();
    await recording?.stopAndPull(localPath);
  }

  /// Stops recording and discards it without saving.
  Future<void> cancelRecording() async {
    final recording = _recordingSession;
    _recordingSession = null;
    _notify();
    await recording?.cancel();
  }

  /// Adjusts the mirror pane width (clamped) when the user drags its edge.
  void setPaneWidth(double width) {
    final clamped = width.clamp(260.0, 720.0);
    if (clamped == paneWidth) return;
    paneWidth = clamped;
    _notify();
  }

  @override
  void onDeviceDisconnected() {
    unawaited(stop());
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop(notify: false));
    super.dispose();
  }
}
