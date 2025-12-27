import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'subscription_models.dart';

/// Manages In-App Purchase subscriptions
class SubscriptionManager {
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Available products
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Purchase callback
  Function(PurchaseDetails)? onPurchaseUpdate;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  SubscriptionManager() {
    _init();
  }

  // ───────────────── INITIALIZATION ─────────────────
  Future<void> _init() async {
    // Check if IAP is available
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[SubscriptionManager] In-App Purchase not available');
      return;
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => debugPrint('[SubscriptionManager] Purchase stream done'),
      onError: (error) => debugPrint('[SubscriptionManager] Purchase stream error: $error'),
    );

    // Load products
    await loadProducts();
  }

  // ───────────────── LOAD PRODUCTS ─────────────────
  Future<bool> loadProducts() async {
    _isLoading = true;

    try {
      // ✅ FIX: Use Set<String> instead of accessing productId in const context
      final productIds = <String>{
        'monthly_premium',  // SubscriptionProduct.monthly.productId
        'yearly_premium',   // SubscriptionProduct.yearly.productId
      };

      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('[SubscriptionManager] Error loading products: ${response.error}');
        _isLoading = false;
        return false;
      }

      _products = response.productDetails;
      debugPrint('[SubscriptionManager] Loaded ${_products.length} products');

      for (final product in _products) {
        debugPrint('  - ${product.id}: ${product.title} (${product.price})');
      }

      _isLoading = false;
      return _products.isNotEmpty;
    } catch (e) {
      debugPrint('[SubscriptionManager] Exception loading products: $e');
      _isLoading = false;
      return false;
    }
  }

  // ───────────────── PURCHASE ─────────────────
  Future<void> buySubscription(SubscriptionProduct product) async {
    final productDetails = _products
        .where((p) => p.id == product.productId)
        .firstOrNull;

    if (productDetails == null) {
      debugPrint('[SubscriptionManager] Product not found: ${product.productId}');
      return;
    }

    debugPrint('[SubscriptionManager] Purchasing: ${productDetails.id}');

    final purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    try {
      // ✅ Use buyNonConsumable for subscriptions
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('[SubscriptionManager] Purchase error: $e');
    }
  }

  // ───────────────── RESTORE PURCHASES ─────────────────
  Future<List<PurchaseDetails>> restorePurchases() async {
    debugPrint('[SubscriptionManager] Restoring purchases...');

    try {
      // ✅ FIX: Use restorePurchases() which triggers purchaseStream
      // The restored purchases will come through the purchaseStream listener
      await _iap.restorePurchases();

      // Wait a bit for the stream to process
      await Future.delayed(const Duration(seconds: 2));

      // ✅ FIX: Get purchases from the platform-specific store
      if (Platform.isAndroid) {
        final GooglePlayPurchaseDetails? pastPurchases =
        await _getPastPurchasesAndroid();

        if (pastPurchases != null) {
          return [pastPurchases];
        }
      }

      // Fallback: return empty list
      debugPrint('[SubscriptionManager] No past purchases found');
      return [];
    } catch (e) {
      debugPrint('[SubscriptionManager] Restore exception: $e');
      return [];
    }
  }

  // ✅ NEW: Helper method to get past purchases on Android
  Future<GooglePlayPurchaseDetails?> _getPastPurchasesAndroid() async {
    try {
      if (Platform.isAndroid) {
        final InAppPurchaseAndroidPlatformAddition androidAddition = _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

        // Query for subscription purchases
        final response = await androidAddition.queryPastPurchases();

        if (response.error != null) {
          debugPrint('[SubscriptionManager] Android query error: ${response.error}');
          return null;
        }

        // Find active subscription
        for (final purchase in response.pastPurchases) {
          if (purchase.status == PurchaseStatus.purchased) {
            debugPrint('[SubscriptionManager] Found active purchase: ${purchase.productID}');
            return purchase as GooglePlayPurchaseDetails;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[SubscriptionManager] Error querying past purchases: $e');
      return null;
    }
  }

  // ───────────────── PURCHASE UPDATES ─────────────────
  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      debugPrint(
        '[SubscriptionManager] Purchase update: ${purchase.productID} - ${purchase.status}',
      );

      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('[SubscriptionManager] Purchase pending');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          debugPrint('[SubscriptionManager] Purchase successful');
          _handleSuccessfulPurchase(purchase);
          break;

        case PurchaseStatus.error:
          debugPrint('[SubscriptionManager] Purchase error: ${purchase.error}');
          break;

        case PurchaseStatus.canceled:
          debugPrint('[SubscriptionManager] Purchase canceled');
          break;
      }

      // Complete purchase
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchase) {
    // Call the callback if set
    onPurchaseUpdate?.call(purchase);

    // Complete the purchase
    if (purchase.pendingCompletePurchase) {
      _iap.completePurchase(purchase);
    }
  }

  // ───────────────── VERIFY PURCHASE ─────────────────
  /// Verify if a purchase is valid (for server-side verification)
  Future<bool> verifyPurchase(PurchaseDetails purchase) async {
    // In production, send purchase.verificationData to your server
    // for verification with Google Play Billing API

    // For now, we trust the purchase
    return purchase.status == PurchaseStatus.purchased;
  }

  // ───────────────── HELPERS ─────────────────
  /// Get product details by ID
  ProductDetails? getProduct(String productId) {
    return _products.where((p) => p.id == productId).firstOrNull;
  }

  /// Check if user has any active subscription
  Future<bool> hasActiveSubscription() async {
    final purchases = await restorePurchases();
    return purchases.isNotEmpty;
  }

  /// Get formatted price for a product
  String getPrice(SubscriptionProduct product) {
    final productDetails = getProduct(product.productId);
    return productDetails?.price ?? product.price;
  }

  // ───────────────── DISPOSE ─────────────────
  void dispose() {
    _subscription?.cancel();
    debugPrint('[SubscriptionManager] Disposed');
  }
}