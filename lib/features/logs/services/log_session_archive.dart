import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../data/device.dart';
import '../data/models/log_entry.dart';
import 'log_formats/android_logcat_format.dart';

/// Disk-backed copy of a live log session.
///
/// Each line is one Android Studio-compatible message object. This keeps
/// appends cheap and lets export stream the archive without loading it all.
class LogSessionArchive {
  LogSessionArchive._(this._directory, this._file, this._sink);

  static const _format = AndroidLogcatFormat();

  final Directory _directory;
  File _file;
  IOSink _sink;
  int _entryCount = 0;
  Object? _error;
  var _generation = 0;

  static Future<LogSessionArchive> create() async {
    final directory = await Directory.systemTemp.createTemp('logbay-logs-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}session.ndjson',
    );
    return LogSessionArchive._(
      directory,
      file,
      file.openWrite(mode: FileMode.writeOnly),
    );
  }

  int get entryCount => _entryCount;
  bool get isAvailable => _error == null;
  Object? get error => _error;

  void append(LogEntry entry) {
    if (!isAvailable) return;
    try {
      _sink.writeln(jsonEncode(_format.entryToMap(entry)));
      _entryCount++;
    } catch (error) {
      _error = error;
    }
  }

  Future<void> flush() async {
    if (!isAvailable) return;
    try {
      await _sink.flush();
    } catch (error) {
      _error = error;
    }
  }

  /// Starts a new empty generation immediately. Closing and deleting the old
  /// file happens in the background, so a running stream does not miss lines.
  void clear() {
    final oldSink = _sink;
    final oldFile = _file;
    final nextGeneration = _generation + 1;
    final nextFile = File(
      '${_directory.path}${Platform.pathSeparator}session-$nextGeneration.ndjson',
    );
    final IOSink nextSink;
    try {
      nextSink = nextFile.openWrite(mode: FileMode.writeOnly);
    } catch (error) {
      _error = error;
      return;
    }
    _generation = nextGeneration;
    _file = nextFile;
    _sink = nextSink;
    _entryCount = 0;
    _error = null;
    unawaited(
      oldSink.close().then((_) async {
        try {
          await oldFile.delete();
        } catch (_) {}
      }),
    );
  }

  Future<void> exportTo(File destination, Device? device) async {
    if (!isAvailable) throw StateError('日志归档不可用：$_error');
    await flush();
    if (!isAvailable) throw StateError('日志归档不可用：$_error');

    final snapshotCount = _entryCount;
    final output = destination.openWrite(mode: FileMode.writeOnly);
    final metadata = {
      'device': {
        'physicalDevice': device == null
            ? null
            : {'serialNumber': device.id, 'status': device.status},
      },
      'exportedAt': DateTime.now().toIso8601String(),
      'totalLogs': snapshotCount,
    };

    try {
      output.write('{"metadata":${jsonEncode(metadata)},"logcatMessages":[');
      var written = 0;
      await for (final line
          in _file
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        if (written > 0) output.write(',');
        output.write(line);
        written++;
        if (written >= snapshotCount) break;
      }
      output.write(']}');
    } finally {
      await output.close();
    }
  }

  Future<void> dispose() async {
    try {
      await _sink.close();
    } catch (_) {}
    try {
      await _directory.delete(recursive: true);
    } catch (_) {}
  }
}
