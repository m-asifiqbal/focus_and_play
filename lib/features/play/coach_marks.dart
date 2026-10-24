// Three quick tips on the very first level: lives, the clock, hints. A spotlight
// glides over each part of the HUD while Pip explains it.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';

class CoachTip {
  const CoachTip(this.target, this.title, this.body);
  final GlobalKey target;
  final String title;
  final String body;
}

class CoachMarks extends StatefulWidget {
  const CoachMarks({super.key, required this.tips, required this.onDone});
  final List<CoachTip> tips;
  final VoidCallback onDone;
  @override
  State<CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends State<CoachMarks> {
  int _step = 0;

  Rect? _rectOf(GlobalKey k) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || me == null || !box.hasSize) return null;
    final tl = box.localToGlobal(Offset.zero, ancestor: me);
    return (tl & box.size).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final tip = widget.tips[_step];
    final instant = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, box) {
      final r = _rectOf(tip.target) ?? Rect.fromLTWH(20, 120, box.maxWidth - 40, 60);
      final below = r.center.dy < box.maxHeight / 2;
      final last = _step == widget.tips.length - 1;
      return Stack(children: [
        AnimatedPositioned(
          duration: instant ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          left: r.left,
          top: r.top,
          width: r.width,
          height: r.height,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFC233), width: 3),
                boxShadow: [BoxShadow(color: c.scrim, spreadRadius: 2000)],
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: instant ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          left: 16,
          right: 16,
          top: below ? r.bottom + 16 : null,
          bottom: below ? null : box.maxHeight - r.top + 16,
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(24),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Pip(size: 52),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('TIP ${_step + 1} OF ${widget.tips.length}', style: MiText.overline.copyWith(color: c.brandInk)),
                      const SizedBox(height: 2),
                      Text(tip.title, style: MiText.headline.copyWith(color: c.ink)),
                      const SizedBox(height: 2),
                      Text(tip.body, style: MiText.label.copyWith(color: c.inkSoft, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  MiTextButton(label: 'Skip tips', color: c.inkSoft, onTap: widget.onDone),
                  const Spacer(),
                  MiButton(
                    label: last ? "Let's play" : 'Next',
                    expand: false,
                    height: 46,
                    fontSize: 17,
                    onTap: () => last ? widget.onDone() : setState(() => _step++),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ]);
    });
  }
}
