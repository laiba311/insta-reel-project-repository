import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdWidget extends StatefulWidget {
  const InterstitialAdWidget({super.key});

  @override
  State<InterstitialAdWidget> createState() => _InterstitialAdWidgetState();
}

class _InterstitialAdWidgetState extends State<InterstitialAdWidget> {
  InterstitialAd? _interstitialAd;
  int numMaxAdAttempts = 0;
  final String adUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test ID

  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          numMaxAdAttempts = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _createInterstitialAd();
            },
            onAdFailedToShowFullScreenContent:
                (InterstitialAd ad, AdError error) {
              ad.dispose();
              _createInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          numMaxAdAttempts += 1;
          if (numMaxAdAttempts <= 3) {
            _createInterstitialAd();
          }
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _createInterstitialAd();
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  void showAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      _createInterstitialAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Interstitial Ad Example')),
      body: Center(
        child: ElevatedButton(
          onPressed: showAd,
          child: const Text('Show Interstitial Ad'),
        ),
      ),
    );
  }
}
