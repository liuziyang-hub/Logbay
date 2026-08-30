import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../presentation/components/feature_view.dart';
import 'data/device_details.dart';
import 'device_info_controller.dart';

/// Device details pane — Card + info rows matching the device home style.
class DeviceInfoFeatureView extends FeatureView {
  const DeviceInfoFeatureView({
    super.key,
    required this.controller,
    required VoidCallback onClose,
  }) : super(onClose: onClose);

  final DeviceInfoController controller;

  @override
  State<DeviceInfoFeatureView> createState() => _DeviceInfoFeatureViewState();
}

class _DeviceInfoFeatureViewState
    extends FeatureViewState<DeviceInfoFeatureView> {
  DeviceInfoController get controller => widget.controller;

  @override
  Listenable get listenable => controller;

  @override
  Widget buildContent(BuildContext context) {
    return FeaturePane(
      header: FeatureViewHeader(
        title: '详情',
        closeTooltip: '关闭详情面板',
        onClose: widget.onClose,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: controller.isLoading ? null : controller.refresh,
            icon: controller.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _Body(controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final DeviceInfoController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (controller.loadState == DeviceInfoLoadState.loading &&
        controller.snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.loadState == DeviceInfoLoadState.error &&
        controller.snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              const Gap(12),
              Text(
                controller.error ?? '无法加载设备详情',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(16),
              FilledButton.tonalIcon(
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = controller.snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (controller.error != null) ...[
          Text(
            controller.error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const Gap(12),
        ],
        for (final section in snapshot.sections)
          if (section.rows.isNotEmpty) ...[
            _SectionCard(section: section),
            const Gap(12),
          ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final DeviceDetailsSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(12),
            const Divider(height: 1),
            const Gap(8),
            for (final row in section.rows) _InfoRow(row: row),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});

  final DeviceDetailsRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              row.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Gap(8),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: row.value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已复制「${row.label}」'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Text(
                  row.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
