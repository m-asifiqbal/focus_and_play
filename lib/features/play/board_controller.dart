// What every game board offers the shared play frame: moves happen inside the
// board; the frame asks for hints, undo, reset and listens for "solved".

import 'package:flutter/foundation.dart';

/// A hint the frame can describe in words (the board highlights it visually).
class HintNote {
  const HintNote(
    this.text, {
    this.actionLabel,
    this.onAction,
    this.free = false,
  });
  final String text;

  /// A button on the hint card (e.g. "Show me") and what it does. The action may
  /// return a follow-up note to show in place of this one.
  final String? actionLabel;
  final HintNote? Function()? onAction;

  /// The follow-up to an earlier hint: costs no hint and doesn't count as a new one.
  final bool free;
}

abstract class BoardController extends ChangeNotifier {
  bool get solved;

  /// Whether a hint would show anything right now.
  bool get canHint;

  /// Applies one hint; returns what to tell the player, or null if nothing was shown.
  HintNote? hint();

  /// True while a multi-step hint waits for its follow-up (pressing Hint again
  /// finishes it for free), so the frame must not ask for a hint to be spent.
  bool get hintPending => false;

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

  /// Thread's "Next number" chip under the board; null for boards without one.
  int? get nextNumber => null;

  /// Called by the frame when the hint key is pressed on a board with own controls.
  VoidCallback? onHintRequested;
}
