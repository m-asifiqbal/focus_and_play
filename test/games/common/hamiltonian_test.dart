import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/common/hamiltonian.dart';

void main() {
  test('random paths are Hamiltonian for many sizes and seeds', () {
    for (final (r, c) in [(4, 4), (5, 5), (6, 6), (7, 7), (5, 6), (8, 8)]) {
      for (var seed = 0; seed < 30; seed++) {
        final p = randomHamiltonianPath(r, c, Random(seed));
        expect(isHamiltonianPath(p, r, c), isTrue, reason: '$r x $c seed $seed');
      }
    }
  });

  test('same seed gives the same path, different seeds differ', () {
    final a = randomHamiltonianPath(6, 6, Random(7));
    final b = randomHamiltonianPath(6, 6, Random(7));
    final c = randomHamiltonianPath(6, 6, Random(8));
    expect(a, b);
    expect(a, isNot(c));
  });
}
