import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../subscription/subscription_provider.dart';
import 'package:flutter/material.dart';

/// Manages AdMob native ads with subscription awareness and priority fallback
/// Fallback chain:
/// 1. Native Primary Ad (High Priority)
/// 2. Native Primary Ad (Medium Priority)
/// 3. Native Primary Ad (Low Priority)
class SubscriptionAwareNativeAdManager {
  final SubscriptionProvider subscriptionProvider;
  final String nativePrimaryIdHigh;
  final String nativePrimaryIdMed;
  final String nativePrimaryIdLow;
  final int maxRetry;

  // Ad instances
  NativeAd? _nativePrimaryHighAd;
  NativeAd? _nativePrimaryMedAd;
  NativeAd? _nativePrimaryLowAd;

  // Ready states
  bool _isPrimaryHighReady = false;
  bool _isPrimaryMedReady = false;
  bool _isPrimaryLowReady = false;

  // Loading states
  bool _isLoadingPrimaryHigh = false;
  bool _isLoadingPrimaryMed = false;
  bool _isLoadingPrimaryLow = false;

  // Retry counters
  int _primaryHighRetryCount = 0;
  int _primaryMedRetryCount = 0;
  int _primaryLowRetryCount = 0;

  SubscriptionAwareNativeAdManager({
    required this.subscriptionProvider,
    required this.nativePrimaryIdHigh,
    required this.nativePrimaryIdMed,
    required this.nativePrimaryIdLow,
    this.maxRetry = 3,
  }) {
    _initialize();
  }

  // ========================================================================
  // INITIALIZATION
  // ========================================================================

  void _initialize() {
    debugPrint('[NativeAdManager] Initializing with 3 priority levels...');

    // Load all ads in priority order
    _loadNativePrimaryHighAd();
    _loadNativePrimaryMedAd();
    _loadNativePrimaryLowAd();
  }

  // ========================================================================
  // LOAD NATIVE ADS
  // ========================================================================

  Future<void> _loadNativePrimaryHighAd() async {
    if (_isLoadingPrimaryHigh) return;

    _isLoadingPrimaryHigh = true;
    debugPrint('[NativeAdManager] Loading primary HIGH: $nativePrimaryIdHigh');

    try {
      _nativePrimaryHighAd = NativeAd(
        adUnitId: nativePrimaryIdHigh,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            debugPrint('[NativeAdManager] ✅ Primary HIGH loaded');
            _isPrimaryHighReady = true;
            _isLoadingPrimaryHigh = false;
            _primaryHighRetryCount = 0;
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('[NativeAdManager] ❌ Primary HIGH failed: ${error.message}');
            ad.dispose();
            _nativePrimaryHighAd = null;
            _isPrimaryHighReady = false;
            _isLoadingPrimaryHigh = false;
            _handlePrimaryHighLoadError();
          },
          onAdOpened: (ad) {
            debugPrint('[NativeAdManager] Primary HIGH opened');
          },
          onAdClosed: (ad) {
            debugPrint('[NativeAdManager] Primary HIGH closed');
          },
          onAdImpression: (ad) {
            debugPrint('[NativeAdManager] Primary HIGH impression');
          },
        ),
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: Colors.white,
          cornerRadius: 10.0,
        ),
      );

      await _nativePrimaryHighAd!.load();
    } catch (e) {
      debugPrint('[NativeAdManager] ❌ Primary HIGH exception: $e');
      _isLoadingPrimaryHigh = false;
      _handlePrimaryHighLoadError();
    }
  }

  Future<void> _loadNativePrimaryMedAd() async {
    if (_isLoadingPrimaryMed) return;

    _isLoadingPrimaryMed = true;
    debugPrint('[NativeAdManager] Loading primary MED: $nativePrimaryIdMed');

    try {
      _nativePrimaryMedAd = NativeAd(
        adUnitId: nativePrimaryIdMed,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            debugPrint('[NativeAdManager] ✅ Primary MED loaded');
            _isPrimaryMedReady = true;
            _isLoadingPrimaryMed = false;
            _primaryMedRetryCount = 0;
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('[NativeAdManager] ❌ Primary MED failed: ${error.message}');
            ad.dispose();
            _nativePrimaryMedAd = null;
            _isPrimaryMedReady = false;
            _isLoadingPrimaryMed = false;
            _handlePrimaryMedLoadError();
          },
          onAdOpened: (ad) {
            debugPrint('[NativeAdManager] Primary MED opened');
          },
          onAdClosed: (ad) {
            debugPrint('[NativeAdManager] Primary MED closed');
          },
          onAdImpression: (ad) {
            debugPrint('[NativeAdManager] Primary MED impression');
          },
        ),
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: Colors.white,
          cornerRadius: 10.0,
        ),
      );

      await _nativePrimaryMedAd!.load();
    } catch (e) {
      debugPrint('[NativeAdManager] ❌ Primary MED exception: $e');
      _isLoadingPrimaryMed = false;
      _handlePrimaryMedLoadError();
    }
  }

  Future<void> _loadNativePrimaryLowAd() async {
    if (_isLoadingPrimaryLow) return;

    _isLoadingPrimaryLow = true;
    debugPrint('[NativeAdManager] Loading primary LOW: $nativePrimaryIdLow');

    try {
      _nativePrimaryLowAd = NativeAd(
        adUnitId: nativePrimaryIdLow,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            debugPrint('[NativeAdManager] ✅ Primary LOW loaded');
            _isPrimaryLowReady = true;
            _isLoadingPrimaryLow = false;
            _primaryLowRetryCount = 0;
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('[NativeAdManager] ❌ Primary LOW failed: ${error.message}');
            ad.dispose();
            _nativePrimaryLowAd = null;
            _isPrimaryLowReady = false;
            _isLoadingPrimaryLow = false;
            _handlePrimaryLowLoadError();
          },
          onAdOpened: (ad) {
            debugPrint('[NativeAdManager] Primary LOW opened');
          },
          onAdClosed: (ad) {
            debugPrint('[NativeAdManager] Primary LOW closed');
          },
          onAdImpression: (ad) {
            debugPrint('[NativeAdManager] Primary LOW impression');
          },
        ),
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: Colors.white,
          cornerRadius: 10.0,
        ),
      );

      await _nativePrimaryLowAd!.load();
    } catch (e) {
      debugPrint('[NativeAdManager] ❌ Primary LOW exception: $e');
      _isLoadingPrimaryLow = false;
      _handlePrimaryLowLoadError();
    }
  }

  // ========================================================================
  // ERROR HANDLING WITH RETRY
  // ========================================================================

  void _handlePrimaryHighLoadError() {
    if (_primaryHighRetryCount < maxRetry) {
      _primaryHighRetryCount++;
      debugPrint('[NativeAdManager] Retrying primary HIGH ($_primaryHighRetryCount/$maxRetry)...');
      Future.delayed(
        Duration(seconds: _primaryHighRetryCount * 2),
        _loadNativePrimaryHighAd,
      );
    } else {
      debugPrint('[NativeAdManager] Primary HIGH retry limit reached');
    }
  }

  void _handlePrimaryMedLoadError() {
    if (_primaryMedRetryCount < maxRetry) {
      _primaryMedRetryCount++;
      debugPrint('[NativeAdManager] Retrying primary MED ($_primaryMedRetryCount/$maxRetry)...');
      Future.delayed(
        Duration(seconds: _primaryMedRetryCount * 2),
        _loadNativePrimaryMedAd,
      );
    } else {
      debugPrint('[NativeAdManager] Primary MED retry limit reached');
    }
  }

  void _handlePrimaryLowLoadError() {
    if (_primaryLowRetryCount < maxRetry) {
      _primaryLowRetryCount++;
      debugPrint('[NativeAdManager] Retrying primary LOW ($_primaryLowRetryCount/$maxRetry)...');
      Future.delayed(
        Duration(seconds: _primaryLowRetryCount * 2),
        _loadNativePrimaryLowAd,
      );
    } else {
      debugPrint('[NativeAdManager] Primary LOW retry limit reached');
    }
  }

  // ========================================================================
  // GET NATIVE AD (WITH FALLBACK CHAIN)
  // ========================================================================

  /// Gets the best available native ad following the priority chain:
  /// Primary High → Primary Med → Primary Low
  NativeAd? getNativeAd() {
    // Check subscription status
    if (subscriptionProvider.isSubscribed) {
      debugPrint('[NativeAdManager] 🌟 Premium user - no ads');
      return null;
    }

    // Try primary ads in order
    if (_isPrimaryHighReady && _nativePrimaryHighAd != null) {
      debugPrint('[NativeAdManager] 📺 Returning primary HIGH ad');
      return _nativePrimaryHighAd;
    }

    if (_isPrimaryMedReady && _nativePrimaryMedAd != null) {
      debugPrint('[NativeAdManager] 📺 Returning primary MED ad');
      return _nativePrimaryMedAd;
    }

    if (_isPrimaryLowReady && _nativePrimaryLowAd != null) {
      debugPrint('[NativeAdManager] 📺 Returning primary LOW ad');
      return _nativePrimaryLowAd;
    }

    debugPrint('[NativeAdManager] ❌ No ads available');
    return null;
  }

  // ========================================================================
  // PUBLIC API
  // ========================================================================

  /// Check if any native ad is ready
  bool get isReady =>
      _isPrimaryHighReady || _isPrimaryMedReady || _isPrimaryLowReady;

  /// Get detailed status of each ad
  Map<String, bool> get adStatus => {
    'primary_high_ready': _isPrimaryHighReady,
    'primary_med_ready': _isPrimaryMedReady,
    'primary_low_ready': _isPrimaryLowReady,
    'loading_primary_high': _isLoadingPrimaryHigh,
    'loading_primary_med': _isLoadingPrimaryMed,
    'loading_primary_low': _isLoadingPrimaryLow,
  };

  /// Get which ad is currently being served
  String get currentAdSource {
    if (subscriptionProvider.isSubscribed) return 'premium_user';
    if (_isPrimaryHighReady) return 'primary_high';
    if (_isPrimaryMedReady) return 'primary_med';
    if (_isPrimaryLowReady) return 'primary_low';
    return 'none';
  }

  /// Manually reload all ads
  Future<void> reloadAllAds() async {
    debugPrint('[NativeAdManager] Reloading all ads...');

    if (!_isLoadingPrimaryHigh && !_isPrimaryHighReady) {
      _loadNativePrimaryHighAd();
    }
    if (!_isLoadingPrimaryMed && !_isPrimaryMedReady) {
      _loadNativePrimaryMedAd();
    }
    if (!_isLoadingPrimaryLow && !_isPrimaryLowReady) {
      _loadNativePrimaryLowAd();
    }
  }

  /// Reload a specific ad by priority
  Future<void> reloadAd(String priority) async {
    switch (priority.toLowerCase()) {
      case 'high':
        if (!_isLoadingPrimaryHigh) {
          _primaryHighRetryCount = 0;
          _loadNativePrimaryHighAd();
        }
        break;
      case 'med':
      case 'medium':
        if (!_isLoadingPrimaryMed) {
          _primaryMedRetryCount = 0;
          _loadNativePrimaryMedAd();
        }
        break;
      case 'low':
        if (!_isLoadingPrimaryLow) {
          _primaryLowRetryCount = 0;
          _loadNativePrimaryLowAd();
        }
        break;
    }
  }

  // ========================================================================
  // DISPOSE
  // ========================================================================

  void dispose() {
    debugPrint('[NativeAdManager] Disposing all ads...');

    _nativePrimaryHighAd?.dispose();
    _nativePrimaryMedAd?.dispose();
    _nativePrimaryLowAd?.dispose();

    _nativePrimaryHighAd = null;
    _nativePrimaryMedAd = null;
    _nativePrimaryLowAd = null;
  }
}