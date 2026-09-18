import 'package:flutter/material.dart';

import '../../session/device_session_controller.dart';
import 'components/rail_button.dart';
import 'components/rail_footer.dart';

/// Far-left vertical rail listing the features available for a device. The
/// rail is split into two sections: Home (pinned at the top, its own
/// mutually-exclusive view) and the other destinations below a divider, each
/// of which toggles on/off independently and stacks side by side. Selecting
/// Home swaps the visible view but never closes the other panes underneath —
/// selecting any of them again restores the previous layout. Install opens a
/// file picker. Settings is pinned to the bottom.
class FeatureRail extends StatelessWidget {
  const FeatureRail({
    super.key,
    required this.session,
    required this.onInstall,
    required this.onOpenSettings,
  });

  final DeviceSessionController session;
  final VoidCallback onInstall;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return Container(
          width: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              right: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          padding: EdgeInsets.all(4),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    RailButton(
                      icon: Icons.home_outlined,
                      label: '主页',
                      isActive: session.isHomeOpen,
                      tooltip: session.isHomeOpen ? '隐藏设备主页' : '显示设备主页',
                      onTap: session.toggleHome,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            spacing: 4,
                            children: [
                              RailButton(
                                icon: Icons.article_outlined,
                                label: '日志',
                                isActive: session.isLogsOpen,
                                tooltip: session.isLogsOpen ? '隐藏日志' : '查看设备日志',
                                onTap: session.toggleLogs,
                              ),
                              RailButton(
                                icon: Icons.terminal_outlined,
                                label: '终端',
                                isActive: session.isTerminalOpen,
                                enabled:
                                    session.canUseTerminal ||
                                    session.isTerminalOpen,
                                tooltip: session.canUseTerminal
                                    ? (session.isTerminalOpen
                                          ? '隐藏终端'
                                          : '打开终端（设备命令行）')
                                    : '导入日志工作区不支持终端',
                                onTap:
                                    session.canUseTerminal ||
                                        session.isTerminalOpen
                                    ? session.toggleTerminal
                                    : null,
                              ),
                              RailButton(
                                icon: Icons.mobile_screen_share,
                                label: '镜像',
                                isActive: session.isMirrorOpen,
                                enabled:
                                    session.canMirror || session.isMirrorOpen,
                                tooltip: session.canMirror
                                    ? (session.isMirrorOpen
                                          ? '隐藏屏幕镜像'
                                          : '打开屏幕镜像')
                                    : '请先连接设备后再使用屏幕镜像',
                                onTap: session.canMirror || session.isMirrorOpen
                                    ? session.toggleMirror
                                    : null,
                              ),
                              RailButton(
                                icon: Icons.monitor_heart_outlined,
                                label: '性能',
                                isActive: session.isPerformanceOpen,
                                enabled:
                                    session.isConnected ||
                                    session.isPerformanceOpen,
                                tooltip: session.isConnected
                                    ? (session.isPerformanceOpen
                                          ? '隐藏性能分析'
                                          : '分析应用性能')
                                    : '请先连接设备后再分析性能',
                                onTap:
                                    session.isConnected ||
                                        session.isPerformanceOpen
                                    ? session.togglePerformance
                                    : null,
                              ),
                              if (session.canReadCrashReports)
                                RailButton(
                                  icon: Icons.bug_report_outlined,
                                  label: '崩溃',
                                  isActive: session.isCrashReportsOpen,
                                  tooltip: session.isCrashReportsOpen
                                      ? '隐藏崩溃报告'
                                      : '查看崩溃报告',
                                  onTap: session.toggleCrashReports,
                                ),
                              RailButton(
                                icon: Icons.folder_outlined,
                                label: '文件',
                                isActive: session.isFilesOpen,
                                enabled:
                                    session.canManageFiles ||
                                    session.isFilesOpen,
                                tooltip:
                                    session.canManageFiles ||
                                        session.isFilesOpen
                                    ? (session.isFilesOpen ? '隐藏文件' : '浏览设备文件')
                                    : '请先连接设备后再浏览文件',
                                onTap:
                                    session.canManageFiles ||
                                        session.isFilesOpen
                                    ? session.toggleFiles
                                    : null,
                              ),
                              RailButton(
                                icon: Icons.apps_outlined,
                                label: '应用',
                                isActive: session.isAppsOpen,
                                enabled:
                                    session.canManageApps || session.isAppsOpen,
                                tooltip:
                                    session.canManageApps || session.isAppsOpen
                                    ? (session.isAppsOpen ? '隐藏应用' : '管理已安装应用')
                                    : '请先连接设备后再管理应用',
                                onTap:
                                    session.canManageApps || session.isAppsOpen
                                    ? session.toggleApps
                                    : null,
                              ),
                              if (session.canRunUtilities)
                                RailButton(
                                  icon: Icons.handyman_outlined,
                                  label: '工具',
                                  isActive: session.isUtilitiesOpen,
                                  tooltip: session.isUtilitiesOpen
                                      ? '隐藏工具'
                                      : '运行设备命令',
                                  onTap: session.toggleUtilities,
                                ),
                              RailButton(
                                icon: session.isInstallingApp
                                    ? Icons.hourglass_top_rounded
                                    : Icons.system_update_outlined,
                                label: '安装',
                                isActive: session.isInstallingApp,
                                enabled: session.isConnected,
                                tooltip: session.isInstallingApp
                                    ? (session.installingAppName == null
                                          ? '正在安装…'
                                          : '正在安装 ${session.installingAppName}…')
                                    : session.isConnected
                                    ? '在此设备上安装应用'
                                    : '请先连接设备后再安装应用',
                                onTap:
                                    session.isConnected &&
                                        !session.isInstallingApp
                                    ? onInstall
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              RailButton(
                icon: Icons.settings_rounded,
                label: '设置',
                isActive: false,
                tooltip: '设置',
                onTap: onOpenSettings,
              ),
              const RailFooter(),
            ],
          ),
        );
      },
    );
  }
}
