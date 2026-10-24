// A scrolling page whose top toolbar stays put: the header sits above the list
// instead of being its first item, so it never scrolls away. A hairline fades in
// under the header once content has scrolled beneath it.
//
// Why one widget: every tab and detail page wants the same behaviour; this is a
// drop-in for `ListView(padding, children)` plus a `header`.

import 'package:flutter/material.dart';

import '../theme/mi_colors.dart';

class PinnedPage extends StatefulWidget {
  const PinnedPage({
    super.key,
    required this.header,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 16),
    this.headerPadding = const EdgeInsets.fromLTRB(20, 8, 20, 10),
    this.background,
  });

  /// The toolbar (title row, back button, period switch…). Stays at the top.
  final Widget header;
  final List<Widget> children;

  /// Padding around the scrolling list.
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry headerPadding;

  /// Behind the header so scrolled content never shows through it (defaults to the
  /// theme's page colour; pass the screen's own ground when it isn't that).
  final Color? background;

  @override
  State<PinnedPage> createState() => _PinnedPageState();
}

class _PinnedPageState extends State<PinnedPage> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      final scrolled = n.metrics.pixels > 1;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final instant = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: instant ? Duration.zero : const Duration(milliseconds: 150),
          padding: widget.headerPadding,
          decoration: BoxDecoration(
            color:
                widget.background ?? Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: _scrolled ? c.line : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: widget.header,
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView(padding: widget.padding, children: widget.children),
          ),
        ),
      ],
    );
  }
}
