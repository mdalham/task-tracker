import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tasktracker/widget/home_screen_container.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/bottomnav/bottom_provider.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';
import '../../helper class/task_helper_class.dart';
import '../../widget/emptystate/empty_home_container.dart';
import '../../widget/emptystate/empty_state.dart';
import '../../widget/emptystate/loading_skeleton.dart';
import '../add task/task_list_tile.dart';

class TodayTask extends StatefulWidget {
  const TodayTask({super.key});

  @override
  State<TodayTask> createState() => _TodayTaskState();
}

class _TodayTaskState extends State<TodayTask> {
  // Banner manager for ads
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;
  int _lastTaskCount = 0;
  final int _indices = 2;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBannerManager();
    });
  }

  void _initializeBannerManager() {
    if (!mounted) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final taskProvider = context.read<TaskProvider>();

    final now = DateTime.now();
    final todayTasks = taskProvider.todayTasks
        .where((t) => t.date != null)
        .where(
          (t) =>
              t.date!.year == now.year &&
              t.date!.month == now.month &&
              t.date!.day == now.day,
        )
        .toList();

    final taskCount = todayTasks.length;

    if (taskCount > 0 || _lastTaskCount != taskCount) {
      // Generate banner indices
      final indices = _generateBannerIndices(taskCount, _indices);

      // Dispose old manager if exists
      _bannerManager?.dispose();

      setState(() {
        _bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: indices,
          admobId: "ca-app-pub-7237142331361857/3881028501",
          metaId: "1916722012533263_1916773885861409",
          unityPlacementId: 'Banner_Android',
        );
        _isInitialized = true;
        _lastTaskCount = taskCount;
      });

      debugPrint(
        '[TodayTask] Initialized with $taskCount tasks, ${indices.length} banner positions',
      );
    }
  }

  List<int> _generateBannerIndices(int taskCount, int step) {
    List<int> indices = [];
    if (taskCount == 0) return indices;

    int index = step;
    while (index < taskCount + indices.length) {
      indices.add(index);
      index += step + 1;
    }

    return indices;
  }

  @override
  void dispose() {
    _bannerManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();
        final todayTasks =
            provider.todayTasks
                .where((t) => t.date != null)
                .where(
                  (t) =>
                      t.date!.year == now.year &&
                      t.date!.month == now.month &&
                      t.date!.day == now.day,
                )
                .toList()
              ..sort((a, b) => a.date!.compareTo(b.date!));

        final currentTaskCount = todayTasks.length;

        // Reinitialize banner manager if task count changed
        if (_lastTaskCount != currentTaskCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeBannerManager();
          });
        }

        // Show empty state if no tasks
        if (todayTasks.isEmpty) {
          return HomeScreenContainer(
            title: 'Today tasks',
            onTap: () {
              context.read<BottomNavProvider>().changeTab(1, timelineTab: 0);
            },
            child: Center(
              child: EmptyHomeContainer(
                title: 'No tasks',
                subText: 'Add new tasks',
              ),
            ),
          );
        }

        // Show loading skeleton
        if (provider.isLoading) {
          return HomeScreenContainer(
            title: 'Today tasks',
            onTap: () {
              context.read<BottomNavProvider>().changeTab(1, timelineTab: 0);
            },
            child: LoadingSkeleton(loadingSkeletonItemCount: todayTasks.length),
          );
        }

        final ColorScheme cs = Theme.of(context).colorScheme;
        final TextTheme tt = Theme.of(context).textTheme;

        // Build the main widget with task list
        return HomeScreenContainer(
          title: 'Today tasks',
          onTap: () {
            context.read<BottomNavProvider>().changeTab(1, timelineTab: 0);
          },
          child: _buildTaskList(todayTasks, cs, tt),
        );
      },
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks, ColorScheme cs, TextTheme tt) {
    // Check if ads should be shown
    final showAds =
        _isInitialized && _bannerManager != null && !_bannerManager!.isDisposed;

    final bannerIndices = showAds
        ? _bannerManager!.getAvailableSources().isNotEmpty
              ? _generateBannerIndices(tasks.length, _indices)
              : <int>[]
        : <int>[];

    final itemCount = tasks.length + bannerIndices.length;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Check if this index should show a banner
        if (showAds && bannerIndices.contains(index)) {
          return ValueListenableBuilder<bool>(
            valueListenable: _bannerManager!.bannerReady(index),
            builder: (context, isReady, child) {
              if (!isReady) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: BannerAdContainerWidget(
                  index: index,
                  bannerManager: _bannerManager!,
                ),
              );
            },
          );
        }

        // Calculate actual task index
        int taskIndex = index - bannerIndices.where((i) => i < index).length;

        if (taskIndex >= tasks.length) return const SizedBox.shrink();

        final task = tasks[taskIndex];
        final timeStr = task.date != null
            ? DateFormat('MMM dd, HH:mm').format(task.date!)
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  timeStr,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 4),
              TaskListTile(
                title: task.title,
                subtitle: task.description,
                menuTitles: const ["Edit", "Delete"],
                menuCallbacks: [
                  () => TaskHelperClass.editTask(context, task),
                  () => TaskHelperClass.deleteTask(context, task),
                ],
                borderColor: TaskHelperClass.priorityColor(task.priority, cs),
                taskIsChecked: task.isChecked,
                toggleComplete: (_) =>
                    TaskHelperClass.toggleComplete(context, task),
                openTask: () => TaskHelperClass.openTask(context, task),
                dateFormate: TaskHelperClass.formatDate(task.date!),
              ),
            ],
          ),
        );
      },
    );
  }
}
