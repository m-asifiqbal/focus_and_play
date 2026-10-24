// The app's confirm dialog: a floating card in the same style as every other card
// (rounded, solid ledge underneath), a mascot or icon badge on top, a big friendly
// title, and full-width buttons — the safe choice is the big filled one.
//
// Why one widget: Exit, Leave level, Use a hint, Restore and Reset all ask the same
// kind of question; they should look and behave alike (pop-in, back button, text
// scale, screen reader) instead of five default Material AlertDialogs.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mi_colors.dart';
import 'mi_art.dart';
import 'mi_buttons.dart';

/// Colour family of the badge and the main button.
enum MiDialogTone { brand, sun, danger }

/// Asks a yes/no question. Returns true for [confirmLabel], false for [cancelLabel]
/// or when dismissed (back button, tap outside).
///
/// [confirmIsPrimary] says which answer gets the big filled button: true when
/// confirming is the normal thing to do ("Restore"), false when it's the risky
/// one ("Leave", "Reset") so the safe answer is the one under the thumb.
Future<bool> showMiConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  IconData? icon,
  bool pip = false,
  MiDialogTone tone = MiDialogTone.brand,
  bool confirmIsPrimary = true,
  bool dismissible = true,
}) async {
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Dismiss',
    barrierColor: context.mi.scrim,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, _) => MiDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      pip: pip,
      tone: tone,
      confirmIsPrimary: confirmIsPrimary,
      onConfirm: () => Navigator.pop(ctx, true),
      onCancel: () => Navigator.pop(ctx, false),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: .88, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return r ?? false;
}

class MiDialog extends StatelessWidget {
  const MiDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
    this.icon,
    this.pip = false,
    this.tone = MiDialogTone.brand,
    this.confirmIsPrimary = true,
  });

  final String title, message, confirmLabel, cancelLabel;
  final VoidCallback onConfirm, onCancel;
  final IconData? icon;

  /// Show Pip the puffin instead of an icon badge (friendly moments, like leaving the app).
  final bool pip;
  final MiDialogTone tone;
  final bool confirmIsPrimary;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final (tint, ink) = switch (tone) {
      MiDialogTone.brand => (c.brandTint, c.brandInk),
      MiDialogTone.sun => (c.sunTint, c.sunInk),
      MiDialogTone.danger => (c.heartTint, c.danger),
    };

    final primaryLabel = confirmIsPrimary ? confirmLabel : cancelLabel;
    final primaryTap = confirmIsPrimary ? onConfirm : onCancel;
    final secondaryLabel = confirmIsPrimary ? cancelLabel : confirmLabel;
    final secondaryTap = confirmIsPrimary ? onCancel : onConfirm;
    // The secondary answer is red only when it is the risky one.
    final secondaryColor = confirmIsPrimary ? c.inkSoft : c.danger;

    final MiButton primary = tone == MiDialogTone.sun && confirmIsPrimary
        ? MiButton.sun(label: primaryLabel, onTap: primaryTap)
        : MiButton(label: primaryLabel, onTap: primaryTap);

    final badge = pip
        ? const Pip(size: 88)
        : Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(
              icon ?? Icons.help_outline_rounded,
              size: 36,
              color: ink,
            ),
          );

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: c.ledge, offset: const Offset(0, 6)),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: ExcludeSemantics(child: badge)),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: MiText.title.copyWith(
                            fontSize: 25,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: MiText.body.copyWith(
                            color: c.inkSoft,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        primary,
                        const SizedBox(height: 2),
                        MiTextButton(
                          label: secondaryLabel,
                          color: secondaryColor,
                          onTap: secondaryTap,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
