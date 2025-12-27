import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/helper%20class/icon_helper.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';
import 'package:tasktracker/widget/custom_snack_bar.dart';
import '../../models/notification/clear_history.dart';
import '../../models/notification/notification_card.dart';
import '../../service/notification/db/notification_models.dart';
import '../../service/notification/provider/notification_provider.dart';
import '../../service/task/provider/task_provider.dart';
import '../../models/dialog/confirm_dialog.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _highlightedId;

  late final NotificationProvider _notificationProvider;

  //Use subscription-aware banner manager
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();



    // Initialize banner manager after frame is built with subscription provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        _bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: [0],
          admobId: "ca-app-pub-7237142331361857/1563378585",
          metaId: "1916722012533263_1916773885861409",
          unityPlacementId: 'Banner_Android',
        );
        _isInitialized = true;
      });

      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationProvider = context.read<NotificationProvider>();
    _notificationProvider.addListener(_onNotificationsChanged);
  }

  void _onNotificationsChanged() {
    final latest = _notificationProvider.notifications.firstOrNull;
    if (latest == null || !mounted) return;
    setState(() => _highlightedId = latest.id);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  @override
  void dispose() {
    _notificationProvider.removeListener(_onNotificationsChanged);
    _scrollController.dispose();
    _bannerManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface),
        ),
        title: Text('Notification History', style: textTheme.displaySmall),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: const [
          _MarkAllReadButton(),
          ClearHistory(),
        ],
      ),

      // ✅ FIXED: Properly constrain the banner ad with subscription check
      bottomNavigationBar: _isInitialized && _bannerManager != null
          ? ValueListenableBuilder<bool>(
        valueListenable: _bannerManager!.bannerReady(0),
        builder: (_, isReady, __) {
          if (!isReady) return const SizedBox.shrink();

          // Wrap in SafeArea and Container with fixed height
          return SafeArea(
            child: SizedBox(
              height: 60, // Standard banner height
              child: _bannerManager!.getBannerWidget(0),
            ),
          );
        },
      )
          : const SizedBox.shrink(),

      // ✅ FIXED: Use Selector instead of Consumer2 to prevent unnecessary rebuilds
      body: Selector2<NotificationProvider, TaskProvider,
          ({List<NotificationHistory> notifications, TaskProvider taskProvider})>(
        selector: (_, notificationProvider, taskProvider) => (
        notifications: notificationProvider.notifications,
        taskProvider: taskProvider,
        ),
        // Only rebuild when notifications list actually changes
        shouldRebuild: (prev, next) => prev.notifications != next.notifications,
        builder: (context, data, child) {
          final notifications = data.notifications;
          final taskProvider = data.taskProvider;

          if (notifications.isEmpty) {
            return const _EmptyState(filterType: 'all');
          }

          final grouped = _groupBySection(notifications);
          final sections = grouped.keys.toList();

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sections.length,
            // ✅ ADDED: Prevent list from rebuilding unnecessarily
            key: const PageStorageKey('notification_list'),
            itemBuilder: (context, sIndex) {
              final section = sections[sIndex];
              final items = grouped[section]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(section, style: textTheme.titleLarge),
                  ),

                  // Cards
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 1),
                    itemBuilder: (context, index) {
                      final n = items[index];
                      return Dismissible(
                        key: ValueKey(n.id ?? n.sentAt.millisecondsSinceEpoch),
                        background: _SwipeRightBackground(n),
                        secondaryBackground: _SwipeLeftBackground(n),
                        confirmDismiss: (dir) =>
                            _confirmDismiss(context, dir, n),
                        direction: DismissDirection.horizontal,
                        child: NotificationCard(
                          notification: n,
                          taskProvider: taskProvider,
                          highlight: n.id == _highlightedId,
                          onTap: () async {
                            if (!n.isRead) {
                              await context
                                  .read<NotificationProvider>()
                                  .markAsRead(n.id!);
                            }
                          },
                          isLast: index == items.length - 1,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<bool?> _confirmDismiss(
      BuildContext context,
      DismissDirection direction,
      NotificationHistory item,
      ) async {
    final provider = context.read<NotificationProvider>();
    if (direction == DismissDirection.startToEnd) {
      await provider.markAsRead(item.id!);
      return false;
    } else {
      final removed = item;
      await provider.delete(item.id!);
      if (!context.mounted) return true;

      CustomSnackBar.show(
        context,
        message: 'Archived "${item.taskTitle}"',
        type: SnackBarType.success,
        actionLabel: 'Undo',
        onAction: () => provider.addNotification(removed),
      );
      return true;
    }
  }

  static Map<String, List<NotificationHistory>> _groupBySection(
      List<NotificationHistory> list,
      ) {
    final map = <String, List<NotificationHistory>>{};
    for (final n in list) {
      final key = _sectionForDate(n.sentAt);
      map.putIfAbsent(key, () => []).add(n);
    }
    return map;
  }

  static String _sectionForDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    if (itemDate == today) return 'Today';
    if (itemDate == yesterday) return 'Yesterday';

    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    if (!itemDate.isBefore(startOfWeek)) return 'This Week';
    return 'Older';
  }
}

class _MarkAllReadButton extends StatelessWidget {
  const _MarkAllReadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: SvgPicture.asset(
        IconHelper.doubleTick,
        width: SizeHelperClass.calendarDayWidth(context),
        height: SizeHelperClass.calendarDayHeight(context),
        colorFilter: const ColorFilter.mode(Colors.blue, BlendMode.srcIn),
      ),
      tooltip: 'Mark All as Read',
      onPressed: () async {
        final provider = context.read<NotificationProvider>();
        final unread = provider.notifications.where((n) => !n.isRead).toList();
        final count = unread.length;

        if (count == 0) {
          if (!context.mounted) return;
          CustomSnackBar.show(
            context,
            message: 'All notifications are already read',
            type: SnackBarType.success,
          );
          return;
        }

        final confirm = await showConfirmDialog(
          context: context,
          title: "Mark All as Read?",
          message: "Mark $count notification${count > 1 ? 's' : ''} as read?",
          confirmText: "Mark All",
          confirmColor: Colors.blue,
        );

        if (!context.mounted) return;
        if (confirm != true) return;

        await provider.markAllAsRead();

        if (!context.mounted) return;
        CustomSnackBar.show(
          context,
          message: 'Marked $count notification${count > 1 ? 's' : ''} as read',
          type: SnackBarType.success,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filterType;
  const _EmptyState({required this.filterType});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 84,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No Notifications Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filterType == 'all'
                ? 'Sent notifications will appear here'
                : 'No ${filterType == 'reminder' ? 'reminder' : '5-minute alert'} notifications',
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SwipeRightBackground extends StatelessWidget {
  final NotificationHistory n;
  const _SwipeRightBackground(this.n);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mark_email_read, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            n.isRead ? 'Read' : 'Mark as read',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeLeftBackground extends StatelessWidget {
  final NotificationHistory n;
  const _SwipeLeftBackground(this.n);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Archive',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.archive, color: Colors.red, size: 20),
        ],
      ),
    );
  }
}