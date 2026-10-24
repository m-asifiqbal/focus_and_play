// Small shared controls: card, switch, segmented control, pills, tier pips,
// section label and the floating bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tier.dart';
import '../../state/save_controller.dart';
import '../feedback/feedback.dart';
import '../theme/app_theme.dart';
import '../theme/mi_colors.dart';
import 'pressable.dart';
import '../constants/plural.dart';

/// White (or night) card with a solid ledge; tappable when [onTap] is set.
class MiCard extends StatelessWidget {
  const MiCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.ledge,
    this.radius = 22,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? ledge;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    if (onTap != null) {
      return MiPressable(
        onTap: onTap,
        color: color ?? c.card,
        ledge: ledge ?? c.ledge,
        ledgeHeight: 3,
        radius: radius,
        padding: padding,
        semanticLabel: semanticLabel,
        child: child,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: ledge == null
            ? null
            : [BoxShadow(color: ledge!, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }
}

/// Animated on/off switch (52×32) with a real switch role.
class MiSwitch extends ConsumerWidget {
  const MiSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final instant = MediaQuery.disableAnimationsOf(context);
    void toggle() {
      ref.read(feedbackProvider).tick();
      onChanged(!value);
    }

    return Semantics(
      toggled: value,
      label: label,
      onTap: toggle,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: toggle,
        child: Container(
          width: 52,
          height: 44,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: instant
                ? Duration.zero
                : const Duration(milliseconds: 200),
            width: 52,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? c.brand : const Color(0xFF7A8AA3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedAlign(
              duration: instant
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped segmented control.
class MiSegmented<T> extends StatelessWidget {
  const MiSegmented({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.iconOf,
    this.expand = false,
    this.height = 40,
  });
  final List<T> values;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final instant = MediaQuery.disableAnimationsOf(context);
    final items = [
      for (final v in values)
        Expanded(
          flex: expand ? 1 : 0,
          child: Semantics(
            selected: v == selected,
            button: true,
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: instant
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == selected
                      ? (c.isNight ? c.card : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(height / 2 - 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconOf != null) ...[
                      Icon(
                        iconOf!(v),
                        size: 18,
                        color: v == selected ? c.ink : c.inkSoft,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      labelOf(v),
                      style: MiText.small.copyWith(
                        color: v == selected ? c.ink : c.inkSoft,
                        fontWeight: v == selected
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.isNight ? c.sunk : const Color(0xFFDCE6F0),
        borderRadius: BorderRadius.circular(height / 2 + 1),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: expand ? items : [for (final i in items) (i).child],
      ),
    );
  }
}

/// Small rounded counter pill (lives, hints, stars).
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.semantics,
    this.background,
  });
  final IconData icon;
  final Color iconColor;
  final String text;
  final String semantics;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: background ?? c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 5),
            Text(
              text,
              style: MiText.headline.copyWith(fontSize: 16, color: c.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live lives + hints pills (refills tick every second).
class EconomyPills extends ConsumerWidget {
  const EconomyPills({super.key, this.background});
  final Color? background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(economyProvider);
    final c = context.mi;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatPill(
          icon: Icons.favorite_rounded,
          iconColor: c.heart,
          text: '${e.lives}',
          semantics: '${e.lives} of 3 lives',
          background: background,
        ),
        const SizedBox(width: 6),
        StatPill(
          icon: Icons.lightbulb_rounded,
          iconColor: const Color(0xFFE0A100),
          text: '${e.hints}',
          semantics: plural(e.hints, 'hint'),
          background: background,
        ),
      ],
    );
  }
}

/// 1–4 pips that show a tier's difficulty.
class TierPips extends StatelessWidget {
  const TierPips({
    super.key,
    required this.tier,
    required this.color,
    this.off,
  });
  final Tier tier;
  final Color color;
  final Color? off;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 5,
            height: 11,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i < tier.pips ? color : (off ?? context.mi.line),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}

/// Upper-case section label (Settings groups, overlines).
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.color,
    this.padding = const EdgeInsets.fromLTRB(12, 18, 12, 8),
  });
  final String text;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(
      text.toUpperCase(),
      style: MiText.overline.copyWith(color: color ?? context.mi.inkSoft),
    ),
  );
}

/// Shows [child] in a floating sheet: 12 pt from the sides, all corners rounded.
Future<T?> showMiSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.mi.scrim,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: ctx.mi.card,
          borderRadius: BorderRadius.circular(32),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: ctx.mi.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(child: builder(ctx)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
