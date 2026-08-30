import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../constants/atmosphere_theme.dart';
import '../../../presentation/theme/theme_typography.dart';
import '../../../services/preferences_service.dart';
import 'recent_file_tile.dart';

/// The last opened log files, bound to [PreferencesService.recentLogFilesListenable]
/// so it rebuilds as files are opened or removed. Empty until the first import.
class RecentFilesList extends StatelessWidget {
  const RecentFilesList({super.key, required this.onOpenRecent});

  final ValueChanged<String> onOpenRecent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AtmosphereTheme>(
      valueListenable: PreferencesService.atmosphereThemeListenable,
      builder: (context, atmosphere, _) {
        return ValueListenableBuilder<List<String>>(
          valueListenable: PreferencesService.recentLogFilesListenable,
          builder: (context, recentFiles, _) {
            if (recentFiles.isEmpty) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '最近打开的文件将显示在此处。',
                  style: ThemeTypography.cardBody(atmosphere),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '最近文件',
                    style: ThemeTypography.badge(atmosphere).copyWith(
                      color: atmosphere.cardTitleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Gap(8),
                for (final path in recentFiles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RecentFileTile(
                      path: path,
                      onOpen: () => onOpenRecent(path),
                      onRemove: () =>
                          PreferencesService.removeRecentLogFile(path),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
