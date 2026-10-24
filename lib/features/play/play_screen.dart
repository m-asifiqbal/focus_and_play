// The shared game frame: top bar, HUD (lives · clock · hints), the board, and
// Undo / Hint / Reset. Owns the attempt: clock per life, time's up, hints,
// pause on background, first-time how-to-play and tips, and the solve hand-off.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ads/ad_service.dart';
import '../../core/feedback/feedback.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/mi_art.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../core/widgets/mi_controls.dart';
import '../../core/widgets/mi_dialog.dart';
import '../../domain/level_config.dart';
import '../../domain/rules.dart';
import '../../domain/save_data.dart';
import '../../state/save_controller.dart';
import 'board_controller.dart';
import 'coach_marks.dart';
import 'how_to_play_sheet.dart';
import 'play_dialogs.dart';
import 'play_hud.dart';
import 'play_session.dart';
import 'puzzle_factory.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key, required this.spec});
  final LevelSpec spec;
  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with WidgetsBindingObserver {
  BoardController? _board;
  late final PlaySession _session = PlaySession(
    spec: widget.spec,
    relaxed: ref.read(settingsProvider).relaxed,
    onTimeUp: _timeUp,
  );
  bool _showTips = false;
  bool _celebrating = false;
  String? _hintText;
  Timer? _hintTimer;

  /// The hint card's button ("Show me") while a two-step hint is waiting.
  HintNote? _hintAction;
  final _livesKey = GlobalKey(),
      _clockKey = GlobalKey(),
      _hintsKey = GlobalKey();

  LevelSpec get spec => widget.spec;

  /// A replay of an already solved level (or today's daily again): no lives at stake.
  /// Decided once, before a solve is recorded.
  late final bool _replay;

  @override
  void initState() {
    super.initState();
    _replay = isReplay(ref.read(saveProvider), widget.spec);
    _session.addListener(_clockWarning);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  /// Set when the puzzle couldn't be built (never seen in tests; shows a retry).
  bool _failed = false;

  Future<void> _load() async {
    final Object puzzle;
    try {
      puzzle = await generatePuzzleAsync(spec);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    final board = controllerFor(puzzle)
      ..addListener(_onBoard)
      ..onHintRequested = _onHint;
    setState(() => _board = board);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final save = ref.read(saveProvider);
    final howKey = 'howto_${spec.game.key}';
    if (!save.seenTips.contains(howKey)) {
      ref.read(saveProvider.notifier).markTipSeen(howKey);
      await showHowToPlay(context, spec.game);
      if (!mounted) return;
    }
    if (!save.seenTips.contains('coach') && !_session.relaxed) {
      setState(() => _showTips = true);
      return;
    }
    _session.start();
  }

  int _warnedAt = -1;

  /// A light tap on each of the last five seconds, so a player focused on the
  /// board feels time running out instead of being surprised by "Time's up".
  void _clockWarning() {
    final left = _session.clockLeft;
    if (_session.relaxed ||
        _session.paused ||
        left > 5 ||
        left <= 0 ||
        left == _warnedAt) {
      return;
    }
    _warnedAt = left;
    ref.read(feedbackProvider).tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _board?.removeListener(_onBoard);
    _board?.dispose();
    _session.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_session.over) _session.pause();
  }

  void _onBoard() {
    final b = _board;
    if (b == null || _session.over) return;
    // The player moved on from a two-step hint (placed, undid, reset…): its card
    // and "Show me" button are stale.
    if (_hintAction != null && !b.hintPending) _clearHint();
    if (b.solved) {
      _solved();
      return;
    }
    final why = b.failMessage;
    if (why != null && !_failing) _lostRound(why);
  }

  bool _failing = false;

  /// The board says the round is lost (Sleuth: every guess used). Costs a life
  /// like a timeout — never on a replay — then offers another go.
  Future<void> _lostRound(String why) async {
    _failing = true;
    _session.pause();
    final save = ref.read(saveProvider.notifier);
    final left = _replay ? save.economyNow.lives : save.loseLife();
    if (!_replay) _session.livesLost++;
    ref.read(feedbackProvider)
      ..thud()
      ..play(Sfx.lose);
    if (!_replay && left <= 0) {
      _session.finish();
      save.recordFailure(
        spec,
        seconds: _session.elapsed,
        hints: _session.hintsUsed,
        livesLost: _session.livesLost,
      );
      if (mounted) context.pushReplacement(Routes.outOfLives, extra: spec);
      return;
    }
    final again = await showMiConfirm(
      context,
      icon: Icons.manage_search_rounded,
      tone: MiDialogTone.sun,
      title: 'Out of guesses',
      message:
          '$why ${_replay ? '' : 'You lost a life. '}Ready for another go? The list stays, but the secret word changes.',
      confirmLabel: 'Try again',
      cancelLabel: 'Leave level',
    );
    if (!mounted) return;
    if (again) {
      _board?.reset();
      _failing = false;
      _session.resume();
    } else {
      _leave(confirm: false);
    }
  }

  void _clearHint() {
    _hintTimer?.cancel();
    if (mounted) {
      setState(() {
        _hintText = null;
        _hintAction = null;
      });
    }
  }

  Future<void> _solved() async {
    _session.finish();
    final fb = ref.read(feedbackProvider);
    fb.play(Sfx.solve);
    fb.celebrate();
    setState(() => _celebrating = true);
    final outcome = ref
        .read(saveProvider.notifier)
        .recordSolve(
          spec,
          seconds: _session.elapsed,
          hints: _session.hintsUsed,
          livesLost: _session.livesLost,
        );
    await Future<void>.delayed(
      Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 200 : 1100,
      ),
    );
    if (!mounted) return;
    context.pushReplacement(Routes.result, extra: outcome);
  }

  Future<void> _timeUp() async {
    final save = ref.read(saveProvider.notifier);
    // Replays of solved levels never cost a life: just a fresh clock.
    final left = _replay ? save.economyNow.lives : save.loseLife();
    if (!_replay) _session.livesLost++;
    ref.read(feedbackProvider)
      ..thud()
      ..play(Sfx.lose);
    if (!_replay && left <= 0) {
      _session.finish();
      save.recordFailure(
        spec,
        seconds: _session.elapsed,
        hints: _session.hintsUsed,
        livesLost: _session.livesLost,
      );
      if (mounted) context.pushReplacement(Routes.outOfLives, extra: spec);
      return;
    }
    final choice = await showTimeUp(
      context,
      livesLeft: left,
      clockSeconds: spec.clockSeconds,
      style: context.island(spec.game),
      lifeLost: !_replay,
    );
    if (!mounted) return;
    switch (choice) {
      case TimeUpChoice.keepGoing:
        _session.freshClock();
        _session.resume();
      case TimeUpChoice.restart:
        _board?.reset();
        _session.freshClock();
        _session.resume();
      case TimeUpChoice.leave:
        _leave(confirm: false);
    }
  }

  Future<void> _onHint() async {
    final b = _board;
    if (b == null || _session.over || !b.canHint) return;
    final save = ref.read(saveProvider.notifier);
    var hints = save.economyNow.hints;
    // Finishing a two-step hint is free: no ad prompt, no confirmation.
    final followUp = b.hintPending;
    if (hints <= 0 && !followUp) {
      _session.pause();
      final ads = ref.read(adServiceProvider);
      final watch = await showOutOfHints(context, adReady: ads.rewardedReady);
      if (watch && await ads.showRewarded()) {
        save.addHints(1);
        hints = 1;
      }
      if (!mounted) return;
      _session.resume();
      if (hints <= 0) return;
    }
    if (ref.read(settingsProvider).confirmHint && !followUp) {
      _session.pause();
      final ok = await confirmHint(context, hints);
      if (!mounted) return;
      _session.resume();
      if (!ok) return;
    }
    final note = b.hint();
    if (note == null) return;
    if (!note.free) {
      save.spendHint();
      _session.hintsUsed++;
    }
    ref.read(feedbackProvider).play(Sfx.hint);
    // The first hint of an attempt also says what it cost (the design's hint card).
    final costNote = !note.free && _session.hintsUsed == 1 && !_session.relaxed
        ? '\nThe no-hint star is off for this level.'
        : '';
    _showHint(note, costNote);
  }

  /// Shows [note] on the hint card. A note with a button stays until it is used
  /// or dismissed (the player is reading and deciding); a plain one fades after 5 s.
  void _showHint(HintNote note, [String costNote = '']) {
    _hintTimer?.cancel();
    setState(() {
      _hintText = '${note.text}$costNote';
      _hintAction = note.actionLabel == null ? null : note;
    });
    _hintTimer = Timer(
      Duration(seconds: note.actionLabel == null ? 5 : 25),
      _clearHint,
    );
  }

  void _useHintAction() {
    final next = _hintAction?.onAction?.call();
    if (next == null) {
      _clearHint();
    } else {
      _showHint(next);
    }
  }

  Future<void> _pause() async {
    if (_session.over) return;
    _session.pause();
    final choice = await showPauseSheet(context, context.island(spec.game));
    if (!mounted) return;
    switch (choice) {
      case PauseChoice.resume:
        _session.resume();
      case PauseChoice.restart:
        _board?.reset();
        _session.freshClock();
        _session.resume();
      case PauseChoice.howTo:
        await showHowToPlay(context, spec.game);
        if (mounted) _session.resume();
      case PauseChoice.leave:
        _leave(confirm: false);
    }
  }

  Future<void> _leave({bool confirm = true}) async {
    if (confirm && _session.elapsed > 5 && !_session.over) {
      final wasPaused = _session.paused;
      _session.pause();
      final ok = await confirmLeave(context);
      if (!mounted) return;
      if (!ok) {
        if (!wasPaused) _session.resume();
        return;
      }
    }
    if (!_session.over) {
      _session.finish();
      ref
          .read(saveProvider.notifier)
          .recordFailure(
            spec,
            seconds: _session.elapsed,
            hints: _session.hintsUsed,
            livesLost: _session.livesLost,
          );
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mi;
    final st = context.island(spec.game);
    final e = ref.watch(economyProvider);
    final b = _board;
    final title = spec.isDaily
        ? 'Daily · ${DateFormat('EEE d MMM').format(DateTime.parse(spec.dayKey!))}'
        : 'Level ${spec.level} · ${spec.tier.label}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: c.isNight ? c.page : st.page,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        MiIconButton(
                          icon: Icons.arrow_back_rounded,
                          label: 'Leave level',
                          onTap: _leave,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                spec.game.title,
                                style: MiText.title.copyWith(
                                  fontSize: 20,
                                  color: c.ink,
                                ),
                              ),
                              Text(
                                title,
                                style: MiText.caption.copyWith(
                                  color: st.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MiIconButton(
                          icon: Icons.pause_rounded,
                          label: 'Pause',
                          onTap: b == null ? null : _pause,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    PlayHud(
                      session: _session,
                      lives: e.lives,
                      hints: e.hints,
                      replay: _replay,
                      style: st,
                      showClock: ref.watch(
                        settingsProvider.select((x) => x.showClock),
                      ),
                      livesKey: _livesKey,
                      clockKey: _clockKey,
                      hintsKey: _hintsKey,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: b == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Pip(size: 72),
                                  const SizedBox(height: 10),
                                  Text(
                                    _failed
                                        ? "This puzzle couldn't be built."
                                        : 'Building your puzzle…',
                                    style: MiText.label.copyWith(
                                      color: c.inkSoft,
                                    ),
                                  ),
                                  if (_failed)
                                    MiTextButton(
                                      label: 'Try again',
                                      onTap: () {
                                        setState(() => _failed = false);
                                        _load();
                                      },
                                    ),
                                ],
                              ),
                            )
                          // Boards size themselves from the width. On short
                          // phones (or large text) the board + its lines can be
                          // taller than the space, so shrink the whole block to
                          // fit rather than hide the bottom behind the controls.
                          : LayoutBuilder(
                              builder: (context, box) => Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SizedBox(
                                    width: box.maxWidth,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        boardFor(b, hintsLeft: e.hints)
                                            .animate()
                                            .fadeIn(duration: 250.ms)
                                            .scaleXY(
                                              begin: .96,
                                              curve: Curves.easeOutBack,
                                            ),
                                        const SizedBox(height: 12),
                                        BoardStatus(board: b, style: st),
                                        const SizedBox(height: 4),
                                        Text(
                                          ruleLine(b),
                                          textAlign: TextAlign.center,
                                          style: MiText.small.copyWith(
                                            color: c.inkSoft,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    if (b != null && !b.ownControls) ...[
                      const SizedBox(height: 8),
                      ListenableBuilder(
                        listenable: b,
                        builder: (_, _) => Row(
                          children: [
                            Expanded(
                              child: ActionKey(
                                icon: Icons.undo_rounded,
                                label: 'Undo',
                                style: st,
                                onTap: b.canUndo ? b.undo : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ActionKey(
                                icon: Icons.lightbulb_rounded,
                                label: 'Hint',
                                style: st,
                                sun: true,
                                badge: e.hints,
                                onTap: b.canHint ? _onHint : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ActionKey(
                                icon: Icons.refresh_rounded,
                                label: b.resetLabel,
                                style: st,
                                onTap: b.reset,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_hintText != null)
              Positioned(
                left: 16,
                right: 16,
                bottom:
                    24 +
                    MediaQuery.paddingOf(context).bottom +
                    (b?.ownControls == true ? 0 : 80),
                child:
                    MiCard(
                          color: c.card,
                          ledge: const Color(0xFFDB9A00),
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFC233),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lightbulb_rounded,
                                  color: Color(0xFF13213C),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _hintText!,
                                      style: MiText.label.copyWith(
                                        color: c.ink,
                                      ),
                                    ),
                                    if (_hintAction != null)
                                      MiTextButton(
                                        label: _hintAction!.actionLabel!,
                                        color: c.brandInk,
                                        onTap: _useHintAction,
                                      ),
                                  ],
                                ),
                              ),
                              MiIconButton(
                                icon: Icons.close_rounded,
                                label: 'Dismiss hint',
                                background: Colors.transparent,
                                onTap: _clearHint,
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .slideY(
                          begin: .4,
                          duration: 300.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(),
              ),
            if (_celebrating)
              const Positioned.fill(child: Confetti(count: 60, loop: false)),
            if (_showTips)
              Positioned.fill(
                child: CoachMarks(
                  tips: [
                    CoachTip(
                      _livesKey,
                      'Three lives',
                      'If the clock runs out you lose one. Your board stays exactly as it was.',
                    ),
                    CoachTip(
                      _clockKey,
                      'Beat the clock',
                      'Each life has its own clock. Finish under par for an extra star.',
                    ),
                    CoachTip(
                      _hintsKey,
                      'Stuck? Ask for a hint',
                      'A hint shows your next move. It never costs a life — only the no-hint star.',
                    ),
                  ],
                  onDone: () {
                    ref.read(saveProvider.notifier).markTipSeen('coach');
                    setState(() => _showTips = false);
                    _session.start();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Exposed for tests: whether a save has seen the first-level tips.
bool hasSeenCoach(SaveData s) => s.seenTips.contains('coach');
