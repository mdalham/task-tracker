import 'package:flutter/material.dart';
import '../ads/banner/banner_ads.dart';
import 'subscription_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// SUBSCRIPTION-AWARE BANNER MANAGER
// Wraps your SmartBannerManager with subscription checking
// ═══════════════════════════════════════════════════════════════════════

class SubscriptionAwareBannerManager {
  final SubscriptionProvider _subscriptionProvider;
  SmartBannerManager? _bannerManager;

  final List<int> indices;
  final String admobId;
  final String metaId;
  final String unityPlacementId;
  final bool includeUnityInRotation;

  bool _isDisposed = false;

  SubscriptionAwareBannerManager({
    required SubscriptionProvider subscriptionProvider,
    required this.indices,
    required this.admobId,
    required this.metaId,
    required this.unityPlacementId,
    this.includeUnityInRotation = true,
  }) : _subscriptionProvider = subscriptionProvider {
    _initialize();

    // Listen to subscription changes
    _subscriptionProvider.addListener(_onSubscriptionChanged);
  }

  // ─────────────────── INITIALIZATION ───────────────────

  void _initialize() {
    if (_subscriptionProvider.isSubscribed) {
      debugPrint('[SubscriptionBanner] ✨ User subscribed - banners disabled');
      _bannerManager = null;
      return;
    }

    debugPrint('[SubscriptionBanner] 📢 User not subscribed - initializing banners');
    debugPrint('[SubscriptionBanner] Indices: $indices');

    _bannerManager = SmartBannerManager(
      indices: indices,
      admobId: admobId,
      metaId: metaId,
      unityPlacementId: unityPlacementId,
      includeUnityInRotation: includeUnityInRotation,
    );

    _bannerManager?.loadAllBanners();
  }

  // ─────────────────── SUBSCRIPTION CHANGE HANDLER ───────────────────

  void _onSubscriptionChanged() {
    if (_isDisposed) return;

    if (_subscriptionProvider.isSubscribed && _bannerManager != null) {
      // User just subscribed - dispose banners immediately
      debugPrint('[SubscriptionBanner] ✨ User subscribed - disposing banners');
      _bannerManager?.dispose();
      _bannerManager = null;
    } else if (!_subscriptionProvider.isSubscribed && _bannerManager == null) {
      // User subscription expired - reinitialize banners
      debugPrint('[SubscriptionBanner] 📢 Subscription expired - reinitializing banners');
      _initialize();
    }
  }

  // ─────────────────── PUBLIC API ───────────────────

  /// Get banner ready notifier for an index
  ValueNotifier<bool> bannerReady(int index) {
    if (_subscriptionProvider.isSubscribed) {
      // Return a notifier that always says false
      return ValueNotifier<bool>(false);
    }

    if (_bannerManager == null) {
      return ValueNotifier<bool>(false);
    }

    return _bannerManager!.bannerReady(index);
  }

  /// Get banner widget for an index
  Widget getBannerWidget(int index) {
    if (_subscriptionProvider.isSubscribed) {
      debugPrint('[SubscriptionBanner] ✨ User subscribed - returning empty widget');
      return const SizedBox.shrink();
    }

    if (_bannerManager == null) {
      debugPrint('[SubscriptionBanner] ⚠️ Banner manager not initialized');
      return const SizedBox.shrink();
    }

    return _bannerManager!.getBannerWidget(index);
  }

  /// Force switch to specific ad source
  void forceSwitch(AdSource source) {
    if (_subscriptionProvider.isSubscribed) {
      debugPrint('[SubscriptionBanner] ✨ User subscribed - no switching needed');
      return;
    }

    _bannerManager?.forceSwitch(source);
  }

  /// Get current ad source
  AdSource? getCurrentSource() {
    if (_subscriptionProvider.isSubscribed) return null;
    return _bannerManager?.getCurrentSource();
  }

  /// Get available ad sources
  List<AdSource> getAvailableSources() {
    if (_subscriptionProvider.isSubscribed) return [];
    return _bannerManager?.getAvailableSources() ?? [];
  }

  /// Check if disposed
  bool get isDisposed => _isDisposed || (_bannerManager?.isDisposed ?? false);

  /// Check if ads are enabled
  bool get adsEnabled => !_subscriptionProvider.isSubscribed;

  /// Check if user is subscribed
  bool get isSubscribed => _subscriptionProvider.isSubscribed;

  // ─────────────────── DISPOSE ───────────────────

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _subscriptionProvider.removeListener(_onSubscriptionChanged);
    _bannerManager?.dispose();
    _bannerManager = null;

    debugPrint('[SubscriptionBanner] Disposed');
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SUBSCRIPTION-AWARE BANNER WIDGET
// Drop-in replacement for your banner ad widgets
// ═══════════════════════════════════════════════════════════════════════

class SubscriptionAwareBannerWidget extends StatelessWidget {
  final int index;
  final SubscriptionAwareBannerManager bannerManager;
  final double? height;
  final EdgeInsets? padding;

  const SubscriptionAwareBannerWidget({
    super.key,
    required this.index,
    required this.bannerManager,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show anything if subscribed
    if (bannerManager.isSubscribed) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: bannerManager.bannerReady(index),
      builder: (context, isReady, child) {
        if (!isReady) {
          return const SizedBox.shrink();
        }

        Widget banner = bannerManager.getBannerWidget(index);

        if (height != null) {
          banner = SizedBox(height: height, child: banner);
        }

        if (padding != null) {
          banner = Padding(padding: padding!, child: banner);
        }

        return banner;
      },
    );
  }
}