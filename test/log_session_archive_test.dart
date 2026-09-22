import 'dart:convert';
import 'dart:io';

import 'package:eagly/data/device.dart';
import 'package:eagly/features/logs/data/models/log_entry.dart';
import 'package:eagly/features/logs/services/log_session_archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('streams a complete Android Studio export and supports clear', () async {
    final archive = await LogSessionArchive.create();
    final outputDirectory = await Directory.systemTemp.createTemp(
      'logbay-archive-test-',
    );
    addTearDown(() async {
      await archive.dispose();
      await outputDirectory.delete(recursive: true);
    });

    archive.append(_entry('first'));
    archive.append(_entry('second'));
    final firstExport = File('${outputDirectory.path}/first.json');
    await archive.exportTo(
      firstExport,
      const AndroidDevice('serial', 'device'),
    );

    final firstJson = jsonDecode(await firstExport.readAsString()) as Map;
    expect(firstJson['metadata']['totalLogs'], 2);
    expect(
      (firstJson['logcatMessages'] as List).map((item) => item['message']),
      ['first', 'second'],
    );

    archive.clear();
    archive.append(_entry('after clear'));
    final secondExport = File('${outputDirectory.path}/second.json');
    await archive.exportTo(secondExport, null);

    final secondJson = jsonDecode(await secondExport.readAsString()) as Map;
    expect(secondJson['metadata']['totalLogs'], 1);
    expect(
      (secondJson['logcatMessages'] as List).single['message'],
      'after clear',
    );
  });
}

LogEntry _entry(String message) => LogEntry(
  timestamp: '09-22 12:00:00.000',
  pid: '1',
  tid: '2',
  level: 'I',
  tag: 'Test',
  message: message,
);
