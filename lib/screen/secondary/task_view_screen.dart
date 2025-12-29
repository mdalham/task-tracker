import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/widget/circular_checkbox.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';
import 'package:tasktracker/helper%20class/task_helper_class.dart';
import '../../models/dialog/delete_dialog.dart';
import '../../service/ads/banner/banner_ads.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_aware_interstitial_manager ·.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/task/db/recurrence_models.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';
import '../../widget/custom_snack_bar.dart';
import '../../widget/emptystate/view_empty_state.dart';

class TaskViewScreen extends StatefulWidget {
  final TaskModel task;
  const TaskViewScreen({super.key, required this.task});

  @override
  State<TaskViewScreen> createState() => _TaskViewScreenState();
}

class _TaskViewScreenState extends State<TaskViewScreen> {
  final DraggableScrollableController _dragController =
  DraggableScrollableController();

  // ✅ FIXED: Add interstitial manager for showing ad on close
  SubscriptionAwareInterstitialManager? _interstitialManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // ✅ Initialize interstitial manager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        _interstitialManager = SubscriptionAwareInterstitialManager(
          subscriptionProvider: subscriptionProvider,
          admobPrimaryId: 'ca-app-pub-7237142331361857/2288769251',
          admobSecondaryId: 'ca-app-pub-7237142331361857/8653935503',
          metaInterstitialId: '1916722012533263_1916774079194723',
          unityInterstitialId: 'Interstitial_Android',
          tapThreshold: 1,
          maxRetry: 20,
        );
        _isInitialized = true;
      });
    });
  }

  @override
  void dispose() {
    _dragController.dispose();
    _interstitialManager?.dispose();
    super.dispose();
  }

  Future<void> _closeWithAd() async {
    _interstitialManager?.registerTap();

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ✅ FIXED: Show ad on back button press
      onWillPop: () async {
        await _closeWithAd();
        return false; // Prevent default pop, we handle it
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            GestureDetector(
              onTap: _closeWithAd,
              child: Container(color: Colors.black26),
            ),
            // Draggable sheet
            DraggableScrollableSheet(
              controller: _dragController,
              initialChildSize: 0.40,
              minChildSize: 0.30,
              maxChildSize: 0.96,
              snap: true,
              snapSizes: const [0.55, 0.75, 0.96],
              builder: (context, scrollController) {
                return Consumer<TaskProvider>(
                  builder: (context, provider, _) {
                    final task = provider.allTasks.firstWhere(
                          (t) => t.id == widget.task.id,
                      orElse: () => widget.task,
                    );
                    return _TaskSheet(
                      task: task,
                      scrollController: scrollController,
                      dragController: _dragController,
                      onClose: _closeWithAd, // ✅ Pass close handler
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Sheet UI – FULL HEADER IS DRAGGABLE
class _TaskSheet extends StatefulWidget {
  final TaskModel task;
  final ScrollController scrollController;
  final DraggableScrollableController dragController;
  final Future<void> Function() onClose; // ✅ Add close callback

  const _TaskSheet({
    required this.task,
    required this.scrollController,
    required this.dragController,
    required this.onClose,
  });

  // Formatters
  static final _dateFmt = DateFormat('EEE, MMM d, yyyy');
  static final _timeFmt = DateFormat('h:mm a');

  @override
  State<_TaskSheet> createState() => _TaskSheetState();

  static Future<void> _deleteTask(BuildContext context, TaskModel task) async {
    // 1. Confirm deletion
    final confirmed = await deleteDialog(
      context: context,
      title: "Delete Task?",
      message: 'This action cannot be undone after delete completed',
    );
    if (confirmed != true) return;
    Navigator.of(context).pop();
    if (task.id == null) return;

    final provider = Provider.of<TaskProvider>(context, listen: false);
    final TaskModel deletedTask = task;
    provider.deleteTask(task.id!);

    if (!context.mounted) return;

    CustomSnackBar.show(
      context,
      message: 'Task deleted successfully!',
      type: SnackBarType.success,
      actionLabel: 'Undo',
      onAction: () async {
        await provider.addTask(deletedTask);
      },
    );
  }
}

class _TaskSheetState extends State<_TaskSheet> {
  // ✅ FIXED: Use subscription-aware banner manager
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // ✅ Initialize banner manager with subscription provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        _bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: [0, 1, 2],
          admobId: "ca-app-pub-7237142331361857/7733093310",
          metaId: "1916722012533263_1916773885861409",
          unityPlacementId: 'Banner_Android',
        );
        _isInitialized = true;
      });
    });
  }

  @override
  void dispose() {
    _bannerManager?.dispose();
    super.dispose();
  }

  // ✅ Helper method to build banner safely
  Widget _buildBanner(int index) {
    if (!_isInitialized || _bannerManager == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _bannerManager!.bannerReady(index),
      builder: (_, isReady, __) {
        if (!isReady) return const SizedBox.shrink();
        return _bannerManager!.getBannerWidget(index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final calendarIconWidth = SizeHelperClass.calendarDayWidth(context);
    final calendarIconHeight = SizeHelperClass.calendarDayHeight(context);

    final dateTimeStr = widget.task.date != null
        ? '${_TaskSheet._dateFmt.format(widget.task.date!)} – ${_TaskSheet._timeFmt.format(widget.task.date!)}'
        : 'No date set';

    final recurrenceStr = widget.task.recurrenceSettings.getDisplayText();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ──────────────────────
          // DRAGGABLE HEADER
          // ──────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) {
              final delta = d.delta.dy;
              final size = widget.dragController.size;
              final newSize = (size - delta / screenHeight).clamp(0.35, 1.0);
              widget.dragController.jumpTo(newSize);
            },
            onVerticalDragEnd: (d) async {
              final current = widget.dragController.size;
              final velocity = d.velocity.pixelsPerSecond.dy;

              // ✅ FIXED: Show ad when dragging down to close
              if (velocity > 800 || current <= 0.32) {
                await widget.onClose();
                return;
              }

              double target;
              if (velocity < -1000) {
                target = 1.0;
              } else if (velocity > 1000) {
                target = 0.35;
              } else {
                const snaps = [0.35, 0.55, 0.75, 1.0];
                target = snaps.reduce(
                      (a, b) => (current - a).abs() < (current - b).abs() ? a : b,
                );
              }

              widget.dragController.animateTo(
                target,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              );
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Title + actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.task.title.isEmpty
                              ? 'Untitled Task'
                              : widget.task.title,
                          style: textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          CircularCheckbox(
                            value: widget.task.isChecked,
                            onChanged: (_) => TaskHelperClass.toggleComplete(
                              context,
                              widget.task,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Edit
                          GestureDetector(
                            onTap: () =>
                                TaskHelperClass.editTask(context, widget.task),
                            child: SvgPicture.asset(
                              'assets/icons/edit.svg',
                              width: calendarIconWidth + 3,
                              height: calendarIconHeight + 3,
                              colorFilter: ColorFilter.mode(
                                cs.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () =>
                                _TaskSheet._deleteTask(context, widget.task),
                            child: SvgPicture.asset(
                              'assets/icons/trash.svg',
                              width: calendarIconWidth + 3,
                              height: calendarIconHeight + 3,
                              colorFilter: ColorFilter.mode(
                                cs.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Date & Time
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/calendar-day.svg',
                        width: calendarIconWidth,
                        height: calendarIconHeight,
                        colorFilter: ColorFilter.mode(
                          cs.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(dateTimeStr, style: textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Divider with priority color
          Divider(
            height: 1,
            thickness: 1,
            color: TaskHelperClass.priorityColor(widget.task.priority, cs),
          ),

          // ✅ FIXED: Use safe banner builder
          _buildBanner(0),

          // Scrollable content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: widget.scrollController,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // DESCRIPTION
                                if (widget.task.description.isNotEmpty) ...[
                                  Text(
                                    widget.task.description,
                                    style: textTheme.bodyLarge!.copyWith(
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],

                                // =============================
                                // CHECKLIST - ✅ FIXED
                                // =============================
                                if (widget.task.checklistTask.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Checklist',
                                        style: textTheme.titleMedium,
                                      ),
                                      _buildChecklistProgress(
                                        context,
                                        textTheme,
                                        cs,
                                      ),
                                    ],
                                  ),

                                  // ✅ FIXED: Use index to identify items uniquely
                                  ...List.generate(
                                    widget.task.checklistTask.length,
                                        (index) {
                                      final item = widget.task.checklistTask[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: GestureDetector(
                                          onTap: () =>
                                              _toggleChecklistItemByIndex(context, index),
                                          child: Row(
                                            children: [
                                              Icon(
                                                item.isChecked
                                                    ? Icons.check_box
                                                    : Icons.check_box_outline_blank,
                                                size: MediaQuery.of(context)
                                                    .size
                                                    .shortestSide *
                                                    0.055,
                                                color: item.isChecked
                                                    ? Colors.green
                                                    : cs.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: textTheme.bodyMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  _buildBanner(1),
                                ],

                                // EMPTY STATE
                                if (widget.task.description.isEmpty &&
                                    widget.task.checklistTask.isEmpty)
                                  Center(
                                    child: ViewEmptyState(title: 'No additional details',),
                                  ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // BOTTOM INFO SECTION (NOW SCROLLABLE)
                          Container(
                            decoration: BoxDecoration(
                              color: cs.surface,
                              border: Border(
                                top: BorderSide(color: cs.outline, width: 1),
                              ),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.task.priority != 'None')
                                  _buildInfoRow(
                                    icon: 'assets/icons/priority-arrow.svg',
                                    label: 'Priority',
                                    value: widget.task.priority,
                                    color: cs,
                                    textTheme: textTheme,
                                    iconHeight: calendarIconHeight,
                                    iconWidth: calendarIconWidth,
                                  ),

                                if (widget.task.category.isNotEmpty)
                                  _buildInfoRow(
                                    icon: 'assets/icons/calendar-day.svg',
                                    label: 'Category',
                                    value: widget.task.category,
                                    color: cs,
                                    textTheme: textTheme,
                                    iconHeight: calendarIconHeight,
                                    iconWidth: calendarIconWidth,
                                  ),

                                if (widget.task.isImportant)
                                  _buildInfoRow(
                                    icon: 'assets/icons/calendar-day.svg',
                                    label: 'Important',
                                    value: '',
                                    color: cs,
                                    textTheme: textTheme,
                                    iconHeight: calendarIconHeight,
                                    iconWidth: calendarIconWidth,
                                  ),

                                if (widget.task.reminderDateTime != null)
                                  _buildInfoRow(
                                    icon:
                                    'assets/icons/bell-notification-social-media.svg',
                                    label: 'Reminder',
                                    value: _formatReminder(
                                      widget.task.reminderDateTime!,
                                    ),
                                    color: cs,
                                    textTheme: textTheme,
                                    iconHeight: calendarIconHeight,
                                    iconWidth: calendarIconWidth,
                                  ),

                                if (widget.task.recurrenceSettings.type !=
                                    RecurrenceType.none)
                                  _buildInfoRow(
                                    icon: 'assets/icons/repeat.svg',
                                    label: 'Recurrence',
                                    value: recurrenceStr,
                                    color: cs,
                                    textTheme: textTheme,
                                    iconHeight: calendarIconHeight,
                                    iconWidth: calendarIconWidth,
                                  ),

                                if (widget.task.isRecurringInstance &&
                                    widget.task.originalDate != null)
                                  _buildInfoRow(
                                    icon: 'assets/icons/calendar-day.svg',
                                    label: 'Instance of',
                                    value: _TaskSheet._dateFmt.format(
                                      widget.task.originalDate!,
                                    ),
                                    color: cs,
                                    textTheme: textTheme,
                                    iconHeight: calendarIconHeight,
                                    iconWidth: calendarIconWidth,
                                  ),

                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: calendarIconHeight,
                                      color: cs.primary.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.task.timestamp,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: cs.primary.withOpacity(0.7),
                                        fontStyle: FontStyle.italic,
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String icon,
    required double iconHeight,
    required double iconWidth,
    required String label,
    required String value,
    required ColorScheme color,
    required TextTheme textTheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SvgPicture.asset(
            icon,
            width: iconWidth,
            height: iconHeight,
            colorFilter: ColorFilter.mode(color.onSurface, BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          if (label.isNotEmpty) Text('$label: ', style: textTheme.bodyMedium),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              value,
              style: textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistProgress(
      BuildContext context,
      TextTheme textTheme,
      ColorScheme cs,
      ) {
    final total = widget.task.checklistTask.length;
    final completed = widget.task.checklistTask.where((i) => i.isChecked).length;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: progress == 1.0
            ? Colors.green.withOpacity(0.1)
            : cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progress == 1.0 ? Colors.green : cs.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            progress == 1.0 ? Icons.check_circle : Icons.circle_outlined,
            size: MediaQuery.of(context).size.shortestSide * 0.035,
            color: progress == 1.0 ? Colors.green : cs.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '$completed/$total',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: progress == 1.0 ? Colors.green : cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Toggle by index instead of comparing item properties
  Future<void> _toggleChecklistItemByIndex(
      BuildContext context,
      int itemIndex,
      ) async {
    if (widget.task.id == null) return;
    final provider = Provider.of<TaskProvider>(context, listen: false);

    final updatedChecklist = List<TaskModel>.from(widget.task.checklistTask);

    // Toggle the specific item by index
    final currentItem = updatedChecklist[itemIndex];
    updatedChecklist[itemIndex] = currentItem.copyWith(
      isChecked: !currentItem.isChecked,
      completedAt: !currentItem.isChecked ? DateTime.now() : null,
    );

    final updatedTask = widget.task.copyWith(
      checklistTask: updatedChecklist,
      updatedAt: DateTime.now(),
    );

    await provider.updateTask(updatedTask);
  }

  // Helpers
  String _formatReminder(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Reminder passed';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h before';
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m before';
    }
    if (diff.inMinutes > 0) return '${diff.inMinutes}m before';
    return 'Now';
  }
}