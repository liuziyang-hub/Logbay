import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'step_list.dart';

class AndroidUnauthorizedGuidance extends StatelessWidget {
  const AndroidUnauthorizedGuidance({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.usb, size: 32, color: theme.colorScheme.primary),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      '允许 USB 调试',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Text(
                '您的 Android 设备正在请求允许来自此计算机的 USB 调试。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(20),
              StepList(
                steps: const [
                  '查看 Android 设备屏幕',
                  '在「允许 USB 调试？」对话框中点击「允许」',
                  '可选勾选「始终允许来自此计算机」',
                  '若对话框已消失，请断开并重新连接 USB 线缆',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
