// Sleuth puzzle model tests: the JSON round trip and the checks on saved data.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_and_play_mindgame/games/sleuth/sleuth.dart';

const _sample = SleuthPuzzle(
  theme: 'Ocean',
  length: 5,
  words: ['BEACH', 'CORAL', 'OCEAN', 'SHARK', 'WATER', 'WHALE'],
  secret: 3,
  tries: 4,
  assist: false,
);

void main() {
  test('answer is the secret word', () {
    expect(_sample.answer, 'SHARK');
  });

  test('JSON round trip keeps everything', () {
    final text = jsonEncode(_sample.toJson());
    final q = SleuthPuzzle.fromJson(jsonDecode(text) as Map<String, Object?>);
    expect(jsonEncode(q.toJson()), text);
    expect(q.theme, 'Ocean');
    expect(q.length, 5);
    expect(q.words, _sample.words);
    expect(q.secret, 3);
    expect(q.tries, 4);
    expect(q.assist, isFalse);
    expect(q.answer, 'SHARK');
  });

  test('restored word list is read-only; toJson copies it', () {
    final q = SleuthPuzzle.fromJson(_sample.toJson());
    expect(() => q.words.add('X'), throwsUnsupportedError);
    final json = _sample.toJson();
    (json['words']! as List).add('EXTRA');
    expect(_sample.words.length, 6);
  });

  test('a missing assist flag defaults to on', () {
    final json = _sample.toJson()..remove('assist');
    expect(SleuthPuzzle.fromJson(json).assist, isTrue);
  });

  test('inconsistent data is rejected with FormatException', () {
    Map<String, Object?> withField(String key, Object? value) =>
        _sample.toJson()..[key] = value;
    expect(
      () => SleuthPuzzle.fromJson(withField('secret', 6)),
      throwsFormatException,
    );
    expect(
      () => SleuthPuzzle.fromJson(withField('secret', -1)),
      throwsFormatException,
    );
    expect(
      () => SleuthPuzzle.fromJson(withField('words', <String>[])),
      throwsFormatException,
    );
    expect(
      () => SleuthPuzzle.fromJson(withField('length', 4)),
      throwsFormatException,
    );
    expect(
      () => SleuthPuzzle.fromJson(withField('tries', 0)),
      throwsFormatException,
    );
  });

  test('params default to assist on', () {
    const p = SleuthParams(length: 5, candidates: 8, tries: 5);
    expect(p.assist, isTrue);
    expect(
      const SleuthParams(
        length: 5,
        candidates: 8,
        tries: 5,
        assist: false,
      ).assist,
      isFalse,
    );
  });
}
