import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/device_file_entry.dart';
import '../file_manager_controller.dart';
import 'file_context_menu.dart';
import 'file_entry_visuals.dart';

/// Detailed table view: a sortable header (Name / Size / Modified /
/// Permissions) above one row per entry. Single tap selects, double tap opens
/// a directory, right-click shows the context menu.
class FileListView extends StatelessWidget {
  const FileListView({
    super.key,
    required this.controller,
    required this.actions,
  });

  final FileManagerController controller;
  final FileManagerActions actions;

  static const double _nameMinWidth = 160;
  static const double _nameMaxWidth = 360;
  static const double _sizeWidth = 84;
  static const double _modifiedWidth = 132;
  static const double _permsWidth = 104;
  static const double _hPad = 24;

  static double get _metaWidth => _sizeWidth + _modifiedWidth + _permsWidth;

  @override
  Widget build(BuildContext context) {
    final entries = controller.entries;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final nameWidth = available.isFinite
            ? (available - _metaWidth - _hPad).clamp(_nameMinWidth, _nameMaxWidth)
            : _nameMaxWidth;
        final tableWidth = math.max(
          available,
          nameWidth + _metaWidth + _hPad,
        );

        final table = SizedBox(
          width: tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, nameWidth),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemExtent: 40,
                  itemBuilder: (context, index) => _FileRow(
                    controller: controller,
                    entry: entries[index],
                    actions: actions,
                    nameWidth: nameWidth,
                  ),
                ),
              ),
            ],
          ),
        );

        if (tableWidth <= available) return table;
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table,
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, double nameWidth) {
    final theme = Theme.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: nameWidth,
            child: _headerCell(context, '名称', FileSortField.name),
          ),
          SizedBox(
            width: _sizeWidth,
            child: _headerCell(
              context,
              '大小',
              FileSortField.size,
              alignEnd: true,
            ),
          ),
          SizedBox(
            width: _modifiedWidth,
            child: _headerCell(context, '修改时间', FileSortField.modified),
          ),
          SizedBox(
            width: _permsWidth,
            child: _headerCell(context, '权限', FileSortField.type),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    BuildContext context,
    String label,
    FileSortField field, {
    bool alignEnd = false,
  }) {
    final theme = Theme.of(context);
    final active = controller.sortField == field;
    return InkWell(
      onTap: () => controller.setSort(field),
      child: Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (active)
            Icon(
              controller.sortAscending
                  ? Icons.arrow_drop_up
                  : Icons.arrow_drop_down,
              size: 18,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.controller,
    required this.entry,
    required this.actions,
    required this.nameWidth,
  });

  final FileManagerController controller;
  final DeviceFileEntry entry;
  final FileManagerActions actions;
  final double nameWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = controller.selectedEntry?.path == entry.path;

    return InkWell(
      onTap: () => controller.selectEntry(entry),
      onDoubleTap: entry.isNavigable ? () => controller.open(entry) : null,
      onSecondaryTapUp: (details) {
        controller.selectEntry(entry);
        showFileEntryMenu(
          context,
          details.globalPosition,
          controller: controller,
          entry: entry,
          actions: actions,
        );
      },
      child: Container(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: nameWidth,
              child: Row(
                children: [
                  FileEntryIcon(entry: entry, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: entry.linkTarget == null
                          ? entry.name
                          : '${entry.name} → ${entry.linkTarget}',
                      waitDuration: const Duration(milliseconds: 600),
                      child: Text(
                        entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: FileListView._sizeWidth,
              child: Text(
                FileEntryVisuals.formatSize(entry),
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(
              width: FileListView._modifiedWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  FileEntryVisuals.formatModified(entry.modified),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: FileListView._permsWidth,
              child: Text(
                entry.permissions ?? entry.typeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
