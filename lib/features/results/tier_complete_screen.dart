// Tier cleared: a flag plants on the island, the next tier opens and the
// chest pays out hints.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../domain/tier.dart';
import '../../state/save_controller.dart';
import '../home/widgets/mini_island.dart';
import '../island/map/island_palette.dart';
import 'result_flow.dart';
import '../../core/constants/plural.dart';

class TierCompleteScreen extends ConsumerWidget {
  const TierCompleteScreen({super.key, required this.outcome});
  final LevelOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mi;
    final g = outcome.spec.game;
    final st = context.island(g);
    final done = outcome.tierCleared ?? outcome.spec.tier;
    final next = Tier.values[(done.index + 1).clamp(0, 3)];
    final zone = IslandPalette.of(g).zones[next.index].name;
    final instant = MediaQuery.disableAnimationsOf(context);
    Widget rise(Widget w, int i) => instant ? w : w.animate().fadeIn(delay: (300 + i * 120).ms).slideY(begin: .2);
    return Scaffold(
      backgroundColor: c.isNight ? c.page : st.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 260,
              child: Stack(children: [
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(32), child: MiniIsland(game: g, night: c.isNight, height: 260))),
                Positioned(
                  right: 40,
                  top: 30,
                  child: instant ? _flag(next, st) : _flag(next, st).animate().slideY(begin: -1.4, duration: 700.ms, curve: Curves.bounceOut).fadeIn(),
                ),
                const Positioned.fill(child: Confetti(count: 24, loop: false)),
              ]),
            ),
            const SizedBox(height: 18),
            rise(Text('${g.island.toUpperCase()} · ${g.title.toUpperCase()}', style: MiText.overline.copyWith(color: st.ink)), 0),
            rise(Text('${done.label} cleared!', style: MiText.hero.copyWith(color: c.ink)), 1),
            const SizedBox(height: 6),
            rise(Text('${next.label} levels are open in the $zone. The puzzles get bigger — you\'re ready.', style: MiText.body.copyWith(color: c.inkSoft, fontSize: 17)), 2),
            const SizedBox(height: 16),
            rise(
              Row(children: [
                for (final t in Tier.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(children: [
                        Container(height: 8, decoration: BoxDecoration(color: t.index <= done.index ? st.color : (t == next ? c.card : c.line), borderRadius: BorderRadius.circular(4), border: t == next ? Border.all(color: st.color, width: 2) : null)),
                        const SizedBox(height: 4),
                        Text(t == next ? '${t.label} · open' : t.label, style: MiText.caption.copyWith(color: t == next ? st.ink : c.inkSoft, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
              ]),
              3,
            ),
            const SizedBox(height: 16),
            if (outcome.chestHints > 0)
              rise(
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: st.cardLedge, offset: const Offset(0, 3))]),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_rounded, size: 36, color: Color(0xFFB7791F)),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Tier chest', style: MiText.headline.copyWith(color: c.ink))),
                    const Icon(Icons.lightbulb_rounded, color: Color(0xFFE0A100)),
                    const SizedBox(width: 4),
                    Text('+${plural(outcome.chestHints, 'hint')}', style: MiText.headline.copyWith(color: c.ink)),
                  ]),
                ),
                4,
              ),
            const Spacer(),
            MiButton(label: 'Climb to ${next.label}', trailingIcon: Icons.arrow_forward_rounded, color: st.color, ledge: st.ledge, onColor: st.onColor, height: 60, onTap: () => goToNextLevel(context, ref, outcome.spec)),
          ]),
        ),
      ),
    );
  }

  Widget _flag(Tier t, IslandStyle st) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: st.color, borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10))),
          child: Text(t.label.toUpperCase(), style: MiText.overline.copyWith(color: st.onColor)),
        ),
        Container(width: 4, height: 70, color: const Color(0xFF13213C)),
      ]);
}
