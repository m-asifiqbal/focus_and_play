// Sleuth puzzle model: a themed, closed list of same-length words, one of which is the
// secret answer, plus the number of guesses the player gets.
//
// Why plain data + JSON: the generator runs inside `Isolate.run`, and the app saves and
// restores games, so everything here crosses isolates and survives a JSON round trip.
// The player never types: every guess is a word picked from [SleuthPuzzle.words], so the
// puzzle needs no dictionary. Pure Dart (no Flutter imports).

/// Fewest candidate words a Sleuth list may have. Fewer than this and a single guess
/// would almost always settle the puzzle, so [SleuthParams.candidates] below this value
/// is raised to it.
const int kSleuthMinCandidates = 6;

/// A generated Sleuth puzzle.
class SleuthPuzzle {
  /// Creates a puzzle. [words] must be upper-case A–Z, unique, all [length] letters long
  /// and sorted alphabetically; [secret] indexes into it. The generator guarantees this
  /// and [SleuthPuzzle.fromJson] checks it.
  const SleuthPuzzle({
    required this.theme,
    required this.length,
    required this.words,
    required this.secret,
    required this.tries,
    required this.assist,
  }) : assert(length > 0, 'words need at least one letter'),
       assert(tries > 0, 'the player needs at least one guess');

  /// Rebuilds a puzzle from [toJson] output; throws [FormatException] when the data is
  /// not a consistent puzzle (empty list, a word of the wrong length, secret out of
  /// range).
  factory SleuthPuzzle.fromJson(Map<String, Object?> j) {
    final words = List<String>.unmodifiable([
      for (final w in j['words'] as List) w as String,
    ]);
    final length = (j['length'] as num).toInt();
    final secret = (j['secret'] as num).toInt();
    final tries = (j['tries'] as num).toInt();
    if (length < 1 || tries < 1) {
      throw FormatException('Sleuth: bad length $length or tries $tries');
    }
    if (words.isEmpty || secret < 0 || secret >= words.length) {
      throw FormatException(
        'Sleuth: secret $secret is outside ${words.length} words',
      );
    }
    for (final w in words) {
      if (w.length != length) {
        throw FormatException('Sleuth: "$w" is not $length letters long');
      }
    }
    return SleuthPuzzle(
      theme: j['theme']! as String,
      length: length,
      words: words,
      secret: secret,
      tries: tries,
      assist: (j['assist'] as bool?) ?? true,
    );
  }

  /// Theme name (a key of `kWordThemes`), shown above the list.
  final String theme;

  /// Letters per word (4..8 with the bundled word bank).
  final int length;

  /// The candidate list: upper-case A–Z, all [length] letters, unique, sorted
  /// alphabetically. The player picks guesses from here.
  final List<String> words;

  /// Index into [words] of the secret answer.
  final int secret;

  /// Maximum number of guesses allowed.
  final int tries;

  /// Whether the UI may cross out candidates that the feedback has ruled out (easy
  /// tiers). The engine always computes them; this only says whether to show them.
  final bool assist;

  /// The secret word.
  String get answer => words[secret];

  /// Plain JSON.
  Map<String, Object?> toJson() => {
    'theme': theme,
    'length': length,
    'words': List<String>.of(words),
    'secret': secret,
    'tries': tries,
    'assist': assist,
  };
}

/// Generation settings for a Sleuth puzzle.
class SleuthParams {
  /// Creates params; [length] is 4..8 (the word bank's range), [candidates] the list
  /// size the generator aims for, [tries] the guesses allowed.
  const SleuthParams({
    required this.length,
    required this.candidates,
    required this.tries,
    this.assist = true,
  });

  /// Letters per word, 4..8.
  final int length;

  /// Words in the list. Raised to [kSleuthMinCandidates] when lower, and capped at what
  /// the largest theme offers for [length] (see `SleuthGenerator.maxCandidates`).
  final int candidates;

  /// Guesses allowed; the generator proves the puzzle can be solved within them.
  final int tries;

  /// Whether the UI may cross out ruled-out candidates (copied into the puzzle).
  final bool assist;

  @override
  String toString() =>
      'SleuthParams(length: $length, candidates: $candidates, tries: $tries, '
      'assist: $assist)';
}
