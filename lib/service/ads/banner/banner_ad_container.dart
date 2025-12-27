import 'package:flutter/material.dart';
import '../../subscription/subscription_aware_banner_manager.dart';
import 'banner_ad_widget_wrapper.dart';

class BannerAdContainerWidget extends StatefulWidget {
  final int index;
  final SubscriptionAwareBannerManager bannerManager;

  const BannerAdContainerWidget({
    super.key,
    required this.index,
    required this.bannerManager,
  });

  @override
  State<BannerAdContainerWidget> createState() => _BannerAdContainerWidgetState();
}

class _BannerAdContainerWidgetState extends State<BannerAdContainerWidget> {

  bool _isRendered = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Center(
        child: BannerAdWidgetWrapper(
          index: widget.index,
          bannerManager: widget.bannerManager,
          onError: () {
            debugPrint('[BannerAdContainer] Ad at index ${widget.index} failed');
            if (mounted) {
              setState(() {
                _isRendered = false;
              });
            }
          },
          onSuccess: () {
            debugPrint('[BannerAdContainer] Ad at index ${widget.index} rendered');
            if (mounted) {
              setState(() {
                _isRendered = true;
              });
            }
          },
        ),
      ),
    );
  }
}