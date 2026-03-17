import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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

  @override
  void dispose() {
    super.dispose();
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
    if (_isDateBooked(date) || !mounted) return;

    setState(() {
      if (_checkInDate == null) {
        _checkInDate = date;
        _checkOutDate = null;
      } else if (_checkOutDate == null) {
        if (date.isBefore(_checkInDate!)) {
          _checkInDate = date;
        } else {
          _checkOutDate = date;
          if (mounted) {
            widget.onDateRangeSelected(
              DateRange(checkIn: _checkInDate!, checkOut: _checkOutDate!),
            );
          }
        }
      } else {
        _checkInDate = date;
        _checkOutDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final localeCode = context.locale.toString();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month - 1,
                      );
                    });
                  }
                },
              ),
              Text(
                DateFormat('MMMM yyyy', localeCode).format(_displayedMonth),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month + 1,
                      );
                    });
                  }
                },
              ),
            ],
          ),
        ),
        _buildWeekdayHeader(isDarkMode),
        _buildCalendar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Tip: Tap the same day twice to book a single day.'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        if (_checkInDate != null) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'Start Date'.tr()}: ${DateFormat('MMM dd, yyyy', localeCode).format(_checkInDate!)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
                ),
                if (_checkOutDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${'End Date'.tr()}: ${DateFormat('MMM dd, yyyy', localeCode).format(_checkOutDate!)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'Nights'.tr()}: ${_checkOutDate!.difference(_checkInDate!).inDays}',
                    style: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDay = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingDayOffset = firstDay.weekday % 7;
    final totalCells = startingDayOffset + daysInMonth;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: totalCells,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        // Empty cells before first day of month
        if (index < startingDayOffset) {
          return const SizedBox.shrink();
        }

        final day = index - startingDayOffset + 1;
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
        final isPast = date.isBefore(DateUtils.dateOnly(DateTime.now()));

        return GestureDetector(
          onTap: isPast || isBooked ? null : () => _selectDate(date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected || isCheckOut
                  ? Colors.blue
                  : isInRange
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.transparent,
              border: Border.all(
                color: isSelected || isCheckOut 
                    ? Colors.blue 
                    : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
              ),
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isPast || isBooked
                      ? (isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400)
                      : isSelected || isCheckOut
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black),
                  fontWeight: isSelected || isCheckOut ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekdayHeader(bool isDarkMode) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: labels
            .map(
              (label) => Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
