import 'package:eagly/constants/app_constants.dart';
import 'package:eagly/services/app_update_service.dart';
import 'package:eagly/services/eagly_info_service.dart';
import 'package:flutter/material.dart';
import 'package:updat/updat.dart';

import 'components/update_pill.dart';

/// Header pill: tap → download → silent overwrite install on Windows.
class AppUpdateChip extends StatefulWidget {
  const AppUpdateChip({super.key});

  @override
  State<AppUpdateChip> createState() => _AppUpdateChipState();
}

class _AppUpdateChipState extends State<AppUpdateChip> {
  String? _pendingInstallVersion;
  bool _installStarted = false;

  @override
  Widget build(BuildContext context) {
    if (!AppUpdateService.isSupported) return const SizedBox.shrink();

    return UpdatWidget(
      appName: AppConstants.appName,
      currentVersion: EaglyInfoService.versionName,
      getLatestVersion: AppUpdateService.getLatestVersion,
      getBinaryUrl: AppUpdateService.getBinaryUrl,
      getDownloadFileLocation: AppUpdateService.getDownloadFileLocation,
      getChangelog: AppUpdateService.getChangelog,
      updateChipBuilder: _buildChip,
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String? latestVersion,
    required String appVersion,
    required UpdatStatus status,
    required void Function() checkForUpdate,
    required void Function() openDialog,
    required void Function() startUpdate,
    required Future<void> Function() launchInstaller,
    required void Function() dismissUpdate,
  }) {
    switch (status) {
      case UpdatStatus.available:
      case UpdatStatus.availableWithChangelog:
        return UpdatePill(
          icon: Icons.system_update_alt_rounded,
          label: '更新',
          tooltip: latestVersion == null
              ? '有新版本可用 — 点击下载并静默安装'
              : '有可用更新 v$latestVersion — 点击下载并静默覆盖安装',
          onTap: () {
            _pendingInstallVersion = latestVersion;
            _installStarted = false;
            startUpdate();
          },
        );
      case UpdatStatus.downloading:
        return const UpdatePill(
          busy: true,
          label: '下载中…',
          tooltip: '正在下载更新…',
        );
      case UpdatStatus.readyToInstall:
        final version = latestVersion ?? _pendingInstallVersion;
        if (!_installStarted && version != null) {
          _installStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _silentInstall(context, version);
          });
        }
        return const UpdatePill(
          busy: true,
          label: '安装中…',
          tooltip: '即将退出并静默覆盖安装',
        );
      case UpdatStatus.error:
      case UpdatStatus.checking:
      case UpdatStatus.upToDate:
      case UpdatStatus.idle:
      case UpdatStatus.dismissed:
        return const SizedBox.shrink();
    }
  }

  Future<void> _silentInstall(
    BuildContext context,
    String latestVersion,
  ) async {
    try {
      await AppUpdateService.quitAndOpenInstaller(latestVersion);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法启动安装程序：$error')),
      );
    }
  }
}
