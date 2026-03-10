import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:caribtap/core/ui/ads/native_ad_widget.dart';

class AdsUtils {
  // Keep useTestAds=true until test devices are confirmed.
  // Do not click live ads during development.
  static const bool useTestAds = true;
  static const double _listingsNativeAdHeight = 280;
  static const double _dealsNativeAdHeight = 330;

  static const String _androidTestNativeUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _iosTestNativeUnitId =
      'ca-app-pub-3940256099942544/3986624511';

  static const String _androidListingsNativeUnitId =
      'ca-app-pub-4460203900531587/3631679974';
  static const String _iosListingsNativeUnitId =
      'ca-app-pub-4460203900531587/3413168069';

  static const String _androidDealsNativeUnitId =
      'ca-app-pub-4460203900531587/8070927945';
  static const String _iosDealsNativeUnitId =
      'ca-app-pub-4460203900531587/2100086392';

  static String _testNativeUnitId() {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosTestNativeUnitId
        : _androidTestNativeUnitId;
  }

  static String listingsNativeUnitId() {
    final adUnitId = useTestAds
        ? _testNativeUnitId()
        : defaultTargetPlatform == TargetPlatform.iOS
            ? _iosListingsNativeUnitId
            : _androidListingsNativeUnitId;
    debugPrint('AdsUtils selected listings ad unit: $adUnitId');
    return adUnitId;
  }

  static String dealsNativeUnitId() {
    final adUnitId = useTestAds
        ? _testNativeUnitId()
        : defaultTargetPlatform == TargetPlatform.iOS
            ? _iosDealsNativeUnitId
            : _androidDealsNativeUnitId;
    debugPrint('AdsUtils selected deals ad unit: $adUnitId');
    return adUnitId;
  }

  static Widget adsContainer({
    String? adUnitId,
    double height = _dealsNativeAdHeight,
  }) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      height: height,
      alignment: Alignment.center,
      child: NativeAdWidget(
        adUnitId: adUnitId ?? listingsNativeUnitId(),
        height: height,
      ),
    );
  }

  static Widget listingsInlineAd() {
    return adsContainer(
      adUnitId: listingsNativeUnitId(),
      height: _listingsNativeAdHeight,
    );
  }

  static Widget dealsFeedAd() {
    return adsContainer(
      adUnitId: dealsNativeUnitId(),
      height: _dealsNativeAdHeight,
    );
  }
}
