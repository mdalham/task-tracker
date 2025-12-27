import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/models/home/custom_appbar.dart';
import 'package:tasktracker/models/home/note_view.dart';
import 'package:tasktracker/models/home/progress_card_view.dart';
import '../../models/home/completed_tasks.dart';
import '../../models/home/today_tasks.dart';
import '../../service/ads/banner/banner_ads.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/task/provider/task_provider.dart';
import '../../widget/animated_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SubscriptionAwareBannerManager? bannerManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ ALTERNATIVE: Initialize here instead of initState
    // This runs after context is fully available
    if (bannerManager == null) {
      final provider = context.read<SubscriptionProvider>();

      bannerManager = SubscriptionAwareBannerManager(
        subscriptionProvider: provider,
        indices: [0, 1, 2],
        admobId: "ca-app-pub-7237142331361857/1563378585",
        metaId: "1916722012533263_1916773885861409",
        unityPlacementId: 'Banner_Android',
      );
    }
  }

  @override
  void dispose() {
    bannerManager?.dispose();
    super.dispose();
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final media = MediaQuery.of(context).size;
    final scale = _scale(context);
    double bottomPadding = (media.height * 0.15 * scale).clamp(50, 90);

    final todayTasks = Provider.of<TaskProvider>(context, listen: false).todayTasks;

    // ✅ Safety check
    if (bannerManager == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimationWidget(
                  start: 0.0,
                  end: 0.4,
                  child: ProgressCardView(onOpen: () {}),
                ),
                const SizedBox(height: 10),

                // ✅ Now safe to use with !
                ValueListenableBuilder<bool>(
                  valueListenable: bannerManager!.bannerReady(0),
                  builder: (_, isReady, __) {
                    if (!isReady) return const SizedBox.shrink();
                    return bannerManager!.getBannerWidget(0);
                  },
                ),

                if (todayTasks.isNotEmpty) ...[
                  AnimationWidget(
                    start: 0.1,
                    end: 0.5,
                    child: Text(
                      'Today tasks',
                      style: textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimationWidget(
                    start: 0.2,
                    end: 0.6,
                    child: const TodayTasks(),
                  ),
                ],
                const SizedBox(height: 10),

                AnimationWidget(
                  start: 0.3,
                  end: 0.7,
                  child: Text('Notes', style: textTheme.titleLarge),
                ),
                const SizedBox(height: 5),
                AnimationWidget(start: 0.4, end: 0.8, child: const NoteView()),
                const SizedBox(height: 10),

                ValueListenableBuilder<bool>(
                  valueListenable: bannerManager!.bannerReady(1),
                  builder: (_, isReady, __) {
                    if (!isReady) return const SizedBox.shrink();
                    return bannerManager!.getBannerWidget(1);
                  },
                ),

                AnimationWidget(
                  start: 0.5,
                  end: 0.9,
                  child: Text('Completed tasks', style: textTheme.titleLarge),
                ),
                const SizedBox(height: 5),
                AnimationWidget(
                  start: 0.6,
                  end: 1,
                  child: const CompletedTasks(),
                ),

                ValueListenableBuilder<bool>(
                  valueListenable: bannerManager!.bannerReady(2),
                  builder: (_, isReady, __) {
                    if (!isReady) return const SizedBox.shrink();
                    return bannerManager!.getBannerWidget(2);
                  },
                ),

                SizedBox(height: bottomPadding),
              ],
            ),
          ),
        ),
      ),
    );
  }
}