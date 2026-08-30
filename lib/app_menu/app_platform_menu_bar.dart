import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'intents.dart';
import '../features/logs/data/models/log_level.dart';
import 'app_menu_scope.dart';
import 'shortcuts.dart';
import 'app_menu_state.dart';

/// The macOS menu bar, rebuilt from the reactive [AppMenuState] in
/// [AppMenuScope]. It is purely declarative: every item dispatches an [Intent]
/// (handled by the app-level `Actions`) and derives its enabled state and label
/// from the snapshot. It holds no controllers or callbacks of its own.
///
/// Because it only depends on the snapshot, it rebuilds when — and only when —
/// the snapshot changes, so an open native menu is not torn down by unrelated
/// app activity.
class AppPlatformMenuBar extends StatelessWidget {
  const AppPlatformMenuBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppMenuScope.stateOf(context);
    return PlatformMenuBar(menus: _menus(state), child: child);
  }

  /// An item that is enabled only when [enabled] is true (disabled items get a
  /// null intent, which is how [PlatformMenuItem] renders them greyed out).
  PlatformMenuItem _item(
    String label,
    Intent intent, {
    bool enabled = true,
    MenuSerializableShortcut? shortcut,
  }) {
    return PlatformMenuItem(
      label: label,
      shortcut: shortcut,
      onSelectedIntent: enabled ? intent : null,
    );
  }

  List<PlatformMenuItem> _menus(AppMenuState s) {
    return [
      // ── File ──────────────────────────────────────────────────────────────
      PlatformMenu(
        label: '文件',
        menus: [
          PlatformMenuItemGroup(
            members: [
              _item(
                '在选定设备上安装应用…',
                const InstallAppIntent(),
                enabled: s.canInstallApp,
                shortcut: kInstallAppShortcut,
              ),
              _item(
                '导出日志…',
                const ExportLogsIntent(),
                enabled: s.canExport,
                shortcut: kExportLogsShortcut,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              _item(
                '设置…',
                const OpenSettingsIntent(),
                shortcut: kSettingsShortcut,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              _item(
                '退出 ${AppConstants.appName}',
                const QuitAppIntent(),
                shortcut: kQuitShortcut,
              ),
            ],
          ),
        ],
      ),

      // ── Logs ──────────────────────────────────────────────────────────────
      PlatformMenu(
        label: '日志',
        menus: [
          PlatformMenuItemGroup(
            members: [
              _item(
                '重新加载设备',
                const ReloadDevicesIntent(),
                shortcut: kReloadDevicesShortcut,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              _item(
                s.isRunning ? '重新启动捕获' : '开始捕获',
                const StartLogcatIntent(),
                enabled: s.canCapture,
                shortcut: kStartLogcatShortcut,
              ),
              _item(
                s.isPaused ? '恢复捕获' : '暂停捕获',
                const TogglePauseResumeIntent(),
                enabled: s.canPauseResume,
                shortcut: kPauseResumeShortcut,
              ),
              _item(
                '清除日志',
                const ClearLogsIntent(),
                enabled: s.canClear,
                shortcut: kClearLogsShortcut,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              _item(
                '滚动到底部',
                const ScrollToEndIntent(),
                enabled: s.canInteractWithLog,
                shortcut: kScrollToEndShortcut,
              ),
            ],
          ),
        ],
      ),

      // ── Search ────────────────────────────────────────────────────────────
      PlatformMenu(
        label: '搜索',
        menus: [
          PlatformMenuItemGroup(
            members: [
              _item(
                '查找…',
                const ActivateSearchIntent(),
                enabled: s.canInteractWithLog,
                shortcut: kFindShortcut,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              _item(
                '上一处匹配',
                const PreviousMatchIntent(),
                enabled: s.canInteractWithLog,
                shortcut: kPreviousMatchShortcut,
              ),
              _item(
                '下一处匹配',
                const NextMatchIntent(),
                enabled: s.canInteractWithLog,
                shortcut: kNextMatchShortcut,
              ),
            ],
          ),
        ],
      ),

      // ── Filter ────────────────────────────────────────────────────────────
      PlatformMenu(
        label: '筛选',
        menus: [
          PlatformMenuItemGroup(
            members: [
              _item(
                '聚焦筛选输入框',
                const FocusFilterIntent(),
                enabled: s.canInteractWithLog,
                shortcut: kFocusFilterShortcut,
              ),
              _item(
                '清除筛选',
                const ClearFilterIntent(),
                enabled: s.canInteractWithLog,
              ),
            ],
          ),
          PlatformMenuItemGroup(members: _logLevelItems(s)),
        ],
      ),

      // ── View ──────────────────────────────────────────────────────────────
      PlatformMenu(
        label: '视图',
        menus: [
          PlatformMenuItemGroup(
            members: [
              _item(
                _checked(s.wrapText, '自动换行'),
                const ToggleWrapTextIntent(),
                enabled: s.canInteractWithLog,
              ),
              _item(
                _checked(s.autoScroll, '自动滚动'),
                const ToggleAutoScrollIntent(),
                enabled: s.canInteractWithLog,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
               _item(
                 '放大',
                 const IncreaseFontIntent(),
                 shortcut: kIncreaseFontShortcut,
               ),
               _item(
                 '缩小',
                 const DecreaseFontIntent(),
                 shortcut: kDecreaseFontShortcut,
               ),
            ],
          ),
        ],
      ),

      // ── Help ──────────────────────────────────────────────────────────────
      PlatformMenu(
        label: '帮助',
        menus: [
          PlatformMenuItemGroup(
            members: [
              _item('关于 ${AppConstants.appName}', const ShowAboutIntent()),
            ],
          ),
        ],
      ),
    ];
  }

  /// macOS menu items have no native checkmark in Flutter's API, so a selected
  /// toggle is shown with a leading check glyph.
  String _checked(bool on, String label) => on ? '✓ $label' : label;

  List<PlatformMenuItem> _logLevelItems(AppMenuState s) {
    final levels = s.isIos ? LogLevel.iosValues : LogLevel.androidValues;
    return [
      for (final level in levels)
        _item(
          _checked(
            level == s.selectedLogLevel,
            level.labelWithDisplayCode(isIos: s.isIos),
          ),
          SetLogLevelIntent(level),
          enabled: s.canInteractWithLog,
        ),
    ];
  }
}
