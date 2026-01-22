import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdSeasonalityHelper {
  /// Returns a multiplier for the price based on the current date (seasonality logic)
  static double getSeasonalMultiplier(DateTime date) {
    // Example: Higher rates in December and July (peak months)
    if (date.month == 12 || date.month == 7) {
      return 1.5;
    }
    // Example: Lower rates in September
    if (date.month == 9) {
      return 0.8;
    }
    return 1.0;
  }

  /// Returns a human-readable label for the current season
  static String getSeasonLabel(DateTime date) {
    if (date.month == 12 || date.month == 7) {
      return 'Peak Season';
    }
    if (date.month == 9) {
      return 'Low Season';
    }
    return 'Regular Season';
  }
}
