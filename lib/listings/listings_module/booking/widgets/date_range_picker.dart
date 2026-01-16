import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRange {
  final DateTime checkIn;
  final DateTime checkOut;

  DateRange({required this.checkIn, required this.checkOut});

  int get numberOfNights => checkOut.difference(checkIn).inDays;
}

class DateRangePickerWidget extends StatefulWidget {
  final Function(DateRange) onDateRangeSelected;
  final List<DateTime> bookedDates;

  const DateRangePickerWidget({
    super.key,
    required this.onDateRangeSelected,
    this.bookedDates = const [],
  });

  @override
  State<DateRangePickerWidget> createState() => _DateRangePickerWidgetState();
}

class _DateRangePickerWidgetState extends State<DateRangePickerWidget> {
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime.now();
  }

  bool _isDateBooked(DateTime date) {
    return widget.bookedDates.any(
      (bookedDate) =>
          bookedDate.year == date.year &&
          bookedDate.month == date.month &&
          bookedDate.day == date.day,
    );
  }

  bool _isDateInRange(DateTime date) {
    if (_checkInDate == null || _checkOutDate == null) return false;
    return date.isAfter(_checkInDate!) && date.isBefore(_checkOutDate!);
  }

  void _selectDate(DateTime date) {
    if (_isDateBooked(date)) return;

    setState(() {
      if (_checkInDate == null) {
        _checkInDate = date;
        _checkOutDate = null;
      } else if (_checkOutDate == null) {
        if (date.isBefore(_checkInDate!)) {
          _checkInDate = date;
        } else {
          _checkOutDate = date;
          widget.onDateRangeSelected(
            DateRange(checkIn: _checkInDate!, checkOut: _checkOutDate!),
          );
        }
      } else {
        _checkInDate = date;
        _checkOutDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_displayedMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
        ),
        _buildCalendar(),
        if (_checkInDate != null) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check-in: ${DateFormat('MMM dd, yyyy').format(_checkInDate!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_checkOutDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Check-out: ${DateFormat('MMM dd, yyyy').format(_checkOutDate!)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nights: ${_checkOutDate!.difference(_checkInDate!).inDays}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDay = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingDayOfWeek = firstDay.weekday;

    final days = <Widget>[];

    // Add empty cells for days before the first day of the month
    for (int i = 0; i < startingDayOfWeek - 1; i++) {
      days.add(Container());
    }

    // Add cells for each day of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final isBooked = _isDateBooked(date);
      final isSelected = _checkInDate != null &&
          _checkInDate!.year == date.year &&
          _checkInDate!.month == date.month &&
          _checkInDate!.day == date.day;
      final isCheckOut = _checkOutDate != null &&
          _checkOutDate!.year == date.year &&
          _checkOutDate!.month == date.month &&
          _checkOutDate!.day == date.day;
      final isInRange = _isDateInRange(date);
      final isPast = date.isBefore(DateTime.now());

      days.add(
        GestureDetector(
          onTap: isPast || isBooked ? null : () => _selectDate(date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected || isCheckOut
                  ? Colors.blue
                  : isInRange
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.transparent,
              border: Border.all(
                color: isSelected || isCheckOut ? Colors.blue : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isPast || isBooked
                      ? Colors.grey.shade400
                      : isSelected || isCheckOut
                          ? Colors.white
                          : Colors.black,
                  fontWeight: isSelected || isCheckOut ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: days,
    );
  }
}
