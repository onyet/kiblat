import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

/// Service untuk mengelola iklan AdMob
class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();

  AdService._();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  /// AdMob App ID: ca-app-pub-7967860040352202~1740407670
  /// Interstitial Ad Unit ID untuk close app
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7967860040352202/5789487410';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7967860040352202/5789487410';
    }
    throw UnsupportedError('Platform tidak didukung');
  }

  /// Inisialisasi Mobile Ads SDK
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Muat iklan interstitial setelah inisialisasi
    instance.loadInterstitialAd();
  }

  /// Memuat iklan interstitial
  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdReady = false;
              // Muat ulang iklan untuk penggunaan berikutnya
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialAdReady = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdReady = false;
          // Coba muat ulang setelah beberapa detik
          Future.delayed(const Duration(seconds: 30), () {
            loadInterstitialAd();
          });
        },
      ),
    );
  }

  /// Tampilkan iklan interstitial (untuk close app)
  /// Mengembalikan true jika iklan ditampilkan
  Future<bool> showInterstitialAd() async {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      await _interstitialAd!.show();
      return true;
    }
    return false;
  }

  /// Cek apakah iklan interstitial sudah siap
  bool get isInterstitialAdReady => _isInterstitialAdReady;

  /// Dispose resources
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }
}
