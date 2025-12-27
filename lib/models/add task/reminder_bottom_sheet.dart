import 'package:flutter/material.dart';

import '../../helper class/size_helper_class.dart';
import '../../widget/custom_snack_bar.dart';

class ReminderBottomSheet extends StatefulWidget {
  final DateTime? taskDateTime;
  final DateTime? currentReminder;
  final Function(DateTime?) onReminderSet;

  const ReminderBottomSheet({
    super.key,
    required this.taskDateTime,
    this.currentReminder,
    required this.onReminderSet,
  });

  @override
  State<ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<ReminderBottomSheet> {
  DateTime? _selectedReminder;
  bool _showCustomPicker = false;
  DateTime? _customDate;
  TimeOfDay? _customTime;

  @override
  void initState() {
    super.initState();
    _selectedReminder = widget.currentReminder;
  }

  List<ReminderOption> _getReminderOptions() {
    final taskDate = widget.taskDateTime ?? DateTime.now();
    final now = DateTime.now();

    return [
      ReminderOption(
        title: '5 minutes before',
        icon: Icons.timer_outlined,
        dateTime: taskDate.subtract(const Duration(minutes: 5)),
      ),
      ReminderOption(
        title: '15 minutes before',
        icon: Icons.access_time,
        dateTime: taskDate.subtract(const Duration(minutes: 15)),
      ),
      ReminderOption(
        title: '30 minutes before',
        icon: Icons.schedule,
        dateTime: taskDate.subtract(const Duration(minutes: 30)),
      ),
      ReminderOption(
        title: '1 hour before',
        icon: Icons.hourglass_empty,
        dateTime: taskDate.subtract(const Duration(hours: 1)),
      ),
      ReminderOption(
        title: '1 day before',
        icon: Icons.calendar_today,
        dateTime: taskDate.subtract(const Duration(days: 1)),
      ),
      ReminderOption(
        title: 'Custom',
        icon: Icons.tune,
        dateTime: null,
        isCustom: true,
      ),
    ].where((option) {
      // Filter out past reminders
      if (option.isCustom) return true;
      return option.dateTime!.isAfter(now);
    }).toList();
  }

  Future<void> _pickCustomDateTime() async {
    final now = DateTime.now();
    final taskDate = widget.taskDateTime ?? now;

    // ---------- COMMON PICKER THEME ----------
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

        // Fixes black text in pickers
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
          bodyLarge: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    // ---------- PICK DATE ----------
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: taskDate,
      builder: (context, child) {
        return Theme(
          data: pickerTheme(context),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    // ---------- PICK TIME ----------
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: pickerTheme(context),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final customDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // ---------- VALIDATION ----------
    if (customDateTime.isBefore(now)) {
      _showError("Reminder cannot be in the past");
      return;
    }

    if (customDateTime.isAfter(taskDate)) {
      _showError("Reminder cannot be after the task time");
      return;
    }

    // ---------- SAVE ----------
    setState(() {
      _customDate = pickedDate;
      _customTime = pickedTime;
      _selectedReminder = customDateTime;
      _showCustomPicker = false;
    });
  }

  void _showError(String message) {
    CustomSnackBar.show(
      context,
      message: message,
      type: SnackBarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final options = _getReminderOptions();

    final iconSize = SizeHelperClass.reminderIconSize(context);


    return Container(
      decoration: BoxDecoration(
        color: colorScheme.onPrimaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set Reminder',
                style: textTheme.headlineSmall
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: colorScheme.onPrimary.withOpacity(0.05),
                  ),
                    child: Icon(Icons.close, color: colorScheme.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reminder Options
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedReminder == option.dateTime;
              final isCustomSelected = option.isCustom && _customDate != null;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (option.isCustom) {
                      _pickCustomDateTime();
                    } else {
                      setState(() => _selectedReminder = option.dateTime);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: (isSelected || isCustomSelected)
                          ? Colors.blue.withOpacity(0.1)
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isSelected || isCustomSelected)
                            ? Colors.blue
                            : colorScheme.outline,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          option.icon,
                          color: (isSelected || isCustomSelected)
                              ? Colors.blue
                              : colorScheme.onSurface,
                          size: iconSize,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.title,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: (isSelected || isCustomSelected)
                                      ? Colors.blue
                                      : colorScheme.onPrimary,
                                ),
                              ),
                              if (!option.isCustom && option.dateTime != null)
                                Text(
                                  _formatDateTime(option.dateTime!),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              if (isCustomSelected && _customDate != null)
                                Text(
                                  _formatDateTime(_selectedReminder!),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.blue.withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected || isCustomSelected)
                          Icon(
                            Icons.check_circle,
                            color: Colors.blue,
                            size: iconSize,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onReminderSet(null);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Remove',
                    style: textTheme.bodyLarge?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selectedReminder == null
                      ? null
                      : () {
                    widget.onReminderSet(_selectedReminder);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  ),
                  child: Text(
                    'Set Reminder',
                    style: textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} from now';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} from now';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} from now';
    } else {
      return 'Now';
    }
  }
}

class ReminderOption {
  final String title;
  final IconData icon;
  final DateTime? dateTime;
  final bool isCustom;

  ReminderOption({
    required this.title,
    required this.icon,
    this.dateTime,
    this.isCustom = false,
  });
}