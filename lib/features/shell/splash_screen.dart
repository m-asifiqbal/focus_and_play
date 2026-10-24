// Short animated splash: the four-isles logo pops in, then we route to
// onboarding (first launch) or Home. Also kicks off ads consent + reminders.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service.dart';
import '../../core/constants/app_info.dart';
import '../../core/notifications/reminder_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../state/save_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    final save = ref.read(saveProvider.notifier);
    save.countSession();
    save.normaliseEconomy();
    _autoBackup();
    // Just long enough for the logo to pop in (~0.9 s); the save is already loaded.
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final onboarded = ref.read(saveProvider).profile.onboarded;
      context.go(onboarded ? Routes.home : Routes.welcome);
      if (onboarded) {
        unawaited(ref.read(adServiceProvider).start());
        unawaited(
          ref
              .read(reminderServiceProvider)
              .sync(ref.read(saveProvider), ref.read(clockProvider)()),
        );
      }
    });
  }

  /// One automatic backup per day (or week) on launch, kept on the phone.
  Future<void> _autoBackup() async {
    final s = ref.read(saveProvider);
    if (!s.settings.autoBackup || !s.profile.onboarded) return;
    final store = ref.read(saveStoreProvider);
    final now = ref.read(clockProvider)();
    try {
      final list = await store.listBackups();
      final last = list
          .where((b) => b.automatic)
          .map((b) => b.createdAt)
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
      final gap = s.settings.backupWeekly
          ? const Duration(days: 7)
          : const Duration(hours: 20);
      if (last == null || now.difference(last) >= gap) {
        await store.writeLocalBackup(s, now, automatic: true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.disableAnimationsOf(context);
    Widget square(Color c, int i) {
      final w = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(14),
        ),
      );
      return instant
          ? w
          : w.animate().scale(
              delay: (120 * i).ms,
              duration: 500.ms,
              curve: Curves.easeOutBack,
              begin: Offset.zero,
            );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF13213C),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          square(const Color(0xFFF0582A), 0),
                          const SizedBox(width: 8),
                          square(const Color(0xFF1F9D55), 1),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          square(const Color(0xFF8A4FD8), 2),
                          const SizedBox(width: 8),
                          square(const Color(0xFF1E9BDC), 3),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC233),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF13213C),
                        width: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppInfo.name,
              style: MiText.hero.copyWith(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'A puzzle island for every mind',
              style: MiText.body.copyWith(
                color: const Color(0xFFC9D6EA),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
