class ShiftParam {
  String name;
  int beginHour;
  int beginMin;
  int endHour;
  int endMin;
  int restHour;
  DateTime effectiveFrom;
  DateTime effectiveTo;

  ShiftParam({
    required this.name,
    required this.beginHour,
    this.beginMin = 0,
    required this.endHour,
    this.endMin = 0,
    required this.restHour,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
  })  : effectiveFrom = effectiveFrom ?? DateTime(2022),
        effectiveTo = effectiveTo ?? DateTime(2099, 12, 31);

  /// Parse "HH:mm" string → [hour, minute]
  static List<int> _parseTime(String s) {
    final parts = s.split(':');
    return [int.parse(parts[0]), parts.length > 1 ? int.parse(parts[1]) : 0];
  }

  Map<String, dynamic> toMap() => {
        'shift': name,
        'begin': '${beginHour.toString().padLeft(2, '0')}:${beginMin.toString().padLeft(2, '0')}',
        'end': '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}',
        'restHour': restHour,
        'effectiveFrom': effectiveFrom,
        'effectiveTo': effectiveTo,
      };

  factory ShiftParam.fromMap(Map<String, dynamic> map) {
    final begin = _parseTime(map['begin'] as String? ?? '08:00');
    final end = _parseTime(map['end'] as String? ?? '17:00');
    return ShiftParam(
      name: map['shift'] as String? ?? 'Day',
      beginHour: begin[0],
      beginMin: begin[1],
      endHour: end[0],
      endMin: end[1],
      restHour: (map['restHour'] as num?)?.toInt() ?? 1,
      effectiveFrom: map['effectiveFrom'] is DateTime
          ? map['effectiveFrom'] as DateTime
          : DateTime(2022),
      effectiveTo: map['effectiveTo'] is DateTime
          ? map['effectiveTo'] as DateTime
          : DateTime(2099, 12, 31),
    );
  }

  @override
  String toString() =>
      'ShiftParam($name ${beginHour.toString().padLeft(2, '0')}:${beginMin.toString().padLeft(2, '0')}-${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')} rest:$restHour from:$effectiveFrom to:$effectiveTo)';
}
