import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Centres [child] in the part of the area that is not covered by the bottom
/// inset, and scrolls instead of overflowing when it does not fit.
///
/// The shell draws its floating nav bar over the bottom of every tab
/// (`extendBody`) and reports the bar's height through
/// `MediaQuery.paddingOf(context).bottom`. Centring against the full height
/// would place the message too low, so that inset is excluded.
///
/// When [onRefresh] is set the content can be pulled to refresh, even when it
/// is shorter than the area.
class InsetCenteredScroll extends StatelessWidget {
  const InsetCenteredScroll({super.key, required this.child, this.onRefresh});

  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final scrollView = LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: onRefresh == null
            ? null
            : const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomInset),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - bottomInset),
            ),
            child: Center(child: child),
          ),
        ],
      ),
    );

    final refresh = onRefresh;
    if (refresh == null) return scrollView;
    return RefreshIndicator(onRefresh: refresh, child: scrollView);
  }
}
