import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

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
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  bool _useSimpleMode = false;
  late final TextEditingController _simpleController;

  @override
  void initState() {
    super.initState();
    _simpleController = TextEditingController(text: widget.initialValue.trim());
    _hours = _parseHours(widget.initialValue.trim());
    
    // If it's free text (contains newlines or isn't structured), use simple mode
    _useSimpleMode = !widget.initialValue.contains('→') && widget.initialValue.trim().isNotEmpty;
  }

  Map<String, Map<String, dynamic>> _parseHours(String input) {
    final Map<String, Map<String, dynamic>> result = {};
    for (var day in _days) {
      result[day] = {'open': '', 'close': '', 'closed': false};
    }
    return result;
  }

  String _buildFormattedHours() {
    List<String> lines = [];
    for (var day in _days) {
      final dayData = _hours[day]!;
      if (dayData['closed'] == true) {
        lines.add('$day: Closed');
      } else if (dayData['open']!.isNotEmpty && dayData['close']!.isNotEmpty) {
        lines.add('$day: ${dayData['open']} → ${dayData['close']}');
      }
    }
    return lines.join('\n');
  }

  @override
  void dispose() {
    _simpleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Opening Hours'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Toggle between structured and simple mode
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
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
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Structured mode (day-by-day)
          if (!_useSimpleMode)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ..._days.map((day) {
                      final dayData = _hours[day]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('Closed'.tr()),
                                value: dayData['closed'] == true,
                                onChanged: (value) {
                                  setState(() {
                                    dayData['closed'] = value ?? false;
                                  });
                                },
                              ),
                              if (dayData['closed'] != true)
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          hintText: 'Open'.tr(),
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          dayData['open'] = value;
                                        },
                                        controller: TextEditingController(
                                          text: dayData['open'],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('→', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          hintText: 'Close'.tr(),
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          dayData['close'] = value;
                                        },
                                        controller: TextEditingController(
                                          text: dayData['close'],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

          // Simple/Free text mode
          if (_useSimpleMode)
            TextField(
              controller: _simpleController,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'e.g.\nMon–Fri 9:00 AM – 5:00 PM\nSat 10:00 AM – 2:00 PM\nSun Closed'
                    .tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final result = _useSimpleMode
                  ? _simpleController.text.trim()
                  : _buildFormattedHours();
              Navigator.pop(context, result);
            },
            child: Text('Save'.tr()),
          ),
        ],
      ),
    );
  }
}
