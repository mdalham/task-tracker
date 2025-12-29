import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../subscription/nativ_ad_manager.dart';

/// Widget to display native ads with fallback chain
class NativeAdWidget extends StatefulWidget {
  final SubscriptionAwareNativeAdManager adManager;
  final double height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const NativeAdWidget({
    super.key,
    required this.adManager,
    this.height = 300,
    this.width,
    this.padding,
    this.borderRadius,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _currentAd;
  bool _isAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadAd();

    // Debug: Check ad status after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        debugPrint('[NativeAdWidget] Ad ready: $_isAdReady');
        debugPrint('[NativeAdWidget] Manager ready: ${widget.adManager.isReady}');
        debugPrint('[NativeAdWidget] Current source: ${widget.adManager.currentAdSource}');
      }
    });
  }

  void _loadAd() {
    // Small delay to ensure manager is fully initialized
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      final ad = widget.adManager.getNativeAd();

      if (ad != null) {
        setState(() {
          _currentAd = ad;
          _isAdReady = true;
        });
        debugPrint('[NativeAdWidget] ✅ Native ad loaded successfully');
      } else {
        debugPrint('[NativeAdWidget] ❌ No native ad available');
        debugPrint('[NativeAdWidget] Manager status: ${widget.adManager.adStatus}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If no ad is available, return empty shrink (no space taken)
    if (!_isAdReady || _currentAd == null) {
      return const SizedBox.shrink();
    }

    debugPrint('[NativeAdWidget] 📺 Displaying native ad');

    Widget adWidget = Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        child: AdWidget(ad: _currentAd!),
      ),
    );

    if (widget.padding != null) {
      return Padding(
        padding: widget.padding!,
        child: adWidget,
      );
    }

    return adWidget;
  }

  @override
  void dispose() {
    // Don't dispose the ad here - it's managed by the manager
    super.dispose();
  }
}