# Ads (AdMob)

AdMob is the app's only network use. Everything else works offline.

## Where ads appear

| Ad | Where | Rule |
|---|---|---|
| Banner (adaptive, anchored) | Home, island maps, Insights | Under the content, above the tab bar, with clear space around it. Never on a puzzle board, a celebration, a sheet or onboarding. The slot keeps its height while loading, so nothing jumps. |
| Interstitial | After a **solved** level, when the player taps *Next level* | Shown behind a 3-second "Quick break" card. At most once every 3 solves **and** 4 minutes, never in the first app session, never mid-puzzle, never when the next stop is the out-of-lives screen. Skipped if no ad is loaded (the player just goes on). Rule lives in `SaveController.interstitialDue()` and `features/results/result_flow.dart`. |
| Rewarded | Out of lives → +1 life; out of hints → +1 hint | Always the player's choice. |

Content is capped at rating **G** (`RequestConfiguration(maxAdContentRating: G)`), because the game is for all ages.

## Consent

`AdService.start()` asks Google's User Messaging Platform for consent (EEA/UK and other regions that need it) before the SDK starts. Settings › *Ad privacy choices* appears when the region requires it and reopens the form.

## Before release: use your own ids

Development builds use Google's **test** ids, so you never click your own live ads.

1. In AdMob, create the app (Android and iOS) and three ad units per platform: banner, interstitial, rewarded.
2. Put your ids in `config/admob.json` (git-ignored; copy `config/admob.example.json`, which holds the test ids). It sets the Android **app id** in the manifest (via `android/app/build.gradle.kts`) and every **unit id** (`lib/core/ads/ad_ids.dart`). Leave a key out to keep its test id; don't leave a value empty.
3. Build with it:

```
flutter build apk --release --dart-define-from-file=config/admob.json
flutter build appbundle --release --dart-define-from-file=config/admob.json
```

Without `--dart-define-from-file` the build uses the test ids, which is right for `flutter run`.

4. iOS: the app id isn't read from the config file. Put it in `ios/Runner/Info.plist` → `GADApplicationIdentifier`, and add Google's full `SKAdNetworkItems` list (only Google's own id is there now).

**Release signing (Android)**: create `android/key.properties` (git-ignored) with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`, as in FocusFlow. Without it, release builds are signed with the debug key: they install fine but Google Play rejects them.

## Google Play "Families" note

If the store listing's target audience includes **children under 13**, Google Play's Families policy applies:
- Only Families-certified ad SDKs (AdMob is), with child-directed treatment configured in AdMob.
- No personalised ads for children.

If you target 13+ only, the G rating cap is still a good default for an all-ages puzzle game. Decide this before the first release; it affects the Play Console content questionnaire.
