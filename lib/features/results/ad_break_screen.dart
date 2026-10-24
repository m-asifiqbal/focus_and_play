// "Quick break": warns that a short ad comes next, counts down 3 s, shows the
// interstitial, then opens the next level.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ad_service.dart';
import '../../core/constants/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/mi_buttons.dart';
import '../../state/save_controller.dart';

class AdBreakScreen extends ConsumerStatefulWidget {
  const AdBreakScreen({super.key, required this.next});
  final String next;
  @override
  ConsumerState<AdBreakScreen> createState() => _AdBreakScreenState();
}

class _AdBreakScreenState extends ConsumerState<AdBreakScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _count = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
  bool _going = false;

  @override
  void initState() {
    super.initState();
    _count.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go();
    });
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_going) return;
    _going = true;
    final shown = await ref.read(adServiceProvider).showInterstitial();
    if (shown) ref.read(saveProvider.notifier).markInterstitialShown();
    if (mounted) context.pushReplacement(widget.next);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF13213C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              SizedBox(
                width: 128,
                height: 128,
                child: AnimatedBuilder(
                  animation: _count,
                  builder: (context, _) => Stack(alignment: Alignment.center, children: [
                    SizedBox.expand(child: CircularProgressIndicator(value: 1 - _count.value, strokeWidth: 10, color: const Color(0xFFFFC233), backgroundColor: const Color(0xFF24324D))),
                    Text('${(3 - _count.value * 3).ceil().clamp(1, 3)}', style: MiText.hero.copyWith(color: Colors.white, fontSize: 52)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Text('Quick break', style: MiText.display.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text("A short ad plays next, then you're straight back in.", textAlign: TextAlign.center, style: MiText.body.copyWith(color: const Color(0xFFC9D6EA), fontSize: 17)),
              const Spacer(),
              Text('Ads keep ${AppInfo.name} free. You\'ll never see one in the middle of a puzzle.', textAlign: TextAlign.center, style: MiText.small.copyWith(color: const Color(0xFFB5C3D9))),
              const SizedBox(height: 14),
              MiButton(label: 'Continue', color: const Color(0xFF24324D), ledge: const Color(0xFF0A1328), onTap: _go),
            ]),
          ),
        ),
      ),
    );
  }
}
