import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'subscription_provider.dart';
import 'subscription_models.dart';

// ═══════════════════════════════════════════════════════════════════════
// AD CONTROLLER - Complete Ad Management with Subscription Awareness
// ═══════════════════════════════════════════════════════════════════════

/// Main controller to check if ads should be displayed
/// Usage: Check subscription status before showing any ads
class AdController extends ChangeNotifier {
  final SubscriptionProvider _subscriptionProvider;

  AdController(this._subscriptionProvider) {
    // Listen to subscription changes
    _subscriptionProvider.addListener(_onSubscriptionChanged);
  }

  // ─────────────────── GETTERS ───────────────────

  /// Whether ads should be shown (false if subscribed)
  bool get shouldShowAds => !_subscriptionProvider.isSubscribed;

  /// Whether user is subscribed
  bool get isSubscribed => _subscriptionProvider.isSubscribed;

  /// Whether subscription is loading
  bool get isLoading =>
      _subscriptionProvider.status == SubscriptionStatus.loading;

  /// Subscription status
  SubscriptionStatus get status => _subscriptionProvider.status;

  /// User subscription details
  UserSubscription get subscription => _subscriptionProvider.subscription;

  // ─────────────────── CALLBACKS ───────────────────

  void _onSubscriptionChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _subscriptionProvider.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  // ─────────────────── UTILITIES ───────────────────

  /// Log ad status for debugging
  void logAdStatus(String location) {
    debugPrint(
      '[AdController] Location: $location | '
          'ShowAds: $shouldShowAds | '
          'Subscribed: $isSubscribed | '
          'Status: $status',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// CONDITIONAL AD WIDGET - Shows ad only if not subscribed
// ═══════════════════════════════════════════════════════════════════════

class ConditionalAdWidget extends StatelessWidget {
  /// The ad widget to show when not subscribed
  final Widget adWidget;

  /// Widget to show when subscribed (defaults to empty space)
  final Widget? subscribedPlaceholder;

  /// Widget to show while loading subscription status
  final Widget? loadingPlaceholder;

  /// Optional padding around the ad
  final EdgeInsets? padding;

  /// Optional debug label
  final String? debugLabel;

  const ConditionalAdWidget({
    super.key,
    required this.adWidget,
    this.subscribedPlaceholder,
    this.loadingPlaceholder,
    this.padding,
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, _) {
        // Debug logging
        if (debugLabel != null) {
          debugPrint(
            '[ConditionalAdWidget] $debugLabel | '
                'Subscribed: ${provider.isSubscribed} | '
                'Status: ${provider.status}',
          );
        }

        // Show loading placeholder while checking subscription
        if (provider.status == SubscriptionStatus.loading) {
          return loadingPlaceholder ?? const SizedBox.shrink();
        }

        // Hide ad if subscribed
        if (provider.isSubscribed) {
          return subscribedPlaceholder ?? const SizedBox.shrink();
        }

        // Show ad
        Widget ad = adWidget;

        if (padding != null) {
          ad = Padding(padding: padding!, child: ad);
        }

        return ad;
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SUBSCRIPTION AWARE MIXIN - Easy integration in any StatefulWidget
// ═══════════════════════════════════════════════════════════════════════

mixin SubscriptionAwareMixin<T extends StatefulWidget> on State<T> {
  /// Whether ads should be shown
  bool get shouldShowAds {
    final provider = context.read<SubscriptionProvider>();
    return !provider.isSubscribed;
  }

  /// Whether user is subscribed
  bool get isSubscribed {
    final provider = context.read<SubscriptionProvider>();
    return provider.isSubscribed;
  }

  /// Get subscription status
  SubscriptionStatus get subscriptionStatus {
    final provider = context.read<SubscriptionProvider>();
    return provider.status;
  }

  /// Listen to subscription changes
  void listenToSubscription(VoidCallback callback) {
    final provider = context.read<SubscriptionProvider>();
    provider.addListener(callback);
  }

  /// Remove subscription listener
  void removeSubscriptionListener(VoidCallback callback) {
    final provider = context.read<SubscriptionProvider>();
    provider.removeListener(callback);
  }
}