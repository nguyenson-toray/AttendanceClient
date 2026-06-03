// ignore_for_file: public_member_api_docs, sort_constructors_first
class History {
  String pcName;
  DateTime time;
  String log;

  History({required this.pcName, required this.time, required this.log});

  Map<String, dynamic> toMap() => {'pcName': pcName, 'time': time, 'log': log};

  factory History.fromMap(Map<String, dynamic> map) {
    return History(
      pcName: (map['pcName'] as String?) ?? '',
      time: map['time'] is DateTime
          ? map['time'] as DateTime
          : DateTime.tryParse(map['time']?.toString() ?? '') ?? DateTime.now(),
      log: (map['log'] as String?) ?? '',
    );
  }

  @override
  String toString() => 'History(pcName: $pcName, time: $time, log: $log)';
}
