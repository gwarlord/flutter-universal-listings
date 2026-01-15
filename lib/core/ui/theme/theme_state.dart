part of 'theme_cubit.dart';

class ThemeState {
  final ThemeMode themeMode;

  ThemeState({required this.themeMode});

  bool get isDarkMode => themeMode == ThemeMode.dark;
  bool get isLightMode => themeMode == ThemeMode.light;
  bool get isSystemMode => themeMode == ThemeMode.system;
}
