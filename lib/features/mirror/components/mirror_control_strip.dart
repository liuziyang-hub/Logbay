import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../flutter_scrcpy/flutter_scrcpy.dart';
import '../mirror_controller.dart';

/// Vertical strip on the pane's right edge: session actions (screenshot,
/// record, rotate, quality) at the top, then device hardware/navigation keys.
class MirrorControlStrip extends StatelessWidget {
  const MirrorControlStrip({super.key, required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = controller.isScreenMirrorRunning;
    final controlEnabled =
        running && controller.screenMirrorSession?.control != null;
    final recording = controller.isRecording;

    Widget keyButton(IconData icon, String tooltip, ScrcpyKey key) {
      return IconButton(
        tooltip: tooltip,
        iconSize: 16,
        onPressed: controlEnabled ? () => controller.handleKey(key) : null,
        icon: Icon(icon),
      );
    }

    Widget actionButton(
      IconData icon,
      String tooltip,
      Future<void> Function() onTap, {
      bool enabled = true,
      Color? color,
    }) {
      return IconButton(
        tooltip: tooltip,
        iconSize: 16,
        color: color,
        onPressed: enabled ? () => onTap() : null,
        icon: Icon(icon),
      );
    }

    Widget divider() => Divider(
      height: 1,
      thickness: 1,
      indent: 10,
      endIndent: 10,
      color: theme.colorScheme.outlineVariant,
    );

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(8),
            actionButton(
              Icons.photo_camera_outlined,
              '截图',
              () => _captureScreenshot(context),
              enabled: controller.canStart || running,
            ),
            if (controller.isIosMirror)
              actionButton(
                controller.iosAudioMuted
                    ? Icons.volume_off_outlined
                    : Icons.volume_up_outlined,
                controller.iosAudioMuted ? '取消静音' : '静音',
                () => controller.setIosAudioMuted(!controller.iosAudioMuted),
                enabled: controller.canStart || running,
              ),
            if (!controller.isIosMirror)
              actionButton(
                recording ? Icons.stop_circle : Icons.videocam_outlined,
                recording ? '停止录制' : '录制屏幕',
                () => recording
                    ? _stopRecording(context)
                    : _startRecording(context),
                enabled: controller.canStart || running || recording,
                color: recording ? theme.colorScheme.error : null,
              ),
            if (!controller.isIosMirror)
              actionButton(
                Icons.screen_rotation_outlined,
                '旋转设备',
                () => _rotate(context),
                enabled: controller.canStart || running,
              ),
            if (!controller.isIosMirror) ...[
              const Gap(8),
              divider(),
              const Gap(8),
              actionButton(
                Icons.content_paste,
                '粘贴剪贴板到设备',
                () => _paste(context),
                enabled: controlEnabled,
              ),
              IconButton(
                tooltip: controller.clipboardSyncEnabled
                    ? '设备剪贴板同步：开'
                    : '设备剪贴板同步：关',
                iconSize: 16,
                color: controller.clipboardSyncEnabled
                    ? theme.colorScheme.primary
                    : null,
                onPressed: () => controller.setClipboardSyncEnabled(
                  !controller.clipboardSyncEnabled,
                ),
                icon: Icon(
                  controller.clipboardSyncEnabled
                      ? Icons.sync
                      : Icons.sync_disabled,
                ),
              ),
              const Gap(8),
              divider(),
              const Gap(8),
              keyButton(Icons.arrow_back, '返回', ScrcpyKey.back),
              keyButton(Icons.circle_outlined, '主屏幕', ScrcpyKey.home),
              keyButton(Icons.crop_square, '概览', ScrcpyKey.appSwitch),
              const Gap(8),
              divider(),
              const Gap(8),
              keyButton(Icons.volume_up, '音量加', ScrcpyKey.volumeUp),
              keyButton(Icons.volume_down, '音量减', ScrcpyKey.volumeDown),
              keyButton(Icons.power_settings_new, '电源', ScrcpyKey.power),
            ],
            const Gap(8),
          ],
        ),
      ),
    );
  }

  static String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  Future<void> _captureScreenshot(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await controller.captureScreenshot();
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
      if (path == null) return; // user cancelled
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
      await controller.startRecording();
      if (controller.isRecording) {
        messenger.showSnackBar(const SnackBar(content: Text('录制中…再次点击停止。')));
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('录制失败：$error')));
    }
  }

  Future<void> _stopRecording(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '保存屏幕录制',
      fileName: 'recording-${_timestamp()}.mp4',
      type: FileType.custom,
      allowedExtensions: ['mp4'],
    );
    try {
      if (path == null) {
        await controller.cancelRecording();
        messenger.showSnackBar(const SnackBar(content: Text('录制已丢弃。')));
        return;
      }
      final outPath = path.toLowerCase().endsWith('.mp4') ? path : '$path.mp4';
      messenger.showSnackBar(const SnackBar(content: Text('正在保存录制…')));
      await controller.stopRecording(outPath);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('录制已保存至 $outPath')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('录制失败：$error')));
    }
  }

  Future<void> _paste(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.pasteFromClipboard();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('粘贴失败：$error')));
    }
  }

  Future<void> _rotate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.rotate();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('旋转失败：$error')));
    }
  }
}
