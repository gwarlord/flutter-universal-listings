import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  late SharedPreferences _prefs;
  static const String _themeKey = 'theme_mode';

  ThemeCubit() : super(ThemeState(themeMode: ThemeMode.light)) {
    _initTheme();
  }

  Future<void> _initTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs.getString(_themeKey);
    
    if (savedTheme != null) {
      final themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == 'ThemeMode.$savedTheme',
        orElse: () => ThemeMode.system,
      );
      emit(ThemeState(themeMode: themeMode));
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    await _prefs.setString(_themeKey, themeMode.toString().split('.').last);
    emit(ThemeState(themeMode: themeMode));
  }

  void toggleTheme(bool isDarkMode) {
    final newTheme = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newTheme);
  }
}
