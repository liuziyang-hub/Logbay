import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../data/device.dart';
import 'discovered_wireless_target.dart';
import 'wireless_detail_row.dart';

/// Detail panel for the currently selected discovered device, with pairing
/// code entry and pair/connect actions.
class WirelessSelectedDevicePanel extends StatelessWidget {
  const WirelessSelectedDevicePanel({
    super.key,
    required this.target,
    required this.connectedDevice,
    required this.pairingCodeController,
    required this.pairingBusy,
    required this.connectingBusy,
    required this.actionsDisabled,
    required this.showConnectAction,
    required this.onPair,
    required this.onConnect,
    required this.onUseManualEntry,
  });

  final DiscoveredWirelessTarget target;

  /// The already-connected device matching [target]'s host, if any.
  final Device? connectedDevice;
  final TextEditingController pairingCodeController;
  final bool pairingBusy;
  final bool connectingBusy;
  final bool actionsDisabled;

  /// Shown when automatic connect failed and an explicit retry is offered.
  final bool showConnectAction;
  final VoidCallback? onPair;
  final VoidCallback? onConnect;
  final VoidCallback onUseManualEntry;

  bool get _alreadyConnected => connectedDevice != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('已选设备', style: theme.textTheme.titleMedium),
          const Gap(8),
          Text(target.host, style: theme.textTheme.bodyLarge),
          if (_alreadyConnected) ...[
            const Gap(6),
            Text(
              '已连接为 ${connectedDevice!.id}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Gap(12),
          if (target.pairingAddress != null)
            WirelessDetailRow(
              icon: Icons.password,
              label: '配对地址',
              value: target.pairingAddress!,
            ),
          if (target.connectAddresses.isNotEmpty)
            WirelessDetailRow(
              icon: Icons.link,
              label: target.connectAddresses.length == 1
                  ? '连接地址'
                  : '连接端口',
              value: target.connectAddresses.join(', '),
            ),
          if (target.canPair && !_alreadyConnected) ...[
            const Gap(14),
            TextField(
              controller: pairingCodeController,
              enabled: !actionsDisabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '配对码',
                hintText: '输入设备上显示的配对码',
                prefixIcon: Icon(Icons.password_outlined),
              ),
              onSubmitted: (_) {
                if (!actionsDisabled && onPair != null) {
                  onPair!();
                }
              },
            ),
          ],
          const Gap(16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (target.canPair && !_alreadyConnected)
                FilledButton.icon(
                  onPressed: actionsDisabled ? null : onPair,
                  icon: pairingBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(target.canConnect ? '配对并连接' : '配对'),
                ),
              if ((!target.canPair && target.canConnect) ||
                  showConnectAction ||
                  _alreadyConnected)
                FilledButton.tonalIcon(
                  onPressed: actionsDisabled || !target.canConnect
                      ? null
                      : onConnect,
                  icon: connectingBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    _alreadyConnected ? '使用已连接设备' : '连接',
                  ),
                ),
              TextButton.icon(
                onPressed: onUseManualEntry,
                icon: const Icon(Icons.tune),
                label: const Text('手动输入'),
              ),
            ],
          ),
          if (showConnectAction && !_alreadyConnected) ...[
            const Gap(12),
            Text(
              '自动连接未完成，您可以为此设备显式重试连接。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (!target.canConnect) ...[
            const Gap(12),
            Text(
              '尚未发现此设备的连接端点。如有需要，配对后可切换到手动输入。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
