import 'package:flutter/material.dart';

/// Lays out [children] (typically filter pills) in a single horizontal row
/// that scrolls instead of wrapping onto new lines when they don't fit the
/// available width — keeps every pill at the same visual "level".
class HorizontalPillRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const HorizontalPillRow({
    super.key,
    required this.children,
    this.spacing = 7,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}
