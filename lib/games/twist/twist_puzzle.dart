// Twist value types: the letter board, its hidden words, generator params and hints.
//
// Why a separate file: the generator, the rules and the UI share these immutable types,
// and puzzles cross isolate boundaries and get saved, so they round-trip through plain
// JSON (maps, lists, ints and strings only).

/// One hidden word and the cells it occupies, in reading order (first letter first).
class TwistWord {
  const TwistWord({required this.word, required this.cells});

  /// The word in upper case, e.g. `WHALE`.
  final String word;

  /// Row-major cell indices, `cells[i]` holds `word[i]`; consecutive cells share an edge.
  final List<int> cells;

  /// Number of letters (== `cells.length`).
  int get length => word.length;

  Map<String, Object?> toJson() => {'word': word, 'cells': List<int>.of(cells)};

  factory TwistWord.fromJson(Map<String, Object?> j) => TwistWord(
    word: j['word'] as String,
    cells: List<int>.unmodifiable((j['cells'] as List).cast<int>()),
  );

  @override
  String toString() => 'TwistWord($word, $cells)';
}

/// A rows×cols letter board fully partitioned into [words] of one [theme].
class TwistPuzzle {
  const TwistPuzzle({
    required this.rows,
    required this.cols,
    required this.letters,
    required this.words,
    required this.theme,
  });

  final int rows, cols;

  /// rows*cols upper-case single letters, row-major.
  final List<String> letters;

  /// The hidden words, sorted by length then by first cell (the order the UI lists them).
  final List<TwistWord> words;

  /// Theme name, a key of `kWordThemes` (e.g. `Ocean`).
  final String theme;

  /// rows*cols.
  int get cellCount => rows * cols;

  Map<String, Object?> toJson() => {
    'rows': rows,
    'cols': cols,
    'theme': theme,
    'letters': List<String>.of(letters),
    'words': [for (final w in words) w.toJson()],
  };

  factory TwistPuzzle.fromJson(Map<String, Object?> j) => TwistPuzzle(
    rows: j['rows'] as int,
    cols: j['cols'] as int,
    theme: j['theme'] as String,
    letters: List<String>.unmodifiable((j['letters'] as List).cast<String>()),
    words: List<TwistWord>.unmodifiable([
      for (final w in j['words'] as List)
        TwistWord.fromJson(w as Map<String, Object?>),
    ]),
  );
}

/// Board size and word-length range for one difficulty.
///
/// rows*cols must be a sum of lengths in [minLen]..[maxLen], and the range must stay
/// inside the word bank's 4..8 (`kTwistMinWordLength`..`kTwistMaxWordLength`).
/// Tested: 4×4 (4..6), 4×5 (4..6), 5×5 (4..7), 5×6 (4..7), 6×6 (4..6 and 4..8).
class TwistParams {
  const TwistParams({
    required this.rows,
    required this.cols,
    this.minLen = 4,
    this.maxLen = 8,
  });

  final int rows, cols;

  /// Shortest and longest word allowed on the board (inclusive).
  final int minLen, maxLen;

  @override
  String toString() => 'TwistParams(${rows}x$cols, $minLen..$maxLen)';
}

/// Which word to hint at and how many of its first letters to show.
class TwistHint {
  const TwistHint({required this.wordIndex, required this.lettersShown});

  /// Index into `TwistPuzzle.words`.
  final int wordIndex;

  /// 1..word length: show this many leading letters (and their cells) of the word.
  final int lettersShown;

  @override
  bool operator ==(Object other) =>
      other is TwistHint &&
      other.wordIndex == wordIndex &&
      other.lettersShown == lettersShown;

  @override
  int get hashCode => Object.hash(wordIndex, lettersShown);

  @override
  String toString() => 'TwistHint(word $wordIndex, $lettersShown letters)';
}
