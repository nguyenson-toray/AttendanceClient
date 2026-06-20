import 'dart:io' show Platform;
import 'package:attandance_client/main.dart';
import 'package:attandance_client/model/attLog.dart';
import 'package:attandance_client/model/employee.dart';
import 'package:attandance_client/model/history.dart';
import 'package:attandance_client/model/otRegister.dart';
import 'package:attandance_client/model/shiftRegister.dart';
import 'package:attandance_client/model/shift_param.dart';
import 'package:attandance_client/model/timesheetSettings.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:attandance_client/appLogger.dart';
import 'package:flutter/foundation.dart';

class MongoDb {
  late var colEmployee,
      colAttLog,
      colShift,
      colShiftRegister,
      colOtRegister,
      colConfig,
      colTimesheetsMonthYear,
      colHistory,
      colListPc,
      colLeaveRegister,
      colTimesheetSettings;
  String ipServer = 'localhost';
  String? ipServerOverride;
  Db db = Db("mongodb://localhost:27017/tiqn");
  initDB() async {
    if (ipServerOverride != null) {
      ipServer = ipServerOverride!;
    } else if (kReleaseMode) {
      ipServer = '10.0.1.4';
    } else {
      ipServer = 'localhost';
    }
    db = Db("mongodb://$ipServer:27017/tiqn");
    try {
      await db.open();
      colEmployee = db.collection('Employee');
      colAttLog = db.collection('AttLog');
      colShift = db.collection('Shift');
      colShiftRegister = db.collection('ShiftRegister');
      colOtRegister = db.collection('OtRegister');
      colConfig = db.collection('Config');
      colTimesheetsMonthYear = db.collection('TimesheetsMonthYear');
      colHistory = db.collection('History');
      colListPc = db.collection('ListPc');
      colLeaveRegister = db.collection('LeaveRegister');
      colTimesheetSettings = db.collection('TimesheetSettings');
      logger.t('Connected to MongoDB at $ipServer');
    } catch (e) {
      logger.t(e);
    }
  }

  Future<String> checkPermission(String pcName) async {
    if (kDebugMode) return 'edit';
    late var allowEdit, allowRead;

    try {
      if (!db.isConnected) {
        logger.t('DB not connected, try connect again');
        await initDB();
      }
      await colListPc.find().forEach((item) => {allowEdit = item['allowEdit']});
      await colListPc.find().forEach((item) => {allowRead = item['allowRead']});
    } catch (e) {
      logger.t(e);
    }
    if (allowEdit.contains(pcName)) {
      return 'edit';
    } else if (allowRead.contains(pcName)) {
      return 'read';
    } else {
      return 'deny';
    }
  }

  Future<List<Employee>> getEmployees() async {
    List<Employee> result = [];
    try {
      if (!db.isConnected) {
        logger.t('getEmployees - DB not connected, try connect again');
        await initDB();
      }
      await colEmployee
          .find(where.sortBy('empId', descending: true))
          .forEach((emp) => {result.add(Employee.fromMap(emp))});
      logger.t('getEmployees: ${result.length} employees found');
    } catch (e) {
      logger.t('getEmployees: $e');
    }

    return result;
  }

  Future<void> updateEmployeeMaternity(
    String empId, {
    required DateTime maternityBegin,
    required DateTime maternityLeaveBegin,
    required DateTime maternityLeaveEnd,
    required DateTime maternityEnd,
    String logDetail = '',
  }) async {
    try {
      if (!db.isConnected) await initDB();
      await colEmployee.updateOne(
        where.eq('empId', empId),
        modify
            .set('maternityBegin', maternityBegin.toUtcKeepValue())
            .set('maternityLeaveBegin', maternityLeaveBegin.toUtcKeepValue())
            .set('maternityLeaveEnd', maternityLeaveEnd.toUtcKeepValue())
            .set('maternityEnd', maternityEnd.toUtcKeepValue()),
      );
      await insertHistory(
        'Edit Employee Maternity – ${logDetail.isNotEmpty ? logDetail : empId}',
      );
    } catch (e, st) {
      logger.d('updateEmployeeMaternity ERROR: $e\n$st');
    }
  }

  Future<List<AttLog>> getAttLogs(List<DateTime> attRangeDates) async {
    List<AttLog> result = [];
    DateTime timneBegin = attRangeDates[0];
    DateTime timeEnd = attRangeDates[1];
    try {
      if (!db.isConnected) {
        logger.t('getAttLogs DB not connected, try connect again');
        await initDB();
      }
      await colAttLog
          .find(
            where
                .gt('timestamp', timneBegin)
                .and(where.lt('timestamp', timeEnd))
                .sortBy('timestamp'),
          )
          .forEach((log) => {result.add(AttLog.fromMap(log))});
    } catch (e) {
      logger.t(e);
    }
    logger.t(
      '========> getAttLogs $timneBegin  to $timeEnd => ${result.length} records',
    );
    return result;
  }

  Future<void> deleteAttLog(String objectId, {String logDetail = ''}) async {
    try {
      if (!db.isConnected) {
        logger.t('deleteAttLog DB not connected, try connect again');
        await initDB();
      }
      final oid = ObjectId.fromHexString(objectId);
      logger.d('deleteAttLog: attempting delete oid=$oid hex=$objectId');
      final result = await colAttLog.deleteOne(where.id(oid));
      logger.d('deleteAttLog: result=$result');
      await insertHistory(
        'Delete AttLog – ${logDetail.isNotEmpty ? logDetail : objectId}',
      );
    } catch (e, st) {
      logger.d('deleteAttLog ERROR: $e\n$st');
    }
  }

  Future<void> updateAttLog(
    String objectId,
    DateTime timestamp, {
    String logDetail = '',
  }) async {
    try {
      if (!db.isConnected) {
        logger.t('updateAttLog DB not connected, try connect again');
        await initDB();
      }
      final oid = ObjectId.fromHexString(objectId);
      final result = await colAttLog.updateOne(
        where.id(oid),
        modify.set('timestamp', timestamp.toUtcKeepValue()),
      );
      logger.d('updateAttLog: result=$result');
      await insertHistory(
        'Edit AttLog – ${logDetail.isNotEmpty ? logDetail : objectId}',
      );
    } catch (e, st) {
      logger.d('updateAttLog ERROR: $e\n$st');
    }
  }

  Future<List<OtRegister>> getOvertime(List<DateTime> dateRange) async {
    List<OtRegister> result = [];
    DateTime dateBegin = dateRange[0];
    DateTime dateEnd = dateRange[1];
    try {
      if (!db.isConnected) {
        logger.t('getOvertime DB not connected, try connect again');
        await initDB();
      }
      await colOtRegister
          .find(
            where
                .gte('otDate', dateBegin)
                .and(where.lte('otDate', dateEnd))
                .sortBy('otDate'),
          )
          .forEach((doc) => {result.add(OtRegister.fromMap(doc))});
    } catch (e) {
      logger.t('getOvertime: $e');
    }
    logger.t(
      '========> getOvertime $dateBegin to $dateEnd => ${result.length} records',
    );
    return result;
  }

  Future<void> deleteOtRegister(int id, {String logDetail = ''}) async {
    try {
      if (!db.isConnected) {
        logger.t('deleteOtRegister DB not connected, try connect again');
        await initDB();
      }
      logger.d('deleteOtRegister: attempting delete _id=$id');
      final result = await colOtRegister.deleteOne(where.eq('_id', id));
      logger.d(
        'deleteOtRegister: success=${result.isSuccess}, nRemoved=${result.nRemoved}',
      );
      await insertHistory(
        'Delete OT – ${logDetail.isNotEmpty ? logDetail : 'id=$id'}',
      );
    } catch (e, st) {
      logger.d('deleteOtRegister ERROR: $e\n$st');
    }
  }

  Future<void> deleteOtRegistersByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      if (!db.isConnected) {
        logger.t('deleteOtRegistersByIds DB not connected, try connect again');
        await initDB();
      }
      final result = await colOtRegister.deleteMany(where.oneFrom('_id', ids));
      logger.d(
        'deleteOtRegistersByIds: success=${result.isSuccess}, nRemoved=${result.nRemoved}',
      );
      await insertHistory(
        'Remove OT Duplicates: ${ids.length} records deleted',
      );
    } catch (e, st) {
      logger.d('deleteOtRegistersByIds ERROR: $e\n$st');
    }
  }

  Future<void> updateOtRegister(
    int id,
    DateTime otDate,
    String otTimeBegin,
    String otTimeEnd, {
    String logDetail = '',
  }) async {
    try {
      if (!db.isConnected) {
        logger.t('updateOtRegister DB not connected, try connect again');
        await initDB();
      }
      final result = await colOtRegister.updateOne(
        where.eq('_id', id),
        modify
            .set('otDate', otDate)
            .set('otTimeBegin', otTimeBegin)
            .set('otTimeEnd', otTimeEnd),
      );
      logger.d('updateOtRegister: result=$result');
      await insertHistory(
        'Edit OT – ${logDetail.isNotEmpty ? logDetail : 'id=$id, ${otDate.toIso8601String().substring(0, 10)}, $otTimeBegin-$otTimeEnd'}',
      );
    } catch (e, st) {
      logger.d('updateOtRegister ERROR: $e\n$st');
    }
  }

  Future<void> insertOtRegisters(List<OtRegister> ots) async {
    if (ots.isNotEmpty) {
      try {
        if (!db.isConnected) {
          logger.t('insertOtRegisters DB not connected, try connect again');
          await initDB();
        }
        final maps = ots.map((e) => e.toMap()).toList();
        await colOtRegister.insertMany(maps);
        logger.t('insertOtRegisters: inserted ${ots.length} records');
        final detail = ots
            .map(
              (e) =>
                  '${e.empId} (${e.name}) OT ${e.otDate.toIso8601String().substring(0, 10)} ${e.otTimeBegin}-${e.otTimeEnd}',
            )
            .join('; ');
        await insertHistory('Add OT [${ots.length}]: $detail');
      } catch (e) {
        logger.t('insertOtRegisters: $e');
      }
    }
  }

  Future<List<ShiftRegister>> getShiftRegisters(
    List<DateTime> dateRange,
  ) async {
    List<ShiftRegister> result = [];
    DateTime dateBegin = dateRange[0];
    DateTime dateEnd = dateRange[1];
    try {
      if (!db.isConnected) {
        logger.t('getShiftRegisters DB not connected, try connect again');
        await initDB();
      }
      // Overlap: fromDate <= dateEnd AND toDate >= dateBegin
      await colShiftRegister
          .find(
            where
                .lte('fromDate', dateEnd)
                .and(where.gte('toDate', dateBegin))
                .sortBy('toDate'),
          )
          .forEach((doc) => {result.add(ShiftRegister.fromMap(doc))});
    } catch (e) {
      logger.t('getShiftRegisters: $e');
    }
    logger.t(
      '========> getShiftRegisters overlap [$dateBegin – $dateEnd] => ${result.length} records',
    );
    return result;
  }

  Future<void> updateShiftRegister(
    String objectId,
    DateTime fromDate,
    DateTime toDate,
    String shift, {
    String logDetail = '',
  }) async {
    try {
      if (!db.isConnected) {
        logger.t('updateShiftRegister DB not connected, try connect again');
        await initDB();
      }
      final oid = ObjectId.fromHexString(objectId);
      final result = await colShiftRegister.updateOne(
        where.id(oid),
        modify
            .set('fromDate', fromDate)
            .set('toDate', toDate)
            .set('shift', shift),
      );
      logger.d('updateShiftRegister: result=$result');
      await insertHistory(
        'Edit Shift – ${logDetail.isNotEmpty ? logDetail : objectId}',
      );
    } catch (e, st) {
      logger.d('updateShiftRegister ERROR: $e\n$st');
    }
  }

  Future<void> deleteShiftRegister(
    String objectId, {
    String logDetail = '',
  }) async {
    try {
      if (!db.isConnected) {
        logger.t('deleteShiftRegister DB not connected, try connect again');
        await initDB();
      }
      final oid = ObjectId.fromHexString(objectId);
      logger.d('deleteShiftRegister: attempting delete oid=$oid hex=$objectId');
      final result = await colShiftRegister.deleteOne(where.id(oid));
      logger.d('deleteShiftRegister: result=$result');
      await insertHistory(
        'Delete Shift – ${logDetail.isNotEmpty ? logDetail : objectId}',
      );
    } catch (e, st) {
      logger.d('deleteShiftRegister ERROR: $e\n$st');
    }
  }

  Future<void> insertShiftRegisters(List<ShiftRegister> srs) async {
    if (srs.isNotEmpty) {
      try {
        if (!db.isConnected) {
          logger.t('insertShiftRegisters DB not connected, try connect again');
          await initDB();
        }
        final maps = srs.map((e) => e.toMap()).toList();
        await colShiftRegister.insertMany(maps);
        // Populate objectIds from inserted maps
        for (int i = 0; i < srs.length; i++) {
          if (maps[i]['_id'] is ObjectId) {
            srs[i].objectId = (maps[i]['_id'] as ObjectId).oid;
          }
        }
        logger.t('insertShiftRegisters: inserted ${srs.length} records');
        await insertHistory(
          'AddShift: ${srs.length} records [${srs.map((e) => '${e.empId} ${e.name}/${e.shift} ${e.fromDate.toString()} - ${e.toDate.toString()}').join(', ')}]',
        );
      } catch (e) {
        logger.t('insertShiftRegisters: $e');
      }
    }
  }

  Future<void> insertAttLogs(List<AttLog> logs) async {
    if (logs.isNotEmpty) {
      try {
        if (!db.isConnected) {
          logger.t('insertAttLogs DB not connected, try connect again');
          await initDB();
        }
        List<Map<String, dynamic>> maps = [];
        for (var element in logs) {
          logger.t('insertAttLogs element : $element');
          maps.add(element.toMap());
        }
        await colAttLog.insertMany(maps);
        // Populate objectIds from inserted maps
        for (int i = 0; i < logs.length; i++) {
          if (maps[i]['_id'] is ObjectId) {
            logs[i].objectId = (maps[i]['_id'] as ObjectId).oid;
          }
        }
        await insertHistory(
          'AddAttLog: ${logs.length} records [${logs.map((e) => '${e.empId} ${e.name} ${e.timestamp.toIso8601String().substring(0, 16)}').join(', ')}]',
        );
      } catch (e) {
        logger.t(e);
      }
    }
  }

  // ─── Timesheet Settings ───────────────────────────────────────────────────

  Future<TimesheetSettings> getTimesheetSettings() async {
    try {
      if (!db.isConnected) {
        logger.t('getTimesheetSettings - DB not connected, try connect again');
        await initDB();
      }
      final doc = await colTimesheetSettings.findOne();
      if (doc != null) {
        logger.t('getTimesheetSettings: loaded from DB');
        return TimesheetSettings.fromMap(doc);
      }
    } catch (e) {
      logger.t('getTimesheetSettings: $e');
    }
    logger.t('getTimesheetSettings: using defaults');
    return TimesheetSettings();
  }

  // ─── Shift Params ─────────────────────────────────────────────────────────

  Future<List<ShiftParam>> getShiftParams() async {
    try {
      if (!db.isConnected) {
        logger.t('getShiftParams - DB not connected, try connect again');
        await initDB();
      }
      final docs = await colShift.find().toList();
      if (docs.isNotEmpty) {
        logger.t('getShiftParams: loaded ${docs.length} records from DB');
        return docs.map<ShiftParam>((d) => ShiftParam.fromMap(d)).toList();
      }
    } catch (e) {
      logger.t('getShiftParams: $e');
    }
    logger.t('getShiftParams: no records found');
    return [];
  }

  // ─── History ──────────────────────────────────────────────────────────────

  Future<void> insertHistory(String log) async {
    try {
      if (!db.isConnected) await initDB();
      await colHistory.insertOne({
        'pcName': Platform.localHostname,
        'time': DateTime.now().toUtcKeepValue(),
        'log': log,
      });
    } catch (e) {
      logger.t('insertHistory: $e');
    }
  }

  Future<List<History>> getHistory(List<DateTime> dateRange) async {
    final List<History> result = [];
    try {
      if (!db.isConnected) await initDB();
      await colHistory
          .find(
            where
                .gte('time', dateRange[0])
                .and(where.lte('time', dateRange[1]))
                .sortBy('time', descending: true),
          )
          .forEach((doc) => result.add(History.fromMap(doc)));
    } catch (e) {
      logger.t('getHistory: $e');
    }
    logger.t('getHistory: ${result.length} records');
    return result;
  }
}
