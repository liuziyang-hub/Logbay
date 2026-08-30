import 'dart:convert';
import 'dart:io';

import 'package:eagly/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// GitHub-releases-backed update source consumed by `UpdatWidget`.
///
/// It reads the latest published release from the GitHub API and maps it onto
/// the stable-named artifacts produced by the release workflow
/// (`.github/workflows/release.yml`): `eagly-macos.dmg`,
/// `eagly-windows-setup.exe`, and `eagly-linux.deb`. Because those names are
/// identical on every release, the download URL only needs the tag.
class AppUpdateService {
  const AppUpdateService._();

  /// Auto-update is disabled for the Logdeck fork (no public release channel).
  static bool get isSupported => false;

  static const _latestReleaseApi =
      'https://api.github.com/repos/${AppConstants.repoOwner}/'
      '${AppConstants.repoName}/releases/latest';

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    // GitHub rejects API requests that omit a User-Agent.
    'User-Agent': '${AppConstants.repoName}-app',
  };

  /// Latest published release as a bare semantic version (leading `v` stripped),
  /// e.g. `1.1.6`. `updat` parses this with `pub_semver`, which rejects a `v`
  /// prefix. Returns `null` when the payload can't be understood so the widget
  /// stays quiet instead of surfacing an error.
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

  /// Download URL of this platform's installer for [version] — the bare semver
  /// handed back by [getLatestVersion]. Release tags follow the `v<semver>`
  /// convention (`release.yml` triggers on `v*`), so the tag is `v$version`.
  static Future<String> getBinaryUrl(String? version) async {
    return '${AppConstants.repoUrl}/releases/download/v$version/$_assetName';
  }

  /// The stable download location shared with `updat`.
  ///
  /// Keeping the location under our control lets us launch the installer only
  /// after this process has quit, rather than opening it while Logdeck still has
  /// its application bundle in use.
  static Future<File> getDownloadFileLocation(String? version) async {
    final downloadsDirectory = await getDownloadsDirectory();
    if (downloadsDirectory == null) {
      throw StateError('找不到“下载”文件夹。');
    }
    return File(
      '${downloadsDirectory.path}${Platform.pathSeparator}'
      '${AppConstants.appName}-$version.$_assetExtension',
    );
  }

  /// Schedules the downloaded installer to open after Logdeck has exited, then
  /// terminates this process. This prevents a macOS DMG from asking the user to
  /// replace an app bundle that is still running.
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
        'param([int]\$appProcessId, [string]\$installerPath) '
            '{ while (Get-Process -Id \$appProcessId '
            '-ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 100 }; '
            'Start-Process -FilePath \$installerPath }',
        '$pid',
        installer.path,
      ], mode: ProcessStartMode.detached);
    } else {
      final opener = Platform.isMacOS ? 'open' : 'xdg-open';
      await Process.start('/bin/sh', [
        '-c',
        'while kill -0 "\$1" 2>/dev/null; do sleep 0.1; done; '
            '"\$2" "\$3"',
        'eagly-updater',
        '$pid',
        opener,
        installer.path,
      ], mode: ProcessStartMode.detached);
    }

    exit(0);
  }

  static String get _assetName {
    if (Platform.isMacOS) return 'eagly-macos.dmg';
    if (Platform.isWindows) return 'eagly-windows-setup.exe';
    return 'eagly-linux.deb';
  }

  static String get _assetExtension => _assetName.split('.').last;

  static String _stripV(String tag) =>
      tag.startsWith('v') || tag.startsWith('V') ? tag.substring(1) : tag;
}
