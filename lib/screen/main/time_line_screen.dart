import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/timeline/all_task_screen.dart';
import '../../models/timeline/completed_task_screen.dart';
import '../../models/timeline/in_process_screen.dart';
import '../../models/timeline/today_tasks_screen.dart';
import '../../screen/main/todo_screen.dart';
import '../../service/bottomnav/bottom_provider.dart';

class TimeLineScreen extends StatefulWidget {
  const TimeLineScreen({super.key});

  @override
  State<TimeLineScreen> createState() => _TimeLineScreenState();
}

class _TimeLineScreenState extends State<TimeLineScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final List<String> tabs = [
    "Tasks",
    "Todo",
    "Today Tasks",
    "In Process",
    "Completed",
  ];

  final List<Widget> screens = [
    const AllTasksScreen(key: ValueKey('Tasks')),
    const TodoScreen(key: ValueKey('Todo')),
    const TodayTasksScreen(key: ValueKey('TodayTasks')),
    const InProcessScreen(key: ValueKey('InProcess')),
    const CompletedScreen(key: ValueKey('Completed')),
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: tabs.length,
      vsync: this,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;

      // Optional: notify provider when user swipes tabs
      context.read<BottomNavProvider>().acknowledgeTimelineChange();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleProviderTabChange();
  }

  void _handleProviderTabChange() {
    final provider = context.read<BottomNavProvider>();

    if (provider.shouldChangeTimelineTab &&
        provider.timelineTabIndex != null) {
      final index = provider.timelineTabIndex!;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _tabController.animateTo(index);
        provider.acknowledgeTimelineChange();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Consumer<BottomNavProvider>(
      builder: (context, provider, _) {
        if (provider.shouldChangeTimelineTab &&
            provider.timelineTabIndex != null &&
            provider.timelineTabIndex != _tabController.index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _tabController.animateTo(provider.timelineTabIndex!);
            provider.acknowledgeTimelineChange();
          });
        }

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            title: Text("Timeline", style: textTheme.displaySmall),
            backgroundColor: cs.surface,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.blue,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withOpacity(0.6),
              labelStyle: textTheme.titleMedium,
              tabs: tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: screens,
          ),
        );
      },
    );
  }
}
