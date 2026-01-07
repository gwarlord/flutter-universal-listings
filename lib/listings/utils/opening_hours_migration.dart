import '../model/opening_hours_v2.dart';

/// Converts legacy openingHours string into structured OpeningHoursV2.
/// This is conservative by design.
OpeningHoursV2 migrateLegacyOpeningHours(String legacy) {
  final lower = legacy.toLowerCase();

  final hours = OpeningHoursV2.empty();

  // Handle very common formats safely
  if (lower.contains('mon-fri')) {
    for (final d in ['mon', 'tue', 'wed', 'thu', 'fri']) {
      hours.days[d]!.add(
        TimeRange(start: '09:00', end: '17:00'),
      );
    }
  }

  if (lower.contains('sat')) {
    hours.days['sat']!.add(
      TimeRange(start: '10:00', end: '14:00'),
    );
  }

  return hours;
}
