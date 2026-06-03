// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'package:attandance_client/main.dart';
import 'package:mongo_dart/mongo_dart.dart';

class ShiftRegister {
  String objectId;
  String empId;
  String name;
  DateTime fromDate;
  DateTime toDate;
  String shift;

  ShiftRegister({
    required this.objectId,
    required this.empId,
    required this.name,
    required this.fromDate,
    required this.toDate,
    required this.shift,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'empId': empId,
      'name': name,
      'fromDate': fromDate.toUtcKeepValue(),
      'toDate': toDate.toUtcKeepValue(),
      'shift': shift,
    };
  }

  factory ShiftRegister.fromMap(Map<String, dynamic> map) {
    return ShiftRegister(
      objectId: (map['_id'] as ObjectId).oid,
      empId: map['empId'] as String,
      name: map['name'] as String,
      fromDate: map['fromDate'] as DateTime,
      toDate: map['toDate'] as DateTime,
      shift: map['shift'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ShiftRegister.fromJson(String source) =>
      ShiftRegister.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ShiftRegister(objectId: $objectId, empId: $empId, name: $name, fromDate: $fromDate, toDate: $toDate, shift: $shift)';
  }
}
