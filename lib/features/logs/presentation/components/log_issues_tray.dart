import 'package:flutter/material.dart';

import '../../services/log_signal_detector.dart';

/// Compact tray listing crash / ANR / native-fault hits with one-tap jump.
class LogIssuesTray extends StatelessWidget {
  const LogIssuesTray({
    super.key,
    required this.issues,
    required this.onJump,
    required this.onClear,
    this.expanded = true,
    this.onToggleExpanded,
  });

  final List<LogIssue> issues;
  final ValueChanged<LogIssue> onJump;
  final VoidCallback onClear;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Color kindColor(LogIssueKind kind) => switch (kind) {
      LogIssueKind.crash => scheme.error,
      LogIssueKind.anr => Colors.orange.shade700,
      LogIssueKind.native => Colors.deepPurple,
    };

    return Material(
      color: scheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '异常（${issues.length}）',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onClear,
                    child: const Text('清除'),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: issues.length,
                itemBuilder: (context, index) {
                  final issue = issues[issues.length - 1 - index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: kindColor(issue.kind).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        issue.kindLabel,
                        style: TextStyle(
                          color: kindColor(issue.kind),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      issue.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: issue.timestamp.isEmpty
                        ? null
                        : Text(
                            issue.timestamp,
                            style: theme.textTheme.bodySmall,
                          ),
                    onTap: () => onJump(issue),
                  );
                },
              ),
            ),
          Divider(height: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}
