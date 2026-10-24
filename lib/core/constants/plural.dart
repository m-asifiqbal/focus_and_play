// Counts in UI text: "1 hint" / "3 hints", "1 life" / "2 lives".
// Why a helper: counts of 1 are common here (first level, first streak day,
// a 1-hint reward), and "1 hints" reads as a bug.

/// [n] followed by [one] or [many] (default: [one] + "s").
String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';
