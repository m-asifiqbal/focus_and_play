// Bridges hints: the next step a person could reason out, falling back to a plain
// "this bridge is part of the answer".
//
// Why a reasoner of its own (not the solver): a hint is a lesson. It must be a step the
// player can follow from the board ("this island can only reach one neighbour"), so the
// rules here are the ones people use — degree counting, crossings, never closing a group
// off, never cutting a group off — applied to the bridges the player has placed.
//
// The placed bridges are first reduced to those that agree with the solution (a wrong or
// surplus bridge is ignored), so every rule starts from facts and every conclusion is
// true of the unique solution. Only the upper bounds shrink while reasoning (bridges
// the solution cannot contain); the first rule that *raises* a bridge count is returned.
// Pure Dart (no Flutter imports).

import 'dart:typed_data';

import 'package:focus_and_play_mindgame/games/bridges/bridges_graph.dart';
import 'package:focus_and_play_mindgame/games/bridges/bridges_puzzle.dart';

/// Why a hinted bridge is right (the UI picks the wording).
enum BridgesHintKind {
  /// The island can still reach only one other island for the bridges it needs.
  onlyNeighbour,

  /// The island needs exactly as many bridges as its open neighbours can take, so
  /// every neighbour gets the most it can.
  fullIsland,

  /// Another forced step: the island must take at least this many to a neighbour, or
  /// bridging differently would cross, close a group off or cut one off.
  /// [BridgesHint.why] says which of those it is.
  forced,

  /// No simple step found: the bridge is just part of the solution.
  solution,
}

/// Why a [BridgesHintKind.forced] step is certain (the UI can say more than "forced").
enum BridgesForcedWhy {
  /// The island's other open neighbours cannot supply enough bridges, so this one
  /// must take at least this many.
  neighbours,

  /// Part of the island's reach is blocked by a bridge that is already drawn, which
  /// leaves too few ways to reach its number.
  crossing,

  /// Any other way would cut islands off: a group of them would be closed off from
  /// the rest, or could not be reached at all.
  cutOff,
}

/// The next step: the link `a`–`b` (`a < b`) and the TOTAL number of bridges it should
/// reach (not how many to add). `count` is 0 only in the rare case that the board holds
/// every solution bridge plus a surplus one: that bridge is then hinted for removal.
class BridgesHint {
  /// Creates a hint.
  const BridgesHint({
    required this.island,
    required this.a,
    required this.b,
    required this.count,
    required this.kind,
    this.why,
  });

  /// The island the reasoning is about (the UI spotlights it).
  final int island;

  /// The two islands of the link, `a < b`.
  final int a, b;

  /// Bridges the link should have (1 or 2; 0 = remove).
  final int count;

  /// What kind of reasoning gives the step.
  final BridgesHintKind kind;

  /// For [BridgesHintKind.forced] only: which reasoning made the bridge certain
  /// (null for the other kinds).
  final BridgesForcedWhy? why;

  @override
  String toString() =>
      'BridgesHint(island $island, $a-$b x$count, ${kind.name}'
      '${why == null ? '' : '/${why!.name}'})';
}

/// Computes hints; [BridgesRules.hint] is the public entry.
class BridgesHintEngine {
  BridgesHintEngine._();

  /// The next hint for [links] on [p]: a reasoning step when there is one (and it
  /// agrees with the solution), else the lowest solution link that is not placed with
  /// its full count. Null when the board already equals the solution.
  static BridgesHint? next(BridgesPuzzle p, List<BridgesLink> links) {
    final g = p.graph;
    final sol = _solutionCounts(p);
    final r = reason(p, links);
    if (r != null) {
      final id = g.pairId(r.a, r.b);
      final have = _correctCounts(g, links, sol);
      if (id >= 0 && r.count <= sol[id] && r.count > have[id]) return r;
    }
    return _fallback(p, links, sol);
  }

  /// The reasoning step alone (no fallback, no safety net): null when the rules find
  /// nothing. Exposed so tests can check the rules never contradict the solution.
  static BridgesHint? reason(BridgesPuzzle p, List<BridgesLink> links) {
    final g = p.graph;
    final n = g.islandCount, pc = g.pairs.length;
    if (n < 2) return null;
    final sol = _solutionCounts(p);
    final lo = _correctCounts(g, links, sol);
    final need = [for (final i in p.islands) i.need];
    // Bridges each island still needs, and per pair the most more it can take.
    final rem = Int32List(n);
    for (var i = 0; i < n; i++) {
      var s = 0;
      for (final q in g.incident[i]) {
        s += lo[q];
      }
      rem[i] = need[i] > s ? need[i] - s : 0;
    }
    final hi = Uint8List(pc);
    for (var q = 0; q < pc; q++) {
      final ra = rem[g.pairA[q]], rb = rem[g.pairB[q]];
      final m = lo[q] + (ra < rb ? ra : rb);
      hi[q] = m > 2 ? 2 : m;
    }
    // Pairs that could take bridges but for a bridge already drawn across them.
    final blocked = Uint8List(pc);
    for (var q = 0; q < pc; q++) {
      if (lo[q] != 0) continue;
      for (final x in g.crossers[q]) {
        if (lo[x] > 0) {
          if (hi[q] > 0) blocked[q] = 1;
          hi[q] = 0;
          break;
        }
      }
    }
    final cuts = BridgesCutFinder(g);
    for (var round = 0; round <= 2 * pc + 2; round++) {
      if (round == 0) {
        final h = _simple(g, need, lo, hi);
        if (h != null) return h;
      }
      final f = _degreeRaise(g, need, lo, hi, blocked, round > 0);
      if (f != null) return f;
      if (cuts.find(hi) && cuts.cutCount > 0) {
        var best = -1;
        for (var k = 0; k < cuts.cutCount; k++) {
          final q = cuts.cuts[k];
          if (lo[q] == 0 && (best < 0 || q < best)) best = q;
        }
        if (best >= 0) {
          return BridgesHint(
            island: g.pairA[best],
            a: g.pairA[best],
            b: g.pairB[best],
            count: 1,
            kind: BridgesHintKind.forced,
            why: BridgesForcedWhy.cutOff,
          );
        }
      }
      if (!_closeGroups(g, rem, lo, hi)) break;
    }
    return null;
  }

  /// Round-0 rules named after what a player sees: [BridgesHintKind.onlyNeighbour]
  /// first, then [BridgesHintKind.fullIsland].
  static BridgesHint? _simple(
    BridgesGraph g,
    List<int> need,
    Uint8List lo,
    Uint8List hi,
  ) {
    for (final full in [false, true]) {
      for (var i = 0; i < g.islandCount; i++) {
        var sl = 0, room = 0, open = 0, first = -1;
        for (final q in g.incident[i]) {
          sl += lo[q];
          if (hi[q] > lo[q]) {
            room += hi[q] - lo[q];
            open++;
            if (first < 0) first = q;
          }
        }
        final remI = need[i] - sl;
        if (remI <= 0) continue;
        if (!full && open == 1 && remI <= room) {
          return BridgesHint(
            island: i,
            a: g.pairA[first],
            b: g.pairB[first],
            count: lo[first] + remI,
            kind: BridgesHintKind.onlyNeighbour,
          );
        }
        if (full && open >= 2 && remI == room) {
          return BridgesHint(
            island: i,
            a: g.pairA[first],
            b: g.pairB[first],
            count: hi[first],
            kind: BridgesHintKind.fullIsland,
          );
        }
      }
    }
    return null;
  }

  /// Degree rule: the island's other pairs can give at most `Σhi − hi[q]`, so pair
  /// `q` must carry the rest. [afterSealing] is true once some upper bound was cut by
  /// the closed-group rule (so the step rests on that).
  static BridgesHint? _degreeRaise(
    BridgesGraph g,
    List<int> need,
    Uint8List lo,
    Uint8List hi,
    Uint8List blocked,
    bool afterSealing,
  ) {
    for (var i = 0; i < g.islandCount; i++) {
      var sh = 0, crossed = false;
      for (final q in g.incident[i]) {
        sh += hi[q];
        if (blocked[q] != 0) crossed = true;
      }
      for (final q in g.incident[i]) {
        final nl = need[i] - (sh - hi[q]);
        if (nl > lo[q]) {
          return BridgesHint(
            island: i,
            a: g.pairA[q],
            b: g.pairB[q],
            count: nl,
            kind: BridgesHintKind.forced,
            why: afterSealing
                ? BridgesForcedWhy.cutOff
                : crossed
                ? BridgesForcedWhy.crossing
                : BridgesForcedWhy.neighbours,
          );
        }
      }
    }
    return null;
  }

  /// Closed-group rule: if giving pair `q` all it can take would use up every bridge
  /// the merged group of islands still needs while other islands remain, that group
  /// would be sealed off — so `q` cannot take that many. Returns whether any upper
  /// bound shrank.
  static bool _closeGroups(
    BridgesGraph g,
    Int32List rem,
    Uint8List lo,
    Uint8List hi,
  ) {
    final n = g.islandCount;
    final root = List<int>.generate(n, (i) => i);
    int find(int x) {
      while (root[x] != x) {
        root[x] = root[root[x]];
        x = root[x];
      }
      return x;
    }

    for (var q = 0; q < g.pairs.length; q++) {
      if (lo[q] > 0) root[find(g.pairA[q])] = find(g.pairB[q]);
    }
    final left = Int32List(n), size = Int32List(n);
    for (var i = 0; i < n; i++) {
      final r = find(i);
      left[r] += rem[i];
      size[r]++;
    }
    var changed = false;
    for (var q = 0; q < g.pairs.length; q++) {
      if (hi[q] <= lo[q]) continue;
      final ra = find(g.pairA[q]), rb = find(g.pairB[q]);
      final total = ra == rb ? left[ra] : left[ra] + left[rb];
      final islands = ra == rb ? size[ra] : size[ra] + size[rb];
      if (islands < n && total - 2 * (hi[q] - lo[q]) == 0) {
        hi[q]--;
        changed = true;
      }
    }
    return changed;
  }

  /// The lowest solution link whose placed count differs from the solution's; when
  /// there is none, the lowest placed pair that is not in the solution (count 0).
  static BridgesHint? _fallback(
    BridgesPuzzle p,
    List<BridgesLink> links,
    Uint8List sol,
  ) {
    final g = p.graph;
    final placed = Uint8List(g.pairs.length);
    final stray = <int>[];
    for (final l in links) {
      final id = g.pairId(l.a, l.b);
      if (id < 0 || sol[id] == 0) {
        if (id >= 0) stray.add(id);
        continue;
      }
      if (l.count > placed[id]) placed[id] = l.count;
    }
    for (final l in p.solution) {
      final id = g.pairId(l.a, l.b);
      if (id >= 0 && placed[id] != l.count) {
        return BridgesHint(
          island: l.a,
          a: l.a,
          b: l.b,
          count: l.count,
          kind: BridgesHintKind.solution,
        );
      }
    }
    if (stray.isEmpty) return null;
    stray.sort();
    final q = stray.first;
    return BridgesHint(
      island: g.pairA[q],
      a: g.pairA[q],
      b: g.pairB[q],
      count: 0,
      kind: BridgesHintKind.solution,
    );
  }

  static Uint8List _solutionCounts(BridgesPuzzle p) {
    final g = p.graph;
    final sol = Uint8List(g.pairs.length);
    for (final l in p.solution) {
      final id = g.pairId(l.a, l.b);
      if (id >= 0) sol[id] = l.count;
    }
    return sol;
  }

  /// Placed bridges per pair, limited to what the solution contains.
  static Uint8List _correctCounts(
    BridgesGraph g,
    List<BridgesLink> links,
    Uint8List sol,
  ) {
    final c = Uint8List(g.pairs.length);
    for (final l in links) {
      final id = g.pairId(l.a, l.b);
      if (id < 0) continue;
      final v = l.count < sol[id] ? l.count : sol[id];
      if (v > c[id]) c[id] = v;
    }
    return c;
  }
}
