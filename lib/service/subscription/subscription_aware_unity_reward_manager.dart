import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import '../subscription/subscription_provider.dart';

/// Manages Unity reward ads with subscription awareness and fallback to interstitial
/// Fallback chain:
/// 1. Unity Primary Reward Ad (High Priority)
/// 2. Unity Primary Reward Ad (Medium Priority)
/// 3. Unity Primary Reward Ad (Low Priority)
/// 4. Unity Secondary Reward Ad
/// 5. AdMob Interstitial Ad (as final fallback)
class SubscriptionAwareUnityRewardManager {
  final SubscriptionProvider subscriptionProvider;
  final String unityPrimaryRewardIdHigh;
  final String unityPrimaryRewardIdMed;
  final String unityPrimaryRewardIdLow;
  final String unitySecondaryRewardId;
  final String admobInterstitialId;
  final int maxRetry;

  // State tracking for primary ads
  bool _isPrimaryRewardHighReady = false;
  bool _isPrimaryRewardMedReady = false;
  bool _isPrimaryRewardLowReady = false;

  // State tracking for other ads
  bool _isSecondaryRewardReady = false;
  bool _isAdMobInterstitialReady = false;

  // Loading states
  bool _isLoadingPrimaryHigh = false;
  bool _isLoadingPrimaryMed = false;
  bool _isLoadingPrimaryLow = false;
  bool _isLoadingSecondaryReward = false;
  bool _isLoadingAdMobInterstitial = false;

  // Retry counters
  int _primaryHighRetryCount = 0;
  int _primaryMedRetryCount = 0;
  int _primaryLowRetryCount = 0;
  int _secondaryRetryCount = 0;
  int _admobRetryCount = 0;

  // Callbacks
  Function(bool completed, String? itemId, int? amount)? _onRewardedComplete;
  Function()? _onRewardFailed;

  SubscriptionAwareUnityRewardManager({
    required this.subscriptionProvider,
    required this.unityPrimaryRewardIdHigh,
    required this.unityPrimaryRewardIdMed,
    required this.unityPrimaryRewardIdLow,
    required this.unitySecondaryRewardId,
    required this.admobInterstitialId,
    this.maxRetry = 3,
  }) {
    _initialize();
  }

  // ========================================================================
  // INITIALIZATION
  // ========================================================================

  void _initialize() {
    debugPrint('[UnityRewardManager] Initializing with 3 primary reward ads...');

    // Load all primary reward ads immediately
    _loadPrimaryRewardAdHigh();
    _loadPrimaryRewardAdMed();
    _loadPrimaryRewardAdLow();

    // Preload secondary and admob as backup
    _loadSecondaryRewardAd();
    _loadAdMobInterstitialAd();
  }

  // ========================================================================
  // LOAD PRIMARY ADS (HIGH, MED, LOW)
  // ========================================================================

  Future<void> _loadPrimaryRewardAdHigh() async {
    if (_isLoadingPrimaryHigh) return;

    _isLoadingPrimaryHigh = true;
    debugPrint('[UnityRewardManager] Loading primary reward ad (HIGH): $unityPrimaryRewardIdHigh');

    try {
      await UnityAds.load(
        placementId: unityPrimaryRewardIdHigh,
        onComplete: (placementId) {
          debugPrint('[UnityRewardManager] ✅ Primary reward ad (HIGH) loaded');
          _isPrimaryRewardHighReady = true;
          _isLoadingPrimaryHigh = false;
          _primaryHighRetryCount = 0;
        },
        onFailed: (placementId, error, message) {
          debugPrint('[UnityRewardManager] ❌ Primary reward (HIGH) failed: $message');
          _isPrimaryRewardHighReady = false;
          _isLoadingPrimaryHigh = false;
          _handlePrimaryHighLoadError();
        },
      );
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ Primary (HIGH) load exception: $e');
      _isLoadingPrimaryHigh = false;
      _handlePrimaryHighLoadError();
    }
  }

  Future<void> _loadPrimaryRewardAdMed() async {
    if (_isLoadingPrimaryMed) return;

    _isLoadingPrimaryMed = true;
    debugPrint('[UnityRewardManager] Loading primary reward ad (MED): $unityPrimaryRewardIdMed');

    try {
      await UnityAds.load(
        placementId: unityPrimaryRewardIdMed,
        onComplete: (placementId) {
          debugPrint('[UnityRewardManager] ✅ Primary reward ad (MED) loaded');
          _isPrimaryRewardMedReady = true;
          _isLoadingPrimaryMed = false;
          _primaryMedRetryCount = 0;
        },
        onFailed: (placementId, error, message) {
          debugPrint('[UnityRewardManager] ❌ Primary reward (MED) failed: $message');
          _isPrimaryRewardMedReady = false;
          _isLoadingPrimaryMed = false;
          _handlePrimaryMedLoadError();
        },
      );
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ Primary (MED) load exception: $e');
      _isLoadingPrimaryMed = false;
      _handlePrimaryMedLoadError();
    }
  }

  Future<void> _loadPrimaryRewardAdLow() async {
    if (_isLoadingPrimaryLow) return;

    _isLoadingPrimaryLow = true;
    debugPrint('[UnityRewardManager] Loading primary reward ad (LOW): $unityPrimaryRewardIdLow');

    try {
      await UnityAds.load(
        placementId: unityPrimaryRewardIdLow,
        onComplete: (placementId) {
          debugPrint('[UnityRewardManager] ✅ Primary reward ad (LOW) loaded');
          _isPrimaryRewardLowReady = true;
          _isLoadingPrimaryLow = false;
          _primaryLowRetryCount = 0;
        },
        onFailed: (placementId, error, message) {
          debugPrint('[UnityRewardManager] ❌ Primary reward (LOW) failed: $message');
          _isPrimaryRewardLowReady = false;
          _isLoadingPrimaryLow = false;
          _handlePrimaryLowLoadError();
        },
      );
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ Primary (LOW) load exception: $e');
      _isLoadingPrimaryLow = false;
      _handlePrimaryLowLoadError();
    }
  }

  Future<void> _loadSecondaryRewardAd() async {
    if (_isLoadingSecondaryReward) return;

    _isLoadingSecondaryReward = true;
    debugPrint('[UnityRewardManager] Loading secondary reward ad: $unitySecondaryRewardId');

    try {
      await UnityAds.load(
        placementId: unitySecondaryRewardId,
        onComplete: (placementId) {
          debugPrint('[UnityRewardManager] ✅ Secondary reward ad loaded');
          _isSecondaryRewardReady = true;
          _isLoadingSecondaryReward = false;
          _secondaryRetryCount = 0;
        },
        onFailed: (placementId, error, message) {
          debugPrint('[UnityRewardManager] ❌ Secondary reward failed: $message');
          _isSecondaryRewardReady = false;
          _isLoadingSecondaryReward = false;
          _handleSecondaryLoadError();
        },
      );
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ Secondary load exception: $e');
      _isLoadingSecondaryReward = false;
      _handleSecondaryLoadError();
    }
  }

  Future<void> _loadAdMobInterstitialAd() async {
    if (_isLoadingAdMobInterstitial) return;

    _isLoadingAdMobInterstitial = true;
    debugPrint('[UnityRewardManager] Loading AdMob interstitial fallback: $admobInterstitialId');

    try {
      // Import your AdMob manager here
      // For now, just marking as ready after delay (replace with actual AdMob implementation)
      await Future.delayed(const Duration(seconds: 2));
      _isAdMobInterstitialReady = true;
      _isLoadingAdMobInterstitial = false;
      _admobRetryCount = 0;
      debugPrint('[UnityRewardManager] ✅ AdMob interstitial loaded');
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ AdMob load exception: $e');
      _isLoadingAdMobInterstitial = false;
      _handleAdMobLoadError();
    }
  }

  // ========================================================================
  // ERROR HANDLING WITH RETRY
  // ========================================================================

  void _handlePrimaryHighLoadError() {
    if (_primaryHighRetryCount < maxRetry) {
      _primaryHighRetryCount++;
      debugPrint('[UnityRewardManager] Retrying primary (HIGH) ($_primaryHighRetryCount/$maxRetry)...');
      Future.delayed(Duration(seconds: _primaryHighRetryCount * 2), _loadPrimaryRewardAdHigh);
    } else {
      debugPrint('[UnityRewardManager] Primary (HIGH) retry limit reached');
    }
  }

  void _handlePrimaryMedLoadError() {
    if (_primaryMedRetryCount < maxRetry) {
      _primaryMedRetryCount++;
      debugPrint('[UnityRewardManager] Retrying primary (MED) ($_primaryMedRetryCount/$maxRetry)...');
      Future.delayed(Duration(seconds: _primaryMedRetryCount * 2), _loadPrimaryRewardAdMed);
    } else {
      debugPrint('[UnityRewardManager] Primary (MED) retry limit reached');
    }
  }

  void _handlePrimaryLowLoadError() {
    if (_primaryLowRetryCount < maxRetry) {
      _primaryLowRetryCount++;
      debugPrint('[UnityRewardManager] Retrying primary (LOW) ($_primaryLowRetryCount/$maxRetry)...');
      Future.delayed(Duration(seconds: _primaryLowRetryCount * 2), _loadPrimaryRewardAdLow);
    } else {
      debugPrint('[UnityRewardManager] Primary (LOW) retry limit reached');
    }
  }

  void _handleSecondaryLoadError() {
    if (_secondaryRetryCount < maxRetry) {
      _secondaryRetryCount++;
      debugPrint('[UnityRewardManager] Retrying secondary ($_secondaryRetryCount/$maxRetry)...');
      Future.delayed(Duration(seconds: _secondaryRetryCount * 2), _loadSecondaryRewardAd);
    } else {
      debugPrint('[UnityRewardManager] Secondary retry limit reached');
    }
  }

  void _handleAdMobLoadError() {
    if (_admobRetryCount < maxRetry) {
      _admobRetryCount++;
      debugPrint('[UnityRewardManager] Retrying AdMob ($_admobRetryCount/$maxRetry)...');
      Future.delayed(Duration(seconds: _admobRetryCount * 2), _loadAdMobInterstitialAd);
    } else {
      debugPrint('[UnityRewardManager] AdMob retry limit reached');
    }
  }

  // ========================================================================
  // SHOW REWARD AD (WITH EXTENDED FALLBACK CHAIN)
  // ========================================================================

  /// Shows reward ad with fallback chain:
  /// Unity Primary (High) → Unity Primary (Med) → Unity Primary (Low) →
  /// Unity Secondary → AdMob Interstitial
  Future<void> showRewardAd({
    required Function(bool completed, String? itemId, int? amount) onComplete,
    Function()? onFailed,
  }) async {
    // ✅ Check subscription status
    if (subscriptionProvider.isSubscribed) {
      debugPrint('[UnityRewardManager] 🌟 Premium user - no ads');
      onComplete(true, 'premium_bypass', 0);
      return;
    }

    _onRewardedComplete = onComplete;
    _onRewardFailed = onFailed;

    // Try primary reward ads in order: High → Med → Low
    if (_isPrimaryRewardHighReady) {
      await _showPrimaryRewardAdHigh();
      return;
    }

    if (_isPrimaryRewardMedReady) {
      await _showPrimaryRewardAdMed();
      return;
    }

    if (_isPrimaryRewardLowReady) {
      await _showPrimaryRewardAdLow();
      return;
    }

    // Fallback to secondary reward ad
    if (_isSecondaryRewardReady) {
      await _showSecondaryRewardAd();
      return;
    }

    debugPrint('[UnityRewardManager] No Unity ads ready, falling back to AdMob interstitial...');

    // Final fallback to AdMob interstitial
    if (_isAdMobInterstitialReady) {
      await _showAdMobInterstitial();
      return;
    }

    // No ads available
    debugPrint('[UnityRewardManager] ❌ No ads available');
    _onRewardFailed?.call();
    _onRewardedComplete?.call(false, null, null);
  }

  // ========================================================================
  // SHOW PRIMARY REWARD ADS
  // ========================================================================

  Future<void> _showPrimaryRewardAdHigh() async {
    debugPrint('[UnityRewardManager] 📺 Showing primary reward ad (HIGH)');

    try {
      await UnityAds.showVideoAd(
        placementId: unityPrimaryRewardIdHigh,
        onComplete: (placementId) {
          debugPrint('[UnityRewardManager] ✅ Primary reward (HIGH) completed');
          _isPrimaryRewardHighReady = false;
          _onRewardedComplete?.call(true, 'unity_primary_high', 1);

          // Reload for next time
          _loadPrimaryRewardAdHigh();
        },
        onFailed: (placementId, error, message) {
          debugPrint('[UnityRewardManager] ❌ Primary (HIGH) show failed: $message');
          _isPrimaryRewardHighReady = false;

          // Try next in fallback chain
          _showFallbackAd();
        },
        onStart: (placementId) {
          debugPrint('[UnityRewardManager] Primary ad (HIGH) started');
        },
        onClick: (placementId) {
          debugPrint('[UnityRewardManager] Primary ad (HIGH) clicked');
        },
        onSkipped: (placementId) {
          debugPrint('[UnityRewardManager] ⏭️ Primary ad (HIGH) skipped');
          _isPrimaryRewardHighReady = false;
          _onRewardedComplete?.call(false, null, null);

          // Reload for next time
          _loadPrimaryRewardAdHigh();
        },
      );
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ Primary (HIGH) show exception: $e');
      _isPrimaryRewardHighReady = false;
      _showFallbackAd();
    }
  }

  Future<void> _showPrimaryRewardAdMed() async {
    debugPrint('[UnityRewardManager] 📺 Showing primary reward ad (MED)');

    try {
      await UnityAds.showVideoAd(
        placementId: unityPrimaryRewardIdMed,
        onComplete: (placementId) {
          debugPrint('[UnityRewardManager] ✅ Primary reward (MED) completed');
          _isPrimaryRewardMedReady = false;
          _onRewardedComplete?.call(true, 'unity_primary_med', 1);

          // Reload for next time
          _loadPrimaryRewardAdMed();
        },
        onFailed: (placementId, error, message) {
          debugPrint('[UnityRewardManager] ❌ Primary (MED) show failed: $message');
          _isPrimaryRewardMedReady = false;

          // Try next in fallback chain
          _showFallbackAd();
        },
        onStart: (placementId) {
          debugPrint('[UnityRewardManager] Primary ad (MED) started');
        },
        onClick: (placementId) {
          debugPrint('[UnityRewardManager] Primary ad (MED) clicked');
        },
        onSkipped: (placementId) {
          debugPrint('[UnityRewardManager] ⏭️ Primary ad (MED) skipped');
          _isPrimaryRewardMedReady = false;
          _onRewardedComplete?.call(false, null, null);

          // Reload for next time
          _loadPrimaryRewardAdMed();
        },
      );
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ Primary (MED) show exception: $e');
      _isPrimaryRewardMedReady = false;
      _showFallbackAd();
    }
  }

  Future<void> _showPrimaryRewardAdLow() async {
    debugPrint('[UnityRewardManager] 📺 Showing primary reward ad (LOW)');

    try {
      await UnityAds.showVideoAd(
        placementId: unityPrimaryRewardIdLow,
        onComplete: (placementId) {
          debugPrint('[UnityRewardManager] ✅ Primary reward (LOW) completed');
          _isPrimaryRewardLowReady = false;
          _onRewardedComplete?.call(true, 'unity_primary_low', 1);

          // Reload for next time
          _loadPrimaryRewardAdLow();
        },
        onFailed: (placementId, error, message) {
          debugPrint('[UnityRewardManager] ❌ Primary (LOW) show failed: $message');
          _isPrimaryRewardLowReady = false;

          // Try secondary or AdMob
          _showSecondaryOrAdMob();
        },
        onStart: (placementId) {
          debugPrint('[UnityRewardManager] Primary ad (LOW) started');
        },
        onClick: (placementId) {
          debugPrint('[UnityRewardManager] Primary ad (LOW) clicked');
        },
        onSkipped: (placementId) {
          debugPrint('[UnityRewardManager] ⏭️ Primary ad (LOW) skipped');
          _isPrimaryRewardLowReady = false;
          _onRewardedComplete?.call(false, null, null);

          // Reload for next time
          _loadPrimaryRewardAdLow();
        },
      );
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ Primary (LOW) show exception: $e');
      _isPrimaryRewardLowReady = false;
      _showSecondaryOrAdMob();
    }
  }

  // ========================================================================
  // SHOW SECONDARY REWARD AD
  // ========================================================================

  Future<void> _showSecondaryRewardAd() async {
    debugPrint('[UnityRewardManager] 📺 Showing secondary reward ad');

    try {
      await UnityAds.showVideoAd(
        placementId: unitySecondaryRewardId,
        onComplete: (placementId) {
          debugPrint('[UnityRewardManager] ✅ Secondary reward completed');
          _isSecondaryRewardReady = false;
          _onRewardedComplete?.call(true, 'unity_secondary', 1);

          // Reload for next time
          _loadSecondaryRewardAd();
        },
        onFailed: (placementId, error, message) {
          debugPrint('[UnityRewardManager] ❌ Secondary show failed: $message');
          _isSecondaryRewardReady = false;

          // Try AdMob fallback
          if (_isAdMobInterstitialReady) {
            _showAdMobInterstitial();
          } else {
            _onRewardFailed?.call();
            _onRewardedComplete?.call(false, null, null);
          }
        },
        onStart: (placementId) {
          debugPrint('[UnityRewardManager] Secondary ad started');
        },
        onClick: (placementId) {
          debugPrint('[UnityRewardManager] Secondary ad clicked');
        },
        onSkipped: (placementId) {
          debugPrint('[UnityRewardManager] ⏭️ Secondary ad skipped');
          _isSecondaryRewardReady = false;
          _onRewardedComplete?.call(false, null, null);

          // Reload for next time
          _loadSecondaryRewardAd();
        },
      );
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ Secondary show exception: $e');
      _isSecondaryRewardReady = false;

      // Try AdMob fallback
      if (_isAdMobInterstitialReady) {
        _showAdMobInterstitial();
      } else {
        _onRewardFailed?.call();
        _onRewardedComplete?.call(false, null, null);
      }
    }
  }

  // ========================================================================
  // SHOW ADMOB INTERSTITIAL (FALLBACK)
  // ========================================================================

  Future<void> _showAdMobInterstitial() async {
    debugPrint('[UnityRewardManager] 📺 Showing AdMob interstitial fallback');

    try {
      // TODO: Implement actual AdMob interstitial show
      // For now, simulate success
      await Future.delayed(const Duration(seconds: 2));

      debugPrint('[UnityRewardManager] ✅ AdMob interstitial completed');
      _isAdMobInterstitialReady = false;
      _onRewardedComplete?.call(true, 'admob_fallback', 1);

      // Reload for next time
      _loadAdMobInterstitialAd();
    } catch (e) {
      debugPrint('[UnityRewardManager] ❌ AdMob show exception: $e');
      _onRewardFailed?.call();
      _onRewardedComplete?.call(false, null, null);
    }
  }

  // ========================================================================
  // FALLBACK HELPERS
  // ========================================================================

  Future<void> _showFallbackAd() async {
    debugPrint('[UnityRewardManager] Attempting fallback chain...');

    // Try remaining primary ads in order: Med → Low
    if (_isPrimaryRewardMedReady) {
      await _showPrimaryRewardAdMed();
      return;
    }

    if (_isPrimaryRewardLowReady) {
      await _showPrimaryRewardAdLow();
      return;
    }

    // If no primary ads, try secondary
    if (_isSecondaryRewardReady) {
      await _showSecondaryRewardAd();
      return;
    }

    // Finally try AdMob
    if (_isAdMobInterstitialReady) {
      await _showAdMobInterstitial();
      return;
    }

    // No fallbacks available
    debugPrint('[UnityRewardManager] ❌ No fallback ads available');
    _onRewardFailed?.call();
    _onRewardedComplete?.call(false, null, null);
  }

  Future<void> _showSecondaryOrAdMob() async {
    debugPrint('[UnityRewardManager] Falling back to secondary or AdMob...');

    // Try secondary
    if (_isSecondaryRewardReady) {
      await _showSecondaryRewardAd();
      return;
    }

    // Try AdMob
    if (_isAdMobInterstitialReady) {
      await _showAdMobInterstitial();
      return;
    }

    // No ads available
    debugPrint('[UnityRewardManager] ❌ No fallback ads available');
    _onRewardFailed?.call();
    _onRewardedComplete?.call(false, null, null);
  }

  // ========================================================================
  // PUBLIC API
  // ========================================================================

  /// Check if any ad is ready
  bool get isReady =>
      _isPrimaryRewardHighReady ||
          _isPrimaryRewardMedReady ||
          _isPrimaryRewardLowReady ||
          _isSecondaryRewardReady ||
          _isAdMobInterstitialReady;

  /// Get status of each ad type
  Map<String, bool> get adStatus => {
    'primary_high_ready': _isPrimaryRewardHighReady,
    'primary_med_ready': _isPrimaryRewardMedReady,
    'primary_low_ready': _isPrimaryRewardLowReady,
    'secondary_ready': _isSecondaryRewardReady,
    'admob_ready': _isAdMobInterstitialReady,
    'loading_primary_high': _isLoadingPrimaryHigh,
    'loading_primary_med': _isLoadingPrimaryMed,
    'loading_primary_low': _isLoadingPrimaryLow,
    'loading_secondary': _isLoadingSecondaryReward,
    'loading_admob': _isLoadingAdMobInterstitial,
  };

  /// Manually reload all ads
  Future<void> reloadAllAds() async {
    debugPrint('[UnityRewardManager] Reloading all ads...');

    // Reload all primary ads if not already loading/ready
    if (!_isLoadingPrimaryHigh && !_isPrimaryRewardHighReady) {
      _loadPrimaryRewardAdHigh();
    }
    if (!_isLoadingPrimaryMed && !_isPrimaryRewardMedReady) {
      _loadPrimaryRewardAdMed();
    }
    if (!_isLoadingPrimaryLow && !_isPrimaryRewardLowReady) {
      _loadPrimaryRewardAdLow();
    }

    // Reload secondary and AdMob
    if (!_isLoadingSecondaryReward && !_isSecondaryRewardReady) {
      _loadSecondaryRewardAd();
    }
    if (!_isLoadingAdMobInterstitial && !_isAdMobInterstitialReady) {
      _loadAdMobInterstitialAd();
    }
  }

  // ========================================================================
  // DISPOSE
  // ========================================================================

  void dispose() {
    debugPrint('[UnityRewardManager] Disposing...');
    _onRewardedComplete = null;
    _onRewardFailed = null;
  }
}