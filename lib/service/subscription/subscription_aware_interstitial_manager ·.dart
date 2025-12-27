import 'package:flutter/material.dart';
import '../ads/industrial/smart_industrial_ad.dart';
import 'subscription_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// SUBSCRIPTION-AWARE INTERSTITIAL MANAGER
// Wraps your SmartInterstitialAdsManager with subscription checking
// ═══════════════════════════════════════════════════════════════════════

class SubscriptionAwareInterstitialManager {
  final SubscriptionProvider _subscriptionProvider;
  SmartInterstitialAdsManager? _adsManager;

  final String admobPrimaryId;
  final String admobSecondaryId;
  final String metaInterstitialId;
  final String unityInterstitialId;
  final int tapThreshold;
  final int maxRetry;

  bool _isDisposed = false;

  SubscriptionAwareInterstitialManager({
    required SubscriptionProvider subscriptionProvider,
    required this.admobPrimaryId,
    required this.admobSecondaryId,
    required this.metaInterstitialId,
    required this.unityInterstitialId,
    this.tapThreshold = 3,
    this.maxRetry = 20,
  }) : _subscriptionProvider = subscriptionProvider {
    _initialize();

    // Listen to subscription changes
    _subscriptionProvider.addListener(_onSubscriptionChanged);
  }

  // ─────────────────── INITIALIZATION ───────────────────

  void _initialize() {
    if (_subscriptionProvider.isSubscribed) {
      debugPrint('[SubscriptionInterstitial] ✨ User subscribed - ads disabled');
      _adsManager = null;
      return;
    }

    debugPrint('[SubscriptionInterstitial] 📢 User not subscribed - initializing ads');

    _adsManager = SmartInterstitialAdsManager(
      tapThreshold: tapThreshold,
      admobPrimaryId: admobPrimaryId,
      admobSecondaryId: admobSecondaryId,
      metaInterstitialId: metaInterstitialId,
      unityInterstitialId: unityInterstitialId,
      maxRetry: maxRetry,
    );

    _adsManager?.loadAll();
  }

  // ─────────────────── SUBSCRIPTION CHANGE HANDLER ───────────────────

  void _onSubscriptionChanged() {
    if (_isDisposed) return;

    if (_subscriptionProvider.isSubscribed && _adsManager != null) {
      // User just subscribed - dispose ads immediately
      debugPrint('[SubscriptionInterstitial] ✨ User subscribed - disposing ads');
      _adsManager?.dispose();
      _adsManager = null;
    } else if (!_subscriptionProvider.isSubscribed && _adsManager == null) {
      // User subscription expired - reinitialize ads
      debugPrint('[SubscriptionInterstitial] 📢 Subscription expired - reinitializing ads');
      _initialize();
    }
  }

  // ─────────────────── PUBLIC API ───────────────────

  /// Register a user tap (shows ad after threshold)
  void registerTap() {
    if (_isDisposed) return;

    if (_subscriptionProvider.isSubscribed) {
      debugPrint('[SubscriptionInterstitial] ✨ User subscribed - skipping tap');
      return;
    }

    if (_adsManager == null) {
      debugPrint('[SubscriptionInterstitial] ⚠️ Ads not initialized');
      return;
    }

    _adsManager?.registerTap();
  }

  /// Show ad immediately (bypasses threshold)
  Future<void> showAd() async {
    if (_isDisposed) return;

    if (_subscriptionProvider.isSubscribed) {
      debugPrint('[SubscriptionInterstitial] ✨ User subscribed - skipping ad');
      return;
    }

    if (_adsManager == null) {
      debugPrint('[SubscriptionInterstitial] ⚠️ Ads not initialized');
      return;
    }

    await _adsManager?.showAd();
  }

  /// Check if any ad is ready
  bool get hasAnyAdReady {
    if (_subscriptionProvider.isSubscribed) return false;
    return _adsManager?.hasAnyAdReady ?? false;
  }

  /// Check if primary AdMob is ready
  bool get hasPrimaryReady {
    if (_subscriptionProvider.isSubscribed) return false;
    return _adsManager?.hasPrimaryReady ?? false;
  }

  /// Check if secondary AdMob is ready
  bool get hasSecondaryReady {
    if (_subscriptionProvider.isSubscribed) return false;
    return _adsManager?.hasSecondaryReady ?? false;
  }

  /// Check if fallback ads are ready
  bool get hasFallbackReady {
    if (_subscriptionProvider.isSubscribed) return false;
    return _adsManager?.hasFallbackReady ?? false;
  }

  /// Get current tap count
  int get currentTapCount {
    if (_subscriptionProvider.isSubscribed) return 0;
    return _adsManager?.currentTapCount ?? 0;
  }

  /// Reset tap counter
  void resetTapCount() {
    if (_subscriptionProvider.isSubscribed) return;
    _adsManager?.resetTapCount();
  }

  /// Get next available network
  AdNetwork? get nextAvailableNetwork {
    if (_subscriptionProvider.isSubscribed) return null;
    return _adsManager?.nextAvailableNetwork;
  }

  /// Force reload all ads
  void reloadAll() {
    if (_subscriptionProvider.isSubscribed) {
      debugPrint('[SubscriptionInterstitial] ✨ User subscribed - no reload needed');
      return;
    }

    _adsManager?.reloadAll();
  }

  /// Get ad status
  Map<String, bool> get adStatus {
    if (_subscriptionProvider.isSubscribed) {
      return {
        'subscribed': true,
        'adsEnabled': false,
        'admobPrimary': false,
        'admobSecondary': false,
        'meta': false,
        'unity': false,
      };
    }

    final status = _adsManager?.adStatus ?? {};
    return {
      'subscribed': false,
      'adsEnabled': true,
      ...status,
    };
  }

  /// Check if ads are enabled
  bool get adsEnabled => !_subscriptionProvider.isSubscribed;

  /// Check if user is subscribed
  bool get isSubscribed => _subscriptionProvider.isSubscribed;

  // ─────────────────── DISPOSE ───────────────────

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _subscriptionProvider.removeListener(_onSubscriptionChanged);
    _adsManager?.dispose();
    _adsManager = null;

    debugPrint('[SubscriptionInterstitial] Disposed');
  }
}