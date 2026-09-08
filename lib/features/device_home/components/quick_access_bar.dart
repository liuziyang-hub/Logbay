import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../data/device.dart';
import '../../../session/device_session_controller.dart';
import 'home_primitives.dart';

/// The feature launcher strip — every pane the app offers for this device,
/// kept above the fold so a new user can see what Eagly does at a glance.
class QuickAccessBar extends StatelessWidget {
  const QuickAccessBar({super.key, required this.session});

  final DeviceSessionController session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final isAndroid = s.platform == DevicePlatform.android;

    // Which tiles exist depends on the platform; whether they are *enabled*
    // depends on the connection — a disconnected device keeps the launcher
    // in place (greyed) instead of collapsing it to a single button.
    final tiles = <Widget>[
      _ShortcutTile(
        icon: Icons.article_outlined,
        label: '日志',
        sublabel: '实时设备日志',
        accelerator: acceleratorLabel('R'),
        isActive: s.isLogsOpen,
        onTap: s.toggleLogs,
        accentIndex: 0,
      ),
      _ShortcutTile(
        icon: Icons.terminal_outlined,
        label: '终端',
        sublabel: '运行设备命令',
        isActive: s.isTerminalOpen,
        onTap: s.canUseTerminal ? s.toggleTerminal : null,
        accentIndex: 1,
      ),
      _ShortcutTile(
        icon: Icons.mobile_screen_share_outlined,
        label: '镜像',
        sublabel: isAndroid ? '控制设备屏幕' : '浏览器投屏',
        isActive: s.isMirrorOpen,
        onTap: s.canMirror ? s.toggleMirror : null,
        accentIndex: 1,
      ),
      if (!isAndroid)
        _ShortcutTile(
          icon: Icons.bug_report_outlined,
          label: '崩溃',
          sublabel: '崩溃报告',
          isActive: s.isCrashReportsOpen,
          onTap: s.canReadCrashReports ? s.toggleCrashReports : null,
          accentIndex: 2,
        ),
      _ShortcutTile(
        icon: Icons.folder_open_outlined,
        label: '文件',
        sublabel: '浏览与传输',
        isActive: s.isFilesOpen,
        onTap: s.canManageFiles ? s.toggleFiles : null,
        accentIndex: 2,
      ),
      _ShortcutTile(
        icon: Icons.apps_outlined,
        label: '应用',
        sublabel: '已安装应用',
        isActive: s.isAppsOpen,
        onTap: s.canManageApps ? s.toggleApps : null,
        accentIndex: 0,
      ),
      if (s.canRunUtilities)
        _ShortcutTile(
          icon: Icons.handyman_outlined,
          label: '工具',
          sublabel: '常用设备命令',
          isActive: s.isUtilitiesOpen,
          onTap: s.toggleUtilities,
          accentIndex: 1,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const Gap(10),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
        if (isAndroid) ...[
          const Gap(10),
          _AndroidCaptureActions(session: session),
        ] else ...[
          const Gap(10),
          _IosCaptureActions(session: session),
        ],
      ],
    );
  }
}

class _AndroidCaptureActions extends StatelessWidget {
  const _AndroidCaptureActions({required this.session});

  final DeviceSessionController session;

  static String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session.mirrorController,
      builder: (context, _) {
        final enabled = session.canMirror;
        final recording = session.isScreenRecording;
        return Row(
          children: [
            OutlinedButton.icon(
              onPressed: enabled ? () => _captureScreenshot(context) : null,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('截图'),
            ),
            const Gap(8),
            OutlinedButton.icon(
              onPressed: !enabled
                  ? null
                  : () => recording
                        ? _stopRecording(context)
                        : _startRecording(context),
              icon: Icon(
                recording ? Icons.stop_circle : Icons.videocam_outlined,
                size: 18,
              ),
              label: Text(recording ? '停止录制' : '录屏'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _captureScreenshot(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await session.captureScreenshot();
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('无法截图。')));
        return;
      }
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '保存截图',
        fileName: 'screenshot-${_timestamp()}.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      if (path == null) return;
      final outPath = path.toLowerCase().endsWith('.png') ? path : '$path.png';
      await File(outPath).writeAsBytes(bytes);
      messenger.showSnackBar(SnackBar(content: Text('截图已保存至 $outPath')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('截图失败：$error')));
    }
  }

  Future<void> _startRecording(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await session.startScreenRecording();
      messenger.showSnackBar(const SnackBar(content: Text('录制中…再次点击停止。')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('录制失败：$error')));
    }
  }

  Future<void> _stopRecording(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '保存录屏',
        fileName: 'recording-${_timestamp()}.mp4',
        type: FileType.custom,
        allowedExtensions: ['mp4'],
      );
      if (path == null) {
        await session.mirrorController.cancelRecording();
        return;
      }
      final outPath = path.toLowerCase().endsWith('.mp4') ? path : '$path.mp4';
      await session.stopScreenRecording(outPath);
      messenger.showSnackBar(SnackBar(content: Text('录屏已保存至 $outPath')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('停止录制失败：$error')));
    }
  }
}

class _IosCaptureActions extends StatelessWidget {
  const _IosCaptureActions({required this.session});

  final DeviceSessionController session;

  static String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session.mirrorController,
      builder: (context, _) {
        final enabled = session.canMirror;
        return Row(
          children: [
            OutlinedButton.icon(
              onPressed: enabled ? () => _captureScreenshot(context) : null,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('截图'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _captureScreenshot(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await session.captureScreenshot();
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('无法截图。')));
        return;
      }
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '保存截图',
        fileName: 'screenshot-${_timestamp()}.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      if (path == null) return;
      final outPath = path.toLowerCase().endsWith('.png') ? path : '$path.png';
      await File(outPath).writeAsBytes(bytes);
      messenger.showSnackBar(SnackBar(content: Text('截图已保存至 $outPath')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('截图失败：$error')));
    }
  }
}

class _ShortcutTile extends StatefulWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isActive,
    required this.onTap,
    this.accelerator,
    this.accentIndex = 0,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool isActive;

  /// `null` disables the tile — the feature needs a connected device.
  final VoidCallback? onTap;
  final String? accelerator;
  final int accentIndex;

  @override
  State<_ShortcutTile> createState() => _ShortcutTileState();
}

class _ShortcutTileState extends State<_ShortcutTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.isActive;
    final enabled = widget.onTap != null;
    final accent = schemeAccentAt(theme.colorScheme, widget.accentIndex);
    final borderColor = active
        ? accent.withValues(alpha: 0.45)
        : _hovered
        ? theme.colorScheme.outline
        : theme.colorScheme.outlineVariant;

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.14)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: enabled ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 17,
                      color: enabled
                          ? accent
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.sublabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.accelerator != null && enabled) ...[
                    const Gap(6),
                    KeyCap(label: widget.accelerator!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (enabled) return tile;
    return Tooltip(
      message: '请先重新连接设备后再使用「${widget.label}」',
      child: Opacity(opacity: 0.45, child: tile),
    );
  }
}
