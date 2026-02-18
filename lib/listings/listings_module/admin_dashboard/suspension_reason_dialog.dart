import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/suspension_info.dart';

class SuspensionReasonDialog extends StatefulWidget {
  final String subjectName;
  final String title;
  final String warningText;

  const SuspensionReasonDialog({
    Key? key,
    required this.subjectName,
    this.title = 'Suspend User',
    this.warningText = 'The user will not be able to log in and will receive a notification.',
  }) : super(key: key);

  @override
  State<SuspensionReasonDialog> createState() => _SuspensionReasonDialogState();
}

class _SuspensionReasonDialogState extends State<SuspensionReasonDialog> {
  late SuspensionReason _selectedReason;
  late TextEditingController _customReasonController;

  @override
  void initState() {
    super.initState();
    _selectedReason = SuspensionReason.breachOfPolicy;
    _customReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.subjectName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Reason Selection
              Text(
                'Select Reason'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Reason options
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: SuspensionReason.values.map((reason) {
                    return RadioListTile<SuspensionReason>(
                      title: Text(reason.displayName),
                      value: reason,
                      groupValue: _selectedReason,
                      onChanged: (value) {
                        setState(() => _selectedReason = value!);
                      },
                      activeColor: Color(cfg.colorPrimary),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Custom Reason Text
              Text(
                'Additional Details (Optional)'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customReasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Provide additional context for this suspension...'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                ),
              ),
              const SizedBox(height: 24),

              // Warning message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.warningText.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'.tr()),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final suspensionInfo = SuspensionInfo(
                        isSuspended: true,
                        reason: _selectedReason,
                        reasonText: _customReasonController.text.trim().isEmpty
                            ? null
                            : _customReasonController.text.trim(),
                      );
                      Navigator.pop(context, suspensionInfo);
                    },
                    child: Text('Suspend'.tr()),
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
