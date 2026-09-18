import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../features/performance/android/perfetto_queries.dart';
import '../../utils/tools_path.dart';

class TraceProcessorExecution {
  const TraceProcessorExecution({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract class TraceProcessorExecutor {
  Future<TraceProcessorExecution> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
    required int maxOutputBytes,
  });

  Future<void> cancel();
}

class NativeTraceProcessorExecutor implements TraceProcessorExecutor {
  Process? _activeProcess;
  bool _cancelled = false;

  @override
  Future<TraceProcessorExecution> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
    required int maxOutputBytes,
  }) async {
    if (_activeProcess != null) throw StateError('已有 Perfetto 解析任务正在运行。');
    _cancelled = false;
    final process = await Process.start(executable, arguments);
    _activeProcess = process;
    final stdoutFuture = _readLimited(
      process.stdout,
      maxOutputBytes,
      onLimit: () => process.kill(ProcessSignal.sigkill),
    );
    final stderrFuture = _readLimited(
      process.stderr,
      1024 * 1024,
      onLimit: () => process.kill(ProcessSignal.sigkill),
    );
    try {
      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          throw TimeoutException('Perfetto 轨迹解析超时。', timeout);
        },
      );
      final stdout = utf8.decode(await stdoutFuture, allowMalformed: true);
      final stderr = utf8.decode(await stderrFuture, allowMalformed: true);
      if (_cancelled) throw StateError('Perfetto 轨迹解析已取消。');
      return TraceProcessorExecution(
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
      );
    } finally {
      _activeProcess = null;
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    _activeProcess?.kill(ProcessSignal.sigkill);
  }

  Future<Uint8List> _readLimited(
    Stream<List<int>> stream,
    int limit, {
    required void Function() onLimit,
  }) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > limit) {
        onLimit();
        throw StateError('Perfetto 输出超过安全上限（$limit 字节）。');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }
}

class PerfettoQueryResult {
  const PerfettoQueryResult({required this.columns, required this.rows});

  final List<String> columns;
  final List<Map<String, Object?>> rows;
}

class PerfettoTraceProcessor {
  PerfettoTraceProcessor({
    TraceProcessorExecutor? executor,
    String? executablePath,
  }) : _executor = executor ?? NativeTraceProcessorExecutor(),
       executable =
           executablePath ??
           resolveBundledExecutablePath('trace_processor_shell') ??
           'trace_processor_shell';

  final TraceProcessorExecutor _executor;
  final String executable;

  Future<PerfettoQueryResult> query(
    String tracePath,
    PerfettoQuery query, {
    Duration timeout = const Duration(seconds: 45),
    int maxOutputBytes = 16 * 1024 * 1024,
  }) async {
    if (!File(tracePath).existsSync()) {
      throw ArgumentError.value(tracePath, 'tracePath', '轨迹文件不存在');
    }
    final execution = await _executor.run(
      executable,
      ['query', '--quiet', tracePath, query.sql],
      timeout: timeout,
      maxOutputBytes: maxOutputBytes,
    );
    if (execution.exitCode != 0) {
      final detail = execution.stderr.trim();
      throw StateError(detail.isEmpty ? 'Perfetto 轨迹解析失败。' : detail);
    }
    return parseCsv(execution.stdout);
  }

  Future<void> cancel() => _executor.cancel();

  static PerfettoQueryResult parseCsv(String source) {
    final records = _parseCsvRecords(source);
    if (records.isEmpty) {
      return const PerfettoQueryResult(columns: [], rows: []);
    }
    final columns = records.first;
    final rows = <Map<String, Object?>>[];
    for (final record in records.skip(1)) {
      if (record.length == 1 && record.single.isEmpty) continue;
      final row = <String, Object?>{};
      for (var index = 0; index < columns.length; index++) {
        row[columns[index]] = index < record.length
            ? _typedValue(record[index])
            : null;
      }
      rows.add(row);
    }
    return PerfettoQueryResult(columns: List.unmodifiable(columns), rows: rows);
  }

  static PerfettoQueryResult parseJson(String source) {
    if (source.trim().isEmpty) {
      return const PerfettoQueryResult(columns: [], rows: []);
    }
    final decoded = jsonDecode(source);
    final values = decoded is List
        ? decoded
        : decoded is Map<String, dynamic> && decoded['rows'] is List
        ? decoded['rows'] as List
        : throw const FormatException('无法识别 Trace Processor JSON 输出。');
    final rows = values
        .map((value) {
          if (value is! Map) throw const FormatException('JSON 行不是对象。');
          return value.map((key, value) => MapEntry(key.toString(), value));
        })
        .toList(growable: false);
    final columns = rows.isEmpty ? <String>[] : rows.first.keys.toList();
    return PerfettoQueryResult(columns: columns, rows: rows);
  }

  static Object? _typedValue(String value) {
    if (value.isEmpty || value.toUpperCase() == 'NULL') return null;
    return int.tryParse(value) ?? double.tryParse(value) ?? value;
  }

  static List<List<String>> _parseCsvRecords(String source) {
    final records = <List<String>>[];
    var record = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (char == '"') {
        if (quoted && index + 1 < source.length && source[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        record.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') {
          index++;
        }
        record.add(field.toString());
        field.clear();
        if (record.any((value) => value.isNotEmpty)) records.add(record);
        record = <String>[];
      } else {
        field.write(char);
      }
    }
    if (quoted) throw const FormatException('CSV 引号未闭合。');
    if (field.isNotEmpty || record.isNotEmpty) {
      record.add(field.toString());
      if (record.any((value) => value.isNotEmpty)) records.add(record);
    }
    return records;
  }
}
