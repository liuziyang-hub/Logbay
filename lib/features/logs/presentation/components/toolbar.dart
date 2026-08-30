import 'package:flutter/material.dart';

import '../../../../presentation/components/animation_utils.dart';
import '../../log_controller.dart';
import '../../log_session_manager.dart';
import 'log_tab_strip.dart';
import 'toolbar_divider.dart';
import 'toolbar_icon_button.dart';

/// Toolbar for the Logs feature: log-tab strip, capture controls
/// (start/pause/clear), copy/row-selection, search, view toggles, export,
/// import, and a pane-level close button.
class Toolbar extends StatelessWidget {
  const Toolbar({
    super.key,
    required this.controller,
    required this.logManager,
    required this.onImportLog,
    required this.onExport,
    required this.onCopyAll,
    required this.onClose,
  });

  final LogController controller;
  final LogSessionManager logManager;
  final VoidCallback? onImportLog;
  final VoidCallback? onExport;
  final VoidCallback? onCopyAll;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    const gap = SizedBox(width: 4);
    const div = ToolbarDivider();
    Widget gapTimes(int n) => SizedBox(width: 4.0 * n);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          // ── Live-only capture controls (hidden for imported logs) ──────
          AnimatedSection(
            visible: !c.isImported,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ToolbarIconButton(
                  icon: c.isRunning
                      ? Icons.restart_alt_rounded
                      : Icons.play_arrow,
                  tooltip: !c.isConnected
                      ? '设备已断开连接'
                      : c.isRunning
                      ? '重新开始'
                      : '开始',
                  onPressed: c.isConnected ? c.startLogcat : null,
                ),
                gap,
                ToolbarIconButton(
                  icon: c.isPaused ? Icons.play_arrow : Icons.pause,
                  tooltip: c.isRunning
                      ? (c.isPaused ? '恢复' : '暂停')
                      : '未运行',
                  isActive: c.isPaused,
                  onPressed: c.isRunning ? c.togglePauseResume : null,
                ),
                gap,
                ToolbarIconButton(
                  icon: Icons.delete_outline,
                  tooltip: c.logs.isNotEmpty
                      ? '清除日志'
                      : '没有可清除的日志',
                  onPressed: c.logs.isNotEmpty ? c.clearLogs : null,
                ),
                gap,
                div,
                gapTimes(3),
              ],
            ),
          ),

          // ── Log tab strip ─────────────────────────────────────────────
          LogTabStrip(logManager: logManager, onImportLog: onImportLog),
          const Spacer(),
          gap,
          div,
          gap,

          // ── Copy / row-select ─────────────────────────────────────────
          ToolbarIconButton(
            icon: Icons.copy_all_outlined,
            tooltip: c.hasAnyCachedLogs ? '复制全部日志' : '没有可复制的日志',
            onPressed: c.hasAnyCachedLogs ? onCopyAll : null,
          ),
          gap,
          ToolbarIconButton(
            icon: c.rowSelectionMode
                ? Icons.checklist_rounded
                : Icons.checklist_outlined,
            tooltip: c.rowSelectionMode
                ? '关闭行选择模式'
                : '开启行选择模式',
            isActive: c.rowSelectionMode,
            onPressed: c.filteredLogs.isNotEmpty
                ? c.toggleRowSelectionMode
                : null,
          ),

          // ── Deselect (appears only when rows are selected) ────────────
          AnimatedSection(
            visible: c.hasSelectedRows,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                gap,
                ToolbarIconButton(
                  icon: Icons.deselect_outlined,
                  tooltip: '清除所选行',
                  onPressed: c.clearSelectedRows,
                ),
              ],
            ),
          ),

          gap,
          div,
          gap,

          // ── Search / wrap / auto-scroll ───────────────────────────────
          ToolbarIconButton(
            icon: Icons.search,
            tooltip: c.searchBarVisible
                ? '关闭搜索'
                : '在日志中搜索（Ctrl+F / Cmd+F）',
            isActive: c.searchBarVisible,
            onPressed: () {
              if (c.searchBarVisible) {
                c.closeSearchBar();
              } else {
                c.activateSearchFromSelection();
              }
            },
          ),
          gap,
          ToolbarIconButton(
            icon: c.wrapText ? Icons.wrap_text : Icons.notes,
            tooltip: c.wrapText ? '关闭自动换行' : '开启自动换行',
            isActive: c.wrapText,
            onPressed: c.toggleWrapText,
          ),
          gap,
          ToolbarIconButton(
            icon: c.autoScroll ? Icons.vertical_align_bottom : Icons.swipe_down,
            tooltip: c.autoScroll ? '自动滚动：开' : '自动滚动：关',
            isActive: c.autoScroll,
            onPressed: c.toggleAutoScroll,
          ),
          gap,
          div,
          gap,

          // ── Export / import ───────────────────────────────────────────
          ToolbarIconButton(
            icon: Icons.upload_outlined,
            tooltip: '导出日志',
            onPressed: onExport,
          ),
          gap,
          ToolbarIconButton(
            icon: Icons.download_outlined,
            tooltip: '导入日志文件',
            onPressed: onImportLog,
          ),
          gap,
          div,
          gap,
          ToolbarIconButton(
            icon: Icons.close,
            tooltip: '关闭日志面板',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

