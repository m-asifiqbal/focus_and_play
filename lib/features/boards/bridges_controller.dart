// Bridges' board state: the bridges the player built, undo, why a tap did nothing,
// and the two-step teaching hint (the same shape as Quilt's).
//
// Why a controller apart from the widget: the play frame asks it for hints, undo and
// "solved" without knowing how the islets are drawn, and tests drive it directly.

import '../../games/bridges/bridges.dart';
import '../play/board_controller.dart';

class BridgesController extends BoardController {
  BridgesController(this.puzzle) : pairs = BridgesRules.pairs(puzzle);
  final BridgesPuzzle puzzle;

  /// Every pair of islets that can be joined (they see each other).
  final List<(int, int)> pairs;

  /// The bridges built so far.
  List<BridgesLink> links = [];
  final List<List<BridgesLink>> _history = [];

  /// A line of feedback under the board (a blocked tap), or null.
  String? message;

  /// The link a hint just placed (glows for a moment).
  (int, int)? hintLink;

  /// After a refused tap: the bridge that was in the way and the one that was tried,
  /// so the board can show *which* crossing it was (cleared with [message]).
  (int, int)? blockedBy, blockedTry;

  BridgesHint? _plan;

  /// The islet a waiting hint talks about; the board dims everything else.
  int? get spotlightIsland => _plan?.island;

  @override
  bool get hintPending => _plan != null;

  List<int> get degrees => BridgesRules.degrees(puzzle, links);

  /// Islets whose bridges add up to their number.
  int get satisfied {
    final d = degrees;
    var n = 0;
    for (var i = 0; i < d.length; i++) {
      if (d[i] == puzzle.islands[i].need) n++;
    }
    return n;
  }

  /// Every number is met but the islets are not one group yet (the one case where
  /// "all numbers right" is not "solved").
  bool get numbersMetButSplit =>
      satisfied == puzzle.islands.length &&
      !BridgesRules.connected(puzzle, links);

  int bridgesBetween(int a, int b) {
    final lo = a < b ? a : b, hi = a < b ? b : a;
    for (final l in links) {
      if (l.a == lo && l.b == hi) return l.count;
    }
    return 0;
  }

  @override
  bool get solved => BridgesRules.isSolved(puzzle, links);

  @override
  bool get canHint => !solved;

  @override
  bool get canUndo => _history.isNotEmpty;

  @override
  String get progressText =>
      '$satisfied of ${puzzle.islands.length} islets done';

  void _clearFeedback() {
    message = null;
    blockedBy = blockedTry = null;
    hintLink = null;
    _plan = null;
  }

  /// A tap on the gap between [a] and [b] (or a drag from one to the other):
  /// none → one → two → none. Returns false when nothing changed (a crossing
  /// bridge is in the way), with [message] saying why.
  bool cycle(int a, int b) {
    _clearFeedback();
    final next = BridgesRules.cycle(puzzle, links, a, b);
    final changed = !_same(next, links);
    if (changed) {
      _history.add(links);
      links = next;
    } else if (bridgesBetween(a, b) == 0) {
      message = "A bridge can't cross another one.";
      for (final l in links) {
        if (BridgesRules.cross(puzzle, l.a, l.b, a, b)) {
          blockedBy = (l.a, l.b);
          blockedTry = a < b ? (a, b) : (b, a);
          break;
        }
      }
    }
    notifyListeners();
    return changed;
  }

  bool _same(List<BridgesLink> x, List<BridgesLink> y) {
    if (x.length != y.length) return false;
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }

  void dismissMessage() {
    if (message == null) return;
    message = null;
    blockedBy = blockedTry = null;
    notifyListeners();
  }

  /// A hint in up to three steps, like a friend looking over your shoulder:
  ///  1. bridges that can't belong to the answer are taken away (the others stay);
  ///  2. otherwise one islet glows with the reason a bridge there is certain;
  ///  3. "Show me" — or pressing Hint again — builds it, free (step 2 paid).
  @override
  HintNote? hint() {
    if (_plan != null) return _reveal(free: true);
    final wrong = BridgesRules.wrongLinks(puzzle, links);
    if (wrong.isNotEmpty) {
      _history.add(links);
      links = [
        for (final l in links)
          if (!wrong.contains(l)) l,
      ];
      _clearFeedback();
      notifyListeners();
      final left = links.length;
      return HintNote(
        left == 0
            ? "Those bridges didn't belong, so I took them away. Ask again and I'll show you where to start."
            : "${wrong.length == 1 ? 'One of your bridges' : '${wrong.length} of your bridges'} didn't belong, so I took ${wrong.length == 1 ? 'it' : 'them'} away. The $left you kept ${left == 1 ? 'is' : 'are'} right.",
      );
    }
    final plan = BridgesRules.hint(puzzle, links);
    if (plan == null) return null;
    _clearFeedback();
    _plan = plan;
    notifyListeners();
    return HintNote(
      switch (plan.kind) {
        BridgesHintKind.onlyNeighbour => 'Look at the glowing islet. It can only reach one other islet now, so its bridges all go there.',
        BridgesHintKind.fullIsland => 'Look at the glowing islet. It needs as many bridges as its neighbours can take, so every neighbour gets the most it can.',
        BridgesHintKind.forced => switch (plan.why) {
          BridgesForcedWhy.crossing => 'Look at the glowing islet. A bridge that is already built blocks some of its routes, so a bridge here is certain.',
          BridgesForcedWhy.cutOff => 'Look at the glowing islet. Any other way would cut some islets off from the rest, so a bridge here is certain.',
          _ => "Look at the glowing islet. Its other neighbours can't give it enough bridges, so a bridge here is certain.",
        },
        BridgesHintKind.solution => 'Look at the glowing islet. A bridge between these two islets belongs in the answer.',
      },
      actionLabel: 'Show me',
      onAction: () => _reveal(),
    );
  }

  HintNote? _reveal({bool free = false}) {
    final plan = _plan;
    if (plan == null) return null;
    _history.add(links);
    final rest = [
      for (final l in links)
        if (!(l.a == plan.a && l.b == plan.b)) l,
    ];
    // count is the link's TOTAL; 0 (a surplus bridge next to the whole answer) means
    // take it away. wrongLinks normally clears those first.
    links = [
      ...rest,
      if (plan.count > 0) BridgesLink(plan.a, plan.b, plan.count),
    ]..sort((x, y) => x.a != y.a ? x.a.compareTo(y.a) : x.b.compareTo(y.b));
    _clearFeedback();
    if (plan.count == 0) {
      notifyListeners();
      return HintNote('Took away a bridge that does not belong.', free: free);
    }
    hintLink = (plan.a, plan.b);
    notifyListeners();
    return HintNote(
      'Built ${plan.count == 1 ? 'a bridge' : 'a double bridge'} for you — it glows on the board.',
      free: free,
    );
  }

  @override
  void undo() {
    if (_history.isEmpty) return;
    links = _history.removeLast();
    _clearFeedback();
    notifyListeners();
  }

  @override
  void reset() {
    if (links.isNotEmpty) _history.add(links);
    links = [];
    _clearFeedback();
    notifyListeners();
  }
}
