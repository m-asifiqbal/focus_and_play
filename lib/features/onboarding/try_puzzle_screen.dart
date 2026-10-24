// Onboarding step 2: learn by doing. A tiny 4×4 Thread the player solves with
// their own finger; Pip cheers and confetti falls when it's done.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback/feedback.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../domain/game_id.dart';
import '../../games/thread/thread.dart';
import '../boards/thread_board.dart';
import 'onboarding_screens.dart';

/// The warm-up puzzle: one path through all 16 squares, 1 → 4.
ThreadPuzzle warmUpPuzzle() => ThreadPuzzle(
      size: 4,
      numbers: const {0: 1, 4: 2, 13: 3, 11: 4},
      solution: const [0, 1, 2, 3, 7, 6, 5, 4, 8, 12, 13, 9, 10, 14, 15, 11],
    );

class TryPuzzleScreen extends ConsumerStatefulWidget {
  const TryPuzzleScreen({super.key});
  @override
  ConsumerState<TryPuzzleScreen> createState() => _TryPuzzleScreenState();
}

class _TryPuzzleScreenState extends ConsumerState<TryPuzzleScreen> {
  late final ThreadController _c = ThreadController(warmUpPuzzle())..addListener(_changed);
  bool _solved = false;

  void _changed() {
    if (!_solved && _c.solved) {
      setState(() => _solved = true);
      ref.read(feedbackProvider)
        ..play(Sfx.solve)
        ..celebrate();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final st = context.island(GameId.thread);
    return Scaffold(
      backgroundColor: c.isNight ? c.page : st.page,
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(height: 44, child: Row(children: [const StepDots(2), const Spacer(), MiTextButton(label: 'Skip', onTap: () => context.push(Routes.pickIsland))])),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Pip(size: 64),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      key: ValueKey(_solved),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomRight: Radius.circular(20), bottomLeft: Radius.circular(6)),
                        boxShadow: [BoxShadow(color: st.cardLedge, offset: const Offset(0, 3))],
                      ),
                      child: Text(
                        _solved ? "You're a natural! That's Thread: one path, numbers in order, every square filled." : 'Draw one thread from 1 to 4. Pass 2 and 3 on the way and fill every square.',
                        style: MiText.label.copyWith(color: c.ink, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              Expanded(child: Center(child: SingleChildScrollView(child: ThreadBoard(controller: _c)))),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_c.progressText, style: MiText.small.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
                if (!_solved && _c.path.isNotEmpty) ...[const SizedBox(width: 8), MiTextButton(label: 'Start over', color: st.ink, onTap: _c.reset)],
              ]),
              Text('Drag your finger across the squares — or tap them one by one.', textAlign: TextAlign.center, style: MiText.small.copyWith(color: c.inkSoft)),
              const SizedBox(height: 14),
              _solved
                  ? MiButton(label: 'Next', trailingIcon: Icons.arrow_forward_rounded, onTap: () => context.push(Routes.pickIsland)).animate().scale(duration: 400.ms, curve: Curves.easeOutBack)
                  : Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.isNight ? c.sunk : const Color(0xFFF0E5DF), borderRadius: BorderRadius.circular(18)),
                      child: Text('Solve it to continue', style: MiText.button.copyWith(color: c.inkSoft, fontSize: 18)),
                    ),
            ]),
          ),
        ),
        if (_solved) const Positioned.fill(child: Confetti(count: 50, loop: false)),
      ]),
    );
  }
}
