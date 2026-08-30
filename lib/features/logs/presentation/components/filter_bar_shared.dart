import 'package:flutter/material.dart';

import '../../data/models/log_level.dart';
import '../../../../presentation/theme/log_level_presentation.dart';

// Consistent height for all filter bar input fields.
const double kFilterFieldHeight = 40.0;

/// Standard [InputDecoration] used across all filter bar fields.
InputDecoration filterInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  IconData? prefixIcon,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  InputBorder inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color, width: 1.2),
  );
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(fontSize: 12),
    hintText: hintText,
    hintStyle: const TextStyle(fontSize: 12),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: inputBorder(colorScheme.outlineVariant),
    enabledBorder: inputBorder(colorScheme.outlineVariant),
    focusedBorder: inputBorder(colorScheme.primary),
    filled: true,
    fillColor: colorScheme.surface,
    prefixIconConstraints: prefixIcon != null
        ? const BoxConstraints(minHeight: 28, minWidth: 28)
        : null,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 14) : null,
  );
}

/// Compact level picker that avoids [DropdownButtonFormField] overlay glitches.
class LogLevelDropdown extends StatelessWidget {
  const LogLevelDropdown({
    super.key,
    required this.selectedLogLevel,
    required this.onLogLevelChanged,
    required this.isIos,
    this.width = 148,
    this.height = kFilterFieldHeight,
  });

  final LogLevel selectedLogLevel;
  final ValueChanged<LogLevel?> onLogLevelChanged;
  final bool isIos;

  /// Fixed width. When `null` the widget expands to fill available space.
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levels = isIos ? LogLevel.iosValues : LogLevel.androidValues;
    final selected = selectedLogLevel.normalizeSelectionForPlatform(
      isIos: isIos,
    );

    Widget field = MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
        elevation: const WidgetStatePropertyAll(6),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
      ),
      builder: (context, controller, _) {
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: InputDecorator(
              isFocused: controller.isOpen,
              decoration: filterInputDecoration(
                context,
                labelText: '优先级',
              ).copyWith(
                contentPadding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
                suffixIcon: Icon(
                  controller.isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
              child: LogLevelLabel(
                level: selected,
                isIos: isIos,
                includeValueInLabel: true,
                compact: true,
                textStyle: theme.textTheme.bodySmall,
              ),
            ),
          ),
        );
      },
      menuChildren: [
        for (final level in levels)
          MenuItemButton(
            onPressed: () => onLogLevelChanged(level),
            trailingIcon: level == selected
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  )
                : null,
            child: SizedBox(
              width: 180,
              child: LogLevelLabel(
                level: level,
                isIos: isIos,
                includeValueInLabel: true,
                compact: true,
                textStyle: theme.textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );

    field = SizedBox(height: height, child: field);
    if (width != null) {
      field = SizedBox(width: width, child: field);
    }
    return field;
  }
}

/// Returns `true` when [query] matches [candidate] at a word/segment boundary.
bool filterBoundaryMatch(String candidate, String query) {
  if (candidate.startsWith(query)) return true;
  for (final separator in const ['.', '/', '_', '-', ':']) {
    if (candidate.contains('$separator$query')) return true;
  }
  return false;
}

/// Deduplicates a list of string values (case-insensitive, trims whitespace).
/// Blank entries are dropped.
List<String> deduplicateFilterValues(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    if (!seen.add(trimmed.toLowerCase())) continue;
    result.add(trimmed);
  }
  return result;
}
