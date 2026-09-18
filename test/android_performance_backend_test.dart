import 'package:eagly/features/performance/android/android_performance_backend.dart';
import 'package:eagly/features/performance/data/performance_metric.dart';
import 'package:eagly/features/performance/services/device_performance_backend.dart';
import 'package:eagly/services/tools/adb_tool.dart';
import 'package:eagly/services/tools/tool_process_runner.dart';
import 'package:flutter_test/flutter_test.dart';

class _MetricsAdbTool extends AdbTool {
  _MetricsAdbTool() : super(executablePath: '/usr/bin/true');

  int systemStatRound = 0;
  int processStatRound = 0;

  @override
  Future<ToolCommandResult> runShellCommand(
    String deviceId,
    List<String> arguments, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final command = arguments.join(' ');
    final output = switch (command) {
      'pidof com.example.app' => '321',
      'dumpsys package com.example.app' => 'userId=10123',
      'dumpsys gfxinfo com.example.app framestats' =>
        '''
---PROFILEDATA---
Flags,IntendedVsync,Vsync,OldestInputEvent,NewestInputEvent,HandleInputStart,AnimationStart,PerformTraversalsStart,DrawStart,SyncQueued,SyncStart,IssueDrawCommandsStart,SwapBuffers,FrameCompleted
0,1000000000,0,0,0,0,0,0,0,0,0,0,0,1010000000
---PROFILEDATA---''',
      'cat /proc/stat' =>
        systemStatRound++ == 0
            ? 'cpu 100 0 100 800 0 0 0 0'
            : 'cpu 140 0 120 840 0 0 0 0',
      'cat /proc/321/stat' =>
        processStatRound++ == 0
            ? '321 (app) S 1 1 1 0 0 0 0 0 0 0 10 5 0 0 0 0'
            : '321 (app) S 1 1 1 0 0 0 0 0 0 0 20 10 0 0 0 0',
      'dumpsys meminfo com.example.app' => 'TOTAL PSS: 2048 TOTAL RSS: 4096',
      'cat /proc/net/xt_qtaguid/stats' => '2 wlan0 0x0 10123 0 1000 1 500 1',
      'dumpsys thermalservice' =>
        'Temperature{mValue=38.5, mType=3, mName=SKIN}',
      _ => '',
    };
    return ToolCommandResult(exitCode: 0, stdout: output, stderr: '');
  }
}

void main() {
  test('collects target app metrics without overlapping rounds', () async {
    final backend = AndroidPerformanceBackend(
      adbTool: _MetricsAdbTool(),
      deviceId: 'device-1',
    );
    final samples = await backend
        .start(
          const PerformanceCollectionRequest(
            applicationId: 'com.example.app',
            sampleInterval: Duration(milliseconds: 1),
          ),
        )
        .take(2)
        .toList();

    expect(samples.first.fps, isNotNull);
    expect(samples.first.memoryBytes, 2048 * 1024);
    expect(samples.first.networkRxBytes, 1000);
    expect(samples.first.temperatureCelsius, 38.5);
    expect(
      samples.first.sourceQuality[PerformanceMetric.temperature],
      PerformanceSourceQuality.precise,
    );
    expect(samples.last.cpuPercent, isNotNull);
  });

  test('marks app metrics unavailable until an app is selected', () async {
    final backend = AndroidPerformanceBackend(
      adbTool: _MetricsAdbTool(),
      deviceId: 'device-1',
    );
    final sample = await backend
        .start(const PerformanceCollectionRequest())
        .first;

    expect(sample.fps, isNull);
    expect(
      sample.unavailableReasons[PerformanceMetric.fps],
      contains('请选择目标应用'),
    );
    expect(sample.temperatureCelsius, 38.5);
  });
}
