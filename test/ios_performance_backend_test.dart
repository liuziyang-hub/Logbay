import 'package:eagly/features/performance/ios/ios_performance_backend.dart';
import 'package:eagly/features/performance/services/device_performance_backend.dart';
import 'package:flutter_test/flutter_test.dart';

class _Runner implements IosMetricsCommandRunner {
  int systemCall = 0;
  final commands = <List<String>>[];

  @override
  Future<String> run(List<String> arguments, {required String udid}) async {
    commands.add(arguments);
    if (arguments.contains('process-id-for-bundle-id')) return '2468\n';
    if (arguments.contains('system')) {
      systemCall++;
      return 'netBytesIn: ${1000 + systemCall * 100}\n'
          'netBytesOut: ${2000 + systemCall * 50}';
    }
    return '[{"name":"Demo","cpuUsage":7.5,"physFootprint":4096}]';
  }

  @override
  Future<String> runFirstLine(
    List<String> arguments, {
    required String udid,
  }) async {
    commands.add(arguments);
    if (arguments.contains('graphics')) {
      return '{"CoreAnimationFramesPerSecond":60}';
    }
    return '{"Temperature":3980}';
  }
}

void main() {
  test('collects process metrics and computes network deltas', () async {
    final runner = _Runner();
    final backend = IosPerformanceBackend(deviceId: 'ios-1', runner: runner);
    final stream = backend.start(
      const PerformanceCollectionRequest(
        applicationId: 'Demo',
        sampleInterval: Duration(milliseconds: 1),
      ),
    );
    final samples = await stream.take(2).toList();
    await backend.stop();

    expect(samples.first.cpuPercent, 7.5);
    expect(samples.first.memoryBytes, 4096);
    expect(samples.first.fps, 60);
    expect(samples.first.temperatureCelsius, 39.8);
    expect(samples.first.networkRxBytes, isNull);
    expect(samples.last.networkRxBytes, 100);
    expect(samples.last.networkTxBytes, 50);
    expect(
      runner.commands
          .where((command) => command.contains('dvt'))
          .every((command) => command.contains('--userspace')),
      isTrue,
    );
  });

  test('resolves bundle identifiers with the upstream DVT command', () async {
    final backend = IosPerformanceBackend(deviceId: 'ios-1', runner: _Runner());

    final sample = await backend
        .start(
          const PerformanceCollectionRequest(
            applicationId: 'com.example.demo',
            sampleInterval: Duration(milliseconds: 1),
          ),
        )
        .first;
    await backend.stop();

    expect(sample.cpuPercent, 7.5);
  });

  test(
    'skips the expensive all-process snapshot without an app target',
    () async {
      final runner = _Runner();
      final backend = IosPerformanceBackend(deviceId: 'ios-1', runner: runner);

      final sample = await backend
          .start(
            const PerformanceCollectionRequest(
              sampleInterval: Duration(milliseconds: 1),
            ),
          )
          .first;
      await backend.stop();

      expect(sample.cpuPercent, isNull);
      expect(sample.memoryBytes, isNull);
      expect(sample.unavailableReasons.values, contains('请输入应用包名或进程名后采集。'));
      expect(
        runner.commands.any(
          (command) =>
              command.contains('process') && command.contains('single'),
        ),
        isFalse,
      );
    },
  );
}
