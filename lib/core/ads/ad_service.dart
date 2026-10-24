// AdMob: consent (UMP), a preloaded interstitial and rewarded ad, and the banner slot.
//
// Rules (see the design canvas): banners only on Home, island maps and Insights;
// an interstitial only after a solved level, behind a "Quick break" card and the
// pacing in SaveController.interstitialDue; rewarded ads only when the player
// chooses (extra life / extra hint). Content rating is capped at G because the
// game is for all ages.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/app_theme.dart';
import '../theme/mi_colors.dart';
import 'ad_ids.dart';

class AdService {
  /// Off in tests and on platforms without the plugin.
  static bool enabled =
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  bool _starting = false;
  bool _canRequest = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInter = false, _loadingReward = false;
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Asks for consent where the law requires it, then starts the SDK and preloads.
  /// Safe to call again (e.g. on resume): it does nothing once ads are ready,
  /// and retries when an earlier attempt failed (no network at launch).
  Future<void> start() async {
    if (!enabled || _starting || ready.value) return;
    _starting = true;
    try {
      await _start();
    } finally {
      _starting = false;
    }
  }

  Future<void> _start() async {
    final done = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          if (!done.isCompleted) done.complete();
        },
        (_) {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
      _canRequest = await ConsentInformation.instance.canRequestAds();
      if (!_canRequest) return;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
      await MobileAds.instance.initialize();
      ready.value = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (_) {
      // No ads is fine; the game never depends on them.
    }
  }

  /// Whether Settings should show "Ad privacy choices".
  Future<bool> privacyOptionsRequired() async {
    if (!enabled) return false;
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptions() async {
    if (!enabled) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
      _canRequest = await ConsentInformation.instance.canRequestAds();
    } catch (_) {}
  }

  void _loadInterstitial() {
    if (!_canRequest || _loadingInter || _interstitial != null) return;
    _loadingInter = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInter = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (_) => _loadingInter = false,
      ),
    );
  }

  void _loadRewarded() {
    if (!_canRequest || _loadingReward || _rewarded != null) return;
    _loadingReward = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingReward = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (_) => _loadingReward = false,
      ),
    );
  }

  /// Shows the interstitial if one is ready. Completes after it closes (or at once).
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        if (!closed.isCompleted) closed.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    await ad.show();
    return closed.future;
  }

  bool get rewardedReady => _rewarded != null;
  bool get interstitialReady => _interstitial != null;

  /// Shows a rewarded ad; true only when the player earned the reward.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (!closed.isCompleted) closed.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadRewarded();
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return closed.future;
  }
}

final adServiceProvider = Provider<AdService>((ref) => AdService());

/// Bottom banner slot. Keeps its height while loading so nothing shifts.
class BannerAdSlot extends ConsumerStatefulWidget {
  const BannerAdSlot({super.key});
  @override
  ConsumerState<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends ConsumerState<BannerAdSlot> {
  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (AdService.enabled && _width != w) {
      _width = w;
      _load(w);
    }
  }

  Future<void> _load(int width) async {
    final svc = ref.read(adServiceProvider);
    if (!svc.ready.value) {
      void retry() {
        svc.ready.removeListener(retry);
        if (mounted) _load(width);
      }

      svc.ready.addListener(retry);
      return;
    }
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width) ??
        AdSize.banner;
    if (!mounted) return;
    // Take the old banner out of the tree before disposing it (width change).
    final old = _ad;
    if (old != null) {
      setState(() {
        _ad = null;
        _loaded = false;
      });
      await old.dispose();
      if (!mounted) return;
    }
    final ad = BannerAd(
      size: size,
      adUnitId: AdIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, _) => a.dispose(),
      ),
    );
    setState(() {
      _ad = ad;
      _size = size;
      _loaded = false;
    });
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = (_size?.height ?? 50).toDouble();
    if (_loaded && _ad != null) {
      return SizedBox(
        width: _size!.width.toDouble(),
        height: h,
        child: AdWidget(ad: _ad!),
      );
    }
    final c = context.mi;
    // Placeholder with the ad's footprint (also what tests and the first launch show).
    return Semantics(
      label: 'Advertisement space',
      child: Container(
        height: h,
        width: 320,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.isNight ? const Color(0xFF1A2740) : c.sunk,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('Ad', style: MiText.caption.copyWith(color: c.inkSoft)),
      ),
    );
  }
}
