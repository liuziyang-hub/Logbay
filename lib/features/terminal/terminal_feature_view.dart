import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../presentation/components/feature_view.dart';
import '../../services/preferences_service.dart';
import 'components/terminal_input_bar.dart';
import 'components/terminal_output_view.dart';
import 'components/terminal_tab_strip.dart';
import 'terminal_controller.dart';
import 'terminal_session_manager.dart';

/// The Terminal pane: a tab strip, the selected tab's scrollback, and the
/// prompt.
class TerminalFeatureView extends FeatureView {
  const TerminalFeatureView({
    super.key,
    required this.manager,
    required VoidCallback onClose,
  }) : super(onClose: onClose);

  final TerminalSessionManager manager;

  @override
  State<TerminalFeatureView> createState() => _TerminalFeatureViewState();
}

class _TerminalFeatureViewState extends FeatureViewState<TerminalFeatureView> {
  TerminalSessionManager get manager => widget.manager;

  @override
  Listenable get listenable => manager;

  Future<void> _copyScrollback(TerminalController controller) async {
    final text = controller.scrollbackText;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    showSnackBar('已复制终端输出。');
  }

  @override
  Widget buildContent(BuildContext context) {
    final controller = manager.selectedTab;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildContent(context, controller),
    );
  }

  Widget _buildContent(BuildContext context, TerminalController controller) {
    final theme = Theme.of(context);

    return FeaturePane(
      header: FeatureViewHeader(
        title: '终端',
        onClose: widget.onClose,
        closeTooltip: '关闭终端面板',
        actions: [
          IconButton(
            tooltip: '复制输出',
            onPressed: controller.lines.isEmpty
                ? null
                : () => _copyScrollback(controller),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: '清空回显（Ctrl+L）',
            onPressed: controller.lines.isEmpty ? null : controller.clear,
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: TerminalTabStrip(manager: manager),
          ),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: PreferencesService.logFontSizeListenable,
              builder: (context, fontSize, _) => Column(
                children: [
                  Expanded(
                    child: TerminalOutputView(
                      key: ObjectKey(controller),
                      lines: controller.lines,
                      fontSize: fontSize,
                    ),
                  ),
                  TerminalInputBar(
                    key: ObjectKey(controller),
                    controller: controller,
                    fontSize: fontSize,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
