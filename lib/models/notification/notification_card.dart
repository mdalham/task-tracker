import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/helper%20class/icon_helper.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';
import 'package:tasktracker/screen/secondary/task_view_screen.dart';
import '../../screen/secondary/note_view_screen.dart';
import '../../service/note/provider/notes_provider.dart';
import '../../service/notification/db/notification_models.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';

class NotificationCard extends StatelessWidget {
  final NotificationHistory notification;
  final TaskProvider taskProvider;
  final bool highlight;
  final VoidCallback? onTap;
  final bool isLast;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.taskProvider,
    this.highlight = false,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final iconWidth = SizeHelperClass.notificationLIconWidth(context);
    final iconHeight = SizeHelperClass.notificationLIconHeight(context);

    final type = notification.notificationType;
    final bool isNoteReminder = type == 'note_reminder';
    final bool isTaskReminder = type == 'reminder';
    final bool isFiveMinute = type == '5-minute';

    Color accentColor;
    String leadingIcon;

    if (isNoteReminder) {
      accentColor = Colors.purple;
      leadingIcon = notification.isRead
          ? IconHelper.notificationIcon
          : IconHelper.notificationBellIcon;
    } else if (isFiveMinute) {
      accentColor = Colors.orange;
      leadingIcon = notification.isRead
          ? IconHelper.notificationIcon
          : IconHelper.notificationBellIcon;
    } else {
      accentColor = Colors.blue;
      leadingIcon = notification.isRead
          ? IconHelper.notificationIcon
          : IconHelper.notificationBellIcon;
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            onTap: () {
              onTap?.call();
              _handleNotificationTap(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leading Icon
                  Container(
                    width: SizeHelperClass.listIconContainerWidth(context),
                    height: SizeHelperClass.listIconContainerHeight(context),
                    padding: EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SvgPicture.asset(
                          leadingIcon,
                          width: iconWidth,
                          height: iconHeight,
                          colorFilter: ColorFilter.mode(
                            colorScheme.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                        if (!notification.isRead)
                          Positioned(
                            left: MediaQuery.of(context).size.width * 0.044,
                            bottom: MediaQuery.of(context).size.height * 0.019,
                            child: SvgPicture.asset(
                              IconHelper.notificationBellBollIcon,
                              colorFilter: ColorFilter.mode(
                                Colors.blue,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.taskTitle,
                                style: textTheme.titleLarge!.copyWith(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isNoteReminder
                                    ? 'Note'
                                    : (isFiveMinute ? '5-Min' : 'Task'),
                                style: textTheme.displayMedium!.copyWith(
                                  fontWeight: FontWeight.w300,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: (notification.taskDescription.isNotEmpty)
                                  ? Text(
                                      notification.taskDescription,
                                      style: textTheme.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : _buildSentTime(),
                            ),
                            Text(
                              _formatTimeAgo(notification.sentAt),
                              style: textTheme.displayMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            thickness: 1,
            indent: 0,
            endIndent: 0,
            color: colorScheme.outline,
          ),
      ],
    );
  }

  Widget _buildSentTime() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 15, color: Colors.grey[600]),
        const SizedBox(width: 5),
        Text(
          'Sent: ${DateFormat('MMM d, yyyy • h:mm a').format(notification.sentAt)}',
          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }

  void _handleNotificationTap(BuildContext context) {
    final type = notification.notificationType;

    if (type == 'note_reminder') {
      // Fetch note by ID
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final note = noteProvider.notes.firstWhere(
        (n) => n.id == notification.taskId,
      );
      //scaffeldmasse

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => NoteViewScreen(note: note),
      );

      return;
    }

    final task = taskProvider.allTasks.firstWhere(
      (t) => t.id == notification.taskId,
    );
    //scaffeldmasse

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskViewScreen(task: task),
    );
  }
}
