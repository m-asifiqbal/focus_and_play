// AdMob unit ids. Defaults are Google's public TEST units, so development builds
// never serve real ads (clicking your own live ads can get an account banned).
//
// For release, put your own ids in config/admob.json and build with
//   flutter build apk --release --dart-define-from-file=config/admob.json
// (the same file sets the Android app id; iOS's is in Info.plist — docs/ads.md).

import 'dart:io';

abstract final class AdIds {
  static const _bannerAndroid = String.fromEnvironment('ADMOB_BANNER_ANDROID', defaultValue: 'ca-app-pub-3940256099942544/9214589741');
  static const _bannerIos = String.fromEnvironment('ADMOB_BANNER_IOS', defaultValue: 'ca-app-pub-3940256099942544/2435281174');
  static const _interAndroid = String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID', defaultValue: 'ca-app-pub-3940256099942544/1033173712');
  static const _interIos = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS', defaultValue: 'ca-app-pub-3940256099942544/4411468910');
  static const _rewardAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID', defaultValue: 'ca-app-pub-3940256099942544/5224354917');
  static const _rewardIos = String.fromEnvironment('ADMOB_REWARDED_IOS', defaultValue: 'ca-app-pub-3940256099942544/1712485313');

  static String get banner => Platform.isIOS ? _bannerIos : _bannerAndroid;
  static String get interstitial => Platform.isIOS ? _interIos : _interAndroid;
  static String get rewarded => Platform.isIOS ? _rewardIos : _rewardAndroid;
}
