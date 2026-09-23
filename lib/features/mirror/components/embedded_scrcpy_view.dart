import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Hosts the isolated SDL window without creating a Flutter video texture.
class EmbeddedScrcpyView extends StatefulWidget {
  const EmbeddedScrcpyView({super.key, required this.processId});

  final int processId;

  @override
  State<EmbeddedScrcpyView> createState() => _EmbeddedScrcpyViewState();
}

class _EmbeddedScrcpyViewState extends State<EmbeddedScrcpyView> {
  static const _channel = MethodChannel('flutter_scrcpy/video');
  Timer? _timer;
  bool _busy = false;
  bool _attached = false;
  bool _visible = false;
  bool _active = true;
  String? _error;
  final _started = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _sync());
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  Future<void> _hide() async {
    _visible = false;
    try {
      await _channel.invokeMethod<void>('hideEmbedded', {
        'pid': widget.processId,
      });
    } on PlatformException {
      // The native process may already have exited during shutdown.
    }
  }

  Future<void> _sync() async {
    if (!mounted || !_active || _busy || _error != null) return;
    final object = context.findRenderObject();
    var visible =
        TickerMode.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        object is RenderBox &&
        object.attached &&
        object.hasSize;
    for (
      var ancestor = object?.parent;
      ancestor != null;
      ancestor = ancestor.parent
    ) {
      if (ancestor is RenderOffstage && ancestor.offstage) visible = false;
    }
    if (!visible) {
      if (_visible) await _hide();
      return;
    }
    final box = object! as RenderBox;
    final scale = View.of(context).devicePixelRatio;
    final origin = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      origin.dx * scale,
      origin.dy * scale,
      box.size.width * scale,
      box.size.height * scale,
    );
    if (rect.isEmpty) {
      if (_visible) await _hide();
      return;
    }
    _busy = true;
    try {
      final ready =
          await _channel.invokeMethod<bool>('updateEmbedded', {
            'pid': widget.processId,
            'x': rect.left.round(),
            'y': rect.top.round(),
            'width': rect.width.round(),
            'height': rect.height.round(),
          }) ??
          false;
      if (!mounted || !_active) {
        await _hide();
        return;
      }
      _visible = ready;
      if (ready && !_attached) setState(() => _attached = true);
      if (!ready && _started.elapsed > const Duration(seconds: 20)) {
        setState(() => _error = '镜像画面未就绪，请停止镜像后重试。');
      }
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message ?? '无法嵌入镜像画面。');
    } finally {
      _busy = false;
    }
  }

  @override
  void deactivate() {
    _active = false;
    unawaited(_hide());
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_hide());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: _error != null
        ? Center(child: Text(_error!, textAlign: TextAlign.center))
        : !_attached
        ? const Center(child: CircularProgressIndicator())
        : null,
  );
}
