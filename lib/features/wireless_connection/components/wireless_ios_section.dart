import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../data/device.dart';
import '../../../session/device_session_manager.dart';

/// Chinese step-by-step panel for iOS wireless (Windows-first).
class WirelessIosSection extends StatelessWidget {
  const WirelessIosSection({
    super.key,
    required this.manager,
    required this.busy,
    required this.onEnableWifiConnections,
    required this.onRefresh,
  });

  final DeviceSessionManager manager;
  final bool busy;
  final Future<void> Function(String? udid) onEnableWifiConnections;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = manager.selected?.device;
    final selectedIos = selected is IosDevice ? selected : null;
    final iosDevices = manager.repository.devices
        .whereType<IosDevice>()
        .where((d) => d.isConnected)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'iOS 无线连接',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(8),
        Text(
          '建议流程：USB 配对一次 → 开启无线调试 → 同一局域网 → 拔线。'
          'Windows 需安装微软商店「Apple 设备」或 iTunes。'
          '主机还需安装 pymobiledevice3（Python）。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(14),
        _StepList(
          steps: const [
            '用数据线连接 iPhone/iPad，在设备上点「信任」，完成配对。',
            '点击下方「开启无线调试」（需已安装 pymobiledevice3）。',
            '确保手机与电脑连在同一 Wi‑Fi。',
            '拔掉 USB 线，点击「刷新设备」；列表中应出现带「无线」标记的 iOS 设备。',
            '之后可查看日志。屏幕镜像建议 iOS 17.4 及以上并开启开发者模式；'
                '更早系统可能需要额外网络隧道配置。',
          ],
        ),
        const Gap(16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => onEnableWifiConnections(selectedIos?.id),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(
                selectedIos == null
                    ? '开启无线调试'
                    : '为「${selectedIos.displayName}」开启',
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新设备'),
            ),
          ],
        ),
        if (selected != null && selected is! IosDevice) ...[
          const Gap(10),
          Text(
            '当前选中的是 Android 设备。开启无线调试将作用于已连接的默认 iOS 设备'
            '（或请先选中一台 iOS）。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Gap(18),
        Text('已发现的 iOS 设备', style: theme.textTheme.labelLarge),
        const Gap(8),
        if (iosDevices.isEmpty)
          Text(
            '暂无已连接的 iOS 设备。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...iosDevices.map((device) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                leading: Icon(
                  device.isWireless ? Icons.wifi : Icons.usb,
                  color: theme.colorScheme.primary,
                ),
                title: Text(device.displayName),
                subtitle: Text(device.isWireless ? '无线' : '有线 USB'),
                trailing: Text(
                  device.id.length > 12
                      ? '${device.id.substring(0, 12)}…'
                      : device.id,
                  style: theme.textTheme.bodySmall,
                ),
                onTap: () => manager.select(device.id),
              ),
            );
          }),
      ],
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(steps[i], style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
