import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps a flex-column table (a `Column` built from a header `Row` and row
/// `Row`s using `Expanded(flex: ...)` cells) so it scrolls horizontally
/// instead of crushing its columns when the viewport is narrower than the
/// table's natural minimum width.
///
/// The inner [child] keeps its existing `Expanded`/flex column code
/// unchanged: giving it a bounded width of `max(minWidth, available)` means
/// on wide screens it renders exactly as before (`width == available`), and
/// on narrow screens columns render at a legible floor width and the table
/// scrolls sideways instead.
class ScrollableTable extends StatelessWidget {
  final double minWidth;
  final Widget child;

  const ScrollableTable({
    super.key,
    required this.minWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(minWidth, constraints.maxWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
