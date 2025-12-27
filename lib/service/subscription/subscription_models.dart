import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscription status enum
enum SubscriptionStatus {
  none,       // No subscription
  active,     // Active subscription
  expired,    // Expired subscription
  cancelled,  // Cancelled but still valid until expiry
  loading,    // Checking status
}

/// Subscription product types
enum SubscriptionProduct {
  monthly('monthly_premium', 'Monthly Premium', '\$3/month'),
  yearly('yearly_premium', 'Yearly Premium', '\$30/year');

  final String productId;
  final String name;
  final String price;

  const SubscriptionProduct(this.productId, this.name, this.price);

  static SubscriptionProduct? fromId(String id) {
    return SubscriptionProduct.values
        .where((p) => p.productId == id)
        .firstOrNull;
  }
}

/// User subscription data model
class UserSubscription {
  final bool isActive;
  final String? productId;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String? platform;
  final DateTime? lastSyncedAt;
  final String? orderId;

  const UserSubscription({
    required this.isActive,
    this.productId,
    this.purchaseDate,
    this.expiryDate,
    this.platform,
    this.lastSyncedAt,
    this.orderId,
  });

  /// Empty subscription (not subscribed)
  factory UserSubscription.none() {
    return const UserSubscription(isActive: false);
  }

  /// Create from Firestore document
  factory UserSubscription.fromFirestore(Map<String, dynamic> data) {
    return UserSubscription(
      isActive: data['isActive'] ?? false,
      productId: data['productId'],
      purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      platform: data['platform'],
      lastSyncedAt: (data['lastSyncedAt'] as Timestamp?)?.toDate(),
      orderId: data['orderId'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'isActive': isActive,
      'productId': productId,
      'purchaseDate': purchaseDate != null
          ? Timestamp.fromDate(purchaseDate!)
          : null,
      'expiryDate': expiryDate != null
          ? Timestamp.fromDate(expiryDate!)
          : null,
      'platform': platform,
      'lastSyncedAt': Timestamp.now(),
      'orderId': orderId,
    };
  }

  /// Check if subscription is valid
  bool get isValid {
    if (!isActive) return false;
    if (expiryDate == null) return false;
    return DateTime.now().isBefore(expiryDate!);
  }

  /// Get days remaining
  int get daysRemaining {
    if (expiryDate == null) return 0;
    final diff = expiryDate!.difference(DateTime.now());
    return diff.inDays;
  }

  /// Get subscription type
  SubscriptionProduct? get product {
    if (productId == null) return null;
    return SubscriptionProduct.fromId(productId!);
  }

  /// Copy with modifications
  UserSubscription copyWith({
    bool? isActive,
    String? productId,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? platform,
    DateTime? lastSyncedAt,
    String? orderId,
  }) {
    return UserSubscription(
      isActive: isActive ?? this.isActive,
      productId: productId ?? this.productId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      platform: platform ?? this.platform,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      orderId: orderId ?? this.orderId,
    );
  }

  @override
  String toString() {
    return 'UserSubscription(isActive: $isActive, product: $productId, '
        'expires: $expiryDate, daysRemaining: $daysRemaining)';
  }
}

/// Purchase result model
class PurchaseResult {
  final bool success;
  final String? message;
  final UserSubscription? subscription;

  const PurchaseResult({
    required this.success,
    this.message,
    this.subscription,
  });

  factory PurchaseResult.success(UserSubscription subscription) {
    return PurchaseResult(
      success: true,
      message: 'Subscription activated successfully!',
      subscription: subscription,
    );
  }

  factory PurchaseResult.failure(String message) {
    return PurchaseResult(
      success: false,
      message: message,
    );
  }

  factory PurchaseResult.cancelled() {
    return const PurchaseResult(
      success: false,
      message: 'Purchase cancelled',
    );
  }
}