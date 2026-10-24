// Root widget: theme from Settings (Day / Night / System), reduce-motion from
// Settings or the phone, and lifecycle hooks (refill lives, re-plan reminders,
// flush the save when the app goes to the background, retry starting ads).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ads/ad_service.dart';
import 'core/constants/app_info.dart';
import 'core/notifications/reminder_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/mi_colors.dart';
import 'domain/save_data.dart';
import 'state/save_controller.dart';

class MindIslesApp extends ConsumerStatefulWidget {
  const MindIslesApp({super.key});
  @override
  ConsumerState<MindIslesApp> createState() => _MindIslesAppState();
}

class _MindIslesAppState extends ConsumerState<MindIslesApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final save = ref.read(saveProvider.notifier);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      save.flush();
      ref.read(reminderServiceProvider).sync(ref.read(saveProvider), ref.read(clockProvider)());
    } else if (state == AppLifecycleState.resumed) {
      save.normaliseEconomy();
      // Ads can't start when the game is opened offline; try again now.
      if (ref.read(saveProvider).profile.onboarded) ref.read(adServiceProvider).start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final theme = ref.watch(settingsProvider.select((s) => s.theme));
    final reduce = ref.watch(settingsProvider.select((s) => s.reduceMotion));
    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.build(MiColors.day),
      darkTheme: AppTheme.build(MiColors.night),
      themeMode: switch (theme) {
        ThemeChoice.day => ThemeMode.light,
        ThemeChoice.night => ThemeMode.dark,
        ThemeChoice.system => ThemeMode.system,
      },
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final night = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: night ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: MediaQuery(
            // One switch for every animation in the app: the phone's setting or ours.
            data: mq.copyWith(
              disableAnimations: mq.disableAnimations || reduce,
              textScaler: mq.textScaler.clamp(minScaleFactor: .85, maxScaleFactor: 1.3),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}
