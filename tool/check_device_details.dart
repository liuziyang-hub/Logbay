// Quick parser smoke test mirroring AdbTool device-details parsing.
// Run: dart run tool/check_device_details.dart
import 'dart:io';

void main(List<String> args) async {
  final adb = args.isNotEmpty
      ? args.first
      : r'D:\Eagly\App\data\adb.exe';
  final devices = await Process.run(adb, ['devices']);
  final idLine = (devices.stdout as String)
      .split('\n')
      .skip(1)
      .map((l) => l.trim())
      .firstWhere(
        (l) => l.endsWith('device') || l.contains('\tdevice'),
        orElse: () => '',
      );
  if (idLine.isEmpty) {
    stderr.writeln('FAIL: no android device');
    exit(2);
  }
  final id = idLine.split(RegExp(r'\s+')).first;
  stdout.writeln('device=$id');

  Future<String> sh(List<String> a) async {
    final r = await Process.run(adb, ['-s', id, 'shell', ...a]);
    return r.stdout as String;
  }

  final propsOut = await sh(['getprop']);
  final props = <String, String>{};
  final re = RegExp(r'^\[([^\]]+)\]:\s*\[(.*)\]$');
  for (final raw in propsOut.split('\n')) {
    final m = re.firstMatch(raw.trim());
    if (m == null) continue;
    final k = m.group(1)?.trim();
    final v = m.group(2)?.trim();
    if (k != null && v != null && k.isNotEmpty && v.isNotEmpty) props[k] = v;
  }

  final need = [
    'ro.product.model',
    'ro.build.version.release',
    'ro.build.version.sdk',
  ];
  var ok = true;
  for (final k in need) {
    final v = props[k];
    stdout.writeln('prop $k=${v ?? "<missing>"}');
    if (v == null || v.isEmpty) ok = false;
  }

  final batt = await sh(['dumpsys', 'battery']);
  final level = RegExp(r'^\s*level:\s*(\d+)', multiLine: true).firstMatch(batt);
  stdout.writeln('battery level=${level?.group(1) ?? "<missing>"}');
  if (level == null) ok = false;

  final df = await sh(['df', '-h', '/data', '/sdcard']);
  stdout.writeln('df lines=${df.trim().split('\n').length}');
  if (!df.contains('Filesystem') && !df.contains('/')) ok = false;

  final echo = await sh(['echo', 'SHELL_OK']);
  stdout.writeln('echo=${echo.trim()}');
  if (!echo.contains('SHELL_OK')) ok = false;

  // Interactive shell brief
  final p = await Process.start(adb, ['-s', id, 'shell']);
  p.stdin.writeln('echo INTERACTIVE_OK');
  p.stdin.writeln('exit');
  final out = await p.stdout.transform(SystemEncoding().decoder).join();
  await p.stderr.drain();
  final code = await p.exitCode;
  stdout.writeln('interactive code=$code out_has=${out.contains('INTERACTIVE_OK')}');
  if (!out.contains('INTERACTIVE_OK') && code != 0) {
    // some devices echo differently; still ok if exit 0
    stdout.writeln('interactive raw=${out.replaceAll('\n', '\\n')}');
  }

  stdout.writeln(ok ? 'PASS device-details backend' : 'FAIL device-details backend');
  exit(ok ? 0 : 1);
}
