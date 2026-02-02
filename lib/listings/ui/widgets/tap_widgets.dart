import 'package:flutter/material.dart';
import 'package:instaflutter/listings/constants/tap_constants.dart';
import 'package:instaflutter/listings/model/tap_model.dart';
import 'package:easy_localization/easy_localization.dart';

/// Widget showing tap badge for a listing
class TapBadgeWidget extends StatelessWidget {
  final int tapCount;
  final String tapBadge;
  final bool showCount;
  final double fontSize;

  const TapBadgeWidget({
    Key? key,
    required this.tapCount,
    required this.tapBadge,
    this.showCount = true,
    this.fontSize = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final badge = TapBadge.fromString(tapBadge);
    
    if (badge == null || badge == TapBadge.none) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Color scheme based on badge level
    Color badgeColor;
    IconData badgeIcon;
    
    switch (badge) {
      case TapBadge.communityVerified:
        badgeColor = Colors.green;
        badgeIcon = Icons.verified;
        break;
      case TapBadge.communityVouched:
        badgeColor = Colors.blue;
        badgeIcon = Icons.check_circle;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: fontSize + 2, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badge.displayText,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: isDark ? badgeColor.withOpacity(0.9) : badgeColor,
            ),
          ),
          if (showCount && tapCount > 0) ...[
            const SizedBox(width: 4),
            Text(
              '($tapCount)',
              style: TextStyle(
                fontSize: fontSize - 1,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact tap count display (for listing cards)
class TapCountDisplay extends StatelessWidget {
  final int tapCount;
  final double iconSize;
  final double fontSize;

  const TapCountDisplay({
    Key? key,
    required this.tapCount,
    this.iconSize = 16,
    this.fontSize = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (tapCount <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.how_to_reg_rounded,
          size: iconSize,
          color: Colors.blue,
        ),
        const SizedBox(width: 4),
        Text(
          tapCount.toString(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}

/// Tap button for listing details
class TapButton extends StatefulWidget {
  final bool isTapped;
  final int tapCount;
  final VoidCallback onTap;
  final bool isLoading;

  const TapButton({
    Key? key,
    required this.isTapped,
    required this.tapCount,
    required this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends State<TapButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isLoading ? null : _handleTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isTapped
                  ? (isDark ? Colors.blue.shade700 : Colors.blue.shade50)
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isTapped ? Colors.blue : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isTapped ? Icons.how_to_reg : Icons.how_to_reg_outlined,
                        color: widget.isTapped ? Colors.blue : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isTapped ? untapButtonText.tr() : tapButtonText.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.isTapped
                                  ? Colors.blue
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          if (widget.tapCount > 0)
                            Text(
                              '${'taps'.tr()}: ${widget.tapCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Dialog to confirm tap action and optionally select reason
class TapReasonDialog extends StatefulWidget {
  const TapReasonDialog({Key? key}) : super(key: key);

  @override
  State<TapReasonDialog> createState() => _TapReasonDialogState();
}

class _TapReasonDialogState extends State<TapReasonDialog> {
  TapReason? selectedReason;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      title: Text(
        tapDialogTitle.tr(),
        style: TextStyle(color: textColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tapDialogMessage.tr(),
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Why are you vouching? (optional)'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ...TapReason.values.map((reason) => Theme(
                data: Theme.of(context).copyWith(
                  unselectedWidgetColor: isDark ? Colors.white70 : Colors.grey,
                ),
                child: RadioListTile<TapReason>(
                  title: Text(
                    reason.displayText.tr(),
                    style: TextStyle(color: textColor),
                  ),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(selectedReason),
          child: Text('Vouch'.tr()),
        ),
      ],
    );
  }
}
