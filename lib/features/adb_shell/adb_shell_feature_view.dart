import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:xterm/xterm.dart';

import '../../presentation/components/feature_view.dart';
import 'adb_shell_controller.dart';

/// ADB Shell pane using open-source [xterm] TerminalView.
class AdbShellFeatureView extends FeatureView {
  const AdbShellFeatureView({
    super.key,
    required this.controller,
    required VoidCallback onClose,
  }) : super(onClose: onClose);

  final AdbShellController controller;

  @override
  State<AdbShellFeatureView> createState() => _AdbShellFeatureViewState();
}

class _AdbShellFeatureViewState extends FeatureViewState<AdbShellFeatureView> {
  AdbShellController get controller => widget.controller;

  @override
  Listenable get listenable => controller;

  @override
  Widget buildContent(BuildContext context) {
    return FeaturePane(
      header: FeatureViewHeader(
        title: '终端',
        closeTooltip: '关闭终端面板',
        onClose: widget.onClose,
        actions: [
          IconButton(
            tooltip: '重连',
            onPressed: controller.canShell ? controller.restart : null,
            icon: controller.state == AdbShellState.connecting
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

  final AdbShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBanner =
        controller.error != null &&
        controller.state != AdbShellState.ready &&
        controller.state != AdbShellState.connecting;

    return Column(
      children: [
        if (showBanner)
          Material(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      controller.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  if (controller.canShell)
                    TextButton(
                      onPressed: controller.restart,
                      child: const Text('重连'),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFF0D1117),
            child: TerminalView(
              controller.terminal,
              autofocus: true,
              backgroundOpacity: 0,
              theme: TerminalThemes.defaultTheme,
              textStyle: TerminalStyle(
                fontSize: 13,
                fontFamily:
                    theme.textTheme.bodyMedium?.fontFamily ?? 'Consolas',
              ),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ),
      ],
    );
  }
}
