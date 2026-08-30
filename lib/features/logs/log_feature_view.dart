import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'data/models/log_entry.dart';
import 'presentation/components/log_lines_limit_input.dart';
import 'presentation/models/log_view_mode.dart';
import '../../features/app_log/app_logger.dart';
import '../../session/device_session_controller.dart';
import '../../presentation/theme/app_theme.dart';
import '../../presentation/components/app_log_overlay.dart';
import '../../presentation/components/centered_state_message.dart';
import '../../presentation/components/feature_view.dart';
import '../../presentation/components/text_search_bar.dart';
import 'presentation/components/log_viewer.dart';
import '../../utils/log_entry_utils.dart';
import '../../utils/log_feedback.dart';
import '../../utils/utils.dart';
import 'presentation/components/classic_filter_bar.dart';
import 'presentation/components/inline_filter_bar.dart';
import 'presentation/components/scroll_to_end_button.dart';
import 'presentation/components/toolbar.dart';
import 'log_controller.dart';
import 'log_session_manager.dart';

/// The Logs feature pane for a single device: toolbar (with log-tab strip),
/// filter area, the log viewer (with empty/search/scroll overlays), and a
/// status bar. Supports multiple live and imported log tabs.
class LogFeatureView extends FeatureView {
  const LogFeatureView({
    super.key,
    required this.logManager,
    required this.session,
    required this.appMemoryBytesListenable,
    required VoidCallback onClose,
  }) : super(onClose: onClose);

  final LogSessionManager logManager;
  final DeviceSessionController session;
  final ValueListenable<int> appMemoryBytesListenable;

  @override
  State<LogFeatureView> createState() => _LogFeatureViewState();
}

class _LogFeatureViewState extends FeatureViewState<LogFeatureView> {
  LogSessionManager get logManager => widget.logManager;
  DeviceSessionController get session => widget.session;

  @override
  Listenable get listenable => logManager;

  Future<void> _handleExportLogs(LogController controller) async {
    final result = await controller.exportLogs();
    if (!mounted || result.cancelled) return;
    showSnackBar(formatExportLogsMessage(result));
  }

  Future<void> _handleImportLog() async {
    final result = await logManager.importLog();
    if (!mounted || result.cancelled) return;
    if (result.isSuccess) {
      showSnackBar(
        '已导入 ${result.fileName}（${result.logs!.length} 条）。',
      );
    } else if (result.error != null) {
      showSnackBar(result.error!);
    }
  }

  Future<void> _handleCopyAllLogs(LogController controller) async {
    final copiedCount = await controller.copyAllLogs();
    if (!mounted || copiedCount == 0) return;
    showSnackBar(
      copiedCount == 1 ? '已复制 1 条日志。' : '已复制 $copiedCount 条日志。',
    );
  }

  Future<void> _handleRowCopyAction(
    LogController controller,
    int? index,
    LogViewerCopyAction action,
  ) async {
    final format = switch (action) {
      LogViewerCopyAction.copyRow => LogCopyFormat.fullLine,
      LogViewerCopyAction.copyMessage => LogCopyFormat.messageOnly,
      LogViewerCopyAction.copyTimestampAndMessage =>
        LogCopyFormat.timestampAndMessage,
    };

    final copiedCount = await controller.copyRowsForContextMenu(
      clickedFilteredIndex: index,
      format: format,
    );
    if (!mounted || copiedCount == 0) return;

    final copiedLabel = switch (action) {
      LogViewerCopyAction.copyRow => '整行',
      LogViewerCopyAction.copyMessage => '消息',
      LogViewerCopyAction.copyTimestampAndMessage => '时间 + 消息',
    };
    showSnackBar(
      copiedCount == 1
          ? '已为 1 行复制$copiedLabel。'
          : '已为 $copiedCount 行复制$copiedLabel。',
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final controller = logManager.selectedTab;
    if (controller == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        session,
        widget.appMemoryBytesListenable,
      ]),
      builder: (context, _) => _buildContent(context, controller),
    );
  }

  Widget _buildContent(BuildContext context, LogController controller) {
    return Column(
      children: [
        _buildToolbar(context, controller),
        if (controller.liveLoggingInterrupted)
          _buildInterruptionBanner(context, controller),
        _buildFilterArea(context, controller),
        Expanded(child: _buildViewerArea(context, controller)),
        _buildStatusBar(context, controller),
      ],
    );
  }

  /// Full-width warning shown when live logging dropped and could not be
  /// resumed automatically. Offers manual recovery and a fresh tab.
  Widget _buildInterruptionBanner(
    BuildContext context,
    LogController controller,
  ) {
    final warning = context.eaglyTheme.warningColor;
    final connected = session.isConnected;
    final message =
        controller.liveLoggingInterruptionMessage ??
        '实时日志已停止。';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.14),
        border: Border(
          top: BorderSide(color: warning.withValues(alpha: 0.4)),
          bottom: BorderSide(color: warning.withValues(alpha: 0.4)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: warning),
          const Gap(10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: warning,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const Gap(8),
          TextButton.icon(
            onPressed: connected
                ? () => unawaited(controller.resumeLiveLogging())
                : null,
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('重新开始日志'),
            style: TextButton.styleFrom(foregroundColor: warning),
          ),
          const Gap(4),
          TextButton.icon(
            onPressed: logManager.addLiveTab,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('新建标签页'),
            style: TextButton.styleFrom(
              foregroundColor: context.eaglyTheme.inlineNoticeForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, LogController controller) {
    return Toolbar(
      controller: controller,
      logManager: logManager,
      onImportLog: _handleImportLog,
      onExport: !controller.hasLogs
          ? null
          : () async => _handleExportLogs(controller),
      onCopyAll: controller.hasAnyCachedLogs
          ? () async => _handleCopyAllLogs(controller)
          : null,
      onClose: widget.onClose,
    );
  }

  Widget _buildFilterArea(BuildContext context, LogController controller) {
    final isInline = controller.filterViewMode == LogFilterViewMode.inline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: isInline
                ? '当前为内联筛选模式，可切换至经典字段。'
                : '当前为经典筛选模式，可切换至内联筛选。',
            onPressed: () {
              controller.setFilterViewMode(
                isInline ? LogFilterViewMode.classic : LogFilterViewMode.inline,
              );
            },
            icon: Icon(
              isInline ? Icons.filter_alt_outlined : Icons.filter_list_rounded,
            ),
          ),
          const Gap(4),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isInline
                  ? InlineFilterBar(
                      key: const ValueKey('inline-filter-bar'),
                      controller: controller.inlineFilter,
                    )
                  : ClassicFilterBar(
                      key: const ValueKey('classic-filter-bar'),
                      controller: controller.classicFilter,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerArea(BuildContext context, LogController controller) {
    final filtered = controller.filteredLogs;
    final matches = controller.searchMatchIndices;
    return _buildLogViewerStack(context, controller, filtered, matches);
  }

  Widget _buildLogViewer(
    LogController controller,
    List<LogEntry> filtered,
    List<int> matches,
  ) {
    final safeIndex = matches.isEmpty
        ? null
        : controller.currentSearchMatchLogIndex(matches);

    return LogViewer(
      key: ValueKey('log-viewer-${controller.logViewerRevision}'),
      logs: filtered,
      scrollController: controller.scrollController,
      wrapText: controller.wrapText,
      onLogRowTap: controller.disableAutoScroll,
      onUserScroll: controller.disableAutoScroll,
      rowSelectionMode: controller.rowSelectionMode,
      selectedRowIndices: controller.selectedRowIndices,
      onRowSelectionStart: controller.beginRowSelectionGesture,
      onSelectedRowsChanged: controller.setSelectedRows,
      onRowSelectionChanged: controller.setRowSelected,
      onRowCopyAction: (index, action) =>
          _handleRowCopyAction(controller, index, action),
      onCopyAll: () => _handleCopyAllLogs(controller),
      onToggleRowSelectionMode: controller.toggleRowSelectionMode,
      onSelectedTextChanged: controller.setSelectedSearchText,
      search: controller.appliedInlineSearch,
      currentMatchLogIndex:
          controller.searchBarVisible && controller.appliedInlineSearch.isActive
          ? safeIndex
          : null,
      onClearRowSelection: controller.clearSelectedRows,
      hiddenColumns: controller.hiddenColumns,
      columnWidths: controller.columnWidths,
      onHiddenColumnsChanged: controller.setHiddenColumns,
      onColumnWidthsChanged: controller.setColumnWidths,
      isIos: controller.isIosLogContext,
    );
  }

  Widget _buildLogViewerStack(
    BuildContext context,
    LogController controller,
    List<LogEntry> filtered,
    List<int> matches,
  ) {
    return Stack(
      children: [
        _buildLogViewer(controller, filtered, matches),
        if (!controller.hasLogs)
          CenteredStateMessage(
            icon: controller.isImported
                ? Icons.description_outlined
                : controller.isRunning
                ? Icons.sync
                : Icons.play_circle_outline,
            title: controller.isImported
                ? '空日志文件'
                : controller.isRunning
                ? '正在等待来自 ${session.device.displayName} 的日志'
                : '准备捕获日志',
            description: controller.isImported
                ? '导入的文件中没有可解析的日志条目。'
                : controller.isRunning
                ? '请保持此标签页打开，日志将从设备持续流入。'
                : '点击播放按钮开始为此设备捕获日志。',
          ),
        if (controller.hasLogs && filtered.isEmpty)
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: context.eaglyTheme.inlineNoticeBackground,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '没有日志符合当前筛选条件，但设备仍在产生日志。',
                        style: TextStyle(
                          color: context.eaglyTheme.inlineNoticeForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: controller.clearFilter,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              context.eaglyTheme.inlineNoticeForeground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('清除筛选'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (controller.searchBarVisible)
          Positioned(
            top: 24,
            right: 12,
            child: TextSearchBar(
              search: controller.inlineSearch,
              hintText: '在日志中搜索…',
              hasError: controller.inlineSearchHasError,
              errorText: controller.inlineSearchErrorText,
              onSearchChanged: controller.updateInlineSearch,
              onSearchOptionsChanged: (search) =>
                  controller.updateInlineSearch(search, applyImmediately: true),
              onNext: controller.onSearchNext,
              onPrevious: controller.onSearchPrev,
              onClose: controller.closeSearchBar,
              totalMatches: matches.length,
              currentMatch: matches.isEmpty
                  ? 0
                  : controller.searchCurrentMatch + 1,
              width: 500,
            ),
          ),
        ListenableBuilder(
          listenable: controller.scrollController,
          builder: (context, child) {
            return ScrollToEndButton(
              visible:
                  controller.hasLogs &&
                  controller.scrollController.hasClients &&
                  controller.scrollController.offset <
                      (controller.scrollController.position.maxScrollExtent -
                          24),
              onPressed: controller.scrollToEnd,
            );
          },
        ),
      ],
    );
  }

  (String, Color) _liveStatusLabel(EaglyTheme theme, LogController controller) {
    if (controller.liveLoggingInterrupted) {
      return ('已中断', theme.statusStoppedColor);
    }
    if (controller.isRecovering) {
      return ('重连中…', theme.statusPausedColor);
    }
    if (controller.isPaused) return ('已暂停', theme.statusPausedColor);
    if (controller.isRunning) return ('实时', theme.statusLiveColor);
    return ('已停止', theme.statusStoppedColor);
  }

  Widget _buildStatusBar(BuildContext context, LogController controller) {
    final theme = context.eaglyTheme;

    return FeatureStatusBar(
      children: [
        Text('日志: ${controller.logCount}', style: theme.statusBarStyle),
        const Gap(16),
        Text(
          '已过滤: ${controller.filteredLogs.length}',
          style: theme.statusBarStyle,
        ),
        if (controller.rowSelectionMode || controller.hasSelectedRows) ...[
          const Gap(16),
          Text(
            '已选择: ${controller.selectedRowCount}',
            style: theme.statusBarStyle,
          ),
        ],
        const Spacer(),
        Text(
          '应用内存: ${formatBytes(widget.appMemoryBytesListenable.value)}',
          style: theme.statusBarStyle,
        ),
        const Gap(16),
        Text(
          '日志内存: ${formatBytes(controller.totalLogsMemoryBytes)}',
          style: theme.statusBarStyle,
        ),
        const Gap(8),
        _buildLogLinesEditor(context, controller),
        const Gap(8),
        SizedBox(
          height: 18,
          child: VerticalDivider(
            width: 2,
            thickness: 2,
            radius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        if (controller.isImported)
          Text(
            '已导入',
            style: TextStyle(
              fontSize: 12,
              color: theme.statusBarStyle.color,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          Builder(
            builder: (context) {
              final (label, color) = _liveStatusLabel(theme, controller);
              return Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ListenableBuilder(
          listenable: AppLogger.global.entriesListenable,
          builder: (context, _) {
            final hasWorkspaceErrors = AppLogger.global.hasEntries(
              sessionTag: controller.appLogSessionTag,
              errorsOnly: true,
            );
            if (!hasWorkspaceErrors) {
              return const SizedBox.shrink();
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Gap(8),
                AppLogTriggerButton(
                  sessionTag: controller.appLogSessionTag,
                  title: '应用日志 • ${session.device.displayName}',
                  tooltip: '显示此设备的应用错误',
                  iconSize: 16,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogLinesEditor(BuildContext context, LogController controller) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: controller.editingLogLinesLimit
          ? null
          : BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: !controller.editingLogLinesLimit
          ? InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: () => controller.setEditingLogLinesLimit(true),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '最大行数: ${controller.logLinesLimit}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            )
          : IntrinsicWidth(
              child: LogLinesLimitInput(
                setEditingLogLinesLimit: controller.setEditingLogLinesLimit,
                submitLogLinesLimit: controller.submitLogLinesLimit,
                logLinesLimit: controller.logLinesLimit,
                isEditing: controller.editingLogLinesLimit,
              ),
            ),
    );
  }
}
