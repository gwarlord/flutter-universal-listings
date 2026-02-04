import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../model/rental_evidence.dart';
import '../../model/rental_booking.dart';
import '../../model/rental_config.dart';
import '../../services/rental_service.dart';

class RentalEvidenceScreen extends StatefulWidget {
  final RentalBooking booking;
  final RentalConfig rentalConfig;
  final EvidenceType evidenceType;

  const RentalEvidenceScreen({
    Key? key,
    required this.booking,
    required this.rentalConfig,
    required this.evidenceType,
  }) : super(key: key);

  @override
  State<RentalEvidenceScreen> createState() => _RentalEvidenceScreenState();
}

class _RentalEvidenceScreenState extends State<RentalEvidenceScreen> {
  final RentalService _rentalService = RentalService();
  final ImagePicker _imagePicker = ImagePicker();
  
  final List<File> _photoFiles = [];
  final List<File> _licensePhotoFiles = []; // For checkout only
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _damageDescriptionController = TextEditingController();
  
  String _fuelLevel = 'Full';
  bool _damageReported = false;
  List<String> _checklist = [];
  final List<bool> _checklistStates = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeChecklist();
    
    // Pre-fill odometer for checkin
    if (widget.evidenceType == EvidenceType.checkin &&
        widget.booking.startOdometer != null) {
      _odometerController.text = widget.booking.startOdometer.toString();
    }
  }

  void _initializeChecklist() {
    if (widget.rentalConfig.rentalType == RentalType.vehicle) {
      _checklist = [
        'Vehicle exterior clean',
        'Interior clean',
        'No visible damage',
        'All parts present',
        'Tires in good condition',
        'Lights working',
        'Keys present',
      ];
    } else {
      _checklist = [
        'Item clean',
        'No visible damage',
        'All parts present',
        'Functional condition',
      ];
    }
    _checklistStates.addAll(List.filled(_checklist.length, false));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _odometerController.dispose();
    _damageDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCheckout = widget.evidenceType == EvidenceType.checkout;
    final isVehicle = widget.rentalConfig.rentalType == RentalType.vehicle;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCheckout ? 'Checkout Evidence' : 'Checkin Evidence'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _canSubmit() ? _submitEvidence : null,
              child: const Text('SUBMIT'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Instructions
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[900]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isCheckout
                          ? 'Document the condition before rental begins'
                          : 'Document the condition at return',
                      style: TextStyle(color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Photos section
          _buildPhotosSection(),
          const SizedBox(height: 24),

          // License photos (checkout only for vehicles)
          if (isCheckout && isVehicle && widget.rentalConfig.requiresLicense) ...[
            _buildLicensePhotosSection(),
            const SizedBox(height: 24),
          ],

          // Vehicle-specific fields
          if (isVehicle) ...[
            TextFormField(
              controller: _odometerController,
              decoration: const InputDecoration(
                labelText: 'Odometer Reading (km) *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _fuelLevel,
              decoration: const InputDecoration(
                labelText: 'Fuel Level *',
                border: OutlineInputBorder(),
              ),
              items: ['Full', '3/4', '1/2', '1/4', 'Empty'].map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _fuelLevel = value);
                }
              },
            ),
            const SizedBox(height: 24),
          ],

          // Checklist
          _buildChecklistSection(),
          const SizedBox(height: 24),

          // Damage report
          _buildDamageSection(),
          const SizedBox(height: 24),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Additional Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos *',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Text(
              '(minimum 2 required)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._photoFiles.map((file) => _buildPhotoItem(file)),
            _buildAddPhotoButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildLicensePhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Driver License Photos *',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Text(
              '(front and back)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._licensePhotoFiles.map((file) => _buildPhotoItem(file, isLicense: true)),
            _buildAddPhotoButton(isLicense: true),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoItem(File file, {bool isLicense = false}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(file),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isLicense) {
                  _licensePhotoFiles.remove(file);
                } else {
                  _photoFiles.remove(file);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton({bool isLicense = false}) {
    return GestureDetector(
      onTap: () => _pickImage(isLicense: isLicense),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
          color: Colors.grey[200],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              'Add Photo',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condition Checklist',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: List.generate(_checklist.length, (index) {
                return CheckboxListTile(
                  title: Text(_checklist[index]),
                  value: _checklistStates[index],
                  onChanged: (value) {
                    setState(() {
                      _checklistStates[index] = value ?? false;
                    });
                  },
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDamageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Damage Report',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Switch(
              value: _damageReported,
              onChanged: (value) {
                setState(() => _damageReported = value);
              },
            ),
          ],
        ),
        if (_damageReported) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _damageDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Damage Description *',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ],
    );
  }

  Future<void> _pickImage({bool isLicense = false}) async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        if (isLicense) {
          _licensePhotoFiles.add(File(image.path));
        } else {
          _photoFiles.add(File(image.path));
        }
      });
    }
  }

  bool _canSubmit() {
    // Must have at least 2 photos
    if (_photoFiles.length < 2) return false;
    
    // Vehicle-specific validations
    if (widget.rentalConfig.rentalType == RentalType.vehicle) {
      if (_odometerController.text.isEmpty) return false;
      
      // Checkout: require license photos if configured
      if (widget.evidenceType == EvidenceType.checkout &&
          widget.rentalConfig.requiresLicense &&
          _licensePhotoFiles.length < 2) {
        return false;
      }
    }
    
    // If damage reported, require description
    if (_damageReported && _damageDescriptionController.text.isEmpty) {
      return false;
    }
    
    return true;
  }

  Future<void> _submitEvidence() async {
    setState(() => _isLoading = true);

    try {
      // TODO: Upload photos to Firebase Storage
      // For now, using placeholder URLs
      final mediaList = _photoFiles.map((file) {
        return RentalMedia(
          url: 'placeholder_url', // TODO: Upload file
          type: MediaType.photo,
          timestamp: DateTime.now(),
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
      }).toList();

      final selectedChecklist = <String>[];
      for (var i = 0; i < _checklist.length; i++) {
        if (_checklistStates[i]) {
          selectedChecklist.add(_checklist[i]);
        }
      }

      final evidence = RentalEvidence(
        type: widget.evidenceType,
        media: mediaList,
        checklist: selectedChecklist,
        damageReported: _damageReported,
        damageDescription: _damageReported
            ? _damageDescriptionController.text
            : null,
        damagePhotoUrls: [], // TODO: Upload damage photos if any
        odometerReading: _odometerController.text.isEmpty
            ? null
            : int.tryParse(_odometerController.text),
        fuelLevel: widget.rentalConfig.rentalType == RentalType.vehicle
            ? _fuelLevel
            : null,
        licensePhotoUrls: widget.evidenceType == EvidenceType.checkout &&
                _licensePhotoFiles.isNotEmpty
            ? ['placeholder_license_url'] // TODO: Upload license photos
            : null,
        timestamp: DateTime.now(),
        capturedBy: widget.booking.customerId, // TODO: Get current user ID
      );

      // Save evidence based on type
      if (widget.evidenceType == EvidenceType.checkout) {
        await _rentalService.addCheckoutEvidence(
          bookingId: widget.booking.id,
          evidence: evidence,
        );
        // Update booking status to active
        await _rentalService.updateBookingStatus(
          bookingId: widget.booking.id,
          newStatus: RentalBookingStatus.active,
        );
      } else {
        await _rentalService.addCheckinEvidence(
          bookingId: widget.booking.id,
          evidence: evidence,
          rentalConfig: widget.rentalConfig,
        );
        // Update booking status to completed (or disputed if damage)
        await _rentalService.updateBookingStatus(
          bookingId: widget.booking.id,
          newStatus: _damageReported
              ? RentalBookingStatus.disputed
              : RentalBookingStatus.completed,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidence submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
