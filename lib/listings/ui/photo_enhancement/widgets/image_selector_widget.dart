import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Widget for selecting and categorizing images for enhancement
class ImageSelectorWidget extends StatefulWidget {
  final Future<void> Function(String imagePath, String category)
      onImageSelected;
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

  Future<void> _pickAndSelectImage(ImageSource source) async {
    final imagePicker = ImagePicker();
    try {
      final pickedFile = await imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile == null || !mounted) return;

      await widget.onImageSelected(pickedFile.path, _selectedCategory);
    } catch (e) {
      if (!mounted) return;
      final action = source == ImageSource.camera
          ? 'taking photo'
          : 'picking image';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error $action: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
                      : () => _pickAndSelectImage(ImageSource.camera),
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
                      : () => _pickAndSelectImage(ImageSource.gallery),
                  icon: widget.isLoading ? null : const Icon(Icons.image),
                  label: Text(widget.isLoading ? '' : 'Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6CDF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        widget.isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    disabledForegroundColor:
                        widget.isDark ? Colors.white70 : Colors.black54,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    elevation: 0,
                  ),
                ),
              ),
            ],
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
            IconButton(
              icon: Icon(
                Icons.info_outline,
                size: 20,
                color: widget.isDark ? Colors.grey.shade400 : Colors.grey[600],
              ),
              onPressed: () => _showCategoryInfo(value, title),
              tooltip: 'Learn more',
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: accentColor),
          ],
        ),
      ),
    );
  }

  void _showCategoryInfo(String category, String title) {
    String description;
    List<String> features;
    String result;

    switch (category) {
      case 'product':
        description = 'Professional e-commerce style photos for physical items and merchandise.';
        features = [
          '✓ Background completely removed',
          '✓ Item placed on clean white background',
          '✓ Automatically cropped tight to product',
          '✓ Removes excess white space',
          '✓ Uses advanced AI background removal',
        ];
        result = 'Clean, studio-quality product shots perfect for professional e-commerce listings';
        break;
      case 'service':
        description = 'Enhanced photos showing your service environment or workspace.';
        features = [
          '✓ Original background preserved',
          '✓ Enhanced brightness (+5%)',
          '✓ Improved color saturation (+10%)',
          '✓ Maintains location context',
          '✓ Natural studio lighting effect',
        ];
        result = 'Your service location with enhanced lighting and colors while keeping the environment visible';
        break;
      case 'person':
        description = 'Natural-looking portraits for profiles, teams, and headshots.';
        features = [
          '✓ Original background preserved',
          '✓ Enhanced brightness (+5%)',
          '✓ Improved color saturation (+10%)',
          '✓ Natural environment maintained',
          '✓ Professional portrait enhancement',
        ];
        result = 'Natural portraits with enhanced lighting while preserving the original setting';
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Row(
            children: [
              Icon(
                category == 'product' ? Icons.shopping_bag :
                category == 'service' ? Icons.handshake : Icons.person,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enhancement Features:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    feature,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? Colors.grey.shade300 : Colors.grey[700],
                    ),
                  ),
                )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark ? Colors.white : Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }
}
