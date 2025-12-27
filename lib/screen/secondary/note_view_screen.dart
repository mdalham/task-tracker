import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/screen/secondary/image_view_screen.dart';
import 'package:tasktracker/service/note/provider/notes_provider.dart';
import 'package:tasktracker/helper%20class/note_helper_class.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../models/dialog/delete_dialog.dart';
import '../../models/note view/audio_player.dart';
import '../../service/ads/banner/banner_ads.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_aware_interstitial_manager ·.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/note/db/notes_models.dart';
import '../../helper class/size_helper_class.dart';
import '../../widget/custom_snack_bar.dart';
import 'note_add_or_edit_screen.dart';

///Draggable Bottom Sheet
class NoteViewScreen extends StatefulWidget {
  final NoteModels note;

  const NoteViewScreen({super.key, required this.note});

  @override
  State<NoteViewScreen> createState() => _NoteViewScreenState();
}

class _NoteViewScreenState extends State<NoteViewScreen> {
  final DraggableScrollableController _dragController =
      DraggableScrollableController();

  // ✅ FIXED: Add interstitial manager for showing ad on close
  SubscriptionAwareInterstitialManager? _interstitialManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        _interstitialManager = SubscriptionAwareInterstitialManager(
          subscriptionProvider: subscriptionProvider,
          admobPrimaryId: 'ca-app-pub-7237142331361857/2288769251',
          admobSecondaryId: 'ca-app-pub-7237142331361857/8653935503',
          metaInterstitialId: '1916722012533263_1916774079194723',
          unityInterstitialId: 'Interstitial_Android',
          tapThreshold: 1,
          maxRetry: 20,
        );
        _isInitialized = true;
      });
    });
  }

  @override
  void dispose() {
    _dragController.dispose();
    _interstitialManager?.dispose();
    super.dispose();
  }

  Future<void> _closeWithAd() async {
    _interstitialManager?.registerTap();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // ✅ FIXED: Show ad on back button press
      onWillPop: () async {
        await _closeWithAd();
        return false; // Prevent default pop, we handle it
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Dimmed backdrop - ✅ FIXED: Show ad on tap outside
            GestureDetector(
              onTap: _closeWithAd,
              child: Container(color: Colors.black26),
            ),
            // Draggable sheet
            DraggableScrollableSheet(
              controller: _dragController,
              initialChildSize: 0.40,
              minChildSize: 0.30,
              maxChildSize: 0.96,
              snap: true,
              snapSizes: const [0.55, 0.75, 0.96],
              builder: (context, scrollController) => _NoteSheet(
                note: widget.note,
                scrollController: scrollController,
                dragController: _dragController,
                onEditResult: (result) {
                  Navigator.of(context).pop(result);
                },
                onClose: _closeWithAd, // ✅ Pass close handler
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sheet UI – FULL HEADER IS DRAGGABLE
class _NoteSheet extends StatefulWidget {
  final NoteModels note;
  final ScrollController scrollController;
  final DraggableScrollableController dragController;
  final void Function(Object? result) onEditResult;
  final Future<void> Function() onClose; // ✅ Add close callback

  const _NoteSheet({
    required this.note,
    required this.scrollController,
    required this.dragController,
    required this.onEditResult,
    required this.onClose,
  });

  // Helper formatters
  static final _dateFmt = DateFormat('EEE, MMM d, yyyy');
  static final _timeFmt = DateFormat('h:mm a');

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  // ✅ FIXED: Use subscription-aware banner manager
  SubscriptionAwareBannerManager? _bannerManager;
  bool _isInitialized = false;

  late NoteModels note;

  @override
  void initState() {
    super.initState();
    note = widget.note;

    // ✅ Initialize banner manager with subscription provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        _bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: [0, 1, 2],
          admobId: "ca-app-pub-7237142331361857/4580424162",
          metaId: "1916722012533263_1916773885861409",
          unityPlacementId: 'Banner_Android',
        );
        _isInitialized = true;
      });
    });
  }

  @override
  void dispose() {
    _bannerManager?.dispose();
    super.dispose();
  }

  // ✅ Helper method to build banner safely
  Widget _buildBanner(int index) {
    if (!_isInitialized || _bannerManager == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _bannerManager!.bannerReady(index),
      builder: (_, isReady, __) {
        if (!isReady) return const SizedBox.shrink();
        return _bannerManager!.getBannerWidget(index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final screenHeight = MediaQuery.of(context).size.height;
    final calendarIconWidth = SizeHelperClass.calendarDayWidth(context);
    final calendarIconHeight = SizeHelperClass.calendarDayHeight(context);

    // BD Time: UTC+6
    final created = (widget.note.noteDateTime ?? DateTime.now()).toUtc().add(
      const Duration(hours: 6),
    );
    String dateTimeStr = _NoteSheet._dateFmt.format(created);
    if (created.hour != 0 || created.minute != 0) {
      dateTimeStr += ' – ${_NoteSheet._timeFmt.format(created)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //DRAGGABLE HEADER
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) {
              final delta = d.delta.dy;
              final size = widget.dragController.size;
              final newSize = (size - delta / screenHeight).clamp(0.35, 1.0);
              widget.dragController.jumpTo(newSize);
            },
            onVerticalDragEnd: (d) async {
              final current = widget.dragController.size;
              final velocity = d.velocity.pixelsPerSecond.dy;

              // ✅ FIXED: Show ad when dragging down to close
              if (velocity > 800 || current <= 0.32) {
                await widget.onClose();
                return;
              }

              double target;
              if (velocity < -1000) {
                target = 1.0;
              } else if (velocity > 1000) {
                target = 0.35;
              } else {
                const snaps = [0.35, 0.55, 0.75, 1.0];
                target = snaps.reduce(
                  (a, b) => (current - a).abs() < (current - b).abs() ? a : b,
                );
              }

              widget.dragController.animateTo(
                target,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              );
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  // Title + edit icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.note.title.isEmpty
                              ? 'Untitled Note'
                              : widget.note.title,
                          style: textTheme.titleLarge,
                          maxLines: null,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      NoteAddOrEditScreen(note: widget.note),
                                ),
                              );
                              if (result != null) widget.onEditResult(result);
                            },
                            child: SvgPicture.asset(
                              'assets/icons/edit.svg',
                              width: calendarIconWidth + 3,
                              height: calendarIconHeight + 3,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _deleteTask(context, widget.note),
                            child: SvgPicture.asset(
                              'assets/icons/trash.svg',
                              width: calendarIconWidth + 3,
                              height: calendarIconHeight + 3,
                              colorFilter: ColorFilter.mode(
                                colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Date & Time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/calendar-day.svg',
                        width: calendarIconWidth,
                        height: calendarIconHeight,
                        colorFilter: ColorFilter.mode(
                          colorScheme.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(dateTimeStr, style: textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: NoteHelperClass.priorityColor(widget.note, colorScheme),
          ),

          // ✅ FIXED: Use safe banner builder
          _buildBanner(0),

          // SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content
                  if (widget.note.content.isNotEmpty) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fontSize = widget.note.fontSize;
                        final textAlign = widget.note.textAlignEnum;

                        return ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 50,
                            maxWidth: double.infinity,
                          ),
                          child: Markdown(
                            key: ValueKey(
                              widget.note.id! + widget.note.content.hashCode,
                            ),
                            data: widget.note.content.trim(),
                            selectable: true,
                            shrinkWrap: true,
                            softLineBreak: true,
                            padding: EdgeInsets.zero,
                            styleSheet: MarkdownStyleSheet(
                              textAlign:
                                  NoteHelperClass.convertTextAlignToWrapAlignment(
                                    textAlign,
                                  ),
                              p: textTheme.bodyLarge?.copyWith(
                                height: 1.75,
                                color: colorScheme.onSurface,
                                fontSize: fontSize,
                              ),

                              h1: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSize + 8,
                              ),
                              h2: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSize + 6,
                              ),
                              h3: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize + 4,
                              ),

                              a: TextStyle(
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                                fontSize: fontSize,
                              ),

                              strong: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSize,
                              ),
                              em: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: fontSize,
                              ),
                              del: TextStyle(
                                color: Colors.red[300],
                                decoration: TextDecoration.lineThrough,
                                fontSize: fontSize,
                              ),

                              code: TextStyle(
                                backgroundColor: colorScheme.primaryContainer,
                                fontFamily: 'JetBrainsMono',
                                fontSize: fontSize - 3.5,
                                color: colorScheme.primary,
                              ),

                              codeblockPadding: const EdgeInsets.all(18),
                              codeblockDecoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colorScheme.outline),
                              ),

                              blockquotePadding: const EdgeInsets.only(
                                left: 16,
                                top: 8,
                                bottom: 8,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                border: Border(
                                  left: BorderSide(
                                    color: colorScheme.outline,
                                    width: 4,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),

                              listBullet: textTheme.bodyLarge?.copyWith(
                                fontSize: fontSize,
                              ),
                              checkbox: TextStyle(
                                color: colorScheme.primary,
                                fontSize: fontSize,
                              ),

                              tableHead: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
                              ),
                              tableBody: textTheme.bodyMedium?.copyWith(
                                fontSize: fontSize,
                              ),
                              tableBorder: TableBorder.all(
                                color: colorScheme.outline,
                                width: 1,
                              ),
                              tableColumnWidth: const FlexColumnWidth(),
                              tableCellsPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              textScaler: TextScaler.linear(
                                MediaQuery.of(
                                  context,
                                ).textScaleFactor.clamp(0.8, 1.3),
                              ),
                            ),

                            onTapLink: (text, href, title) async {
                              if (href == null || href.isEmpty) return;

                              String url = href.trim();
                              if (!RegExp(
                                r'^[a-zA-Z][a-zA-Z0-9+.-]*:',
                              ).hasMatch(url)) {
                                url = 'https://$url';
                              }

                              Uri? uri = Uri.tryParse(url);
                              if (uri == null || uri.scheme.isEmpty) {
                                uri = Uri.parse('https://$href');
                              }

                              final bool launched = await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );

                              if (!launched && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Cannot open link: ${href.trim()}',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  //Checklist
                  if (note.checklist.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Checklist', style: textTheme.titleMedium),
                        _buildChecklistProgress(
                          context,
                          textTheme,
                          colorScheme,
                        ),
                      ],
                    ),
                    ...note.checklist
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: GestureDetector(
                              onTap: () => _toggleChecklistItem(context, item),
                              child: Row(
                                children: [
                                  Icon(
                                    item.isChecked
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    size:
                                        MediaQuery.of(
                                          context,
                                        ).size.shortestSide *
                                        0.055,
                                    color: item.isChecked
                                        ? Colors.green
                                        : colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    const SizedBox(height: 10),
                  ],
                  //Audio
                  if (widget.note.audios.isNotEmpty) ...[
                    Text('Audio', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...widget.note.audios.map((path) {
                      final file = File(path);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AudioPlayer(file: file),
                      );
                    }).toList(),
                  ],
                  const SizedBox(height: 4),
                  //Images
                  if (widget.note.images.isNotEmpty) ...[
                    Text(
                      'Images',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.note.images.map((path) {
                        final file = File(path);
                        return GestureDetector(
                          onTap: () {
                            final index = widget.note.images.indexOf(path);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageViewScreen(
                                  images: widget.note.images
                                      .map((p) => File(p))
                                      .toList(),
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              file,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // ✅ FIXED: Use safe banner builder
                    _buildBanner(1),
                  ],

                  // Empty state
                  if (widget.note.content.isEmpty &&
                      widget.note.images.isEmpty &&
                      widget.note.audios.isEmpty &&
                      widget.note.checklist.isEmpty)
                    Center(
                      child: Text(
                        'No additional details',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 10),

                  // ✅ FIXED: Use safe banner builder
                  _buildBanner(2),
                ],
              ),
            ),
          ),

          //BOTTOM DETAILS
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  Divider(thickness: 1.2, color: colorScheme.outline),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 25,
                      top: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.priority != 'None')
                          _buildInfoRow(
                            icon: 'assets/icons/priority-arrow.svg',
                            label: 'Priority',
                            value: note.priority,
                            color: colorScheme,
                            textTheme: textTheme,
                            iconHeight: calendarIconHeight,
                            iconWidth: calendarIconWidth,
                          ),

                        if (note.category.isNotEmpty)
                          _buildInfoRow(
                            icon: 'assets/icons/calendar-day.svg',
                            label: 'Category',
                            value: note.category,
                            color: colorScheme,
                            textTheme: textTheme,
                            iconHeight: calendarIconHeight,
                            iconWidth: calendarIconWidth,
                          ),

                        if (note.reminder != null)
                          _buildInfoRow(
                            icon:
                                'assets/icons/bell-notification-social-media.svg',
                            label: 'Reminder',
                            value: _formatReminder(note.reminder!),
                            color: colorScheme,
                            textTheme: textTheme,
                            iconHeight: calendarIconHeight,
                            iconWidth: calendarIconWidth,
                          ),
                        if (note.address.isNotEmpty)
                          _buildInfoRow(
                            icon: 'assets/icons/marker.svg',
                            label: 'Address',
                            value: note.address,
                            color: colorScheme,
                            textTheme: textTheme,
                            iconHeight: calendarIconHeight + 6,
                            iconWidth: calendarIconWidth + 6,
                          ),
                        if (note.pinned)
                          _buildInfoRow(
                            icon: 'assets/icons/thumbtack.svg',
                            label: 'Pinned',
                            value: 'Top',
                            color: colorScheme,
                            textTheme: textTheme,
                            iconHeight: calendarIconHeight + 6,
                            iconWidth: calendarIconWidth + 6,
                          ),

                        // Created on (BD Time)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Created ${DateFormat('MMM d, yyyy – h:mm a').format(created)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatReminder(DateTime reminder) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 6)); // BD Time
    final diff = reminder.difference(now);
    if (diff.isNegative) return 'Reminder passed';
    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours % 24}h before';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m before';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m before';
    }
    return 'Now';
  }

  Widget _buildChecklistProgress(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme cs,
  ) {
    final total = note.checklist.length;
    final completed = note.checklist.where((i) => i.isChecked).length;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: progress == 1.0
            ? Colors.green.withOpacity(0.1)
            : cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progress == 1.0 ? Colors.green : cs.outline,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            progress == 1.0 ? Icons.check_circle : Icons.circle_outlined,
            size: MediaQuery.of(context).size.shortestSide * 0.035,
            color: progress == 1.0 ? Colors.green : cs.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '$completed/$total',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: progress == 1.0 ? Colors.green : cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleChecklistItem(
    BuildContext context,
    ChecklistItem item,
  ) async {
    final provider = Provider.of<NoteProvider>(context, listen: false);

    if (note.id == null) return;

    final updatedChecklist = note.checklist.map((i) {
      if (i.title == item.title) {
        return i.copyWith(isChecked: !i.isChecked);
      }
      return i;
    }).toList();

    final updatedNote = note.copyWith(checklist: updatedChecklist);

    setState(() {
      note = updatedNote;
    });

    await provider.updateNote(updatedNote);
  }

  Widget _buildInfoRow({
    required String icon,
    required double iconHeight,
    required double iconWidth,
    required String label,
    required String value,
    required ColorScheme color,
    required TextTheme textTheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SvgPicture.asset(
            icon,
            width: iconWidth,
            height: iconHeight,
            colorFilter: ColorFilter.mode(color.onSurface, BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          if (label.isNotEmpty) Text('$label: ', style: textTheme.bodyMedium),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                value,
                style: textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _deleteTask(BuildContext context, NoteModels note) async {
    // 1. Confirm deletion
    final confirmed = await deleteDialog(
      context: context,
      title: "Delete Note?",
      message: 'This action cannot be undone after delete completed',
    );
    if (confirmed != true) return;
    Navigator.of(context).pop();
    if (note.id == null) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);
    final NoteModels deletedNote = note;
    provider.deleteNote(note.id!);

    if (!context.mounted) return;

    CustomSnackBar.show(
      context,
      message: 'Note deleted successfully!',
      type: SnackBarType.success,
      actionLabel: 'Undo',
      onAction: () async {
        await provider.addNote(deletedNote);
      },
    );
  }
}
