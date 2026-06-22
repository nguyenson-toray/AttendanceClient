// ignore_for_file: public_member_api_docs, sort_constructors_first
class TimesheetSettings {
  int minOtMinute;
  int otBlockMinute;
  int workingBlockMinute;
  bool allowOtInRestTime;
  List<String> excludeEmpIds;

  TimesheetSettings({
    this.minOtMinute = 30,
    this.otBlockMinute = 1,
    this.workingBlockMinute = 1,
    this.allowOtInRestTime = false,
    this.excludeEmpIds = const [],
  });

  Map<String, dynamic> toMap() => {
    'minOtMinute': minOtMinute,
    'otBlockMinute': otBlockMinute,
    'workingBlockMinute': workingBlockMinute,
    'allowOtInRestTime': allowOtInRestTime,
    'excludeEmpIds': excludeEmpIds,
  };

  factory TimesheetSettings.fromMap(Map<String, dynamic> map) {
    final rawExclude = map['excludeEmpIds'];
    final excludeList = rawExclude is List
        ? rawExclude.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : rawExclude is String && rawExclude.trim().isNotEmpty
            ? rawExclude.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : <String>[];
    return TimesheetSettings(
      minOtMinute: (map['minOtMinute'] as num?)?.toInt() ?? 30,
      otBlockMinute: (map['otBlockMinute'] as num?)?.toInt() ?? 1,
      workingBlockMinute: (map['workingBlockMinute'] as num?)?.toInt() ?? 1,
      allowOtInRestTime: (map['allowOtInRestTime'] as bool?) ?? false,
      excludeEmpIds: excludeList,
    );
  }

  @override
  String toString() =>
      'TimesheetSettings(minOtMinute: $minOtMinute, otBlockMinute: $otBlockMinute, workingBlockMinute: $workingBlockMinute, allowOtInRestTime: $allowOtInRestTime, excludeEmpIds: $excludeEmpIds)';
}
