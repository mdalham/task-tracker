import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../helper class/size_helper_class.dart';

enum SnackBarType { success, warning, error }

class CustomSnackBar {
  static void show(
      BuildContext context, {
        required String message,
        SnackBarType type = SnackBarType.error,
        Duration duration = const Duration(seconds: 3),
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    // Define colors and SVG icons for each type
    String iconPath;
    Color bgColor;
    Color iconColor = Colors.white;

    switch (type) {
      case SnackBarType.success:
        bgColor = Colors.green;
        iconPath = 'assets/icons/badge-check.svg';
        break;
      case SnackBarType.warning:
        bgColor = Colors.orange;
        iconPath = 'assets/icons/warning.svg';
        break;
      case SnackBarType.error:
      default:
        bgColor = Theme.of(context).colorScheme.error;
        iconPath = 'assets/icons/octagon.svg';
    }

    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _SnackBarWidget(
        message: message,
        backgroundColor: bgColor,
        icon: iconPath,
        duration: duration,
        overlayEntry: overlayEntry,
        iconColor: iconColor,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _SnackBarWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final String icon;
  final Color iconColor;
  final Duration duration;
  final OverlayEntry overlayEntry;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SnackBarWidget({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.duration,
    required this.overlayEntry,
    required this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  __SnackBarWidgetState createState() => __SnackBarWidgetState();
}

class __SnackBarWidgetState extends State<_SnackBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(widget.duration, () async {
      await _controller.reverse();
      widget.overlayEntry.remove();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appBarIconHeight = SizeHelperClass.noteAddAppIconHeight(context);
    final appBarIconWidth = SizeHelperClass.noteAddAppIconWidth(context);

    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 12),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  widget.icon,
                  height: appBarIconHeight,
                  width: appBarIconWidth,
                  colorFilter:
                  ColorFilter.mode(widget.iconColor, BlendMode.srcIn),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.actionLabel != null && widget.onAction != null)
                  TextButton(
                    onPressed: () {
                      widget.onAction!();
                      widget.overlayEntry.remove();
                    },
                    child: Text(
                      widget.actionLabel!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
