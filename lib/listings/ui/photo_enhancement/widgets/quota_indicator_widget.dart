import 'package:caribtap/listings/ui/photo_enhancement/cubit/cubit.dart';
import 'package:caribtap/listings/ui/photo_enhancement/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Displays quota indicator with remaining enhancements
class QuotaIndicatorWidget extends StatelessWidget {
  final EnhancementQuota quota;
  final bool showDetails;
  final TextStyle? textStyle;

  const QuotaIndicatorWidget({
    Key? key,
    required this.quota,
    this.showDetails = true,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final remaining = quota.getRemainingQuota();
    final percentage = remaining / EnhancementQuota.monthlyLimit;
    final color = percentage > 0.3
        ? Colors.green
        : percentage > 0.1
            ? Colors.orange
            : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDetails) ...[
          Text(
            'Monthly Enhancement Quota',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$remaining/10',
              style: textStyle ??
                  TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 14,
                  ),
            ),
          ],
        ),
        if (showDetails && quota.isQuotaExhausted()) ...[
          const SizedBox(height: 8),
          Text(
            'Quota exhausted. Resets on ${quota.monthResetDate.toString().split(' ')[0]}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
