import 'package:flutter/material.dart';
import '../../service/ads/native_ad_widget.dart';
import '../../service/subscription/nativ_ad_manager.dart';

class EmptyHomeContainer extends StatefulWidget {
  final String? subText;
  final String title;
  final SubscriptionAwareNativeAdManager? nativeAdManager;

  const EmptyHomeContainer({
    super.key,
    this.subText,
    required this.title,
    this.nativeAdManager,
  });

  @override
  State<EmptyHomeContainer> createState() => _EmptyHomeContainerState();
}

class _EmptyHomeContainerState extends State<EmptyHomeContainer> {
  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(
          widget.title,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.subText != null && widget.subText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.subText!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // Native ad below (if available)
        if (widget.nativeAdManager != null &&
            widget.nativeAdManager!.isReady) ...[
          const SizedBox(height: 10),
          NativeAdWidget(
            adManager: widget.nativeAdManager!,
            height: 200,
            width: 290,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ],
    );
  }
}
