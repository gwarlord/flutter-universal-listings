import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

class LocationPhotosEditor extends StatefulWidget {
  final String? exteriorImageUrl;
  final String? interiorImageUrl;
  final String? locationInstructions;
  final Function(String? exteriorUrl, String? interiorUrl, String? instructions) onPhotosChanged;
  final Future<List<String>> Function(List<File> images) uploadImages;
  final bool isDark;
  final Color primaryColor;

  const LocationPhotosEditor({
    Key? key,
    this.exteriorImageUrl,
    this.interiorImageUrl,
    this.locationInstructions,
    required this.onPhotosChanged,
    required this.uploadImages,
    required this.isDark,
    required this.primaryColor,
  }) : super(key: key);

  @override
  State<LocationPhotosEditor> createState() => _LocationPhotosEditorState();
}

class _LocationPhotosEditorState extends State<LocationPhotosEditor> {
  late String? _exteriorUrl;
  late String? _interiorUrl;
  late String? _instructions;
  late TextEditingController _instructionsController;
  bool _isLoadingExterior = false;
  bool _isLoadingInterior = false;

  @override
  void initState() {
    super.initState();
    _exteriorUrl = widget.exteriorImageUrl;
    _interiorUrl = widget.interiorImageUrl;
    _instructions = widget.locationInstructions;
    _instructionsController = TextEditingController(text: _instructions ?? '');
  }

  @override
  void didUpdateWidget(LocationPhotosEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exteriorImageUrl != widget.exteriorImageUrl) {
      _exteriorUrl = widget.exteriorImageUrl;
    }
    if (oldWidget.interiorImageUrl != widget.interiorImageUrl) {
      _interiorUrl = widget.interiorImageUrl;
    }
    if (oldWidget.locationInstructions != widget.locationInstructions) {
      _instructions = widget.locationInstructions;
      _instructionsController.text = _instructions ?? '';
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(bool isExterior) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    try {
      setState(() {
        if (isExterior) {
          _isLoadingExterior = true;
        } else {
          _isLoadingInterior = true;
        }
      });

      final file = File(pickedFile.path);
      final uploadedUrls = await widget.uploadImages([file]);

      if (uploadedUrls.isNotEmpty) {
        setState(() {
          if (isExterior) {
            _exteriorUrl = uploadedUrls.first;
            _isLoadingExterior = false;
          } else {
            _interiorUrl = uploadedUrls.first;
            _isLoadingInterior = false;
          }
        });
        widget.onPhotosChanged(_exteriorUrl, _interiorUrl, _instructions);
      }
    } catch (e) {
      setState(() {
        if (isExterior) {
          _isLoadingExterior = false;
        } else {
          _isLoadingInterior = false;
        }
      });
      _showError('Failed to upload photo');
    }
  }

  void _removePhoto(bool isExterior) {
    setState(() {
      if (isExterior) {
        _exteriorUrl = null;
      } else {
        _interiorUrl = null;
      }
    });
    widget.onPhotosChanged(_exteriorUrl, _interiorUrl, _instructions);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Photos (Optional)'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help customers visually find your location and assess your space'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPhotoTile(
                  label: 'Exterior'.tr(),
                  hint: 'Show entrance/signage if possible'.tr(),
                  imageUrl: _exteriorUrl,
                  isLoading: _isLoadingExterior,
                  onAdd: () => _pickAndUploadPhoto(true),
                  onRemove: () => _removePhoto(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPhotoTile(
                  label: 'Interior'.tr(),
                  hint: 'Show customer/service area (avoid faces unless permitted)'.tr(),
                  imageUrl: _interiorUrl,
                  isLoading: _isLoadingInterior,
                  onAdd: () => _pickAndUploadPhoto(false),
                  onRemove: () => _removePhoto(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _instructionsController,
            onChanged: (value) {
              _instructions = value.trim().isEmpty ? null : value.trim();
              widget.onPhotosChanged(_exteriorUrl, _interiorUrl, _instructions);
            },
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g., "Take the staircase to the left to the 3rd floor"'.tr(),
              labelText: 'Finding Instructions (Optional)'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
              labelStyle: TextStyle(
                color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              hintStyle: TextStyle(
                color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                fontSize: 13,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: widget.isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: widget.primaryColor, width: 2),
              ),
            ),
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile({
    required String label,
    required String hint,
    required String? imageUrl,
    required bool isLoading,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image/Placeholder
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasImage && !isLoading)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(7),
                      topRight: Radius.circular(7),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    ),
                  )
                else if (!isLoading)
                  _buildPlaceholder()
                else
                  Center(
                    child: CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                    ),
                  ),
              ],
            ),
          ),
          // Label and Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                if (hasImage && !isLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 18),
                        onPressed: onAdd,
                        color: widget.primaryColor,
                        iconSize: 20,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: const EdgeInsets.all(6),
                        tooltip: 'Replace'.tr(),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18),
                        onPressed: onRemove,
                        color: Colors.red,
                        iconSize: 20,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: const EdgeInsets.all(6),
                        tooltip: 'Remove'.tr(),
                      ),
                    ],
                  )
                else if (!isLoading)
                  _buildActionButton(
                    label: 'Add Photo'.tr(),
                    icon: Icons.add_a_photo,
                    onPressed: onAdd,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 32,
            color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'No photo'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isDanger = false,
  }) {
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDanger ? Colors.red : widget.primaryColor,
          side: BorderSide(
            color: isDanger ? Colors.red : widget.primaryColor,
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
