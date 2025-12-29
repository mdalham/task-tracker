import 'package:flutter/material.dart';
import 'package:tasktracker/widget/emptystate/loading_skeleton.dart';
import 'package:tasktracker/helper%20class/task_helper_class.dart';
import 'package:tasktracker/models/add%20task/task_list_tile.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/ads/native_ad_widget.dart';
import '../../service/subscription/nativ_ad_manager.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';
import '../../widget/animated_widget.dart';
import 'calender_model.dart';
import 'package:provider/provider.dart';

class TodayTasksScreen extends StatefulWidget {
  const TodayTasksScreen({super.key});

  @override
  State<TodayTasksScreen> createState() => _TodayTasksScreenState();
}

class _TodayTasksScreenState extends State<TodayTasksScreen> {
  // Use subscription-aware banner managers
  SubscriptionAwareBannerManager? _bannerManager;
  SubscriptionAwareBannerManager? _topBannerManager;
  SubscriptionAwareNativeAdManager? _nativeAdManager;
  bool _isNativeInitialized = false;
  bool _isInitialized = false;
  final int _indices = 2;


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();
      final taskProvider = context.read<TaskProvider>();

      // Get today's tasks
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

      _initializeNativeAds();
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        // Generate banner indices for list (banner every 2 tasks)
        final listIndices = _generateBannerIndices(todayTasks.length, _indices);

        setState(() {
          // Initialize top banner manager (single banner)
          _topBannerManager = SubscriptionAwareBannerManager(
            subscriptionProvider: subscriptionProvider,
            indices: [0],
            admobId: "ca-app-pub-7237142331361857/3881028501",
            metaId: "1916722012533263_1916773885861409",
            unityPlacementId: 'Banner_Android',
          );

          // Initialize list banner manager
          if (listIndices.isNotEmpty) {
            _bannerManager = SubscriptionAwareBannerManager(
              subscriptionProvider: subscriptionProvider,
              indices: listIndices,
              admobId: "ca-app-pub-7237142331361857/3881028501",
              metaId: "1916722012533263_1916773885861409",
              unityPlacementId: 'Banner_Android',
            );
          }

          _isInitialized = true;
        });

        debugPrint(
          '[TodayTasksScreen] Initialized: '
              'Top banner ready, '
              'List banners: ${listIndices.length} positions',
        );
      }
    });
  }



  // Helper method to generate banner indices
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
    _topBannerManager?.dispose();
    _bannerManager?.dispose();
    _nativeAdManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calendar animation
                const AnimationWidget(
                  start: 0.2,
                  end: 0.7,
                  child: CalendarModel(),
                ),

                // ✅ FIXED: Top banner with null safety
                if (_isInitialized && _topBannerManager != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: _topBannerManager!.bannerReady(0),
                    builder: (_, isReady, __) {
                      if (!isReady) return const SizedBox.shrink();
                      return _topBannerManager!.getBannerWidget(0);
                    },
                  ),

                const SizedBox(height: 10),

                // Title
                AnimationWidget(
                  start: 0.3,
                  end: 0.8,
                  child: Text('Today\'s Tasks', style: textTheme.titleLarge),
                ),
                const SizedBox(height: 5),

                // Task List
                AnimationWidget(
                  start: 0.4,
                  end: 0.9,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.56,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimaryContainer,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: Consumer<TaskProvider>(
                      builder: (context, provider, _) {
                        final now = DateTime.now();
                        final todayTasks = provider.todayTasks
                            .where((t) => t.date != null)
                            .where(
                              (t) =>
                          t.date!.year == now.year &&
                              t.date!.month == now.month &&
                              t.date!.day == now.day,
                        )
                            .toList()
                          ..sort((a, b) => a.date!.compareTo(b.date!));

                        final isLoading = provider.isLoading;

                        if (isLoading) {
                          return LoadingSkeleton(
                            loadingSkeletonItemCount: todayTasks.length,
                          );
                        }

                        if (todayTasks.isEmpty) {
                          return _buildEmptyState(colorScheme, textTheme);
                        }

                        return _buildTaskList(todayTasks, colorScheme);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks, ColorScheme colorScheme) {
    // Proper null safety checks
    final showAds = _isInitialized &&
        _bannerManager != null &&
        !_bannerManager!.isDisposed;

    final bannerIndices = showAds
        ? _generateBannerIndices(tasks.length, _indices)
        : <int>[];

    final itemCount = tasks.length + bannerIndices.length;

    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Check if this index should show a banner
        if (showAds && bannerIndices.contains(index)) {
          return ValueListenableBuilder<bool>(
            valueListenable: _bannerManager!.bannerReady(index),
            builder: (context, isReady, child) {
              if (!isReady) return const SizedBox.shrink();

              return BannerAdContainerWidget(
                index: index,
                bannerManager: _bannerManager!,
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

  Widget _buildEmptyState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: MediaQuery.of(context).size.shortestSide * 0.12,
            color: cs.onSurface,
          ),
          const SizedBox(height: 6),
          Text(
            'No tasks for today',
            style: tt.bodyLarge,
          ),
          const SizedBox(height: 2),
          Text('Tasks due today will appear here', style: tt.bodySmall),
          const SizedBox(height: 6),
          if (_nativeAdManager != null &&
              _nativeAdManager!.isReady) ...[
            const SizedBox(height: 10),
            NativeAdWidget(
              adManager: _nativeAdManager!,
              height: 275,
              width: 270,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ],
      ),
    );
  }
  void _initializeNativeAds() {
    if (!mounted) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();

    setState(() {
      _nativeAdManager = SubscriptionAwareNativeAdManager(
        subscriptionProvider: subscriptionProvider,
        nativePrimaryIdHigh: 'ca-app-pub-7237142331361857/3877570139',
        nativePrimaryIdMed: 'ca-app-pub-7237142331361857/2341127181',
        nativePrimaryIdLow: 'ca-app-pub-7237142331361857/3102887974',
        maxRetry: 5,
      );
      _isNativeInitialized = true;
    });

    debugPrint('[HomeScreen] Native ad manager initialized');

    // Debug: Check status after initialization
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _nativeAdManager != null) {
        debugPrint('[HomeScreen] Native ad status after 3s:');
        debugPrint('[HomeScreen] Is ready: ${_nativeAdManager!.isReady}');
        debugPrint(
          '[HomeScreen] Current source: ${_nativeAdManager!.currentAdSource}',
        );
        debugPrint('[HomeScreen] Status: ${_nativeAdManager!.adStatus}');
      }
    });
  }


}