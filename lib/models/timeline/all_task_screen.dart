import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasktracker/widget/loading_skeleton.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';
import 'package:tasktracker/helper%20class/task_helper_class.dart';
import 'package:tasktracker/models/add%20task/task_list_tile.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/ads/banner/banner_ads.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';
import '../../widget/animated_widget.dart';
import '../../widget/custom_snack_bar.dart';
import '../dialog/delete_dialog.dart';

class AllTasksScreen extends StatefulWidget {
  const AllTasksScreen({super.key});

  @override
  State<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends State<AllTasksScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _refreshController = RefreshController(initialRefresh: false);

  String _searchQuery = '';
  String _sortBy = 'date';
  bool _sortDescending = true;
  final String _filterPriority = 'All';
  final String _filterCategory = 'All';

  // ✅ FIXED: Use subscription-aware banner manager
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;
  final int _indices = 2;

  @override
  void initState() {
    super.initState();
    _loadSortPreferences();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Provider.of<TaskProvider>(context, listen: false).loadAllTasks();

      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        final subscriptionProvider = context.read<SubscriptionProvider>();
        final taskProvider = context.read<TaskProvider>();
        final taskCount = taskProvider.allTasks.length;

        // Generate banner indices (banner every 2 tasks)
        final indices = _generateBannerIndices(taskCount, _indices);

        if (indices.isEmpty) {
          debugPrint('[AllTasksScreen] No banner indices generated');
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
          '[AllTasksScreen] Banner manager initialized with ${indices.length} positions',
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

  Future<void> _loadSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _sortBy = prefs.getString('task_sort_by') ?? 'date';
        _sortDescending = prefs.getBool('task_sort_descending') ?? true;
      });
    }
  }

  Future<void> _saveSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('task_sort_by', _sortBy);
    await prefs.setBool('task_sort_descending', _sortDescending);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    _bannerManager?.dispose();
    super.dispose();
  }

  void _onRefresh() async {
    await Provider.of<TaskProvider>(context, listen: false).loadAllTasks();
    if (mounted) {
      _refreshController.refreshCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final iconWidth = SizeHelperClass.searchIconWidth(context);
    final iconHeight = SizeHelperClass.searchIconHeight(context);
    final sortIconWidth = SizeHelperClass.sortIconWidth(context);
    final sortIconHeight = SizeHelperClass.sortIconHeight(context);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          final allTasks = provider.allTasks;

          // Apply search and filters
          var filtered = allTasks.where((t) {
            final matchesSearch =
                t.title.toLowerCase().contains(_searchQuery) ||
                t.description.toLowerCase().contains(_searchQuery);
            final matchesPriority =
                _filterPriority == 'All' || t.priority == _filterPriority;
            final matchesCategory =
                _filterCategory == 'All' || t.category == _filterCategory;
            return matchesSearch && matchesPriority && matchesCategory;
          }).toList();

          // Apply sort
          filtered.sort((a, b) {
            int comparison;
            switch (_sortBy) {
              case 'date':
                comparison = (a.date ?? DateTime(9999)).compareTo(
                  b.date ?? DateTime(9999),
                );
                break;
              case 'priority':
                const order = {'High': 0, 'Medium': 1, 'Low': 2, 'None': 3};
                comparison = order[a.priority]!.compareTo(order[b.priority]!);
                break;
              case 'title':
                comparison = a.title.compareTo(b.title);
                break;
              default:
                comparison = 0;
            }
            return _sortDescending ? -comparison : comparison;
          });

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                children: [
                  _buildSearchAndFilters(
                    cs,
                    tt,
                    provider,
                    iconWidth,
                    iconHeight,
                    sortIconWidth,
                    sortIconHeight,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: AnimationWidget(
                      start: 0.0,
                      end: 0.4,
                      child: SmartRefresher(
                        controller: _refreshController,
                        onRefresh: _onRefresh,
                        header: const MaterialClassicHeader(),
                        child: provider.isLoading
                            ? LoadingSkeleton(
                                loadingSkeletonItemCount:
                                    provider.allTasks.length,
                              )
                            : filtered.isEmpty
                            ? _buildEmptyState(cs, tt)
                            : _buildTaskList(filtered, cs, tt, provider),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(
    ColorScheme cs,
    TextTheme tt,
    TaskProvider provider,
    double iconWidth,
    double iconHeight,
    double sortIconWidth,
    double sortIconHeight,
  ) {
    return TextField(
      controller: _searchController,
      style: tt.titleMedium,
      decoration: InputDecoration(
        hintText: 'Search tasks...',
        hintStyle: tt.titleMedium!.copyWith(
          color: cs.onPrimary.withOpacity(0.7),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SvgPicture.asset(
            'assets/icons/search.svg',
            width: iconWidth,
            height: iconHeight,
            colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
          ),
        ),
        suffixIcon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _searchQuery.isNotEmpty
              ? IconButton(
                  key: const ValueKey('clear'),
                  icon: SvgPicture.asset(
                    'assets/icons/cross-small.svg',
                    width: iconWidth,
                    height: iconHeight,
                    colorFilter: ColorFilter.mode(
                      cs.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : GestureDetector(
                  key: const ValueKey('sort'),
                  onTap: () => _showSortMenu(context, tt),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SvgPicture.asset(
                      'assets/icons/sort.svg',
                      width: sortIconWidth,
                      height: sortIconHeight,
                      colorFilter: ColorFilter.mode(
                        cs.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 56,
          minHeight: 56,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.4)),
        ),
      ),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
    );
  }

  void _showSortMenu(BuildContext context, TextTheme tt) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Sort By',
                style: tt.titleMedium!.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _buildSortOption(
              tt,
              'Date (Newest First)',
              'date',
              true,
              Icons.date_range,
            ),
            _buildSortOption(
              tt,
              'Date (Oldest First)',
              'date',
              false,
              Icons.date_range,
            ),
            _buildSortOption(
              tt,
              'Priority (High to Low)',
              'priority',
              false,
              Icons.flag,
            ),
            _buildSortOption(
              tt,
              'Priority (Low to High)',
              'priority',
              true,
              Icons.flag,
            ),
            _buildSortOption(tt, 'Title (A-Z)', 'title', false, Icons.title),
            _buildSortOption(tt, 'Title (Z-A)', 'title', true, Icons.title),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
    TextTheme tt,
    String label,
    String sortBy,
    bool descending,
    IconData icon,
  ) {
    final isSelected = _sortBy == sortBy && _sortDescending == descending;
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: tt.bodyLarge),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        setState(() {
          _sortBy = sortBy;
          _sortDescending = descending;
        });
        _saveSortPreferences();
        Navigator.pop(context);
      },
    );
  }

  Widget _buildTaskList(
    List<TaskModel> tasks,
    ColorScheme cs,
    TextTheme tt,
    TaskProvider provider,
  ) {
    final showAds =
        _isInitialized && _bannerManager != null && !_bannerManager!.isDisposed;

    final bannerIndices = showAds
        ? _generateBannerIndices(tasks.length, _indices)
        : <int>[];

    final itemCount = tasks.length + bannerIndices.length;

    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      itemCount: itemCount,
      key: const PageStorageKey('task_list'),
      itemBuilder: (context, index) {
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

        int taskIndex = index - bannerIndices.where((i) => i < index).length;

        if (taskIndex >= tasks.length) return const SizedBox.shrink();

        final task = tasks[taskIndex];

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Dismissible(
            key: ValueKey(
              task.id ?? '${task.title}_${task.date?.millisecondsSinceEpoch}',
            ),
            background: Container(
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.check, color: Colors.green, size: 28),
            ),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.red, size: 28),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await TaskHelperClass.toggleComplete(context, task);
                return false;
              } else {
                final confirmed = await deleteDialog(
                  context: context,
                  title: 'Delete Task?',
                  message:
                      'Delete "${task.title}" permanently?\nThis action cannot be undone.',
                  confirmText: 'Delete',
                );
                if (confirmed == true && task.id != null) {
                  await provider.deleteTask(task.id!);
                  return true;
                }
                return false;
              }
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart && mounted) {
                CustomSnackBar.show(
                  context,
                  message: 'Task deleted successfully!',
                  type: SnackBarType.success,
                );
              }
            },
            child: TaskListTile(
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
              dateFormate: task.date != null
                  ? TaskHelperClass.formatDate(task.date!)
                  : 'No date',
            ),
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
            Icons.task_alt,
            size: MediaQuery.of(context).size.shortestSide * 0.12,
            color: cs.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text('No tasks found', style: tt.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Try adding a new task or adjust filters',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
