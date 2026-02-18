import 'package:flutter/material.dart';

/// Shows processing progress for enhancement
class EnhancementProgressWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String message;
  final bool showPercentage;

  const EnhancementProgressWidget({
    Key? key,
    required this.progress,
    required this.message,
    this.showPercentage = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (showPercentage)
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
