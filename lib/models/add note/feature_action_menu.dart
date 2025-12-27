import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';

import '../../widget/custom_snack_bar.dart';

enum TextAlignOption { left, center, right, justify }

class FeatureActionMenu extends StatefulWidget {
  final Function(File) onImagePicked;
  final Function(File) onAudioRecorded;
  final Function(TextAlign) onTextAlignChanged;
  final Function(double) onFontSizeChanged;
  final double selectedFontSize;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;

  const FeatureActionMenu({
    super.key,
    required this.onImagePicked,
    required this.onAudioRecorded,
    required this.onTextAlignChanged,
    required this.onFontSizeChanged,
    required this.selectedFontSize,
    required this.contentController,
    required this.contentFocusNode,
  });

  @override
  State<FeatureActionMenu> createState() => _FeatureActionMenuState();
}

class _FeatureActionMenuState extends State<FeatureActionMenu>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late final AnimationController _arrowController;
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  TextAlignOption _selectedAlignment = TextAlignOption.left;
  late double _currentFontSize;

  bool _isRecording = false;
  String? _audioFilePath;

  static const double _collapsedHeight = 80;
  static const double _expandedHeight = 290;

  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.contentController;
    _currentFontSize = widget.selectedFontSize;
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _audioRecorder.openRecorder();
    await _audioRecorder.setSubscriptionDuration(
      const Duration(milliseconds: 500),
    );
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

  Future<void> recordAudio() async {
    if (_isRecording) {
      await _audioRecorder.stopRecorder().then((path) {
        if (path != null) widget.onAudioRecorded(File(path));
        setState(() => _isRecording = false);
      });
    } else {
      if (await Permission.microphone.request().isGranted) {
        _audioFilePath =
        '${Directory.systemTemp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
        await _audioRecorder.startRecorder(toFile: _audioFilePath);
        setState(() => _isRecording = true);
      }
    }
  }

  @override
  void dispose() {
    _arrowController.dispose();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double conMinHeight = SizeHelperClass.conMinHeight(context);


    final double iconAreaHeight = isExpanded ? (_expandedHeight - 48) : 0;

    return GestureDetector(
      onTap: toggleExpand,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Container(
          width: 60,
          constraints: const BoxConstraints(minHeight: _collapsedHeight),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.outline, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _arrowController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _arrowController.value * math.pi,
                        child: GestureDetector(
                          onTap: toggleExpand,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: SizeHelperClass.keyboardArrowDownIconSize(context),
                            color: colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildAction(
                    icon: 'assets/icons/image_add.svg',
                    tooltip: 'Add image',
                    colorScheme: colorScheme,
                    onTap: () => pickImage(context, colorScheme, textTheme),
                  ),
                ],
              ),
              ClipRect(
                child: SizedBox(
                  height: iconAreaHeight,
                  width: 60,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isExpanded ? 1 : 0,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 300),
                      offset: isExpanded ? Offset.zero : const Offset(0, 0.2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildAudioAction(
                            icon: _isRecording
                                ? 'assets/icons/stop_audio.svg'
                                : 'assets/icons/audio.svg',
                            tooltip: 'Record audio',
                            colorScheme: colorScheme,
                            onTap: recordAudio,
                          ),
                          _buildTextAlignmentAction(colorScheme),
                          _buildFontSizeAction(colorScheme),
                          _buildAction(
                            icon: 'assets/icons/bold.svg',
                            tooltip: 'Bold',
                            colorScheme: colorScheme,
                            onTap: () {
                              insertMarkdown(
                                '**',
                                '**',
                              );
                            },
                          ),
                          _buildAction(
                            icon: 'assets/icons/italic.svg',
                            tooltip: 'Italic',
                            colorScheme: colorScheme,
                            onTap: () {
                              insertMarkdown(
                                '*',
                                '*',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (isExpanded) const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }

  void insertMarkdown(String left, String right) {
    final text = _controller.text;
    var selection = _controller.selection;

    if (!selection.isValid) {
      selection = TextSelection.collapsed(offset: text.length);
    }

    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    final selectedText = text.substring(start, end);

    String newText;
    TextSelection newSelection;

    if (start != end) {
      newText = text.replaceRange(start, end, '$left$selectedText$right');
      final innerStart = start + left.length;
      final innerEnd = innerStart + selectedText.length;
      newSelection = TextSelection(
        baseOffset: innerStart,
        extentOffset: innerEnd,
      );
    } else {
      newText = text.replaceRange(start, end, '$left$right');
      final cursorPos = start + left.length;
      newSelection = TextSelection.collapsed(offset: cursorPos);
    }
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.selection = newSelection;

      try {
        widget.contentFocusNode.requestFocus();
      } catch (_) {
        WidgetsBinding.instance.focusManager.primaryFocus?.requestFocus();
      }
    });
  }

  Widget _buildTextAlignmentAction(ColorScheme colorScheme) {
    Widget getIconForOption(TextAlignOption option, {Color? color}) {
      String path;
      switch (option) {
        case TextAlignOption.left:
          path = 'assets/icons/left_align.svg';
          break;
        case TextAlignOption.center:
          path = 'assets/icons/center_align.svg';
          break;
        case TextAlignOption.right:
          path = 'assets/icons/right_align.svg';
          break;
        case TextAlignOption.justify:
          path = 'assets/icons/justify_align.svg';
          break;
      }

      return SvgPicture.asset(
        path,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          color ?? colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      );
    }

    TextAlign getTextAlign(TextAlignOption option) {
      switch (option) {
        case TextAlignOption.left:
          return TextAlign.left;
        case TextAlignOption.center:
          return TextAlign.center;
        case TextAlignOption.right:
          return TextAlign.right;
        case TextAlignOption.justify:
          return TextAlign.justify;
      }
    }

    OverlayEntry? overlayEntry;

    void showOverlay(BuildContext context) {
      overlayEntry = OverlayEntry(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            overlayEntry?.remove();
            overlayEntry = null;
          },
          child: Stack(
            children: [
              Positioned(
                right: 90,
                top: 174,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: TextAlignOption.values.map((option) {
                        final isSelected = _selectedAlignment == option;
                        return IconButton(
                          icon: getIconForOption(
                            option,
                            color: isSelected
                                ? Colors.blue
                                : colorScheme.onSurface,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedAlignment = option;
                            });
                            widget.onTextAlignChanged(getTextAlign(option));
                            overlayEntry?.remove();
                            overlayEntry = null;
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry!);
    }

    return GestureDetector(
      onLongPress: () => showOverlay(context),
      child: _buildAction(
        icon: 'assets/icons/${_selectedAlignment.name}_align.svg',
        tooltip: 'Text alignment',
        colorScheme: colorScheme,
        onTap: () {
          CustomSnackBar.show(
            context,
            message: 'Long press to Change text alignment',
            type: SnackBarType.success,
          );
        },
      ),
    );
  }

  Widget _buildFontSizeAction(ColorScheme colorScheme) {
    OverlayEntry? overlayEntry;
    final List<double> fontSizes = [
      10,
      12,
      14,
      16,
      18,
      20,
      22,
      24,
      26,
      28,
      30,
      32,
      34,
      36,
    ];

    void showOverlay(BuildContext context) {
      overlayEntry = OverlayEntry(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            overlayEntry?.remove();
            overlayEntry = null;
          },
          child: Stack(
            children: [
              Positioned(
                right: 90,
                top: 196,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: 180,
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: fontSizes.map((size) {
                          return GestureDetector(
                            onTap: () {
                              setState(() => _currentFontSize = size);
                              widget.onFontSizeChanged(size);
                              overlayEntry?.remove();
                              overlayEntry = null;
                              CustomSnackBar.show(
                                context,
                                message: 'Font size set to ${size.toInt()}',
                                type: SnackBarType.success,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              color: _currentFontSize == size
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.transparent,
                              child: Center(
                                child: Text(
                                  size.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: size,
                                    color: _currentFontSize == size
                                        ? Colors.blue
                                        : colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry!);
    }

    return GestureDetector(
      onLongPress: () => showOverlay(context),
      child: _buildAction(
        icon: 'assets/icons/font_size.svg',
        tooltip: 'Font size',
        colorScheme: colorScheme,
        onTap: () {
          CustomSnackBar.show(
            context,
            message: 'Long press to Change font size',
            type: SnackBarType.warning,
          );
        },
      ),
    );
  }

  Widget _buildAction({
    required String icon,
    required String tooltip,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: SvgPicture.asset(
            icon,
            colorFilter: ColorFilter.mode(
              colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioAction({
    required String icon,
    required String tooltip,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              final isStop = (child.key as ValueKey).value
                  .toString()
                  .contains("stop_audio");
              if (isStop) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              }
              return ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: SvgPicture.asset(
              icon,
              key: ValueKey(icon),
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }



  Future<void> pickImage(
      BuildContext context,
      ColorScheme colorScheme,
      TextTheme textTheme,
      ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.primaryContainer,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: colorScheme.outline, width: 1.5),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text('Pick Image', style: textTheme.displaySmall),
                  Divider(thickness: 1.5, color: colorScheme.outline),
                  ListTile(
                    leading: Icon(
                      Icons.photo_library,
                      color: colorScheme.onSurface,
                    ),
                    title: Text('Gallery', style: textTheme.bodyLarge),
                    onTap: () async {
                      final XFile? image = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        widget.onImagePicked(File(image.path));
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.camera_alt, color: colorScheme.onSurface),
                    title: Text('Camera', style: textTheme.bodyLarge),
                    onTap: () async {
                      final XFile? image = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                      );
                      if (image != null) {
                        widget.onImagePicked(File(image.path));
                      }
                      Navigator.of(context).pop(); // close sheet
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
