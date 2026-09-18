import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../flutter_scrcpy/flutter_scrcpy.dart';
import '../mirror_controller.dart';
import 'ios_mirror_webview.dart';

class PaneBody extends StatelessWidget {
  const PaneBody({super.key, required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = controller.device;
    final session = controller.screenMirrorSession;

    // Android: live texture once the mirror is running.
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

    // iOS: pymobiledevice3 serve-web HEVC viewer, embedded on Windows.
    if (controller.isIosMirror &&
        controller.isScreenMirrorRunning &&
        controller.iosViewerUrl != null) {
      final url = controller.iosViewerUrl!;
      return IosMirrorWebView(
        url: url,
        fallback: _IosMirrorBrowserFallback(controller: controller, url: url),
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
        description: controller.isIosMirror
            ? (controller.iosPrepareHint ??
                  '正在为 ${device.displayName} 启动 iOS 镜像…')
            : '正在为 ${device.displayName} 启动屏幕镜像。',
      ),
      ScreenMirrorState.running => (
        icon: Icons.cast_connected_rounded,
        title: '镜像运行中',
        description: '正在控制 ${device.displayName} 的屏幕。',
      ),
      ScreenMirrorState.unsupported => (
        icon: Icons.phonelink_off_rounded,
        title: '不支持的设备',
        description: controller.screenMirrorError ?? '当前设备不支持屏幕镜像。',
      ),
      ScreenMirrorState.error => (
        icon: Icons.error_outline_rounded,
        title: '镜像不可用',
        description: controller.screenMirrorError ?? '无法启动镜像会话。',
      ),
      ScreenMirrorState.stopped => (
        icon: Icons.mobile_screen_share,
        title: '准备镜像',
        description: controller.isIosMirror
            ? '为 ${device.displayName} 启动 iOS 镜像'
                  '（需开发者模式；首次会自动下载并挂载开发者镜像）。'
            : '为 ${device.displayName} 启动屏幕镜像。',
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
          if (controller.isIosMirror &&
              controller.screenMirrorState == ScreenMirrorState.stopped) ...[
            const Gap(12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('静音启动'),
              subtitle: Text('开启后镜像不播放设备声音', style: theme.textTheme.bodySmall),
              value: controller.iosAudioMuted,
              onChanged: (muted) => controller.setIosAudioMuted(muted),
            ),
          ],
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
            label: Text(controller.isScreenMirrorRunning ? '停止镜像' : '开始镜像'),
          ),
        ],
      ),
    );
  }
}

/// Shown when the in-pane WebView is unavailable (non-Windows, no WebView2).
class _IosMirrorBrowserFallback extends StatelessWidget {
  const _IosMirrorBrowserFallback({
    required this.controller,
    required this.url,
  });

  final MirrorController controller;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.cast_connected_rounded,
            size: 42,
            color: theme.colorScheme.primary,
          ),
          const Gap(12),
          Text(
            '无法在窗口内播放',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          Text(
            '请在浏览器中打开画面，或复制地址到 Chrome / Edge。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '镜像地址',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(4),
                  SelectableText(
                    url,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Consolas',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => controller.openIosViewer(),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('打开浏览器画面'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已复制镜像地址')));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制地址'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
