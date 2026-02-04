import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import '../../model/rental_config.dart';

class RentalConfigEditor extends StatefulWidget {
  final RentalConfig? initialConfig;
  final Function(RentalConfig?) onConfigChanged;

  const RentalConfigEditor({
    Key? key,
    this.initialConfig,
    required this.onConfigChanged,
  }) : super(key: key);

  @override
  State<RentalConfigEditor> createState() => _RentalConfigEditorState();
}

class _RentalConfigEditorState extends State<RentalConfigEditor> {
  late bool _isRentalEnabled;
  late RentalType _rentalType;
  late RentalPricingUnit _pricingUnit;
  late TextEditingController _basePriceController;
  late TextEditingController _bufferMinutesController;
  late TextEditingController _depositAmountController;
  late TextEditingController _dailyMileageLimitController;
  late TextEditingController _overagePriceController;
  late TextEditingController _termsController;
  
  late bool _requiresDeposit;
  late bool _requiresLicense;

  @override
  void initState() {
    super.initState();
    
    final config = widget.initialConfig;
    _isRentalEnabled = config?.isRentalEnabled ?? false;
    _rentalType = config?.rentalType ?? RentalType.general;
    _pricingUnit = config?.defaultPricingUnit ?? RentalPricingUnit.daily;
    _requiresDeposit = config?.requiresDeposit ?? false;
    _requiresLicense = config?.requiresLicense ?? false;
    
    _basePriceController = TextEditingController(
      text: config?.basePrice.toString() ?? '',
    );
    _bufferMinutesController = TextEditingController(
      text: config?.bufferMinutes.toString() ?? '30',
    );
    _depositAmountController = TextEditingController(
      text: config?.depositAmount?.toString() ?? '',
    );
    _dailyMileageLimitController = TextEditingController(
      text: config?.dailyMileageLimit?.toString() ?? '',
    );
    _overagePriceController = TextEditingController(
      text: config?.overagePricePerKm?.toString() ?? '',
    );
    _termsController = TextEditingController(
      text: config?.termsAndConditions ?? '',
    );
  }

  @override
  void dispose() {
    _basePriceController.dispose();
    _bufferMinutesController.dispose();
    _depositAmountController.dispose();
    _dailyMileageLimitController.dispose();
    _overagePriceController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enable/Disable Rentals
        SwitchListTile(
          value: _isRentalEnabled,
          onChanged: (value) {
            setState(() {
              _isRentalEnabled = value;
              _notifyChange();
            });
          },
          title: Text(
            'Enable Rentals',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Allow customers to rent this listing',
            style: isDark
                ? const TextStyle(color: Colors.white, fontSize: 14)
                : const TextStyle(fontSize: 14),
          ),
          activeColor: Color(colorPrimary),
          activeTrackColor: Color(colorPrimary).withOpacity(0.5),
          inactiveThumbColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
        
        if (_isRentalEnabled) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rental Type
                DropdownButtonFormField<RentalType>(
                  value: _rentalType,
                  decoration: const InputDecoration(
                    labelText: 'Rental Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: RentalType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _rentalType = value;
                        _notifyChange();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Pricing Unit
                DropdownButtonFormField<RentalPricingUnit>(
                  value: _pricingUnit,
                  decoration: const InputDecoration(
                    labelText: 'Pricing Unit *',
                    border: OutlineInputBorder(),
                  ),
                  items: RentalPricingUnit.values.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _pricingUnit = value;
                        _notifyChange();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Base Price
                TextFormField(
                  controller: _basePriceController,
                  decoration: const InputDecoration(
                    labelText: 'Base Price *',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _notifyChange(),
                ),
                const SizedBox(height: 16),
                
                // Buffer Minutes
                TextFormField(
                  controller: _bufferMinutesController,
                  decoration: const InputDecoration(
                    labelText: 'Buffer Minutes',
                    hintText: 'Time between bookings (default: 30)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _notifyChange(),
                ),
                const SizedBox(height: 16),
                
                // Deposit
                SwitchListTile(
                  title: const Text('Require Deposit'),
                  value: _requiresDeposit,
                  onChanged: (value) {
                    setState(() {
                      _requiresDeposit = value;
                      _notifyChange();
                    });
                  },
                ),
                
                if (_requiresDeposit) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _depositAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Deposit Amount *',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _notifyChange(),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Vehicle-specific settings
                if (_rentalType == RentalType.vehicle) ...[
                  Text(
                    'Vehicle Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Require Driver License'),
                    value: _requiresLicense,
                    onChanged: (value) {
                      setState(() {
                        _requiresLicense = value;
                        _notifyChange();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _dailyMileageLimitController,
                    decoration: const InputDecoration(
                      labelText: 'Daily Mileage Limit (km)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _notifyChange(),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _overagePriceController,
                    decoration: const InputDecoration(
                      labelText: 'Overage Price Per KM',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _notifyChange(),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Terms and Conditions
                Text(
                  'Terms & Conditions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _termsController,
                  decoration: const InputDecoration(
                    hintText: 'Enter rental terms and conditions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  onChanged: (_) => _notifyChange(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _notifyChange() {
    // Always create config, even if disabled
    // The parent will decide whether to save it based on isRentalEnabled flag
    
    // If no base price set, don't create config yet (validation)
    if (_isRentalEnabled && _basePriceController.text.isEmpty) {
      return;
    }

    final basePrice = _basePriceController.text.isEmpty 
        ? 0.0 
        : double.tryParse(_basePriceController.text) ?? 0.0;

    final config = RentalConfig(
      isRentalEnabled: _isRentalEnabled,
      rentalType: _rentalType,
      defaultPricingUnit: _pricingUnit,
      basePrice: basePrice,
      bufferMinutes: int.tryParse(_bufferMinutesController.text) ?? 30,
      requiresDeposit: _requiresDeposit,
      depositAmount: _requiresDeposit 
          ? double.tryParse(_depositAmountController.text)
          : null,
      requiresLicense: _requiresLicense,
      dailyMileageLimit: int.tryParse(_dailyMileageLimitController.text),
      overagePricePerKm: double.tryParse(_overagePriceController.text),
      termsAndConditions: _termsController.text.isEmpty 
          ? null 
          : _termsController.text,
    );

    widget.onConfigChanged(config);
  }
}
