import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../widget/custom_container.dart';
import '../../widget/custom_menu_widget.dart';
import '../../helper class/size_helper_class.dart';

class CustomNotesListTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> menuTitles;
  final List<VoidCallback> menuCallbacks;
  final Color borderColor;
  final bool showAvatar;
  final Widget? leadingWidget;

  const CustomNotesListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.menuTitles,
    required this.menuCallbacks,
    required this.borderColor,
    this.showAvatar = true,
    this.leadingWidget,
  });

  @override
  State<CustomNotesListTile> createState() => _CustomNotesListTileState();
}

class _CustomNotesListTileState extends State<CustomNotesListTile> {



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
    final TextTheme tt = Theme.of(context).textTheme;

    final moreIconWidth = SizeHelperClass.moreIconWidth(context);
    final moreIconHeight = SizeHelperClass.moreIconHeight(context);
    final lIconContainerWidth = SizeHelperClass.listIconContainerWidth(context);
    final lIconContainerHeight = SizeHelperClass.listIconContainerHeight(context);

    final scale = _scale(context);
    double listIconContainerHeight = (lIconContainerHeight * scale)
        .clamp(45, 112);
    double listIconContainerWidth = (lIconContainerWidth * scale)
        .clamp(18, 330);

    return CustomContainer(
      color: cs.primaryContainer,
      outlineColor: widget.leadingWidget != null
          ? Colors.red.withOpacity(0.5)
          : widget.borderColor,
      circularRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Note Icon or Custom Leading Widget
            if (widget.showAvatar || widget.leadingWidget != null)
              widget.leadingWidget ??
                  CustomContainer(
                    padding: EdgeInsets.all(8),
                    height: listIconContainerHeight,
                    width: listIconContainerWidth,
                    color: cs.primaryContainer,
                    outlineColor: cs.outline,
                    circularRadius: 9,
                    child: SvgPicture.asset(
                      'assets/icons/note_fill.svg',
                      colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
                    ),
                  ),

            if (widget.showAvatar || widget.leadingWidget != null)
              const SizedBox(width: 8),

            // Note Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.isEmpty ? 'Untitled' : widget.title,
                    style: tt.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle.isNotEmpty)
                    Text(
                      widget.subtitle,
                      style: tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Menu (hidden when leadingWidget is provided)
            if (widget.leadingWidget == null)
              GestureDetector(
                onTapDown: (details) {
                  customMenuWidget(
                    context: context,
                    position: details.globalPosition,
                    titles: widget.menuTitles,
                    onTapCallbacks: widget.menuCallbacks,
                    colorScheme: cs,
                    textTheme: tt,
                  );
                },
                child: SvgPicture.asset(
                  'assets/icons/menu-dots-vertical.svg',
                  height: moreIconHeight,
                  width: moreIconWidth,
                  colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
                ),
              ),
          ],
        ),
      ),
    );
  }
}