import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/atmosphere_theme.dart';
import '../../presentation/theme/theme_typography.dart';
import '../../services/preferences_service.dart';

class GetStartedActionCard extends StatelessWidget {
  const GetStartedActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.secondaryActions = const [],
    this.children = const [],
    this.glass = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final List<Widget> secondaryActions;
  final List<Widget> children;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(18);

    Widget buildCard(AtmosphereTheme atmosphere) {
      final fill = glass ? atmosphere.glassFill : theme.colorScheme.surface;
      final border = glass ? atmosphere.glassBorder : null;
      final accent = atmosphere.primaryAccent;
      final titleStyle = glass
          ? ThemeTypography.cardTitle(atmosphere)
          : theme.textTheme.titleMedium;
      final subtitleStyle = glass
          ? ThemeTypography.cardBody(atmosphere)
          : theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            );

      final card = Material(
        color: glass ? Colors.transparent : theme.colorScheme.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: glass
                ? BoxDecoration(
                    borderRadius: radius,
                    color: fill,
                    border: Border.all(color: border!, width: 1.2),
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0x59000000),
                        blurRadius: 36,
                        offset: Offset(0, 16),
                      ),
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  )
                : null,
            child: Column(
              spacing: 12,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(icon, color: accent, size: 24),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: titleStyle),
                          const SizedBox(height: 4),
                          Text(subtitle, style: subtitleStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                if (secondaryActions.isNotEmpty)
                  Wrap(spacing: 8, runSpacing: 8, children: secondaryActions),
                if (children.isNotEmpty) Column(spacing: 8, children: children),
              ],
            ),
          ),
        ),
      );

      if (!glass) return card;

      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: card,
        ),
      );
    }

    if (!glass) return buildCard(AtmosphereTheme.lake);

    return ValueListenableBuilder<AtmosphereTheme>(
      valueListenable: PreferencesService.atmosphereThemeListenable,
      builder: (context, atmosphere, _) => buildCard(atmosphere),
    );
  }
}
