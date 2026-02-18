import 'package:flutter/material.dart';

/// Button to trigger photo enhancement workflow
class EnhanceButtonWidget extends StatelessWidget {
  final VoidCallback onPressed;
  final bool enabled;
  final String label;
  final IconData icon;
  final double? width;
  final VoidCallback? onLongPress;

  const EnhanceButtonWidget({
    Key? key,
    required this.onPressed,
    this.enabled = true,
    this.label = 'Enhance Photo',
    this.icon = Icons.auto_fix_high,
    this.width,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Colors.blue : Colors.grey[400],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onLongPress: onLongPress,
      ),
    );
  }
}
