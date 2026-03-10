import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
    required this.adUnitId,
    this.height = 330,
  });

  final String adUnitId;
  final double height;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  final Completer<NativeAd> _nativeAdCompleter = Completer<NativeAd>();

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _nativeAdCompleter.completeError(
        Exception('Native ads are not supported on web.'),
      );
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      factoryId: 'adFactoryExample',
      customOptions: const <String, Object>{},
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('Native ad loaded: ${widget.adUnitId}');
          _nativeAdCompleter.complete(ad as NativeAd);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          debugPrint('Native ad failed to load for ${widget.adUnitId}: $error');
          _nativeAdCompleter.completeError(error);
        },
      ),
    );

    Future<void>.delayed(const Duration(seconds: 1), () {
      try {
        debugPrint('Loading native ad: ${widget.adUnitId}');
        _nativeAd?.load();
      } catch (error) {
        debugPrint('Native ad load threw for ${widget.adUnitId}: $error');
        if (!_nativeAdCompleter.isCompleted) {
          _nativeAdCompleter.completeError(error);
        }
      }
    });
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: FutureBuilder<NativeAd>(
        future: _nativeAdCompleter.future,
        builder: (BuildContext context, AsyncSnapshot<NativeAd> snapshot) {
          Widget child;

          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
            case ConnectionState.active:
              child = const SizedBox.shrink();
              break;
            case ConnectionState.done:
              if (snapshot.hasData && _nativeAd != null) {
                child = SizedBox(
                  width: double.infinity,
                  height: widget.height,
                  child: AdWidget(ad: _nativeAd!),
                );
              } else {
                child = Center(
                  child: Text('Error loading native ad'.tr()),
                );
              }
              break;
          }

          return Container(
            width: double.infinity,
            height: widget.height,
            alignment: Alignment.center,
            child: child,
          );
        },
      ),
    );
  }
}
