import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widget/custom_container.dart';
import '../../widget/custom_snack_bar.dart';

/// REMINDER POPUP – USES DEVICE LOCAL TIME
class ReminderPopup extends StatefulWidget {
  final DateTime? initialDateTime;
  final Function(DateTime)? onSelected;

  const ReminderPopup({
    super.key,
    this.initialDateTime,
    this.onSelected,
  });

  /// Static show method
  static Future<DateTime?> show(
      BuildContext context, {
        DateTime? initialDateTime,
      }) {
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ReminderPopup(
        initialDateTime: initialDateTime,
        onSelected: (dt) => Navigator.of(dialogContext).pop(dt),
      ),
    );
  }

  @override
  State<ReminderPopup> createState() => _ReminderPopupState();
}

class _ReminderPopupState extends State<ReminderPopup> {
  late DateTime _selectedDateTime;
  late TextEditingController _dateController;
  late TextEditingController _timeController;

  final List<String> _defaultTimes = [
    '10:00 AM',
    '12:00 PM',
    '02:00 PM',
    '04:00 PM',
    '06:00 PM',
  ];

  @override
  void initState() {
    super.initState();

    // Use provided datetime or current time (no adding hours)
    final now = DateTime.now();
    final initialLocal = widget.initialDateTime ?? now;

    _selectedDateTime = initialLocal;
    _dateController = TextEditingController(text: _formatDate(initialLocal));
    _timeController = TextEditingController(text: _formatTime(initialLocal));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) => DateFormat('MMM dd, yyyy').format(dt);
  String _formatTime(DateTime dt) => DateFormat('hh:mm a').format(dt);

  void _updateControllers() {
    _dateController.text = _formatDate(_selectedDateTime);
    _timeController.text = _formatTime(_selectedDateTime);
  }

  // Date Picker
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime.isAfter(now) ? _selectedDateTime : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.white,
              surface: Colors.grey,
            )
                : const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
              surface: Colors.grey,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
        _updateControllers();
      });
    }
  }

  // Time Picker – Prevents past time
  Future<void> _pickTime() async {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.white,
              surface: Colors.grey,
            )
                : const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
              surface: Colors.grey,
            ),
            timePickerTheme: const TimePickerThemeData(
              hourMinuteShape: CircleBorder(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final candidate = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        picked.hour,
        picked.minute,
      );

      if (candidate.isBefore(now)) {
        _showError('You cannot select a past time!');
        return;
      }

      setState(() {
        _selectedDateTime = candidate;
        _updateControllers();
      });
    }
  }


  // Default Time Buttons
  Widget _buildDefaultTimeButtons(ColorScheme color) {
    final now = DateTime.now();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _defaultTimes.map((timeStr) {
          final parts = timeStr.split(' ');
          final timePart = parts[0];
          final ampm = parts[1];

          final hourStr = timePart.split(':')[0];
          var hour24 = int.parse(hourStr);

          if (ampm == 'PM' && hourStr != '12') hour24 += 12;
          if (ampm == 'AM' && hourStr == '12') hour24 = 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () {
                final candidate = DateTime(
                  _selectedDateTime.year,
                  _selectedDateTime.month,
                  _selectedDateTime.day,
                  hour24,
                  0,
                );

                if (candidate.isBefore(now)) {
                  _showError('You cannot select a past time!');
                  return;
                }

                setState(() {
                  _selectedDateTime = candidate;
                  _updateControllers();
                });
              },
              child: Text(timeStr, style: const TextStyle(fontSize: 13)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showError(String message) {
    CustomSnackBar.show(
      context,
      message: message,
      type: SnackBarType.error,
    );
  }

  // Reusable TextField
  Widget _buildTextField({
    required TextEditingController controller,
    required VoidCallback onIconTap,
    required IconData icon,
    required String hintText,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: TextField(
        readOnly: true,
        controller: controller,
        textAlign: TextAlign.start,
        textAlignVertical: TextAlignVertical.center,
        style: textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: textTheme.displaySmall,
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(icon, color: colorScheme.onSurface),
            onPressed: onIconTap,
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.of(context).size.width * 1;
    final height = MediaQuery.of(context).size.width * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: CustomContainer(
        width: width,
        height: height,
        color: colorScheme.onPrimaryContainer,
        outlineColor: colorScheme.outline,
        circularRadius: 12,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Set Reminder', style: textTheme.titleLarge),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _dateController,
                onIconTap: _pickDate,
                icon: Icons.calendar_today,
                hintText: 'Select Date',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),
              _buildDefaultTimeButtons(colorScheme),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _timeController,
                onIconTap: _pickTime,
                icon: Icons.access_time,
                hintText: 'Select Time',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: textTheme.bodyLarge),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      debugPrint('DEBUG: Reminder selected (local): $_selectedDateTime');
                      widget.onSelected!(_selectedDateTime);
                      Navigator.pop(context, _selectedDateTime);
                    },
                    child:
                    const Text('OK', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}