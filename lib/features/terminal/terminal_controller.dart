import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/device.dart';
import '../../services/devices_repository.dart';
import '../../session/feature_controller.dart';
import '../../utils/utils.dart';
import 'data/terminal_command.dart';
import 'data/terminal_line.dart';
import 'data/terminal_process.dart';
import 'data/terminal_tools.dart';

/// One terminal tab: a scrollback, a command history, the device its commands
/// go to, and at most one running process.
///
/// The device selector is implicit — a line is aimed at [targetDevice] and the
/// `-s`/`-u` flag is added on the way out. A line that selects a device itself
/// is passed through untouched.
class TerminalController extends FeatureController {
  TerminalController(super.session, {List<Device> Function()? availableDevices})
    : _availableDevices =
          availableDevices ?? (() => DevicesRepository.instance.devices) {
    _push(
      TerminalLine.notice(
        '命令将在 ${session.device.displayName} 上执行，无需手动指定设备。'
        '输入 help 查看用法。',
      ),
    );
  }

  /// How much scrollback is kept. A streaming command (`adb logcat`) fills
  /// this quickly, so old lines fall off the front the way a terminal's do.
  static const int maxScrollbackLines = 5000;

  /// How many submitted lines ↑/↓ can walk back through.
  static const int maxHistoryEntries = 200;

  /// How long process output is batched before the view is told about it.
  @visibleForTesting
  static Duration outputFlushInterval = const Duration(milliseconds: 60);

  final List<Device> Function() _availableDevices;

  final List<TerminalLine> _lines = [];
  final List<String> _history = [];
  int _historyCursor = 0;

  Device? _pinnedDevice;
  TerminalProcessSession? _running;
  String? _runningCommand;
  bool _cancelRequested = false;
  Timer? _flushTimer;
  bool _disposed = false;

  List<TerminalLine> get lines => List.unmodifiable(_lines);
  List<String> get history => List.unmodifiable(_history);

  /// True while a command is running; the input line then feeds its stdin.
  bool get isRunning => _running != null;

  /// The command line currently running, as actually executed.
  String? get runningCommand => _runningCommand;

  /// The device this tab's commands go to: the pinned one when `use` set it,
  /// otherwise the session's own device.
  Device get targetDevice {
    final pinned = _pinnedDevice;
    if (pinned == null) return device;
    return _lookupById(pinned.id) ?? pinned;
  }

  /// True when `use` pointed this tab somewhere other than its own device.
  bool get isPinnedElsewhere => _pinnedDevice != null;

  /// Whether the target device can be reached right now.
  bool get isTargetReachable => targetDevice.isConnected;

  /// The whole scrollback as text, for the copy button.
  String get scrollbackText => _lines.map((line) => line.copyText).join('\n');

  // ── Input ────────────────────────────────────────────────────────────────

  /// Handles one submitted line: stdin for the running process when there is
  /// one, otherwise a new command.
  Future<void> submit(String input) async {
    if (_disposed) return;
    final text = input.trim();
    if (text.isEmpty) return;

    _remember(text);
    final running = _running;
    if (running != null) {
      _append(TerminalLine.input(text));
      running.sendLine(text);
      return;
    }
    await _run(text);
  }

  /// Stops the running command, if any.
  Future<void> cancel() async {
    final running = _running;
    if (running == null) return;
    _cancelRequested = true;
    await running.kill();
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    _notify();
  }

  /// The previous history entry, or `null` at the start of the history.
  String? historyPrevious() {
    if (_historyCursor == 0) return null;
    _historyCursor--;
    return _history[_historyCursor];
  }

  /// The next history entry, an empty string when walking past the newest, or
  /// `null` when not browsing the history at all.
  String? historyNext() {
    if (_historyCursor >= _history.length) return null;
    _historyCursor++;
    return _historyCursor == _history.length ? '' : _history[_historyCursor];
  }

  void _remember(String text) {
    if (_history.isEmpty || _history.last != text) {
      _history.add(text);
      if (_history.length > maxHistoryEntries) _history.removeAt(0);
    }
    _historyCursor = _history.length;
  }

  // ── Dispatch ─────────────────────────────────────────────────────────────

  Future<void> _run(String text) async {
    final request = parseTerminalInput(text);

    var target = targetDevice;
    String? targetError;
    final reference = request.deviceRef;
    if (reference != null) {
      final resolved = _resolveDeviceRef(reference);
      if (resolved.device != null) {
        target = resolved.device!;
      } else {
        targetError = resolved.error;
      }
    }

    _append(TerminalLine.command(text, prompt: target.displayName));
    if (targetError != null) {
      _append(TerminalLine.error(targetError));
      return;
    }

    switch (request) {
      case TerminalInvalidRequest(:final message):
        _append(TerminalLine.error(message));
      case final TerminalBuiltinRequest builtin:
        _runBuiltin(builtin, target);
      case TerminalToolRequest(:final tool, :final arguments):
        if (!tool.supports(target)) {
          _append(
            TerminalLine.error(
              '${tool.executable} 面向 '
              '${_platformLabel(tool.platform!)} 设备；'
              '${target.displayName} 是 ${_platformLabel(target.platform)}。'
              '运行 `tools` 查看此处可用的工具。',
            ),
          );
          return;
        }
        await _start(
          TerminalInvocation(
            executable: tool.executable,
            arguments: tool.argumentsFor(target, arguments),
          ),
          target,
        );
      case TerminalShellRequest(:final script):
        await _runShell(script, target);
    }
  }

  /// A line that named no tool is meant for the device's own shell. Android
  /// has one via `adb shell`; iOS does not.
  Future<void> _runShell(String script, Device target) async {
    if (target.platform != DevicePlatform.android) {
      _append(
        TerminalLine.error(
          'iOS 设备没有交互式 shell，因此「${script.split(' ').first}」无法直接运行。'
          '请先输入 tools 查看可用工具，再以工具名开头执行（例如 ideviceinfo）。',
        ),
      );
      return;
    }

    final adb = lookupTerminalTool('adb')!;
    await _start(
      TerminalInvocation(
        executable: adb.executable,
        // The script is one argument, evaluated by the *device's* `sh`.
        arguments: adb.argumentsFor(target, ['shell', script]),
      ),
      target,
    );
  }

  Future<void> _start(TerminalInvocation invocation, Device target) async {
    if (!target.isConnected) {
      _append(
        TerminalLine.error(
          '${target.displayName} 已断开 — 请重新连接后再运行命令。',
        ),
      );
      return;
    }

    _cancelRequested = false;
    _runningCommand = invocation.displayCommand;
    _notify();

    StreamSubscription<TerminalOutputChunk>? subscription;
    try {
      final process = await service.startTerminalProcess(invocation);
      if (_disposed) {
        unawaited(process.kill());
        return;
      }
      _running = process;
      _notify();

      final drained = Completer<void>();
      subscription = process.output.listen(
        _appendOutput,
        onDone: () {
          if (!drained.isCompleted) drained.complete();
        },
        onError: (Object error) =>
            _appendOutput(TerminalOutputChunk('$error', isError: true)),
      );

      final exitCode = await process.exitCode;
      await drained.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );

      if (_cancelRequested) {
        _push(const TerminalLine.notice('已停止。'));
      } else if (exitCode != 0) {
        _push(TerminalLine.notice('以退出码 $exitCode 结束。'));
      }
    } catch (error) {
      _push(TerminalLine.error(describeError(error)));
    } finally {
      unawaited(subscription?.cancel());
      _running = null;
      _runningCommand = null;
      _cancelRequested = false;
      _flush();
    }
  }

  // ── Built-ins ────────────────────────────────────────────────────────────

  void _runBuiltin(TerminalBuiltinRequest request, Device target) {
    switch (request.builtin) {
      case TerminalBuiltin.help:
        _printHelp(target);
      case TerminalBuiltin.clear:
        clear();
      case TerminalBuiltin.devices:
        _printDevices(target);
      case TerminalBuiltin.use:
        _useDevice(request.arguments);
      case TerminalBuiltin.tools:
        _printTools(target);
      case TerminalBuiltin.history:
        _printHistory();
    }
  }

  void _printHelp(Device target) {
    final lines = <String>[
      '命令默认发往：${target.displayName}',
      '',
      '怎么用：',
      '  · 输入已知工具名再跟参数（例如 adb devices、ideviceinfo）',
      if (target.platform == DevicePlatform.android)
        '  · 直接输入 shell 内容也可（例如 ls /sdcard、pm list packages）',
      '  · @设备名 命令 — 只把这一行发到另一台设备',
      '',
      '内置命令：',
      for (final builtin in TerminalBuiltin.values)
        '  ${builtin.names.first.padRight(10)} ${builtin.summary}',
      '',
      '快捷键：↑/↓ 历史 · Ctrl+C 停止 · Ctrl+L 清空',
    ];
    for (final line in lines) {
      _push(TerminalLine.notice(line));
    }
    _notify();
  }

  void _printDevices(Device target) {
    final candidates = _candidates;
    if (candidates.isEmpty) {
      _append(const TerminalLine.notice('当前没有已连接的设备。'));
      return;
    }

    final nameWidth = candidates
        .map((candidate) => candidate.displayName.length)
        .reduce((a, b) => a > b ? a : b);
    for (final candidate in candidates) {
      final marker = candidate.id == target.id ? '→' : ' ';
      _push(
        TerminalLine.notice(
          '$marker ${candidate.displayName.padRight(nameWidth)}  '
          '${candidate.id}  ${_platformLabel(candidate.platform)}  '
          '${candidate.statusLabel}',
        ),
      );
    }
    _push(
      const TerminalLine.notice(
        '  （箭头为本标签目标；输入 use 设备名 可切换，use auto 取消固定）',
      ),
    );
    _notify();
  }

  void _useDevice(List<String> arguments) {
    if (arguments.isEmpty) {
      _append(
        TerminalLine.notice(
          '命令目标为 ${targetDevice.displayName}。'
          '输入 use 设备名 可切换，use auto 跟随本标签设备。',
        ),
      );
      return;
    }

    final reference = arguments.join(' ');
    if (reference == 'auto' || reference == '-') {
      _pinnedDevice = null;
      _append(
        TerminalLine.notice('已跟随本标签设备：${device.displayName}。'),
      );
      return;
    }

    final resolved = _resolveDeviceRef(reference);
    if (resolved.device == null) {
      _append(TerminalLine.error(resolved.error!));
      return;
    }
    _pinnedDevice = resolved.device!.id == device.id ? null : resolved.device;
    _append(
      TerminalLine.notice('命令现在发往 ${targetDevice.displayName}。'),
    );
  }

  void _printTools(Device target) {
    final supported = terminalTools
        .where((tool) => tool.supports(target))
        .toList();
    if (supported.isEmpty) {
      _append(const TerminalLine.notice('此处没有可用工具。'));
      return;
    }
    final width = supported
        .map((tool) => tool.executable.length)
        .reduce((a, b) => a > b ? a : b);
    for (final tool in supported) {
      _push(
        TerminalLine.notice(
          '  ${tool.executable.padRight(width)}  ${tool.summary}',
        ),
      );
    }
    if (target.platform == DevicePlatform.android) {
      _push(
        const TerminalLine.notice('其它输入将在设备 shell 中执行。'),
      );
    }
    _notify();
  }

  void _printHistory() {
    if (_history.isEmpty) {
      _append(const TerminalLine.notice('暂无历史记录。'));
      return;
    }
    for (var index = 0; index < _history.length; index++) {
      _push(
        TerminalLine.notice('${'${index + 1}'.padLeft(4)}  ${_history[index]}'),
      );
    }
    _notify();
  }

  // ── Device resolution ────────────────────────────────────────────────────

  List<Device> get _candidates {
    final candidates = [..._availableDevices()];
    if (!candidates.any((candidate) => candidate.id == device.id)) {
      candidates.add(device);
    }
    return candidates;
  }

  static String _platformLabel(DevicePlatform platform) => switch (platform) {
    DevicePlatform.android => 'Android',
    DevicePlatform.ios => 'iOS',
  };

  Device? _lookupById(String id) {
    for (final candidate in _candidates) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  /// Resolves a `@ref` / `use <ref>` reference.
  ({Device? device, String? error}) _resolveDeviceRef(String reference) {
    final needle = reference.toLowerCase();
    final candidates = _candidates;

    final exact = candidates
        .where((candidate) => candidate.id.toLowerCase() == needle)
        .toList();
    if (exact.length == 1) return (device: exact.single, error: null);

    final partial = candidates
        .where(
          (candidate) =>
              candidate.id.toLowerCase().contains(needle) ||
              candidate.displayName.toLowerCase().contains(needle),
        )
        .toList();
    if (partial.length == 1) return (device: partial.single, error: null);
    if (partial.isEmpty) {
      return (
        device: null,
        error:
            '没有匹配「$reference」的设备。运行 `devices` 查看已连接设备。',
      );
    }
    return (
      device: null,
      error:
          '「$reference」匹配到 ${partial.length} 台设备'
          '（${partial.map((candidate) => candidate.id).join(', ')}）。'
          '请使用更长的前缀或完整 id。',
    );
  }

  // ── Scrollback plumbing ──────────────────────────────────────────────────

  void _appendOutput(TerminalOutputChunk chunk) {
    _push(
      TerminalLine(
        chunk.isError ? TerminalLineKind.stderr : TerminalLineKind.stdout,
        chunk.text,
      ),
    );
    _flushTimer ??= Timer(outputFlushInterval, _flush);
  }

  void _push(TerminalLine line) {
    _lines.add(line);
    if (_lines.length > maxScrollbackLines) {
      _lines.removeRange(0, _lines.length - maxScrollbackLines);
    }
  }

  void _append(TerminalLine line) {
    _push(line);
    _notify();
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void onDeviceDisconnected() {
    _append(TerminalLine.notice('${device.displayName} 已断开。'));
  }

  @override
  void onDeviceConnected() {
    _append(TerminalLine.notice('${device.displayName} 已重新连接。'));
  }

  @override
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    final running = _running;
    _running = null;
    if (running != null) unawaited(running.kill());
    super.dispose();
  }
}
