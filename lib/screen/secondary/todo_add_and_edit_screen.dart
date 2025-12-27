import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tasktracker/widget/custom_snack_bar.dart';
import '../../service/todo/db/todo_model.dart';
import '../../service/todo/provider/todo_provider.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../service/subscription/subscription_aware_interstitial_manager ·.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../widget/category_item.dart';
import '../../widget/custom_container.dart';

class AddEditTodoScreen extends StatefulWidget {
  final Todo? todo;

  const AddEditTodoScreen({super.key, this.todo});

  @override
  State<AddEditTodoScreen> createState() => _AddEditTodoScreenState();
}

class _AddEditTodoScreenState extends State<AddEditTodoScreen> {
  final DraggableScrollableController _dragController =
      DraggableScrollableController();

  SubscriptionAwareInterstitialManager? _interstitialManager;
  SubscriptionAwareBannerManager? _bannerManager; // ✅ Added
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
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

        // ✅ Banner manager
        _bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: [0],
          admobId: "ca-app-pub-7237142331361857/4580424162",
          metaId: "1916722012533263_1916773885861409",
          unityPlacementId: 'Banner_Android',
        );

        _isInitialized = true;
      });

      debugPrint('[AddEditTodoScreen] Ad managers initialized');
    });
  }

  @override
  void dispose() {
    _dragController.dispose();
    _interstitialManager?.dispose();
    _bannerManager?.dispose(); // ✅ Added
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
      onWillPop: () async {
        await _closeWithAd();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            GestureDetector(
              onTap: _closeWithAd,
              child: Container(color: Colors.black26),
            ),
            DraggableScrollableSheet(
              controller: _dragController,
              initialChildSize: 0.695,
              minChildSize: 0.40,
              maxChildSize: 0.96,
              snap: true,
              snapSizes: const [0.695, 0.96],
              builder: (context, scrollController) => _TodoSheet(
                todo: widget.todo,
                scrollController: scrollController,
                dragController: _dragController,
                onClose: _closeWithAd,
                bannerManager: _bannerManager,
                isInitialized: _isInitialized,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoSheet extends StatefulWidget {
  final Todo? todo;
  final ScrollController scrollController;
  final DraggableScrollableController dragController;
  final Future<void> Function() onClose;
  final SubscriptionAwareBannerManager? bannerManager;
  final bool isInitialized;

  const _TodoSheet({
    required this.todo,
    required this.scrollController,
    required this.dragController,
    required this.onClose,
    required this.bannerManager,
    required this.isInitialized,
  });

  @override
  State<_TodoSheet> createState() => _TodoSheetState();
}

class _TodoSheetState extends State<_TodoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final FocusNode _descFocus = FocusNode();

  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  DateTime? _selectedReminderDateTime;
  int _selectedPriority = 0;
  String _selectedCategory = 'None';

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  bool get _isEditing => widget.todo != null;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.todo!.title;
      _descriptionController.text = widget.todo!.description ?? '';
      _categoryController.text = widget.todo!.category ?? '';
      _selectedDueDate = widget.todo!.dueDate;
      _selectedDueTime = widget.todo!.dueTime != null
          ? TimeOfDay.fromDateTime(widget.todo!.dueTime!)
          : null;
      _selectedReminderDateTime = widget.todo!.reminderDateTime;
      _selectedPriority = widget.todo!.priority;
      _selectedCategory = widget.todo!.category ?? 'None';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) {
                  final delta = d.delta.dy;
                  final size = widget.dragController.size;
                  final newSize = (size - delta / screenHeight).clamp(
                    0.50,
                    1.0,
                  );
                  widget.dragController.jumpTo(newSize);
                },
                onVerticalDragEnd: (d) async {
                  final current = widget.dragController.size;
                  final velocity = d.velocity.pixelsPerSecond.dy;

                  if (velocity > 800 || current <= 0.48) {
                    await widget.onClose();
                    return;
                  }

                  double target;
                  if (velocity < -1000) {
                    target = 1.0;
                  } else if (velocity > 1000) {
                    target = 0.50;
                  } else {
                    const snaps = [0.50, 0.75, 1.0];
                    target = snaps.reduce(
                      (a, b) =>
                          (current - a).abs() < (current - b).abs() ? a : b,
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
                    children: [
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
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Todo',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isEditing)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _showDeleteDialog(context),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Divider(height: 1, thickness: 1, color: colorScheme.outline),

              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.all(10),
                    children: [
                      // Title Field
                      _buildTitleField(),
                      const SizedBox(height: 10),

                      // Description Field
                      _buildDescriptionField(),
                      const SizedBox(height: 10),

                      // Priority Selection
                      Text("Priority", style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPriorityChip(
                              'None',
                              0,
                              colorScheme,
                              textTheme,
                            ),
                            ..._priorities.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final priority = entry.value;
                              return _buildPriorityChip(
                                priority,
                                index,
                                colorScheme,
                                textTheme,
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Category Selection
                      Text("Category", style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      CategoryItem(
                        selectedCategory: _selectedCategory,
                        onCategoryChanged: (c) =>
                            setState(() => _selectedCategory = c),
                      ),

                      const SizedBox(height: 10),

                      ValueListenableBuilder<bool>(
                        valueListenable: widget.bannerManager!.bannerReady(0),
                        builder: (_, isReady, __) {
                          if (!isReady) return const SizedBox.shrink();
                          return BannerAdContainerWidget(
                            index: 0,
                            bannerManager: widget.bannerManager!,
                          );
                        },
                      ),

                      Text("Schedule", style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildDateTimeChip(
                            icon: 'assets/icons/calendar-day.svg',
                            label: _buildDueDateTimeLabel(),
                            isSelected: _selectedDueDate != null,
                            onTap: _selectDueDateTime,
                            onClear: _selectedDueDate != null
                                ? () => setState(() {
                                    _selectedDueDate = null;
                                    _selectedDueTime = null;
                                  })
                                : null,
                          ),

                          // Reminder Chip
                          _buildDateTimeChip(
                            icon: 'assets/icons/bell.svg',
                            label: _selectedReminderDateTime != null
                                ? DateFormat(
                                    'MMM dd, h:mm a',
                                  ).format(_selectedReminderDateTime!)
                                : 'Set Reminder',
                            isSelected: _selectedReminderDateTime != null,
                            onTap: _selectReminder,
                            onClear: _selectedReminderDateTime != null
                                ? () => setState(
                                    () => _selectedReminderDateTime = null,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating Save Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: _isSaving ? null : _saveTodo,
                child: CustomContainer(
                  height: 56,
                  width: 56,
                  color: _isSaving ? Colors.blue.withOpacity(0.6) : Colors.blue,
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
    );
  }

  // ========================================================================
  // UI BUILDER METHODS
  // ========================================================================

  Widget _buildTitleField() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return CustomContainer(
      color: colorScheme.primaryContainer,
      outlineColor: colorScheme.outline,
      circularRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: TextFormField(
        controller: _titleController,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: textTheme.titleLarge,
        decoration: InputDecoration(
          hintText: 'Todo title',
          labelStyle: textTheme.titleLarge,
          border: InputBorder.none,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a title';
          }
          return null;
        },
        textCapitalization: TextCapitalization.sentences,
        autofocus: !_isEditing,
      ),
    );
  }

  Widget _buildDescriptionField() {
    final double maxH = MediaQuery.of(context).size.height * 0.5;
    final double minH = MediaQuery.of(context).size.height * 0.14;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        border: Border.all(
          color: _descFocus.hasFocus ? Colors.blue : colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      constraints: BoxConstraints(minHeight: minH, maxHeight: maxH),
      child: TextFormField(
        controller: _descriptionController,
        focusNode: _descFocus,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: textTheme.bodyLarge,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Enter description (Optional)',
          alignLabelWithHint: true,
          hintStyle: textTheme.bodyLarge,
          labelStyle: textTheme.bodyLarge,
          border: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(
    String label,
    int value,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final bool isSel = _selectedPriority == value;
    final Color color = value == 3
        ? Colors.redAccent
        : value == 2
        ? Colors.orangeAccent
        : value == 1
        ? Colors.green
        : colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSel
                ? color.withOpacity(0.1)
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? color : colorScheme.outline,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                value == 0 ? Icons.remove_circle_outline : Icons.flag,
                color: color,
                size: isSel ? 20 : 18,
              ),
              const SizedBox(width: 6),
              Text(label, style: textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeChip({
    required String icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.1)
              : colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              icon,
              height: 20,
              colorFilter: ColorFilter.mode(
                isSelected ? Colors.blue : colorScheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: isSelected ? Colors.blue : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: isSelected ? Colors.blue : colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // HELPER METHODS
  // ========================================================================

  String _buildDueDateTimeLabel() {
    if (_selectedDueDate == null) {
      return 'Set Due Date';
    }

    final dateStr = DateFormat('MMM dd').format(_selectedDueDate!);

    if (_selectedDueTime != null) {
      final timeStr = _selectedDueTime!.format(context);
      return '$dateStr, $timeStr';
    }

    return dateStr;
  }

  // ========================================================================
  // DATE/TIME PICKER METHODS
  // ========================================================================

  ThemeData _pickerTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme.of(context).copyWith(
      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
            )
          : const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: isDark ? Colors.white : Colors.black),
        bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  Future<void> _selectDueDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );

    if (date == null) return;

    setState(() => _selectedDueDate = date);

    if (mounted) {
      final shouldSetTime = await _showTimeOptionDialog();

      if (shouldSetTime == true && mounted) {
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedDueTime ?? TimeOfDay.now(),
          builder: (context, child) =>
              Theme(data: _pickerTheme(context), child: child!),
        );

        if (time != null) {
          setState(() => _selectedDueTime = time);
        }
      }
    }
  }

  Future<bool?> _showTimeOptionDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Time?'),
        content: const Text(
          'Would you like to set a specific time for this due date?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set Time'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedReminderDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedReminderDateTime != null
            ? TimeOfDay.fromDateTime(_selectedReminderDateTime!)
            : TimeOfDay.now(),
        builder: (context, child) =>
            Theme(data: _pickerTheme(context), child: child!),
      );

      if (time != null) {
        final now = DateTime.now();
        final candidate = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        if (candidate.isBefore(now.add(const Duration(minutes: 1)))) {
          if (mounted) {
            CustomSnackBar.show(
              context,
              message: "Can't select past time for reminder",
              type: SnackBarType.warning,
            );
          }
          return;
        }

        setState(() => _selectedReminderDateTime = candidate);
      }
    }
  }

  // ========================================================================
  // SAVE & DELETE METHODS
  // ========================================================================

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<TodoProvider>();

    DateTime? dueTime;
    if (_selectedDueDate != null && _selectedDueTime != null) {
      dueTime = DateTime(
        _selectedDueDate!.year,
        _selectedDueDate!.month,
        _selectedDueDate!.day,
        _selectedDueTime!.hour,
        _selectedDueTime!.minute,
      );
    }

    bool success;
    if (_isEditing) {
      success = await provider.updateTodo(
        id: widget.todo!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _selectedCategory == 'None' ? null : _selectedCategory,
        dueDate: _selectedDueDate,
        dueTime: dueTime,
        reminderDateTime: _selectedReminderDateTime,
        priority: _selectedPriority,
      );
    } else {
      success = await provider.addTodo(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _selectedCategory == 'None' ? null : _selectedCategory,
        dueDate: _selectedDueDate,
        dueTime: dueTime,
        reminderDateTime: _selectedReminderDateTime,
        priority: _selectedPriority,
      );
    }

    if (success && mounted) {
      await widget.onClose();
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: _isEditing
              ? 'Todo updated successfully!'
              : 'Todo created successfully!',
          type: SnackBarType.success,
        );
      }
    } else if (mounted && provider.errorMessage != null) {
      CustomSnackBar.show(
        context,
        message: 'Todo ${_isEditing ? 'update' : 'addition'} failed!',
        type: SnackBarType.error,
      );
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _showDeleteDialog(BuildContext context) {
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
            onPressed: () async {
              final deletedTodo = widget.todo!;

              await context.read<TodoProvider>().deleteTodo(widget.todo!.id);

              Navigator.pop(context);
              await widget.onClose();

              if (mounted) {
                CustomSnackBar.show(
                  context,
                  message: 'Todo deleted successfully!',
                  type: SnackBarType.success,
                  actionLabel: 'Undo',
                  onAction: () async {
                    await context.read<TodoProvider>().restoreTodo(deletedTodo);
                  },
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
