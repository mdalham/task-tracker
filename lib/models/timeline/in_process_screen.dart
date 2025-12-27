import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';
import '../../widget/animated_widget.dart';
import '../../helper class/task_helper_class.dart';
import '../add task/task_list_tile.dart';
import 'package:tasktracker/widget/loading_skeleton.dart';

class InProcessScreen extends StatefulWidget {
  const InProcessScreen({super.key});

  @override
  State<InProcessScreen> createState() => _InProcessScreenState();
}

class _InProcessScreenState extends State<InProcessScreen> {
  int? selectedDateIndex;
  final ScrollController _scrollController = ScrollController();
  late List<Map<String, dynamic>> timelineData;

  //  Use subscription-aware banner manager
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;
  final int _indices = 2;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TaskProvider>(context, listen: false);
    final tasks = provider.inProgressTasks;
    timelineData = _generateTimelineData(tasks);

    // TOMORROW IS ALWAYS AT INDEX 0
    selectedDateIndex = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _jumpToIndexNoAnimation(selectedDateIndex!);

      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        final subscriptionProvider = context.read<SubscriptionProvider>();
        final taskProvider = context.read<TaskProvider>();
        final totalTasks = taskProvider.inProgressTasks.length;

        // Generate banner indices (banner every 2 tasks)
        final indices = _generateBannerIndices(totalTasks, _indices);

        if (indices.isEmpty) {
          debugPrint('[InProcessScreen] No banner indices generated');
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

        debugPrint(
          '[InProcessScreen] Banner manager initialized with ${indices.length} positions',
        );
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
    final tomorrowString = DateFormat(
      'MMM dd, yyyy',
    ).format(DateTime.now().add(const Duration(days: 1)));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return LoadingSkeleton(
              loadingSkeletonItemCount: provider.inProgressTasks.length,
            );
          }

          final tasks = provider.inProgressTasks;
          timelineData = _generateTimelineData(tasks);

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 10),
            itemCount: timelineData.length,
            itemBuilder: (context, index) {
              final day = timelineData[index];
              final isSelected = selectedDateIndex == index;
              final isTomorrow = day["date"] == tomorrowString;
              final currentDate = DateFormat('MMM dd, yyyy').parse(day["date"]);
              final currentMonth = DateFormat('MMMM yyyy').format(currentDate);
              final previousMonth = index > 0
                  ? DateFormat('MMMM yyyy').format(
                DateFormat(
                  'MMM dd, yyyy',
                ).parse(timelineData[index - 1]["date"]),
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
                            color: isTomorrow
                                ? Colors.blue.withOpacity(0.8)
                                : Colors.blueAccent.withOpacity(0.8),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline Dot
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
                                  // Date Header
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
                                              color: isTomorrow
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

                                  // Task List
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
    final tomorrow = today.add(const Duration(days: 1));
    final endDate = today.add(const Duration(days: 365));

    final Map<String, List<TaskModel>> tasksByDate = {};

    for (final task in tasks) {
      if (task.date == null) continue;
      final dateStr = DateFormat('MMM dd, yyyy').format(task.date!);
      tasksByDate.putIfAbsent(dateStr, () => []).add(task);
    }

    final List<Map<String, dynamic>> data = [];

    // TOMORROW FIRST
    final tomorrowStr = DateFormat('MMM dd, yyyy').format(tomorrow);
    data.add({"date": tomorrowStr, "tasks": tasksByDate[tomorrowStr] ?? []});

    // REST (SKIP TODAY)
    DateTime current = tomorrow.add(const Duration(days: 1));
    while (!current.isAfter(endDate)) {
      final dateStr = DateFormat('MMM dd, yyyy').format(current);
      data.add({"date": dateStr, "tasks": tasksByDate[dateStr] ?? []});
      current = current.add(const Duration(days: 1));
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