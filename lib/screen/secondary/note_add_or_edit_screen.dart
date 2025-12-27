import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';
import '../../models/add note/audio_player_widget.dart';
import '../../models/add note/check_list_note_widget.dart';
import '../../models/add note/custom_note_menu.dart';
import '../../models/add note/custom_note_menu_popup.dart';
import '../../models/add note/feature_action_menu.dart';
import '../../models/add note/multi_image_grid.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_aware_interstitial_manager ·.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../widget/category_item.dart';
import '../../service/note/db/notes_models.dart';
import '../../service/note/provider/notes_provider.dart';
import '../../widget/custom_container.dart';
import '../../widget/custom_snack_bar.dart';
import 'image_view_screen.dart';

class NoteAddOrEditScreen extends StatefulWidget {
  final NoteModels? note;
  const NoteAddOrEditScreen({super.key, this.note});

  @override
  State<NoteAddOrEditScreen> createState() => _NoteAddOrEditScreenState();
}

class _NoteAddOrEditScreenState extends State<NoteAddOrEditScreen>
    with SingleTickerProviderStateMixin {

  // ✅ Subscription-aware ad managers
  SubscriptionAwareBannerManager? _bannerManager;
  SubscriptionAwareInterstitialManager? _interstitialManager;
  bool _adsInitialized = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  // UI state
  double _contentFontSize = 16;
  TextAlign _textAlign = TextAlign.left;
  bool _isContentExpanded = false;
  late final AnimationController _arrowController;

  bool _isInitialized = false;

  // Undo / Redo
  final List<String> _titleHistory = [];
  final List<String> _contentHistory = [];
  int _titleIndex = -1;
  int _contentIndex = -1;
  bool _isPerformingUndoRedo = false;
  TextEditingController? _lastFocusedController;

  // Media
  final List<File> _images = [];
  final List<File> _audios = [];

  // Note data
  late NoteModels _noteData;
  DateTime? _createdAtLocal;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // ✅ Initialize subscription-aware ad managers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        // Banner manager
        _bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: [0, 1],
          admobId: "ca-app-pub-7237142331361857/4580424162",
          metaId: "1916722012533263_1916773885861409",
          unityPlacementId: 'Banner_Android',
        );

        // Interstitial manager
        _interstitialManager = SubscriptionAwareInterstitialManager(
          subscriptionProvider: subscriptionProvider,
          admobPrimaryId: 'ca-app-pub-7237142331361857/2288769251',
          admobSecondaryId: 'ca-app-pub-7237142331361857/8653935503',
          metaInterstitialId: '1916722012533263_1916774079194723',
          unityInterstitialId: 'Interstitial_Android',
          tapThreshold: 1,
          maxRetry: 20,
        );

        _adsInitialized = true;
      });

      debugPrint('[NoteAddOrEditScreen] Ad managers initialized');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final provider = Provider.of<NoteProvider>(context, listen: false);
      _initNoteData(provider);
      _setupListeners();
      _isInitialized = true;
    }
  }

  void _initNoteData(NoteProvider provider) {
    if (widget.note != null) {
      final original = widget.note!;
      _noteData = original.copyWith(
        images: List.from(original.images),
        audios: List.from(original.audios),
        checklist: original.checklist
            .map((c) => ChecklistItem(title: c.title, isChecked: c.isChecked))
            .toList(),
      );
      _createdAtLocal = original.localCreatedAt;
      _textAlign = original.textAlignEnum;
      _contentFontSize = original.fontSize;

      debugPrint(
        'Edit: Loaded textAlign: $_textAlign, fontSize: $_contentFontSize',
      );
    } else {
      _noteData = NoteModels(
        noteDateTime: DateTime.now().toUtc(),
        checklist: [],
        textAlign: 'left',
        fontSize: 18.0,
      );
      _createdAtLocal = DateTime.now().toLocal();
    }

    _titleController.text = _noteData.title;
    _contentController.text = _noteData.content;
    _images.addAll(
      _noteData.images.map((p) => File(p)).where((f) => f.existsSync()),
    );
    _audios.addAll(
      _noteData.audios.map((p) => File(p)).where((f) => f.existsSync()),
    );
    _initUndoRedo();
  }

  void _setupListeners() {
    _titleFocusNode.addListener(() => setState(() {}));
    _contentFocusNode.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
    _contentController.addListener(() {
      setState(() {});
      _handleContentChange();
    });
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _interstitialManager?.dispose();
    _bannerManager?.dispose();
    super.dispose();
  }

  // ✅ Close with ad
  Future<void> _closeWithAd() async {
    _interstitialManager?.registerTap();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _discardAndPop() {
    if (mounted) Navigator.pop(context, 'DELETE');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final appBarIconHeight = SizeHelperClass.noteAddAppIconHeight(context);
    final appBarIconWidth = SizeHelperClass.noteAddAppIconWidth(context);
    final double conMinHeight = SizeHelperClass.conMinHeight(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.note != null ? 'Edit Note' : 'Add Note',
          style: textTheme.displaySmall,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface),
          onPressed: _closeWithAd, // ✅ Show ad on back button
        ),
        actions: [
          // Undo
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/undo-alt.svg',
              height: appBarIconHeight,
              width: appBarIconWidth,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            onPressed: undo,
          ),
          // Redo
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/redo-alt.svg',
              height: appBarIconHeight,
              width: appBarIconWidth,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            onPressed: redo,
          ),
          // Pin
          IconButton(
            icon: SvgPicture.asset(
              _noteData.pinned
                  ? 'assets/icons/thumbtack.svg'
                  : 'assets/icons/thumbtack _filled.svg',
              height: appBarIconHeight,
              width: appBarIconWidth,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => setState(
                  () => _noteData = _noteData.copyWith(pinned: !_noteData.pinned),
            ),
          ),
          // More menu
          GestureDetector(
            onTapDown: (details) {
              customNoteMenuPopup(
                context: context,
                position: details.globalPosition,
                colorScheme: colorScheme,
                left: 210,
                top: 10,
                builder: (close) => CustomNoteMenu(
                  onItemTap: close,
                  timestampController: _contentController,
                  noteData: _noteData,
                  onReminderChanged: (date) {
                    debugPrint('DEBUG: Reminder received in add screen: $date');
                    setState(
                          () => _noteData = _noteData.copyWith(reminder: date),
                    );
                  },
                  onPriorityChanged: (priority) {
                    setState(
                          () => _noteData = _noteData.copyWith(priority: priority),
                    );
                  },
                  onAddressChanged: (address) {
                    setState(
                          () => _noteData = _noteData.copyWith(address: address),
                    );
                  },
                  onDiscard: _discardAndPop,
                ),
              );
            },
            child: SvgPicture.asset(
              'assets/icons/menu-dots-vertical.svg',
              height: appBarIconHeight,
              width: appBarIconWidth,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      CategoryItem(
                        selectedCategory: _noteData.category,
                        onCategoryChanged: (cat) => setState(
                              () => _noteData = _noteData.copyWith(category: cat),
                        ),
                      ),

                      // Title + Content
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          border: Border.all(
                            color: (_titleFocusNode.hasFocus ||
                                _contentFocusNode.hasFocus)
                                ? Colors.blue
                                : colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        constraints: BoxConstraints(
                          minHeight: conMinHeight,
                          maxHeight: _isContentExpanded
                              ? MediaQuery.of(context).size.height * 0.7
                              : conMinHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTitleField(textTheme),
                            Divider(color: colorScheme.outline),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildContentField(
                                  colorScheme,
                                  textTheme,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ✅ Banner Ad 1
                  if (_adsInitialized && _bannerManager != null)
                    ValueListenableBuilder<bool>(
                      valueListenable: _bannerManager!.bannerReady(0),
                      builder: (_, isReady, __) {
                        if (!isReady) return const SizedBox.shrink();
                        return BannerAdContainerWidget(
                          index: 0,
                          bannerManager: _bannerManager!,
                        );
                      },
                    ),

                  CheckListNoteWidget(
                    initialItems: _noteData.checklist,
                    onChanged: (updatedList) {
                      setState(() {
                        _noteData = _noteData.copyWith(
                          checklist: updatedList,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Audio
                  if (_audios.isNotEmpty) ..._buildAudioWidgets(),
                  const SizedBox(height: 10),

                  // Images
                  if (_images.isNotEmpty)
                    MultiImageGrid(
                      images: _images,
                      onImageTap: (index) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ImageViewScreen(
                              images: _images,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      onRemove: (index) {
                        setState(() => _images.removeAt(index));
                      },
                    ),
                  const SizedBox(height: 10),

                  // Details
                  _notesDetails(colorScheme),

                  // ✅ Banner Ad 2
                  if (_adsInitialized && _bannerManager != null)
                    ValueListenableBuilder<bool>(
                      valueListenable: _bannerManager!.bannerReady(1),
                      builder: (_, isReady, __) {
                        if (!isReady) return const SizedBox.shrink();
                        return BannerAdContainerWidget(
                          index: 1,
                          bannerManager: _bannerManager!,
                        );
                      },
                    ),
                ],
              ),
            ),

            // Floating menu
            Positioned(
              top: 73,
              right: 20,
              child: FeatureActionMenu(
                onImagePicked: (image) => setState(() => _images.add(image)),
                onAudioRecorded: (audio) => setState(() => _audios.add(audio)),
                onTextAlignChanged: (align) =>
                    setState(() => _textAlign = align),
                onFontSizeChanged: (size) =>
                    setState(() => _contentFontSize = size),
                selectedFontSize: _contentFontSize,
                contentController: _contentController,
                contentFocusNode: _contentFocusNode,
              ),
            ),

            // SAVE BUTTON
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GestureDetector(
                  onTap: _isSaving ? null : _saveAndPop,
                  child: CustomContainer(
                    height: 56,
                    width: 56,
                    color: _isSaving
                        ? Colors.blue.withOpacity(0.6)
                        : Colors.blue,
                    circularRadius: 28,
                    outlineColor: colorScheme.outline,
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : SvgPicture.asset(
                        'assets/icons/check.svg',
                        height: 30,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // SAVE
  // ========================================================================

  Future<void> _saveAndPop() async {
    if (!mounted) return;
    final provider = Provider.of<NoteProvider>(context, listen: false);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Check your input!',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);

    _noteData = _noteData.copyWith(
      title: title,
      content: content,
      images: _images.map((f) => f.path).toList(),
      audios: _audios.map((f) => f.path).toList(),
      checklist: _noteData.checklist
          .where((item) => item.title.trim().isNotEmpty)
          .toList(),
      textAlign: NoteModels.textAlignToString(_textAlign),
      fontSize: _contentFontSize,
    );

    debugPrint(
      'Saving with textAlign: ${_noteData.textAlign}, fontSize: ${_noteData.fontSize}',
    );

    try {
      if (widget.note == null) {
        await provider.addNote(_noteData);

        // ✅ Show ad on save
        _interstitialManager?.registerTap();
        await Future.delayed(const Duration(milliseconds: 400));

        if (mounted) {
          Navigator.pop(context, _noteData);
          CustomSnackBar.show(
            context,
            message: 'Note added successfully!',
            type: SnackBarType.success,
          );
        }
        debugPrint('Note added');
      } else {
        await provider.updateNote(_noteData);
        if (mounted) {
          Navigator.pop(context, _noteData);
          CustomSnackBar.show(
            context,
            message: 'Note updated successfully!',
            type: SnackBarType.success,
          );
        }
        debugPrint('Note updated');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Note addition failed!',
          type: SnackBarType.error,
        );
      }
      debugPrint('Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ========================================================================
  // UI WIDGETS
  // ========================================================================

  Widget _notesDetails(ColorScheme colorScheme) {
    final created = _createdAtLocal ?? DateTime.now().toLocal();
    final reminder = _noteData.localReminder;
    return CustomContainer(
      color: colorScheme.primaryContainer,
      outlineColor: colorScheme.outline,
      circularRadius: 18,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(created)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.notifications, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Reminder: ${reminder != null ? DateFormat('yyyy-MM-dd HH:mm').format(reminder) : 'No Reminder'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 6),
                const Text('Address: ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    _noteData.address.isNotEmpty
                        ? _noteData.address
                        : 'No Address',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.flag, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Priority: ${_noteData.priority}',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.category, size: 18),
                const SizedBox(width: 6),
                const Text('Category: ', style: TextStyle(fontSize: 14)),
                Text(
                  _noteData.category.isNotEmpty
                      ? _noteData.category
                      : 'Uncategorized',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField(TextTheme textTheme) {
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      style: textTheme.titleLarge,
      decoration: const InputDecoration(
        hintText: 'Title',
        border: InputBorder.none,
      ),
      onTap: () => _lastFocusedController = _titleController,
    );
  }

  Widget _buildContentField(ColorScheme colorScheme, TextTheme textTheme) {
    return TextField(
      controller: _contentController,
      focusNode: _contentFocusNode,
      textAlign: _textAlign,
      maxLines: null,
      style: textTheme.bodyLarge!.copyWith(
        color: colorScheme.onPrimary,
        fontSize: _contentFontSize,
      ),
      decoration: const InputDecoration(
        hintText: 'Enter your note here...',
        border: InputBorder.none,
        isCollapsed: true,
      ),
      onTap: () => _lastFocusedController = _contentController,
    );
  }

  void _handleContentChange() {
    final lineCount = '\n'.allMatches(_contentController.text).length + 1;
    final estimatedHeight = lineCount * (_contentFontSize + 6);
    setState(() {
      _isContentExpanded = estimatedHeight + 20 > 250;
    });
  }

  // ========================================================================
  // UNDO / REDO
  // ========================================================================

  void _initUndoRedo() {
    _setupControllerListener(
      _titleController,
      _titleHistory,
          (v) => _titleIndex = v,
    );
    _setupControllerListener(
      _contentController,
      _contentHistory,
          (v) => _contentIndex = v,
    );
    _pushHistory(_titleController, _titleHistory, (v) => _titleIndex = v);
    _pushHistory(_contentController, _contentHistory, (v) => _contentIndex = v);
  }

  void _setupControllerListener(
      TextEditingController controller,
      List<String> history,
      void Function(int) setIndex,
      ) {
    controller.addListener(() {
      if (_isPerformingUndoRedo) return;
      final currentText = controller.text;
      final lastText = history.isNotEmpty ? history.last : "";
      if (currentText != lastText) {
        final index = history.length - 1;
        if (index < history.length - 1) {
          history.removeRange(index + 1, history.length);
        }
        _pushHistory(controller, history, setIndex);
      }
    });
  }

  void _pushHistory(
      TextEditingController controller,
      List<String> history,
      void Function(int) setIndex,
      ) {
    final text = controller.text;
    if (history.isEmpty || history.last != text) {
      history.add(text);
      setState(() => setIndex(history.length - 1));
    }
  }

  void undo() {
    if (_lastFocusedController == null) return;
    final controller = _lastFocusedController!;
    final history = controller == _titleController
        ? _titleHistory
        : _contentHistory;
    int index = controller == _titleController ? _titleIndex : _contentIndex;
    if (index > 0) {
      _isPerformingUndoRedo = true;
      index--;
      controller.text = history[index];
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      setState(() {
        if (controller == _titleController) {
          _titleIndex = index;
        } else {
          _contentIndex = index;
        }
      });
      _isPerformingUndoRedo = false;
    }
  }

  void redo() {
    if (_lastFocusedController == null) return;
    final controller = _lastFocusedController!;
    final history = controller == _titleController
        ? _titleHistory
        : _contentHistory;
    int index = controller == _titleController ? _titleIndex : _contentIndex;
    if (index < history.length - 1) {
      _isPerformingUndoRedo = true;
      index++;
      controller.text = history[index];
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      setState(() {
        if (controller == _titleController) {
          _titleIndex = index;
        } else {
          _contentIndex = index;
        }
      });
      _isPerformingUndoRedo = false;
    }
  }

  // ========================================================================
  // AUDIO
  // ========================================================================

  List<Widget> _buildAudioWidgets() => _audios
      .map(
        (file) => AudioPlayerWidget(
      file: file,
      onDelete: () => setState(() => _audios.remove(file)),
    ),
  )
      .toList();
}