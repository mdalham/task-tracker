// lib/widget/custom_notes_menu.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:tasktracker/models/add%20note/reminder_popup.dart';
import '../../service/note/db/notes_models.dart';
import '../../widget/custom_container.dart';
import 'location_popup.dart';


class CustomNoteMenu extends StatefulWidget {
  final VoidCallback onItemTap;
  final TextEditingController timestampController;
  final NoteModels noteData;
  final void Function(DateTime?)? onReminderChanged;
  final void Function(String)? onPriorityChanged;
  final void Function(String)? onAddressChanged;
  final VoidCallback? onDiscard;

  const CustomNoteMenu({
    super.key,
    required this.onItemTap,
    required this.timestampController,
    required this.noteData,
    this.onReminderChanged,
    this.onPriorityChanged,
    this.onAddressChanged,
    this.onDiscard,
  });

  @override
  State<CustomNoteMenu> createState() => _CustomNoteMenuState();
}

class _CustomNoteMenuState extends State<CustomNoteMenu> {
  DateTime? _reminderDateTime;
  late String _priority;
  bool _priorityExpanded = false;
  final List<String> _priorityLevels = ['None', 'Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _priority = widget.noteData.priority;
    _reminderDateTime = widget.noteData.reminder;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Add Timestamp – Device Local Time
  // ──────────────────────────────────────────────────────────────────────
  void _addTimestamp() {
    final now = DateTime.now().toLocal(); // Device local
    final timestamp = DateFormat('MMM dd, yyyy – hh:mm a').format(now);
    widget.timestampController.text += '\n$timestamp';
    widget.onItemTap();
    debugPrint('Menu: Added timestamp: $timestamp');
  }

  // ──────────────────────────────────────────────────────────────────────
  // Reusable Row
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildInfoRow(
      String icon,
      String title,
      TextTheme textTheme,
      ColorScheme colorScheme, {
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: onTap ?? widget.onItemTap,
      child: Row(
        children: [
          SvgPicture.asset(
            icon,
            color: colorScheme.onSurface,
            width: 26,
            height: 26,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Reminder Row – Uses localReminder (device time)
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildReminderRow(TextTheme textTheme, ColorScheme colorScheme) {
    final displayText = 'Reminder';

    return _buildInfoRow(
      'assets/icons/alarm-clock.svg',
      displayText,
      textTheme,
      colorScheme,
      onTap: () async {
        widget.onItemTap(); // Close menu first
        final selectedDateTime = await showDialog<DateTime>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ReminderPopup(
            initialDateTime: widget.noteData.reminder,
            onSelected: (_) {},
          ),
        );

        if (selectedDateTime != null) {
          widget.onReminderChanged?.call(selectedDateTime);
          Future.delayed(
            const Duration(milliseconds: 50),
                () => setState(() {}),
          );
          debugPrint('✅ Reminder data updated in menu: $selectedDateTime');
        }
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Address Row
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildAddressRow(TextTheme textTheme, ColorScheme colorScheme) {
    final displayText =  'Address';

    return _buildInfoRow(
      'assets/icons/marker.svg',
      displayText,
      textTheme,
      colorScheme,
      onTap: () async {
        widget.onItemTap();
        final address = await LocationPopup.show(
          context,
          initialAddress: widget.noteData.address,

        );
        if (address != null) {
          widget.onAddressChanged?.call(address);
          Future.delayed(
            const Duration(milliseconds: 50),
                () => setState(() {}),
          );
          debugPrint('✅ Reminder data updated in menu: $address');
        }
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Priority Section
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildPrioritySection(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _priorityExpanded = !_priorityExpanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/priority-arrow.svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                      colorScheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Priority',
                    style: textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                turns: _priorityExpanded ? 0.5 : 0,
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 350),
          crossFadeState: _priorityExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              children: _priorityLevels.map((level) {
                final isSelected = _priority == level;
                return ChoiceChip(
                  label: Text(level),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _priority = level);
                    widget.onPriorityChanged?.call(level);
                    debugPrint('Menu: Priority set to: $level');
                  },
                  selectedColor: Colors.transparent,
                  backgroundColor: colorScheme.primaryContainer,
                  checkmarkColor: Colors.blue,
                  labelStyle: isSelected
                      ? textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  )
                      : textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? Colors.blue : colorScheme.outline,
                      width: 1.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }


  // Discard Row
  Widget _buildDiscardRow(TextTheme textTheme, ColorScheme colorScheme) {
    return _buildInfoRow(
      'assets/icons/delete-document.svg',
      'Discard',
      textTheme,
      colorScheme,
      onTap: () {
        widget.onDiscard?.call();
        debugPrint('Menu: Discard tapped');
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _priorityExpanded ? 290 : 230,
      width: 220,
      child: CustomContainer(
        height: double.infinity,
        width: double.infinity,
        color: colorScheme.primaryContainer,
        outlineColor: colorScheme.outline,
        circularRadius: 18,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                'assets/icons/time-quarter-past.svg',
                'Timestamp',
                textTheme,
                colorScheme,
                onTap: _addTimestamp,
              ),
              const SizedBox(height: 15),
              _buildReminderRow(textTheme, colorScheme),
              const SizedBox(height: 15),
              _buildAddressRow(textTheme, colorScheme),
              const SizedBox(height: 15),
              _buildPrioritySection(textTheme, colorScheme),
              const SizedBox(height: 15),
              _buildDiscardRow(textTheme, colorScheme),
            ],
          ),
        ),
      ),
    );
  }
}
