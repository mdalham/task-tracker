import 'package:flutter/material.dart';
import '../../subscription/subscription_aware_banner_manager.dart';

class BannerAdWidgetWrapper extends StatefulWidget {
  final int index;
  final SubscriptionAwareBannerManager bannerManager;
  final VoidCallback onError;
  final VoidCallback onSuccess;

  const BannerAdWidgetWrapper({
    super.key,
    required this.index,
    required this.bannerManager,
    required this.onError,
    required this.onSuccess,
  });

  @override
  State<BannerAdWidgetWrapper> createState() => _AdWidgetWrapperState();
}

class _AdWidgetWrapperState extends State<BannerAdWidgetWrapper> {
  bool _hasError = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // ✅ Delay rendering slightly to ensure ad is fully ready
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !_hasError) {
        setState(() => _isLoaded = true);
        widget.onSuccess();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded) {
      // ✅ Show subtle loading indicator
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    try {
      return widget.bannerManager.getBannerWidget(widget.index);
    } catch (e) {
      debugPrint('[_AdWidgetWrapper] Error rendering ad: $e');
      _hasError = true;
      widget.onError();
      return const SizedBox.shrink();
    }
  }
}
