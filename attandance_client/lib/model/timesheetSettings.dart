// ignore_for_file: public_member_api_docs, sort_constructors_first
class TimesheetSettings {
  int minOtMinute;
  int otBlockMinute;
  int workingBlockMinute;
  bool allowOtInRestTime;

  TimesheetSettings({
    this.minOtMinute = 30,
    this.otBlockMinute = 1,
    this.workingBlockMinute = 1,
    this.allowOtInRestTime = false,
  });

  Map<String, dynamic> toMap() => {
    'minOtMinute': minOtMinute,
    'otBlockMinute': otBlockMinute,
    'workingBlockMinute': workingBlockMinute,
    'allowOtInRestTime': allowOtInRestTime,
  };

  factory TimesheetSettings.fromMap(Map<String, dynamic> map) {
    return TimesheetSettings(
      minOtMinute: (map['minOtMinute'] as num?)?.toInt() ?? 30,
      otBlockMinute: (map['otBlockMinute'] as num?)?.toInt() ?? 1,
      workingBlockMinute: (map['workingBlockMinute'] as num?)?.toInt() ?? 1,
      allowOtInRestTime: (map['allowOtInRestTime'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'TimesheetSettings(minOtMinute: $minOtMinute, otBlockMinute: $otBlockMinute, workingBlockMinute: $workingBlockMinute, allowOtInRestTime: $allowOtInRestTime)';
}
