import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tasktracker/models/todo/todo_loading_skeleton.dart';
import 'package:tasktracker/widget/home_screen_container.dart';
import '../../screen/secondary/todo_add_and_edit_screen.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/bottomnav/bottom_provider.dart';
import '../../service/todo/db/todo_model.dart';
import '../../service/todo/provider/todo_provider.dart';
import '../../widget/emptystate/empty_home_container.dart';
import '../../models/todo/todo_list_item.dart';

/// TodoList Widget - Production Ready
///
/// Displays user's incomplete todos with integrated banner ads
/// - Shows todos sorted by priority (today's tasks first)
/// - Displays banner ads every N todos (configurable)
/// - Respects user subscription status
/// - Handles ad loading failures gracefully
class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  // Ad configuration
  static const String _adUnitId = 'ca-app-pub-7237142331361857/3881028501';
  static const int _adFrequency = 3; // Show ad every 3 todos

  // Ad state management
  final Map<int, BannerAd> _bannerAds = {};
  final Map<int, bool> _adLoadStatus = {};
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Load todos first
      await Provider.of<TodoProvider>(context, listen: false).loadTodos();

      // Initialize ads after todos are loaded
      _initializeAds();
    });
  }

  /// Initialize banner ads based on todo count
  void _initializeAds() {
    if (!mounted || _disposed) return;

    final subscriptionProvider = context.read<SubscriptionProvider>();

    // Don't load ads if user is subscribed
    if (subscriptionProvider.isSubscribed) {
      debugPrint('[TodoList] User subscribed - skipping ads');
      return;
    }

    final todoProvider = context.read<TodoProvider>();
    final incompleteTodos = todoProvider.todos
        .where((todo) => !todo.isCompleted)
        .length;

    // Calculate ad positions
    final adIndices = _calculateAdPositions(incompleteTodos);

    debugPrint('[TodoList] Initializing ${adIndices.length} banner ads');

    // Load ads for each position
    for (final index in adIndices) {
      _loadBannerAd(index);
    }
  }

  /// Calculate positions where ads should appear
  /// Returns list of indices in the todo list where ads will be inserted
  List<int> _calculateAdPositions(int todoCount) {
    if (todoCount < _adFrequency) return [];

    final List<int> positions = [];
    int position = _adFrequency;

    while (position < todoCount + positions.length) {
      positions.add(position);
      position += _adFrequency + 1; // +1 because ad takes a slot
    }

    return positions;
  }

  /// Load a banner ad for a specific position
  void _loadBannerAd(int index) {
    if (_disposed) return;

    // Dispose existing ad if any
    _bannerAds[index]?.dispose();
    _adLoadStatus[index] = false;

    final ad = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }

          debugPrint('[TodoList] ✅ Banner ad loaded at index $index');

          if (mounted) {
            setState(() {
              _bannerAds[index] = ad as BannerAd;
              _adLoadStatus[index] = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[TodoList] ❌ Banner ad failed at index $index: ${error.message}');
          ad.dispose();

          if (mounted) {
            setState(() {
              _adLoadStatus[index] = false;
            });
          }
        },
        onAdOpened: (ad) {
          debugPrint('[TodoList] Banner ad opened at index $index');
        },
        onAdClosed: (ad) {
          debugPrint('[TodoList] Banner ad closed at index $index');
        },
      ),
    );

    ad.load();
  }

  @override
  void dispose() {
    _disposed = true;

    // Dispose all banner ads
    for (final ad in _bannerAds.values) {
      ad.dispose();
    }
    _bannerAds.clear();
    _adLoadStatus.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoProvider>(
      builder: (context, provider, _) {
        final now = DateTime.now();

        // Get and sort incomplete todos
        final allIncompleteTodos = provider.todos
            .where((todo) => !todo.isCompleted)
            .toList()
          ..sort((a, b) {
            // Check if each todo is due today
            final aIsToday = a.dueDate != null &&
                a.dueDate!.year == now.year &&
                a.dueDate!.month == now.month &&
                a.dueDate!.day == now.day;

            final bIsToday = b.dueDate != null &&
                b.dueDate!.year == now.year &&
                b.dueDate!.month == now.month &&
                b.dueDate!.day == now.day;

            // Today's todos come first
            if (aIsToday && !bIsToday) return -1;
            if (!aIsToday && bIsToday) return 1;

            // Sort by priority
            if (a.priority != b.priority) {
              return b.priority.compareTo(a.priority);
            }

            // Sort by due date
            if (a.dueDate != null && b.dueDate != null) {
              return a.dueDate!.compareTo(b.dueDate!);
            }

            // Todos with due dates come first
            if (a.dueDate != null && b.dueDate == null) return -1;
            if (a.dueDate == null && b.dueDate != null) return 1;

            return 0;
          });

        // Empty state
        if (allIncompleteTodos.isEmpty) {
          return HomeScreenContainer(
            title: 'Todo',
            onTap: () => context.read<BottomNavProvider>().changeTab(1),
            child: Center(
              child: EmptyHomeContainer(
                title: 'No todo',
                subText: 'Add new todo',
              ),
            ),
          );
        }

        // Loading state
        if (provider.isLoading) {
          return HomeScreenContainer(
            title: 'Todo',
            onTap: () => context.read<BottomNavProvider>().changeTab(1),
            child: TodoLoadingSkeleton(
              loadingSkeletonItemCount: allIncompleteTodos.length,
            ),
          );
        }

        // Main content
        return HomeScreenContainer(
          title: 'Todo',
          onTap: () => context.read<BottomNavProvider>().changeTab(1),
          child: _buildTodoList(allIncompleteTodos, provider),
        );
      },
    );
  }

  /// Build the todo list with integrated banner ads
  Widget _buildTodoList(List<Todo> todos, TodoProvider provider) {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final showAds = !subscriptionProvider.isSubscribed;

    final adPositions = showAds
        ? _calculateAdPositions(todos.length)
        : <int>[];

    final List<Widget> items = [];
    int todoIndex = 0;
    int listIndex = 0;

    // Build list with todos and ads interspersed
    while (todoIndex < todos.length) {
      // Check if we should insert an ad at this position
      if (showAds && adPositions.contains(listIndex)) {
        final adWidget = _buildBannerAdWidget(listIndex);
        if (adWidget != null) {
          items.add(adWidget);
        }
        listIndex++;
        continue;
      }

      // Add todo item
      items.add(_buildTodoItem(todos[todoIndex], provider));
      todoIndex++;
      listIndex++;
    }

    // Check for remaining ads after all todos
    while (showAds && adPositions.contains(listIndex)) {
      final adWidget = _buildBannerAdWidget(listIndex);
      if (adWidget != null) {
        items.add(adWidget);
      }
      listIndex++;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  /// Build a banner ad widget for a specific position
  /// Returns null if ad is not loaded
  Widget? _buildBannerAdWidget(int index) {
    final isLoaded = _adLoadStatus[index] ?? false;
    final ad = _bannerAds[index];

    if (!isLoaded || ad == null) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }

  /// Build a single todo item widget
  Widget _buildTodoItem(Todo todo, TodoProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TodoListItem(
        key: ValueKey(todo.id),
        todo: todo,
        onTap: () => _navigateToEditTodo(context, todo),
        onToggle: () => provider.toggleTodoCompletion(todo.id),
        onDelete: () => _showDeleteDialog(context, todo.id, provider),
      ),
    );
  }

  /// Navigate to edit todo screen
  Future<void> _navigateToEditTodo(BuildContext context, Todo todo) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditTodoScreen(todo: todo),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteDialog(
      BuildContext context,
      String todoId,
      TodoProvider provider,
      ) {
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
              provider.deleteTodo(todoId);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}