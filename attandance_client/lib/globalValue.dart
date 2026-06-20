import 'package:attandance_client/main.dart';
import 'package:attandance_client/model/attLog.dart';
import 'package:attandance_client/model/employee.dart';
import 'package:attandance_client/model/history.dart';
import 'package:attandance_client/model/otRegister.dart';
import 'package:attandance_client/model/shiftRegister.dart';
import 'package:attandance_client/model/shift_param.dart';
import 'package:attandance_client/model/timesheetSettings.dart';
import 'package:attandance_client/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class GValue {
  String pcName = '';
  bool isConectedDb = false;
  String permission = ''; // 'edit' | 'read' | 'deny' | '' = not yet checked

  // App paths
  String serverFolder = r'T:\02.Public\05.IT\02.Software\04.Attendance App V3';
  String localFolder = r'D:\04.Attendance App V3';
  String get serverExePath => '$serverFolder\\attandance_client.exe';
  String get localExePath => '$localFolder\\attandance_client.exe';

  List<Employee> employees = [];
  List<AttLog> attLogs = [];
  List<OtRegister> otRegisters = [];
  List<ShiftRegister> shiftRegisters = [];
  List<History> histories = [];
  List<DateTime> dateRangeAtt = [
    DateTime.now().toBeginDay(),
    DateTime.now().toEndDay(),
  ];
  List<DateTime> dateRangeOvertime = [
    DateTime.now().subtract(Duration(days: 14)).toBeginDay(),
    DateTime.now().add(Duration(days: 14)).toEndDay(),
  ];
  List<DateTime> dateRangeShift = [
    DateTime(DateTime.now().year - 1, 12, 31).toBeginDay(),
    DateTime(DateTime.now().year, 12, 25).toBeginDay(),
  ];
  List<DateTime> dateRangeTimesheet = [
    DateTime.now().subtract(Duration(days: 15)).toBeginDay(),
    DateTime.now().subtract(Duration(days: 1)).toEndDay(),
  ];
  List<DateTime> dateRangeHistory = [
    DateTime.now().subtract(const Duration(days: 7)).toBeginDay(),
    DateTime.now().toEndDay(),
  ];
  PackageInfo packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  UpdateInfo? pendingUpdate;

  // Shift params & Timesheet settings
  List<ShiftParam> shiftParams = [];
  TimesheetSettings timesheetSettings = TimesheetSettings();
}
