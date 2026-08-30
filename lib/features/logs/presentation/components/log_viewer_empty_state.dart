import 'package:flutter/material.dart';

import '../../../../presentation/components/centered_state_message.dart';
import '../../log_controller.dart';

/// Placeholder shown when the tab has no logs yet — waiting, ready, or an
/// empty imported file.
class LogViewerEmptyState extends StatelessWidget {
  const LogViewerEmptyState({
    super.key,
    required this.controller,
    required this.deviceDisplayName,
  });

  final LogController controller;
  final String deviceDisplayName;

  @override
  Widget build(BuildContext context) {
    return CenteredStateMessage(
      icon: controller.isImported
          ? Icons.description_outlined
          : controller.isRunning
          ? Icons.sync
          : Icons.play_circle_outline,
      title: controller.isImported
          ? '空日志文件'
          : controller.isRunning
          ? '正在等待来自 $deviceDisplayName 的日志'
          : '准备捕获日志',
      description: controller.isImported
          ? '导入的文件中没有可解析的日志条目。'
          : controller.isRunning
          ? '请保持此标签页打开，日志将从设备持续流入。'
          : '点击播放按钮开始为此设备捕获日志。',
    );
  }
}
