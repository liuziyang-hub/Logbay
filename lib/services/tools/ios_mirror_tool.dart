import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/app_log/app_logger.dart';
import 'pymobiledevice3_launcher.dart';

/// Live iOS screen mirror via pymobiledevice3
/// `developer core-device display serve-web` (iOS 17+, HEVC → browser).
///
/// Upstream: https://github.com/doronz88/pymobiledevice3
class IosMirrorSession {
  IosMirrorSession({required this.viewerUrl, required Process process})
    : _process = process;

  final String viewerUrl;
  final Process _process;
  bool _stopped = false;

  Future<int> get exitCode => _process.exitCode;

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _process.kill(ProcessSignal.sigterm);
    try {
      await _process.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      _process.kill(ProcessSignal.sigkill);
    }
  }

  /// Opens [viewerUrl] in the system browser (serve-web already embeds
  /// touch/button controls in the page).
  Future<void> openViewer() => IosMirrorTool.openUrl(viewerUrl);
}

class IosMirrorTool {
  IosMirrorTool({AppLogger? logger})
    : _logger = logger ?? AppLogger(source: 'IosMirrorTool');

  final AppLogger _logger;

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

    final port = httpPort ?? await _allocatePort();
    final args = command.args([
      'developer',
      'core-device',
      'display',
      'serve-web',
      '--userspace',
      '--tunnel',
      udid,
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

    return IosMirrorSession(viewerUrl: viewerUrl, process: process);
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

  static String _friendlyExit(int code, String stderr, String stdout) {
    final blob = '$stderr\n$stdout'.toLowerCase();
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
