import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/device.dart';
import '../../../presentation/theme/app_theme.dart';
import '../terminal_controller.dart';

/// The prompt: the target-device label, the command editor, and the run/stop
/// button.
class TerminalInputBar extends StatefulWidget {
  const TerminalInputBar({
    super.key,
    required this.controller,
    required this.fontSize,
  });

  final TerminalController controller;
  final double fontSize;

  @override
  State<TerminalInputBar> createState() => _TerminalInputBarState();
}

class _TerminalInputBarState extends State<TerminalInputBar> {
  static const int _minLines = 3;
  static const int _maxLines = 10;

  final TextEditingController _input = TextEditingController();
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKeyEvent);

  TerminalController get controller => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;

    if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (!controller.isRunning) return KeyEventResult.ignored;
      unawaited(controller.cancel());
      return KeyEventResult.handled;
    }
    if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyL) {
      controller.clear();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      _submit();
      return KeyEventResult.handled;
    }
    if (!_input.text.contains('\n')) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        return _applyHistory(controller.historyPrevious());
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        return _applyHistory(controller.historyNext());
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _applyHistory(String? entry) {
    if (entry == null) return KeyEventResult.ignored;
    _input.value = TextEditingValue(
      text: entry,
      selection: TextSelection.collapsed(offset: entry.length),
    );
    return KeyEventResult.handled;
  }

  void _submit() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    unawaited(controller.submit(text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eaglyTheme = context.eaglyTheme;
    final target = controller.targetDevice;
    final isRunning = controller.isRunning;

    final mono = eaglyTheme.logBodyStyle.copyWith(
      fontSize: widget.fontSize,
      height: 1.45,
      color: theme.colorScheme.onSurface,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: _PromptLabel(
              device: target,
              isPinned: controller.isPinnedElsewhere,
              isRunning: isRunning,
              style: mono,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focusNode,
                  autofocus: true,
                  minLines: _minLines,
                  maxLines: _maxLines,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _submit(),
                  style: mono,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: isRunning
                        ? '正在运行 — Ctrl+C 停止'
                        : target.isConnected
                        ? '输入命令… · help 查看帮助\n回车运行 · Shift+回车换行'
                        : '${target.displayName} 已断开',
                    hintMaxLines: 2,
                    hintStyle: mono.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (isRunning)
                IconButton(
                  tooltip: '停止（Ctrl+C）',
                  onPressed: () => unawaited(controller.cancel()),
                  icon: Icon(
                    Icons.stop_circle_outlined,
                    color: eaglyTheme.errorColor,
                  ),
                )
              else
                IconButton(
                  tooltip: '运行（Enter）',
                  onPressed: _submit,
                  icon: const Icon(Icons.keyboard_return),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptLabel extends StatelessWidget {
  const _PromptLabel({
    required this.device,
    required this.isPinned,
    required this.isRunning,
    required this.style,
  });

  final Device device;
  final bool isPinned;
  final bool isRunning;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = device.isConnected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: isPinned
          ? '已固定到 ${device.displayName} — 输入 use auto 可恢复跟随本标签设备'
          : '${device.displayName} (${device.id})',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPinned) ...[
            Icon(Icons.push_pin_outlined, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            device.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            isRunning ? '»' : r'$',
            style: style.copyWith(
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
