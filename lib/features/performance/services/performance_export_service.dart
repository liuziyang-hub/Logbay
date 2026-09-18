import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../data/performance_sample.dart';
import '../data/performance_session.dart';

enum PerformanceExportFormat { csv, json }

class PerformanceExportService {
  const PerformanceExportService();

  String encode(PerformanceSession session, PerformanceExportFormat format) =>
      switch (format) {
        PerformanceExportFormat.csv => _encodeCsv(session.samples),
        PerformanceExportFormat.json => _encodeJson(session),
      };

  Future<String?> exportWithDialog(
    PerformanceSession session,
    PerformanceExportFormat format,
  ) async {
    if (session.samples.isEmpty) {
      throw StateError('当前会话没有可导出的性能数据。');
    }
    final extension = format.name;
    final stamp = session.startedAt.toIso8601String().replaceAll(':', '-');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出性能数据',
      fileName: 'Logbay-performance-$stamp.$extension',
      allowedExtensions: [extension],
      type: FileType.custom,
    );
    if (path == null) return null;
    await File(path).writeAsString(encode(session, format), flush: true);
    return path;
  }

  String _encodeCsv(List<PerformanceSample> samples) {
    final rows = <List<Object?>>[
      const [
        'timestamp',
        'elapsed_ms',
        'fps',
        'frame_time_ms',
        'cpu_percent',
        'memory_bytes',
        'network_rx_bytes',
        'network_tx_bytes',
        'temperature_celsius',
        'slow_frames',
        'frozen_frames',
      ],
      ...samples.map(_sampleValues),
    ];
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  String _encodeJson(PerformanceSession session) {
    final value = {
      'schemaVersion': 1,
      'deviceId': session.deviceId,
      'applicationId': session.applicationId,
      'startedAt': session.startedAt.toIso8601String(),
      'endedAt': session.endedAt?.toIso8601String(),
      'sampleIntervalMs': session.sampleInterval.inMilliseconds,
      'droppedSampleCount': session.droppedSampleCount,
      'samples': session.samples
          .map((sample) {
            final values = _sampleValues(sample);
            return <String, Object?>{
              'timestamp': values[0],
              'elapsedMs': values[1],
              'fps': values[2],
              'frameTimeMs': values[3],
              'cpuPercent': values[4],
              'memoryBytes': values[5],
              'networkRxBytes': values[6],
              'networkTxBytes': values[7],
              'temperatureCelsius': values[8],
              'slowFrames': values[9],
              'frozenFrames': values[10],
            };
          })
          .toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  List<Object?> _sampleValues(PerformanceSample sample) => [
    sample.timestamp.toIso8601String(),
    sample.elapsed.inMilliseconds,
    sample.fps,
    sample.frameTimeMs,
    sample.cpuPercent,
    sample.memoryBytes,
    sample.networkRxBytes,
    sample.networkTxBytes,
    sample.temperatureCelsius,
    sample.slowFrameCount,
    sample.frozenFrameCount,
  ];

  String _csvCell(Object? value) {
    if (value == null) return '';
    final text = '$value';
    if (!text.contains(RegExp(r'[,"\r\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
