import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';
import '../../service/ads/industrial/smart_industrial_ad.dart';
import '../../service/subscription/subscription_aware_interstitial_manager ·.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../widget/circular_checkbox.dart';
import '../../widget/custom_container.dart';
import '../../widget/custom_menu_widget.dart';

class TaskListTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> menuTitles;
  final List<VoidCallback> menuCallbacks;
  final Color borderColor;
  final bool taskIsChecked;
  final ValueChanged<bool?> toggleComplete;
  final GestureTapCallback openTask;
  final String dateFormate;

  const TaskListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.menuTitles,
    required this.menuCallbacks,
    required this.borderColor,
    required this.taskIsChecked,
    required this.toggleComplete,
    required this.openTask,
    required this.dateFormate,
  });

  @override
  State<TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<TaskListTile> {
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
    final lIconContainerHeight = SizeHelperClass.listIconContainerHeight(
      context,
    );

    final scale = _scale(context);
    double listIconContainerHeight = (lIconContainerHeight * scale).clamp(
      45,
      112,
    );
    double listIconContainerWidth = (lIconContainerWidth * scale).clamp(
      18,
      330,
    );

    return GestureDetector(
      onTap: widget.openTask,
      child: CustomContainer(
        color: cs.primaryContainer,
        outlineColor: widget.borderColor,
        circularRadius: 16,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CustomContainer(
                height: listIconContainerHeight,
                width: listIconContainerWidth,
                color: cs.primaryContainer,
                outlineColor: cs.outline,
                circularRadius: 9,
                child: SvgPicture.asset(
                  widget.taskIsChecked
                      ? 'assets/icons/task_completed.svg'
                      : 'assets/icons/task.svg',
                  colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
                ),
              ),

              const SizedBox(width: 8),

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
                    if (widget.subtitle.isEmpty)
                      Text(widget.dateFormate, style: tt.bodySmall)
                    else ...[
                      Text(
                        widget.subtitle,
                        style: tt.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Checkbox
              CircularCheckbox(
                value: widget.taskIsChecked,
                onChanged: widget.toggleComplete,
              ),
              const SizedBox(width: 8),

              // Menu
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
      ),
    );
  }
}
