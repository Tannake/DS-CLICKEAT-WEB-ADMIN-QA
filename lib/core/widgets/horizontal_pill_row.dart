import 'package:flutter/material.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';

/// Lays out [children] (typically filter pills) in a single horizontal row
/// that scrolls instead of wrapping onto new lines when they don't fit the
/// available width — keeps every pill at the same visual "level". Shows an
/// always-visible scrollbar so the extra pills are discoverable instead of
/// hiding behind a plain, hint-less scroll view.
class HorizontalPillRow extends StatefulWidget {
  final List<Widget> children;
  final double spacing;

  const HorizontalPillRow({
    super.key,
    required this.children,
    this.spacing = 7,
  });

  @override
  State<HorizontalPillRow> createState() => _HorizontalPillRowState();
}

class _HorizontalPillRowState extends State<HorizontalPillRow> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      radius: const Radius.circular(99),
      thickness: 6,
      thumbColor: AppColors.ink4,
      trackColor: AppColors.line,
      trackBorderColor: AppColors.line,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            for (var i = 0; i < widget.children.length; i++) ...[
              if (i > 0) SizedBox(width: widget.spacing),
              widget.children[i],
            ],
          ],
        ),
      ),
    );
  }
}
