import 'package:flutter/material.dart';

enum RecurrenceType { none, daily, weekly, monthly, yearly }

enum WeekDay {
  monday(1, 'Mon'),
  tuesday(2, 'Tue'),
  wednesday(3, 'Wed'),
  thursday(4, 'Thu'),
  friday(5, 'Fri'),
  saturday(6, 'Sat'),
  sunday(7, 'Sun');

  const WeekDay(this.value, this.shortName);
  final int value;
  final String shortName;
}

class RecurrenceSettings {
  RecurrenceType type;
  int interval;
  DateTime? endDate;
  List<WeekDay> selectedWeekdays;
  int? monthlyDay;
  bool monthlyLastDay;

  RecurrenceSettings({
    this.type = RecurrenceType.none,
    this.interval = 1,
    this.endDate,
    this.selectedWeekdays = const [],
    this.monthlyDay,
    this.monthlyLastDay = false,
  });

  // -------------------------------------------------
  // COPY WITH
  // -------------------------------------------------
  RecurrenceSettings copyWith({
    RecurrenceType? type,
    int? interval,
    DateTime? endDate,
    List<WeekDay>? selectedWeekdays,
    int? monthlyDay,
    bool? monthlyLastDay,
  }) {
    return RecurrenceSettings(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      endDate: endDate ?? this.endDate,
      selectedWeekdays: selectedWeekdays ?? List.from(this.selectedWeekdays),
      monthlyDay: monthlyDay ?? this.monthlyDay,
      monthlyLastDay: monthlyLastDay ?? this.monthlyLastDay,
    );
  }

  // -------------------------------------------------
  // NEXT OCCURRENCE (never in the past, respects endDate)
  // -------------------------------------------------
  DateTime? getNextOccurrence(DateTime currentDate) {
    if (type == RecurrenceType.none) return null;

    final now = DateTime.now();
    DateTime candidate;

    switch (type) {
      case RecurrenceType.daily:
        candidate = currentDate.add(Duration(days: interval));
        break;
      case RecurrenceType.weekly:
        candidate = _nextWeekly(currentDate);
        break;
      case RecurrenceType.monthly:
        candidate = _nextMonthly(currentDate);
        break;
      case RecurrenceType.yearly:
        candidate = DateTime(
          currentDate.year + interval,
          currentDate.month,
          currentDate.day,
          currentDate.hour,
          currentDate.minute,
        );
        break;
      default:
        return null;
    }

    if (endDate != null && candidate.isAfter(endDate!)) return null;
    if (candidate.isBefore(now)) return null;
    return candidate;
  }

  DateTime _nextWeekly(DateTime from) {
    final weekdays = selectedWeekdays.isEmpty
        ? [WeekDay.values[from.weekday - 1]]
        : selectedWeekdays;

    for (int i = 1; i <= 7 * interval + 7; i++) {
      final next = from.add(Duration(days: i));
      if (weekdays.any((wd) => wd.value == next.weekday)) {
        return next;
      }
    }
    return from.add(Duration(days: 7 * interval)); // fallback
  }

  DateTime _nextMonthly(DateTime from) {
    if (monthlyLastDay) {
      final next = DateTime(from.year, from.month + interval + 1, 0);
      return DateTime(next.year, next.month, next.day, from.hour, from.minute);
    }

    final day = monthlyDay ?? from.day;
    var candidate = DateTime(from.year, from.month + interval, day, from.hour, from.minute);

    final daysInMonth = DateTime(candidate.year, candidate.month + 1, 0).day;
    if (day > daysInMonth) {
      candidate = DateTime(candidate.year, candidate.month, daysInMonth, from.hour, from.minute);
    }

    return candidate;
  }



  /// Returns the next valid occurrence AFTER `fromDate` (defaults to now)
  /// Keeps advancing until we find a future date – works even if you complete a task weeks late
  DateTime? getNextOccurrenceAfter(DateTime baseDate, {DateTime? fromDate}) {
    if (type == RecurrenceType.none) return null;

    fromDate ??= DateTime.now();
    DateTime cursor = baseDate.add(const Duration(seconds: 1)); // start just after base
    int safety = 0;
    const int maxSafety = 1000;

    while ((cursor.isBefore(fromDate) || cursor.isAtSameMomentAs(fromDate)) && safety++ < maxSafety) {
      cursor = switch (type) {
        RecurrenceType.daily => cursor.add(Duration(days: interval)),
        RecurrenceType.weekly => _nextWeekly(cursor),
        RecurrenceType.monthly => _nextMonthly(cursor),
        RecurrenceType.yearly => DateTime(
          cursor.year + interval,
          cursor.month,
          cursor.day,
          cursor.hour,
          cursor.minute,
        ),
        RecurrenceType.none => cursor,
      };
    }

    if (endDate != null && cursor.isAfter(endDate!)) return null;
    if (cursor.isBefore(fromDate) || cursor.isAtSameMomentAs(fromDate)) return null;

    return cursor;
  }
  // DISPLAY TEXT
  // -------------------------------------------------
  String getDisplayText() {
    if (type == RecurrenceType.none) return 'No Repeat';
    final intervalText = interval == 1 ? '' : 'Every $interval ';
    switch (type) {
      case RecurrenceType.daily:
        return '${intervalText}Day${interval == 1 ? '' : 's'}';
      case RecurrenceType.weekly:
        if (selectedWeekdays.isEmpty) return '${intervalText}Week${interval == 1 ? '' : 's'}';
        final days = selectedWeekdays.map((wd) => wd.shortName).join(', ');
        return '${intervalText}Week${interval == 1 ? '' : 's'} on $days';
      case RecurrenceType.monthly:
        if (monthlyLastDay) return '${intervalText}Month${interval == 1 ? '' : 's'} (Last Day)';
        if (monthlyDay != null) return '${intervalText}Month${interval == 1 ? '' : 's'} (Day $monthlyDay)';
        return '${intervalText}Month${interval == 1 ? '' : 's'}';
      case RecurrenceType.yearly:
        return '${intervalText}Year${interval == 1 ? '' : 's'}';
      default:
        return 'No Repeat';
    }
  }

  // -------------------------------------------------
  // TO / FROM MAP
  // -------------------------------------------------
  Map<String, dynamic> toMap() => {
    'type': type.name,
    'interval': interval,
    'endDate': endDate?.toIso8601String(),
    'selectedWeekdays': selectedWeekdays.map((wd) => wd.value).join(','),
    'monthlyDay': monthlyDay,
    'monthlyLastDay': monthlyLastDay ? 1 : 0,
  };

  factory RecurrenceSettings.fromMap(Map<String, dynamic> map) {
    List<WeekDay> weekdays = [];
    if (map['selectedWeekdays'] != null && map['selectedWeekdays'].toString().isNotEmpty) {
      final values = map['selectedWeekdays'].toString().split(',');
      weekdays = values
          .where((v) => v.isNotEmpty)
          .map((v) => WeekDay.values.firstWhere(
            (wd) => wd.value == int.parse(v),
        orElse: () => WeekDay.monday,
      ))
          .toList();
    }

    return RecurrenceSettings(
      type: RecurrenceType.values.firstWhere(
            (e) => e.name == (map['type'] ?? 'none'),
        orElse: () => RecurrenceType.none,
      ),
      interval: map['interval'] ?? 1,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      selectedWeekdays: weekdays,
      monthlyDay: map['monthlyDay'],
      monthlyLastDay: (map['monthlyLastDay'] ?? 0) == 1,
    );
  }

  @override
  String toString() {
    return 'RecurrenceSettings(type: $type, interval: $interval, endDate: $endDate, '
        'weekdays: $selectedWeekdays, monthlyDay: $monthlyDay, lastDay: $monthlyLastDay)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecurrenceSettings &&
        other.type == type &&
        other.interval == interval &&
        other.endDate == endDate &&
        _listEquals(other.selectedWeekdays, selectedWeekdays) &&
        other.monthlyDay == monthlyDay &&
        other.monthlyLastDay == monthlyLastDay;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      interval,
      endDate,
      Object.hashAll(selectedWeekdays),
      monthlyDay,
      monthlyLastDay,
    );
  }

  // Helper for list equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}