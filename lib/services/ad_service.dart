import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola iklan AdMob
class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();

  AdService._();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isShowing = false;

  /// AdMob App ID: ca-app-pub-7967860040352202~1740407670
  /// Interstitial Ad Unit ID untuk close app
  static bool testMode = false;

  static void setTestMode(bool enabled) {
    testMode = enabled;
    debugPrint('[AdService] testMode set: $testMode');
  }

  static String get interstitialAdUnitId {
    if (testMode) {
      // Google's sample interstitial ad unit id
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/1033173712';
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
    }

    if (Platform.isAndroid) {
      return 'ca-app-pub-7967860040352202/5789487410';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7967860040352202/5789487410';
    }
    throw UnsupportedError('Platform tidak didukung');
  }

  /// Inisialisasi Mobile Ads SDK
  static Future<void> initialize() async {
    debugPrint('[AdService] Initializing MobileAds (testMode=$testMode)');
    await MobileAds.instance.initialize();
    // Muat iklan interstitial setelah inisialisasi
    instance.loadInterstitialAd();
  }

  /// Memuat iklan interstitial
  void loadInterstitialAd() {
    // If an ad already exists, don't overwrite it.
    if (_interstitialAd != null) {
      debugPrint('[AdService] Interstitial already loaded, skipping load.');
      return;
    }

    debugPrint(
      '[AdService] Loading interstitial ad (unit: $interstitialAdUnitId)',
    );

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Interstitial loaded');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;

          // Keep a safe default fullScreenContentCallback; it will be overridden when showing
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  debugPrint(
                    '[AdService] Interstitial dismissed (default callback)',
                  );
                  try {
                    ad.dispose();
                  } catch (_) {}
                  _isInterstitialAdReady = false;
                  // Muat ulang iklan untuk penggunaan berikutnya
                  loadInterstitialAd();
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  debugPrint('[AdService] Interstitial failed to show: $error');
                  try {
                    ad.dispose();
                  } catch (_) {}
                  _isInterstitialAdReady = false;
                  loadInterstitialAd();
                },
              );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Interstitial failed to load: $error');
          _isInterstitialAdReady = false;
          // Coba muat ulang setelah beberapa detik (backoff could be improved)
          Future.delayed(const Duration(seconds: 30), () {
            loadInterstitialAd();
          });
        },
      ),
    );
  }

  /// Tampilkan iklan interstitial (untuk close app)
  /// Mengembalikan true jika iklan ditampilkan
  /// Attempts to show interstitial ad and waits until it's dismissed or fails.
  /// Returns true if an ad was shown and dismissed, false otherwise.
  /// A [timeout] is applied to avoid blocking the caller if the ad doesn't fire callbacks.
  Future<bool> showInterstitialAd({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!_isInterstitialAdReady || _interstitialAd == null) return false;
    if (_isShowing) return false; // avoid re-entrance

    final ad = _interstitialAd!;

    // Clear stored reference immediately so we don't try to show it again
    _interstitialAd = null;
    _isInterstitialAdReady = false;
    _isShowing = true;

    final completer = Completer<bool>();

    // Override callbacks for this showing so we know when it finishes
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[AdService] Interstitial showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdService] Interstitial dismissed (show callback)');
        try {
          ad.dispose();
        } catch (_) {}
        _isShowing = false;
        // Start loading next ad
        loadInterstitialAd();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Interstitial failed to show: $error');
        try {
          ad.dispose();
        } catch (_) {}
        _isShowing = false;
        loadInterstitialAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      debugPrint('[AdService] Attempting to show interstitial');
      await ad.show();
    } catch (e) {
      debugPrint('[AdService] Error while calling show(): $e');
      _isShowing = false;
      loadInterstitialAd();
      if (!completer.isCompleted) completer.complete(false);
    }

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          // If callbacks don't arrive, reset and try to recover
          _isShowing = false;
          loadInterstitialAd();
          return false;
        },
      );
    } catch (_) {
      _isShowing = false;
      loadInterstitialAd();
      return false;
    }
  }

  /// Convenience helper: show an interstitial and then exit the app.
  /// Tries to show an interstitial with [timeout] and then calls SystemNavigator.pop().
  /// The method will still exit even if an ad isn't available or fails.
  Future<void> showInterstitialThenExit({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      // Attempt to show ad; this returns true if shown and dismissed, false otherwise
      await showInterstitialAd(timeout: timeout);
    } finally {
      // Exit the app after attempt (do not hang if ad fails)
      try {
        SystemNavigator.pop();
      } catch (_) {
        // If SystemNavigator fails on some platforms, fallback to exit(0)
        try {
          exit(0);
        } catch (_) {}
      }
    }
  }

  /// Cek apakah iklan interstitial sudah siap
  bool get isInterstitialAdReady => _isInterstitialAdReady;

  /// Cek apakah saat ini sedang menampilkan iklan
  bool get isShowingInterstitial => _isShowing;

  /// Force reload interstitial ad. Disposes current ad (if any) and starts a fresh load.
  void reloadInterstitialAd() {
    debugPrint('[AdService] Reloading interstitial ad (force)');
    try {
      _interstitialAd?.dispose();
    } catch (_) {}
    _interstitialAd = null;
    _isInterstitialAdReady = false;
    // Start fresh load
    loadInterstitialAd();
  }

  /// Dispose resources
  void dispose() {
    debugPrint('[AdService] Disposing interstitial ad');
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }
}
