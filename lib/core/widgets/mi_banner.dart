// A one-to-two line message card under a board: why a move did nothing or was
// wrong (danger), or a gentle nudge (info). Dismissible when [onDismiss] is given.
//
// Why shared: Quilt ("this patch must be a wide rectangle") and Bridges ("a bridge
// can't cross another one") say the same kind of thing in the same place, so they
// look and read the same, and a screen reader announces both as a live region
// while keeping the ✕ button reachable.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mi_colors.dart';
import 'mi_buttons.dart';

enum MiBannerTone { danger, info }

class MiBanner extends StatelessWidget {
  const MiBanner({
    super.key,
    required this.text,
    this.tone = MiBannerTone.danger,
    this.onDismiss,
  });
  final String text;
  final MiBannerTone tone;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    final accent = tone == MiBannerTone.danger ? mi.danger : mi.brandInk;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsetsDirectional.only(
          start: 12,
          end: onDismiss == null ? 12 : 0,
        ),
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withValues(alpha: .12), mi.card),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: .6), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MiText.small.copyWith(color: mi.ink, height: 1.25),
              ),
            ),
            if (onDismiss != null)
              MiIconButton(
                icon: Icons.close_rounded,
                label: 'Dismiss message',
                background: Colors.transparent,
                onTap: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
