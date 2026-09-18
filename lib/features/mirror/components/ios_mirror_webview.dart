import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

/// Embeds the pymobiledevice3 serve-web HEVC viewer (Windows WebView2).
///
/// Other platforms, missing WebView2, or init failure → [fallback].
class IosMirrorWebView extends StatefulWidget {
  const IosMirrorWebView({
    super.key,
    required this.url,
    required this.fallback,
  });

  final String url;
  final Widget fallback;

  @override
  State<IosMirrorWebView> createState() => _IosMirrorWebViewState();
}

class _IosMirrorWebViewState extends State<IosMirrorWebView> {
  static bool _environmentReady = false;

  WebviewController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      unawaited(_init());
    } else {
      _failed = true;
    }
  }

  Future<void> _init() async {
    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null) {
        throw StateError('WebView2 运行时未安装');
      }
      if (!_environmentReady) {
        try {
          await WebviewController.initializeEnvironment(
            additionalArguments: '--autoplay-policy=no-user-gesture-required',
          );
        } catch (_) {
          // Already initialized by a previous session.
        }
        _environmentReady = true;
      }

      final controller = WebviewController();
      await controller.initialize();
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await controller.setBackgroundColor(const Color(0x00000000));
      await controller.loadUrl(widget.url);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(IosMirrorWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && _controller != null) {
      unawaited(_controller!.loadUrl(widget.url));
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Future<WebviewPermissionDecision> _onPermission(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    return WebviewPermissionDecision.allow;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || !Platform.isWindows) return widget.fallback;
    final controller = _controller;
    if (!_ready || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Webview(controller, permissionRequested: _onPermission);
  }
}
