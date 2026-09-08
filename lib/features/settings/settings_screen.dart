import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../constants/atmosphere_theme.dart';
import '../logs/data/models/log_level.dart';
import '../logs/presentation/models/log_view_mode.dart';
import '../../services/preferences_service.dart';
import '../../presentation/components/app_log_overlay.dart';
import '../../presentation/components/eagly_dialog.dart';

/// Presents the settings as a large desktop dialog.
Future<void> showSettingsDialog(BuildContext context) {
  return showEaglyDialog<void>(
    context: context,
    builder: (_) => const SettingsScreen(),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AtmosphereTheme _atmosphereTheme;
  late bool _wrapText;
  late bool _autoScroll;
  late bool _preferIosUnifiedLogging;
  late LogLevel _selectedLogLevel;
  late LogFilterViewMode _filterViewMode;
  late double _logFontSize;
  late double _zoomLevel;
  late bool _tipsEnabled;
  late final TextEditingController _logLinesController;

  @override
  void initState() {
    super.initState();
    _atmosphereTheme = PreferencesService.atmosphereTheme;
    _wrapText = PreferencesService.wrapText;
    _autoScroll = PreferencesService.autoScroll;
    _preferIosUnifiedLogging = PreferencesService.preferIosUnifiedLogging;
    _selectedLogLevel = PreferencesService.selectedLogLevel;
    _filterViewMode = PreferencesService.filterViewMode;
    _logFontSize = PreferencesService.logFontSize;
    _zoomLevel = PreferencesService.zoomLevel;
    _tipsEnabled = PreferencesService.tipsEnabled;
    _logLinesController = TextEditingController(
      text: PreferencesService.logLinesLimit.toString(),
    );
  }

  @override
  void dispose() {
    _logLinesController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveLogLinesLimit() async {
    final parsed = int.tryParse(_logLinesController.text.trim());
    if (parsed == null || parsed < 1000) {
      _showSnackBar('最大行数至少为 1000。');
      return;
    }

    setState(() {
      _logLinesController.text = parsed.toString();
    });
    PreferencesService.logLinesLimit = parsed;
    _showSnackBar('最大行数已更新。');
  }

  Future<void> _resetHiddenColumns() async {
    PreferencesService.hiddenColumns = {};
    if (!mounted) return;
    setState(() {});
    _showSnackBar('已重置隐藏列。');
  }

  Future<void> _resetColumnWidths() async {
    PreferencesService.columnWidths = {};
    if (!mounted) return;
    setState(() {});
    _showSnackBar('已重置列宽。');
  }

  int get _atmosphereIndex => AtmosphereTheme.values.indexOf(_atmosphereTheme);

  void _setAtmosphereByIndex(int index) {
    final next = AtmosphereTheme.values[index];
    setState(() => _atmosphereTheme = next);
    PreferencesService.atmosphereTheme = next;
  }

  @override
  Widget build(BuildContext context) {
    final hiddenColumns = PreferencesService.hiddenColumns;
    final theme = Theme.of(context);
    Widget sectionCard({
      required String title,
      required List<Widget> children,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: List<Widget>.generate(children.length * 2 - 1, (i) {
                  final index = i ~/ 2;
                  if (i.isEven) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: children[index],
                    );
                  }
                  return const Divider(height: 1);
                }),
              ),
            ),
          ),
        ],
      );
    }

    return EaglyDialog(
      title: '设置',
      icon: Icons.settings_outlined,
      width: 820,
      height: 640,
      contentPadding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          sectionCard(
            title: '外观',
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('主题', style: theme.textTheme.bodyLarge),
                      ),
                      ToggleButtons(
                        isSelected: List.generate(
                          AtmosphereTheme.values.length,
                          (i) => i == _atmosphereIndex,
                          growable: false,
                        ),
                        onPressed: (index) => _setAtmosphereByIndex(index),
                        borderRadius: BorderRadius.circular(6),
                        selectedBorderColor: theme.colorScheme.primary
                            .withValues(alpha: 0.5),
                        constraints: const BoxConstraints(
                          minWidth: 72,
                          minHeight: 36,
                        ),
                        children: [
                          for (final a in AtmosphereTheme.values) Text(a.label),
                        ],
                      ),
                    ],
                  ),
                  const Gap(8),
                  Text(
                    _atmosphereTheme.settingsHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _atmosphereTheme.description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '日志字号',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Aa',
                          style: TextStyle(fontSize: _logFontSize),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: Slider(
                          value: _logFontSize,
                          min: 8,
                          max: 24,
                          divisions: 16,
                          label: _logFontSize.toStringAsFixed(0),
                          onChanged: (v) {
                            setState(() => _logFontSize = v);
                            PreferencesService.logFontSize = v;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text('缩放比例', style: theme.textTheme.bodyLarge),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.zoom_out, size: 18),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () {
                          final next = (PreferencesService.zoomLevel - 0.05)
                              .clamp(0.7, 1.8);
                          setState(() => _zoomLevel = next);
                          PreferencesService.zoomLevel = next;
                        },
                      ),
                      SizedBox(
                        width: 200,
                        child: Slider(
                          value: _zoomLevel,
                          min: 0.7,
                          max: 1.8,
                          divisions: 22,
                          label: '${(_zoomLevel * 100).toStringAsFixed(0)}%',
                          onChanged: (v) {
                            setState(() => _zoomLevel = v);
                            PreferencesService.zoomLevel = v;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.zoom_in, size: 18),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () {
                          final next = (PreferencesService.zoomLevel + 0.05)
                              .clamp(0.7, 1.8);
                          setState(() => _zoomLevel = next);
                          PreferencesService.zoomLevel = next;
                        },
                      ),
                    ],
                  ),
                ],
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _tipsEnabled,
                title: const Text('功能提示'),
                subtitle: const Text('在应用顶栏轮播功能提示'),
                onChanged: (value) {
                  setState(() => _tipsEnabled = value);
                  PreferencesService.tipsEnabled = value;
                },
              ),
            ],
          ),
          const Gap(16),
          sectionCard(
            title: '新标签页默认值',
            children: [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _wrapText,
                title: const Text('自动换行'),
                subtitle: const Text('消息列自动换行'),
                onChanged: (value) {
                  setState(() => _wrapText = value);
                  PreferencesService.wrapText = value;
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _autoScroll,
                title: const Text('自动滚动'),
                subtitle: const Text('始终滚动到最新日志'),
                onChanged: (value) {
                  setState(() => _autoScroll = value);
                  PreferencesService.autoScroll = value;
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _preferIosUnifiedLogging,
                title: const Text('iOS 统一日志'),
                subtitle: const Text(
                  '优先用 pymobiledevice3（os_trace）；不可用时回退 idevicesyslog',
                ),
                onChanged: (value) {
                  setState(() => _preferIosUnifiedLogging = value);
                  PreferencesService.preferIosUnifiedLogging = value;
                },
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('默认日志级别'),
                trailing: SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<LogLevel>(
                    initialValue: _selectedLogLevel,
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(8),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: LogLevel.values
                        .map(
                          (level) => DropdownMenuItem<LogLevel>(
                            value: level,
                            child: Text(level.labelWithCode),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedLogLevel = value);
                      PreferencesService.selectedLogLevel = value;
                    },
                  ),
                ),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('默认筛选样式'),
                subtitle: Text(_filterViewMode.description),
                trailing: SegmentedButton<LogFilterViewMode>(
                  segments: LogFilterViewMode.values
                      .map(
                        (mode) => ButtonSegment<LogFilterViewMode>(
                          value: mode,
                          label: Text(mode.label),
                        ),
                      )
                      .toList(growable: false),
                  selected: {_filterViewMode},
                  onSelectionChanged: (selection) {
                    final mode = selection.first;
                    setState(() => _filterViewMode = mode);
                    PreferencesService.filterViewMode = mode;
                  },
                ),
              ),
              // (no explicit Divider here)
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('最大日志行数'),
                      Text('最少 1000', style: theme.textTheme.labelSmall),
                    ],
                  ),
                  const Gap(16),
                  Expanded(
                    child: TextField(
                      controller: _logLinesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '${PreferencesService.defaultLogLinesLimit}',
                      ),
                      onSubmitted: (_) => _saveLogLinesLimit(),
                    ),
                  ),
                  const Gap(12),
                  FilledButton(
                    onPressed: _saveLogLinesLimit,
                    child: const Text('应用'),
                  ),
                ],
              ),
            ],
          ),
          const Gap(16),
          sectionCard(
            title: '已保存的布局默认值',
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('默认隐藏列'),
                subtitle: Text(
                  '默认隐藏 ${hiddenColumns.length} 列',
                ),
                trailing: TextButton(
                  onPressed: hiddenColumns.isEmpty ? null : _resetHiddenColumns,
                  child: const Text('重置'),
                ),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('默认列宽'),
                subtitle: const Text('新标签页沿用已保存的列宽'),
                trailing: TextButton(
                  onPressed: _resetColumnWidths,
                  child: const Text('重置'),
                ),
              ),
            ],
          ),
          const Gap(16),
          sectionCard(
            title: '关于',
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('应用日志'),
                subtitle: const Text(
                  '打开内部调试日志查看器，并可复制完整应用日志。',
                ),
                onTap: () => showAppLogDialog(title: '应用日志', context),
                trailing: const AppLogTriggerButton(
                  title: '应用日志',
                  tooltip: '显示应用日志',
                  iconSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
