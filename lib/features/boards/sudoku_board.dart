// Sudoku Six: 6×6 grid with 2×3 boxes, its own tools (Undo, Erase, Notes, Hint)
// and a 1–6 keypad that shows how many of each number are still to place.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/feedback.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/island_style.dart';
import '../../core/theme/mi_colors.dart';
import '../../core/widgets/pressable.dart';
import '../../domain/game_id.dart';
import '../../games/sudoku/sudoku.dart';
import '../../state/save_controller.dart';
import '../play/board_controller.dart';

/// One undo step: values, notes and which squares a hint filled.
class _Snap {
  _Snap(this.values, this.notes, this.hinted);
  final List<int> values;
  final Map<int, Set<int>> notes;
  final Set<int> hinted;
}

class SudokuController extends BoardController {
  SudokuController(this.puzzle) : values = List.of(puzzle.givens);
  final SudokuPuzzle puzzle;
  List<int> values;
  Map<int, Set<int>> notes = {};
  Set<int> hinted = {};
  int? selected;
  bool notesMode = false;
  final List<_Snap> _history = [];

  bool isGiven(int i) => puzzle.givens[i] != 0;

  @override
  bool get solved => SudokuRules.isSolved(puzzle, values);
  @override
  bool get canHint => !solved;
  @override
  bool get canUndo => _history.isNotEmpty;
  @override
  bool get ownControls => true;
  @override
  String get progressText =>
      '${values.where((v) => v != 0).length} of 36 squares';

  bool get _sameAsGivens {
    for (var i = 0; i < 36; i++) {
      if (values[i] != puzzle.givens[i]) return false;
    }
    return true;
  }

  int remaining(int n) => 6 - values.where((v) => v == n).length;

  void _push() => _history.add(
    _Snap(
      List.of(values),
      {
        for (final e in notes.entries) e.key: {...e.value},
      },
      {...hinted},
    ),
  );

  void select(int i) {
    selected = i;
    notifyListeners();
  }

  /// Places [n] (or toggles it as a note) in the selected square.
  bool input(int n) {
    final i = selected;
    if (i == null || isGiven(i)) return false;
    _push();
    if (notesMode) {
      final s = {...?notes[i]};
      s.contains(n) ? s.remove(n) : s.add(n);
      notes[i] = s;
    } else {
      values[i] = values[i] == n ? 0 : n;
      hinted.remove(i); // the player's own entry now, not the hint's
      if (values[i] != 0) {
        notes.remove(i);
        // Clear this number from notes in the same row, column and box.
        for (var k = 0; k < 36; k++) {
          if (k ~/ 6 == i ~/ 6 ||
              k % 6 == i % 6 ||
              ((k ~/ 12) == (i ~/ 12) && (k % 6) ~/ 3 == (i % 6) ~/ 3)) {
            notes[k]?.remove(n);
          }
        }
      }
    }
    notifyListeners();
    return true;
  }

  void erase() {
    final i = selected;
    if (i == null ||
        isGiven(i) ||
        (values[i] == 0 && (notes[i]?.isEmpty ?? true))) {
      return;
    }
    _push();
    values[i] = 0;
    notes.remove(i);
    hinted.remove(i);
    notifyListeners();
  }

  void toggleNotes() {
    notesMode = !notesMode;
    notifyListeners();
  }

  @override
  HintNote? hint() {
    final i = SudokuRules.hintCell(puzzle, values, preferred: selected);
    if (i == null) return null;
    _push();
    values[i] = puzzle.solution[i];
    notes.remove(i);
    hinted.add(i);
    selected = i;
    notifyListeners();
    return HintNote(
      'Row ${i ~/ 6 + 1}, column ${i % 6 + 1} is ${puzzle.solution[i]}.',
    );
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    values = s.values;
    notes = s.notes;
    hinted = s.hinted;
    notifyListeners();
  }

  @override
  void reset() {
    // Undoable, like Reset in the other games.
    if (!_sameAsGivens || notes.isNotEmpty) _push();
    values = List.of(puzzle.givens);
    notes = {};
    hinted = {};
    notifyListeners();
  }
}

class SudokuBoard extends ConsumerWidget {
  const SudokuBoard({
    super.key,
    required this.controller,
    required this.hintsLeft,
  });
  final SudokuController controller;
  final int hintsLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mi = context.mi;
    final st = context.island(GameId.sudoku);
    final mark = ref.watch(settingsProvider.select((s) => s.markMistakes));
    final large = ref.watch(settingsProvider.select((s) => s.largeNumbers));
    final fb = ref.read(feedbackProvider);
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final conflicts = mark
            ? SudokuRules.conflicts(c.values)
            : const <int>{};
        final sel = c.selected;
        final selVal = sel == null ? 0 : c.values[sel];
        return LayoutBuilder(
          builder: (context, box) {
            final boardW = min(box.maxWidth, 340.0);
            final cell = (boardW - 8 - 4 - 4 * 2) / 6;
            Widget cellW(int i) {
              final r = i ~/ 6, col = i % 6;
              final v = c.values[i];
              final given = c.isGiven(i);
              var bg = mi.isNight ? st.cell : Colors.white;
              if (sel != null &&
                  (r == sel ~/ 6 ||
                      col == sel % 6 ||
                      (r ~/ 2 == sel ~/ 12 && col ~/ 3 == (sel % 6) ~/ 3))) {
                bg = mi.isNight
                    ? Color.lerp(st.cell, st.color, .26)!
                    : const Color(0xFFEAF4FE);
              }
              if (selVal != 0 && v == selVal) {
                bg = mi.isNight
                    ? Color.lerp(st.cell, st.color, .5)!
                    : const Color(0xFFCFE5FA);
              }
              if (c.hinted.contains(i)) {
                bg = mi.isNight
                    ? const Color(0xFF4A3B12)
                    : const Color(0xFFFFF1CC);
              }
              if (i == sel) {
                bg = mi.isNight
                    ? Color.lerp(st.cell, st.color, .72)!
                    : const Color(0xFFBFDDF8);
              }
              final wrong = conflicts.contains(i) && !given;
              final fg = given
                  ? mi.ink
                  : (wrong
                        ? mi.danger
                        : (mi.isNight
                              ? const Color(0xFF7CC4F2)
                              : const Color(0xFF1D6BB0)));
              final n = c.notes[i];
              return Semantics(
                button: true,
                selected: i == sel,
                label:
                    'Row ${r + 1}, column ${col + 1}${v != 0 ? ', $v' : ', empty'}${given ? ', given' : ''}${wrong ? ', clashes' : ''}',
                onTap: () => c.select(i),
                excludeSemantics: true,
                child: GestureDetector(
                  excludeFromSemantics: true,
                  onTap: () {
                    fb.tick();
                    c.select(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: bg,
                      border: i == sel
                          ? Border.all(
                              color: mi.isNight
                                  ? const Color(0xFF7CC4F2)
                                  : const Color(0xFF1D6BB0),
                              width: 3,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: v != 0
                        ? Text(
                            '$v',
                            style: MiText.title.copyWith(
                              fontSize: cell * (large ? .6 : .52),
                              color: fg,
                              fontWeight: given
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              decoration: wrong
                                  ? TextDecoration.underline
                                  : null,
                              decorationColor: mi.danger,
                              decorationStyle: TextDecorationStyle.wavy,
                            ),
                          )
                        : (n == null || n.isEmpty
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    children: [
                                      for (var k = 1; k <= 6; k++)
                                        SizedBox(
                                          width: (cell - 6) / 3,
                                          child: Text(
                                            n.contains(k) ? '$k' : '',
                                            textAlign: TextAlign.center,
                                            style: MiText.caption.copyWith(
                                              fontSize: cell * .22,
                                              color: mi.inkSoft,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )),
                  ),
                ),
              );
            }

            Widget boxW(int b) {
              final br = b ~/ 2, bc = b % 2;
              return Container(
                color: mi.isNight
                    ? const Color(0xFF0D1626)
                    : const Color(0xFFB8D3EE),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var rr = 0; rr < 2; rr++)
                      Padding(
                        padding: EdgeInsets.only(top: rr == 0 ? 0 : 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var cc = 0; cc < 3; cc++)
                              Padding(
                                padding: EdgeInsets.only(left: cc == 0 ? 0 : 2),
                                child: cellW((br * 2 + rr) * 6 + bc * 3 + cc),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: mi.card,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: st.cardLedge,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: mi.isNight ? st.cellEdge : const Color(0xFF2B5E91),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var br = 0; br < 3; br++)
                            Padding(
                              padding: EdgeInsets.only(top: br == 0 ? 0 : 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  boxW(br * 2),
                                  const SizedBox(width: 4),
                                  boxW(br * 2 + 1),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Tool(
                      icon: Icons.undo_rounded,
                      label: 'Undo',
                      onTap: c.canUndo ? c.undo : null,
                      st: st,
                    ),
                    _Tool(
                      icon: Icons.backspace_rounded,
                      label: 'Erase',
                      onTap: c.erase,
                      st: st,
                    ),
                    _Tool(
                      icon: Icons.edit_rounded,
                      label: c.notesMode ? 'Notes on' : 'Notes off',
                      onTap: c.toggleNotes,
                      st: st,
                      active: c.notesMode,
                    ),
                    _Tool(
                      icon: Icons.lightbulb_rounded,
                      label: 'Hint',
                      onTap: () => c.onHintRequested?.call(),
                      st: st,
                      sun: true,
                      badge: hintsLeft,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var n = 1; n <= 6; n++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: MiPressable(
                            onTap: () {
                              if (c.input(n)) fb.play(Sfx.place, volume: .6);
                            },
                            semanticLabel: 'Enter $n, ${c.remaining(n)} left',
                            color: mi.isNight ? st.cell : Colors.white,
                            ledge: st.cardLedge,
                            radius: 16,
                            height: 64,
                            sound: false,
                            child: Opacity(
                              opacity: c.remaining(n) > 0 ? 1 : .4,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$n',
                                    style: MiText.title.copyWith(
                                      fontSize: 27,
                                      color: mi.isNight
                                          ? const Color(0xFF7CC4F2)
                                          : const Color(0xFF1D6BB0),
                                    ),
                                  ),
                                  Text(
                                    c.remaining(n) > 0
                                        ? '${c.remaining(n)} left'
                                        : 'done',
                                    style: MiText.caption.copyWith(
                                      fontSize: 11.5,
                                      color: mi.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.st,
    this.active = false,
    this.sun = false,
    this.badge,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final IslandStyle st;
  final bool active, sun;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final mi = context.mi;
    final fg = sun ? const Color(0xFF13213C) : mi.ink;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: MiPressable(
          onTap: onTap,
          semanticLabel: label,
          selected: active,
          color: sun ? const Color(0xFFFFC233) : (active ? st.tint : mi.card),
          ledge: sun ? const Color(0xFFDB9A00) : st.cardLedge,
          border: active ? Border.all(color: st.color, width: 2) : null,
          radius: 16,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: fg),
                  Text(
                    label,
                    style: MiText.caption.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: -8,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF13213C),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '$badge',
                      style: MiText.caption.copyWith(
                        color: Colors.white,
                        fontFamily: MiFonts.display,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
