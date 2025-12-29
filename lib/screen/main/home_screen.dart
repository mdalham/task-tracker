import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/models/home/custom_appbar.dart';
import 'package:tasktracker/models/home/day_list.dart';
import 'package:tasktracker/models/home/note_view.dart';
import 'package:tasktracker/models/home/progress_card_view.dart';
import 'package:tasktracker/models/home/todo_list.dart';
import '../../models/home/completed_tasks.dart';
import '../../models/home/project.dart';
import '../../models/home/today_task.dart';
import '../../service/ads/native_ad_widget.dart';
import '../../service/subscription/nativ_ad_manager.dart';
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
  SubscriptionAwareNativeAdManager? _nativeAdManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBannerManager();
      _initializeNativeAds();
    });
  }

  void _initializeBannerManager() {
    if (!mounted) return;

    final provider = context.read<SubscriptionProvider>();
    setState(() {
      bannerManager = SubscriptionAwareBannerManager(
        subscriptionProvider: provider,
        indices: [0, 1],
        admobId: "ca-app-pub-7237142331361857/1563378585",
        metaId: "1916722012533263_1916773885861409",
        unityPlacementId: 'Banner_Android',
      );
    });
    debugPrint('[HomeScreen] Banner manager initialized');
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
      _isInitialized = true;
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

  @override
  void dispose() {
    bannerManager?.dispose();
    _nativeAdManager?.dispose();
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
    final TextTheme textTheme = Theme.of(context).textTheme;

    final media = MediaQuery.of(context).size;
    final scale = _scale(context);
    double bottomPadding = (media.height * 0.15 * scale).clamp(50, 90);

    // ✅ Safety check - show loading while initializing
    if (bannerManager == null || !_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: const CustomAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimationWidget(
                  start: 0.0,
                  end: 0.4,
                  child: ProgressCardView(onOpen: () {}),
                ),
                const SizedBox(height: 10),

                // Horizontal scrolling section
                Scrollbar(
                  thickness: 4,
                  radius: const Radius.circular(10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const TodayTask(),
                        const SizedBox(width: 10),
                        const TodoList(),
                        const SizedBox(width: 10),
                        if (_nativeAdManager!.isReady)
                          NativeAdWidget(
                            adManager: _nativeAdManager!,
                            height: 360,
                            width: 290,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        if (_nativeAdManager!.isReady)
                          const SizedBox(width: 10),
                        const DayList(),
                        const SizedBox(width: 10),
                        const Project(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Notes section
                AnimationWidget(
                  start: 0.3,
                  end: 0.7,
                  child: Text('Notes', style: textTheme.titleLarge),
                ),
                const SizedBox(height: 5),
                AnimationWidget(start: 0.4, end: 0.8, child: const NoteView()),
                const SizedBox(height: 10),

                // Banner Ad 2
                ValueListenableBuilder<bool>(
                  valueListenable: bannerManager!.bannerReady(0),
                  builder: (_, isReady, __) {
                    if (!isReady) return const SizedBox.shrink();
                    return bannerManager!.getBannerWidget(0);
                  },
                ),
                const SizedBox(height: 10),

                // Completed tasks section
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
                const SizedBox(height: 10),

                // Banner Ad 3
                ValueListenableBuilder<bool>(
                  valueListenable: bannerManager!.bannerReady(1),
                  builder: (_, isReady, __) {
                    if (!isReady) return const SizedBox.shrink();
                    return bannerManager!.getBannerWidget(1);
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
