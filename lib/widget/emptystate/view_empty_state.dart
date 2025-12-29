import 'package:flutter/material.dart';
import '../../service/ads/native_ad_widget.dart';
import '../../service/subscription/nativ_ad_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import 'package:provider/provider.dart';

class ViewEmptyState extends StatefulWidget {
  final String title;

  const ViewEmptyState({super.key, required this.title});

  @override
  State<ViewEmptyState> createState() => _ViewEmptyStateState();
}

class _ViewEmptyStateState extends State<ViewEmptyState> {
  SubscriptionAwareNativeAdManager? _nativeAdManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNativeAds();
    });
  }

  void _initializeNativeAds() {
    if (!mounted) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();

    setState(() {
      _nativeAdManager = SubscriptionAwareNativeAdManager(
        subscriptionProvider: subscriptionProvider,
        nativePrimaryIdHigh: 'ca-app-pub-7237142331361857/3877570139',
        nativePrimaryIdMed: 'ca-app-pub-7237142331361857/2341127181',
        nativePrimaryIdLow: 'ca-app-pub-7237142331361857/3102887974',
        maxRetry: 5,
      );
      _isInitialized = true;
    });

    debugPrint('[HomeScreen] Native ad manager initialized');

    // Debug: Check status after initialization
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _nativeAdManager != null) {
        debugPrint('[HomeScreen] Native ad status after 3s:');
        debugPrint('[HomeScreen] Is ready: ${_nativeAdManager!.isReady}');
        debugPrint(
          '[HomeScreen] Current source: ${_nativeAdManager!.currentAdSource}',
        );
        debugPrint('[HomeScreen] Status: ${_nativeAdManager!.adStatus}');
      }
    });
  }

  @override
  void dispose() {
    _nativeAdManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),

          // Native ad below (if available)
          if (_nativeAdManager != null && _nativeAdManager!.isReady) ...[
            const SizedBox(height: 10),
            NativeAdWidget(
              adManager: _nativeAdManager!,
              height: 320,
              width: double.infinity,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ],
      ),
    );
  }
}
