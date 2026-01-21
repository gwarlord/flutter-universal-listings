class TimeRange {
  final String start;
  final String end;

  TimeRange({required this.start, required this.end});

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
  };
}

class OpeningHoursV2 {
  final Map<String, List<TimeRange>> days;

  OpeningHoursV2(this.days);

  factory OpeningHoursV2.empty() {
    return OpeningHoursV2({
      'mon': [],
      'tue': [],
      'wed': [],
      'thu': [],
      'fri': [],
      'sat': [],
      'sun': [],
    });
  }

  Map<String, dynamic> toJson() => {
    'days': days.map((key, value) => MapEntry(key, value.map((t) => t.toJson()).toList())),
  };
}
