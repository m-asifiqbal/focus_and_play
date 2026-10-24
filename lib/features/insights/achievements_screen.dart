// Achievement gallery: earned badges first (newest has a NEW tag), then the rest
// with a progress bar. Filter chips per island and for streaks.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../domain/achievements.dart';
import '../../domain/game_id.dart';
import '../../state/save_controller.dart';
import '../results/achievement_dialog.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});
  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  String _filter = 'All';

  bool _match(AchievementState a) => switch (_filter) {
        'All' => true,
        'Streaks' => a.def.kind == BadgeKind.streak || a.def.kind == BadgeKind.sun,
        _ => a.def.game?.title == _filter,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final save = ref.watch(saveProvider);
    final all = Achievements.states(save);
    final newest = all.where((a) => a.unlocked).fold<AchievementState?>(null, (m, a) => m == null || a.unlockedAt! > m.unlockedAt! ? a : m);
    final list = all.where(_match).toList()..sort((a, b) => (b.unlocked ? 1 : 0).compareTo(a.unlocked ? 1 : 0));
    final instant = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              MiIconButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: () => context.pop()),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Achievements', style: MiText.title.copyWith(fontSize: 24, color: c.ink)),
                  Text('${all.where((a) => a.unlocked).length} of ${all.length} unlocked', style: MiText.caption.copyWith(color: c.inkSoft, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              for (final f in ['All', ...GameId.values.map((g) => g.title), 'Streaks'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    labelStyle: MiText.small.copyWith(color: _filter == f ? Colors.white : c.ink, fontWeight: FontWeight.w800),
                    selectedColor: c.isNight ? c.brand : c.navy,
                    backgroundColor: c.card,
                    showCheckmark: false,
                    shape: StadiumBorder(side: BorderSide(color: _filter == f ? Colors.transparent : c.line, width: 1.5)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .72),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final a = list[i];
                final card = _AchievementCard(state: a, isNew: a == newest && DateTime.now().millisecondsSinceEpoch - (a.unlockedAt ?? 0) < 3 * 86400000);
                return instant ? card : card.animate().fadeIn(delay: (30 * i).ms).scaleXY(begin: .85, curve: Curves.easeOutBack);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.state, required this.isNew});
  final AchievementState state;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final d = state.def;
    return Semantics(
      button: state.unlocked,
      label: '${d.title}. ${d.description} ${state.unlocked ? 'Unlocked.' : '${state.current} of ${d.target}.'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: state.unlocked ? () => showAchievement(context, d) : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(20)),
          child: Stack(clipBehavior: Clip.none, children: [
            Column(children: [
              HexBadge(kind: d.kind, unlocked: state.unlocked, size: 50),
              const SizedBox(height: 6),
              Text(d.title, textAlign: TextAlign.center, maxLines: 2, style: MiText.small.copyWith(color: c.ink, fontWeight: FontWeight.w800, height: 1.15)),
              const Spacer(),
              if (state.unlocked)
                Text(DateFormat('d MMM').format(DateTime.fromMillisecondsSinceEpoch(state.unlockedAt!)), style: MiText.caption.copyWith(fontSize: 12, color: c.inkSoft))
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: state.fraction, minHeight: 6, color: c.inkSoft, backgroundColor: c.sunk),
                ),
                const SizedBox(height: 4),
                Text('${state.current} of ${d.target}', style: MiText.caption.copyWith(fontSize: 12, color: c.inkSoft)),
              ],
            ]),
            if (isNew)
              Positioned(
                top: -6,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: c.sun, borderRadius: BorderRadius.circular(8)),
                  child: Text('NEW', style: MiText.caption.copyWith(fontSize: 11, color: const Color(0xFF13213C), fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
