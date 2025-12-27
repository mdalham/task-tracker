import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helper class/size_helper_class.dart';
import '../../models/todo/filter_chip_row.dart';
import '../../models/todo/todo_list_item.dart';
import '../../models/todo/todo_loading_skeleton.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/todo/db/todo_model.dart';
import '../../service/todo/provider/todo_provider.dart';
import '../../widget/animated_widget.dart';
import '../../widget/empty_state.dart';
import '../secondary/todo_add_and_edit_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );

  String _searchQuery = '';

  // ✅ Banner ad system
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;
  final int _indices = 2; // Banner every 2 todos

  @override
  void initState() {
    super.initState();
    _loadSortPreferences();

    // ✅ Initialize banner manager after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Provider.of<TodoProvider>(context, listen: false).loadTodos();

      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        final subscriptionProvider = context.read<SubscriptionProvider>();
        final todoProvider = context.read<TodoProvider>();
        final todoCount = todoProvider.todos.length;

        // Generate banner indices (banner every 2 todos)
        final indices = _generateBannerIndices(todoCount, _indices);

        if (indices.isEmpty) {
          debugPrint('[TodoScreen] No banner indices generated');
          return;
        }

        setState(() {
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
          '[TodoScreen] Banner manager initialized with ${indices.length} positions',
        );
      }
    });
  }

  // ✅ Helper method to generate banner indices
  List<int> _generateBannerIndices(int todoCount, int step) {
    List<int> indices = [];
    if (todoCount == 0) return indices;

    int index = step; // First banner after 'step' todos
    while (index < todoCount + indices.length) {
      indices.add(index);
      index += step + 1; // +1 because banner occupies a slot
    }

    return indices;
  }

  // ✅ Pull to refresh handler
  void _onRefresh() async {
    await Provider.of<TodoProvider>(context, listen: false).refreshTodos();
    if (mounted) {
      _refreshController.refreshCompleted();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    _bannerManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Consumer<TodoProvider>(
      builder: (context, provider, _) {
        // Get icon sizes
        final iconWidth = SizeHelperClass.searchIconWidth(context);
        final iconHeight = SizeHelperClass.searchIconHeight(context);
        final sortIconWidth = SizeHelperClass.sortIconWidth(context);
        final sortIconHeight = SizeHelperClass.sortIconHeight(context);

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                children: [
                  _buildSearchAndFilters(
                    colorScheme,
                    textTheme,
                    provider,
                    iconWidth,
                    iconHeight,
                    sortIconWidth,
                    sortIconHeight,
                  ),
                  const SizedBox(height: 6),
                  const FilterChipRow(),
                  Expanded(
                    child: AnimationWidget(
                      start: 0.0,
                      end: 0.4,
                      child: SmartRefresher(
                        controller: _refreshController,
                        onRefresh: _onRefresh,
                        header: const MaterialClassicHeader(),
                        child: Builder(
                          builder: (context) {
                            if (provider.isLoading) {
                              return TodoLoadingSkeleton(loadingSkeletonItemCount: provider.todos.length);
                            }

                            if (provider.errorMessage != null) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(provider.errorMessage!),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => provider.refreshTodos(),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final todos = provider.todos;

                            if (todos.isEmpty) {
                              return const EmptyState(title: 'No todos yet');
                            }

                            return _buildTodoList(
                              todos,
                              colorScheme,
                              textTheme,
                              provider,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodoList(
    List<Todo> todos,
    ColorScheme cs,
    TextTheme tt,
    TodoProvider provider,
  ) {
    final showAds =
        _isInitialized && _bannerManager != null && !_bannerManager!.isDisposed;

    final bannerIndices = showAds
        ? _generateBannerIndices(todos.length, _indices)
        : <int>[];

    final itemCount = todos.length + bannerIndices.length;

    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      itemCount: itemCount,
      padding: const EdgeInsets.symmetric(vertical: 6),
      key: const PageStorageKey('todo_list'),
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

        int todoIndex = index - bannerIndices.where((i) => i < index).length;

        if (todoIndex >= todos.length) return const SizedBox.shrink();

        final todo = todos[todoIndex];

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: TodoListItem(
            key: ValueKey(todo.id),
            todo: todo,
            onTap: () => _navigateToEditTodo(context, todo),
            onToggle: () => provider.toggleTodoCompletion(todo.id),
            onDelete: () => _showDeleteDialog(context, todo.id),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(
    ColorScheme cs,
    TextTheme tt,
    TodoProvider provider,
    double iconWidth,
    double iconHeight,
    double sortIconWidth,
    double sortIconHeight,
  ) {
    return TextField(
      controller: _searchController,
      style: tt.titleMedium,
      decoration: InputDecoration(
        hintText: 'Search todos...',
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
                    provider.clearSearch();
                  },
                )
              : GestureDetector(
                  key: const ValueKey('sort'),
                  onTap: () => _showSortMenu(context, tt, provider),
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
      onChanged: (v) {
        setState(() => _searchQuery = v.trim().toLowerCase());
        provider.setSearchQuery(v);
      },
    );
  }

  void _showSortMenu(
    BuildContext context,
    TextTheme tt,
    TodoProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                'Sort By',
                style: tt.titleMedium!.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSortOption(
                      tt,
                      provider,
                      'Created Date (Newest First)',
                      TodoSortBy.createdDate,
                      SortOrder.descending,
                      Icons.date_range,
                    ),
                    _buildSortOption(
                      tt,
                      provider,
                      'Created Date (Oldest First)',
                      TodoSortBy.createdDate,
                      SortOrder.ascending,
                      Icons.date_range,
                    ),
                    _buildSortOption(
                      tt,
                      provider,
                      'Due Date (Nearest First)',
                      TodoSortBy.dueDate,
                      SortOrder.ascending,
                      Icons.event,
                    ),
                    _buildSortOption(
                      tt,
                      provider,
                      'Due Date (Farthest First)',
                      TodoSortBy.dueDate,
                      SortOrder.descending,
                      Icons.event,
                    ),
                    _buildSortOption(
                      tt,
                      provider,
                      'Priority (High to Low)',
                      TodoSortBy.priority,
                      SortOrder.descending,
                      Icons.flag,
                    ),
                    _buildSortOption(
                      tt,
                      provider,
                      'Priority (Low to High)',
                      TodoSortBy.priority,
                      SortOrder.ascending,
                      Icons.flag,
                    ),
                    _buildSortOption(
                      tt,
                      provider,
                      'Title (A-Z)',
                      TodoSortBy.title,
                      SortOrder.ascending,
                      Icons.title,
                    ),
                    _buildSortOption(
                      tt,
                      provider,
                      'Title (Z-A)',
                      TodoSortBy.title,
                      SortOrder.descending,
                      Icons.title,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Now updates TodoProvider directly
  Widget _buildSortOption(
    TextTheme tt,
    TodoProvider provider,
    String label,
    TodoSortBy sortBy,
    SortOrder sortOrder,
    IconData icon,
  ) {
    final isSelected =
        provider.sortBy == sortBy && provider.sortOrder == sortOrder;

    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: tt.bodyLarge),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        // ✅ Update provider's sort state
        provider.setSortBy(sortBy);

        // ✅ If clicking same sortBy, toggle order
        if (provider.sortBy == sortBy && provider.sortOrder != sortOrder) {
          provider.setSortBy(sortBy); // This toggles the order
        }

        // ✅ Save to SharedPreferences
        _saveSortPreferences(sortBy, sortOrder);

        Navigator.pop(context);
      },
    );
  }

  // ✅ FIXED: Load and apply to provider
  Future<void> _loadSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final sortByString = prefs.getString('todo_sort_by') ?? 'createdDate';
      final sortOrderString =
          prefs.getString('todo_sort_order') ?? 'descending';

      // Convert strings back to enums
      final sortBy = TodoSortBy.values.firstWhere(
        (e) => e.toString().split('.').last == sortByString,
        orElse: () => TodoSortBy.createdDate,
      );

      final sortOrder = sortOrderString == 'ascending'
          ? SortOrder.ascending
          : SortOrder.descending;

      // ✅ Apply to provider
      final provider = context.read<TodoProvider>();
      provider.setSortBy(sortBy);

      // Toggle again if needed to get correct order
      if (provider.sortOrder != sortOrder) {
        provider.setSortBy(sortBy);
      }
    }
  }

  // ✅ FIXED: Save using enum names
  Future<void> _saveSortPreferences(
    TodoSortBy sortBy,
    SortOrder sortOrder,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('todo_sort_by', sortBy.toString().split('.').last);
    await prefs.setString(
      'todo_sort_order',
      sortOrder == SortOrder.ascending ? 'ascending' : 'descending',
    );
  }

  Future<void> _navigateToEditTodo(BuildContext context, Todo todo) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditTodoScreen(todo: todo),
    );
  }

  void _showDeleteDialog(BuildContext context, String todoId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Todo'),
        content: const Text('Are you sure you want to delete this todo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TodoProvider>().deleteTodo(todoId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
