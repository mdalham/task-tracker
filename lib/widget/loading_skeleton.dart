import 'package:flutter/material.dart';
import '../helper class/size_helper_class.dart';
import 'custom_container.dart';

class LoadingSkeleton extends StatefulWidget {
  final int loadingSkeletonItemCount;
  const LoadingSkeleton({super.key, required this.loadingSkeletonItemCount});

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _gradientController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();

    // ✅ Pulse animation (opacity)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ✅ Gradient animation (shimmer wave)
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _gradientAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  static double _scale(BuildContext context) {
    final width = MediaQuery.of(context).size.shortestSide;
    if (width < 360) return 0.85;
    if (width < 400) return 1.0;
    if (width < 600) return 1.1;
    return 1.4;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final lIconContainerWidth = SizeHelperClass.listIconContainerWidth(context);
    final lIconContainerHeight = SizeHelperClass.listIconContainerHeight(context);

    final scale = _scale(context);
    double listIconContainerHeight = (lIconContainerHeight * scale).clamp(45, 112);
    double listIconContainerWidth = (lIconContainerWidth * scale).clamp(18, 330);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _gradientAnimation]),
      builder: (context, child) {
        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: widget.loadingSkeletonItemCount,
          itemBuilder: (_, i) => Opacity(
            opacity: _pulseAnimation.value, // ✅ Pulse opacity
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CustomContainer(
                color: cs.primaryContainer,
                outlineColor: Colors.transparent,
                circularRadius: 16,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      // ✅ Animated gradient container (left icon)
                      AnimatedGradientBox(
                        height: listIconContainerHeight,
                        width: listIconContainerWidth,
                        isDark: isDark,
                        gradientPosition: _gradientAnimation.value,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ Animated gradient container (title)
                            AnimatedGradientBox(
                              height: 20,
                              width: MediaQuery.of(context).size.width * 0.65,
                              isDark: isDark,
                              gradientPosition: _gradientAnimation.value,
                              borderRadius: 4,
                            ),
                            const SizedBox(height: 5),
                            // ✅ Animated gradient container (subtitle)
                            AnimatedGradientBox(
                              height: 13,
                              width: MediaQuery.of(context).size.width * 0.51,
                              isDark: isDark,
                              gradientPosition: _gradientAnimation.value,
                              borderRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ✨ Animated Gradient Box Widget
class AnimatedGradientBox extends StatelessWidget {
  final double height;
  final double width;
  final bool isDark;
  final double gradientPosition;
  final double borderRadius;

  const AnimatedGradientBox({
    super.key,
    required this.height,
    required this.width,
    required this.isDark,
    required this.gradientPosition,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Adaptive colors for light/dark mode
    final baseColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.shade300.withOpacity(0.5);

    final midColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.grey.shade200.withOpacity(0.7);

    final highlightColor = isDark
        ? Colors.white.withOpacity(0.20)
        : Colors.white.withOpacity(0.9);

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            baseColor,
            midColor,
            highlightColor,
            midColor,
            baseColor,
          ],
          stops: [
            (gradientPosition - 1.5).clamp(0.0, 1.0),
            (gradientPosition - 0.5).clamp(0.0, 1.0),
            gradientPosition.clamp(0.0, 1.0),
            (gradientPosition + 0.5).clamp(0.0, 1.0),
            (gradientPosition + 1.5).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}