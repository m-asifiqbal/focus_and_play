// Quilt's board state: the patches the player stitched, the drag in progress, undo,
// why the last patch was wrong, and the two-step teaching hint.
//
// Why a controller apart from the widget: the play frame asks it for hints, undo and
// "solved" without knowing about drawing, and tests drive it directly.

import '../../games/quilt/quilt.dart';
import '../play/board_controller.dart';

class QuiltController extends BoardController {
  QuiltController(this.puzzle);
  final QuiltPuzzle puzzle;

  List<QuiltRect> placed = [];
  final List<List<QuiltRect>> _history = [];
  int? dragFrom, dragTo;

  /// The patch a hint just placed (it glows).
  QuiltRect? hintRect;

  /// Why the patch the player just stitched is wrong, and which patch that is.
  /// Both are null while it fits. Cleared by the next drag, undo, reset or hint.
  QuiltFault? fault;
  QuiltRect? faultRect;

  /// The two-step hint waiting for its "Show me" (or a second press of Hint).
  QuiltHintPlan? _plan;

  /// The clue a waiting hint points at; the board dims everything else.
  int? get spotlightClue => _plan?.clue;

  @override
  bool get hintPending => _plan != null;

  int get n => puzzle.size;
  QuiltRect? get preview => dragFrom == null || dragTo == null
      ? null
      : QuiltRect.spanning(dragFrom!, dragTo!, n);

  @override
  bool get solved => QuiltRules.isSolved(puzzle, placed);

  // A hint exists until every solution patch is placed, and placing all of them
  // is exactly "solved" (patches never overlap). Checked on every drag frame, so
  // keep it cheap: no candidate search here.
  @override
  bool get canHint => !solved;
  @override
  bool get canUndo => _history.isNotEmpty;
  @override
  String get progressText =>
      '${placed.where((r) => QuiltRules.fits(puzzle, r)).length} of ${puzzle.clues.length} patches';

  void _clearFeedback() {
    hintRect = null;
    fault = null;
    faultRect = null;
    _plan = null;
  }

  void startDrag(int cell) {
    dragFrom = cell;
    dragTo = cell;
    _clearFeedback();
    notifyListeners();
  }

  void updateDrag(int cell) {
    if (dragFrom == null || cell == dragTo) return;
    dragTo = cell;
    notifyListeners();
  }

  /// Finishes a drag. Returns 1 when a patch was stitched, -1 when one was unpicked,
  /// 0 otherwise. After a 1, [fault] says whether (and why) the new patch is wrong.
  int endDrag() {
    final r = preview;
    dragFrom = dragTo = null;
    if (r == null) {
      notifyListeners();
      return 0;
    }
    if (r.area == 1) {
      final hit = placed.indexWhere((p) => p.contains(r.row * n + r.col, n));
      if (hit >= 0) {
        _history.add(List.of(placed));
        placed = [...placed]..removeAt(hit);
        notifyListeners();
        return -1;
      }
      // A tap on an empty square: every patch is at least 2 squares, so a 1×1
      // patch could never fit. Ignore it instead of stitching a warning patch.
      notifyListeners();
      return 0;
    }
    _history.add(List.of(placed));
    placed = [...placed.where((p) => !p.overlaps(r)), r];
    fault = QuiltRules.fault(puzzle, r);
    faultRect = fault == null ? null : r;
    notifyListeners();
    return 1;
  }

  /// Hides the "why it's wrong" message (the player read it).
  void dismissFault() {
    if (fault == null) return;
    fault = null;
    faultRect = null;
    notifyListeners();
  }

  /// A hint in up to three steps, like a friend looking over your shoulder:
  ///  1. patches that can't belong to the answer are taken off (your correct ones stay);
  ///  2. otherwise one clue glows with the reason it has a single answer;
  ///  3. "Show me" — or pressing Hint again — stitches it, free (step 2 paid).
  @override
  HintNote? hint() {
    if (_plan != null) return _reveal(free: true);
    final wrong = QuiltRules.wrongPatches(puzzle, placed);
    if (wrong.isNotEmpty) {
      _history.add(List.of(placed));
      placed = [
        for (final r in placed)
          if (!wrong.contains(r)) r,
      ];
      _clearFeedback();
      notifyListeners();
      final left = placed.length;
      return HintNote(
        left == 0
            ? "Those patches didn't belong, so I cleared them. Ask again and I'll show you where to start."
            : "${wrong.length == 1 ? 'One of your patches' : '${wrong.length} of your patches'} didn't belong, so I took ${wrong.length == 1 ? 'it' : 'them'} off. The $left you kept ${left == 1 ? 'is' : 'are'} correct.",
      );
    }
    final plan = QuiltRules.hintPlan(puzzle, placed);
    if (plan == null) return null;
    _clearFeedback();
    _plan = plan;
    notifyListeners();
    return HintNote(
      plan.options <= 1
          ? 'Look at the glowing clue: only one patch fits it. Any other would cover another clue or overlap a finished patch.'
          : 'Look at the glowing clue. On its own it could fit ${plan.options} ways, but only one leaves room for every other clue.',
      actionLabel: 'Show me',
      onAction: () => _reveal(),
    );
  }

  HintNote? _reveal({bool free = false}) {
    final plan = _plan;
    if (plan == null) return null;
    final h = plan.rect;
    _history.add(List.of(placed));
    placed = [...placed.where((p) => !p.overlaps(h)), h];
    _clearFeedback();
    hintRect = h;
    notifyListeners();
    return HintNote(
      'Stitched a ${h.width} × ${h.height} patch — it glows on the board.',
      free: free,
    );
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    placed = _history.removeLast();
    _clearFeedback();
    notifyListeners();
  }

  @override
  void reset() {
    if (placed.isNotEmpty) _history.add(List.of(placed));
    placed = [];
    _clearFeedback();
    notifyListeners();
  }
}
