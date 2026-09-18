import '../../../services/tools/adb_tool.dart';
import '../data/performance_metric.dart';
import '../data/performance_sample.dart';
import 'android_gfxinfo_parser.dart';
import 'android_meminfo_parser.dart';
import 'android_network_parser.dart';
import 'android_proc_cpu_parser.dart';
import 'android_temperature_parser.dart';

class AndroidLiveMetricsCollector {
  AndroidLiveMetricsCollector({
    required AdbTool adbTool,
    required this.deviceId,
  }) : _adbTool = adbTool;

  final AdbTool _adbTool;
  final String deviceId;

  AndroidCpuSnapshot? _previousCpu;
  String? _cachedPackage;
  int? _pid;
  int? _uid;

  Future<PerformanceSample> collect({
    required String? applicationId,
    required Duration elapsed,
  }) async {
    final unavailable = <PerformanceMetric, String>{};
    final quality = <PerformanceMetric, PerformanceSourceQuality>{};
    final packageName = applicationId?.trim();
    if (packageName == null || packageName.isEmpty) {
      const reason = '请选择目标应用后再采集该指标。';
      unavailable.addAll({
        PerformanceMetric.fps: reason,
        PerformanceMetric.frameTime: reason,
        PerformanceMetric.cpu: reason,
        PerformanceMetric.memory: reason,
        PerformanceMetric.networkReceive: reason,
        PerformanceMetric.networkTransmit: reason,
      });
    } else {
      await _ensureProcess(packageName);
    }

    AndroidFrameStats? frame;
    double? cpu;
    AndroidAppMemoryStats? memory;
    AndroidNetworkStats? network;

    if (packageName != null && packageName.isNotEmpty) {
      frame = AndroidGfxinfoParser.parse(
        await _stdout(['dumpsys', 'gfxinfo', packageName, 'framestats']),
      );
      if (frame == null) {
        unavailable[PerformanceMetric.fps] = '设备未返回目标应用的帧统计。';
        unavailable[PerformanceMetric.frameTime] = '设备未返回目标应用的帧耗时。';
      } else {
        quality[PerformanceMetric.fps] = PerformanceSourceQuality.precise;
        quality[PerformanceMetric.frameTime] = PerformanceSourceQuality.precise;
      }

      final pid = _pid;
      if (pid == null) {
        unavailable[PerformanceMetric.cpu] = '目标应用当前未运行。';
      } else {
        final snapshot = AndroidProcCpuParser.parse(
          systemStat: await _stdout(['cat', '/proc/stat']),
          processStat: await _stdout(['cat', '/proc/$pid/stat']),
        );
        final previous = _previousCpu;
        if (snapshot != null && previous != null) {
          cpu = snapshot.usageSince(previous);
        }
        _previousCpu = snapshot;
        if (cpu == null) {
          unavailable[PerformanceMetric.cpu] = '正在建立 CPU 采样基线。';
        } else {
          quality[PerformanceMetric.cpu] = PerformanceSourceQuality.precise;
        }
      }

      memory = AndroidMeminfoParser.parse(
        await _stdout(['dumpsys', 'meminfo', packageName]),
      );
      if (memory == null) {
        unavailable[PerformanceMetric.memory] = '设备未返回目标应用的内存统计。';
      } else {
        quality[PerformanceMetric.memory] = PerformanceSourceQuality.precise;
      }

      final uid = _uid;
      if (uid == null) {
        unavailable[PerformanceMetric.networkReceive] = '无法解析目标应用 UID。';
        unavailable[PerformanceMetric.networkTransmit] = '无法解析目标应用 UID。';
      } else {
        network = AndroidNetworkParser.parseQtaguid(
          await _stdout(['cat', '/proc/net/xt_qtaguid/stats']),
          uid: uid,
        );
        if (network == null) {
          const reason = '系统未开放目标应用的网络计数器。';
          unavailable[PerformanceMetric.networkReceive] = reason;
          unavailable[PerformanceMetric.networkTransmit] = reason;
        } else {
          quality[PerformanceMetric.networkReceive] =
              PerformanceSourceQuality.precise;
          quality[PerformanceMetric.networkTransmit] =
              PerformanceSourceQuality.precise;
        }
      }
    }

    var temperature = AndroidTemperatureParser.parseThermalService(
      await _stdout(['dumpsys', 'thermalservice']),
    );
    if (temperature != null) {
      quality[PerformanceMetric.temperature] = PerformanceSourceQuality.precise;
    } else {
      temperature = AndroidTemperatureParser.parseBattery(
        await _stdout(['dumpsys', 'battery']),
      );
      if (temperature == null) {
        unavailable[PerformanceMetric.temperature] = '设备未提供可读取的温度数据。';
      } else {
        quality[PerformanceMetric.temperature] =
            PerformanceSourceQuality.fallback;
      }
    }

    return PerformanceSample(
      timestamp: DateTime.now(),
      elapsed: elapsed,
      fps: frame?.fps,
      frameTimeMs: frame?.averageFrameTimeMs,
      slowFrameCount: frame?.slowFrameCount,
      frozenFrameCount: frame?.frozenFrameCount,
      cpuPercent: cpu,
      memoryBytes: memory == null ? null : memory.pssKb * 1024,
      networkRxBytes: network?.receiveBytes,
      networkTxBytes: network?.transmitBytes,
      temperatureCelsius: temperature,
      sourceQuality: quality,
      unavailableReasons: unavailable,
    );
  }

  Future<void> _ensureProcess(String packageName) async {
    if (_cachedPackage != packageName) {
      _cachedPackage = packageName;
      _pid = null;
      _uid = null;
      _previousCpu = null;
    }
    final pidOutput = await _stdout(['pidof', packageName]);
    final pidValues = pidOutput.trim().split(RegExp(r'\s+'));
    _pid = pidValues.isEmpty ? null : int.tryParse(pidValues.first);
    if (_uid == null) {
      final packageDump = await _stdout(['dumpsys', 'package', packageName]);
      final uidMatch = RegExp(r'\buserId=(\d+)').firstMatch(packageDump);
      _uid = uidMatch == null ? null : int.tryParse(uidMatch.group(1)!);
    }
  }

  Future<String> _stdout(List<String> arguments) async {
    try {
      final result = await _adbTool.runShellCommand(
        deviceId,
        arguments,
        timeout: const Duration(seconds: 4),
      );
      return result.isSuccess ? result.stdout : '';
    } catch (_) {
      return '';
    }
  }
}
