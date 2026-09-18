import 'dart:convert';

import 'package:eagly/features/performance/data/performance_sample.dart';
import 'package:eagly/features/performance/data/performance_session.dart';
import 'package:eagly/features/performance/services/performance_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PerformanceSession session;

  setUp(() {
    session =
        PerformanceSession(
          deviceId: 'device-1',
          applicationId: 'com.example.demo',
          startedAt: DateTime.utc(2026, 9, 18, 8),
        )..add(
          PerformanceSample(
            timestamp: DateTime.utc(2026, 9, 18, 8, 0, 1),
            elapsed: const Duration(seconds: 1),
            fps: 59.5,
            cpuPercent: 7.2,
            memoryBytes: 4096,
          ),
        );
  });

  test('exports stable CSV columns without inventing missing values', () {
    final csv = const PerformanceExportService().encode(
      session,
      PerformanceExportFormat.csv,
    );

    expect(csv, contains('timestamp,elapsed_ms,fps'));
    expect(csv, contains('59.5,,7.2,4096'));
  });

  test('exports versioned JSON with session metadata', () {
    final source = const PerformanceExportService().encode(
      session,
      PerformanceExportFormat.json,
    );
    final json = jsonDecode(source) as Map<String, Object?>;

    expect(json['schemaVersion'], 1);
    expect(json['applicationId'], 'com.example.demo');
    expect(json['samples'], hasLength(1));
  });
}
