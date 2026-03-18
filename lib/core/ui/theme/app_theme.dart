import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color cardBackground;
  final Color cardBorder;
  final Color mutedText;
  final Color subtleBackground;
  final Color inputFill;
  final Color inputHint;

  const AppThemeColors({
    required this.cardBackground,
    required this.cardBorder,
    required this.mutedText,
    required this.subtleBackground,
    required this.inputFill,
    required this.inputHint,
  });

  static const AppThemeColors light = AppThemeColors(
    cardBackground: Colors.white,
    cardBorder: Color(0xFFB7DBD9),
    mutedText: Color(0xFF517C80),
    subtleBackground: Color(0xFFE2F2F1),
    inputFill: Colors.white,
    inputHint: Color(0xFF517C80),
  );

  static const AppThemeColors dark = AppThemeColors(
    cardBackground: Color(0xFF1F1F1F),
    cardBorder: Color(0xFF2C2C2C),
    mutedText: Color(0xFFB0B0B0),
    subtleBackground: Color(0xFF2A2A2A),
    inputFill: Color(0xFF121212),
    inputHint: Color(0xFF9CA3AF),
  );

  @override
  AppThemeColors copyWith({
    Color? cardBackground,
    Color? cardBorder,
    Color? mutedText,
    Color? subtleBackground,
    Color? inputFill,
    Color? inputHint,
  }) {
    return AppThemeColors(
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      mutedText: mutedText ?? this.mutedText,
      subtleBackground: subtleBackground ?? this.subtleBackground,
      inputFill: inputFill ?? this.inputFill,
      inputHint: inputHint ?? this.inputHint,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) {
      return this;
    }

    return AppThemeColors(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      subtleBackground: Color.lerp(subtleBackground, other.subtleBackground, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputHint: Color.lerp(inputHint, other.inputHint, t)!,
    );
  }
}

class AppTheme {
  static bool get _isIosPlatform => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _isAndroidPlatform => defaultTargetPlatform == TargetPlatform.android;

  static TextTheme _platformTextTheme(TextTheme baseTheme) {
    if (_isAndroidPlatform) {
      return GoogleFonts.interTextTheme(baseTheme);
    }
    if (_isIosPlatform) {
      return baseTheme.apply(fontFamily: 'SF-Pro-Text');
    }
    return baseTheme;
  }

  static TextStyle _platformAppBarTitleTextStyle() {
    const base = TextStyle(
      color: Colors.white,
      fontSize: 20.0,
      fontWeight: FontWeight.w500,
    );

    if (_isAndroidPlatform) {
      return GoogleFonts.inter(textStyle: base);
    }
    if (_isIosPlatform) {
      return base.copyWith(fontFamily: 'SF-Pro-Text');
    }
    return base;
  }

  static ThemeData light({required Color primary, required Color accent, required bool isIos}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      onSurface: const Color(0xFF1C1C13),
    );

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: const Color(0xFFF1FBFC),
      colorScheme: colorScheme,
      textTheme: _platformTextTheme(ThemeData.light().textTheme),
      textSelectionTheme: TextSelectionThemeData(cursorColor: primary),
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: primary,
        surfaceTintColor: Colors.transparent,
        elevation: isIos ? 0 : null,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: _platformAppBarTitleTextStyle(),
      ),
      extensions: const [AppThemeColors.light],
    );
  }

  static ThemeData dark({required Color primary, required Color accent}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surface: const Color(0xFF1E1E1E),
      onSurface: Colors.white,
    );

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: colorScheme,
      textTheme: _platformTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: primary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _platformAppBarTitleTextStyle(),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extensions: const [AppThemeColors.dark],
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeColors get appThemeColors {
    final extension = Theme.of(this).extension<AppThemeColors>();
    if (extension != null) {
      return extension;
    }
    return Theme.of(this).brightness == Brightness.dark
        ? AppThemeColors.dark
        : AppThemeColors.light;
  }
}
