import 'package:caribtap/listings/ui/photo_enhancement/models/models.dart';
import 'package:caribtap/listings/ui/photo_enhancement/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Shows before/after comparison of enhanced image
class ComparisonViewWidget extends StatefulWidget {
  final EnhancementResponse enhancement;
  final String originalImagePath;
  final List<String> appliedEnhancements;
  final bool isPreview;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final UserEnhancementQuota? userQuota;

  const ComparisonViewWidget({
    Key? key,
    required this.enhancement,
    required this.originalImagePath,
    required this.appliedEnhancements,
    this.isPreview = false,
    required this.onApprove,
    required this.onReject,
    this.userQuota,
  }) : super(key: key);

  @override
  State<ComparisonViewWidget> createState() => _ComparisonViewWidgetState();
}

class _ComparisonViewWidgetState extends State<ComparisonViewWidget> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                'Before & After Comparison',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              if (widget.isPreview) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _showOriginal = !_showOriginal;
            });
          },
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _showOriginal
                        ? widget.enhancement.originalImageUrl
                        : widget.enhancement.enhancedImageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _showOriginal ? 'Original' : 'Enhanced',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isPreview
              ? 'Preview mode - Tap Approve to process full quality'
              : 'Tap image to switch between original and enhanced',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        _buildEnhancementsList(isDark),
        const SizedBox(height: 16),
        // Show user quota status
        if (widget.userQuota != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CompactUsageCounterWidget(
              quota: widget.userQuota!,
              mainAxisAlignment: MainAxisAlignment.start,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onReject,
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onApprove,
                icon: const Icon(Icons.check),
                label: const Text('Approve & Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 80), // Bottom padding for button accessibility
      ],
    );
  }

  Widget _buildEnhancementsList(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.blue[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enhancements Applied:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.appliedEnhancements.map((enhancement) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: isDark ? Colors.green[400] : Colors.green[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatEnhancementName(enhancement),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          if (widget.enhancement.hasDisclosureBadge)
            Row(
              children: [
                Icon(
                  Icons.info,
                  size: 16,
                  color: isDark ? Colors.orange[400] : Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"Enhanced for clarity" badge will be added',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatEnhancementName(String enhancement) {
    return enhancement
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
