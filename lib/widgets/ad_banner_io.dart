import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_config.dart';
import '../services/ad_platform.dart';

class AppBannerAd extends StatefulWidget {
  const AppBannerAd({super.key, this.enabled = AdConfig.enabled});

  final bool enabled;

  @override
  State<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends State<AppBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled &&
        AdConfig.hasAndroidBanner &&
        AdPlatform.canUseMobileAds) {
      _loadAd();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    try {
      final ad = BannerAd(
        size: AdSize.banner,
        adUnitId: AdConfig.androidBannerAdUnitId.trim(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!mounted) {
              return;
            }
            setState(() {
              _failed = true;
            });
          },
        ),
        request: const AdRequest(),
      );
      unawaited(
        ad.load().catchError((Object error, StackTrace stackTrace) {
          ad.dispose();
          _reportAdError(error, stackTrace);
        }),
      );
    } catch (error, stackTrace) {
      _reportAdError(error, stackTrace);
    }
  }

  void _reportAdError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'google_mobile_ads',
        context: ErrorDescription('loading the bottom banner ad'),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        !AdConfig.hasAndroidBanner ||
        !AdPlatform.canUseMobileAds ||
        _failed) {
      return const SizedBox.shrink();
    }

    if (_isLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return SizedBox(height: AdSize.banner.height.toDouble());
  }
}
