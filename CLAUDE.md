# CLAUDE.md — Mind Isles

Offline puzzle game (Android + iOS): four islands, each with one puzzle (Thread, Quilt, Twist, Sudoku Six), 60 levels in four tiers, a daily puzzle, lives/clock/hints, Insights, Settings, local backup. Design canvas: https://claude.ai/artifact/WRdJQoeZueXJsnKGqpk4GY

## Rules
1. **Offline first.** The only network code is AdMob (`lib/core/ads/`). No analytics, no accounts, no other network packages.
2. **Engines are pure Dart and deterministic** (`lib/games/*`): no Flutter imports, only the seeded `Random` they are given, iteration/node limits (never wall-clock). Every puzzle must have exactly one solution. Contract: `docs/engines.md`. Never change `LevelConfig.levelSeed` (it would change every published level).
3. **One save document** (`lib/domain/save_data.dart`), one Notifier (`lib/state/save_controller.dart`). UI watches slices of it; game rules (lives refill, hints, stars, streak) live in `lib/domain/rules.dart` as pure functions of (state, now). Anything new the player can lose must be in `SaveData` so backups carry it.
4. **No hard-coded colours in features**: `context.mi` (MiColors, Day/Night) and `context.island(game)` (IslandStyle). Text styles: `MiText`. Fonts are bundled (Fredoka, Nunito).
5. **Ads only where docs/ads.md says** — never on a board, celebration, sheet or onboarding.
6. **Accessibility**: semantics label on icon-only controls, ≥ 44 pt targets, honour reduce motion (`MediaQuery.disableAnimationsOf` — the app folds the Settings switch into it).

## Commands
```
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
dart format <changed files only>
```
App icons (Android legacy + adaptive + monochrome, iOS, Play 512) are generated: `dart tool/icon/generate.dart` (no packages; `--out <dir>` to preview).
`android/gradle.properties` sets `kotlin.incremental=false`: the project (E:) and the pub cache (C:) are on different drives, which breaks Kotlin's incremental cache — keep it.
**Release builds must be run, not just built.** Widget tests and debug builds don't run R8; the first release APK crashed at launch because R8 stripped WorkManager's Room constructor (pulled in by AdMob). Keep `android/app/proguard-rules.pro`, and after adding a native plugin, install `flutter build apk --release --dart-define-from-file=config/admob.json` on a device/emulator and check `adb logcat -b crash`. The emulator (`Pixel_3a_API_34_extension_level_7_x86_64`) boots with `-gpu swiftshader_indirect -no-snapshot` when no Gradle build is running.
In tests, puzzles generate synchronously (`FLUTTER_TEST`); on devices they run in `Isolate.run`, so closures passed there must only capture sendable data.
Screens can be checked without a device: `flutter test --no-pub test/features/screens_capture_test.dart` writes `build/screens/*.png` (fonts loaded, real router, sample save from `test/helpers/app_harness.dart`). In tests, shadows render as solid black outlines — that's the test renderer, not a bug.

## Conventions
- Imports in lib use relative paths within a feature and `../../` across; tests import `package:focus_and_play_mindgame/...`.
- Header comment per file (what / why); explain why, not what. Keep files under ~400 lines.
- New board = a `BoardController` subclass + widget in `lib/features/boards/`, registered in `features/play/puzzle_factory.dart`.
- Destructive actions confirm first (reset progress, restore backup, leave a level after playing).
