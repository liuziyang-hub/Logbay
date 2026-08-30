import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../models/log_view_mode.dart';
import '../../log_controller.dart';
import 'classic_filter_bar.dart';
import 'inline_filter_bar.dart';

/// The filter area row: inline/classic mode toggle plus the active filter
/// bar, cross-faded on mode switch.
class LogFilterArea extends StatelessWidget {
  const LogFilterArea({super.key, required this.controller});

  final LogController controller;

  @override
  Widget build(BuildContext context) {
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
}
