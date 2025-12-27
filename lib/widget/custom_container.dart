import 'package:flutter/material.dart';

class CustomContainer extends StatefulWidget {
  final double? height;
  final double? width;
  final double circularRadius;
  final Color color;
  final Color outlineColor;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;


  const CustomContainer({
    super.key,
    this.height,
    this.width,
    required this.color,
    required this.outlineColor,
    required this.child, this.padding, this.margin, required this.circularRadius,
  });

  @override
  State<CustomContainer> createState() => _CustomContainerState();
}

class _CustomContainerState extends State<CustomContainer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.circularRadius),
        border: Border.all(color: widget.outlineColor, width: 1.5),
      ),
      child: widget.child,
    );
  }
}
