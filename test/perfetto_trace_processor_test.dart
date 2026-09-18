import 'dart:async';
import 'dart:io';

import 'package:eagly/features/performance/android/perfetto_queries.dart';
import 'package:eagly/services/tools/perfetto_trace_processor.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExecutor implements TraceProcessorExecutor {
  TraceProcessorExecution result = const TraceProcessorExecution(
    exitCode: 0,
    stdout: 'ts,name,value\n1,"Render, main",16.7\n2,"quoted ""value""",NULL\n',
    stderr: '',
  );
  Object? error;
  bool cancelled = false;
  List<String>? arguments;

  @override
  Future<TraceProcessorExecution> run(
    String executable,
    List<String> arguments, {
    required Duration timeout,
    required int maxOutputBytes,
  }) async {
    this.arguments = arguments;
    if (error case final failure?) throw failure;
    return result;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

void main() {
  late Directory directory;
  late String tracePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trace-processor-test-');
    tracePath = '${directory.path}${Platform.pathSeparator}sample.pftrace';
    await File(tracePath).writeAsBytes(const [1, 2, 3]);
  });

  tearDown(() async => directory.delete(recursive: true));

  test('runs only controlled arguments and parses typed CSV rows', () async {
    final executor = _FakeExecutor();
    final processor = PerfettoTraceProcessor(
      executor: executor,
      executablePath: 'trace_processor_shell',
    );

    final result = await processor.query(
      tracePath,
      const PerfettoQuery(id: 'frames', sql: 'SELECT 1;'),
    );

    expect(executor.arguments, ['query', '--quiet', tracePath, 'SELECT 1;']);
    expect(result.columns, ['ts', 'name', 'value']);
    expect(result.rows.first, {'ts': 1, 'name': 'Render, main', 'value': 16.7});
    expect(result.rows.last['name'], 'quoted "value"');
    expect(result.rows.last['value'], isNull);
  });

  test('accepts empty CSV and JSON object rows', () {
    expect(PerfettoTraceProcessor.parseCsv('').rows, isEmpty);
    final result = PerfettoTraceProcessor.parseJson(
      '{"rows":[{"ts":1,"value":2.5}]}',
    );
    expect(result.columns, ['ts', 'value']);
    expect(result.rows.single['value'], 2.5);
  });

  test('surfaces timeout and output-limit failures', () async {
    final executor = _FakeExecutor();
    final processor = PerfettoTraceProcessor(
      executor: executor,
      executablePath: 'trace_processor_shell',
    );
    executor.error = TimeoutException('timeout');
    await expectLater(
      processor.query(
        tracePath,
        const PerfettoQuery(id: 'x', sql: 'SELECT 1;'),
      ),
      throwsA(isA<TimeoutException>()),
    );
    executor.error = StateError('输出超过安全上限');
    await expectLater(
      processor.query(
        tracePath,
        const PerfettoQuery(id: 'x', sql: 'SELECT 1;'),
      ),
      throwsStateError,
    );
  });

  test('forwards cancellation to the active executor', () async {
    final executor = _FakeExecutor();
    final processor = PerfettoTraceProcessor(executor: executor);

    await processor.cancel();

    expect(executor.cancelled, isTrue);
  });

  test('query catalog rejects unsafe application identifiers', () {
    expect(
      () => PerfettoQueries.forApplication("app'; DROP TABLE slice;--"),
      throwsArgumentError,
    );
    final queries = PerfettoQueries.forApplication('com.example.app');
    expect(
      queries.map((query) => query.id),
      containsAll(['frames', 'cpu', 'memory', 'network', 'power', 'slices']),
    );
  });
}
