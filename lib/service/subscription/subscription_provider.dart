import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_models.dart';
import 'subscription_manager.dart';
import 'firebase_subscription_service.dart';

/// Manages subscription state across the app
class SubscriptionProvider extends ChangeNotifier {
  // Services
  late final SubscriptionManager _subscriptionManager;
  late final FirebaseSubscriptionService _firebaseService;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // State
  SubscriptionStatus _status = SubscriptionStatus.loading;
  UserSubscription _subscription = UserSubscription.none();
  User? _user;
  String? _errorMessage;
  bool _isProcessing = false;

  // Getters
  SubscriptionStatus get status => _status;
  UserSubscription get subscription => _subscription;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isProcessing;
  bool get isSubscribed => _subscription.isValid;
  bool get isLoggedIn => _user != null;
  List<ProductDetails> get products => _subscriptionManager.products;

  SubscriptionProvider() {
    _init();
  }

  // ───────────────── INITIALIZATION ─────────────────
  Future<void> _init() async {
    debugPrint('[SubscriptionProvider] Initializing...');

    // Initialize services
    _subscriptionManager = SubscriptionManager();
    _firebaseService = FirebaseSubscriptionService();

    // Set purchase callback
    _subscriptionManager.onPurchaseUpdate = _handlePurchaseUpdate;

    // Check auth state
    _user = _auth.currentUser;
    _auth.authStateChanges().listen(_onAuthStateChanged);

    // Load subscription if logged in
    if (_user != null) {
      await _loadSubscription();
    } else {
      _status = SubscriptionStatus.none;
      notifyListeners();
    }

    // Load cached subscription status
    await _loadCachedStatus();
  }

  // ───────────────── AUTH ─────────────────
  Future<bool> signInWithGoogle() async {
    try {
      _isProcessing = true;
      _errorMessage = null;
      notifyListeners();

      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isProcessing = false;
        notifyListeners();
        return false; // User cancelled
      }

      // Get auth details
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      await _auth.signInWithCredential(credential);

      debugPrint('[SubscriptionProvider] Signed in: ${_auth.currentUser?.email}');

      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[SubscriptionProvider] Sign in error: $e');
      _errorMessage = 'Failed to sign in. Please try again.';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();

      _user = null;
      _subscription = UserSubscription.none();
      _status = SubscriptionStatus.none;

      await _clearCachedStatus();

      notifyListeners();
      debugPrint('[SubscriptionProvider] Signed out');
    } catch (e) {
      debugPrint('[SubscriptionProvider] Sign out error: $e');
    }
  }

  void _onAuthStateChanged(User? user) {
    _user = user;

    if (user != null) {
      _loadSubscription();
    } else {
      _subscription = UserSubscription.none();
      _status = SubscriptionStatus.none;
    }

    notifyListeners();
  }

  // ───────────────── SUBSCRIPTION ─────────────────
  Future<void> _loadSubscription() async {
    try {
      _status = SubscriptionStatus.loading;
      notifyListeners();

      // Load from Firebase
      _subscription = await _firebaseService.getSubscription();

      // Update status
      if (_subscription.isValid) {
        _status = SubscriptionStatus.active;
        await _cacheStatus(true);
      } else {
        _status = SubscriptionStatus.none;
        await _cacheStatus(false);
      }

      debugPrint('[SubscriptionProvider] Loaded: $_subscription');
      notifyListeners();
    } catch (e) {
      debugPrint('[SubscriptionProvider] Load error: $e');
      _status = SubscriptionStatus.none;
      notifyListeners();
    }
  }

  // ───────────────── PURCHASE ─────────────────
  Future<void> buySubscription(SubscriptionProduct product) async {
    if (!isLoggedIn) {
      _errorMessage = 'Please sign in first';
      notifyListeners();
      return;
    }

    try {
      _isProcessing = true;
      _errorMessage = null;
      notifyListeners();

      await _subscriptionManager.buySubscription(product);

      // Purchase callback will handle the rest
    } catch (e) {
      debugPrint('[SubscriptionProvider] Purchase error: $e');
      _errorMessage = 'Failed to start purchase. Please try again.';
      _isProcessing = false;
      notifyListeners();
    }
  }

  void _handlePurchaseUpdate(PurchaseDetails purchase) async {
    try {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {

        // Get product
        final product = SubscriptionProduct.fromId(purchase.productID);
        if (product == null) {
          debugPrint('[SubscriptionProvider] Unknown product: ${purchase.productID}');
          return;
        }

        // Save to Firebase
        await _firebaseService.saveSubscription(purchase, product);

        // Reload subscription
        await _loadSubscription();

        _errorMessage = null;
        _isProcessing = false;
        notifyListeners();

        debugPrint('[SubscriptionProvider] Purchase completed successfully');
      } else if (purchase.status == PurchaseStatus.error) {
        _errorMessage = 'Purchase failed: ${purchase.error?.message}';
        _isProcessing = false;
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.canceled) {
        _isProcessing = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SubscriptionProvider] Purchase update error: $e');
      _errorMessage = 'Failed to activate subscription';
      _isProcessing = false;
      notifyListeners();
    }
  }

  // ───────────────── RESTORE ─────────────────
  Future<bool> restorePurchases() async {
    if (!isLoggedIn) {
      _errorMessage = 'Please sign in first';
      notifyListeners();
      return false;
    }

    try {
      _isProcessing = true;
      _errorMessage = null;
      notifyListeners();

      // Restore from Play Store
      final purchases = await _subscriptionManager.restorePurchases();

      if (purchases.isEmpty) {
        _errorMessage = 'No purchases found to restore';
        _isProcessing = false;
        notifyListeners();
        return false;
      }

      // Restore most recent purchase
      final latestPurchase = purchases.first;
      final subscription = await _firebaseService.restoreFromPurchase(latestPurchase);

      if (subscription != null && subscription.isValid) {
        _subscription = subscription;
        _status = SubscriptionStatus.active;
        await _cacheStatus(true);
        _errorMessage = null;

        debugPrint('[SubscriptionProvider] Restored successfully');
      } else {
        _errorMessage = 'Restored subscription is not valid';
      }

      _isProcessing = false;
      notifyListeners();
      return subscription != null && subscription.isValid;
    } catch (e) {
      debugPrint('[SubscriptionProvider] Restore error: $e');
      _errorMessage = 'Failed to restore purchases';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // ───────────────── CACHE ─────────────────
  Future<void> _cacheStatus(bool isSubscribed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_subscribed', isSubscribed);
      await prefs.setInt('cache_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[SubscriptionProvider] Cache error: $e');
    }
  }

  Future<void> _loadCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSubscribed = prefs.getBool('is_subscribed') ?? false;
      final timestamp = prefs.getInt('cache_timestamp') ?? 0;

      // Use cache if less than 1 hour old
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge < 3600000 && isSubscribed) {
        // Don't override actual status, just use as fallback
        if (_status == SubscriptionStatus.loading) {
          _status = SubscriptionStatus.active;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[SubscriptionProvider] Load cache error: $e');
    }
  }

  Future<void> _clearCachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_subscribed');
      await prefs.remove('cache_timestamp');
    } catch (e) {
      debugPrint('[SubscriptionProvider] Clear cache error: $e');
    }
  }

  // ───────────────── UTILITIES ─────────────────
  String getPrice(SubscriptionProduct product) {
    return _subscriptionManager.getPrice(product);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadSubscription();
  }

  @override
  void dispose() {
    _subscriptionManager.dispose();
    super.dispose();
  }
}