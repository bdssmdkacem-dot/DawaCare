import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

class DawaCareBanner extends StatefulWidget {
  final String productionAdUnitId;

  const DawaCareBanner({
    super.key,
    required this.productionAdUnitId,
  });

  @override
  State<DawaCareBanner> createState() => _DawaCareBannerState();
}

class _DawaCareBannerState extends State<DawaCareBanner> {
  BannerAd? _bannerAd;
  AdSize? _adSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0 || _bannerAd != null) return;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;

    final ad = BannerAd(
      adUnitId: AdService.instance.bannerUnitId(widget.productionAdUnitId),
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          debugPrint('DawaCare banner load failed: $error');
          ad.dispose();
          if (mounted) setState(() {});
        },
      ),
    );

    setState(() {
      _adSize = size;
      _bannerAd = ad;
    });
    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    final size = _adSize;
    if (ad == null || size == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: size.height.toDouble(),
        child: Center(child: AdWidget(ad: ad)),
      ),
    );
  }
}
