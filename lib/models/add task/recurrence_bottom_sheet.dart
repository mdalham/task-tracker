import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../service/ads/banner/banner_ads.dart';
import '../../service/task/db/recurrence_models.dart';
import '../../widget/custom_container.dart';
import '../../helper class/size_helper_class.dart';

class RecurrenceBottomSheet extends StatefulWidget {
  final RecurrenceSettings currentSettings;
  final Function(RecurrenceSettings) onRecurrenceSet;

  const RecurrenceBottomSheet({
    super.key,
    required this.currentSettings,
    required this.onRecurrenceSet,
  });

  @override
  State<RecurrenceBottomSheet> createState() => _RecurrenceBottomSheetState();
}

class _RecurrenceBottomSheetState extends State<RecurrenceBottomSheet> {
  late RecurrenceSettings _settings;

  final bannerManager = SmartBannerManager(
    indices: [0,1],
    admobId: "ca-app-pub-7237142331361857/7094906861",
    metaId: "1916722012533263_1916773885861409",
    unityPlacementId: 'Banner_Android',
  );

  @override
  void initState() {
    super.initState();
    bannerManager.loadAllBanners();
    _settings = RecurrenceSettings(
      type: widget.currentSettings.type,
      interval: widget.currentSettings.interval,
      endDate: widget.currentSettings.endDate,
      selectedWeekdays: List.from(widget.currentSettings.selectedWeekdays),
      monthlyDay: widget.currentSettings.monthlyDay,
      monthlyLastDay: widget.currentSettings.monthlyLastDay,
    );
  }

  @override
  void dispose() {
    bannerManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final iconSize = SizeHelperClass.repeatTaskIconSize(context);
    final rtiHeight = SizeHelperClass.reminderIconHeight(context);
    final rtiWidth = SizeHelperClass.repeatTaskIconWidth(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Repeat Task', style: textTheme.headlineSmall),
                TextButton(
                  onPressed: () {
                    widget.onRecurrenceSet(_settings);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Done',
                    style: textTheme.titleMedium!.copyWith(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: bannerManager.bannerReady(0),
            builder: (_, isReady, __) {
              if (!isReady) return const SizedBox.shrink();
              return bannerManager.getBannerWidget(0);
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recurrence Type Selection
                  _buildRecurrenceTypeSelector(
                    colorScheme,
                    textTheme,
                    rtiHeight,
                    rtiWidth,
                  ),

                  if (_settings.type != RecurrenceType.none) ...[
                    const SizedBox(height: 24),
                    _buildIntervalSelector(colorScheme, textTheme),
                  ],

                  if (_settings.type == RecurrenceType.weekly) ...[
                    const SizedBox(height: 24),
                    _buildWeekdaySelector(colorScheme, textTheme),
                  ],

                  if (_settings.type == RecurrenceType.monthly) ...[
                    const SizedBox(height: 24),
                    _buildMonthlyOptions(colorScheme, textTheme),
                  ],

                  if (_settings.type != RecurrenceType.none) ...[
                    const SizedBox(height: 24),
                    _buildEndDateSelector(
                      colorScheme,
                      textTheme,
                      'assets/icons/calendar-day.svg',
                      rtiHeight,
                      rtiWidth,
                    ),
                  ],

                  const SizedBox(height: 24),
                  _buildPreview(colorScheme, textTheme),
                  ValueListenableBuilder<bool>(
                    valueListenable: bannerManager.bannerReady(1),
                    builder: (_, isReady, __) {
                      if (!isReady) return const SizedBox.shrink();
                      return bannerManager.getBannerWidget(1);
                    },
                  ),
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceTypeSelector(
    ColorScheme colorScheme,
    TextTheme textTheme,
    double iconHeight,
    double iconWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repeat',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...RecurrenceType.values.map((type) {
          final isSelected = _settings.type == type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _settings.type = type),
              child: CustomContainer(
                color: isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surface,
                outlineColor: isSelected ? Colors.blue : colorScheme.outline,
                circularRadius: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      _getRecurrenceIcon(type),
                      width: iconWidth,
                      height: iconHeight,
                      colorFilter: ColorFilter.mode(
                        colorScheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getRecurrenceTypeDisplayName(type),
                      style: textTheme.bodyMedium?.copyWith(
                        color: isSelected ? Colors.blue : colorScheme.onPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildIntervalSelector(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repeat Every', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: CustomContainer(
                color: colorScheme.primaryContainer,
                outlineColor: colorScheme.outline,
                circularRadius: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: _settings.interval.toString(),
                  ),
                  onChanged: (value) {
                    final interval = int.tryParse(value);
                    if (interval != null && interval > 0) {
                      setState(() => _settings.interval = interval);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                _getIntervalUnit(_settings.type, _settings.interval),
                style: textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdaySelector(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repeat On', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WeekDay.values.map((weekday) {
            final isSelected = _settings.selectedWeekdays.contains(weekday);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _settings.selectedWeekdays.remove(weekday);
                  } else {
                    _settings.selectedWeekdays.add(weekday);
                  }
                });
              },
              child: CustomContainer(
                color: isSelected ? Colors.blue : colorScheme.primaryContainer,
                outlineColor: isSelected ? Colors.blue : colorScheme.outline,
                circularRadius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  weekday.shortName,
                  style: textTheme.bodyMedium!.copyWith(
                    color: isSelected ? Colors.white : colorScheme.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMonthlyOptions(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monthly Options', style: textTheme.titleMedium),
        const SizedBox(height: 12),

        // Specific Day Option
        GestureDetector(
          onTap: () => setState(() {
            _settings.monthlyLastDay = false;
            _settings.monthlyDay ??= DateTime.now().day;
          }),
          child: CustomContainer(
            color: !_settings.monthlyLastDay
                ? Colors.blue.withOpacity(0.07)
                : colorScheme.primaryContainer,
            outlineColor: !_settings.monthlyLastDay
                ? Colors.blue
                : colorScheme.outline,
            circularRadius: 12,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Radio<bool>(
                  value: false,
                  groupValue: _settings.monthlyLastDay,
                  onChanged: (value) => setState(() {
                    _settings.monthlyLastDay = false;
                    _settings.monthlyDay ??= DateTime.now().day;
                  }),
                ),
                Text('On day ', style: textTheme.bodyMedium),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.14,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      hintText: (_settings.monthlyDay ?? DateTime.now().day)
                          .toString(),
                    ),
                    onChanged: (value) {
                      final day = int.tryParse(value);
                      if (day != null && day >= 1 && day <= 31) {
                        setState(() {
                          _settings.monthlyDay = day;
                          _settings.monthlyLastDay = false;
                        });
                      }
                    },
                  ),
                ),
                Text(' of the month', style: textTheme.bodyMedium),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Last Day Option
        GestureDetector(
          onTap: () => setState(() => _settings.monthlyLastDay = true),
          child: CustomContainer(
            color: _settings.monthlyLastDay
                ? colorScheme.primaryContainer
                : colorScheme.surface,
            outlineColor: _settings.monthlyLastDay
                ? Colors.blue
                : colorScheme.outline,
            circularRadius: 12,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _settings.monthlyLastDay,
                  onChanged: (value) =>
                      setState(() => _settings.monthlyLastDay = true),
                ),
                Text(
                  'On the last day of the month',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndDateSelector(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String icon,
    double iconHeight,
    double iconWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('End Date (Optional)', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickEndDate,
          child: CustomContainer(
            color: colorScheme.primaryContainer,
            outlineColor: colorScheme.outline,
            circularRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SvgPicture.asset(
                  icon,
                  width: iconWidth,
                  height: iconHeight,
                  colorFilter: ColorFilter.mode(
                    colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _settings.endDate != null
                      ? 'Ends on ${_settings.endDate!.day}/${_settings.endDate!.month}/${_settings.endDate!.year}'
                      : 'No End Date',
                  style: textTheme.bodyLarge,
                ),
                const Spacer(),
                if (_settings.endDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _settings.endDate = null),
                    child: Icon(
                      Icons.close,
                      color: colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        CustomContainer(
          color: colorScheme.primaryContainer.withOpacity(0.5),
          outlineColor: colorScheme.outline,
          circularRadius: 12,
          padding: const EdgeInsets.all(16),
          child: Text(_settings.getDisplayText(), style: textTheme.bodyLarge),
        ),
      ],
    );
  }

  Future<void> _pickEndDate() async {
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

        // Fix text color inside date picker
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: isDark ? Colors.white : Colors.black),
          bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),

        // Fix hint text inside any input fields in dialog
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
      );
    }

    // ---------- PICK END DATE ----------
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _settings.endDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(data: pickerTheme(context), child: child!);
      },
    );

    // ---------- SAVE ----------
    if (picked != null) {
      setState(() => _settings.endDate = picked);
    }
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

  String _getRecurrenceTypeDisplayName(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.none:
        return 'No Repeat';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.yearly:
        return 'Yearly';
    }
  }

  String _getIntervalUnit(RecurrenceType type, int interval) {
    switch (type) {
      case RecurrenceType.daily:
        return interval == 1 ? 'Day' : 'Days';
      case RecurrenceType.weekly:
        return interval == 1 ? 'Week' : 'Weeks';
      case RecurrenceType.monthly:
        return interval == 1 ? 'Month' : 'Months';
      case RecurrenceType.yearly:
        return interval == 1 ? 'Year' : 'Years';
      case RecurrenceType.none:
        return '';
    }
  }
}
