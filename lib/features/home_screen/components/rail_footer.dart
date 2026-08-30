import 'package:flutter/material.dart';

/// Bottom-pinned separator under Settings (version string intentionally omitted).
class RailFooter extends StatelessWidget {
  const RailFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: colorScheme.outlineVariant,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
