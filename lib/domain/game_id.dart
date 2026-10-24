// The six puzzle games, one per island. Pure Dart (used by save data and engines).

/// Which puzzle (and therefore which island) something belongs to.
enum GameId {
  thread,
  quilt,
  twist,
  sudoku,
  sleuth,
  bridges;

  /// Display name of the puzzle.
  String get title => switch (this) {
    GameId.thread => 'Thread',
    GameId.quilt => 'Quilt',
    GameId.twist => 'Twist',
    GameId.sudoku => 'Sudoku Six',
    GameId.sleuth => 'Sleuth',
    GameId.bridges => 'Bridges',
  };

  /// Name of the island that hosts it.
  String get island => switch (this) {
    GameId.thread => 'Ember Isle',
    GameId.quilt => 'Meadow Isle',
    GameId.twist => 'Crystal Isle',
    GameId.sudoku => 'Frost Isle',
    GameId.sleuth => 'Harbor Isle',
    GameId.bridges => 'Lagoon Isle',
  };

  /// One-line rule, used in onboarding, level sheets and how-to-play.
  String get rule => switch (this) {
    GameId.thread =>
      'Draw one path through every square, passing the numbers in order.',
    GameId.quilt => 'Split the field into rectangles. Each patch holds one clue that tells its size or shape.',
    GameId.twist => 'Trace the hidden words through the letter tiles. Every tile is used once.',
    GameId.sudoku =>
      'Fill the 6 × 6 grid so every row, column and box holds 1 to 6.',
    GameId.sleuth => 'Find the hidden word. Pick words from the list and read the tile colours to rule the others out.',
    GameId.bridges => 'Join the islets with bridges so each one has exactly its number, nothing crosses and every islet is connected.',
  };

  /// Stable key for JSON (never rename).
  String get key => name;

  static GameId fromKey(String key) => GameId.values.firstWhere(
    (g) => g.key == key,
    orElse: () => GameId.thread,
  );
}
