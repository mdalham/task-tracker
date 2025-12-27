import 'package:flutter/material.dart';

class AnimationWidget extends StatefulWidget {
  final Widget child;
  final double start; // 0.0 to 1.0
  final double end;   // 0.0 to 1.0
  final Duration duration;
  final Offset beginOffset;

  const AnimationWidget({
    super.key,
    required this.child,
    this.start = 0.0,
    this.end = 0.4,
    this.duration = const Duration(milliseconds: 1000),
    this.beginOffset = const Offset(0, 0.2),
  });

  @override
  State<AnimationWidget> createState() => _AnimationWidgetState();
}

class _AnimationWidgetState extends State<AnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(widget.start, widget.end, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(widget.start, widget.end, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}
