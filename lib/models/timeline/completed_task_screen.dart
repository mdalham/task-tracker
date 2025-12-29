import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/widget/emptystate/loading_skeleton.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';
import '../../widget/animated_widget.dart';
import '../../helper class/task_helper_class.dart';
import '../add task/task_list_tile.dart';

class CompletedScreen extends StatefulWidget {
  const CompletedScreen({super.key});

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen> {
  int? selectedDateIndex = 0;
  final ScrollController _scrollController = ScrollController();

  // ✅ FIXED: Use subscription-aware banner manager
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;
  final int _indices = 2;


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final completedTasks = taskProvider.completedTasks;

      _jumpToIndexNoAnimation(selectedDateIndex!);

      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        final subscriptionProvider = context.read<SubscriptionProvider>();
        final taskCount = completedTasks.length;

        // Generate banner indices (banner every 2 tasks)
        final indices = _generateBannerIndices(taskCount, _indices);

        if (indices.isEmpty) {
          debugPrint('[CompletedScreen] No banner indices generated');
          return;
        }

        setState(() {
          // ✅ Initialize subscription-aware banner manager
          _bannerManager = SubscriptionAwareBannerManager(
            subscriptionProvider: subscriptionProvider,
            indices: indices,
            admobId: "ca-app-pub-7237142331361857/3881028501",
            metaId: "1916722012533263_1916773885861409",
            unityPlacementId: 'Banner_Android',
          );
          _isInitialized = true;
        });

        debugPrint('[CompletedScreen] Banner manager initialized with ${indices.length} positions');
      }
    });
  }

  // ✅ Helper method to generate banner indices
  List<int> _generateBannerIndices(int taskCount, int step) {
    List<int> indices = [];
    if (taskCount == 0) return indices;

    int index = step; // First banner after 'step' tasks
    while (index < taskCount + indices.length) {
      indices.add(index);
      index += step + 1; // +1 because banner occupies a slot
    }

    return indices;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bannerManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final todayString = DateFormat('MMM dd, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return LoadingSkeleton(
              loadingSkeletonItemCount: provider.completedTasks.length,
            );
          }

          final tasks = provider.completedTasks;
          final timelineData = _generateTimelineData(tasks);

          if (timelineData.isEmpty) {
            return Center(
              child: Text(
                'No completed tasks in the last year',
                style: textTheme.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 10),
            itemCount: timelineData.length,
            itemBuilder: (context, index) {
              final day = timelineData[index];
              final isSelected = selectedDateIndex == index;
              final isToday = day["date"] == todayString;
              final currentDate = DateFormat('MMM dd, yyyy').parse(day["date"]);
              final currentMonth = DateFormat('MMMM yyyy').format(currentDate);
              final previousMonth = index > 0
                  ? DateFormat('MMMM yyyy').format(
                DateFormat('MMM dd, yyyy').parse(
                  timelineData[index - 1]["date"],
                ),
              )
                  : "";

              return AnimationWidget(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentMonth != previousMonth)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(currentMonth, style: textTheme.titleLarge),
                      ),
                    Stack(
                      children: [
                        Positioned(
                          left: 9,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: Colors.blue.withOpacity(0.8),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              alignment: Alignment.topCenter,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.white,
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedDateIndex = isSelected
                                            ? null
                                            : index;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            day["date"],
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .copyWith(
                                              color: isToday
                                                  ? Colors.blue
                                                  : colorScheme.primary,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent
                                                  .withOpacity(0.2),
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "${day["tasks"].length} Tasks",
                                              style: textTheme.bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    child: isSelected &&
                                        (day["tasks"] as List).isNotEmpty
                                        ? Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.only(
                                          top: 10,
                                          left: 10,
                                          right: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface,
                                          borderRadius:
                                          BorderRadius.circular(18),
                                          border: Border.all(
                                            color: colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                        child: _buildTaskList(
                                          day["tasks"] as List<TaskModel>,
                                        ),
                                      ),
                                    )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks) {
    // ✅ FIXED: Proper null safety checks
    final showAds = _isInitialized &&
        _bannerManager != null &&
        !_bannerManager!.isDisposed;

    final bannerIndices = showAds
        ? _generateBannerIndices(tasks.length, _indices)
        : <int>[];

    final itemCount = tasks.length + bannerIndices.length;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Check if this index should show a banner
        if (showAds && bannerIndices.contains(index)) {
          return ValueListenableBuilder<bool>(
            valueListenable: _bannerManager!.bannerReady(index),
            builder: (context, isReady, child) {
              if (!isReady) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TaskListTile(
            title: task.title.isEmpty ? 'Untitled' : task.title,
            subtitle: task.description.isEmpty
                ? 'No description'
                : task.description,
            menuTitles: const ["Edit", "Delete"],
            menuCallbacks: [
                  () => TaskHelperClass.editTask(context, task),
                  () => TaskHelperClass.deleteTask(context, task),
            ],
            borderColor: TaskHelperClass.priorityColor(
              task.priority,
              Theme.of(context).colorScheme,
            ),
            taskIsChecked: task.isChecked,
            toggleComplete: (_) =>
                TaskHelperClass.toggleComplete(context, task),
            openTask: () => TaskHelperClass.openTask(context, task),
            dateFormate: task.date != null
                ? TaskHelperClass.formatDate(task.date!)
                : 'No date',
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _generateTimelineData(List<TaskModel> tasks) {
    final today = DateTime.now();
    final oneYearAgo = today.subtract(const Duration(days: 365));
    final Map<String, List<TaskModel>> tasksByDate = {};

    // Group only tasks from last 365 days
    for (final task in tasks) {
      if (task.date == null) continue;
      if (task.date!.isBefore(oneYearAgo)) continue;

      final dateStr = DateFormat('MMM dd, yyyy').format(task.date!);
      tasksByDate.putIfAbsent(dateStr, () => []).add(task);
    }

    final List<Map<String, dynamic>> data = [];

    // TODAY FIRST
    final todayStr = DateFormat('MMM dd, yyyy').format(today);
    if (tasksByDate.containsKey(todayStr)) {
      data.add({"date": todayStr, "tasks": tasksByDate[todayStr]!});
    } else {
      data.add({"date": todayStr, "tasks": <TaskModel>[]});
    }

    // YESTERDAY → 364 days ago (all dates)
    DateTime current = today.subtract(const Duration(days: 1));
    while (!current.isBefore(oneYearAgo)) {
      final dateStr = DateFormat('MMM dd, yyyy').format(current);
      data.add({
        "date": dateStr,
        "tasks": tasksByDate[dateStr] ?? <TaskModel>[],
      });
      current = current.subtract(const Duration(days: 1));
    }

    return data;
  }

  void _jumpToIndexNoAnimation(int index) {
    if (!_scrollController.hasClients) return;
    const double itemHeight = 110.0;
    final offset = index * itemHeight;
    try {
      _scrollController.jumpTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    } catch (_) {}
  }
}