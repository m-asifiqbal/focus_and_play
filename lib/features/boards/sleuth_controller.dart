// Sleuth's board state: which word is picked, the guesses made, the words the
// player (or the game, on easy tiers) has crossed out, and the hint.
//
// Why a controller apart from the widget: the play frame asks it for hints and
// "solved / out of guesses" without knowing how the grid is drawn, and tests drive
// it directly.

import '../../games/sleuth/sleuth.dart';
import '../play/board_controller.dart';

class SleuthController extends BoardController {
  SleuthController(SleuthPuzzle puzzle) : _puzzle = puzzle;

  SleuthPuzzle _puzzle;
  SleuthPuzzle get puzzle => _puzzle;

  /// Guesses made, oldest first.
  final List<SleuthGuess> history = [];

  /// The list word chosen for the next guess (not yet submitted).
  int? picked;

  /// Words the player crossed out by hand (long-press).
  final Set<int> struck = {};

  /// The word the last hint pointed at (glows until the next move).
  int? hinted;

  /// Bumped on every submitted guess so the grid can play its flip.
  int guessCount = 0;

  List<SleuthMark>? get lastMarks =>
      history.isEmpty ? null : history.last.marks;

  bool get outOfTries => !solved && history.length >= puzzle.tries;

  @override
  bool get solved => SleuthRules.isSolved(puzzle, history);

  @override
  String? get failMessage =>
      outOfTries ? 'The word was ${puzzle.answer}.' : null;

  @override
  bool get canHint => !solved && !outOfTries;

  @override
  bool get canUndo => picked != null;

  @override
  String get resetLabel => 'Restart';

  @override
  bool get ownControls => true;

  @override
  String get progressText => '${history.length} of ${puzzle.tries} guesses';

  /// Words still possible after all the feedback so far.
  late List<int> _remaining = List.generate(puzzle.words.length, (i) => i);
  List<int> get remaining => _remaining;

  bool wasGuessed(int word) => history.any((g) => g.word == word);

  /// Crossed out: by the game when the list is assisted and the feedback rules the
  /// word out, or by the player.
  bool isCrossedOut(int word) =>
      struck.contains(word) ||
      (puzzle.assist &&
          !solved &&
          !_remaining.contains(word) &&
          !wasGuessed(word));

  /// Taps a word: pick it for the next guess (tap again to unpick). Guessed or
  /// crossed-out words can still be picked on purpose, except one already tried.
  void pick(int word) {
    if (solved || outOfTries || wasGuessed(word)) return;
    picked = picked == word ? null : word;
    hinted = null;
    notifyListeners();
  }

  /// Long-press: the player's own cross-out.
  void toggleStrike(int word) {
    if (solved || outOfTries || wasGuessed(word)) return;
    struck.contains(word) ? struck.remove(word) : struck.add(word);
    if (picked == word) picked = null;
    notifyListeners();
  }

  /// Submits the picked word. Returns the marks it earned, or null when nothing
  /// was picked.
  List<SleuthMark>? submit() {
    final w = picked;
    if (w == null || solved || outOfTries) return null;
    final g = SleuthRules.guess(puzzle, w);
    history.add(g);
    picked = null;
    hinted = null;
    guessCount++;
    _remaining = SleuthRules.remaining(puzzle, history);
    notifyListeners();
    return g.marks;
  }

  /// Hint: the word to try next — the one that narrows the list down the most
  /// whatever the answer is. It is picked for the player (they still press Guess).
  @override
  HintNote? hint() {
    if (!canHint) return null;
    final best = SleuthRules.bestGuess(puzzle, history);
    if (best < 0) return null; // every word is already tried
    picked = best;
    hinted = best;
    notifyListeners();
    final word = puzzle.words[best];
    final left = _remaining.length;
    return HintNote(
      left == 1
          ? 'Only one word fits all the clues: $word.'
          : 'Try $word. Whichever word is the secret, it rules out the most of the $left that are left.',
    );
  }

  @override
  void undo() {
    if (picked == null) return;
    picked = null;
    hinted = null;
    notifyListeners();
  }

  /// Starts the round again with a different secret from the same list (the same
  /// answer twice would be a giveaway). The new secret is checked to be findable
  /// within the guesses, like the original.
  @override
  void reset() {
    final n = puzzle.words.length;
    for (var step = 1; step < n; step++) {
      final k = (puzzle.secret + step) % n;
      final candidate = SleuthPuzzle(
        theme: puzzle.theme,
        length: puzzle.length,
        words: puzzle.words,
        secret: k,
        tries: puzzle.tries,
        assist: puzzle.assist,
      );
      final run = SleuthRules.greedyRun(candidate);
      if (run.isNotEmpty && run.last.isCorrect && run.length <= puzzle.tries) {
        _puzzle = candidate;
        break;
      }
    }
    history.clear();
    picked = null;
    hinted = null;
    struck.clear();
    guessCount = 0;
    _remaining = List.generate(puzzle.words.length, (i) => i);
    notifyListeners();
  }
}
