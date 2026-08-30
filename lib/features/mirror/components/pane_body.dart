import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../flutter_scrcpy/flutter_scrcpy.dart';
import '../mirror_controller.dart';

class PaneBody extends StatelessWidget {
  const PaneBody({super.key, required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = controller.device;
    final session = controller.screenMirrorSession;

    // Display the live texture once the mirror is running.
    if (session != null && controller.isScreenMirrorRunning) {
      final aspectRatio = session.height > 0
          ? session.width / session.height
          : 9 / 16;
      return ScrcpyView(
        textureId: session.textureId,
        aspectRatio: aspectRatio,
        onTouch: controller.handleTouch,
      );
    }

    final (
      :icon,
      :title,
      :description,
    ) = switch (controller.screenMirrorState) {
      ScreenMirrorState.starting => (
        icon: Icons.hourglass_top_rounded,
        title: '正在启动镜像',
        description: '正在为 ${device.displayName} 启动屏幕镜像。',
      ),
      ScreenMirrorState.running => (
        icon: Icons.cast_connected_rounded,
        title: '镜像运行中',
        description: '正在控制 ${device.displayName} 的屏幕。',
      ),
      ScreenMirrorState.unsupported => (
        icon: Icons.phonelink_off_rounded,
        title: '不支持的设备',
        description:
            controller.screenMirrorError ??
            '屏幕镜像仅支持 Android 设备。',
      ),
      ScreenMirrorState.error => (
        icon: Icons.error_outline_rounded,
        title: '镜像不可用',
        description:
            controller.screenMirrorError ??
            '无法启动镜像会话。',
      ),
      ScreenMirrorState.stopped => (
        icon: Icons.mobile_screen_share,
        title: '准备镜像',
        description: '为 ${device.displayName} 启动屏幕镜像。',
      ),
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: theme.colorScheme.primary),
          const Gap(12),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(18),
          FilledButton.icon(
            onPressed: controller.isScreenMirrorRunning
                ? () => controller.stop()
                : controller.canStart
                ? () => controller.start()
                : null,
            icon: Icon(
              controller.isScreenMirrorRunning
                  ? Icons.stop_circle_outlined
                  : Icons.play_arrow,
            ),
            label: Text(
              controller.isScreenMirrorRunning ? '停止镜像' : '开始镜像',
            ),
          ),
        ],
      ),
    );
  }
}
