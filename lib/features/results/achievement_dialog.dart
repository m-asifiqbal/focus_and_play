// "Achievement unlocked" pop-up: the badge spins in, light sweeps across it.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../domain/achievements.dart';
import '../../core/constants/plural.dart';

Future<void> showAchievement(BuildContext context, AchievementDef def) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xE60E1830),
    builder: (ctx) {
      final instant = MediaQuery.disableAnimationsOf(ctx);
      Widget badge = HexBadge(kind: def.kind, unlocked: true, size: 140);
      if (!instant) {
        badge = badge
            .animate()
            .scale(duration: 800.ms, curve: Curves.elasticOut, begin: const Offset(.2, .2))
            .rotate(begin: -.5, duration: 700.ms, curve: Curves.easeOutBack)
            .then()
            .shimmer(duration: 1400.ms, color: Colors.white.withValues(alpha: .6));
      }
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          badge,
          const SizedBox(height: 18),
          Text('ACHIEVEMENT UNLOCKED', style: MiText.overline.copyWith(color: const Color(0xFFFFC233))),
          const SizedBox(height: 6),
          Text(def.title, textAlign: TextAlign.center, style: MiText.hero.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(def.description, textAlign: TextAlign.center, style: MiText.body.copyWith(color: const Color(0xFFC9D6EA), fontSize: 17)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF1C2C49), borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFC233)),
              const SizedBox(width: 8),
              Text('+${plural(def.rewardHints, 'hint')}', style: MiText.headline.copyWith(color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 20),
          MiButton.sun(label: 'Collect', onTap: () => Navigator.pop(ctx)),
        ]),
      );
    },
  );
}
