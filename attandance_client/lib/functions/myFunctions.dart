import 'dart:io';
import 'dart:typed_data';
import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/main.dart';
import 'package:attandance_client/model/attLog.dart';
import 'package:attandance_client/model/employee.dart';
import 'package:attandance_client/model/otRegister.dart';
import 'package:attandance_client/model/shiftRegister.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:excel/excel.dart' as xl show Border, BorderStyle;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:oktoast/oktoast.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

/// Hàm nhận vào chuỗi mã và trả về List chứa [startDate, endDate]
class MyFunctions {
  /// Extract [start, end] directly from a PickerDateRange — works in release.
  static List<DateTime> extractDateRangeFromPicker(dynamic value) {
    if (value == null) return [];
    // Cast to PickerDateRange to avoid toString() tree-shaking in release
    try {
      final range = value as PickerDateRange;
      final start = range.startDate;
      final end = range.endDate ?? range.startDate;
      if (start == null) return [];
      return [start.toBeginDay(), end!.toEndDay()];
    } catch (_) {
      // fallback to string parsing for any unexpected type
      return extractDateRange(value.toString());
    }
  }

  static List<DateTime> extractDateRange(String input) {
    // Biểu thức chính quy để tìm chuỗi ngày tháng năm
    RegExp regExp = RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}');
    Iterable<Match> matches = regExp.allMatches(input);

    if (matches.length >= 2) {
      DateTime startDate = DateTime.parse(matches.elementAt(0).group(0)!);
      DateTime endDate = DateTime.parse(
        matches.elementAt(1).group(0)!,
      ).toEndDay();

      // Trả về list chứa 2 phần tử theo đúng yêu cầu
      return [startDate, endDate];
    }
    if (matches.length == 1) {
      DateTime startDate = DateTime.parse(
        matches.elementAt(0).group(0)!,
      ).toBeginDay();

      DateTime endDate = startDate.toEndDay();
      return [startDate, endDate]; // endDate lấy giá trị của startDate
    }

    // Trả về list rỗng nếu chuỗi đầu vào không hợp lệ hoặc không đủ dữ liệu
    return [];
  }

  static Future<void> loadData(String type, BuildContext context) async {
    showToast('Loading : $type', backgroundColor: AppColors.textSecondary);
    context.loaderOverlay.show();
    switch (type) {
      case 'employee':
        // Load employee data
        App.gValue.employees = await App.mongoDb.getEmployees();

        break;
      case 'attLog':
        // Load attendance log data
        App.gValue.attLogs = await App.mongoDb.getAttLogs(
          App.gValue.dateRangeAtt,
        );
        break;
      case 'overtime':
        App.gValue.otRegisters = await App.mongoDb.getOvertime(
          App.gValue.dateRangeOvertime,
        );
        break;
      case 'shift':
        App.gValue.shiftRegisters = await App.mongoDb.getShiftRegisters(
          App.gValue.dateRangeShift,
        );
        break;
      case 'history':
        App.gValue.histories = await App.mongoDb.getHistory(
          App.gValue.dateRangeHistory,
        );
        break;
      case 'all':
        // Load all
        App.gValue.employees = await App.mongoDb.getEmployees();
        App.gValue.attLogs = await App.mongoDb.getAttLogs(
          App.gValue.dateRangeAtt,
        );
        App.gValue.otRegisters = await App.mongoDb.getOvertime(
          App.gValue.dateRangeOvertime,
        );
        App.gValue.shiftRegisters = await App.mongoDb.getShiftRegisters(
          App.gValue.dateRangeShift,
        );
        break;
      default:
    }
    context.loaderOverlay.hide();
  }

  /// Returns a map with keys 'present' and 'absent', each containing a list of [Employee].
  /// Active on [date] = workStatus contains 'Working', OR workStatus contains 'Resigned' but resignOn > date.
  static Map<String, List<Employee>> getPresentAbsent(
    DateTime date, {
    List<AttLog>? attLogs,
    List<Employee>? employees,
  }) {
    final logs = attLogs ?? App.gValue.attLogs;
    final emps = employees ?? App.gValue.employees;
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final activeEmployees = emps.where((e) {
      final status = e.workStatus ?? '';
      if (status.contains('Working')) return true;
      if (status.contains('Resigned')) {
        return e.resignOn != null && e.resignOn!.isAfter(date);
      }
      return false;
    }).toList();

    final presentEmpIds = logs
        .where(
          (l) => l.timestamp.isAfter(dayStart) && l.timestamp.isBefore(dayEnd),
        )
        .map((l) => l.empId)
        .toSet();

    final present = activeEmployees
        .where((e) => presentEmpIds.contains(e.empId))
        .toList();
    final absent = activeEmployees
        .where((e) => !presentEmpIds.contains(e.empId))
        .toList();

    return {'present': present, 'absent': absent};
  }

  static Map<String, String> getEmployeeMap() {
    Map<String, String> employeeMap = {};
    for (var emp in App.gValue.employees) {
      // filter : eclude workStatus = 'resigned' and resignedOn < DateTime.now() -30 days
      if (emp.workStatus == 'Resigned' && emp.resignOn != null) {
        if (emp.resignOn!.isBefore(
          DateTime.now().subtract(Duration(days: 30)),
        )) {
          continue; // skip employee resigned more than 30 days
        }
      }
      employeeMap[emp.empId ?? ''] = '${emp.empId!} ${emp.name!} ${emp.group!}';
    }
    return employeeMap;
  }

  /// Generate a file name with timestamp: [type]_YYMMDD_HHMMSS
  static String exportFileName(String type) {
    final now = DateTime.now();
    final ts = DateFormat('yyMMdd_HHmmss').format(now);
    return '${type}_$ts';
  }

  /// Save Excel bytes to file, show toast, and open the file.
  static Future<void> saveAndOpenExcel(Excel excel, String fileName) async {
    // Yield to event loop so the overlay can render before heavy encoding
    await Future.delayed(const Duration(milliseconds: 50));
    final bytes = excel.encode();
    if (bytes == null) {
      showToast('Export failed: could not encode file');
      return;
    }
    final path = await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
    showToast('Exported at Download\\$fileName.xlsx');
    // Open file
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    }
  }

  /// Style header row: bold text
  static void styleHeader(Sheet sheet, int colCount) {
    for (int c = 0; c < colCount; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#D9E2F3'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }
  }

  /// Export template with sample data from the DataGridSource.
  /// [columnIndices] maps each template header to the column index in the source.
  static Future<void> exportTemplate({
    required List<String> headers,
    required String type,
    DataGridSource? source,
    List<int>? columnIndices,
    int sampleRows = 10,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      styleHeader(sheet, headers.length);

      // Add sample data rows from source if available
      final rows = source?.rows ?? [];
      final count = rows.length < sampleRows ? rows.length : sampleRows;
      for (int r = 0; r < count; r++) {
        final cells = rows[r].getCells();
        final rowData = <CellValue>[];
        if (columnIndices != null) {
          for (final idx in columnIndices) {
            rowData.add(_toCellValue(idx < cells.length ? cells[idx].value : ''));
          }
        } else {
          for (int c = 0; c < headers.length && c < cells.length; c++) {
            rowData.add(_toCellValue(cells[c].value));
          }
        }
        sheet.appendRow(rowData);
      }

      // If no data or fewer rows than sampleRows, fill remaining with empty bordered rows
      if (count < sampleRows) {
        final thinBorder = xl.Border(borderStyle: xl.BorderStyle.Thin);
        final borderStyle = CellStyle(
          leftBorder: thinBorder,
          rightBorder: thinBorder,
          topBorder: thinBorder,
          bottomBorder: thinBorder,
        );
        for (int r = count + 1; r <= sampleRows; r++) {
          for (int c = 0; c < headers.length; c++) {
            final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
            );
            cell.value = TextCellValue('');
            cell.cellStyle = borderStyle;
          }
        }
      }

      await saveAndOpenExcel(excel, exportFileName('${type}_Template'));
    } catch (e) {
      showToast('Export error: $e');
    }
  }

  /// Export a DataGridSource to an Excel file.
  /// [headers] must match the column order in the DataGridSource rows.
  static Future<void> exportGridToExcel({
    required DataGridSource source,
    required List<String> headers,
    required String type,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Header row
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      styleHeader(sheet, headers.length);

      // Data rows
      for (final row in source.rows) {
        sheet.appendRow(
          row.getCells().map((c) => _toCellValue(c.value)).toList(),
        );
      }

      await saveAndOpenExcel(excel, exportFileName(type));
    } catch (e) {
      showToast('Export error: $e');
    }
  }

  // Date patterns: yyyy-MM-dd, dd-MM-yyyy, dd/MM/yyyy
  static final _dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  // DateTime patterns: yyyy-MM-dd HH:mm
  static final _dateTimeRegex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$');
  // Time patterns: HH:mm
  static final _timeRegex = RegExp(r'^\d{2}:\d{2}$');

  static CellValue _toCellValue(dynamic v) {
    if (v == null) return TextCellValue('');
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is DateTime) {
      return DateTimeCellValue.fromDateTime(v);
    }
    final s = v.toString();
    if (s.isEmpty) return TextCellValue('');
    // Try date: yyyy-MM-dd
    if (_dateRegex.hasMatch(s)) {
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return DateCellValue(year: dt.year, month: dt.month, day: dt.day);
      }
    }
    // Try datetime: yyyy-MM-dd HH:mm
    if (_dateTimeRegex.hasMatch(s)) {
      final dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
      if (dt != null) {
        return DateTimeCellValue(
          year: dt.year,
          month: dt.month,
          day: dt.day,
          hour: dt.hour,
          minute: dt.minute,
        );
      }
    }
    // Try time: HH:mm
    if (_timeRegex.hasMatch(s)) {
      final parts = s.split(':');
      return TimeCellValue(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    return TextCellValue(s);
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  static Excel? _pickAndDecodeExcel(Uint8List bytes) {
    return Excel.decodeBytes(bytes);
  }

  static String _cell(Sheet sheet, int row, int col) =>
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
          .value
          ?.toString()
          .trim() ??
      '';

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    // Excel serial date number (e.g. 45808)
    final asNum = double.tryParse(s);
    if (asNum != null && asNum > 25569) {
      // Excel epoch: 1900-01-01 with the bug offset
      final days = asNum.toInt() - 25569;
      return DateTime.utc(1970, 1, 1).add(Duration(days: days));
    }
    // Try multiple date formats
    for (final fmt in [
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('yyyy/MM/dd'),
      DateFormat('dd-MM-yyyy'),
    ]) {
      try {
        return fmt.parseStrict(s);
      } catch (_) {}
    }
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDateTime(String s) {
    if (s.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd HH:mm').parseStrict(s);
    } catch (_) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
  }

  // ─── pick xlsx bytes ──────────────────────────────────────────────────────
  static Future<Uint8List?> _pickXlsxBytes() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    return result?.files.single.bytes;
  }

  static Employee _findEmployee(String empId) {
    return App.gValue.employees.firstWhere(
      (e) => e.empId == empId,
      orElse: () => Employee(empId: empId),
    );
  }

  // ─── attLog import ────────────────────────────────────────────────────────
  // Template columns: Finger ID | Employee ID | Timestamp | Machine No
  static Future<List<AttLog>?> importAttLogs() async {
    final bytes = await _pickXlsxBytes();
    if (bytes == null) return null;
    final excel = _pickAndDecodeExcel(bytes);
    if (excel == null) {
      showToast('Cannot read file');
      return null;
    }
    final sheet = excel.sheets.values.first;
    final logs = <AttLog>[];
    final skipped = <String>[];
    for (int r = 1; r < sheet.maxRows; r++) {
      final fingerId = int.tryParse(_cell(sheet, r, 0)) ?? 0;
      final empId = _cell(sheet, r, 1);
      final tsStr = _cell(sheet, r, 2);
      final machineNo = int.tryParse(_cell(sheet, r, 3)) ?? 0;
      if (empId.isEmpty && tsStr.isEmpty) continue; // blank row
      if (empId.isEmpty) {
        skipped.add('Row ${r + 1}: missing Employee ID');
        continue;
      }
      if (tsStr.isEmpty) {
        skipped.add('Row ${r + 1}: missing Timestamp');
        continue;
      }
      final ts = _parseDateTime(tsStr);
      if (ts == null) {
        skipped.add('Row ${r + 1}: invalid Timestamp "$tsStr"');
        continue;
      }
      final emp = _findEmployee(empId);
      logs.add(
        AttLog(
          objectId: '',
          attFingerId: fingerId,
          empId: empId,
          name: emp.name ?? empId,
          timestamp: ts,
          machineNo: machineNo,
        ),
      );
    }
    if (logs.isEmpty) {
      showToast(
        'No valid rows found${skipped.isNotEmpty ? '\n${skipped.join('\n')}' : ''}',
        duration: const Duration(seconds: 5),
      );
      return [];
    }
    if (skipped.isNotEmpty) {
      showToast(
        'Skipped ${skipped.length} row(s):\n${skipped.join('\n')}',
        duration: const Duration(seconds: 5),
      );
    }
    return logs;
  }

  // ─── overtime import ──────────────────────────────────────────────────────
  // Template columns: OT Date | Begin | End | Emp ID
  static Future<List<OtRegister>?> importOtRegisters() async {
    final bytes = await _pickXlsxBytes();
    if (bytes == null) return null;
    final excel = _pickAndDecodeExcel(bytes);
    if (excel == null) {
      showToast('Cannot read file');
      return null;
    }
    final sheet = excel.sheets.values.first;
    final ots = <OtRegister>[];
    final skipped = <String>[];
    final baseId = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final nowStr = DateFormat('yyyyMMddHHmm').format(now);
    for (int r = 1; r < sheet.maxRows; r++) {
      final otDateStr = _cell(sheet, r, 0);
      final otTimeBegin = _cell(sheet, r, 1);
      final otTimeEnd = _cell(sheet, r, 2);
      final empId = _cell(sheet, r, 3);
      if (empId.isEmpty && otDateStr.isEmpty) continue; // blank row
      if (empId.isEmpty) {
        skipped.add('Row ${r + 1}: missing Emp ID');
        continue;
      }
      if (otDateStr.isEmpty) {
        skipped.add('Row ${r + 1}: missing OT Date');
        continue;
      }
      final otDate = _parseDate(otDateStr);
      if (otDate == null) {
        skipped.add('Row ${r + 1}: invalid date "$otDateStr"');
        continue;
      }
      final emp = _findEmployee(empId);
      final empSuffix = empId.length > 5 ? empId.substring(5) : empId;
      ots.add(
        OtRegister(
          id: baseId + r,
          requestNo: '${nowStr}_$empSuffix',
          requestDate: now,
          otDate: otDate,
          otTimeBegin: otTimeBegin,
          otTimeEnd: otTimeEnd,
          empId: empId,
          name: emp.name ?? empId,
        ),
      );
    }
    if (ots.isEmpty) {
      showToast(
        'No valid rows found${skipped.isNotEmpty ? '\n${skipped.join('\n')}' : ''}',
        duration: const Duration(seconds: 5),
      );
      return [];
    }
    if (skipped.isNotEmpty) {
      showToast(
        'Skipped ${skipped.length} row(s):\n${skipped.join('\n')}',
        duration: const Duration(seconds: 5),
      );
    }
    return ots;
  }

  // ─── shift import ─────────────────────────────────────────────────────────
  // Template columns: From Date | To Date | Shift | Emp ID
  static Future<List<ShiftRegister>?> importShiftRegisters() async {
    final bytes = await _pickXlsxBytes();
    if (bytes == null) return null;
    final excel = _pickAndDecodeExcel(bytes);
    if (excel == null) {
      showToast('Cannot read file');
      return null;
    }
    final sheet = excel.sheets.values.first;
    final srs = <ShiftRegister>[];
    final skipped = <String>[];
    for (int r = 1; r < sheet.maxRows; r++) {
      final fromDateStr = _cell(sheet, r, 0);
      final toDateStr = _cell(sheet, r, 1);
      final shift = _cell(sheet, r, 2);
      final empId = _cell(sheet, r, 3);
      if (empId.isEmpty && fromDateStr.isEmpty) continue; // blank row
      if (empId.isEmpty) {
        skipped.add('Row ${r + 1}: missing Emp ID');
        continue;
      }
      if (fromDateStr.isEmpty) {
        skipped.add('Row ${r + 1}: missing From Date');
        continue;
      }
      final fromDate = _parseDate(fromDateStr);
      if (fromDate == null) {
        skipped.add('Row ${r + 1}: invalid From Date "$fromDateStr"');
        continue;
      }
      final toDate = _parseDate(toDateStr);
      if (toDate == null) {
        skipped.add('Row ${r + 1}: invalid To Date "$toDateStr"');
        continue;
      }
      final emp = _findEmployee(empId);
      srs.add(
        ShiftRegister(
          objectId: '',
          empId: empId,
          name: emp.name ?? empId,
          fromDate: fromDate,
          toDate: toDate,
          shift: shift,
        ),
      );
    }
    if (srs.isEmpty) {
      showToast(
        'No valid rows found${skipped.isNotEmpty ? '\n${skipped.join('\n')}' : ''}',
        duration: const Duration(seconds: 5),
      );
      return [];
    }
    if (skipped.isNotEmpty) {
      showToast(
        'Skipped ${skipped.length} row(s):\n${skipped.join('\n')}',
        duration: const Duration(seconds: 5),
      );
    }
    return srs;
  }
}
