import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../model/rental_unit.dart';
import '../../services/rental_service.dart';

class RentalUnitEditorScreen extends StatefulWidget {
  final String listingId;
  final RentalUnit? unit; // null for new unit

  const RentalUnitEditorScreen({
    Key? key,
    required this.listingId,
    this.unit,
  }) : super(key: key);

  @override
  State<RentalUnitEditorScreen> createState() => _RentalUnitEditorScreenState();
}

class _RentalUnitEditorScreenState extends State<RentalUnitEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final RentalService _rentalService = RentalService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _unitNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _licensePlateController;
  late TextEditingController _vinController;
  late TextEditingController _odometerController;

  RentalUnitStatus _status = RentalUnitStatus.available;
  String _fuelLevel = 'Full';
  List<String> _photoUrls = [];
  List<File> _newPhotos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _unitNameController = TextEditingController(text: widget.unit?.unitName ?? '');
    _descriptionController = TextEditingController(text: widget.unit?.description ?? '');
    _licensePlateController = TextEditingController(text: widget.unit?.licensePlate ?? '');
    _vinController = TextEditingController(text: widget.unit?.vin ?? '');
    _odometerController = TextEditingController(
      text: widget.unit?.currentOdometer?.toString() ?? '',
    );

    if (widget.unit != null) {
      _status = widget.unit!.status;
      _fuelLevel = widget.unit!.fuelLevel ?? 'Full';
      _photoUrls = List.from(widget.unit!.photoUrls);
    }
  }

  @override
  void dispose() {
    _unitNameController.dispose();
    _descriptionController.dispose();
    _licensePlateController.dispose();
    _vinController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.unit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Unit' : 'Add Unit'),
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
              onPressed: _saveUnit,
              child: const Text('SAVE'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photos section
            _buildPhotoSection(),
            const SizedBox(height: 24),

            // Unit name
            TextFormField(
              controller: _unitNameController,
              decoration: const InputDecoration(
                labelText: 'Unit Name *',
                hintText: 'e.g., Unit 1, Red Honda Civic, Drill Set A',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a unit name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Additional details about this unit',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Status dropdown
            DropdownButtonFormField<RentalUnitStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: RentalUnitStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Vehicle-specific fields header
            Row(
              children: [
                Icon(Icons.directions_car, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Vehicle Details (if applicable)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // License plate
            TextFormField(
              controller: _licensePlateController,
              decoration: const InputDecoration(
                labelText: 'License Plate',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // VIN
            TextFormField(
              controller: _vinController,
              decoration: const InputDecoration(
                labelText: 'VIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Odometer
            TextFormField(
              controller: _odometerController,
              decoration: const InputDecoration(
                labelText: 'Current Odometer (km)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Fuel level dropdown
            DropdownButtonFormField<String>(
              value: _fuelLevel,
              decoration: const InputDecoration(
                labelText: 'Fuel Level',
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
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Existing photos
              ..._photoUrls.map((url) => _buildPhotoItem(url, isUrl: true)),
              // New photos
              ..._newPhotos.map((file) => _buildPhotoItem(file.path, isUrl: false)),
              // Add button
              _buildAddPhotoButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoItem(String path, {required bool isUrl}) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[300],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isUrl
                ? Image.network(path, fit: BoxFit.cover)
                : Image.file(File(path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: () => _removePhoto(path, isUrl),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[400]!),
          color: Colors.grey[200],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, color: Colors.grey[600]),
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

  void _removePhoto(String path, bool isUrl) {
    setState(() {
      if (isUrl) {
        _photoUrls.remove(path);
      } else {
        _newPhotos.removeWhere((file) => file.path == path);
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newPhotos.add(File(image.path));
      });
    }
  }

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Upload new photos to Firebase Storage
      // For now, just keep existing URLs
      final allPhotoUrls = List<String>.from(_photoUrls);

      // Create or update unit
      final unit = RentalUnit(
        id: widget.unit?.id ?? '',
        listingId: widget.listingId,
        unitName: _unitNameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        photoUrls: allPhotoUrls,
        status: _status,
        licensePlate: _licensePlateController.text.isEmpty
            ? null
            : _licensePlateController.text,
        vin: _vinController.text.isEmpty ? null : _vinController.text,
        currentOdometer: _odometerController.text.isEmpty
            ? null
            : int.tryParse(_odometerController.text),
        fuelLevel: _licensePlateController.text.isEmpty ? null : _fuelLevel,
        createdAt: widget.unit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.unit == null) {
        // Create new unit
        await _rentalService.createRentalUnit(unit);
      } else {
        // Update existing unit
        await _rentalService.updateRentalUnit(unit);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.unit == null
                ? 'Unit created successfully'
                : 'Unit updated successfully'),
          ),
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
