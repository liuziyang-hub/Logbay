import 'package:flutter/material.dart';

import 'settings_section_card.dart';

/// 'Appearance' section: theme toggle, log font size, and the feature-tips
/// switch.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({
    super.key,
    required this.themeIndex,
    required this.onThemeChanged,
    required this.logFontSize,
    required this.onLogFontSizeChanged,
    required this.tipsEnabled,
    required this.onTipsEnabledChanged,
  });

  final int themeIndex;
  final ValueChanged<int> onThemeChanged;
  final double logFontSize;
  final ValueChanged<double> onLogFontSizeChanged;
  final bool tipsEnabled;
  final ValueChanged<bool> onTipsEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSectionCard(
      title: '外观',
      children: [
        Row(
          children: [
            Expanded(
              child: Text('主题', style: theme.textTheme.bodyLarge),
            ),
            ToggleButtons(
              isSelected: List.generate(
                3,
                (i) => i == themeIndex,
                growable: false,
              ),
              onPressed: (index) => onThemeChanged(index),
              borderRadius: BorderRadius.circular(6),
              selectedBorderColor: theme.colorScheme.primary.withValues(
                alpha: 0.5,
              ),
              constraints: const BoxConstraints(
                minWidth: 84,
                minHeight: 36,
              ),
              children: const [Text('自动'), Text('浅色'), Text('深色')],
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
                    style: TextStyle(fontSize: logFontSize),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Slider(
                    value: logFontSize,
                    min: 8,
                    max: 24,
                    divisions: 16,
                    label: logFontSize.toStringAsFixed(0),
                    onChanged: onLogFontSizeChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: tipsEnabled,
          title: const Text('功能提示'),
          subtitle: const Text('在应用顶栏轮播功能提示'),
          onChanged: onTipsEnabledChanged,
        ),
      ],
    );
  }
}
