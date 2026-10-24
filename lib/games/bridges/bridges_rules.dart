// Bridges rules: what the player may draw, the solved check, wrong-bridge detection and
// hints for the UI.
//
// Why separate from the generator: the UI calls these on every tap, so they are small
// and never search. Everything works on the player's current list of links
// (`BridgesLink`, island indices with `a < b`); the geometry (which islands see each
// other, which bridges would cross) comes from the puzzle's cached `BridgesGraph`.

import 'package:focus_and_play_mindgame/games/bridges/bridges_hint.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges_puzzle.dart';

export 'package:focus_and_play_mindgame/games/bridges/bridges_hint.dart'
    show BridgesHint, BridgesHintKind;

/// Pure rule checks for Bridges.
class BridgesRules {
  BridgesRules._();

  /// Every pair of islands that see each other along a row or column with no island
  /// between them, as `(a, b)` with `a < b`, ordered by `(a, b)`.
  static List<(int, int)> pairs(BridgesPuzzle p) => p.graph.pairs;

  /// Whether the straight segments `a1`–`b1` and `a2`–`b2` (island indices) cross: one
  /// horizontal, one vertical, meeting strictly inside both. Segments that merely share
  /// an island, or run parallel, do not cross.
  static bool cross(BridgesPuzzle p, int a1, int b1, int a2, int b2) {
    final i = p.islands;
    final n = i.length;
    if (a1 < 0 || b1 < 0 || a2 < 0 || b2 < 0) return false;
    if (a1 >= n || b1 >= n || a2 >= n || b2 >= n) return false;
    final h1 = i[a1].row == i[b1].row, v1 = i[a1].col == i[b1].col;
    final h2 = i[a2].row == i[b2].row, v2 = i[a2].col == i[b2].col;
    if (h1 == v1 || h2 == v2) return false; // diagonal or a single point
    if (h1 == h2) return false; // parallel
    // Order so the first segment is the horizontal one.
    final (ha, hb, va, vb) = h1 ? (a1, b1, a2, b2) : (a2, b2, a1, b1);
    final row = i[ha].row, col = i[va].col;
    final c1 = i[ha].col < i[hb].col ? i[ha].col : i[hb].col;
    final c2 = i[ha].col < i[hb].col ? i[hb].col : i[ha].col;
    final r1 = i[va].row < i[vb].row ? i[va].row : i[vb].row;
    final r2 = i[va].row < i[vb].row ? i[vb].row : i[va].row;
    return col > c1 && col < c2 && row > r1 && row < r2;
  }

  /// Bridges attached to each island (a double link counts twice).
  static List<int> degrees(BridgesPuzzle p, List<BridgesLink> links) {
    final d = List<int>.filled(p.islands.length, 0);
    for (final l in links) {
      if (l.a >= 0 && l.a < d.length) d[l.a] += l.count;
      if (l.b >= 0 && l.b < d.length) d[l.b] += l.count;
    }
    return d;
  }

  /// Whether a bridge may be drawn between [a] and [b]: they see each other and no
  /// existing link crosses the way (links on the pair itself do not count — use
  /// [cycle] to change their number). Bridge counts are not checked.
  static bool canAdd(BridgesPuzzle p, List<BridgesLink> links, int a, int b) {
    final id = p.graph.pairId(a, b);
    if (id < 0) return false;
    final lo = a < b ? a : b, hi = a < b ? b : a;
    for (final l in links) {
      if (cross(p, lo, hi, l.a, l.b)) return false;
    }
    return true;
  }

  /// The links after a tap on the gap between [a] and [b]: 0 → 1 → 2 → 0 bridges. When
  /// the pair cannot be bridged (not visible, or a crossing link is in the way) the
  /// same [links] list comes back unchanged; otherwise a new list sorted by `(a, b)`.
  static List<BridgesLink> cycle(
    BridgesPuzzle p,
    List<BridgesLink> links,
    int a,
    int b,
  ) {
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }
    var current = 0;
    for (final l in links) {
      if (l.a == a && l.b == b) current = l.count;
    }
    if (current == 0 && !canAdd(p, links, a, b)) return links;
    final next = current == 2 ? 0 : current + 1;
    final out = [
      for (final l in links)
        if (!(l.a == a && l.b == b)) l,
      if (next > 0) BridgesLink(a, b, next),
    ];
    out.sort(_byPair);
    return out;
  }

  /// Whether [island] has more bridges than it needs.
  static bool overfull(BridgesPuzzle p, List<BridgesLink> links, int island) =>
      degrees(p, links)[island] > p.islands[island].need;

  /// Whether the links join every island into one group.
  static bool connected(BridgesPuzzle p, List<BridgesLink> links) {
    final n = p.islands.length;
    if (n <= 1) return true;
    final root = List<int>.generate(n, (i) => i);
    int find(int x) {
      while (root[x] != x) {
        root[x] = root[root[x]];
        x = root[x];
      }
      return x;
    }

    var groups = n;
    for (final l in links) {
      if (l.a < 0 || l.b < 0 || l.a >= n || l.b >= n) continue;
      final ra = find(l.a), rb = find(l.b);
      if (ra != rb) {
        root[ra] = rb;
        groups--;
      }
    }
    return groups == 1;
  }

  /// Solved = every link is a visible pair with 1 or 2 bridges (each pair once), no two
  /// links cross, every island has exactly its number of bridges, and all islands form
  /// one group.
  static bool isSolved(BridgesPuzzle p, List<BridgesLink> links) {
    final n = p.islands.length;
    final seen = <int>{};
    for (final l in links) {
      if (l.count < 1 || l.count > 2) return false;
      if (l.a >= l.b || p.graph.pairId(l.a, l.b) < 0) return false;
      if (!seen.add(l.a * n + l.b)) return false;
    }
    final d = degrees(p, links);
    for (var i = 0; i < n; i++) {
      if (d[i] != p.islands[i].need) return false;
    }
    for (var x = 0; x < links.length; x++) {
      for (var y = x + 1; y < links.length; y++) {
        if (cross(p, links[x].a, links[x].b, links[y].a, links[y].b)) {
          return false;
        }
      }
    }
    return connected(p, links);
  }

  /// The next teaching step, or null when [links] already solve the puzzle.
  ///
  /// Reasons from the placed links that agree with the solution (wrong ones are
  /// ignored): [BridgesHintKind.onlyNeighbour], then [BridgesHintKind.fullIsland], then
  /// other forced steps; when none applies, the lowest solution link not yet placed with
  /// its full count ([BridgesHintKind.solution]). `count` is the link's TOTAL to reach
  /// (so it can also lower a link that has too many). Edge case: when the board holds
  /// every solution bridge plus a surplus pair, the hint names that pair with `count`
  /// 0 (remove it) — check [wrongLinks] first if you want to treat that separately.
  static BridgesHint? hint(BridgesPuzzle p, List<BridgesLink> links) {
    if (isSolved(p, links)) return null;
    return BridgesHintEngine.next(p, links);
  }

  /// Placed links that are not part of the solution, in the order given. Compared by
  /// pair: a pair the solution lacks is wrong, a count above the solution's is wrong,
  /// a count below it is not (it is just unfinished).
  static List<BridgesLink> wrongLinks(
    BridgesPuzzle p,
    List<BridgesLink> links,
  ) {
    final n = p.islands.length;
    final want = <int, int>{for (final l in p.solution) l.a * n + l.b: l.count};
    return [
      for (final l in links)
        if ((want[l.a * n + l.b] ?? 0) < l.count) l,
    ];
  }

  static int _byPair(BridgesLink x, BridgesLink y) =>
      x.a != y.a ? x.a.compareTo(y.a) : x.b.compareTo(y.b);
}
