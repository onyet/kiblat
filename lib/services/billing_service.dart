import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
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
  final ValueNotifier<List<ProductDetails>> productsNotifier = ValueNotifier(
    [],
  );

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
      final ProductDetailsResponse response = await _iap.queryProductDetails({
        proProductId,
      });
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          '[BillingService] Products not found: ${response.notFoundIDs}',
        );
      }
      productsNotifier.value = response.productDetails;
      debugPrint(
        '[BillingService] Successfully loaded ${response.productDetails.length} products.',
      );

      // --- Bidirectional Entitlement Sync ---
      // This ensures Pro status is both Granted (on purchase/restore)
      // AND Revoked (on refund/voided transaction).
      await _syncEntitlements();
    } catch (e) {
      debugPrint('[BillingService] Initialization failed: $e');
      isStoreAvailable.value = false;
      billingError.value = e.toString();
    }
  }

  /// Silently queries the store to verify if the user still owns "Pro".
  /// If the purchase is missing (refunded/revoked), the app reverts to Free.
  Future<void> _syncEntitlements() async {
    try {
      debugPrint('[BillingService] Syncing entitlements...');

      List<PurchaseDetails> pastPurchases = [];

      if (Platform.isAndroid) {
        final addition = _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final QueryPurchaseDetailsResponse response = await addition
            .queryPastPurchases();

        // If there's an error (e.g., network), we DO NOT downgrade.
        // We only act if the store returns a successful but empty/different list.
        if (response.error != null) {
          debugPrint(
            '[BillingService] Sync failed (Store Error): ${response.error}',
          );
          return;
        }
        pastPurchases = response.pastPurchases;
      } else {
        // Fallback for other platforms (logic can be extended for iOS StoreKit 2)
        // For now, we rely on the persistent stream or a manual restore trigger.
        return;
      }

      var hasProEntitlement = false;
      for (final purchase in pastPurchases) {
        if (purchase.productID == proProductId &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) &&
            await _verifyStorePurchase(purchase)) {
          hasProEntitlement = true;
          break;
        }
      }

      final settings = SettingsService.instance.notifier.value;

      if (hasProEntitlement && !settings.isProUser) {
        debugPrint(
          '[BillingService] Sync: Found missing entitlement. Upgrading to Pro.',
        );
        await _updateProStatus(true);
      } else if (!hasProEntitlement && settings.isProUser) {
        debugPrint(
          '[BillingService] Sync: Entitlement not found (Refunded?). Downgrading to Free.',
        );
        await _updateProStatus(false);
      } else {
        debugPrint(
          '[BillingService] Sync: Local state matches Store (${hasProEntitlement ? 'Pro' : 'Free'}).',
        );
      }
    } catch (e) {
      debugPrint('[BillingService] Entitlement sync failed: $e');
    }
  }

  Future<void> _updateProStatus(bool isPro) async {
    final settings = SettingsService.instance.notifier.value;
    final updated = settings.copyWith(isProUser: isPro);
    await SettingsService.instance.update(updated);

    if (isPro) {
      AdService.instance.dispose();
      if (onPurchaseSuccess != null) onPurchaseSuccess!();
    } else {
      // Re-initialize ads if user was downgraded (dispose clears _isInitialized).
      await AdService.initialize();
      AdService.instance.loadInterstitialAd();
      AdService.instance.loadRewardedAd();
    }
  }

  /// Verify that a terminal store transaction belongs to the Pro product.
  /// Android purchase data is checked cryptographically and against the app's
  /// package/product IDs. StoreKit 2 emits only locally verified transactions;
  /// StoreKit 1 transactions are matched back to Apple's transaction object.
  Future<bool> _verifyStorePurchase(PurchaseDetails purchase) async {
    if (purchase.productID != proProductId) return false;

    if (Platform.isAndroid) {
      if (purchase is! GooglePlayPurchaseDetails) return false;
      try {
        final signedData = purchase.billingClientPurchase.originalJson;
        final signature = purchase.billingClientPurchase.signature;
        final decoded = json.decode(signedData);
        if (decoded is! Map<String, dynamic> ||
            decoded['productId'] != proProductId ||
            decoded['packageName'] != 'id.onyet.app.kiblat' ||
            decoded['purchaseState'] != 0) {
          return false;
        }

        return await _platformChannel.invokeMethod<bool>('verifySignature', {
              'signedData': signedData,
              'signature': signature,
              'publicKey': _playStorePublicKey,
            }) ??
            false;
      } catch (e) {
        debugPrint('[BillingService] Purchase verification failed: $e');
        return false;
      }
    }

    if (Platform.isIOS) {
      if (purchase is SK2PurchaseDetails) {
        // The StoreKit 2 plugin only maps verified Transaction results to
        // SK2PurchaseDetails. Require Apple's signed transaction payload too.
        return purchase.verificationData.serverVerificationData.isNotEmpty;
      }
      if (purchase is AppStorePurchaseDetails) {
        return purchase.skPaymentTransaction.payment.productIdentifier ==
                proProductId &&
            purchase.verificationData.localVerificationData.isNotEmpty &&
            purchase.transactionDate != null;
      }
    }

    return false;
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

  /// Restore purchases.
  ///
  /// Always clears [isPendingPurchase] when finished. Previously, Android could
  /// return an empty purchase stream (common on debug/sideload builds), leaving
  /// the Settings spinner stuck forever.
  Future<void> restorePurchases() async {
    isPendingPurchase.value = true;
    billingError.value = null;
    try {
      if (!isStoreAvailable.value) {
        final available = await _iap.isAvailable();
        isStoreAvailable.value = available;
        if (!available) {
          billingError.value = kDebugMode
              ? 'Play Billing unavailable on this install. Debug/sideload APKs usually cannot restore — install from Play (internal testing) with a license-tester account.'
              : 'Store unavailable. Please try again later.';
          return;
        }
      }

      // Triggers purchaseStream for any owned items (iOS + Android).
      await _iap.restorePurchases();
      // Android: also query past purchases directly (more reliable than stream-only).
      await _syncEntitlements();

      final isPro = SettingsService.instance.notifier.value.isProUser;
      if (!isPro) {
        billingError.value = kDebugMode
            ? 'No Pro purchase found. Debug builds signed with the debug key often cannot see Play purchases — use a Play Console test build.'
            : 'No Pro purchase found for this Google account.';
      }
    } catch (e) {
      debugPrint('[BillingService] Restore purchases error: $e');
      billingError.value = e.toString();
    } finally {
      isPendingPurchase.value = false;
    }
  }

  /// Process raw purchase updates
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchaseDetails in purchases) {
      debugPrint(
        '[BillingService] Handling purchase: ${purchaseDetails.productID}, status: ${purchaseDetails.status}',
      );

      if (purchaseDetails.status == PurchaseStatus.pending) {
        isPendingPurchase.value = true;
      } else {
        isPendingPurchase.value = false;
        try {
          if (purchaseDetails.status == PurchaseStatus.purchased ||
              purchaseDetails.status == PurchaseStatus.restored) {
            final isValid = await _verifyStorePurchase(purchaseDetails);
            if (isValid) {
              await _updateProStatus(true);
              debugPrint('[BillingService] Purchase successful / restored!');
            } else {
              debugPrint('[BillingService] Purchase verification failed.');
              billingError.value = 'Purchase verification failed';
            }
          } else if (purchaseDetails.status == PurchaseStatus.error) {
            debugPrint(
              '[BillingService] Purchase error: ${purchaseDetails.error}',
            );
            billingError.value =
                purchaseDetails.error?.message ?? 'Transaction failed';
          } else if (purchaseDetails.status == PurchaseStatus.canceled) {
            debugPrint('[BillingService] Purchase canceled by user.');
            billingError.value = 'Purchase canceled';
          }
        } catch (e) {
          debugPrint('[BillingService] Purchase processing failed: $e');
          billingError.value = 'Purchase processing failed';
        } finally {
          // Complete terminal transactions even when validation fails, so the
          // store does not keep redelivering an invalid or unrelated purchase.
          if (purchaseDetails.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchaseDetails);
            } catch (e) {
              debugPrint('[BillingService] Could not complete purchase: $e');
            }
          }
        }
      }
    }
  }
}
