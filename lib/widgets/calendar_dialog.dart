import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime displayedMonth;
  final int Function(DateTime) calorieCalculator;
  final void Function(DateTime) onDateSelected;
  final void Function(DateTime) onMonthChanged;

  const CalendarDialog({
    super.key,
    required this.initialDate,
    required this.displayedMonth,
    required this.calorieCalculator,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  @override
  State<CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<CalendarDialog> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.displayedMonth.year, widget.displayedMonth.month, 1);
    _selectedDate = widget.initialDate;
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  int _daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  int _firstDayOfWeekOffset(DateTime month) {
    // Monday = 0, Sunday = 6
    return (month.weekday - 1) % 7;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isSelected(DateTime date) {
    return date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(_displayedMonth);
    final daysInMonth = _daysInMonth(_displayedMonth);
    final firstDayOffset = _firstDayOfWeekOffset(_displayedMonth);
    final totalCells = firstDayOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month navigation header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  monthName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Weekday headers
            Row(
              children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Calendar grid
            ...List.generate(rows, (rowIndex) {
              return Row(
                children: List.generate(7, (colIndex) {
                  final cellIndex = rowIndex * 7 + colIndex;
                  final dayNum = cellIndex - firstDayOffset + 1;

                  if (cellIndex < firstDayOffset || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 60));
                  }

                  final date = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
                  final calories = widget.calorieCalculator(date);
                  final isToday = _isToday(date);
                  final isSelected = _isSelected(date);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onDateSelected(date),
                      child: Container(
                        height: 60,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : isToday
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : null,
                              ),
                            ),
                            if (calories > 0)
                              Text(
                                '$calories',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    final today = DateTime.now();
                    widget.onDateSelected(today);
                  },
                  child: const Text('Today'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
