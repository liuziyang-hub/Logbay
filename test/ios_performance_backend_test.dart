import 'package:eagly/features/performance/ios/ios_performance_backend.dart';
import 'package:eagly/features/performance/services/device_performance_backend.dart';
import 'package:flutter_test/flutter_test.dart';

class _Runner implements IosMetricsCommandRunner {
  int systemCall = 0;
  @override
  Future<String> run(List<String> arguments, {required String udid}) async {
    if (arguments.contains('process-id-for-bundle-id')) return '2468\n';
    if (arguments.contains('system')) {
      systemCall++;
      return '{"netBytesIn":${1000 + systemCall * 100},"netBytesOut":${2000 + systemCall * 50}}';
    }
    return '[{"name":"Demo","cpuUsage":7.5,"physFootprint":4096}]';
  }
}

void main() {
  test('collects process metrics and computes network deltas', () async {
    final backend = IosPerformanceBackend(deviceId: 'ios-1', runner: _Runner());
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
    expect(samples.first.networkRxBytes, isNull);
    expect(samples.last.networkRxBytes, 100);
    expect(samples.last.networkTxBytes, 50);
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
}
