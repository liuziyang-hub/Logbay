import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../utils/tools_path.dart';

@immutable
class Pymobiledevice3Version implements Comparable<Pymobiledevice3Version> {
  const Pymobiledevice3Version(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static Pymobiledevice3Version? parse(String raw) {
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(raw);
    if (match == null) return null;
    return Pymobiledevice3Version(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(Pymobiledevice3Version other) {
    final majorResult = major.compareTo(other.major);
    if (majorResult != 0) return majorResult;
    final minorResult = minor.compareTo(other.minor);
    if (minorResult != 0) return minorResult;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

/// Resolves how to invoke `pymobiledevice3` on this host.
class Pymobiledevice3Command {
  const Pymobiledevice3Command(this.executable, this.prefixArgs);

  final String executable;
  final List<String> prefixArgs;

  /// Full argv after the executable (includes `-m pymobiledevice3` when needed).
  List<String> args(List<String> command) => [...prefixArgs, ...command];
}

/// Resolves the bundled pymobiledevice3 runtime first, with host installations
/// retained as a development fallback.
class Pymobiledevice3Launcher {
  Pymobiledevice3Launcher._();

  static const managedVersion = '11.15.4';

  static Future<Pymobiledevice3Command?>? _resolved;

  static Future<Pymobiledevice3Command?> resolve() {
    return _resolved ??= _probe();
  }

  static void resetCache() {
    _resolved = null;
  }

  static Future<bool> isAvailable() async => (await resolve()) != null;

  /// Returns the installed CLI version, or `null` when an older build does
  /// not expose a parseable `version` command.
  static Future<Pymobiledevice3Version?> installedVersion({
    Pymobiledevice3Command? command,
  }) async {
    final resolved = command ?? await resolve();
    if (resolved == null) return null;
    try {
      final result = await Process.run(
        resolved.executable,
        resolved.args(['version']),
        runInShell: Platform.isWindows,
      ).timeout(const Duration(seconds: 10));
      return Pymobiledevice3Version.parse('${result.stdout}\n${result.stderr}');
    } catch (_) {
      return null;
    }
  }

  static Future<Pymobiledevice3Command?> _probe() async {
    for (final candidate in _candidates()) {
      try {
        final result = await Process.run(candidate.executable, [
          ...candidate.prefixArgs,
          '--help',
        ], runInShell: Platform.isWindows).timeout(const Duration(seconds: 90));
        final out = '${result.stdout}\n${result.stderr}'.toLowerCase();
        if (result.exitCode == 0 ||
            out.contains('syslog') ||
            out.contains('usage') ||
            out.contains('pymobiledevice3')) {
          if (Platform.isWindows && candidate.prefixArgs.contains('tool')) {
            final managed = _managedWindowsCommand();
            if (managed != null) return managed;
          }
          return candidate;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static List<Pymobiledevice3Command> _candidates() {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      final localAppData = Platform.environment['LOCALAPPDATA'];
      return [
        if (_managedWindowsCommand(appData: appData) case final managed?)
          managed,
        if (_bundledWindowsCommand() case final bundled?) bundled,
        if (localAppData != null &&
            File('$localAppData\\Programs\\uv\\uv.exe').existsSync())
          Pymobiledevice3Command('$localAppData\\Programs\\uv\\uv.exe', const [
            'tool',
            'run',
            '--from',
            'pymobiledevice3==$managedVersion',
            'pymobiledevice3',
          ]),
        const Pymobiledevice3Command('uvx', [
          '--from',
          'pymobiledevice3==$managedVersion',
          'pymobiledevice3',
        ]),
        const Pymobiledevice3Command('pymobiledevice3', []),
        const Pymobiledevice3Command('py', ['-3', '-m', 'pymobiledevice3']),
        const Pymobiledevice3Command('python', ['-m', 'pymobiledevice3']),
        const Pymobiledevice3Command('python3', ['-m', 'pymobiledevice3']),
      ];
    }
    return const [
      Pymobiledevice3Command('pymobiledevice3', []),
      Pymobiledevice3Command('python3', ['-m', 'pymobiledevice3']),
      Pymobiledevice3Command('python', ['-m', 'pymobiledevice3']),
    ];
  }

  static Pymobiledevice3Command? _bundledWindowsCommand() {
    final directory = resolveBundledToolsDirectory();
    if (directory == null) return null;
    return bundledWindowsCommandIn(directory);
  }

  static Pymobiledevice3Command? _managedWindowsCommand({String? appData}) {
    final root = appData ?? Platform.environment['APPDATA'];
    if (root == null) return null;
    final executable = File(
      '$root\\uv\\tools\\pymobiledevice3\\Scripts\\pymobiledevice3.exe',
    );
    if (!executable.existsSync()) return null;
    return Pymobiledevice3Command(executable.path, const []);
  }

  @visibleForTesting
  static Pymobiledevice3Command? bundledWindowsCommandIn(Directory directory) {
    final executable = File(
      '${directory.path}\\ios-runtime\\pymobiledevice3.exe',
    );
    if (executable.existsSync()) {
      return Pymobiledevice3Command(executable.path, const []);
    }
    final uv = File('${directory.path}\\ios-runtime\\uv.exe');
    if (!uv.existsSync()) return null;
    return Pymobiledevice3Command(uv.path, const [
      'tool',
      'run',
      '--from',
      'pymobiledevice3==$managedVersion',
      'pymobiledevice3',
    ]);
  }
}
