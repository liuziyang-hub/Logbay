import 'dart:io';

/// Resolves how to invoke `pymobiledevice3` on this host.
class Pymobiledevice3Command {
  const Pymobiledevice3Command(this.executable, this.prefixArgs);

  final String executable;
  final List<String> prefixArgs;

  /// Full argv after the executable (includes `-m pymobiledevice3` when needed).
  List<String> args(List<String> command) => [...prefixArgs, ...command];
}

/// Shared launcher for host-installed pymobiledevice3 (not bundled).
class Pymobiledevice3Launcher {
  Pymobiledevice3Launcher._();

  static Future<Pymobiledevice3Command?>? _resolved;

  static Future<Pymobiledevice3Command?> resolve() {
    return _resolved ??= _probe();
  }

  static void resetCache() {
    _resolved = null;
  }

  static Future<bool> isAvailable() async => (await resolve()) != null;

  static Future<Pymobiledevice3Command?> _probe() async {
    for (final candidate in _candidates()) {
      try {
        final result = await Process.run(
          candidate.executable,
          [...candidate.prefixArgs, '--help'],
          runInShell: Platform.isWindows,
        );
        final out = '${result.stdout}\n${result.stderr}'.toLowerCase();
        if (result.exitCode == 0 ||
            out.contains('syslog') ||
            out.contains('usage') ||
            out.contains('pymobiledevice3')) {
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
      return const [
        Pymobiledevice3Command('pymobiledevice3', []),
        Pymobiledevice3Command('py', ['-3', '-m', 'pymobiledevice3']),
        Pymobiledevice3Command('python', ['-m', 'pymobiledevice3']),
        Pymobiledevice3Command('python3', ['-m', 'pymobiledevice3']),
      ];
    }
    return const [
      Pymobiledevice3Command('pymobiledevice3', []),
      Pymobiledevice3Command('python3', ['-m', 'pymobiledevice3']),
      Pymobiledevice3Command('python', ['-m', 'pymobiledevice3']),
    ];
  }
}
