// Buttons built on MiPressable: filled (brand / island / sun), ghost and round icon.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mi_colors.dart';
import 'pressable.dart';

/// Big filled button with a ledge. Defaults to the brand teal.
class MiButton extends StatelessWidget {
  const MiButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.color,
    this.ledge,
    this.onColor,
    this.height = 56,
    this.expand = true,
    this.fontSize = 19,
  });

  /// Sun-yellow button (hints, rewards) with dark text.
  factory MiButton.sun({
    Key? key,
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    double height = 56,
  }) => MiButton(
    key: key,
    label: label,
    onTap: onTap,
    icon: icon,
    height: height,
    color: const Color(0xFFFFC233),
    ledge: const Color(0xFFDB9A00),
    onColor: const Color(0xFF13213C),
  );

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color? color;
  final Color? ledge;
  final Color? onColor;
  final double height;
  final bool expand;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final fg = onColor ?? c.onBrand;
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: fg, size: fontSize + 3),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MiText.button.copyWith(color: fg, fontSize: fontSize),
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, color: fg, size: fontSize + 3),
        ],
      ],
    );
    return MiPressable(
      onTap: onTap,
      color: color ?? c.brand,
      ledge: ledge ?? c.brandLedge,
      radius: height >= 56 ? 18 : 16,
      ledgeHeight: 5,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      semanticLabel: label,
      child: Center(child: row),
    );
  }
}

/// Outlined button for secondary actions.
class MiGhostButton extends StatelessWidget {
  const MiGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.height = 50,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final fg = color ?? c.ink;
    return MiPressable(
      onTap: onTap,
      color: Colors.transparent,
      height: height,
      radius: 16,
      border: Border.all(color: fg.withValues(alpha: .35), width: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      semanticLabel: label,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MiText.label.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain text action (≥ 44 pt tall).
class MiTextButton extends StatelessWidget {
  const MiTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.mi.brandInk;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: MiText.label.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 44×44 round icon button (back, close, pause…). Always has a semantics label.
class MiIconButton extends StatelessWidget {
  const MiIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.background,
    this.color,
    this.size = 44,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final Color? background;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    return MiPressable(
      onTap: onTap,
      color: background ?? c.card,
      radius: size / 2,
      width: size,
      height: size,
      semanticLabel: label,
      child: Icon(icon, color: color ?? c.ink, size: size * .5),
    );
  }
}
