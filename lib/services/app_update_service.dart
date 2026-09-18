import 'dart:convert';
import 'dart:io';

import 'package:eagly/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// GitHub-releases-backed update source consumed by `UpdatWidget`.
///
/// Reads the latest published release from the GitHub API and maps it onto
/// Logbay installer artifacts (`Logbay-{version}-windows-setup.exe`, etc.).
class AppUpdateService {
  const AppUpdateService._();

  /// Enabled for the public Logbay GitHub release channel.
  static bool get isSupported => true;

  static const _latestReleaseApi =
      'https://api.github.com/repos/${AppConstants.repoOwner}/'
      '${AppConstants.repoName}/releases/latest';

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    // GitHub rejects API requests that omit a User-Agent.
    'User-Agent': '${AppConstants.repoName}-app',
  };

  /// Latest published release as a bare semantic version (leading `v` stripped).
  static Future<String?> getLatestVersion() async {
    if (!isSupported) return null;
    final res = await http.get(Uri.parse(_latestReleaseApi), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('查询 GitHub 最新版本失败（${res.statusCode}）。');
    }
    final tag = (jsonDecode(res.body) as Map<String, dynamic>)['tag_name'];
    if (tag is! String || tag.isEmpty) return null;
    return _stripV(tag);
  }

  /// Release notes body of the latest release, shown in the update dialog.
  static Future<String?> getChangelog(
    String latestVersion,
    String appVersion,
  ) async {
    final res = await http.get(Uri.parse(_latestReleaseApi), headers: _headers);
    if (res.statusCode != 200) return null;
    final body = (jsonDecode(res.body) as Map<String, dynamic>)['body'];
    return body is String && body.trim().isNotEmpty ? body : null;
  }

  /// Download URL of this platform's installer for [version].
  static Future<String> getBinaryUrl(String? version) async {
    return '${AppConstants.repoUrl}/releases/download/v$version/'
        '${assetFileName(version)}';
  }

  /// Stable installer file name for [version] on the current platform.
  static String assetFileName(String? version) {
    final v = version ?? '0.0.0';
    if (Platform.isMacOS) return 'Logbay-$v-macos.dmg';
    if (Platform.isWindows) return 'Logbay-$v-windows-setup.exe';
    return 'Logbay-$v-linux.deb';
  }

  /// The stable download location shared with `updat`.
  static Future<File> getDownloadFileLocation(String? version) async {
    final downloadsDirectory = await getDownloadsDirectory();
    if (downloadsDirectory == null) {
      throw StateError('找不到“下载”文件夹。');
    }
    return File(
      '${downloadsDirectory.path}${Platform.pathSeparator}'
      '${assetFileName(version)}',
    );
  }

  /// Quits Logbay and launches the installer.
  ///
  /// On Windows the Inno Setup package is started with silent overwrite flags
  /// so the user does not need to click through the wizard.
  static Future<void> quitAndOpenInstaller(String version) async {
    final installer = await getDownloadFileLocation(version);
    if (!await installer.exists()) {
      throw StateError('找不到已下载的安装程序。');
    }

    if (Platform.isWindows) {
      await Process.start('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-Command',
        windowsInstallerCommand,
        '$pid',
        installer.path,
      ], mode: ProcessStartMode.detached);
    } else {
      final opener = Platform.isMacOS ? 'open' : 'xdg-open';
      await Process.start('/bin/sh', [
        '-c',
        'while kill -0 "\$1" 2>/dev/null; do sleep 0.1; done; '
            '"\$2" "\$3"',
        'logbay-updater',
        '$pid',
        opener,
        installer.path,
      ], mode: ProcessStartMode.detached);
    }

    exit(0);
  }

  /// PowerShell command used by the detached Windows updater.
  ///
  /// The parameter declaration must end before the wait/install statements.
  /// Wrapping those statements in `{ ... }` would only create a script-block
  /// value and never execute the installer.
  static String get windowsInstallerCommand =>
      'param([int]\$appProcessId, [string]\$installerPath); '
      'while (Get-Process -Id \$appProcessId '
      '-ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }; '
      'Start-Process -FilePath \$installerPath -ArgumentList '
      "'/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"
      "'/CLOSEAPPLICATIONS','/FORCECLOSEAPPLICATIONS',"
      "'/LANG=chinesesimplified'";

  static String _stripV(String tag) =>
      tag.startsWith('v') || tag.startsWith('V') ? tag.substring(1) : tag;
}
