// Test helpers for the Bridges engine: two solvers written independently of the engine's
// own (no propagation, no shared search code), so tests can check the engine against
// something that is obviously right.
//
//  * [bruteForce] tries every 0/1/2 assignment of the visible pairs (tiny puzzles only);
//    each rule can be switched off to show what it contributes.
//  * [referenceCount] is a plain depth-first search over the pairs in order with only
//    degree pruning — fast enough for the largest generated puzzles.
//
// Not named `*_test.dart` so the test runner does not pick it up as a test.

import 'package:focus_and_play_mindgame/games/bridges/bridges.dart';

/// Every arrangement of bridges that gives each island exactly its number, optionally
/// also joined into one group ([requireConnected]) and without crossings
/// ([forbidCrossing]). Only for puzzles with about a dozen pairs.
List<List<BridgesLink>> bruteForce(
  BridgesPuzzle p, {
  bool requireConnected = true,
  bool forbidCrossing = true,
}) {
  final g = p.graph;
  final pairs = g.pairs.length;
  final cur = List<int>.filled(pairs, 0);
  final out = <List<BridgesLink>>[];
  void rec(int i) {
    if (i == pairs) {
      final got = List<int>.filled(p.islands.length, 0);
      for (var q = 0; q < pairs; q++) {
        got[g.pairA[q]] += cur[q];
        got[g.pairB[q]] += cur[q];
      }
      for (var k = 0; k < got.length; k++) {
        if (got[k] != p.islands[k].need) return;
      }
      if (forbidCrossing) {
        for (var q = 0; q < pairs; q++) {
          if (cur[q] == 0) continue;
          for (final x in g.crossers[q]) {
            if (cur[x] > 0) return;
          }
        }
      }
      final links = [
        for (var q = 0; q < pairs; q++)
          if (cur[q] > 0) BridgesLink(g.pairA[q], g.pairB[q], cur[q]),
      ];
      if (requireConnected && !BridgesRules.connected(p, links)) return;
      out.add(links);
      return;
    }
    for (var v = 0; v <= 2; v++) {
      cur[i] = v;
      rec(i + 1);
    }
    cur[i] = 0;
  }

  rec(0);
  return out;
}

/// Number of solutions of [p] (stopping at [limit]) by plain depth-first search with
/// degree pruning, a crossing test and a final connectivity test.
int referenceCount(BridgesPuzzle p, {int limit = 3}) {
  final n = p.islands.length;
  final pairs = p.graph.pairs;
  final need = [for (final i in p.islands) i.need];
  final got = List<int>.filled(n, 0);
  final left = List<int>.filled(n, 0); // pairs of each island not decided yet
  for (final (a, b) in pairs) {
    left[a]++;
    left[b]++;
  }
  final cnt = List<int>.filled(pairs.length, 0);
  var found = 0;

  bool crosses(int q) {
    for (var x = 0; x < q; x++) {
      if (cnt[x] > 0 &&
          BridgesRules.cross(
            p,
            pairs[q].$1,
            pairs[q].$2,
            pairs[x].$1,
            pairs[x].$2,
          )) {
        return true;
      }
    }
    return false;
  }

  void rec(int q) {
    if (found >= limit) return;
    if (q == pairs.length) {
      for (var i = 0; i < n; i++) {
        if (got[i] != need[i]) return;
      }
      final links = [
        for (var x = 0; x < pairs.length; x++)
          if (cnt[x] > 0) BridgesLink(pairs[x].$1, pairs[x].$2, cnt[x]),
      ];
      if (BridgesRules.connected(p, links)) found++;
      return;
    }
    final (a, b) = pairs[q];
    left[a]--;
    left[b]--;
    for (var v = 0; v <= 2; v++) {
      cnt[q] = v;
      if (v > 0 && crosses(q)) continue;
      got[a] += v;
      got[b] += v;
      if (got[a] <= need[a] &&
          got[b] <= need[b] &&
          got[a] + 2 * left[a] >= need[a] &&
          got[b] + 2 * left[b] >= need[b]) {
        rec(q + 1);
      }
      got[a] -= v;
      got[b] -= v;
    }
    cnt[q] = 0;
    left[a]++;
    left[b]++;
  }

  rec(0);
  return found;
}
