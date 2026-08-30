class AppConstants {
  /// Product name shown in window title, About, settings, menus, etc.
  static const appName = 'Logdeck';

  /// Landing-page hero brand only (keep as-is on the home lake screen).
  static const landingBrandName = '刘子阳';

  static const appDescription =
      '桌面日志与设备工作台：支持 Android / iOS 日志、镜像、文件与应用管理。';
  /// Local fork — no upstream release feed / auto-update.
  static const repoOwner = '';
  static const repoName = '';
  static const repoUrl = '';

  /// Identifier + label for the synthetic device-less "Imported Logs" workspace
  /// session that hosts log files opened without a connected device.
  static const importedWorkspaceId = '__imported-logs__';
  static const importedWorkspaceLabel = '导入的日志';

  /// Fastshot-style lake hero video used on the home landing screen.
  static const homeBackgroundVideoUrl =
      'https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260826_124724_bc041163-d651-425f-aea3-2acc1efc2c96.mp4';

  /// Motionsites forest source (bundled as boomerang loop for seamless cuts).
  static const homeForestBackgroundVideoUrl =
      'https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260511_131941_d136af49-e243-493a-be14-6ff3f24e09e6.mp4';

  static const newTabActionId = '__new-tab-action__';
  static const newTabLabel = '新建标签页';
  static const newTabTooltip = '创建新标签页';
  static const fontSizeSnackBarWidth = 120.0;
}
