import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/app_log/app_logger.dart';
import 'ios_developer_image_tool.dart';
import 'ios_wireless_tool.dart';
import 'pymobiledevice3_launcher.dart';

/// Live iOS screen mirror via pymobiledevice3
/// `developer core-device display serve-web` (iOS 17+, HEVC → browser).
///
/// Upstream: https://github.com/doronz88/pymobiledevice3
class IosMirrorSession {
  IosMirrorSession({required this.viewerUrl, Process? process})
    : _process = process;

  final String viewerUrl;
  final Process? _process;
  final Completer<int> _fakeExit = Completer<int>();
  bool _stopped = false;

  Future<int> get exitCode => _process?.exitCode ?? _fakeExit.future;

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    final process = _process;
    if (process == null) {
      if (!_fakeExit.isCompleted) _fakeExit.complete(0);
      return;
    }
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      process.kill(ProcessSignal.sigkill);
    }
  }

  /// Opens [viewerUrl] in the system browser (serve-web already embeds
  /// touch/button controls in the page).
  Future<void> openViewer() => IosMirrorTool.openUrl(viewerUrl);
}

class IosMirrorTool {
  IosMirrorTool({
    AppLogger? logger,
    IosDeveloperImageTool? imageTool,
    IosWirelessTool? wirelessTool,
  }) : _logger = logger ?? AppLogger(source: 'IosMirrorTool'),
       _imageTool = imageTool ?? IosDeveloperImageTool(),
       _wirelessTool = wirelessTool ?? IosWirelessTool();

  final AppLogger _logger;
  final IosDeveloperImageTool _imageTool;
  final IosWirelessTool _wirelessTool;

  static const minimumStableVersion = Pymobiledevice3Version(11, 15, 4);

  static Future<bool> isAvailable() => Pymobiledevice3Launcher.isAvailable();

  /// Starts serve-web bound to loopback and returns a session once the HTTP
  /// URL is observed (or after a short readiness wait).
  ///
  /// Audio is on by default (viewer auto-enables sound). Pass [noAudio] to
  /// add CLI `--no-audio` so the viewer starts muted.
  Future<IosMirrorSession> start({
    required String udid,
    int? httpPort,
    bool noAudio = false,
    void Function(String message)? onProgress,
  }) async {
    final command = await Pymobiledevice3Launcher.resolve();
    if (command == null) {
      throw IosMirrorException(
        '未找到 pymobiledevice3。请先安装：\n'
        'pip install -U pymobiledevice3\n'
        '并确保设备已开启开发者模式、已挂载 Developer Disk Image：\n'
        'pymobiledevice3 mounter auto-mount',
      );
    }

    await _checkCompatibility(command: command, udid: udid);

    try {
      await _imageTool.ensureMounted(udid: udid, onProgress: onProgress);
    } on IosDeveloperImageException catch (error) {
      throw IosMirrorException(error.message);
    }

    onProgress?.call('正在启动屏幕投流…');
    final port = httpPort ?? await _allocatePort();
    // serve-web does not accept --udid / --userspace/--tunnel together.
    // Current pmd3 default is the no-root userspace tunnel; target via env.
    final args = command.args([
      'developer',
      'core-device',
      'display',
      'serve-web',
      '--bind',
      '127.0.0.1',
      '--http-port',
      '$port',
      if (noAudio) '--no-audio',
    ]);

    _logger.info('Starting iOS mirror serve-web on 127.0.0.1:$port');
    final process = await Process.start(
      command.executable,
      args,
      runInShell: Platform.isWindows,
      environment: {...Platform.environment, 'PYMOBILEDEVICE3_UDID': udid},
    );

    final viewerUrl = 'http://127.0.0.1:$port/';
    final ready = Completer<void>();
    final stderrBuf = StringBuffer();
    final stdoutBuf = StringBuffer();

    void considerLine(String line) {
      final lower = line.toLowerCase();
      if (!ready.isCompleted &&
          (lower.contains('http://') ||
              lower.contains('serving') ||
              lower.contains('uvicorn') ||
              lower.contains('running on'))) {
        ready.complete();
      }
      if (lower.contains('error') ||
          lower.contains('traceback') ||
          lower.contains('invalidservice') ||
          lower.contains('not found')) {
        stderrBuf.writeln(line);
      }
    }

    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
          stdoutBuf.writeln(line);
          considerLine(line);
          _logger.info('[serve-web] $line');
        });
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
          stderrBuf.writeln(line);
          considerLine(line);
          _logger.info('[serve-web:err] $line');
        });

    // Either the process prints readiness, or we give the HTTP server a
    // moment and probe the port.
    try {
      await Future.any([
        ready.future,
        Future<void>.delayed(const Duration(seconds: 4)),
        process.exitCode.then((code) {
          throw IosMirrorException(
            _friendlyExit(code, stderrBuf.toString(), stdoutBuf.toString()),
          );
        }),
      ]);
    } on IosMirrorException {
      process.kill();
      rethrow;
    }

    if (!await _portOpen(port)) {
      // Give one more beat for slow tunnel bring-up.
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    if (!await _portOpen(port)) {
      final detail = stderrBuf.toString().trim();
      process.kill();
      throw IosMirrorException(
        detail.isEmpty
            ? 'iOS 镜像服务未能在端口 $port 启动。'
                  '请确认 iOS 17.4+、开发者模式已开，并已执行 mounter auto-mount。'
            : 'iOS 镜像启动失败：\n$detail',
      );
    }

    final serverFailure = await _probeCodecFailure(port);
    if (serverFailure != null) {
      process.kill();
      final message = friendlyServerFailure(serverFailure);
      if (_requiresNewerIos(serverFailure)) {
        throw UnsupportedError(message);
      }
      throw IosMirrorException(message);
    }

    return IosMirrorSession(viewerUrl: viewerUrl, process: process);
  }

  Future<void> _checkCompatibility({
    required Pymobiledevice3Command command,
    required String udid,
  }) async {
    final devices = await _wirelessTool.listUsbmuxDevices();
    UsbmuxDeviceEntry? selected;
    for (final entry in devices) {
      if (entry.udid.toLowerCase() == udid.toLowerCase()) {
        selected = entry;
        break;
      }
    }
    final productVersion = selected?.productVersion;
    final installed = await Pymobiledevice3Launcher.installedVersion(
      command: command,
    );
    final issue = compatibilityIssue(
      productVersion: productVersion,
      installedVersion: installed,
    );
    if (issue != null) throw UnsupportedError(issue);
  }

  @visibleForTesting
  static String? compatibilityIssue({
    String? productVersion,
    Pymobiledevice3Version? installedVersion,
  }) {
    final iosMajor = productVersion == null
        ? null
        : int.tryParse(productVersion.trim().split('.').first);
    if (iosMajor != null && iosMajor < 27) {
      return '当前设备为 iOS $productVersion。CoreDevice 实时投屏需要 iOS 27 或以上。\n'
          '你仍可使用“截图”功能查看当前画面；升级系统后可启用实时投屏和鼠标控制。';
    }
    if (installedVersion != null &&
        installedVersion.compareTo(minimumStableVersion) < 0) {
      return '当前 pymobiledevice3 版本为 $installedVersion，实时投屏需要 '
          '$minimumStableVersion 或以上。\n'
          '请执行：pip install -U pymobiledevice3，然后重新启动 Logbay。';
    }
    return null;
  }

  static bool _requiresNewerIos(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('requires ios 27') ||
        lower.contains('ios 27.0 or later');
  }

  @visibleForTesting
  static String friendlyServerFailure(String raw) {
    if (_requiresNewerIos(raw)) {
      return '此设备的系统不支持 CoreDevice 实时投屏；设备端要求 iOS 27 或以上。\n'
          '你仍可使用“截图”功能查看当前画面。';
    }
    final lower = raw.toLowerCase();
    if (lower.contains('camera') || lower.contains('microphone')) {
      return '无法开始 iOS 投屏：相机或麦克风正被其他应用占用。'
          '请关闭相机、录音等应用后重试。';
    }
    return 'iOS 投屏服务返回错误：\n${raw.trim()}';
  }

  static Future<void> openUrl(String url) async {
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.start('open', [url]);
    } else {
      await Process.start('xdg-open', [url]);
    }
  }

  static Future<int> _allocatePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static Future<bool> _portOpen(int port) async {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: const Duration(milliseconds: 400),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _probeCodecFailure(int port) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/codec'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode < 400) {
        await response.drain<void>();
        return null;
      }
      return await response
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
    } catch (_) {
      // Older serve-web versions may not expose /codec until the page loads.
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _friendlyExit(int code, String stderr, String stdout) {
    final blob = '$stderr\n$stdout'.toLowerCase();
    if (_requiresNewerIos(blob)) {
      return friendlyServerFailure(blob);
    }
    if (blob.contains('developer') && blob.contains('disk')) {
      return '需要先挂载 Developer Disk Image：\n'
          'pymobiledevice3 mounter auto-mount';
    }
    if (blob.contains('tunnel') || blob.contains('userspace')) {
      return '无法建立 iOS 17+ 隧道。请确认 USB 已信任，并重试。\n'
          '原始输出：${stderr.trim().isEmpty ? stdout.trim() : stderr.trim()}';
    }
    if (blob.contains('no device') || blob.contains('not found')) {
      return '未找到该 iOS 设备，请重新插拔并信任此电脑。';
    }
    final detail = stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim();
    return 'iOS 镜像进程退出（code $code）${detail.isEmpty ? '' : '：\n$detail'}';
  }
}

class IosMirrorException implements Exception {
  IosMirrorException(this.message);
  final String message;

  @override
  String toString() => message;
}
