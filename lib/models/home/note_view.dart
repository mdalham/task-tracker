import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/models/note%20view/custom_notes_list_tile.dart';
import 'package:tasktracker/widget/empty_state.dart';
import '../../helper class/note_helper_class.dart';
import '../../screen/secondary/note_add_or_edit_screen.dart';
import '../../screen/secondary/note_view_screen.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_aware_interstitial_manager ·.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/bottomnav/bottom_provider.dart';
import '../../service/note/db/notes_models.dart';
import '../../service/note/provider/notes_provider.dart';
import '../../widget/loading_skeleton.dart';
import '../../helper class/size_helper_class.dart';

class NoteView extends StatefulWidget {
  const NoteView({super.key});

  @override
  State<NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<NoteView>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late final AnimationController _arrowController;

  // Use subscription-aware managers
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
        final noteProvider = context.read<NoteProvider>();
        final notes = noteProvider.notes;

        // Generate banner indices (banner every 2 notes)
        final indices = _generateBannerIndices(notes.length, _indices);

        setState(() {
           // ✅ Initialize banner manager
          if (indices.isNotEmpty) {
            _bannerManager = SubscriptionAwareBannerManager(
              subscriptionProvider: subscriptionProvider,
              indices: indices,
              admobId: "ca-app-pub-7237142331361857/5431458486",
              metaId: "1916722012533263_1916773885861409",
              unityPlacementId: 'Banner_Android',
            );
          }

          _isInitialized = true;
        });

        debugPrint(
          '[NoteView] Initialized: '
              'Interstitial ready, '
              'Banners: ${indices.length} positions',
        );
      }
    });
  }

  // ✅ Helper method to generate banner indices
  List<int> _generateBannerIndices(int noteCount, int step) {
    List<int> indices = [];
    if (noteCount == 0) return indices;

    int index = step; // First banner after 'step' notes
    while (index < noteCount + indices.length) {
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

  void _handleMenuAction(String action, NoteModels note) async {
    final provider = Provider.of<NoteProvider>(context, listen: false);

    if (action == 'Edit') {
      final result = await Navigator.push<NoteModels>(
        context,
        MaterialPageRoute(builder: (_) => NoteAddOrEditScreen(note: note)),
      );
      if (result != null) {
        await provider.updateNote(result);
      }
    } else if (action == 'Delete') {
      if (note.id != null) {
        NoteHelperClass.deleteNote(context, note);
      }
    }
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
    final provider = Provider.of<NoteProvider>(context);
    final notes = provider.notes;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final double sHeight = SizeHelperClass.homeConSHeight(context);
    final double eHeight = SizeHelperClass.homeConEHeight(context);

    final scale = _scale(context);
    double shrinkHeight = (sHeight * scale).clamp(112, 125);
    double expendedHeight = (eHeight * scale).clamp(335, 370);

    if (notes.isEmpty) {
      return EmptyState(title: 'No notes created yet!');
    }

    if (provider.isLoading) {
      return LoadingSkeleton(
        loadingSkeletonItemCount: isExpanded ? notes.length : 1,
      );
    }

    final displayNotes = isExpanded ? notes : notes.take(1).toList();
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
              color: colorScheme.onPrimaryContainer,
              border: Border.all(color: colorScheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
                top: 30,
                bottom: 10,
              ),
              child: _buildNoteList(displayNotes, colorScheme),
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 7,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.read<BottomNavProvider>().changeTab(2),
                child: Text(
                  'View more',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.blue),
                ),
              ),
              const SizedBox(width: 5),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: toggleExpand,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 26,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteList(
      List<NoteModels> notes,
      ColorScheme colorScheme,
      ) {
    // ✅ FIXED: Proper null safety checks
    final showAds = _isInitialized &&
        _bannerManager != null &&
        !_bannerManager!.isDisposed;

    final bannerIndices = showAds
        ? _generateBannerIndices(notes.length, _indices)
        : <int>[];

    final itemCount = notes.length + bannerIndices.length;

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

        // Calculate actual note index
        int noteIndex = index - bannerIndices.where((i) => i < index).length;

        if (noteIndex >= notes.length) return const SizedBox.shrink();

        final note = notes[noteIndex];

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildNoteTile(note, colorScheme),
        );
      },
    );
  }

  Widget _buildNoteTile(NoteModels note, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => NoteViewScreen(note: note),
        );
      },
      child: CustomNotesListTile(
        title: note.title.isEmpty ? 'Untitled' : note.title,
        subtitle: note.content.isEmpty ? 'No details' : note.content,
        menuTitles: const ['Edit', 'Delete'],
        menuCallbacks: [
              () => _handleMenuAction('Edit', note),
              () => _handleMenuAction('Delete', note),
        ],
        borderColor: NoteHelperClass.priorityColor(note, colorScheme),
      ),
    );
  }
}