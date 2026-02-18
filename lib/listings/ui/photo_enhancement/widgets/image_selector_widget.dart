import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Widget for selecting and categorizing images for enhancement
class ImageSelectorWidget extends StatefulWidget {
  final Function(String imagePath, String category) onImageSelected;
  final VoidCallback onCancel;
  final bool isLoading;
  final bool isDark;

  const ImageSelectorWidget({
    Key? key,
    required this.onImageSelected,
    required this.onCancel,
    this.isLoading = false,
    this.isDark = false,
  }) : super(key: key);

  @override
  State<ImageSelectorWidget> createState() => _ImageSelectorWidgetState();
}

class _ImageSelectorWidgetState extends State<ImageSelectorWidget> {
  String _selectedCategory = 'product';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Image Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _buildCategoryOption(
                'product',
                'Product',
                'Physical item or merchandise',
                Icons.shopping_bag,
              ),
              const SizedBox(height: 12),
              _buildCategoryOption(
                'service',
                'Service',
                'Service preview or workspace',
                Icons.handshake,
              ),
              const SizedBox(height: 12),
              _buildCategoryOption(
                'person',
                'Person',
                'Profile or team photo',
                Icons.person,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.isLoading
                      ? null
                      : () async {
                          final imagePicker = ImagePicker();
                          try {
                            final pickedFile = await imagePicker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 90,
                            );
                            
                            if (pickedFile != null) {
                              widget.onImageSelected(pickedFile.path, _selectedCategory);
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error taking photo: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.isLoading
                      ? null
                      : () async {
                          final imagePicker = ImagePicker();
                          try {
                            final pickedFile = await imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 90,
                            );
                            
                            if (pickedFile != null) {
                              widget.onImageSelected(pickedFile.path, _selectedCategory);
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error picking image: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  icon: widget.isLoading ? null : const Icon(Icons.image),
                  label: Text(widget.isLoading ? '' : 'Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.isLoading ? null : widget.onCancel,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.isDark ? Colors.white : Colors.black,
              side: BorderSide(
                color: widget.isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryOption(
    String value,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedCategory == value;
    final accentColor = Colors.blueAccent;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? accentColor : (widget.isDark ? Colors.grey.shade600 : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected 
              ? (widget.isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50])
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : (widget.isDark ? Colors.grey.shade400 : Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? accentColor : (widget.isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.grey.shade400 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: accentColor),
          ],
        ),
      ),
    );
  }
}
