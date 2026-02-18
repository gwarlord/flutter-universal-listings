import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/ui/photo_enhancement/models/user_enhancement_quota.dart';
import 'package:flutter/material.dart';

/// Displays user enhancement usage counters
class UsageCounterWidget extends StatelessWidget {
  final UserEnhancementQuota quota;
  final bool compact;
  final TextStyle? textStyle;

  const UsageCounterWidget({
    Key? key,
    required this.quota,
    this.compact = false,
    this.textStyle,
  }) : super(key: key);

  Color _getEnhancementColor() {
    final remaining = quota.getRemainingEnhancementQuota();
    if (remaining > 5) return Colors.green;
    if (remaining > 2) return Colors.orange;
    return Colors.red;
  }

  Color _getPreviewColor() {
    final remaining = quota.getRemainingPreviewQuota();
    if (remaining > 5) return Colors.green;
    if (remaining > 2) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final baseStyle = textStyle ??
        TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        );

    if (compact) {
      // Compact format: "Enhancements: 1/10 | Previews: 3/10"
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enhancements: ',
            style: baseStyle,
          ),
          Text(
            '${quota.enhancementsUsed}/${UserEnhancementQuota.monthlyLimit}',
            style: baseStyle.copyWith(color: _getEnhancementColor()),
          ),
          Text(
            ' | Previews: ',
            style: baseStyle,
          ),
          Text(
            '${quota.previewsUsed}/${UserEnhancementQuota.monthlyLimit}',
            style: baseStyle.copyWith(color: _getPreviewColor()),
          ),
        ],
      );
    }

    // Full format with icons
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Monthly Quota',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCounterCard(
              icon: Icons.camera_alt_outlined,
              label: 'Enhancements',
              used: quota.enhancementsUsed,
              total: UserEnhancementQuota.monthlyLimit,
              color: _getEnhancementColor(),
              context: context,
            ),
            _buildCounterCard(
              icon: Icons.visibility_outlined,
              label: 'Previews',
              used: quota.previewsUsed,
              total: UserEnhancementQuota.monthlyLimit,
              color: _getPreviewColor(),
              context: context,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            quota.getScheduleInfo(),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterCard({
    required IconData icon,
    required String label,
    required int used,
    required int total,
    required Color color,
    required BuildContext context,
  }) {
    final isDark = isDarkMode(context);
    final percentage = (used / total).clamp(0.0, 1.0);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          color: isDark ? Colors.grey[850] : Colors.blue[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$used/$total',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 4,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact inline usage counter widget
class CompactUsageCounterWidget extends StatelessWidget {
  final UserEnhancementQuota quota;
  final TextStyle? textStyle;
  final MainAxisAlignment mainAxisAlignment;

  const CompactUsageCounterWidget({
    Key? key,
    required this.quota,
    this.textStyle,
    this.mainAxisAlignment = MainAxisAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final baseStyle = textStyle ??
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        );

    Color getEnhancementColor() {
      final remaining = quota.getRemainingEnhancementQuota();
      if (remaining > 5) return Colors.green;
      if (remaining > 2) return Colors.orange;
      return Colors.red;
    }

    Color getPreviewColor() {
      final remaining = quota.getRemainingPreviewQuota();
      if (remaining > 5) return Colors.green;
      if (remaining > 2) return Colors.orange;
      return Colors.red;
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text('Enhancements: ', style: baseStyle),
            Text(
              '${quota.enhancementsUsed}/${UserEnhancementQuota.monthlyLimit}',
              style: baseStyle.copyWith(color: getEnhancementColor()),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text('Previews: ', style: baseStyle),
            Text(
              '${quota.previewsUsed}/${UserEnhancementQuota.monthlyLimit}',
              style: baseStyle.copyWith(color: getPreviewColor()),
            ),
          ],
        ),
      ],
    );
  }
}
