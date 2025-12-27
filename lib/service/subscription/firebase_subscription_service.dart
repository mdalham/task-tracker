import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'subscription_models.dart';

/// Syncs subscription status with Firebase Firestore
class FirebaseSubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ───────────────── GET SUBSCRIPTION ─────────────────
  /// Get user's subscription from Firestore
  Future<UserSubscription> getSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[FirebaseSubscription] No user logged in');
        return UserSubscription.none();
      }

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('active')
          .get();

      if (!doc.exists) {
        debugPrint('[FirebaseSubscription] No subscription found');
        return UserSubscription.none();
      }

      final subscription = UserSubscription.fromFirestore(doc.data()!);
      debugPrint('[FirebaseSubscription] Loaded: $subscription');

      // Check if expired
      if (!subscription.isValid) {
        debugPrint('[FirebaseSubscription] Subscription expired');
        await _deactivateSubscription();
        return UserSubscription.none();
      }

      return subscription;
    } catch (e) {
      debugPrint('[FirebaseSubscription] Error getting subscription: $e');
      return UserSubscription.none();
    }
  }

  // ───────────────── SAVE SUBSCRIPTION ─────────────────
  /// Save subscription to Firestore
  Future<void> saveSubscription(
      PurchaseDetails purchase,
      SubscriptionProduct product,
      ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[FirebaseSubscription] Cannot save: No user logged in');
        return;
      }

      // Calculate expiry date
      final purchaseDate = DateTime.now();
      final expiryDate = product == SubscriptionProduct.monthly
          ? purchaseDate.add(const Duration(days: 30))
          : purchaseDate.add(const Duration(days: 365));

      final subscription = UserSubscription(
        isActive: true,
        productId: purchase.productID,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        platform: Platform.isAndroid ? 'android' : 'ios',
        orderId: purchase.purchaseID,
        lastSyncedAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('active')
          .set(subscription.toFirestore());

      // Also save to top-level subscriptions for quick lookup
      await _firestore.collection('subscriptions').doc(user.uid).set({
        'active': true,
        'productId': purchase.productID,
        'expiresAt': Timestamp.fromDate(expiryDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FirebaseSubscription] Saved: $subscription');
    } catch (e) {
      debugPrint('[FirebaseSubscription] Error saving subscription: $e');
      rethrow;
    }
  }

  // ───────────────── RESTORE SUBSCRIPTION ─────────────────
  /// Restore subscription from purchase details
  Future<UserSubscription?> restoreFromPurchase(PurchaseDetails purchase) async {
    try {
      final product = SubscriptionProduct.fromId(purchase.productID);
      if (product == null) {
        debugPrint('[FirebaseSubscription] Unknown product: ${purchase.productID}');
        return null;
      }

      await saveSubscription(purchase, product);
      return await getSubscription();
    } catch (e) {
      debugPrint('[FirebaseSubscription] Error restoring: $e');
      return null;
    }
  }

  // ───────────────── DEACTIVATE ─────────────────
  /// Deactivate subscription
  Future<void> _deactivateSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('active')
          .update({'isActive': false});

      await _firestore.collection('subscriptions').doc(user.uid).update({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FirebaseSubscription] Deactivated');
    } catch (e) {
      debugPrint('[FirebaseSubscription] Error deactivating: $e');
    }
  }

  // ───────────────── LISTEN TO CHANGES ─────────────────
  /// Listen to subscription changes in real-time
  Stream<UserSubscription> subscriptionStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(UserSubscription.none());
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscription')
        .doc('active')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return UserSubscription.none();
      }

      final subscription = UserSubscription.fromFirestore(snapshot.data()!);

      // Auto-deactivate if expired
      if (!subscription.isValid) {
        _deactivateSubscription();
        return UserSubscription.none();
      }

      return subscription;
    });
  }

  // ───────────────── CANCEL SUBSCRIPTION ─────────────────
  /// Cancel subscription (mark as cancelled but keep until expiry)
  Future<void> cancelSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('active')
          .update({
        'cancelled': true,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FirebaseSubscription] Cancelled (active until expiry)');
    } catch (e) {
      debugPrint('[FirebaseSubscription] Error cancelling: $e');
    }
  }

  // ───────────────── SYNC STATUS ─────────────────
  /// Update last synced timestamp
  Future<void> updateSyncStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('active')
          .update({
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirebaseSubscription] Error updating sync: $e');
    }
  }

  // ───────────────── CHECK SUBSCRIPTION ─────────────────
  /// Quick check if user is subscribed
  Future<bool> isSubscribed() async {
    final subscription = await getSubscription();
    return subscription.isValid;
  }

  // ───────────────── GET SUBSCRIPTION DETAILS ─────────────────
  /// Get detailed subscription info
  Future<Map<String, dynamic>?> getSubscriptionDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('active')
          .get();

      return doc.data();
    } catch (e) {
      debugPrint('[FirebaseSubscription] Error getting details: $e');
      return null;
    }
  }
}