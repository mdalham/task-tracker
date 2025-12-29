import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:facebook_audience_network/facebook_audience_network.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart' hide BannerSize;

import '../../subscription/subscription_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// TODO LIST BANNER MANAGER
// Dedicated banner manager for TodoList with subscription awareness
// ═══════════════════════════════════════════════════════════════════════

enum TodoAdSource { admob, meta, unity }

class TodoListBannerManager {
  final SubscriptionProvider subscriptionProvider;
  final List<int> indices;
  final String admobId;
  final String metaId;
  final String unityPlacementId;

  final Map<int, BannerAd> _admobBanners = {};
  final Map<int, ValueNotifier<bool>> _adReady = {};
  final Map<int, int> _adRetry = {};
  final Map<int, Timer> _retryTimers = {};
  final Map<int, Widget> _metaWidgets = {};

  TodoAdSource? _currentSource;
  Timer? _switchTimer;
  final Random _random = Random();
  final int _maxRetries = 20;

  bool _metaReady = false;
  bool _unityReady = false;
  bool _disposed = false;
  bool _initialized = false;

  Widget? _unityWidget;
  int _unityRetryCount = 0;
  final int _maxUnityRetries = 20;

  TodoListBannerManager({
    required this.subscriptionProvider,
    required this.indices,
    required this.admobId,
    required this.metaId,
    required this.unityPlacementId,
  }) {
    _initialize();
    subscriptionProvider.addListener(_onSubscriptionChanged);
  }

  // ─────────────────── INITIALIZATION ───────────────────

  void _initialize() {
    if (subscriptionProvider.isSubscribed) {
      debugPrint("[TodoBanner] ✨ User subscribed - skipping initialization");
      _disposed = true;
      return;
    }

    debugPrint("═" * 50);
    debugPrint("[TodoBanner] 🚀 Initializing TodoList banners");
    debugPrint("[TodoBanner] Indices: $indices");
    debugPrint("[TodoBanner] Ad Unit: $admobId");
    debugPrint("═" * 50);

    _loadAllBanners();
    _initialized = true;
  }

  void _loadAllBanners() {
    if (_disposed) return;

    debugPrint("[TodoBanner] Loading ${indices.length} banner positions");

    for (var index in indices) {
      _loadAdMob(index);
    }
    _loadMeta();
    _loadUnityBanner();

    // ✅ Set initial source immediately
    _updateCurrentBanner();

    debugPrint("[TodoBanner] ✅ Initial source: $_currentSource");
  }

  // ─────────────────── SUBSCRIPTION HANDLER ───────────────────

  void _onSubscriptionChanged() {
    if (subscriptionProvider.isSubscribed && !_disposed) {
      debugPrint("[TodoBanner] ✨ User subscribed - disposing all ads");
      dispose();
    }
  }

  // ─────────────────── ADMOB LOADING ───────────────────

  void _loadAdMob(int index) {
    if (_disposed) return;

    final existingAd = _admobBanners[index];
    if (existingAd != null) {
      existingAd.dispose();
      _admobBanners.remove(index);
    }

    _adReady[index] ??= ValueNotifier(false);
    _adReady[index]!.value = false;
    _adRetry[index] ??= 0;

    debugPrint("[TodoBanner AdMob] Loading index $index");

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
          _adReady[index]?.value = true;

          debugPrint("[TodoBanner AdMob] ✅ Loaded index $index");
          debugPrint("[TodoBanner AdMob] Total loaded: ${_admobBanners.length}");

          _updateCurrentBanner();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _admobBanners.remove(index);
          _adReady[index]?.value = false;

          debugPrint("[TodoBanner AdMob] ❌ Failed index $index: ${error.message}");
          debugPrint("[TodoBanner AdMob] Error code: ${error.code}");

          if (!_disposed) {
            _scheduleRetry(index);
          }
        },
      ),
    );

    ad.load();
  }

  void _scheduleRetry(int index) {
    if (_disposed) return;

    final attempt = _adRetry[index] ?? 0;

    if (attempt >= _maxRetries) {
      debugPrint("[TodoBanner AdMob] ⛔ Max retries for index $index");
      return;
    }

    final delay = Duration(seconds: min(pow(2, attempt).toInt() * 2, 30));

    _retryTimers[index]?.cancel();
    _retryTimers[index] = Timer(delay, () {
      if (!_disposed) {
        _adRetry[index] = attempt + 1;
        debugPrint("[TodoBanner AdMob] 🔄 Retry $index, attempt ${attempt + 1}");
        _loadAdMob(index);
      }
    });
  }

  // ─────────────────── META LOADING ───────────────────

  void _loadMeta() {
    if (_disposed) return;

    debugPrint("[TodoBanner Meta] Creating ${indices.length} widgets");

    for (var index in indices) {
      _metaWidgets[index] = FacebookBannerAd(
        placementId: metaId,
        bannerSize: BannerSize.STANDARD,
        listener: (result, value) {
          if (_disposed) return;

          debugPrint("[TodoBanner Meta] Index $index: $result");

          switch (result) {
            case BannerAdResult.LOADED:
              debugPrint("[TodoBanner Meta] ✅ Loaded index $index");
              _metaReady = true;
              _adReady[index]?.value = true;
              _updateCurrentBanner();
              break;

            case BannerAdResult.ERROR:
              debugPrint("[TodoBanner Meta] ❌ Error index $index: $value");
              _metaReady = false;
              _adReady[index]?.value = false;
              break;

            case BannerAdResult.CLICKED:
              debugPrint("[TodoBanner Meta] 👆 Clicked index $index");
              break;

            case BannerAdResult.LOGGING_IMPRESSION:
              debugPrint("[TodoBanner Meta] 👁️ Impression index $index");
              break;
          }
        },
      );
    }

    debugPrint("[TodoBanner Meta] ✅ Created ${_metaWidgets.length} widgets");
  }

  // ─────────────────── UNITY LOADING ───────────────────

  void _loadUnityBanner() {
    if (_disposed) return;

    debugPrint("[TodoBanner Unity] Loading banner");

    try {
      UnityAds.load(
        placementId: unityPlacementId,
        onComplete: (placementId) {
          if (_disposed) return;

          _unityReady = true;
          _unityRetryCount = 0;

          _unityWidget = UnityBannerAd(
            placementId: unityPlacementId,
            onLoad: (id) => debugPrint("[TodoBanner Unity] ✅ Loaded: $id"),
            onClick: (id) => debugPrint("[TodoBanner Unity] 👆 Clicked: $id"),
            onShown: (id) => debugPrint("[TodoBanner Unity] 👁️ Shown: $id"),
            onFailed: (id, error, msg) {
              debugPrint("[TodoBanner Unity] ❌ Failed: $error - $msg");
              _unityReady = false;
              _unityWidget = null;
            },
          );

          debugPrint("[TodoBanner Unity] ✅ Banner loaded");
          _updateCurrentBanner();
        },
        onFailed: (placementId, error, message) {
          if (_disposed) return;

          _unityReady = false;
          _unityWidget = null;

          debugPrint("[TodoBanner Unity] ❌ Load failed: $error");

          if (_unityRetryCount < _maxUnityRetries) {
            _unityRetryCount++;
            final delay = Duration(seconds: 5 * _unityRetryCount);
            debugPrint("[TodoBanner Unity] 🔄 Retry in ${delay.inSeconds}s");

            Timer(delay, () {
              if (!_disposed) _loadUnityBanner();
            });
          }
        },
      );
    } catch (e) {
      debugPrint("[TodoBanner Unity] ⚠️ Exception: $e");
      _unityReady = false;
      _unityWidget = null;
    }
  }

  // ─────────────────── SOURCE MANAGEMENT ───────────────────

  List<TodoAdSource> _getAvailableSources() {
    List<TodoAdSource> sources = [];

    if (_admobBanners.isNotEmpty) sources.add(TodoAdSource.admob);
    if (_metaReady && _metaWidgets.isNotEmpty) sources.add(TodoAdSource.meta);
    if (_unityReady && _unityWidget != null) sources.add(TodoAdSource.unity);

    return sources;
  }

  void _updateCurrentBanner() {
    if (_disposed) return;

    final available = _getAvailableSources();

    debugPrint("[TodoBanner] ═════════════════════════");
    debugPrint("[TodoBanner] Available sources: $available");
    debugPrint("[TodoBanner] Current source: $_currentSource");
    debugPrint("[TodoBanner] AdMob count: ${_admobBanners.length}");
    debugPrint("[TodoBanner] Meta ready: $_metaReady");
    debugPrint("[TodoBanner] Unity ready: $_unityReady");

    // ✅ Even if no ads fully ready, set a source if anything is loading
    if (available.isEmpty) {
      if (_admobBanners.isNotEmpty) {
        _currentSource = TodoAdSource.admob;
        debugPrint("[TodoBanner] ✅ Set to AdMob (loading)");
      } else if (_metaWidgets.isNotEmpty) {
        _currentSource = TodoAdSource.meta;
        debugPrint("[TodoBanner] ✅ Set to Meta (loading)");
      } else {
        _currentSource = null;
        debugPrint("[TodoBanner] ⚠️ No sources available");
      }
      debugPrint("[TodoBanner] ═════════════════════════");
      return;
    }

    if (_currentSource == null) {
      _currentSource = available.first;
      debugPrint("[TodoBanner] 📺 Initial source: $_currentSource");
      _updateReadyStates();
      _scheduleSwitch();
      debugPrint("[TodoBanner] ═════════════════════════");
      return;
    }

    if (available.contains(_currentSource)) {
      debugPrint("[TodoBanner] ✓ Current source still valid");
      _updateReadyStates();
    } else {
      _currentSource = available.first;
      debugPrint("[TodoBanner] 📺 Updated source: $_currentSource");
      _updateReadyStates();
      _scheduleSwitch();
    }

    debugPrint("[TodoBanner] ═════════════════════════");
  }

  void _updateReadyStates() {
    if (_disposed) return;

    for (var index in indices) {
      bool ready = false;

      switch (_currentSource) {
        case TodoAdSource.admob:
          ready = _admobBanners.containsKey(index);
          break;
        case TodoAdSource.meta:
          ready = _metaReady && _metaWidgets.containsKey(index);
          break;
        case TodoAdSource.unity:
          ready = _unityReady && _unityWidget != null;
          break;
        default:
          ready = false;
      }

      _adReady[index]?.value = ready;
    }
  }

  void _scheduleSwitch() {
    if (_disposed) return;

    _switchTimer?.cancel();

    final available = _getAvailableSources();
    if (available.length <= 1) return;

    int delay = 16 + _random.nextInt(20);
    _switchTimer = Timer(Duration(seconds: delay), () {
      if (!_disposed) _switchAd();
    });
  }

  void _switchAd() {
    if (_disposed) return;

    final available = _getAvailableSources();
    if (available.length <= 1) return;

    final currentIndex = available.indexOf(_currentSource!);
    final nextIndex = (currentIndex + 1) % available.length;
    _currentSource = available[nextIndex];

    debugPrint("[TodoBanner] 🔄 Switched to: $_currentSource");
    _updateReadyStates();
    _scheduleSwitch();
  }

  // ─────────────────── PUBLIC API ───────────────────

  ValueNotifier<bool> bannerReady(int index) {
    if (subscriptionProvider.isSubscribed || _disposed) {
      return ValueNotifier<bool>(false);
    }

    _adReady[index] ??= ValueNotifier(false);
    return _adReady[index]!;
  }

  Widget getBannerWidget(int index) {
    debugPrint("═" * 50);
    debugPrint("[TodoBanner] getBannerWidget($index)");
    debugPrint("[TodoBanner] Subscribed: ${subscriptionProvider.isSubscribed}");
    debugPrint("[TodoBanner] Disposed: $_disposed");
    debugPrint("[TodoBanner] Current source: $_currentSource");
    debugPrint("[TodoBanner] Ready: ${_adReady[index]?.value}");

    if (subscriptionProvider.isSubscribed || _disposed) {
      debugPrint("[TodoBanner] ✨ User subscribed or disposed");
      debugPrint("═" * 50);
      return const SizedBox.shrink();
    }

    if (_currentSource == null) {
      debugPrint("[TodoBanner] ⚠️ No source selected, trying to update...");
      _updateCurrentBanner();

      if (_currentSource == null) {
        debugPrint("[TodoBanner] ❌ Still no source available");
        debugPrint("═" * 50);
        return const SizedBox.shrink();
      }
    }

    final isReady = _adReady[index]?.value ?? false;
    if (!isReady) {
      debugPrint("[TodoBanner] ⏳ Not ready yet");
      debugPrint("═" * 50);
      return const SizedBox.shrink();
    }

    Widget widget;

    switch (_currentSource) {
      case TodoAdSource.admob:
        final ad = _admobBanners[index];
        if (ad == null) {
          debugPrint("[TodoBanner] ❌ AdMob ad null for $index");
          debugPrint("═" * 50);
          return const SizedBox.shrink();
        }
        debugPrint("[TodoBanner] 📺 Showing AdMob $index");
        widget = SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        );
        break;

      case TodoAdSource.meta:
        final metaWidget = _metaWidgets[index];
        if (metaWidget == null) {
          debugPrint("[TodoBanner] ❌ Meta widget null for $index");
          debugPrint("═" * 50);
          return const SizedBox.shrink();
        }
        debugPrint("[TodoBanner] 📺 Showing Meta $index");
        widget = metaWidget;
        break;

      case TodoAdSource.unity:
        if (_unityWidget == null) {
          debugPrint("[TodoBanner] ❌ Unity widget null");
          debugPrint("═" * 50);
          return const SizedBox.shrink();
        }
        debugPrint("[TodoBanner] 📺 Showing Unity $index");
        widget = _unityWidget!;
        break;

      default:
        debugPrint("[TodoBanner] ❌ Unknown source");
        debugPrint("═" * 50);
        return const SizedBox.shrink();
    }

    debugPrint("═" * 50);
    return Center(child: widget);
  }

  List<String> getAvailableSources() {
    if (subscriptionProvider.isSubscribed || _disposed) return [];
    return _getAvailableSources()
        .map((s) => s.toString().split('.').last)
        .toList();
  }

  TodoAdSource? getCurrentSource() => _currentSource;
  bool get isDisposed => _disposed;
  bool get isInitialized => _initialized;

  // ─────────────────── DISPOSE ───────────────────

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    debugPrint("[TodoBanner] 🧹 Disposing...");

    subscriptionProvider.removeListener(_onSubscriptionChanged);

    _switchTimer?.cancel();
    _switchTimer = null;

    for (var timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();

    for (var ad in _admobBanners.values) {
      ad.dispose();
    }
    _admobBanners.clear();

    for (var notifier in _adReady.values) {
      notifier.dispose();
    }
    _adReady.clear();

    _adRetry.clear();
    _metaWidgets.clear();
    _unityWidget = null;

    debugPrint("[TodoBanner] ✅ Disposed");
  }
}