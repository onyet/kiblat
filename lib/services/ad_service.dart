import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:kiblat/services/settings_service.dart';

/// Service untuk mengelola iklan AdMob
class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();

  AdService._();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isShowing = false;
  bool _isDisposed = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;
  bool _isRewardedAdLoading = false;
  bool _isShowingRewarded = false;

  /// AdMob App ID: ca-app-pub-7967860040352202~1740407670
  /// Interstitial Ad Unit ID untuk close app
  static bool _testMode = false;

  static bool get testMode => kDebugMode && _testMode;

  static void setTestMode(bool enabled) {
    _testMode = enabled;
    debugPrint('[AdService] testMode set: $_testMode (effective: $testMode)');
  }

  static bool get bypassRewardedGate => kDebugMode && testMode;

  static String get interstitialAdUnitId {
    if (testMode) {
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

  static String get rewardedAdUnitId {
    if (testMode) {
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/5224354917';
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    }

    if (Platform.isAndroid) {
      return 'ca-app-pub-7967860040352202/9413432801';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7967860040352202/9413432801';
    }
    throw UnsupportedError('Platform tidak didukung');
  }

  static String get prayerLogBannerUnitId {
    if (testMode) {
      return Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/2934735716';
    }
    return 'ca-app-pub-7967860040352202/4176479928';
  }

  static String get settingsBannerUnitId {
    if (testMode) {
      return Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/2934735716';
    }
    return 'ca-app-pub-7967860040352202/6716003030';
  }

  static String get prayerTimesBannerUnitId {
    if (testMode) {
      return Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/2934735716';
    }
    return 'ca-app-pub-7967860040352202/3192103683';
  }

  static bool _isInitialized = false;

  /// Inisialisasi Mobile Ads SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint('[AdService] Initializing MobileAds (testMode=$testMode)');
    instance._isDisposed = false;
    await MobileAds.instance.initialize();
    _isInitialized = true;
    // Note: loadInterstitialAd and loadRewardedAd are now called lazily
    // to save resources on low-end devices during startup.
  }

  static bool get isInitialized => _isInitialized;

  /// Memuat iklan interstitial
  void loadInterstitialAd() {
    // If disposed, don't attempt to load or schedule future work.
    if (_isDisposed) {
      debugPrint('[AdService] Service disposed, not loading interstitial.');
      return;
    }
    // Skip loading ads if user is Pro
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) {
      debugPrint('[AdService] User is Pro, skipping interstitial ad load.');
      return;
    }
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
          _interstitialAd!
              .fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint(
                '[AdService] Interstitial dismissed (default callback)',
              );
              try {
                ad.dispose();
              } catch (_) {}
              _isInterstitialAdReady = false;
              // Muat ulang iklan untuk penggunaan berikutnya, kecuali sudah dispose
              if (!_isDisposed) {
                loadInterstitialAd();
              } else {
                debugPrint(
                  '[AdService] Service disposed, skipping reload after dismiss.',
                );
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('[AdService] Interstitial failed to show: $error');
              try {
                ad.dispose();
              } catch (_) {}
              _isInterstitialAdReady = false;
              if (!_isDisposed) {
                loadInterstitialAd();
              } else {
                debugPrint(
                  '[AdService] Service disposed, skipping reload after failure to show.',
                );
              }
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Interstitial failed to load: $error');
          _isInterstitialAdReady = false;
          // Coba muat ulang setelah beberapa detik (backoff could be improved)
          Future.delayed(const Duration(seconds: 30), () {
            if (!_isDisposed) loadInterstitialAd();
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
    Duration timeout = const Duration(seconds: 7),
  }) async {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) {
      debugPrint('[AdService] User is Pro, bypassing interstitial ad.');
      return false;
    }
    
    // Lazy load if not ready
    if (!_isInterstitialAdReady || _interstitialAd == null) {
      loadInterstitialAd();
      return false;
    }
    
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
        // Start loading next ad if not disposed
        if (!_isDisposed) {
          loadInterstitialAd();
        } else {
          debugPrint(
            '[AdService] Service disposed, skipping reload after show callback.',
          );
        }
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Interstitial failed to show: $error');
        try {
          ad.dispose();
        } catch (_) {}
        _isShowing = false;
        if (!_isDisposed) {
          loadInterstitialAd();
        } else {
          debugPrint(
            '[AdService] Service disposed, skipping reload after failure to show.',
          );
        }
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      debugPrint('[AdService] Attempting to show interstitial');
      await ad.show();
    } catch (e) {
      debugPrint('[AdService] Error while calling show(): $e');
      _isShowing = false;
      if (!_isDisposed) loadInterstitialAd();
      if (!completer.isCompleted) completer.complete(false);
    }

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          // If callbacks don't arrive within timeout, reset and try to recover
          _isShowing = false;
          if (!_isDisposed) loadInterstitialAd();
          return false;
        },
      );
    } catch (_) {
      _isShowing = false;
      if (!_isDisposed) loadInterstitialAd();
      return false;
    }
  }

  /// Convenience helper: show an interstitial and then exit the app.
  /// Tries to show an interstitial with [timeout] and then calls SystemNavigator.pop().
  /// The method will still exit even if an ad isn't available or fails.
  Future<void> showInterstitialThenExit({
    Duration timeout = const Duration(seconds: 7),
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
    if (_isDisposed) {
      debugPrint(
        '[AdService] reload requested but service is disposed, ignoring.',
      );
      return;
    }
    debugPrint('[AdService] Reloading interstitial ad (force)');
    try {
      _interstitialAd?.dispose();
    } catch (_) {}
    _interstitialAd = null;
    _isInterstitialAdReady = false;
    // Start fresh load
    loadInterstitialAd();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Rewarded Ad
  // ──────────────────────────────────────────────────────────────────────────

  /// Load a rewarded ad for custom ringtone unlock
  void loadRewardedAd() {
    if (_isDisposed) {
      debugPrint('[AdService] Service disposed, not loading rewarded.');
      return;
    }
    // Skip loading ads if user is Pro
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) {
      debugPrint('[AdService] User is Pro, skipping rewarded ad load.');
      return;
    }
    if (_isRewardedAdLoading) {
      debugPrint('[AdService] Rewarded load already in progress, skipping.');
      return;
    }
    if (_rewardedAd != null) {
      debugPrint('[AdService] Rewarded already loaded, skipping.');
      return;
    }

    debugPrint('[AdService] Loading rewarded ad (unit: $rewardedAdUnitId)');
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] Rewarded ad loaded');
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] Rewarded ad failed to load: $error');
          _isRewardedAdReady = false;
          _isRewardedAdLoading = false;
          // Retry after delay
          Future.delayed(const Duration(seconds: 30), () {
            if (!_isDisposed) loadRewardedAd();
          });
        },
      ),
    );
  }

  Future<bool> waitForRewardedAdReady({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (bypassRewardedGate) return true;
    if (_isRewardedAdReady && _rewardedAd != null) return true;

    loadRewardedAd();

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_isRewardedAdReady && _rewardedAd != null) return true;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return _isRewardedAdReady && _rewardedAd != null;
  }

  /// Show rewarded ad and wait for reward.
  /// Returns true if the user earned the reward, false otherwise.
  Future<bool> showRewardedAd({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) {
      debugPrint('[AdService] User is Pro, bypassing rewarded ad.');
      return true; // Auto-bypass rewarded ad for Pro
    }
    
    // Lazy load if not ready
    if (!_isRewardedAdReady || _rewardedAd == null) {
      loadRewardedAd();
      return false;
    }

    if (_isShowingRewarded) return false;

    final ad = _rewardedAd!;
    _rewardedAd = null;
    _isRewardedAdReady = false;
    _isShowingRewarded = true;

    final completer = Completer<bool>();
    bool userEarnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('[AdService] Rewarded ad showed');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint(
          '[AdService] Rewarded ad dismissed (earned=$userEarnedReward)',
        );
        try {
          ad.dispose();
        } catch (_) {}
        _isShowingRewarded = false;
        if (!_isDisposed) loadRewardedAd();
        if (!completer.isCompleted) completer.complete(userEarnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Rewarded ad failed to show: $error');
        try {
          ad.dispose();
        } catch (_) {}
        _isShowingRewarded = false;
        if (!_isDisposed) loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      debugPrint('[AdService] Attempting to show rewarded ad');
      await ad.show(
        onUserEarnedReward: (AdWithoutView adView, RewardItem reward) {
          debugPrint(
            '[AdService] User earned reward: ${reward.amount} ${reward.type}',
          );
          userEarnedReward = true;
        },
      );
    } catch (e) {
      debugPrint('[AdService] Error showing rewarded ad: $e');
      _isShowingRewarded = false;
      if (!_isDisposed) loadRewardedAd();
      if (!completer.isCompleted) completer.complete(false);
    }

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _isShowingRewarded = false;
          if (!_isDisposed) loadRewardedAd();
          return false;
        },
      );
    } catch (_) {
      _isShowingRewarded = false;
      if (!_isDisposed) loadRewardedAd();
      return false;
    }
  }

  /// Cek apakah rewarded ad sudah siap
  bool get isRewardedAdReady => _isRewardedAdReady;

  bool get isRewardedAdLoading => _isRewardedAdLoading;

  /// Cek apakah sedang menampilkan rewarded ad
  bool get isShowingRewarded => _isShowingRewarded;

  void reloadRewardedAd() {
    if (_isDisposed) {
      debugPrint('[AdService] reload requested but service is disposed.');
      return;
    }
    debugPrint('[AdService] Reloading rewarded ad (force)');
    try {
      _rewardedAd?.dispose();
    } catch (_) {}
    _rewardedAd = null;
    _isRewardedAdReady = false;
    _isRewardedAdLoading = false;
    loadRewardedAd();
  }

  /// Dispose resources
  void dispose() {
    debugPrint('[AdService] Disposing ads');
    _isDisposed = true;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;
    _isRewardedAdLoading = false;
  }
}
