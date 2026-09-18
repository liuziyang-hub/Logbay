enum IosMirrorFailureKind {
  developerImage,
  tunnel,
  displayService,
  mediaInUse,
  codec,
  webView,
  portConflict,
  deviceUnavailable,
  unsupportedSystem,
  unknown,
}

class IosMirrorDiagnostic {
  const IosMirrorDiagnostic({
    required this.kind,
    required this.title,
    required this.message,
    required this.suggestion,
    required this.rawDetail,
  });

  final IosMirrorFailureKind kind;
  final String title;
  final String message;
  final String suggestion;
  final String rawDetail;

  String get userMessage => '$title：$message\n$suggestion';

  static IosMirrorDiagnostic classify(String raw) {
    final detail = raw.trim();
    final lower = detail.toLowerCase();
    if (_hasAny(lower, const [
      'code 9021',
      'code: 9021',
      'requires ios 27',
      'ios 27.0 or later',
    ])) {
      return _build(
        IosMirrorFailureKind.unsupportedSystem,
        '当前系统暂不支持可控制实时镜像',
        'Apple 的远程控制服务要求 iOS 27 或以上；当前设备系统无法启动该服务。',
        '这不是连接故障。你仍可截取当前画面；设备升级到 iOS 27 后可重新检测实时镜像。',
        detail,
      );
    }
    if (_hasAny(lower, const [
      'developer disk image',
      'personalized image',
      'cryptex',
      'imagemounter',
      'ddi',
    ])) {
      return _build(
        IosMirrorFailureKind.developerImage,
        '开发者镜像未就绪',
        '设备尚未正确挂载 Developer Disk Image 或个性化镜像。',
        '保持设备解锁并重新连接，然后点击重试；Logbay 会自动重新挂载开发者镜像。',
        detail,
      );
    }
    if (_hasAny(lower, const [
      'tunnel',
      'remotexpc',
      'remote service discovery',
      'rsd',
      'userspace',
    ])) {
      return _build(
        IosMirrorFailureKind.tunnel,
        'iOS 调试隧道连接失败',
        '设备的 RemoteXPC/RSD 通道未建立或已中断。',
        '确认手机已信任此电脑、保持解锁并重新插拔 USB；关闭其他占用 iOS 调试通道的软件后重试。',
        detail,
      );
    }
    if (_hasAny(lower, const [
      'code 9022',
      'code: 9022',
      'camera',
      'microphone',
      'avcapture',
    ])) {
      return _build(
        IosMirrorFailureKind.mediaInUse,
        '设备媒体通道被占用',
        '相机或麦克风正在被其他应用使用，系统拒绝启动实时投屏。',
        '关闭相机、通话、录音、直播或会议应用，再返回 Logbay 重试。',
        detail,
      );
    }
    if (_hasAny(lower, const [
      'displayservice',
      'invalidservice',
      'display service',
    ])) {
      return _build(
        IosMirrorFailureKind.displayService,
        '显示服务不可用',
        '当前设备没有提供 CoreDevice DisplayService，或开发者服务尚未完全启动。',
        '确认已开启开发者模式并重启手机；仍失败时可先使用浏览器查看或截图模式。',
        detail,
      );
    }
    if (_hasAny(lower, const [
      'hevc',
      'webcodec',
      'codec',
      'decoder',
      'h265',
    ])) {
      return _build(
        IosMirrorFailureKind.codec,
        '视频解码能力不可用',
        '当前 WebView2 或显卡环境无法解码 iOS 返回的 HEVC 视频流。',
        '更新 Microsoft Edge WebView2 和显卡驱动，或改用系统 Chrome/Edge 打开投屏。',
        detail,
      );
    }
    if (_hasAny(lower, const [
      'address already in use',
      'only one usage of each socket',
      'winerror 10048',
    ])) {
      return _build(
        IosMirrorFailureKind.portConflict,
        '本地端口被占用',
        '投屏服务无法绑定本机回环端口。',
        '关闭残留的投屏进程后重试，Logbay 会重新分配随机端口。',
        detail,
      );
    }
    if (_hasAny(lower, const [
      'no device',
      'device not found',
      'not paired',
      'pairing',
      'trust',
    ])) {
      return _build(
        IosMirrorFailureKind.deviceUnavailable,
        'iOS 设备不可用',
        '设备未连接、未配对，或尚未信任此电脑。',
        '解锁手机并确认“信任此电脑”，然后重新连接数据线。',
        detail,
      );
    }
    if (_hasAny(lower, const [
      'requires ios',
      'not supported on this ios',
      'unsupported os version',
    ])) {
      return _build(
        IosMirrorFailureKind.unsupportedSystem,
        '当前系统不支持实时投屏',
        '设备返回的开发者服务不具备实时显示能力。',
        '可以继续使用截图模式；系统或运行时更新后再尝试实时投屏。',
        detail,
      );
    }
    if (_hasAny(lower, const ['webview2', 'navigation failed'])) {
      return _build(
        IosMirrorFailureKind.webView,
        '内嵌浏览器加载失败',
        '投屏服务已启动，但内嵌 WebView2 无法加载本地画面。',
        '点击“在浏览器中打开”；同时检查或修复 WebView2 运行时。',
        detail,
      );
    }
    return _build(
      IosMirrorFailureKind.unknown,
      'iOS 投屏启动失败',
      '上游服务返回了无法识别的错误。',
      '请复制诊断信息后重试；若持续出现，可切换到浏览器或截图模式。',
      detail,
    );
  }

  static bool _hasAny(String value, List<String> patterns) =>
      patterns.any(value.contains);

  static IosMirrorDiagnostic _build(
    IosMirrorFailureKind kind,
    String title,
    String message,
    String suggestion,
    String rawDetail,
  ) => IosMirrorDiagnostic(
    kind: kind,
    title: title,
    message: message,
    suggestion: suggestion,
    rawDetail: redactForLog(rawDetail),
  );

  /// Removes host and device identifiers before a diagnostic is persisted.
  static String redactForLog(String raw) {
    return raw
        .replaceAll(
          RegExp(r'C:\\Users\\[^\\\r\n]+', caseSensitive: false),
          r'C:\Users\<redacted>',
        )
        .replaceAll(
          RegExp(r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{16}\b'),
          '<redacted-udid>',
        );
  }
}
