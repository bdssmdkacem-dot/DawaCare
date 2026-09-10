import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  static const String appId = 'ca-app-pub-1377346158677931~8717689654';

  static const String homeBannerId =
      'ca-app-pub-1377346158677931/6914005046';
  static const String medicinesBannerId =
      'ca-app-pub-1377346158677931/9559998036';
  static const String navigationInterstitialId =
      'ca-app-pub-1377346158677931/7373170046';

  static const String _testBannerId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  // Keep test ads on by default for development/APK testing. Production ads
  // are enabled explicitly with --dart-define=DAWACARE_TEST_ADS=false.
  static const bool useTestAds = bool.fromEnvironment(
    'DAWACARE_TEST_ADS',
    defaultValue: true,
  );

  InterstitialAd? _interstitialAd;
  bool _loadingInterstitial = false;
  DateTime? _lastInterstitialShown;

  String bannerUnitId(String productionId) {
    return useTestAds ? _testBannerId : productionId;
  }

  String get interstitialUnitId =>
      useTestAds ? _testInterstitialId : navigationInterstitialId;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (_loadingInterstitial || _interstitialAd != null) return;
    _loadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('DawaCare interstitial show failed: $error');
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('DawaCare interstitial load failed: $error');
        },
      ),
    );
  }

  Future<bool> showNavigationInterstitial() async {
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }

    final lastShown = _lastInterstitialShown;
    if (lastShown != null &&
        DateTime.now().difference(lastShown) < const Duration(minutes: 3)) {
      return false;
    }

    _interstitialAd = null;
    _lastInterstitialShown = DateTime.now();
    ad.show();
    _loadInterstitial();
    return true;
  }
}
