// Where to go after a celebration: the next level (through the out-of-lives
// screen or a quick ad break when due), or Home after the daily / last level.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service.dart';
import '../../core/router/app_router.dart';
import '../../domain/level_config.dart';
import '../../domain/tier.dart';
import '../../state/save_controller.dart';

void goToNextLevel(BuildContext context, WidgetRef ref, LevelSpec done) {
  if (done.isDaily || done.level >= Levels.perIsland) {
    context.go(Routes.home);
    return;
  }
  final next = LevelConfig.forLevel(done.game, done.level + 1);
  final save = ref.read(saveProvider.notifier);
  save.normaliseEconomy();
  final relaxed = ref.read(settingsProvider).relaxed;
  if (!relaxed && save.economyNow.lives <= 0) {
    context.pushReplacement(Routes.outOfLives, extra: next);
    return;
  }
  final route = Routes.play(next.game, next.level);
  if (save.interstitialDue() && ref.read(adServiceProvider).interstitialReady) {
    context.pushReplacement(Routes.adBreak, extra: route);
  } else {
    context.pushReplacement(route);
  }
}
