import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/models/dialog/delete_dialog.dart';
import 'package:tasktracker/widget/custom_container.dart';
import 'package:tasktracker/widget/loading_skeleton.dart';
import 'package:tasktracker/helper%20class/note_helper_class.dart';
import '../../models/note view/custom_notes_list_tile.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/note/db/notes_models.dart';
import '../../service/note/provider/notes_provider.dart';
import '../../helper class/size_helper_class.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_aware_interstitial_manager ·.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../widget/custom_snack_bar.dart';
import '../secondary/note_add_or_edit_screen.dart';
import '../secondary/note_view_screen.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with TickerProviderStateMixin {
  final Set<int> _selectedIndices = {};
  bool _selectionMode = false;
  final int _indices = 2;

  TabController? _tabController;
  List<RefreshController> _controllers = [];

  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();
      final noteProvider = context.read<NoteProvider>();
      final noteCount = noteProvider.notes.length;

      // Generate banner indices (banner every 2 notes)
      final indices = _generateBannerIndices(noteCount, _indices);

      setState(() {

        // Initialize banner manager
        _bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: indices,
          admobId: "ca-app-pub-7237142331361857/5431458486",
          metaId: "1916722012533263_1916773885861409",
          unityPlacementId: 'Banner_Android',
        );

        _isInitialized = true;
      });

      debugPrint('[NotesScreen] Initialized with $noteCount notes, ${indices.length} banner positions');
    });
  }

  List<int> _generateBannerIndices(int itemCount, int step) {
    List<int> indices = [];
    if (itemCount == 0) return indices;

    int index = step; // First banner after 'step' items
    while (index < itemCount + indices.length) {
      indices.add(index);
      index += step + 1; // +1 because banner occupies a slot
    }

    return indices;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    for (var c in _controllers) {
      c.dispose();
    }
    _bannerManager?.dispose();
    super.dispose();
  }

  void _initControllers(int length) {
    if (_controllers.length != length) {
      for (var c in _controllers) {
        c.dispose();
      }
      _controllers = List.generate(length, (_) => RefreshController());
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
    return Consumer<NoteProvider>(
      builder: (context, provider, _) {
        final categories = _categories(provider);

        // init controllers & tabs safely
        _initControllers(categories.length);
        if (_tabController == null ||
            _tabController!.length != categories.length) {
          final prevIndex = _tabController?.index ?? 0;
          _tabController?.dispose();
          _tabController = TabController(
            length: categories.length,
            vsync: this,
          );
          if (prevIndex < categories.length) _tabController!.index = prevIndex;
        }

        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final appBarIconHeight = SizeHelperClass.noteAddAppIconHeight(context);
        final appBarIconWidth = SizeHelperClass.noteAddAppIconWidth(context);
        final lIconContainerWidth = SizeHelperClass.listIconContainerWidth(
          context,
        );
        final lIconContainerHeight = SizeHelperClass.listIconContainerHeight(
          context,
        );

        final scale = _scale(context);
        double listIconContainerHeight = (lIconContainerHeight * scale).clamp(
          45,
          112,
        );
        double listIconContainerWidth = (lIconContainerWidth * scale).clamp(
          18,
          330,
        );

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            title: _selectionMode
                ? Text(
              '${_selectedIndices.length} selected',
              style: tt.displaySmall,
            )
                : Text('Notes', style: tt.displaySmall),
            leading: _selectionMode
                ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelSelection,
            )
                : null,
            actions: _selectionMode
                ? [
              IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/trash.svg',
                  height: appBarIconHeight - 7,
                  width: appBarIconWidth - 8,
                  colorFilter: const ColorFilter.mode(
                    Colors.redAccent,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: _deleteSelected,
              ),
            ]
                : null,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.blue,
              labelStyle: tt.titleMedium,
              unselectedLabelColor: cs.onSurface.withOpacity(0.6),
              tabs: categories.map((c) => Tab(text: c)).toList(),
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(categories.length, (i) {
                final cat = categories[i];
                final visible = _visibleNotesFor(cat, provider);

                if (visible.isEmpty) {
                  return const Center(child: Text('No notes in this category'));
                }

                return SmartRefresher(
                  controller: _controllers[i],
                  onRefresh: _onRefresh,
                  header: const MaterialClassicHeader(),
                  child: provider.isLoading
                      ? LoadingSkeleton(
                    loadingSkeletonItemCount: visible.length,
                  )
                      : _buildNoteList(
                    visible,
                    cs,
                    listIconContainerHeight,
                    listIconContainerWidth,
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoteList(
      List<NoteModels> notes,
      ColorScheme colorScheme,
      double iconHeight,
      double iconWidth,
      ) {

    final showAds = _isInitialized &&
        _bannerManager != null &&
        !_bannerManager!.isDisposed;

    final bannerIndices = showAds ? _bannerManager!.getAvailableSources().isNotEmpty
        ? _generateBannerIndices(notes.length, _indices)
        : <int>[]
        : <int>[];

    final itemCount = notes.length + bannerIndices.length;

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      physics: const AlwaysScrollableScrollPhysics(),
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
          child: GestureDetector(
            onLongPress: () => _onLongPress(noteIndex),
            onTap: () => _onTap(noteIndex, notes),
            child: CustomNotesListTile(
              title: note.title.isEmpty ? 'Untitled' : note.title,
              subtitle: note.content.isEmpty ? 'No details' : note.content,
              menuTitles: ['Edit', 'Delete', note.pinned ? 'Unpin' : 'Pin'],
              menuCallbacks: [
                    () async {
                  final edited = await Navigator.push<NoteModels>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteAddOrEditScreen(note: note),
                    ),
                  );
                  if (edited != null) {
                    await Provider.of<NoteProvider>(
                      context,
                      listen: false,
                    ).updateNote(edited);
                  }
                },
                    () async {
                  if (note.id != null) {
                    await NoteHelperClass.deleteNote(context, note);
                  }
                },
                    () async {
                  final updated = note.copyWith(pinned: !note.pinned);
                  await Provider.of<NoteProvider>(
                    context,
                    listen: false,
                  ).updateNote(updated);
                },
              ],
              showAvatar: !_selectionMode,
              leadingWidget: _selectionMode
                  ? CustomContainer(
                height: iconHeight,
                width: iconWidth,
                color: Colors.transparent,
                outlineColor: colorScheme.outline,
                circularRadius: 8,
                child: Icon(
                  _selectedIndices.contains(noteIndex)
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: Colors.blue,
                ),
              )
                  : null,
              borderColor: NoteHelperClass.priorityColor(note, colorScheme),
            ),
          ),
        );
      },
    );
  }

  void _onLongPress(int index) => _toggleSelection(index);

  Future<void> _onTap(int index, List<NoteModels> visible) async {
    if (_selectionMode) {
      _toggleSelection(index);
      return;
    }

    final note = visible[index];
    final provider = Provider.of<NoteProvider>(context, listen: false);

    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteViewScreen(note: note),
    );

    if (result is NoteModels) await provider.updateNote(result);
    if (result == 'DELETE' && note.id != null) {
      await provider.deleteNote(note.id!);
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Note deleted successfully!',
          type: SnackBarType.success,
        );
      }
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _selectionMode = false;
      } else {
        _selectedIndices.add(index);
        _selectionMode = true;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _deleteSelected() async {
    final provider = Provider.of<NoteProvider>(context, listen: false);
    final visible = _visibleNotesFor(_currentCategory(), provider);

    final toDelete = _selectedIndices.map((i) => visible[i]).toList();

    // Show confirm dialog before deleting
    final confirm = await deleteDialog(
      context: context,
      title: "Delete Selected?",
      message:
      "Delete ${toDelete.length} note${toDelete.length > 1 ? 's' : ''}? This action cannot be undone.",
      confirmText: "Delete",
    );

    if (confirm != true) return;

    for (final note in toDelete) {
      if (note.id != null) {
        provider.deleteNote(note.id!);
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Note deleted successfully!',
            type: SnackBarType.success,
          );
        }
      }
    }

    _cancelSelection();
  }

  String _currentCategory() {
    final provider = Provider.of<NoteProvider>(context, listen: false);
    final cats = _categories(provider);
    final index = _tabController?.index ?? 0;
    return index < cats.length ? cats[index] : 'All';
  }

  List<NoteModels> _visibleNotesFor(String category, NoteProvider provider) {
    final List<NoteModels> list = category == 'All'
        ? List<NoteModels>.from(provider.notes)
        : provider.notes
        .where((n) => n.category == category)
        .cast<NoteModels>()
        .toList();

    list.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.localNoteDateTime.compareTo(a.localNoteDateTime);
    });

    return list;
  }

  List<String> _categories(NoteProvider provider) {
    final Set<String> set = {'All'};

    for (final NoteModels n in provider.notes) {
      if (n.category.isNotEmpty && n.category != 'Uncategorized') {
        set.add(n.category);
      }
    }

    final List<String> list = set.toList()..sort();
    return list;
  }

  Future<void> _onRefresh() async {
    if (_tabController == null) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);
    final currentIndex = _tabController!.index;

    await provider.loadNotes();

    if (mounted && currentIndex < _controllers.length) {
      _controllers[currentIndex].refreshCompleted();
      setState(() {});
    }
  }
}