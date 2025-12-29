import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/bottomnav/bottom_provider.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';
import '../../helper class/size_helper_class.dart';
import '../../helper class/task_helper_class.dart';
import '../../widget/emptystate/empty_state.dart';
import '../../widget/emptystate/loading_skeleton.dart';
import '../add task/task_list_tile.dart';

class CompletedTasks extends StatefulWidget {
  const CompletedTasks({super.key});

  @override
  State<CompletedTasks> createState() => _CompletedTasksState();
}

class _CompletedTasksState extends State<CompletedTasks>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late final AnimationController _arrowController;

  // Use subscription-aware banner manager
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;
  final int _indices = 2;


  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        final subscriptionProvider = context.read<SubscriptionProvider>();
        final taskProvider = context.read<TaskProvider>();

        final completedTasks = taskProvider.completedTasks
            .where((t) => t.date != null)
            .toList();

        // Generate banner indices (banner every 2 tasks)
        final indices = _generateBannerIndices(completedTasks.length, _indices);

        if (indices.isEmpty) {
          debugPrint('[CompletedTasks] No banner indices generated');
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
          '[CompletedTasks] Banner manager initialized with ${indices.length} positions',
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
    _arrowController.dispose();
    _bannerManager?.dispose();
    super.dispose();
  }

  void toggleExpand() {
    setState(() {
      isExpanded = !isExpanded;
      if (isExpanded) {
        _arrowController.forward();
      } else {
        _arrowController.reverse();
      }
    });
  }

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

    final double sHeight = SizeHelperClass.homeConSHeight(context);
    final double eHeight = SizeHelperClass.homeConEHeight(context);

    final scale = _scale(context);
    double shrinkHeight = (sHeight * scale).clamp(112, 125);
    double expendedHeight = (eHeight * scale).clamp(330, 340);

    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        final completedTasks =
        provider.completedTasks.where((t) => t.date != null).toList()
          ..sort((a, b) => b.date!.compareTo(a.date!));

        if (completedTasks.isEmpty) {
          return EmptyState(title: 'No tasks completed yet!');
        }

        if (provider.isLoading) {
          return LoadingSkeleton(loadingSkeletonItemCount: isExpanded ? 5 : 1);
        }

        final displayTasks = isExpanded
            ? completedTasks
            : completedTasks.take(1).toList();

        final containerHeight = isExpanded ? expendedHeight : shrinkHeight;

        return Stack(
          children: [
            GestureDetector(
              onTap: toggleExpand,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: containerHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: cs.onPrimaryContainer,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _buildTaskList(displayTasks, cs),
                ),
              ),
            ),

            // ARROW INDICATOR
            Positioned(
              right: 10,
              top: 7,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      context.read<BottomNavProvider>().changeTab(
                        1,
                        timelineTab: 4,
                      );
                    },
                    child: Text(
                      'View more',
                      style: tt.bodySmall?.copyWith(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 5),
                  AnimatedBuilder(
                    animation: _arrowController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _arrowController.value * 3.14,
                        child: GestureDetector(
                          onTap: toggleExpand,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: SizeHelperClass.keyboardArrowDownIconSize(
                              context,
                            ),
                            color: cs.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskList(
      List<TaskModel> tasks,
      ColorScheme colorScheme,
      ) {
    // ✅ FIXED: Proper null safety checks
    final showAds = _isInitialized &&
        _bannerManager != null &&
        !_bannerManager!.isDisposed;

    final bannerIndices = showAds
        ? _generateBannerIndices(tasks.length, _indices)
        : <int>[];

    final itemCount = tasks.length + bannerIndices.length;

    return ListView.builder(
      physics: isExpanded
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
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
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  task.date != null
                      ? DateFormat('MMM dd, HH:mm').format(task.date!)
                      : '',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
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
                borderColor:
                TaskHelperClass.priorityColor(task.priority, colorScheme),
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