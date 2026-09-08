import 'package:flutter/material.dart';

import '../terminal_session_manager.dart';
import 'terminal_tab_chip.dart';

/// Horizontally scrolling strip of terminal tabs with a trailing "+" button.
class TerminalTabStrip extends StatefulWidget {
  const TerminalTabStrip({super.key, required this.manager});

  final TerminalSessionManager manager;

  @override
  State<TerminalTabStrip> createState() => _TerminalTabStripState();
}

class _TerminalTabStripState extends State<TerminalTabStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;

    return ListenableBuilder(
      listenable: Listenable.merge([manager, ...manager.tabs]),
      builder: (context, _) => SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < manager.tabs.length; i++)
              TerminalTabChip(
                label: manager.labelFor(i),
                selected: i == manager.selectedIndex,
                isRunning: manager.tabs[i].isRunning,
                isPinned: manager.tabs[i].isPinnedElsewhere,
                tooltip: manager.tabs[i].isRunning
                    ? '正在运行命令…'
                    : '命令发往 ${manager.tabs[i].targetDevice.displayName}',
                onTap: () => manager.selectTab(i),
                onClose: manager.canClose(i) ? () => manager.closeTab(i) : null,
              ),
            Tooltip(
              message: '新建终端标签',
              child: IconButton(
                onPressed: manager.addTab,
                mouseCursor: SystemMouseCursors.click,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                icon: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
