// The tab pages (Home, Insights, Settings) side by side: switching tabs slides
// the new page in from the right (a tab further right) or the left, while the
// old page slides out the other way.
//
// Why a custom container: go_router's IndexedStack keeps each tab's state but
// cannot animate. This keeps the same guarantees — every tab stays mounted,
// hidden tabs are offstage with their tickers off — and adds the slide. Each
// child keeps the same widget structure in every state, so nothing remounts.

import 'package:flutter/material.dart';

class SlidingBranches extends StatefulWidget {
  const SlidingBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;

  /// One Navigator per tab, in tab order.
  final List<Widget> children;

  @override
  State<SlidingBranches> createState() => _SlidingBranchesState();
}

class _SlidingBranchesState extends State<SlidingBranches>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
        value: 1,
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _from = null);
        }
      });
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  /// The tab sliding out, while the slide runs.
  int? _from;

  @override
  void didUpdateWidget(SlidingBranches old) {
    super.didUpdateWidget(old);
    if (old.currentIndex == widget.currentIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _from = null;
      _c.value = 1;
      return;
    }
    _from = old.currentIndex;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final to = widget.currentIndex;
    final from = _from;
    // +1: the new tab is to the right, so it comes in from the right edge.
    final dir = from == null ? 0.0 : (to > from ? 1.0 : -1.0);
    // Mirror the motion for right-to-left layouts.
    final rtl = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            _branch(i, active: i == to, leaving: i == from, dx: dir * rtl),
        ],
      ),
    );
  }

  Widget _branch(
    int i, {
    required bool active,
    required bool leaving,
    required double dx,
  }) {
    final visible = active || leaving;
    final Animation<Offset> position;
    if (active && dx != 0) {
      position = Tween(begin: Offset(dx, 0), end: Offset.zero).animate(_t);
    } else if (leaving) {
      position = Tween(begin: Offset.zero, end: Offset(-dx, 0)).animate(_t);
    } else {
      position = const AlwaysStoppedAnimation(Offset.zero);
    }
    return KeyedSubtree(
      key: ValueKey(i),
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: IgnorePointer(
            ignoring: leaving,
            child: SlideTransition(
              position: position,
              child: widget.children[i],
            ),
          ),
        ),
      ),
    );
  }
}
