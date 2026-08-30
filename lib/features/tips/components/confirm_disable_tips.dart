import 'package:flutter/material.dart';

/// Confirmation guard before tips are turned off for good. Returns true only
/// when the user explicitly confirms.
Future<bool> confirmDisableTips(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('关闭提示？'),
      content: const Text(
        '您将不再在标题栏看到功能提示。'
        '可随时在设置中重新开启。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
