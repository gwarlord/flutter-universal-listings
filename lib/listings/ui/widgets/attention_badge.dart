import 'package:flutter/material.dart';
import 'package:instaflutter/listings/model/attention_state_model.dart';

// A distinct, vibrant color for notifications.
const _kAttentionColor = Color(0xFF009688); // Teal

/// Widget to display attention badge (dot or count) on UI elements
class AttentionBadge extends StatelessWidget {
  final AttentionStateModel attentionState;
  final AttentionModule module;
  final Color? badgeColor;
  final double badgeSize;
  final Color? textColor;

  const AttentionBadge({
    super.key,
    required this.attentionState,
    required this.module,
    this.badgeColor,
    this.badgeSize = 20,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final count = attentionState.getCountForModule(module);
    
    if (count == 0) {
      return const SizedBox.shrink();
    }

    final displayText = attentionState.getDisplayCount(module);
    final bgColor = badgeColor ?? _kAttentionColor;
    final txtColor = textColor ?? Colors.white; // White text for good contrast on teal

    return Container(
      height: badgeSize,
      width: badgeSize,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.6),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: displayText.isEmpty
            ? const SizedBox.shrink()
            : Text(
                displayText,
                style: TextStyle(
                  color: txtColor,
                  fontSize: badgeSize * 0.5,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}

/// Small dot indicator with no count
class AttentionDot extends StatelessWidget {
  final bool hasAttention;
  final Color? dotColor;
  final double dotSize;

  const AttentionDot({
    super.key,
    required this.hasAttention,
    this.dotColor,
    this.dotSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasAttention) {
      return const SizedBox.shrink();
    }

    final color = dotColor ?? _kAttentionColor;

    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5), // Add border for contrast
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.7),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// Inline badge for drawer/menu items with proper trailing alignment
class BadgeWithIcon extends StatelessWidget {
  final Widget icon;
  final AttentionStateModel attentionState;
  final AttentionModule module;
  final Color? badgeColor;

  const BadgeWithIcon({
    super.key,
    required this.icon,
    required this.attentionState,
    required this.module,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final count = attentionState.getCountForModule(module);

    if (count == 0) {
      return icon;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -8,
          top: -8,
          child: AttentionBadge(
            attentionState: attentionState,
            module: module,
            badgeSize: 18,
            badgeColor: badgeColor ?? _kAttentionColor,
          ),
        ),
      ],
    );
  }
}
