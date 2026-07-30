// ignore_for_file: public_member_api_docs, sort_constructors_first
class History {
  String pcName;
  String userName;
  DateTime time;
  String log;

  History({
    required this.pcName,
    required this.userName,
    required this.time,
    required this.log,
  });

  Map<String, dynamic> toMap() => {
    'pcName': pcName,
    'userName': userName,
    'time': time,
    'log': log,
  };

  factory History.fromMap(Map<String, dynamic> map) {
    return History(
      pcName: (map['pcName'] as String?) ?? '',
      userName: (map['userName'] as String?) ?? '',
      time: map['time'] is DateTime
          ? map['time'] as DateTime
          : DateTime.tryParse(map['time']?.toString() ?? '') ?? DateTime.now(),
      log: (map['log'] as String?) ?? '',
    );
  }

  @override
  String toString() =>
      'History(pcName: $pcName, userName: $userName, time: $time, log: $log)';
}
