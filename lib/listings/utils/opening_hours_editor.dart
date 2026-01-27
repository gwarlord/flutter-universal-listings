import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/core/utils/helper.dart';

class OpeningHoursEditorSheet {
  /// Opens a bottom sheet and returns the saved text, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    String initialValue = '',
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OpeningHoursEditor(initialValue: initialValue),
    );
  }
}

class _OpeningHoursEditor extends StatefulWidget {
  final String initialValue;
  const _OpeningHoursEditor({required this.initialValue});

  @override
  State<_OpeningHoursEditor> createState() => _OpeningHoursEditorState();
}

class _OpeningHoursEditorState extends State<_OpeningHoursEditor> {
  late final Map<String, Map<String, dynamic>> _hours;
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  bool _useSimpleMode = false;
  late final TextEditingController _simpleController;
  final Map<String, TextEditingController> _openControllers = {};
  final Map<String, TextEditingController> _closeControllers = {};

  @override
  void initState() {
    super.initState();
    _simpleController = TextEditingController(text: widget.initialValue.trim());
    _hours = _parseHours(widget.initialValue.trim());

    for (var day in _days) {
      _openControllers[day] = TextEditingController(text: _hours[day]!['open']);
      _closeControllers[day] =
          TextEditingController(text: _hours[day]!['close']);
    }

    // If it's free text (contains newlines or isn't structured), use simple mode
    _useSimpleMode = !widget.initialValue.contains('→') &&
        widget.initialValue.trim().isNotEmpty;
  }

  Map<String, Map<String, dynamic>> _parseHours(String input) {
    final Map<String, Map<String, dynamic>> result = {};
    for (var day in _days) {
      result[day] = {
        'open': '',
        'close': '',
        'closed': day == 'Sunday' && input.isEmpty
      };
    }

    if (input.isEmpty) return result;

    final lines = input.split('\n');
    for (var line in lines) {
      for (var day in _days) {
        if (line.startsWith('$day:')) {
          final content = line.substring(day.length + 1).trim();
          if (content.toLowerCase() == 'closed') {
            result[day]!['closed'] = true;
          } else if (content.contains('→')) {
            final parts = content.split('→');
            if (parts.length == 2) {
              result[day]!['open'] = parts[0].trim();
              result[day]!['close'] = parts[1].trim();
            }
          }
          break;
        }
      }
    }
    return result;
  }

  String _buildFormattedHours() {
    List<String> lines = [];
    for (var day in _days) {
      final dayData = _hours[day]!;
      if (dayData['closed'] == true) {
        lines.add('$day: Closed');
      } else if (_openControllers[day]!.text.isNotEmpty &&
          _closeControllers[day]!.text.isNotEmpty) {
        lines.add(
            '$day: ${_openControllers[day]!.text} → ${_closeControllers[day]!.text}');
      }
    }
    return lines.join('\n');
  }

  void _applyMondayToWeekdays() {
    final openTime = _openControllers['Monday']!.text;
    final closeTime = _closeControllers['Monday']!.text;
    final isClosed = _hours['Monday']!['closed'] == true;

    setState(() {
      for (var day in ['Tuesday', 'Wednesday', 'Thursday', 'Friday']) {
        _openControllers[day]!.text = openTime;
        _closeControllers[day]!.text = closeTime;
        _hours[day]!['closed'] = isClosed;
      }
    });
  }

  Future<void> _pickTime(BuildContext context, String day, bool isOpen) async {
    final controller = isOpen ? _openControllers[day] : _closeControllers[day];
    TimeOfDay initialTime = isOpen
        ? const TimeOfDay(hour: 9, minute: 0)
        : const TimeOfDay(hour: 17, minute: 0);

    if (controller!.text.isNotEmpty) {
      try {
        final format = DateFormat.jm();
        final date = format.parse(controller.text);
        initialTime = TimeOfDay.fromDateTime(date);
      } catch (_) {}
    }

    final isDark = isDarkMode(context);
    final theme = Theme.of(context);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: theme.primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.grey[900]!,
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: Colors.grey[900],
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: theme.primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        final dt =
            DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        controller.text = DateFormat.jm().format(dt);
      });
    }
  }

  @override
  void dispose() {
    _simpleController.dispose();
    for (var c in _openControllers.values) {
      c.dispose();
    }
    for (var c in _closeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final fabInset = MediaQuery.of(context).viewPadding.bottom;
    final isDark = isDarkMode(context);
    final theme = Theme.of(context);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset + fabInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Opening Hours'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, null),
                icon: Icon(Icons.close, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toggle between structured and simple mode
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text('Structured'.tr()),
                icon: const Icon(Icons.calendar_today),
              ),
              ButtonSegment(
                value: true,
                label: Text('Free Text'.tr()),
                icon: const Icon(Icons.edit),
              ),
            ],
            selected: {_useSimpleMode},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
                _useSimpleMode = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (!_useSimpleMode)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _days.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final day = _days[index];
                        final dayData = _hours[day]!;
                        final isMonday = day == 'Monday';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                            color: isDark ? Colors.grey[900] : Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    day.tr(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  if (isMonday)
                                    TextButton.icon(
                                      onPressed: _applyMondayToWeekdays,
                                      icon:
                                          const Icon(Icons.copy_all, size: 18),
                                      label: Text(
                                        'Apply to Mon-Fri'.tr(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  title: Text('Closed'.tr(),
                                      style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  value: dayData['closed'] == true,
                                  onChanged: (value) {
                                    setState(() {
                                      dayData['closed'] = value ?? false;
                                    });
                                  },
                                  activeColor: theme.primaryColor,
                                ),
                              ),
                              if (dayData['closed'] != true) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () =>
                                            _pickTime(context, day, true),
                                        child: TextField(
                                          controller: _openControllers[day],
                                          enabled: false,
                                          style: TextStyle(color: textColor),
                                          decoration: InputDecoration(
                                            hintText: 'Open'.tr(),
                                            prefixIcon: const Icon(
                                                Icons.access_time,
                                                size: 18),
                                            isDense: true,
                                            disabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: isDark
                                                      ? Colors.grey[700]!
                                                      : Colors.grey[300]!),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(Icons.arrow_forward,
                                          size: 16, color: Colors.grey),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () =>
                                            _pickTime(context, day, false),
                                        child: TextField(
                                          controller: _closeControllers[day],
                                          enabled: false,
                                          style: TextStyle(color: textColor),
                                          decoration: InputDecoration(
                                            hintText: 'Close'.tr(),
                                            prefixIcon: const Icon(
                                                Icons.access_time,
                                                size: 18),
                                            isDense: true,
                                            disabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                  color: isDark
                                                      ? Colors.grey[700]!
                                                      : Colors.grey[300]!),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  if (_useSimpleMode)
                    TextField(
                      controller: _simpleController,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText:
                            'e.g.\nMon–Fri 9:00 AM – 5:00 PM\nSat 10:00 AM – 2:00 PM\nSun Closed'
                                .tr(),
                        hintStyle: TextStyle(
                            color:
                                isDark ? Colors.grey[500] : Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Save Button (Fixed at bottom)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final result = _useSimpleMode
                  ? _simpleController.text.trim()
                  : _buildFormattedHours();
              Navigator.pop(context, result);
            },
            child: Text('Save'.tr(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
