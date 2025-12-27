import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../service/ads/banner/banner_ad_container.dart';
import '../../service/subscription/subscription_aware_banner_manager.dart';
import '../../service/subscription/subscription_aware_interstitial_manager ·.dart';
import '../../service/subscription/subscription_provider.dart';
import '../../widget/category_item.dart';
import '../../models/add task/check_list_task_widget.dart';
import '../../models/add task/recurrence_bottom_sheet.dart';
import '../../models/add task/reminder_bottom_sheet.dart';
import '../../service/task/db/recurrence_models.dart';
import '../../service/task/db/tasks_models.dart';
import '../../service/task/provider/task_provider.dart';
import '../../widget/custom_container.dart';
import '../../helper class/size_helper_class.dart';
import '../../widget/custom_snack_bar.dart';

class TaskAddOrEditScreen extends StatefulWidget {
  final TaskModel? task;
  const TaskAddOrEditScreen({super.key, this.task});

  @override
  State<TaskAddOrEditScreen> createState() => _TaskAddOrEditScreenState();
}

class _TaskAddOrEditScreenState extends State<TaskAddOrEditScreen> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey();

  // ✅ Subscription-aware ad managers
  SubscriptionAwareBannerManager? _bannerManager;
  SubscriptionAwareInterstitialManager? _interstitialManager;
  bool _isInitialized = false;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _descFocus = FocusNode();

  DateTime? _selectedDateTime;

  bool _isImportant = false;
  String _selectedPriority = 'None';
  String _selectedCategory = '';
  DateTime? _reminderDateTime;
  late RecurrenceSettings _recurrenceSettings;
  List<TaskModel> _checklist = [];

  final List<String> _priorities = ['Low', 'Medium', 'High'];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _titleCtrl.text = '';
    _descCtrl.text = '';
    _descCtrl.addListener(() => setState(() {}));
    _recurrenceSettings = RecurrenceSettings();

    if (widget.task != null) {
      final t = widget.task!;
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description;
      _selectedDateTime = t.date;
      _isImportant = t.isImportant;
      _selectedPriority = t.priority;
      _selectedCategory = t.category;
      _reminderDateTime = t.reminderDateTime;
      _recurrenceSettings = t.recurrenceSettings.copyWith();
      _checklist = t.checklistTask.map((e) => e.copyWith()).toList();
    } else {
      final now = DateTime.now();
      _selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      );
    }

    // ✅ Initialize subscription-aware ad managers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final subscriptionProvider = context.read<SubscriptionProvider>();

      setState(() {
        // Banner manager
        _bannerManager = SubscriptionAwareBannerManager(
          subscriptionProvider: subscriptionProvider,
          indices: [0, 1, 2],
          admobId: "ca-app-pub-7237142331361857/7733093310",
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

        _isInitialized = true;
      });

      debugPrint('[TaskAddOrEditScreen] Ad managers initialized');
    });
  }

  @override
  void dispose() {
    _interstitialManager?.dispose();
    _bannerManager?.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final iconWidth = SizeHelperClass.reminderIconWidth(context);
    final iconHeight = SizeHelperClass.reminderIconHeight(context);
    final rtiHeight = SizeHelperClass.reminderIconHeight(context);
    final rtiWidth = SizeHelperClass.repeatTaskIconWidth(context);

    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: GestureDetector(
            onTap: _closeWithAd, // ✅ Show ad on back button
            child: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface),
          ),
          title: Text(
            widget.task == null ? "Add Task" : "Edit Task",
            style: textTheme.displaySmall,
          ),
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ Banner Ad 1
                      if (_isInitialized && _bannerManager != null)
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

                      // TITLE
                      CustomContainer(
                        color: colorScheme.primaryContainer,
                        outlineColor: colorScheme.outline,
                        circularRadius: 12,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: _buildTitleField(textTheme),
                      ),
                      const SizedBox(height: 10),

                      // DATE & TIME
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker(colorScheme, textTheme),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTimePicker(colorScheme, textTheme),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // DESCRIPTION
                      _buildDescriptionField(colorScheme, textTheme),
                      const SizedBox(height: 10),

                      // CHECKLIST
                      Text("Checklist", style: textTheme.titleMedium),
                      const SizedBox(height: 5),
                      CheckListTaskWidget(
                        initialItems: _checklist,
                        onChanged: (list) => setState(() => _checklist = list),
                      ),
                      const SizedBox(height: 10),

                      // PRIORITY
                      Text("Priority", style: textTheme.titleMedium),
                      const SizedBox(height: 5),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['None', ..._priorities].map((p) {
                            final isSel = _selectedPriority == p;
                            final color = p == 'High'
                                ? Colors.redAccent
                                : p == 'Medium'
                                ? Colors.orangeAccent
                                : p == 'Low'
                                ? Colors.green
                                : colorScheme.outline;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedPriority = p),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
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
                                        p == 'None'
                                            ? Icons.remove_circle_outline
                                            : Icons.flag,
                                        color: color,
                                        size: isSel ? 20 : 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(p, style: textTheme.titleSmall),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ✅ Banner Ad 2
                      if (_isInitialized && _bannerManager != null)
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

                      // CATEGORY
                      Text("Category", style: textTheme.titleMedium),
                      const SizedBox(height: 5),
                      CategoryItem(
                        selectedCategory: _selectedCategory,
                        onCategoryChanged: (c) =>
                            setState(() => _selectedCategory = c),
                      ),
                      const SizedBox(height: 10),

                      // RECURRENCE
                      _buildRecurrenceSection(
                        colorScheme,
                        textTheme,
                        rtiHeight,
                        rtiWidth,
                      ),
                      const SizedBox(height: 10),

                      // REMINDER
                      _buildReminderSection(
                        colorScheme,
                        textTheme,
                        iconWidth,
                        iconHeight,
                      ),

                      // ✅ Banner Ad 3
                      if (_isInitialized && _bannerManager != null)
                        ValueListenableBuilder<bool>(
                          valueListenable: _bannerManager!.bannerReady(2),
                          builder: (_, isReady, __) {
                            if (!isReady) return const SizedBox.shrink();
                            return BannerAdContainerWidget(
                              index: 2,
                              bannerManager: _bannerManager!,
                            );
                          },
                        ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // SAVE BUTTON
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GestureDetector(
                    onTap: _isSaving ? null : _saveTask,
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
      ),
    );
  }

  // ========================================================================
  // UI BUILDER METHODS
  // ========================================================================

  Widget _buildTitleField(TextTheme tt) {
    return TextField(
      controller: _titleCtrl,
      style: tt.titleLarge,
      decoration: const InputDecoration(
        hintText: 'Title',
        border: InputBorder.none,
      ),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildTimePicker(ColorScheme cs, TextTheme tt) {
    return GestureDetector(
      onTap: _pickTime,
      child: CustomContainer(
        color: cs.primaryContainer,
        outlineColor: cs.outline,
        circularRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.access_time, color: cs.onSurface, size: 20),
            const SizedBox(width: 10),
            Text(
              _selectedDateTime != null
                  ? DateFormat.jm().format(_selectedDateTime!)
                  : TimeOfDay.now().format(context),
              style: tt.bodySmall!.copyWith(color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField(ColorScheme cs, TextTheme tt) {
    final double maxH = MediaQuery.of(context).size.height * 0.6;
    final double minH = MediaQuery.of(context).size.height * 0.2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border.all(
          color: _descFocus.hasFocus ? Colors.blue : cs.outline,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      constraints: BoxConstraints(minHeight: minH, maxHeight: maxH),
      child: TextField(
        controller: _descCtrl,
        focusNode: _descFocus,
        maxLines: null,
        style: tt.bodyLarge!.copyWith(color: cs.onPrimary),
        decoration: const InputDecoration(
          hintText: 'Enter your note here...',
          border: InputBorder.none,
          isCollapsed: true,
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _buildRecurrenceSection(
      ColorScheme cs,
      TextTheme tt,
      double iconHeight,
      double iconWidth,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Recurrence", style: tt.titleMedium),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: _showRecurrenceSheet,
          child: CustomContainer(
            color: cs.primaryContainer,
            outlineColor: cs.outline,
            circularRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SvgPicture.asset(
                  _getRecurrenceIcon(_recurrenceSettings.type),
                  width: iconWidth,
                  height: iconHeight,
                  colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _recurrenceSettings.getDisplayText(),
                    style: tt.bodyLarge,
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: cs.onSurface, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSection(
      ColorScheme cs,
      TextTheme tt,
      double iconWidth,
      double iconHeight,
      ) {
    return GestureDetector(
      onTap: _showReminderSheet,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Reminder", style: tt.titleMedium),
              if (_reminderDateTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatReminder(_reminderDateTime!),
                    style: tt.bodySmall!.copyWith(color: Colors.blue),
                  ),
                ),
            ],
          ),
          SvgPicture.asset(
            _reminderDateTime != null
                ? 'assets/icons/bell-notification-social-media.svg'
                : 'assets/icons/bell.svg',
            width: iconWidth,
            height: iconHeight,
            colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(ColorScheme cs, TextTheme tt) {
    ThemeData pickerTheme(BuildContext context) {
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

    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDateTime ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          builder: (context, child) =>
              Theme(data: pickerTheme(context), child: child!),
        );

        if (picked != null) {
          setState(() => _selectedDateTime = picked);
        }
      },
      child: CustomContainer(
        color: cs.primaryContainer,
        outlineColor: cs.outline,
        circularRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: cs.onSurface, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedDateTime != null
                    ? DateFormat('EEE, MMM d').format(_selectedDateTime!)
                    : 'Today',
                style: tt.bodySmall!.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // SAVE / PICKERS / HELPERS
  // ========================================================================

  // ✅ Close with ad
  Future<void> _closeWithAd() async {
    _interstitialManager?.registerTap();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveTask() async {
    if (_titleCtrl.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Check your input!',
        type: SnackBarType.warning,
      );
      return;
    }

    if (_selectedDateTime == null) {
      CustomSnackBar.show(
        context,
        message: 'Please set date & time',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = Provider.of<TaskProvider>(context, listen: false);

    try {
      final task = TaskModel(
        id: widget.task?.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        date: _selectedDateTime,
        priority: _selectedPriority,
        category: _selectedCategory,
        isImportant: _isImportant,
        reminderDateTime: _reminderDateTime,
        reminderEnabled: _reminderDateTime != null,
        recurrenceSettings: _recurrenceSettings,
        checklistTask: _checklist,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        completedAt: widget.task?.completedAt,
      );
      debugPrint('RecurrenceSettings: $_recurrenceSettings');

      bool success;
      String msg;

      if (widget.task == null) {
        final id = await provider.addTask(task);
        success = id != null;
        msg = _recurrenceSettings.type != RecurrenceType.none
            ? 'Recurring task created Successfully!'
            : 'Task added Successfully!';
      } else {
        success = await provider.updateTask(task);
        msg = _recurrenceSettings.type != RecurrenceType.none
            ? 'Recurring task updated Successfully!'
            : 'Task updated Successfully!';
      }

      if (success && mounted) {
        // ✅ Show ad on save
        _interstitialManager?.registerTap();
        await Future.delayed(const Duration(milliseconds: 400));
        Navigator.pop(context, true);
        CustomSnackBar.show(context, message: msg, type: SnackBarType.success);
      }
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: 'Task addition failed!',
        type: SnackBarType.error,
      );
      print('saving error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showReminderSheet() {
    if (_selectedDateTime == null) {
      CustomSnackBar.show(
        context,
        message: 'Set date & time first',
        type: SnackBarType.warning,
      );
      return;
    }

    if (_selectedDateTime!.isBefore(
      DateTime.now().add(const Duration(minutes: 1)),
    )) {
      CustomSnackBar.show(
        context,
        message: 'Can\'t set reminder for past time',
        type: SnackBarType.warning,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderBottomSheet(
        taskDateTime: _selectedDateTime!,
        currentReminder: _reminderDateTime,
        onReminderSet: (dt) => setState(() => _reminderDateTime = dt),
      ),
    );
  }

  void _showRecurrenceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecurrenceBottomSheet(
        currentSettings: _recurrenceSettings,
        onRecurrenceSet: (s) => setState(() => _recurrenceSettings = s),
      ),
    );
  }

  String _formatReminder(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d before';
    if (diff.inHours > 0) return '${diff.inHours}h before';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m before';
    return 'Now';
  }

  String _getRecurrenceIcon(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return 'assets/icons/block.svg';
      case RecurrenceType.daily:
        return 'assets/icons/daily.svg';
      case RecurrenceType.weekly:
        return 'assets/icons/sevendays.svg';
      case RecurrenceType.monthly:
        return 'assets/icons/monthly.svg';
      case RecurrenceType.yearly:
        return 'assets/icons/yearly.svg';
    }
  }

  Future<void> _pickTime() async {
    final initialTime = _selectedDateTime != null
        ? TimeOfDay.fromDateTime(_selectedDateTime!)
        : TimeOfDay.now();

    ThemeData pickerTheme(BuildContext context) {
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

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) =>
          Theme(data: pickerTheme(context), child: child!),
    );

    if (picked != null) {
      final now = DateTime.now();
      final base = _selectedDateTime ?? now;
      final candidate = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );

      if (candidate.isBefore(now.add(const Duration(minutes: 1)))) {
        CustomSnackBar.show(
          context,
          message: "Can't select past time",
          type: SnackBarType.warning,
        );
        return;
      }

      setState(() => _selectedDateTime = candidate);
    }
  }
}