// The "ledge" press: a solid shadow under the control that disappears while the
// finger is down, so the control sinks by exactly the ledge height. Nothing
// around it moves. Borrowed from the Kids Learning App's interaction style.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/feedback.dart';

class MiPressable extends ConsumerStatefulWidget {
  const MiPressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    this.ledge,
    this.radius = 18,
    this.ledgeHeight = 4,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    this.border,
    this.height,
    this.width,
    this.selected,
    this.sound = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;

  /// Colour of the solid ledge; null = no ledge (flat).
  final Color? ledge;
  final double radius;
  final double ledgeHeight;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final BoxBorder? border;
  final double? height;
  final double? width;
  final bool? selected;
  final bool sound;

  @override
  ConsumerState<MiPressable> createState() => _MiPressableState();
}

class _MiPressableState extends ConsumerState<MiPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final instant = MediaQuery.disableAnimationsOf(context);
    final ledgeH = widget.ledge == null ? 0.0 : widget.ledgeHeight;
    final pressed = _down && enabled;
    final body = AnimatedContainer(
      duration: instant ? Duration.zero : const Duration(milliseconds: 70),
      curve: Curves.easeOut,
      height: widget.height,
      width: widget.width,
      padding: widget.padding,
      transform: Matrix4.translationValues(0, pressed ? ledgeH : 0, 0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: widget.border,
        boxShadow: widget.ledge == null || pressed
            ? const []
            : [BoxShadow(color: widget.ledge!, offset: Offset(0, ledgeH))],
      ),
      child: widget.child,
    );
    final VoidCallback? tap = enabled
        ? () {
            final fb = ref.read(feedbackProvider);
            fb.tick();
            if (widget.sound) fb.play(Sfx.tap, volume: .5);
            widget.onTap!();
          }
        : null;
    // The tap lives on this semantics node (not only on the GestureDetector):
    // excludeSemantics drops the children's actions, and screen readers need a
    // tap action to activate the control.
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: tap,
      excludeSemantics: widget.semanticLabel != null,
      child: Padding(
        padding: EdgeInsets.only(bottom: ledgeH),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: tap,
          child: Opacity(opacity: enabled ? 1 : .5, child: body),
        ),
      ),
    );
  }
}
