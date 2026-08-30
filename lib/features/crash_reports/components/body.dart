import 'package:flutter/material.dart';

import '../../../presentation/components/centered_state_message.dart';
import '../crash_report_controller.dart';
import 'crash_report_detail.dart';
import 'crash_report_list.dart';

class Body extends StatelessWidget {
  const Body({super.key, required this.controller});

  final CrashReportController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.selectedReport != null) {
      return CrashReportDetail(controller: controller);
    }

    switch (controller.loadState) {
      case CrashReportLoadState.idle:
      case CrashReportLoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case CrashReportLoadState.unsupported:
        return CenteredStateMessage(
          icon: Icons.phonelink_off_rounded,
          title: '不支持的设备',
          description:
              controller.error ??
              '崩溃报告读取功能仅支持 iOS 设备。',
        );
      case CrashReportLoadState.error:
        return CenteredStateMessage(
          icon: Icons.error_outline_rounded,
          title: '无法读取崩溃报告',
          description: controller.error ?? '出现错误。',
          footer: FilledButton.icon(
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        );
      case CrashReportLoadState.ready:
        if (controller.reports.isEmpty) {
          return const CenteredStateMessage(
            icon: Icons.check_circle_outline_rounded,
            title: '无崩溃报告',
            description: '此设备没有可显示的崩溃报告。',
          );
        }
        return CrashReportList(controller: controller);
    }
  }
}
