import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart' hide BannerSize;

enum AdSource { admob, meta, unity }

class SmartBannerManager {
  final List<int> indices;
  final String admobId;
  final String metaId;
  final String unityPlacementId;
  final bool includeUnityInRotation;

  final Map<int, BannerAd> _admobBanners = {};
  final Map<int, ValueNotifier<bool>> _adReady = {};
  final Map<int, int> _adRetry = {};
  final Map<int, Timer> _retryTimers = {};
  final Map<int, Widget> _metaWidgets = {};

  AdSource? _currentSource;
  Timer? _switchTimer;
  final Random _random = Random();
  final int _maxRetries = 20;

  bool _metaReady = false;
  bool _unityReady = false;
  bool _disposed = false;

  Widget? _unityWidget;
  int _unityRetryCount = 0;
  final int _maxUnityRetries = 20;

  SmartBannerManager({
    required this.indices,
    required this.admobId,
    required this.metaId,
    required this.unityPlacementId,
    this.includeUnityInRotation = true,
  });

  void loadAllBanners() {
    if (_disposed) {
      debugPrint("[SmartBannerManager] ⚠️ Already disposed, cannot load");
      return;
    }

    debugPrint("═" * 50);
    debugPrint("[SmartBannerManager] 🚀 Loading all banners");
    debugPrint("═" * 50);
    debugPrint("[AdMob] Loading ${indices.length} banners");
    debugPrint("[Meta] Initializing");
    debugPrint("[Unity] Loading banner");
    debugPrint("═" * 50);

    for (var index in indices) {
      _loadAdMob(index);
    }
    _loadMeta();
    _loadUnityBanner();
  }

  ValueNotifier<bool> bannerReady(int index) {
    return _adReady[index] ??= ValueNotifier(false);
  }

  void _loadAdMob(int index) {
    if (_disposed) return;

    // ✅ Properly dispose existing ad
    final existingAd = _admobBanners[index];
    if (existingAd != null) {
      existingAd.dispose();
      _admobBanners.remove(index);
    }

    _adReady[index] ??= ValueNotifier(false);
    _adReady[index]!.value = false;
    _adRetry[index] ??= 0;

    final ad = BannerAd(
      adUnitId: admobId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }

          _admobBanners[index] = ad as BannerAd;
          _adRetry[index] = 0;
          debugPrint("[AdMob] ✅ Loaded index $index");

          // ✅ Set ready state AFTER successful load
          _adReady[index]?.value = true;
          _updateCurrentBanner();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _admobBanners.remove(index);
          _adReady[index]?.value = false;
          debugPrint("[AdMob] ❌ Failed index $index: ${error.message}");

          if (!_disposed) {
            _scheduleRetry(index);
          }
        },
        onAdOpened: (ad) {
          debugPrint("[AdMob] 📱 Opened index $index");
        },
        onAdClosed: (ad) {
          debugPrint("[AdMob] ❌ Closed index $index");
        },
      ),
    );

    ad.load();
  }

  void _scheduleRetry(int index) {
    if (_disposed) return;

    final attempt = _adRetry[index] ?? 0;

    if (attempt >= _maxRetries) {
      debugPrint("[AdMob] ⛔ Max retries reached for index $index");
      return;
    }

    // ✅ Exponential backoff with max 30 seconds
    final delay = Duration(seconds: min(pow(2, attempt).toInt() * 2, 30));

    _retryTimers[index]?.cancel();
    _retryTimers[index] = Timer(delay, () {
      if (!_disposed) {
        _adRetry[index] = attempt + 1;
        debugPrint("[AdMob] 🔄 Retry index $index, attempt ${attempt + 1}/$_maxRetries");
        _loadAdMob(index);
      }
    });
  }

  void _loadMeta() {
    if (_disposed) return;

    debugPrint("╔" + "═" * 48 + "╗");
    debugPrint("║ [Meta] 🔧 INITIALIZING META ADS              ║");
    debugPrint("╚" + "═" * 48 + "╝");
    debugPrint("[Meta] Meta ID: $metaId");
    debugPrint("[Meta] Creating ${indices.length} banner widgets");

    // Create widgets for each index
    for (var index in indices) {
      debugPrint("[Meta] 📱 Creating widget for index $index");

      _metaWidgets[index] = FacebookBannerAd(
        placementId: metaId,
        bannerSize: BannerSize.STANDARD,
        listener: (result, value) {
          if (_disposed) return;

          debugPrint("[Meta] 📡 Index $index: $result");

          switch (result) {
            case BannerAdResult.LOADED:
              debugPrint("[Meta] ✅ Loaded index $index");
              _metaReady = true;
              _adReady[index]?.value = true;
              _updateCurrentBanner();
              break;

            case BannerAdResult.ERROR:
              debugPrint("[Meta] ❌ Error index $index: $value");
              _metaReady = false;
              _adReady[index]?.value = false;
              break;

            case BannerAdResult.CLICKED:
              debugPrint("[Meta] 👆 Clicked index $index");
              break;

            case BannerAdResult.LOGGING_IMPRESSION:
              debugPrint("[Meta] 👁️ Impression logged index $index");
              break;
          }
        },
      );

      debugPrint("[Meta] ✅ Widget created for index $index");
    }

    debugPrint("[Meta] ✅ All ${_metaWidgets.length} widgets created");
    _updateCurrentBanner();
  }

  void _loadUnityBanner() {
    if (_disposed || !includeUnityInRotation) return;

    debugPrint("[Unity] 📱 Loading banner...");
    debugPrint("[Unity] Placement: $unityPlacementId");
    debugPrint("[Unity] Retry count: $_unityRetryCount/$_maxUnityRetries");

    try {
      UnityAds.load(
        placementId: unityPlacementId,
        onComplete: (placementId) {
          if (_disposed) return;

          _unityReady = true;
          _unityRetryCount = 0;

          // ✅ Create Unity widget once
          _unityWidget = UnityBannerAd(
            placementId: unityPlacementId,
            onLoad: (id) => debugPrint("[Unity Widget] ✅ Loaded: $id"),
            onClick: (id) => debugPrint("[Unity Widget] 👆 Clicked: $id"),
            onShown: (id) => debugPrint("[Unity Widget] 👁️ Shown: $id"),
            onFailed: (id, error, msg) {
              debugPrint("[Unity Widget] ❌ Failed: $error - $msg");
              _unityReady = false;
              _unityWidget = null;
            },
          );

          debugPrint("[Unity] ✅ Banner loaded successfully");
          _updateCurrentBanner();
        },
        onFailed: (placementId, error, message) {
          if (_disposed) return;

          _unityReady = false;
          _unityWidget = null;

          debugPrint("[Unity] ❌ Load failed");
          debugPrint("[Unity] Error: $error");
          debugPrint("[Unity] Message: $message");

          // ✅ Limited retry with backoff
          if (_unityRetryCount < _maxUnityRetries) {
            _unityRetryCount++;
            final delay = Duration(seconds: 5 * _unityRetryCount);
            debugPrint("[Unity] 🔄 Retrying in ${delay.inSeconds}s...");

            Timer(delay, () {
              if (!_disposed) {
                _loadUnityBanner();
              }
            });
          } else {
            debugPrint("[Unity] ⛔ Max retries reached, giving up");
          }
        },
      );
    } catch (e) {
      debugPrint("[Unity] ⚠️ Exception: $e");
      _unityReady = false;
      _unityWidget = null;
    }
  }

  List<AdSource> _getAvailableSources() {
    List<AdSource> sources = [];

    if (_admobBanners.isNotEmpty) sources.add(AdSource.admob);
    if (_metaReady && _metaWidgets.isNotEmpty) sources.add(AdSource.meta);
    if (_unityReady && _unityWidget != null && includeUnityInRotation) {
      sources.add(AdSource.unity);
    }

    return sources;
  }

  void _updateCurrentBanner() {
    if (_disposed) return;

    final available = _getAvailableSources();

    debugPrint("[_updateCurrentBanner] Available: $available");
    debugPrint("[_updateCurrentBanner] Current: $_currentSource");

    if (available.isEmpty) {
      debugPrint("[SmartBannerManager] ⚠️ No ads ready");
      _currentSource = null;
      return;
    }

    if (_currentSource == null) {
      _currentSource = available.first;
      debugPrint("[SmartBannerManager] 📺 Initial: $_currentSource");
      _updateReadyStates();
      _scheduleSwitch();
      return;
    }

    if (available.contains(_currentSource)) {
      debugPrint("[SmartBannerManager] ✓ Current source still available");
      _updateReadyStates();
      return;
    }

    _currentSource = available.first;
    debugPrint("[SmartBannerManager] 📺 Updated: $_currentSource");
    _updateReadyStates();
    _scheduleSwitch();
  }

  void _updateReadyStates() {
    if (_disposed) return;

    debugPrint("[_updateReadyStates] Source: $_currentSource");

    for (var index in indices) {
      bool ready = false;

      switch (_currentSource) {
        case AdSource.admob:
          ready = _admobBanners.containsKey(index);
          break;
        case AdSource.meta:
          ready = _metaReady && _metaWidgets.containsKey(index);
          break;
        case AdSource.unity:
          ready = _unityReady && _unityWidget != null;
          break;
        default:
          ready = false;
      }

      debugPrint("[_updateReadyStates] Index $index ready: $ready");
      _adReady[index]?.value = ready;
    }
  }

  void _scheduleSwitch() {
    if (_disposed) return;

    _switchTimer?.cancel();

    final available = _getAvailableSources();
    if (available.length <= 1) {
      debugPrint("[SmartBannerManager] ⚠️ Only ${available.length} source(s), no switching");
      return;
    }

    int delay = 16 + _random.nextInt(20);
    _switchTimer = Timer(Duration(seconds: delay), () {
      if (!_disposed) {
        _switchAd();
      }
    });
    debugPrint("[SmartBannerManager] ⏱️ Next switch in $delay seconds");
  }

  void _switchAd() {
    if (_disposed) return;

    final available = _getAvailableSources();

    debugPrint("[_switchAd] Current: $_currentSource");
    debugPrint("[_switchAd] Available: $available");

    if (available.length <= 1) {
      debugPrint("[SmartBannerManager] ⚠️ Only ${available.length} source(s)");
      return;
    }

    final currentIndex = available.indexOf(_currentSource!);
    final nextIndex = (currentIndex + 1) % available.length;
    final next = available[nextIndex];

    _currentSource = next;
    debugPrint("[SmartBannerManager] 🔄 Switched to: $next");

    _updateReadyStates();
    _scheduleSwitch();
  }

  Widget _adMobWidget(BannerAd ad) {
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }

  Widget _metaWidget(int index) {
    final widget = _metaWidgets[index];

    if (widget == null) {
      debugPrint("[_metaWidget] ❌ Widget NULL for index $index");
      return const SizedBox.shrink();
    }

    debugPrint("[_metaWidget] ✅ Returning Meta widget $index");
    return widget;
  }

  Widget getBannerWidget(int index) {
    if (_disposed) return const SizedBox.shrink();

    final isReady = _adReady[index]?.value ?? false;

    debugPrint("[getBannerWidget] Index: $index, Source: $_currentSource, Ready: $isReady");

    if (!isReady) {
      return const SizedBox.shrink();
    }

    switch (_currentSource) {
      case AdSource.admob:
        final ad = _admobBanners[index];
        if (ad == null) {
          debugPrint("[getBannerWidget] ❌ AdMob NULL for $index");
          return const SizedBox.shrink();
        }
        debugPrint("[Banner] 📺 Showing AdMob $index");
        return Center(child: _adMobWidget(ad));

      case AdSource.meta:
        debugPrint("[Banner] 📺 Showing Meta $index");
        return Center(child: _metaWidget(index));

      case AdSource.unity:
        if (_unityWidget == null) {
          debugPrint("[getBannerWidget] ❌ Unity widget NULL");
          return const SizedBox.shrink();
        }
        debugPrint("[Banner] 📺 Showing Unity $index");
        return Center(child: _unityWidget!);

      default:
        debugPrint("[getBannerWidget] ❌ No source selected");
        return const SizedBox.shrink();
    }
  }

  // ✅ Public API methods
  void forceSwitch(AdSource source) {
    if (_disposed) return;

    debugPrint("[forceSwitch] Forcing switch to: $source");
    final available = _getAvailableSources();

    if (!available.contains(source)) {
      debugPrint("[forceSwitch] ❌ Source $source not available");
      return;
    }

    _currentSource = source;
    debugPrint("[forceSwitch] ✅ Switched to: $source");
    _updateReadyStates();
    _scheduleSwitch();
  }

  AdSource? getCurrentSource() => _currentSource;
  List<AdSource> getAvailableSources() => _getAvailableSources();
  bool get isDisposed => _disposed;

  // ✅ Proper cleanup
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    debugPrint("[SmartBannerManager] 🧹 Disposing...");

    // Cancel all timers
    _switchTimer?.cancel();
    _switchTimer = null;

    for (var timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();

    // Dispose AdMob banners
    for (var ad in _admobBanners.values) {
      ad.dispose();
    }
    _admobBanners.clear();

    // Dispose ValueNotifiers
    for (var notifier in _adReady.values) {
      notifier.dispose();
    }
    _adReady.clear();

    // Clear other collections
    _adRetry.clear();
    _metaWidgets.clear();
    _unityWidget = null;

    debugPrint("[SmartBannerManager] ✅ Disposed successfully");
  }
}