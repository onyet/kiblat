import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/services/ad_service.dart';

/// Service managing Google Play Billing and In-App Purchases (Kiblat Pro)
class BillingService {
  BillingService._internal();

  static final BillingService instance = BillingService._internal();

  static const String proProductId = 'kiblat_lifetime_pro';

  static const MethodChannel _platformChannel = MethodChannel(
    'id.onyet.app.kiblat/platform',
  );

  static const String _playStorePublicKey =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqkvjCZwLuhVs2FxlefOuCbBbJg3pCvqqMFR+pAELs4ewwPNf/zwJa64WsD7WpIcIVpiiFnjYFY6dA9RmAQN1oEvR+vuWhxC/gWcaCMGWQX2GJYUONPxxBjN4PqZV10cuE+iNNzopyPiGJ4/GRvyYOV6v7yoKwT1S1iDM2XyUzhQimXnqqqspe12zoganNqShXV21K2ZVWsVkiqiIptez1utF4daJdt+9RmTFSR6zMqEvdkyK+rmWmLrlJkJQdV54MUI38jxdfe77wHAOjVhXzv6GuxFXsihkk2qB5miX4yEknOi5t3cVYG7OWBRjRQd1zb5dKMS7gtXQvvBnrjcZZwIDAQAB';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Whether the store is available on the current device
  final ValueNotifier<bool> isStoreAvailable = ValueNotifier(false);

  /// Loaded products from Google Play
  final ValueNotifier<List<ProductDetails>> productsNotifier = ValueNotifier([]);

  /// Whether a purchase is currently pending
  final ValueNotifier<bool> isPendingPurchase = ValueNotifier(false);

  /// Latest billing error message, if any
  final ValueNotifier<String?> billingError = ValueNotifier(null);

  /// Event listener to notify UI when purchase is successful
  VoidCallback? onPurchaseSuccess;

  /// Initialize and load store details
  Future<void> initialize() async {
    try {
      final bool available = await _iap.isAvailable();
      if (!available) {
        debugPrint('[BillingService] Store not available.');
        isStoreAvailable.value = false;
        return;
      }
      isStoreAvailable.value = true;

      // Listen to transaction updates
      final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen(
        (purchaseDetailsList) {
          _handlePurchaseUpdates(purchaseDetailsList);
        },
        onDone: () {
          _subscription?.cancel();
        },
        onError: (error) {
          debugPrint('[BillingService] Stream error: $error');
          billingError.value = error.toString();
          isPendingPurchase.value = false;
        },
      );

      // Query product details from Google Play
      final ProductDetailsResponse response = await _iap.queryProductDetails({proProductId});
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[BillingService] Products not found: ${response.notFoundIDs}');
      }
      productsNotifier.value = response.productDetails;
      debugPrint('[BillingService] Successfully loaded ${response.productDetails.length} products.');
    } catch (e) {
      debugPrint('[BillingService] Initialization failed: $e');
      isStoreAvailable.value = false;
      billingError.value = e.toString();
    }
  }

  /// Dispose listeners
  void dispose() {
    _subscription?.cancel();
    isStoreAvailable.dispose();
    productsNotifier.dispose();
    isPendingPurchase.dispose();
    billingError.dispose();
  }

  /// Launch purchase flow for Kiblat Pro
  Future<void> buyPro() async {
    if (productsNotifier.value.isEmpty) {
      billingError.value = 'Product details not loaded yet. Please try again.';
      return;
    }

    final product = productsNotifier.value.firstWhere(
      (p) => p.id == proProductId,
      orElse: () => throw Exception('Product $proProductId not found in store'),
    );

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    isPendingPurchase.value = true;
    billingError.value = null;

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[BillingService] Buy product error: $e');
      billingError.value = e.toString();
      isPendingPurchase.value = false;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    isPendingPurchase.value = true;
    billingError.value = null;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[BillingService] Restore purchases error: $e');
      billingError.value = e.toString();
      isPendingPurchase.value = false;
    }
  }

  /// Process raw purchase updates
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchaseDetails in purchases) {
      debugPrint('[BillingService] Handling purchase: ${purchaseDetails.productID}, status: ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        isPendingPurchase.value = true;
      } else {
        isPendingPurchase.value = false;

        bool isValid = true;

        if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Verify purchase (100% offline local validation to respect user privacy)
          if (Platform.isAndroid) {
            try {
              if (purchaseDetails is GooglePlayPurchaseDetails) {
                final signedData = purchaseDetails.billingClientPurchase.originalJson;
                final signature = purchaseDetails.billingClientPurchase.signature;

                final bool? result = await _platformChannel.invokeMethod<bool>(
                  'verifySignature',
                  {
                    'signedData': signedData,
                    'signature': signature,
                    'publicKey': _playStorePublicKey,
                  },
                );
                isValid = result ?? false;
              } else {
                debugPrint('[BillingService] Warning: Purchase is not GooglePlayPurchaseDetails on Android!');
                isValid = false;
              }
            } catch (e) {
              debugPrint('[BillingService] Local signature verification failed with exception: $e');
              isValid = false;
            }
          }

          if (isValid) {
            final settings = SettingsService.instance.notifier.value;
            final updated = settings.copyWith(isProUser: true);
            await SettingsService.instance.update(updated);

            // Pro is active, dispose AdMob immediately to remove all banner and tracking ads
            AdService.instance.dispose();

            if (onPurchaseSuccess != null) {
              onPurchaseSuccess!();
            }

            debugPrint('[BillingService] Purchase successful / restored!');
          } else {
            debugPrint('[BillingService] Purchase signature verification failed!');
            billingError.value = 'Purchase verification failed: invalid signature';
          }
        } else if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('[BillingService] Purchase error: ${purchaseDetails.error}');
          billingError.value = purchaseDetails.error?.message ?? 'Transaction failed';
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          debugPrint('[BillingService] Purchase canceled by user.');
          billingError.value = 'Purchase canceled';
        }

        // Complete the purchase with the platform store (critical for Google Play)
        if (isValid && purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Switch app icon dynamically (only supported on Android via activity-alias)
  Future<void> updateAppIcon(bool isPro) async {
    if (Platform.isAndroid) {
      try {
        await _platformChannel.invokeMethod('changeIcon', {
          'iconName': isPro ? 'pro' : 'default',
        });
        debugPrint('[BillingService] App icon update requested: ${isPro ? 'pro' : 'default'}');
      } catch (e) {
        debugPrint('[BillingService] Failed to update app icon: $e');
      }
    }
  }
}
