// An island: the scrolling map with a glass header (lives, hints, tier progress),
// a floating "Play level N" button and the banner ad strip at the bottom.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../domain/game_id.dart';
import '../../domain/tier.dart';
import '../../state/save_controller.dart';
import 'level_start_sheet.dart';
import 'map/island_map_view.dart';
import 'map/island_palette.dart';

class IslandScreen extends ConsumerWidget {
  const IslandScreen({super.key, required this.game});
  final GameId game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final st = context.island(game);
    final prog = ref.watch(saveProvider.select((s) => s.progress(game)));
    final badge = ref.watch(saveProvider.select((s) => s.profile.badge));
    final current = prog.current;
    final tier = Levels.tierOf(current);
    final inTier = prog.levels.keys.where((l) => Levels.tierOf(l) == tier).length;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final completed = prog.completed;

    return Scaffold(
      backgroundColor: c.isNight ? IslandPalette.seaNight : IslandPalette.sea,
      body: Stack(children: [
        Positioned.fill(
          child: IslandMapView(
            game: game,
            progress: prog,
            night: c.isNight,
            badge: badge,
            topInset: MediaQuery.paddingOf(context).top + 110,
            bottomInset: 150 + bottomPad,
            onLevel: (l) => showLevelStart(context, ref, game, l),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: MediaQuery.paddingOf(context).top + 6,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(
              color: (c.isNight ? const Color(0xFF16223A) : Colors.white).withValues(alpha: .95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Column(children: [
              Row(children: [
                MiIconButton(icon: Icons.arrow_back_rounded, label: 'Back', background: c.isNight ? c.sunk : c.page, onTap: () => context.pop()),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(game.island, style: MiText.title.copyWith(fontSize: 20, color: c.ink)),
                    Text(game.title, style: MiText.caption.copyWith(color: st.ink, fontWeight: FontWeight.w800)),
                  ]),
                ),
                EconomyPills(background: c.isNight ? c.sunk : c.page),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const SizedBox(width: 4),
                Text(tier.label, style: MiText.headline.copyWith(fontSize: 15, color: c.ink)),
                const SizedBox(width: 6),
                TierPips(tier: tier, color: st.color),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: (inTier / Levels.perTier).clamp(0.02, 1.0), minHeight: 8, backgroundColor: st.tint, color: st.color),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$inTier of ${Levels.perTier}', style: MiText.caption.copyWith(color: c.inkSoft, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                const StarShape(filled: true, size: 15),
                const SizedBox(width: 3),
                Text('${prog.stars}', style: MiText.headline.copyWith(fontSize: 15, color: c.ink)),
              ]),
            ]),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: SizedBox(
                width: 270,
                child: MiButton(
                  label: completed ? 'Island complete!' : 'Play level $current',
                  icon: completed ? Icons.emoji_events_rounded : Icons.play_arrow_rounded,
                  color: st.color,
                  ledge: st.ledge,
                  onColor: st.onColor,
                  height: 58,
                  onTap: () => showLevelStart(context, ref, game, current),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              color: c.card,
              padding: EdgeInsets.only(top: 8, bottom: 8 + bottomPad),
              child: const Center(child: BannerAdSlot()),
            ),
          ]),
        ),
      ]),
    );
  }
}
