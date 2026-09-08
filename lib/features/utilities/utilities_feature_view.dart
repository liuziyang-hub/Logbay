import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../presentation/components/centered_state_message.dart';
import '../../presentation/components/feature_view.dart';
import '../../presentation/theme/app_theme.dart';
import 'components/utility_output_panel.dart';
import 'components/utility_tile.dart';
import 'data/utility_command.dart';
import 'utilities_controller.dart';
import 'utility_runner.dart';

/// Utilities pane: the device-command catalog as a searchable, grouped list.
///
/// The view is entirely driven by the catalog — it renders whatever
/// [UtilitiesController.groups] hands it — so it never mentions a specific
/// command or platform. Clicking a tile collects parameters (if any), confirms
/// (if the command asks for it), runs, and shows the result in the output
/// panel or, for side-effect-only commands, a snackbar.
class UtilitiesFeatureView extends FeatureView {
  const UtilitiesFeatureView({
    super.key,
    required this.controller,
    required super.onClose,
  });

  final UtilitiesController controller;

  @override
  State<UtilitiesFeatureView> createState() => _UtilitiesFeatureViewState();
}

class _UtilitiesFeatureViewState
    extends FeatureViewState<UtilitiesFeatureView> {
  final TextEditingController _searchController = TextEditingController();

  UtilitiesController get controller => widget.controller;

  @override
  Listenable get listenable => controller;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleTap(UtilityCommand command) => runUtilityCommand(
    context,
    controller: controller,
    command: command,
    showSnackBar: showSnackBar,
  );

  @override
  Widget buildContent(BuildContext context) {
    final result = controller.lastResult;

    return FeaturePane(
      header: FeatureViewHeader(
        title: '工具',
        onClose: widget.onClose,
        closeTooltip: '关闭工具面板',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            controller: _searchController,
            onChanged: controller.setSearchText,
          ),
          if (!controller.isConnected) const _DisconnectedNotice(),
          Expanded(child: _buildBody(context)),
          if (result != null)
            UtilityOutputPanel(result: result, onClose: controller.clearResult),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!controller.hasAnyUtility) {
      return const CenteredStateMessage(
        icon: Icons.handyman_outlined,
        title: '此处没有可用工具',
        description: '当前会话未绑定真实设备。',
      );
    }

    final groups = controller.groups;
    if (groups.isEmpty) {
      return const CenteredStateMessage(
        icon: Icons.search_off,
        title: '没有匹配的工具',
        description: '试试其他关键词。',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupHeader(title: group.title, icon: group.icon),
            for (final command in group.commands)
              UtilityTile(
                key: ValueKey(command.id),
                command: command,
                isRunning: controller.runningCommandId == command.id,
                enabled: controller.isConnected && !controller.isRunning,
                onTap: () => _handleTap(command),
              ),
          ],
        );
      },
    );
  }
}

/// Inline strip explaining why every tile is dimmed.
class _DisconnectedNotice extends StatelessWidget {
  const _DisconnectedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eaglyTheme = context.eaglyTheme;

    return Container(
      width: double.infinity,
      color: eaglyTheme.inlineNoticeBackground,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.link_off,
            size: 14,
            color: eaglyTheme.inlineNoticeForeground,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              '设备已断开 — 重新连接后即可运行这些命令。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: eaglyTheme.inlineNoticeForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 12, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const Gap(8),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SizedBox(
        height: 34,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(
            isDense: true,
            hintText: '搜索工具…',
            prefixIcon: const Icon(Icons.search, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
    );
  }
}
