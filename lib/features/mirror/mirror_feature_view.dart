import 'package:flutter/material.dart';

import '../../presentation/components/feature_view.dart';
import 'components/mirror_control_strip.dart';
import 'components/pane_body.dart';
import 'components/quality_button.dart';
import 'mirror_controller.dart';

/// Screen-mirror feature pane. Renders the live texture + controls, driven by a
/// [MirrorController]. [onClose] hides the pane (handled by the device screen).
class MirrorFeatureView extends FeatureView {
  const MirrorFeatureView({
    super.key,
    required this.controller,
    required VoidCallback onClose,
  }) : super(onClose: onClose);

  final MirrorController controller;

  @override
  State<MirrorFeatureView> createState() => _MirrorFeatureViewState();
}

class _MirrorFeatureViewState extends FeatureViewState<MirrorFeatureView> {
  MirrorController get controller => widget.controller;

  @override
  Listenable get listenable => controller;

  @override
  Widget buildContent(BuildContext context) {
    return FeaturePane(
      header: FeatureViewHeader(
        title: '屏幕镜像',
        closeTooltip: '关闭镜像面板',
        onClose: widget.onClose,
        actions: [
          IconButton(
            tooltip: controller.isScreenMirrorRunning ? '停止镜像' : '开始镜像',
            onPressed: controller.canStart || controller.isScreenMirrorRunning
                ? () {
                    if (controller.isScreenMirrorRunning) {
                      controller.stop();
                    } else {
                      controller.start();
                    }
                  }
                : null,
            icon: Icon(
              controller.isScreenMirrorRunning
                  ? Icons.stop_circle_outlined
                  : Icons.play_arrow,
            ),
          ),
          if (controller.isIosMirror && controller.iosViewerUrl != null)
            IconButton(
              tooltip: '在浏览器中打开画面',
              onPressed: () => controller.openIosViewer(),
              icon: const Icon(Icons.open_in_browser),
            ),
          if (!controller.isIosMirror) QualityButton(controller: controller),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child:
                controller.isIosMirror &&
                    controller.isScreenMirrorRunning &&
                    controller.iosViewerUrl != null
                ? PaneBody(controller: controller)
                : Center(child: PaneBody(controller: controller)),
          ),
          MirrorControlStrip(controller: controller),
        ],
      ),
    );
  }
}
