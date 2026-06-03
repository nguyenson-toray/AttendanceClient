// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Employee {
  String? empId = 'TIQN-';
  int? attFingerId = 0;
  String? name = "Nguyễn Văn A";
  String? department = 'Production';
  String? section = 'Production';
  String? group = 'Line 1';
  String? gender = 'Female';
  String? position = 'Sewing Worker';
  String? level = 'Worker';
  String? directIndirect = 'Direct';
  String? sewingNonSewing = 'Sewing';
  String? supporting = '';
  DateTime? dob;
  DateTime? joiningDate = DateTime.utc(1900, 1, 1);
  String? workStatus = 'Working';
  DateTime? resignOn = DateTime.utc(2099, 12, 31);
  DateTime? maternityBegin = DateTime.utc(2099, 12, 31);
  DateTime? maternityLeaveBegin = DateTime.utc(2099, 12, 31);
  DateTime? maternityLeaveEnd = DateTime.utc(2099, 12, 31);
  DateTime? maternityEnd = DateTime.utc(2099, 12, 31);
  Employee({
    this.empId,
    this.attFingerId,
    this.name,
    this.department,
    this.section,
    this.group,
    this.gender,
    this.position,
    this.level,
    this.directIndirect,
    this.sewingNonSewing,
    this.supporting,
    this.dob,
    this.joiningDate,
    this.workStatus,
    this.resignOn,
    this.maternityBegin,
    this.maternityLeaveBegin,
    this.maternityLeaveEnd,
    this.maternityEnd,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'empId': empId,
      'attFingerId': attFingerId,
      'name': name,
      'department': department,
      'section': section,
      'group': group,
      'gender': gender,
      'position': position,
      'level': level,
      'directIndirect': directIndirect,
      'sewingNonSewing': sewingNonSewing,
      'supporting': supporting,
      'dob': dob?.millisecondsSinceEpoch,
      'joiningDate': joiningDate?.millisecondsSinceEpoch,
      'workStatus': workStatus,
      'resignOn': resignOn?.millisecondsSinceEpoch,
      'maternityBegin': maternityBegin?.millisecondsSinceEpoch,
      'maternityLeaveBegin': maternityLeaveBegin?.millisecondsSinceEpoch,
      'maternityLeaveEnd': maternityLeaveEnd?.millisecondsSinceEpoch,
      'maternityEnd': maternityEnd?.millisecondsSinceEpoch,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      empId: map['empId'] != null ? map['empId'] as String : null,
      attFingerId: map['attFingerId'] != null
          ? map['attFingerId'] as int
          : null,
      name: map['name'] != null ? map['name'] as String : null,
      department: map['department'] != null
          ? map['department'] as String
          : null,
      section: map['section'] != null ? map['section'] as String : null,
      group: map['group'] != null ? map['group'] as String : null,
      gender: map['gender'] != null ? map['gender'] as String : null,
      position: map['position'] != null ? map['position'] as String : null,
      level: map['level'] != null ? map['level'] as String : null,
      directIndirect: map['directIndirect'] != null
          ? map['directIndirect'] as String
          : null,
      sewingNonSewing: map['sewingNonSewing'] != null
          ? map['sewingNonSewing'] as String
          : null,
      supporting: map['supporting'] != null
          ? map['supporting'] as String
          : null,
      dob: map['dob'] != null ? map['dob'] : null,
      joiningDate: map['joiningDate'] != null ? map['joiningDate'] : null,
      workStatus: map['workStatus'] != null
          ? map['workStatus'] as String
          : null,
      resignOn: map['resignOn'] != null ? map['resignOn'] : null,
      maternityBegin: map['maternityBegin'] != null
          ? map['maternityBegin']
          : null,
      maternityLeaveBegin: map['maternityLeaveBegin'] != null
          ? map['maternityLeaveBegin']
          : null,
      maternityLeaveEnd: map['maternityLeaveEnd'] != null
          ? map['maternityLeaveEnd']
          : null,
      maternityEnd: map['maternityEnd'] != null ? map['maternityEnd'] : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Employee.fromJson(String source) =>
      Employee.fromMap(json.decode(source) as Map<String, dynamic>);
}
