import 'package:flutter/material.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:intl/intl.dart';

/// Form for editing redemption and expiry settings for deals
/// Can be embedded in ad_upload_screen or used as a separate step
class DealSettingsForm extends StatefulWidget {
  final String? initialRedemptionType; // 'PROMO_CODE' or 'IN_APP_CLAIM'
  final String? initialPromoCode;
  final int? initialRedemptionLimitTotal;
  final int? initialRedemptionLimitPerUser;
  final DateTime? initialExpireAt;
  final DateTime? initialScheduleAt;
  
  final Function(DealSettings settings) onSaved;

  const DealSettingsForm({
    Key? key,
    this.initialRedemptionType,
    this.initialPromoCode,
    this.initialRedemptionLimitTotal,
    this.initialRedemptionLimitPerUser,
    this.initialExpireAt,
    this.initialScheduleAt,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<DealSettingsForm> createState() => _DealSettingsFormState();
}

class _DealSettingsFormState extends State<DealSettingsForm> {
  late String _redemptionType;
  late TextEditingController _promoCodeController;
  late TextEditingController _limitTotalController;
  late TextEditingController _limitPerUserController;
  late DateTime _expireAt;
  DateTime? _scheduleAt;
  bool _hasRedemptionLimit = false;
  bool _hasPerUserLimit = false;

  @override
  void initState() {
    super.initState();
    _redemptionType = widget.initialRedemptionType ?? 'IN_APP_CLAIM';
    _promoCodeController = TextEditingController(text: widget.initialPromoCode ?? '');
    _limitTotalController = TextEditingController(
      text: widget.initialRedemptionLimitTotal?.toString() ?? '',
    );
    _limitPerUserController = TextEditingController(
      text: widget.initialRedemptionLimitPerUser?.toString() ?? '',
    );
    _expireAt = widget.initialExpireAt ?? DateTime.now().add(const Duration(days: 30));
    _scheduleAt = widget.initialScheduleAt;
    _hasRedemptionLimit = widget.initialRedemptionLimitTotal != null;
    _hasPerUserLimit = widget.initialRedemptionLimitPerUser != null;
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    _limitTotalController.dispose();
    _limitPerUserController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(Function(DateTime) onDateSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expireAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  void _save() {
    triggerHapticLight();
    final settings = DealSettings(
      redemptionType: _redemptionType,
      promoCode: _redemptionType == 'PROMO_CODE' ? _promoCodeController.text : null,
      redemptionLimitTotal: _hasRedemptionLimit 
          ? int.tryParse(_limitTotalController.text)
          : null,
      redemptionLimitPerUser: _hasPerUserLimit
          ? int.tryParse(_limitPerUserController.text)
          : null,
      expireAt: _expireAt,
      scheduleAt: _scheduleAt,
    );

    widget.onSaved(settings);
    Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Deal Settings'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 20),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expiry section
              Text(
                'Expiry & Schedule',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Expiry date
              Card(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                shadowColor: isDark ? Colors.black54 : Colors.black12,
                elevation: isDark ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deal Expires',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy').format(_expireAt),
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _selectDate((date) {
                              setState(() => _expireAt = date);
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                              side: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Schedule date (optional)
              Card(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                shadowColor: isDark ? Colors.black54 : Colors.black12,
                elevation: isDark ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Schedule for Later (optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Switch(
                            value: _scheduleAt != null,
                            onChanged: (value) {
                              triggerHapticLight();
                              setState(() {
                                if (value) {
                                  _scheduleAt = DateTime.now().add(const Duration(days: 1));
                                } else {
                                  _scheduleAt = null;
                                }
                              });
                            },
                            activeColor: primaryColor,
                            inactiveThumbColor: isDark ? Colors.grey[600] : Colors.grey,
                            inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey.shade300,
                          ),
                        ],
                      ),
                      if (_scheduleAt != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy - hh:mm a').format(_scheduleAt!),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _selectDate((date) {
                                setState(() => _scheduleAt = date);
                              }),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : Colors.black87,
                                side: BorderSide(
                                  color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                                ),
                              ),
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Redemption section
              Text(
                'Redemption Type',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Redemption type selection
              Card(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                shadowColor: isDark ? Colors.black54 : Colors.black12,
                elevation: isDark ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioListTile<String>(
                        title: Text(
                          'Promo Code',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Users copy a code to redeem',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        value: 'PROMO_CODE',
                        groupValue: _redemptionType,
                        onChanged: (value) {
                          triggerHapticLight();
                          setState(() => _redemptionType = value!);
                        },
                        activeColor: primaryColor,
                        fillColor: MaterialStateProperty.resolveWith<Color>(
                          (states) {
                            if (states.contains(MaterialState.selected)) {
                              return primaryColor;
                            }
                            return isDark ? Colors.white70 : Colors.black54;
                          },
                        ),
                        tileColor: isDark ? Colors.grey[850] : Colors.white,
                      ),
                      RadioListTile<String>(
                        title: Text(
                          'In-App Claim',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Users claim through the app',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        value: 'IN_APP_CLAIM',
                        groupValue: _redemptionType,
                        onChanged: (value) {
                          triggerHapticLight();
                          setState(() => _redemptionType = value!);
                        },
                        activeColor: primaryColor,
                        fillColor: MaterialStateProperty.resolveWith<Color>(
                          (states) {
                            if (states.contains(MaterialState.selected)) {
                              return primaryColor;
                            }
                            return isDark ? Colors.white70 : Colors.black54;
                          },
                        ),
                        tileColor: isDark ? Colors.grey[850] : Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Promo code input (only show if PROMO_CODE selected)
              if (_redemptionType == 'PROMO_CODE') ...[
                Card(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  shadowColor: isDark ? Colors.black54 : Colors.black12,
                  elevation: isDark ? 1 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Promo Code',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _promoCodeController,
                          decoration: InputDecoration(
                            hintText: 'e.g., SAVE20SUMMER',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.grey[850] : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Redemption limits section
              Text(
                'Redemption Limits',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Total redemption limit
              Card(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                shadowColor: isDark ? Colors.black54 : Colors.black12,
                elevation: isDark ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Redemptions',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Switch(
                            value: _hasRedemptionLimit,
                            onChanged: (value) {
                              triggerHapticLight();
                              setState(() => _hasRedemptionLimit = value);
                            },
                            activeColor: primaryColor,
                            inactiveThumbColor: isDark ? Colors.grey[600] : Colors.grey,
                            inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey.shade300,
                          ),
                        ],
                      ),
                      if (_hasRedemptionLimit) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _limitTotalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g., 100',
                            suffix: const Text('items'),
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            suffixStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.grey[850] : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Per-user redemption limit
              Card(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                shadowColor: isDark ? Colors.black54 : Colors.black12,
                elevation: isDark ? 1 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Per User Limit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Switch(
                            value: _hasPerUserLimit,
                            onChanged: (value) {
                              triggerHapticLight();
                              setState(() => _hasPerUserLimit = value);
                            },
                            activeColor: primaryColor,
                            inactiveThumbColor: isDark ? Colors.grey[600] : Colors.grey,
                            inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey.shade300,
                          ),
                        ],
                      ),
                      if (_hasPerUserLimit) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _limitPerUserController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g., 1',
                            suffix: const Text('times'),
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            suffixStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.grey[850] : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data class for deal settings
class DealSettings {
  final String redemptionType; // 'PROMO_CODE' or 'IN_APP_CLAIM'
  final String? promoCode;
  final int? redemptionLimitTotal;
  final int? redemptionLimitPerUser;
  final DateTime expireAt;
  final DateTime? scheduleAt;

  DealSettings({
    required this.redemptionType,
    this.promoCode,
    this.redemptionLimitTotal,
    this.redemptionLimitPerUser,
    required this.expireAt,
    this.scheduleAt,
  });
}
