import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

enum AdNetwork { admobPrimary, admobSecondary, meta, unity }

/// Smart Video Interstitial Ads Manager
/// Priority: AdMob Primary → AdMob Secondary → Meta → Unity
/// All ads are video interstitials only (no rewarded ads)
class SmartInterstitialAdsManager {
  final int tapThreshold;
  final String admobPrimaryId;
  final String admobSecondaryId;
  final String metaInterstitialId;
  final String unityInterstitialId;

  final int _maxRetry;

  int _tapCount = 0;
  bool _disposed = false;
  bool _isShowingAd = false;

  // Retry counters
  int _admobPrimaryRetries = 0;
  int _admobSecondaryRetries = 0;
  int _metaInterstitialRetries = 0;
  int _unityInterstitialRetries = 0;

  InterstitialAd? _admobPrimary;

  InterstitialAd? _admobSecondary;

  bool _metaInterstitialReady = false;

  bool _unityInterstitialReady = false;

  SmartInterstitialAdsManager({
    required this.tapThreshold,
    required this.admobPrimaryId,
    required this.admobSecondaryId,
    required this.metaInterstitialId,
    required this.unityInterstitialId,
    int maxRetry = 3,
  }) : _maxRetry = maxRetry;

  void loadAll() {
    if (_disposed) return;

    _loadAdMobPrimary();
    _loadAdMobSecondary();
    _loadMetaInterstitial();
    _loadUnityInterstitial();
  }

  void registerTap() {
    if (_disposed || _isShowingAd) return;

    _tapCount++;
    debugPrint("[SmartInterstitialAds] Tap $_tapCount / $tapThreshold");

    if (_tapCount >= tapThreshold) {
      _tapCount = 0;
      showAd();
    }
  }


  Future<void> showAd() async {
    if (_disposed || _isShowingAd) {
      debugPrint("[SmartInterstitialAds] Already showing ad or disposed");
      return;
    }

    _isShowingAd = true;

    try {
      await _showInterstitial();
    } catch (e) {
      debugPrint("[SmartInterstitialAds] Error showing ad: $e");
    } finally {
      _isShowingAd = false;
    }
  }


  Future<void> _showInterstitial() async {
    try {
      if (_admobPrimary != null) {
        debugPrint("[SmartInterstitialAds] Showing AdMob PRIMARY (video interstitial)");
        await _admobPrimary!.show();
        return;
      }

      if (_admobSecondary != null) {
        debugPrint("[SmartInterstitialAds] Primary unavailable, showing AdMob SECONDARY");
        await _admobSecondary!.show();
        return;
      }

      if (_metaInterstitialReady) {
        debugPrint("[SmartInterstitialAds] Both AdMob unavailable, showing Meta interstitial");
        final result = await FacebookInterstitialAd.showInterstitialAd();
        if (result == true) {
          _metaInterstitialReady = false;
          _loadMetaInterstitial();
          return;
        }
      }

      if (_unityInterstitialReady) {
        debugPrint("[SmartInterstitialAds] AdMob & Meta unavailable, showing Unity interstitial");
        UnityAds.showVideoAd(
          placementId: unityInterstitialId,
          onComplete: (placementId) {
            debugPrint("[SmartInterstitialAds] Unity interstitial complete");
          },
          onFailed: (placementId, error, message) {
            debugPrint("[SmartInterstitialAds] Unity interstitial failed: $message");
          },
        );
        _unityInterstitialReady = false;
        _loadUnityInterstitial();
        return;
      }

      debugPrint("[SmartInterstitialAds] No interstitial ads available from any network");
    } catch (e) {
      debugPrint("[SmartInterstitialAds] Interstitial show error: $e");
    }
  }

  void _loadAdMobPrimary() {
    if (_disposed) return;

    debugPrint("[SmartInterstitialAds] Loading AdMob PRIMARY (video interstitial)...");

    InterstitialAd.load(
      adUnitId: admobPrimaryId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("[SmartInterstitialAds] AdMob PRIMARY loaded (video interstitial)");
          _admobPrimaryRetries = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint("[SmartInterstitialAds] AdMob PRIMARY showed");
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint("[SmartInterstitialAds] AdMob PRIMARY dismissed");
              ad.dispose();
              _admobPrimary = null;
              _loadAdMobPrimary();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint("[SmartInterstitialAds] AdMob PRIMARY failed to show: $error");
              ad.dispose();
              _admobPrimary = null;
              _loadAdMobPrimary();
            },
            onAdImpression: (ad) {
              debugPrint("[SmartInterstitialAds] AdMob PRIMARY impression recorded");
            },
          );

          _admobPrimary = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint("[SmartInterstitialAds] AdMob PRIMARY failed to load: $error");
          _admobPrimary = null;

          if (_admobPrimaryRetries < _maxRetry) {
            _admobPrimaryRetries++;
            final delaySeconds = _admobPrimaryRetries * 2;
            debugPrint(
              "[SmartInterstitialAds] Retrying AdMob PRIMARY in ${delaySeconds}s (attempt $_admobPrimaryRetries/$_maxRetry)",
            );
            Future.delayed(
              Duration(seconds: delaySeconds),
              _loadAdMobPrimary,
            );
          } else {
            debugPrint("[SmartInterstitialAds] Max retries for AdMob PRIMARY, will use secondary");
            _admobPrimaryRetries = 0;
          }
        },
      ),
    );
  }

  void _loadAdMobSecondary() {
    if (_disposed) return;

    debugPrint("[SmartInterstitialAds] Loading AdMob SECONDARY (interstitial)...");

    InterstitialAd.load(
      adUnitId: admobSecondaryId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("[SmartInterstitialAds] AdMob SECONDARY loaded (interstitial)");
          _admobSecondaryRetries = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint("[SmartInterstitialAds] AdMob SECONDARY showed");
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint("[SmartInterstitialAds] AdMob SECONDARY dismissed");
              ad.dispose();
              _admobSecondary = null;
              _loadAdMobSecondary();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint("[SmartInterstitialAds] AdMob SECONDARY failed to show: $error");
              ad.dispose();
              _admobSecondary = null;
              _loadAdMobSecondary();
            },
            onAdImpression: (ad) {
              debugPrint("[SmartInterstitialAds] AdMob SECONDARY impression recorded");
            },
          );

          _admobSecondary = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint("[SmartInterstitialAds] AdMob SECONDARY failed to load: $error");
          _admobSecondary = null;

          if (_admobSecondaryRetries < _maxRetry) {
            _admobSecondaryRetries++;
            final delaySeconds = _admobSecondaryRetries * 2;
            debugPrint(
              "[SmartInterstitialAds] Retrying AdMob SECONDARY in ${delaySeconds}s (attempt $_admobSecondaryRetries/$_maxRetry)",
            );
            Future.delayed(
              Duration(seconds: delaySeconds),
              _loadAdMobSecondary,
            );
          } else {
            debugPrint("[SmartInterstitialAds] Max retries for AdMob SECONDARY, will use Meta");
            _admobSecondaryRetries = 0;
          }
        },
      ),
    );
  }

  void _loadMetaInterstitial() {
    if (_disposed) return;

    debugPrint("[SmartInterstitialAds] Loading Meta interstitial (fallback)...");

    FacebookInterstitialAd.loadInterstitialAd(
      placementId: metaInterstitialId,
      listener: (result, value) {
        if (result == InterstitialAdResult.LOADED) {
          debugPrint("[SmartInterstitialAds] Meta interstitial loaded");
          _metaInterstitialReady = true;
          _metaInterstitialRetries = 0;
        } else if (result == InterstitialAdResult.ERROR) {
          debugPrint("[SmartInterstitialAds] Meta interstitial error: $value");
          _metaInterstitialReady = false;

          if (_metaInterstitialRetries < _maxRetry) {
            _metaInterstitialRetries++;
            final delaySeconds = _metaInterstitialRetries * 2;
            debugPrint(
              "[SmartInterstitialAds] Retrying Meta in ${delaySeconds}s (attempt $_metaInterstitialRetries/$_maxRetry)",
            );
            Future.delayed(
              Duration(seconds: delaySeconds),
              _loadMetaInterstitial,
            );
          } else {
            debugPrint("[SmartInterstitialAds] Max retries for Meta");
            _metaInterstitialRetries = 0;
          }
        } else if (result == InterstitialAdResult.DISMISSED) {
          debugPrint("[SmartInterstitialAds] Meta interstitial dismissed");
          _metaInterstitialReady = false;
          _loadMetaInterstitial();
        } else if (result == InterstitialAdResult.DISPLAYED) {
          debugPrint("[SmartInterstitialAds] Meta interstitial displayed");
        }
      },
    );
  }

  void _loadUnityInterstitial() {
    if (_disposed) return;

    debugPrint("[SmartInterstitialAds] Loading Unity interstitial (fallback)...");

    UnityAds.load(
      placementId: unityInterstitialId,
      onComplete: (placementId) {
        debugPrint("[SmartInterstitialAds] Unity interstitial loaded");
        _unityInterstitialReady = true;
        _unityInterstitialRetries = 0;
      },
      onFailed: (placementId, error, message) {
        debugPrint("[SmartInterstitialAds] Unity interstitial load failed: $message");
        _unityInterstitialReady = false;

        // Retry with exponential backoff
        if (_unityInterstitialRetries < _maxRetry) {
          _unityInterstitialRetries++;
          final delaySeconds = _unityInterstitialRetries * 2;
          debugPrint(
            "[SmartInterstitialAds] Retrying Unity in ${delaySeconds}s (attempt $_unityInterstitialRetries/$_maxRetry)",
          );
          Future.delayed(
            Duration(seconds: delaySeconds),
            _loadUnityInterstitial,
          );
        } else {
          debugPrint("[SmartInterstitialAds] Max retries for Unity");
          _unityInterstitialRetries = 0;
        }
      },
    );
  }

  void dispose() {
    if (_disposed) return;

    debugPrint("[SmartInterstitialAds] Disposing manager...");

    _disposed = true;

    _admobPrimary?.dispose();
    _admobSecondary?.dispose();

    _admobPrimary = null;
    _admobSecondary = null;
    _metaInterstitialReady = false;
    _unityInterstitialReady = false;
    _isShowingAd = false;
    _tapCount = 0;

    _admobPrimaryRetries = 0;
    _admobSecondaryRetries = 0;
    _metaInterstitialRetries = 0;
    _unityInterstitialRetries = 0;

    debugPrint("[SmartInterstitialAds] Manager disposed");
  }

  bool get hasAnyAdReady {
    return _admobPrimary != null ||
        _admobSecondary != null ||
        _metaInterstitialReady ||
        _unityInterstitialReady;
  }

  bool get hasPrimaryReady => _admobPrimary != null;

  bool get hasSecondaryReady => _admobSecondary != null;

  bool get hasFallbackReady => _metaInterstitialReady || _unityInterstitialReady;

  void resetTapCount() {
    _tapCount = 0;
    debugPrint("[SmartInterstitialAds] Tap count reset");
  }

  int get currentTapCount => _tapCount;

  bool get isDisposed => _disposed;

  AdNetwork? get nextAvailableNetwork {
    if (_admobPrimary != null) return AdNetwork.admobPrimary;
    if (_admobSecondary != null) return AdNetwork.admobSecondary;
    if (_metaInterstitialReady) return AdNetwork.meta;
    if (_unityInterstitialReady) return AdNetwork.unity;
    return null;
  }

  void reloadAll() {
    if (_disposed) return;

    debugPrint("[SmartInterstitialAds] Force reloading all ads...");

    _admobPrimaryRetries = 0;
    _admobSecondaryRetries = 0;
    _metaInterstitialRetries = 0;
    _unityInterstitialRetries = 0;

    if (_admobPrimary == null) _loadAdMobPrimary();
    if (_admobSecondary == null) _loadAdMobSecondary();
    if (!_metaInterstitialReady) _loadMetaInterstitial();
    if (!_unityInterstitialReady) _loadUnityInterstitial();
  }

  Map<String, bool> get adStatus => {
    'admobPrimary': _admobPrimary != null,
    'admobSecondary': _admobSecondary != null,
    'meta': _metaInterstitialReady,
    'unity': _unityInterstitialReady,
  };
}