// Sleuth: find the secret word on the list. Tap a word, press Guess, and read the
// tiles — green: right letter in the right place, yellow: right letter somewhere
// else, grey: not in the word. Rule words out until one is left.
//
// Tiles flip one after another when a guess is revealed. On the easy tiers the list
// crosses out words the feedback has ruled out; on harder tiers the player crosses
// them out by hand (long-press).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../domain/game_id.dart';
import '../../games/sleuth/sleuth.dart';
import '../../state/save_controller.dart';
import '../play/play_hud.dart' show ActionKey;
import 'sleuth_controller.dart';

export 'sleuth_controller.dart';

/// Fill and text colour of a revealed tile. Dark text on the bright tiles keeps
/// them readable (white on this green is too faint).
(Color, Color) sleuthMarkColors(MiColors mi, SleuthMark m) => switch (m) {
  SleuthMark.correct => (const Color(0xFF3DCB7B), const Color(0xFF0D1626)),
  SleuthMark.present => (const Color(0xFFFFC233), const Color(0xFF13213C)),
  SleuthMark.absent =>
    mi.isNight
        ? (const Color(0xFF3A4A68), mi.ink)
        : (const Color(0xFFD5DBE4), mi.ink),
};

String _markWord(SleuthMark m) => switch (m) {
  SleuthMark.correct => 'right place',
  SleuthMark.present => 'wrong place',
  SleuthMark.absent => 'not in the word',
};

class SleuthBoard extends ConsumerStatefulWidget {
  const SleuthBoard({
    super.key,
    required this.controller,
    required this.hintsLeft,
  });
  final SleuthController controller;
  final int hintsLeft;
  @override
  ConsumerState<SleuthBoard> createState() => _SleuthBoardState();
}

class _SleuthBoardState extends ConsumerState<SleuthBoard>
    with SingleTickerProviderStateMixin {
  /// 0 → 1 over a reveal: tile k flips during its own slice of the time.
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  int _seen = 0;
  SleuthController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _seen = c.guessCount;
    c.addListener(_onChange);
  }

  @override
  void didUpdateWidget(SleuthBoard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
      _seen = c.guessCount;
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _flip.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (c.guessCount > _seen) {
      MediaQuery.disableAnimationsOf(context)
          ? _flip.value = 1
          : _flip.forward(from: 0);
    }
    _seen = c.guessCount;
  }

  void _submit() {
    final marks = c.submit();
    if (marks == null) return;
    final fb = ref.read(feedbackProvider);
    if (marks.every((m) => m == SleuthMark.correct)) {
      fb.bump();
    } else {
      fb
        ..tick()
        ..play(Sfx.place, volume: .6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    final st = context.island(GameId.sleuth);
    final cb = ref.watch(settingsProvider.select((s) => s.colourBlind));
    return LayoutBuilder(
      builder: (context, box) {
        final p = c.puzzle;
        const gap = 6.0;
        final tile = min(
          50.0,
          (min(box.maxWidth, 360.0) - 24 - gap * (p.length - 1)) / p.length,
        );
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mi.card,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: st.cardLedge,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Theme: ${p.theme}',
                        style: MiText.label.copyWith(
                          color: st.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var r = 0; r < p.tries; r++)
                        Padding(
                          padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
                          child: _row(r, tile, gap, st, mi, cb),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < p.words.length; i++) _chip(i, st, mi),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ActionKey(
                      icon: Icons.lightbulb_rounded,
                      label: 'Hint',
                      style: st,
                      sun: true,
                      badge: widget.hintsLeft,
                      onTap: c.canHint ? () => c.onHintRequested?.call() : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: MiButton(
                      label: 'Guess',
                      icon: Icons.search_rounded,
                      color: st.color,
                      ledge: st.ledge,
                      onColor: st.onColor,
                      height: 66,
                      onTap: c.picked == null ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// One row of the grid: a revealed guess, the word being picked, or empty.
  Widget _row(
    int r,
    double tile,
    double gap,
    IslandStyle st,
    MiColors mi,
    bool cb,
  ) {
    final p = c.puzzle;
    final submitted = r < c.history.length;
    final preview = r == c.history.length ? c.picked : null;
    final word = submitted
        ? p.words[c.history[r].word]
        : (preview == null ? '' : p.words[preview]);
    final marks = submitted ? c.history[r].marks : null;
    final newest = submitted && r == c.history.length - 1;
    final label = submitted
        ? 'Guess ${r + 1}: $word. ${[for (var k = 0; k < word.length; k++) '${word[k]} ${_markWord(marks![k])}'].join(', ')}.'
        : (preview != null ? 'Next guess: $word' : 'Guess ${r + 1}, empty');
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < p.length; k++)
            Padding(
              padding: EdgeInsets.only(left: k == 0 ? 0 : gap),
              child: AnimatedBuilder(
                animation: _flip,
                builder: (context, _) {
                  // Tile k flips in its own slice of the reveal (a ripple left to right).
                  final start = k * .1;
                  final t = newest
                      ? ((_flip.value - start) / .45).clamp(0.0, 1.0)
                      : 1.0;
                  final showColour = marks != null && t >= .5;
                  final bg = showColour
                      ? sleuthMarkColors(mi, marks[k]).$1
                      : (preview != null ? Colors.transparent : st.cell);
                  final fg = showColour
                      ? sleuthMarkColors(mi, marks[k]).$2
                      : mi.ink;
                  final border = showColour
                      ? Colors.transparent
                      : (preview != null
                            ? st.color
                            : (mi.isNight ? st.cellEdge : Colors.transparent));
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(
                      1,
                      newest ? max(0.02, cos(pi * t).abs()) : 1,
                      1,
                    ),
                    child: Container(
                      width: tile,
                      height: tile,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(tile * .24),
                        border: Border.all(
                          color: border,
                          width: preview != null && !showColour ? 2.5 : 1.6,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (word.isNotEmpty)
                            Text(
                              word[k],
                              style: MiText.title.copyWith(
                                fontSize: tile * .52,
                                color: fg,
                              ),
                            ),
                          // Not by colour alone: a mark in the corner when asked for.
                          if (cb && showColour && marks[k] != SleuthMark.absent)
                            Positioned(
                              right: 3,
                              top: 2,
                              child: Icon(
                                marks[k] == SleuthMark.correct
                                    ? Icons.check_rounded
                                    : Icons.circle,
                                size: marks[k] == SleuthMark.correct
                                    ? tile * .3
                                    : tile * .16,
                                color: fg,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(int i, IslandStyle st, MiColors mi) {
    final word = c.puzzle.words[i];
    final picked = c.picked == i;
    final tried = c.wasGuessed(i);
    final crossed = c.isCrossedOut(i);
    final hinted = c.hinted == i;
    final Color bg = picked
        ? st.color
        : (tried ? st.tint : (mi.isNight ? st.cell : Colors.white));
    final Color fg = picked ? st.onColor : (tried ? mi.inkSoft : mi.ink);
    return Semantics(
      button: true,
      selected: picked,
      label:
          'Word $word${tried ? ', already guessed' : ''}${crossed ? ', crossed out' : ''}${hinted ? ', suggested by the hint' : ''}',
      onTap: () => c.pick(i),
      onLongPress: () => c.toggleStrike(i),
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: () {
          ref.read(feedbackProvider).tick();
          c.pick(i);
        },
        onLongPress: () {
          ref.read(feedbackProvider).bump();
          c.toggleStrike(i);
        },
        child: AnimatedOpacity(
          opacity: crossed ? .42 : 1,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            height: 44,
            constraints: const BoxConstraints(minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            // No `alignment:` here — it would stretch the chip to the whole row
            // inside the Wrap. The Center below centres the word in the min width.
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hinted
                    ? const Color(0xFFFFC233)
                    : (picked
                          ? st.ledge
                          : (mi.isNight ? st.cellEdge : st.cardLedge)),
                width: hinted ? 3.5 : 1.8,
              ),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                word,
                style: MiText.headline.copyWith(
                  fontSize: 16,
                  letterSpacing: 1,
                  color: fg,
                  decoration: crossed ? TextDecoration.lineThrough : null,
                  decorationThickness: 2.4,
                  decorationColor: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
