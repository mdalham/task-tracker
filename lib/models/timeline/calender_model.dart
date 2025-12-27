import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';

import '../../widget/custom_container.dart';

class CalendarModel extends StatefulWidget {
  const CalendarModel({super.key});

  @override
  State<CalendarModel> createState() => _CalendarModelState();
}

class _CalendarModelState extends State<CalendarModel>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late final AnimationController _controller;
  late final AnimationController _arrowController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  void _toggleCalendar() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
        _arrowController.forward();
      } else {
        _controller.reverse();
        _arrowController.reverse();
      }
    });
  }

  List<DateTime> _getCurrentWeekDays(DateTime focusedDay) {
    final start = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  void _closeCalendar() {
    if (_isExpanded) _toggleCalendar();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final size = SizeHelperClass.keyboardArrowDownIconSize(context);
    final weekDays = _getCurrentWeekDays(_focusedDay);

    return Stack(
      children: [
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeCalendar,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
        Column(
          children: [
            GestureDetector(
              onTap: _toggleCalendar,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer, // background from colorScheme
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: colorScheme.outline,)
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var day in weekDays)
                              _dayBox(
                                day,
                                colorScheme: colorScheme,
                                textTheme: textTheme,
                                isSelected: isSameDay(_selectedDay, day),
                                onTap: () {
                                  setState(() {
                                    _selectedDay = day;
                                    _focusedDay = day;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: AnimatedBuilder(
                        animation: _arrowController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _arrowController.value * 3.14,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: size,
                              color: colorScheme.onSurface,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizeTransition(
              sizeFactor: _animation,
              axisAlignment: -1.0,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                child: CustomContainer(
                  color: colorScheme.onPrimaryContainer,
                  outlineColor: colorScheme.outline,
                  circularRadius: 15,
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      defaultDecoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      weekendDecoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      outsideDecoration: BoxDecoration(
                        color: Colors.transparent,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      defaultTextStyle: textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      todayTextStyle: textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      selectedTextStyle: textTheme.bodyLarge!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      weekendTextStyle: textTheme.bodyLarge!.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dayBox(
      DateTime day, {
        required ColorScheme colorScheme,
        required TextTheme textTheme,
        bool isSelected = false,
        VoidCallback? onTap,
      }) {
    final isToday = isSameDay(day, DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: MediaQuery.of(context).size.width * 0.15,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : isToday
              ? Colors.blue.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][day.weekday - 1],
              style: textTheme.titleSmall
            ),
            const SizedBox(height: 6),
            Text(
              "${day.day}",
              style: textTheme.titleMedium
            ),
          ],
        ),
      ),
    );
  }
}
