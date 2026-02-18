import 'package:flutter/material.dart';
import 'package:caribtap/listings/constants/tap_constants.dart';
import 'package:caribtap/listings/model/tap_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;

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
        badgeColor = Color(cfg.colorPrimary);
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
          color: Color(cfg.colorPrimary),
        ),
        const SizedBox(width: 4),
        Text(
          tapCount.toString(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: Color(cfg.colorPrimary),
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

/// Premium Tap to Vouch button with water ripple effect
class TapVouchButton extends StatefulWidget {
  final bool isTapped;
  final int tapCount;
  final String? badgeText;
  final VoidCallback onTap;
  final bool enabled;

  const TapVouchButton({
    Key? key,
    required this.isTapped,
    required this.tapCount,
    required this.onTap,
    this.badgeText,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<TapVouchButton> createState() => _TapVouchButtonState();
}

class _TapVouchButtonState extends State<TapVouchButton> with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _rippleController;
  late final AnimationController _burstController;
  late final AnimationController _iconPulseController;

  late final Animation<double> _pressScale;
  late final Animation<double> _rippleProgress;
  late final Animation<double> _rippleOpacity;
  late final Animation<double> _burstProgress;
  late final Animation<double> _burstOpacity;
  late final Animation<double> _iconPulse;

  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 520),
      vsync: this,
    );
    _burstController = AnimationController(
      duration: const Duration(milliseconds: 480),
      vsync: this,
    );
    _iconPulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _pressScale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
    _rippleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOutCubic),
    );
    _rippleOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOutCubic),
    );
    _burstProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _burstController, curve: Curves.easeOutCubic),
    );
    _burstOpacity = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: _burstController, curve: Curves.easeOutCubic),
    );
    _iconPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconPulseController, curve: Curves.easeInOut),
    );

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _iconPulseController.stop();
      _iconPulseController.value = 0.0;
    } else if (!_iconPulseController.isAnimating) {
      _iconPulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TapVouchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion && widget.isTapped && !oldWidget.isTapped) {
      _burstController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _rippleController.dispose();
    _burstController.dispose();
    _iconPulseController.dispose();
    super.dispose();
  }

  void _startRipple(Offset localPosition) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _tapPosition = localPosition;
    if (!reduceMotion) {
      _rippleController.forward(from: 0.0);
    }
  }

  void _handleTap() {
    if (!widget.enabled) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final primary = Color(cfg.colorPrimary);
    final gradient = LinearGradient(
      colors: [
        const Color(0xFF20C4B4),
        const Color(0xFF1B75D0),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    // Brighter, more saturated version when vouched
    final tappedOverlay = LinearGradient(
      colors: [
        const Color(0xFF2FE3D8),
        const Color(0xFF3BA5FF),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final contentColor = Colors.white;
    final badgeText = (widget.badgeText ?? '').trim();
    final labelText = widget.isTapped ? 'Vouched'.tr() : tapButtonText.tr();
    final microText = widget.isTapped ? 'You vouched'.tr() : 'Vouch for credibility'.tr();
    final countText = '${widget.tapCount} ${'community taps'.tr()}';

    return RepaintBoundary(
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: 'Tap to vouch for this business'.tr(),
        child: AnimatedBuilder(
          animation: _pressScale,
          builder: (context, child) => Transform.scale(
            scale: reduceMotion ? 1.0 : _pressScale.value,
            child: child,
          ),
          child: GestureDetector(
            onTapDown: widget.enabled
                ? (details) {
                    if (!reduceMotion) {
                      _pressController.forward();
                    }
                    _startRipple(details.localPosition);
                  }
                : null,
            onTapUp: widget.enabled
                ? (_) {
                    if (!reduceMotion) _pressController.reverse();
                  }
                : null,
            onTapCancel: widget.enabled
                ? () {
                    if (!reduceMotion) _pressController.reverse();
                  }
                : null,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              elevation: widget.enabled ? 4 : 0,
              shadowColor: primary.withOpacity(0.22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: widget.enabled
                            ? (widget.isTapped ? tappedOverlay : gradient)
                            : null,
                        color: widget.enabled
                            ? null
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: WaterRippleIcon(
                                        key: ValueKey<bool>(widget.isTapped),
                                        isActive: widget.isTapped,
                                        color: contentColor,
                                        size: 22,
                                        pulse: _iconPulse.value,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            labelText,
                                            style: TextStyle(
                                              color: contentColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              microText,
                                              style: TextStyle(
                                                color: contentColor.withOpacity(0.85),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (badgeText.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Verified by people who vouch for this business’s credibility.'.tr(),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.16),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: Colors.white.withOpacity(0.28)),
                                          ),
                                          child: Text(
                                            badgeText,
                                            style: TextStyle(
                                              color: contentColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                                ),
                                child: Text(
                                  countText,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: contentColor.withOpacity(0.95),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _rippleController,
                            _burstController,
                          ]),
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _WaterRipplePainter(
                                tapPosition: _tapPosition,
                                progress: _rippleProgress.value,
                                opacity: _rippleOpacity.value,
                                burstProgress: _burstProgress.value,
                                burstOpacity: _burstOpacity.value,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.enabled ? _handleTap : null,
                          splashColor: Colors.white.withOpacity(0.06),
                          highlightColor: Colors.white.withOpacity(0.04),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterRipplePainter extends CustomPainter {
  final Offset tapPosition;
  final double progress;
  final double opacity;
  final double burstProgress;
  final double burstOpacity;
  final Color color;

  _WaterRipplePainter({
    required this.tapPosition,
    required this.progress,
    required this.opacity,
    required this.burstProgress,
    required this.burstOpacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 && burstProgress <= 0) return;

    final maxRadius = size.longestSide * 0.9;
    final center = tapPosition == Offset.zero
        ? Offset(size.width * 0.5, size.height * 0.5)
        : tapPosition;

    if (progress > 0) {
      _paintRings(
        canvas,
        center,
        maxRadius * progress,
        opacity,
      );
    }

    if (burstProgress > 0) {
      _paintRings(
        canvas,
        Offset(size.width * 0.5, size.height * 0.5),
        maxRadius * (0.6 + burstProgress * 0.5),
        burstOpacity,
      );
    }
  }

  void _paintRings(Canvas canvas, Offset center, double baseRadius, double alpha) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..color = color.withOpacity(alpha.clamp(0.0, 1.0));

    for (int i = 0; i < 3; i++) {
      final ringOpacity = (alpha - i * 0.12).clamp(0.0, 1.0);
      if (ringOpacity <= 0) continue;
      ringPaint.color = color.withOpacity(ringOpacity);
      final radius = baseRadius + (i * 10);
      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity ||
        oldDelegate.burstProgress != burstProgress ||
        oldDelegate.burstOpacity != burstOpacity ||
        oldDelegate.tapPosition != tapPosition;
  }
}

class WaterRippleIcon extends StatelessWidget {
  final bool isActive;
  final double size;
  final Color color;
  final double pulse;

  const WaterRippleIcon({
    Key? key,
    required this.isActive,
    required this.size,
    required this.color,
    required this.pulse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Show thumbs up when vouched, water ripple when not
    if (isActive) {
      return Icon(
        Icons.thumb_up_rounded,
        size: size,
        color: color,
      );
    }
    
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WaterRippleIconPainter(
          color: color,
          isActive: isActive,
          pulse: pulse,
        ),
      ),
    );
  }
}

class _WaterRippleIconPainter extends CustomPainter {
  final Color color;
  final bool isActive;
  final double pulse;

  _WaterRippleIconPainter({
    required this.color,
    required this.isActive,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final baseRadius = size.width * 0.16;
    final pulseScale = 1.0 + (pulse * 0.08);
    final pulseFade = 1.0 - (pulse * 0.2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
      ..color = color.withOpacity((isActive ? 0.95 : 0.8) * pulseFade);

    // Center dot
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(isActive ? 1.0 : 0.85);
    canvas.drawCircle(center, baseRadius * 0.6 * pulseScale, dotPaint);

    // Concentric rings
    for (int i = 1; i <= 3; i++) {
      final opacity = (isActive ? 0.9 : 0.7) - (i * 0.15);
      if (opacity <= 0) continue;
      ringPaint.color = color.withOpacity((opacity * pulseFade).clamp(0.0, 1.0));
      canvas.drawCircle(center, baseRadius * (1.0 + i * 0.9) * pulseScale, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterRippleIconPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isActive != isActive ||
        oldDelegate.pulse != pulse;
  }
}

class _TapButtonState extends State<TapButton> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (!widget.isTapped) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TapButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTapped != oldWidget.isTapped) {
      if (widget.isTapped) {
        _pulseController.stop();
        _pulseController.value = 0.0; // Reset to base value
      } else {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
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
    final primaryColor = Color(cfg.colorPrimary);

    return ScaleTransition(
      scale: widget.isTapped ? _scaleAnimation : _pulseAnimation,
      child: GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) => _animationController.reverse(),
        onTapCancel: () => _animationController.reverse(),
        child: Material(
          elevation: widget.isTapped ? 0 : 2,
          shadowColor: primaryColor.withOpacity(0.3),
          color: widget.isTapped
              ? primaryColor.withOpacity(isDark ? 0.3 : 0.1)
              : (isDark ? Colors.grey.shade800 : Colors.white),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: widget.isLoading ? null : _handleTap,
            borderRadius: BorderRadius.circular(24),
            splashColor: primaryColor.withOpacity(0.2),
            highlightColor: primaryColor.withOpacity(0.1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isTapped ? primaryColor : (isDark ? Colors.grey.shade600 : primaryColor.withOpacity(0.3)),
                  width: 2,
                ),
              ),
              child: widget.isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isTapped ? Icons.how_to_reg : Icons.how_to_reg_outlined,
                          color: widget.isTapped ? (isDark ? Colors.white : primaryColor) : primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.isTapped ? untapButtonText.tr() : tapButtonText.tr(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: widget.isTapped
                                    ? (isDark ? Colors.white : primaryColor)
                                    : (isDark ? Colors.white : primaryColor),
                              ),
                            ),
                            if (widget.tapCount > 0)
                              Text(
                                '${'taps'.tr()}: ${widget.tapCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isTapped
                                      ? (isDark ? Colors.white70 : primaryColor.withOpacity(0.8))
                                      : (isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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
    final primaryColor = Color(cfg.colorPrimary);
    
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Icon(Icons.how_to_reg, size: 40, color: primaryColor),
          const SizedBox(height: 12),
          Text(
            tapDialogTitle.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tapDialogMessage.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 24),
            Text(
              'Why are you vouching? (optional)'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            ...TapReason.values.map((reason) => Theme(
                  data: Theme.of(context).copyWith(
                    radioTheme: RadioThemeData(
                      fillColor: MaterialStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(MaterialState.selected)) {
                          return primaryColor;
                        }
                        return isDark ? Colors.white70 : Colors.grey.shade600;
                      }),
                    ),
                  ),
                  child: RadioListTile<TapReason>(
                    title: Text(
                      reason.displayText.tr(),
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    activeColor: primaryColor,
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                )),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancel'.tr(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(selectedReason),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Vouch Now'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
