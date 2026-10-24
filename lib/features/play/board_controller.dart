// What every game board offers the shared play frame: moves happen inside the
// board; the frame asks for hints, undo, reset and listens for "solved".

import 'package:flutter/foundation.dart';

/// A hint the frame can describe in words (the board highlights it visually).
class HintNote {
  const HintNote(this.text);
  final String text;
}

abstract class BoardController extends ChangeNotifier {
  bool get solved;

  /// Whether a hint would show anything right now.
  bool get canHint;

  /// Applies one hint; returns what to tell the player, or null if nothing was shown.
  HintNote? hint();

  bool get canUndo;
  void undo();

  /// Clears the board back to the start.
  void reset();

  /// Label for the reset key ("Reset" / "Clear").
  String get resetLabel => 'Reset';

  /// Boards with their own keypad (Sudoku) hide the shared Undo/Hint/Reset row.
  bool get ownControls => false;

  /// "20 of 36 cells" style progress line under the board.
  String get progressText;

  /// Called by the frame when the hint key is pressed on a board with own controls.
  VoidCallback? onHintRequested;
}
