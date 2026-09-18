import 'package:flutter/material.dart';

import '../../presentation/components/feature_view.dart';
import '../../utils/utils.dart';
import 'data/performance_metric.dart';
import 'data/performance_sample.dart';
import 'performance_controller.dart';

class PerformanceFeatureView extends FeatureView {
  const PerformanceFeatureView({
    super.key,
    required this.controller,
    super.onClose,
  });

  final PerformanceController controller;

  @override
  State<PerformanceFeatureView> createState() => _PerformanceFeatureViewState();
}

class _PerformanceFeatureViewState
    extends FeatureViewState<PerformanceFeatureView> {
  final TextEditingController _applicationController = TextEditingController();

  @override
  Listenable get listenable => widget.controller;

  @override
  void dispose() {
    _applicationController.dispose();
    super.dispose();
  }

  Future<void> _toggleCollection() async {
    if (widget.controller.isRunning ||
        widget.controller.state == PerformanceCollectionState.starting) {
      await widget.controller.stop();
      return;
    }
    final application = _applicationController.text.trim();
    await widget.controller.start(
      applicationId: application.isEmpty ? null : application,
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final controller = widget.controller;
    final latest = controller.samples.lastOrNull;
    return FeaturePane(
      header: FeatureViewHeader(
        title: '性能分析',
        onClose: widget.onClose,
        actions: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _applicationController,
              enabled: !controller.isRunning,
              decoration: const InputDecoration(
                hintText: '应用包名或进程名',
                prefixIcon: Icon(Icons.apps_outlined, size: 17),
              ),
              onSubmitted: (_) => _toggleCollection(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: controller.state == PerformanceCollectionState.stopping
                ? null
                : _toggleCollection,
            icon: Icon(
              controller.isRunning
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(controller.isRunning ? '停止采集' : '开始采集'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _PerformanceBody(controller: controller, latest: latest),
      statusBar: FeatureStatusBar(
        children: [
          Icon(
            controller.isRunning ? Icons.circle : Icons.circle_outlined,
            size: 10,
            color: controller.isRunning
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(_stateLabel(controller.state)),
          const Spacer(),
          Text('${controller.samples.length} 个采样点'),
        ],
      ),
    );
  }

  String _stateLabel(PerformanceCollectionState state) => switch (state) {
    PerformanceCollectionState.idle => '尚未采集',
    PerformanceCollectionState.starting => '正在启动采集…',
    PerformanceCollectionState.running => '实时采集中',
    PerformanceCollectionState.stopping => '正在停止…',
    PerformanceCollectionState.failed => '采集异常',
  };
}

class _PerformanceBody extends StatelessWidget {
  const _PerformanceBody({required this.controller, required this.latest});

  final PerformanceController controller;
  final PerformanceSample? latest;

  @override
  Widget build(BuildContext context) {
    if (controller.errorMessage != null) {
      return Center(
        child: _Notice(
          icon: Icons.error_outline_rounded,
          title: '性能采集未能继续',
          message: controller.errorMessage!,
        ),
      );
    }
    final sample = latest;
    if (sample == null) {
      return const Center(
        child: _Notice(
          icon: Icons.monitor_heart_outlined,
          title: '选择应用并开始采集',
          message: '实时查看 FPS、帧耗时、CPU、内存、网络和温度。\n未提供的指标会显示具体原因，不会用 0 代替。',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              label: 'FPS',
              value: _number(sample.fps, 1),
              reason: sample.unavailableReasons[PerformanceMetric.fps],
              icon: Icons.speed_rounded,
            ),
            _MetricCard(
              label: '帧耗时',
              value: sample.frameTimeMs == null
                  ? null
                  : '${sample.frameTimeMs!.toStringAsFixed(1)} ms',
              reason: sample.unavailableReasons[PerformanceMetric.frameTime],
              icon: Icons.av_timer_rounded,
            ),
            _MetricCard(
              label: 'CPU',
              value: sample.cpuPercent == null
                  ? null
                  : '${sample.cpuPercent!.toStringAsFixed(1)}%',
              reason: sample.unavailableReasons[PerformanceMetric.cpu],
              icon: Icons.memory_rounded,
            ),
            _MetricCard(
              label: '内存',
              value: sample.memoryBytes == null
                  ? null
                  : formatBytes(sample.memoryBytes!),
              reason: sample.unavailableReasons[PerformanceMetric.memory],
              icon: Icons.storage_rounded,
            ),
            _MetricCard(
              label: '网络接收 / 发送',
              value:
                  sample.networkRxBytes == null || sample.networkTxBytes == null
                  ? null
                  : '${formatBytes(sample.networkRxBytes!)} / ${formatBytes(sample.networkTxBytes!)}',
              reason:
                  sample.unavailableReasons[PerformanceMetric.networkReceive],
              icon: Icons.swap_vert_circle_outlined,
            ),
            _MetricCard(
              label: '温度',
              value: sample.temperatureCelsius == null
                  ? null
                  : '${sample.temperatureCelsius!.toStringAsFixed(1)} °C',
              reason: sample.unavailableReasons[PerformanceMetric.temperature],
              icon: Icons.thermostat_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最近采样', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                ...controller.samples.reversed
                    .take(8)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 76,
                              child: Text('${item.elapsed.inSeconds}s'),
                            ),
                            Expanded(
                              child: Text('FPS ${_number(item.fps, 1) ?? '—'}'),
                            ),
                            Expanded(
                              child: Text(
                                'CPU ${item.cpuPercent?.toStringAsFixed(1) ?? '—'}%',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '内存 ${item.memoryBytes == null ? '—' : formatBytes(item.memoryBytes!)}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String? _number(double? value, int fractionDigits) =>
      value?.toStringAsFixed(fractionDigits);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.reason,
    required this.icon,
  });

  final String label;
  final String? value;
  final String? reason;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 210,
      height: 112,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 7),
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const Spacer(),
              Text(
                value ?? '不可用',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (value == null && reason != null)
                Text(
                  reason!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
