# Mind Isles

An offline puzzle game for all ages: four islands, four puzzles, 60 levels each from Easy to Expert, plus a daily puzzle.

| Island | Puzzle | Rule |
|---|---|---|
| Ember Isle | **Thread** | One path through every square, passing the numbers in order. |
| Meadow Isle | **Quilt** | Split the field into rectangles; each patch holds one clue (its size or shape). |
| Crystal Isle | **Twist** | Trace hidden words through neighbouring letter tiles; every tile is used once. |
| Frost Isle | **Sudoku Six** | 6 × 6 sudoku with 2 × 3 boxes. |

"Mind Isles" is a working title. It lives in `lib/core/constants/app_info.dart`.

Design canvas: https://claude.ai/artifact/WRdJQoeZueXJsnKGqpk4GY

## Run

```
flutter pub get
flutter run
```

Tests (about 120, around 10 s):

```
flutter test --no-pub
```

`test/features/screens_capture_test.dart` also writes a PNG of every main screen to `build/screens/` so the screens can be checked without a device.

Release build (your AdMob ids in the git-ignored `config/admob.json`; see [docs/ads.md](docs/ads.md)):

```
flutter build apk --release --dart-define-from-file=config/admob.json
```

## How it plays

- **Lives and clock**: 3 lives, shared across islands. Each life has its own clock. When it runs out you lose a life, keep your board and get a fresh clock. One life refills every 20 minutes. Replaying a level you already solved (or today's daily again) never costs a life, so it works with no lives left.
- **Twist's free letter**: the first word starts with its first letter showing, and every word you find reveals the first letter of the next one (shortest first). It isn't a hint and doesn't cost the no-hint star.
- **Hints**: 3 free a day, plus rewards from chests, achievements and rewarded ads. A hint never costs a life, only the "no hints" star.
- **Stars**: solve (1) + beat par (2) + no hints (3). Relaxed mode (Settings) turns off the clock and lives and caps each level at one star.
- **Tiers**: Easy 1–15, Medium 16–30, Hard 31–45, Expert 46–60. The last level of each tier opens a chest of hints.
- **Generation**: every level is built from a fixed seed, so every phone gets the same level 34 and nothing needs the network. Every puzzle is checked to have exactly one solution. Difficulty tuning (board sizes, par times, clocks) is in `lib/domain/level_config.dart`.

## Structure

```
lib/
  games/<thread|quilt|twist|sudoku>/   pure-Dart engines: generator, solver, rules (see docs/engines.md)
  domain/                              save model, rules (lives/hints/stars/streak), levels, achievements, insights
  state/save_controller.dart           the one Riverpod Notifier over the save game
  core/                                theme, widgets, storage, ads, reminders, sounds/haptics, router
  features/                            onboarding, home, island (map painter), play (frame + boards), results, insights, settings
```

- **State**: Riverpod 2.6, no codegen.
- **Navigation**: go_router, with the 3 tabs in a `StatefulShellRoute`.
- **Storage**: one JSON save file, written atomically, plus `.mindisles` backups.

## Before release

- **AdMob**: replace the test ids and decide the Families-policy question; both are covered in [docs/ads.md](docs/ads.md).
- **Application id**: `com.iqballabs.focus_and_play` is set in `android/app/build.gradle.kts` (Android) and `com.iqballabs.focusAndPlay` in the Xcode project (iOS bundle ids can't contain underscores). It is permanent once the app is on Google Play.
- **Signing**: until `android/key.properties` exists, the release build is signed with the debug key. Add your upload key there, as in the FocusFlow project.
- **App icon**: the four-isles logo on navy, drawn by `dart tool/icon/generate.dart`. It writes the Android legacy and adaptive icons (with a monochrome layer for themed icons), the iOS set and `store/play_icon_512.png` for the Play listing. Re-run it if the logo changes.
- **Sounds**: the files in `assets/sounds/` are synthesised placeholders with no licence issues. Swap them for your own if you like. There is no music.
