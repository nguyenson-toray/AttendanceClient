import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/ui/contextMenu.dart';
import 'package:attandance_client/appLogger.dart';
import 'package:attandance_client/main.dart';
import 'package:attandance_client/model/attLog.dart';
import 'package:attandance_client/model/employee.dart';
import 'package:attandance_client/functions/myFunctions.dart';
import 'package:attandance_client/ui/myWidget.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:drop_down_search_field/drop_down_search_field.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:oktoast/oktoast.dart';

class AttTab extends StatefulWidget {
  const AttTab({super.key});

  @override
  State<AttTab> createState() => _AttTabState();
}

class _AttTabState extends State<AttTab> {
  AttLogDataSource attLogDataSource = AttLogDataSource(
    attLogs: App.gValue.attLogs,
  );
  DateTime _selectedDateTime = DateTime.now();
  List<DateTime> _selectedDates = [];
  final List<String> _selectedEmpIds = [];
  final TextEditingController _empSearchController = TextEditingController();
  final SuggestionsBoxController _suggestionsBoxController =
      SuggestionsBoxController();
  final DataGridController _dataGridController = DataGridController();

  void _handleAttCellAction(DataGridCellTapDetails details) {
    if (App.gValue.permission != 'edit') return;
    final visualIndex = details.rowColumnIndex.rowIndex - 1;
    final effectiveRows = attLogDataSource.effectiveRows;
    if (visualIndex < 0 || visualIndex >= effectiveRows.length) return;
    final row = effectiveRows[visualIndex];
    final cells = row.getCells();
    final empId =
        cells.firstWhere((c) => c.columnName == 'empID').value as String;
    final name =
        cells.firstWhere((c) => c.columnName == 'name').value as String;
    final ts =
        cells.firstWhere((c) => c.columnName == 'timestamp').value as DateTime;
    // Find the actual data source index for this row
    final dataIndex = attLogDataSource.rows.indexOf(row);
    if (dataIndex < 0) return;
    final objectId = attLogDataSource.getObjectId(dataIndex);
    final pos = details.globalPosition;
    showContextMenu(
      context,
      pos,
      onEdit: () {
        _showEditAttDialog(objectId, ts, dataIndex, empId: empId, name: name);
      },
      onDelete: () {
        _showDeleteAttConfirm(objectId, empId, name, ts, dataIndex);
      },
    );
  }

  final DateRangePickerController _pickerController =
      DateRangePickerController();

  Future<DateTime?> showDateTimePicker(BuildContext ctx, {DateTime? initial}) async {
    DateTime temp = initial ?? _selectedDateTime;
    return showDialog<DateTime>(
      context: ctx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CalendarDatePicker(
                  initialDate: temp,
                  firstDate: DateTime(2023, 12, 26),
                  lastDate: DateTime.now(),
                  onDateChanged: (d) => setLocal(
                    () => temp = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      temp.hour,
                      temp.minute,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 8),
                      const Text('Time:'),
                      const SizedBox(width: 12),
                      _timeSpinner(
                        value: temp.hour,
                        max: 23,
                        onChanged: (v) => setLocal(
                          () => temp = DateTime(
                            temp.year,
                            temp.month,
                            temp.day,
                            v,
                            temp.minute,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          ':',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _timeSpinner(
                        value: temp.minute,
                        max: 59,
                        onChanged: (v) => setLocal(
                          () => temp = DateTime(
                            temp.year,
                            temp.month,
                            temp.day,
                            temp.hour,
                            v,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, temp),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeSpinner({
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return _TimeSpinnerField(value: value, max: max, onChanged: onChanged);
  }

  Future<void> _showAddAttDialog(BuildContext ctx) async {
    _selectedEmpIds.clear();
    _selectedDates = [];
    final now = DateTime.now();
    _selectedDateTime = DateTime(now.year, now.month, now.day, 8, 0);
    await showDialog(
      context: ctx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add attendance log'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select employees:'),
                  const SizedBox(height: 8),
                  _buildEmployeeMultiSelect(onChanged: () => setLocal(() {})),
                  const SizedBox(height: 12),
                  const Text('Select dates:'),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 280,
                    child: SfDateRangePicker(
                      backgroundColor: AppColors.surface,
                      headerStyle: DateRangePickerHeaderStyle(
                        backgroundColor: AppColors.surfaceAlt,
                        textStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      todayHighlightColor: AppColors.primary,
                      selectionColor: AppColors.primary,
                      selectionMode: DateRangePickerSelectionMode.multiple,
                      initialSelectedDates: _selectedDates,
                      maxDate: DateTime.now(),
                      minDate: DateTime(2023, 12, 26),
                      monthViewSettings: const DateRangePickerMonthViewSettings(
                        firstDayOfWeek: 1,
                        weekendDays: [7],
                      ),
                      onSelectionChanged: (args) => setLocal(
                        () => _selectedDates = (args.value as List<DateTime>)
                            .toList(),
                      ),
                    ),
                  ),
                  // const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 8),
                      const Text('Time:'),
                      const SizedBox(width: 12),
                      _timeSpinner(
                        value: 8,
                        max: 23,
                        onChanged: (v) => setLocal(
                          () => _selectedDateTime = DateTime(
                            _selectedDateTime.year,
                            _selectedDateTime.month,
                            _selectedDateTime.day,
                            v,
                            _selectedDateTime.minute,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          ':',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _timeSpinner(
                        value: 0,
                        max: 59,
                        onChanged: (v) => setLocal(
                          () => _selectedDateTime = DateTime(
                            _selectedDateTime.year,
                            _selectedDateTime.month,
                            _selectedDateTime.day,
                            _selectedDateTime.hour,
                            v,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedDates.isNotEmpty)
                        Text(
                          '${_selectedDates.length} ngày đã chọn',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save'),
              onPressed: (_selectedEmpIds.isEmpty || _selectedDates.isEmpty)
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _saveAttLogs(context);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAttLogs(BuildContext ctx) async {
    final int hour = _selectedDateTime.hour;
    final int minute = _selectedDateTime.minute;

    final logs = <AttLog>[];
    for (final empId in _selectedEmpIds) {
      final emp = App.gValue.employees.firstWhere(
        (e) => e.empId == empId,
        orElse: () => Employee(empId: empId, attFingerId: 0, name: empId),
      );
      for (final date in _selectedDates) {
        logs.add(
          AttLog(
            objectId: '',
            attFingerId: emp.attFingerId ?? 0,
            empId: empId,
            name: emp.name ?? empId,
            timestamp: DateTime(
              date.year,
              date.month,
              date.day,
              hour,
              minute,
            ).toUtcKeepValue(),
            machineNo: 0,
          ),
        );
      }
    }

    context.loaderOverlay.show();
    await App.mongoDb.insertAttLogs(logs);
    if (!mounted) return;
    context.loaderOverlay.hide();
    App.gValue.attLogs.addAll(logs);
    attLogDataSource.insertRows(logs);
    setState(() {
      _selectedEmpIds.clear();
      _selectedDates = [];
      _selectedDateTime = DateTime.now();
    });
    showToast('Saved ${logs.length} attendance log(s)');
  }

  Future<void> _showEditAttDialog(
    String objectId,
    DateTime current,
    int rowIndex, {
    String empId = '',
    String name = '',
  }) async {
    DateTime editTs = current;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          titlePadding: EdgeInsets.zero,
          title: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Attendance Log',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (empId.isNotEmpty)
                  Text(
                    '$empId  ·  $name',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (empId.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$empId  ·  $name',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  'Timestamp',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDateTimePicker(ctx, initial: editTs);
                    if (picked != null) setLocal(() => editTs = picked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(editTs),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final overlay = context.loaderOverlay;
                overlay.show();
                await App.mongoDb.updateAttLog(
                  objectId,
                  editTs,
                  logDetail:
                      '${empId.isNotEmpty ? "$empId ($name) " : ""}${DateFormat("yyyy-MM-dd HH:mm").format(current)} → ${DateFormat("yyyy-MM-dd HH:mm").format(editTs)}',
                );
                // Update in-memory list
                final idx = App.gValue.attLogs.indexWhere(
                  (e) => e.objectId == objectId,
                );
                if (idx != -1) {
                  App.gValue.attLogs[idx] = App.gValue.attLogs[idx].copyWith(
                    timestamp: editTs,
                  );
                }
                if (!mounted) return;
                overlay.hide();
                attLogDataSource.updateRow(rowIndex, editTs);
                showToast('Attendance log updated');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAttConfirm(
    String objectId,
    String empId,
    String name,
    DateTime ts,
    int rowIndex,
  ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          decoration: BoxDecoration(
            color: AppColors.dangerTint,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: AppColors.dangerText, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delete Attendance Log',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dangerText,
                ),
              ),
            ],
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this log?',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            'Emp ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            empId,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            'Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(ts),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final overlay = context.loaderOverlay;
              overlay.show();
              await App.mongoDb.deleteAttLog(
                objectId,
                logDetail:
                    '$empId ($name) @ ${DateFormat("yyyy-MM-dd HH:mm").format(ts)}',
              );
              // Remove from in-memory list
              App.gValue.attLogs.removeWhere((e) => e.objectId == objectId);
              if (!mounted) return;
              overlay.hide();
              attLogDataSource.removeRow(rowIndex);
              showToast('Attendance log deleted');
            },
          ),
        ],
      ),
    );
  }

  // ── Absent list ───────────────────────────────────────────────────────────

  bool get _isSingleDay {
    final r = App.gValue.dateRangeAtt;
    return r[0].year == r[1].year &&
        r[0].month == r[1].month &&
        r[0].day == r[1].day;
  }

  List<Employee> _computeAbsentEmployees() {
    final date = App.gValue.dateRangeAtt[0];
    final presentEmpIds = App.gValue.attLogs
        .where(
          (log) =>
              log.timestamp.year == date.year &&
              log.timestamp.month == date.month &&
              log.timestamp.day == date.day,
        )
        .map((log) => log.empId)
        .toSet();
    return App.gValue.employees
        .where(
          (e) =>
              (e.workStatus?.startsWith('Working') ?? false) &&
              !presentEmpIds.contains(e.empId),
        )
        .toList()
      ..sort((a, b) => (a.group ?? '').compareTo(b.group ?? ''));
  }

  Future<void> _exportAbsentToExcel(List<Employee> absent) async {
    final overlay = context.loaderOverlay;
    overlay.show();
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Absent'];
      excel.delete('Sheet1');
      final headers = ['No', 'Emp ID', 'Att ID', 'Name', 'Group'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      MyFunctions.styleHeader(sheet, headers.length);
      for (var i = 0; i < absent.length; i++) {
        final e = absent[i];
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(e.empId ?? ''),
          IntCellValue(e.attFingerId ?? 0),
          TextCellValue(e.name ?? ''),
          TextCellValue(e.group ?? ''),
        ]);
      }
      await MyFunctions.saveAndOpenExcel(
        excel,
        MyFunctions.exportFileName('AbsentList'),
      );
    } catch (e) {
      showToast('Export error: $e');
    }
    overlay.hide();
  }

  void _showAbsentDialog() {
    final absent = _computeAbsentEmployees();
    final dateStr = DateFormat('dd/MM/yyyy').format(App.gValue.dateRangeAtt[0]);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Absent Employees — $dateStr (${absent.length} people)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                // const Divider(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: absent.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No absent employees found.',
                              style: TextStyle(color: AppColors.textTertiary),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 16,
                            headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            dataTextStyle: const TextStyle(fontSize: 12),
                            columns: const [
                              DataColumn(label: Text('No')),
                              DataColumn(label: Text('Emp ID')),
                              DataColumn(label: Text('Att ID')),
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Group')),
                            ],
                            rows: List.generate(absent.length, (i) {
                              final e = absent[i];
                              return DataRow(
                                cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(Text(e.empId ?? '')),
                                  DataCell(Text('${e.attFingerId ?? ''}')),
                                  DataCell(Text(e.name ?? '')),
                                  DataCell(Text(e.group ?? '')),
                                ],
                              );
                            }),
                          ),
                        ),
                ),
                // const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: absent.isEmpty
                        ? null
                        : () => _exportAbsentToExcel(absent),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Missing Checkin ──────────────────────────────────────────────────────

  static const _shiftParams = <String, (int, int, int, int)>{
    'Day': (8, 0, 17, 0),
    'Shift 1': (6, 0, 14, 0),
    'Shift 2': (14, 0, 22, 0),
    'Canteen': (7, 0, 16, 0),
  };

  List<_MissingCheckinRow> _computeMissingCheckin() {
    final results = <_MissingCheckinRow>[];
    final dateStart = App.gValue.dateRangeAtt[0].toBeginDay();
    final dateEnd = App.gValue.dateRangeAtt[1].toBeginDay();

    // Index shift registers by (dayKey, empId)
    final shiftIndex = <String, Map<String, String>>{};
    for (final sr in App.gValue.shiftRegisters) {
      for (
        var d = sr.fromDate.toBeginDay();
        !d.isAfter(sr.toDate.toBeginDay());
        d = d.add(const Duration(days: 1))
      ) {
        final dk = _dayKey(d);
        (shiftIndex[dk] ??= {})[sr.empId] = sr.shift;
      }
    }

    // Index attLogs by (dayKey, empId)
    final logIndex = <String, Map<String, List<AttLog>>>{};
    for (final l in App.gValue.attLogs) {
      final dk = _dayKey(l.timestamp);
      (logIndex[dk] ??= {}).putIfAbsent(l.empId, () => []).add(l);
    }

    final workingEmps = App.gValue.employees
        .where((e) => e.workStatus?.startsWith('Working') ?? false)
        .toList();

    for (
      var d = dateStart;
      !d.isAfter(dateEnd);
      d = d.add(const Duration(days: 1))
    ) {
      final dk = _dayKey(d);
      final dayLogs = logIndex[dk] ?? {};
      final dayShifts = shiftIndex[dk] ?? {};

      for (final emp in workingEmps) {
        final logs = dayLogs[emp.empId];
        if (logs == null || logs.isEmpty) continue; // absent, not missing

        // Determine shift
        String shift = 'Day';
        if ((emp.group ?? '') == 'Canteen') shift = 'Canteen';
        if (dayShifts[emp.empId] != null) shift = dayShifts[emp.empId]!;
        if (d.weekday == DateTime.sunday) shift = 'Day';

        final p = _shiftParams[shift] ?? _shiftParams['Day']!;
        final shiftBegin = DateTime.utc(d.year, d.month, d.day, p.$1, p.$2);
        final shiftEnd = DateTime.utc(d.year, d.month, d.day, p.$3, p.$4);

        final bool isMissing;
        if (logs.length == 1) {
          isMissing = true;
        } else {
          final allBefore = logs.every((l) => l.timestamp.isBefore(shiftBegin));
          final allAfter = logs.every((l) => l.timestamp.isAfter(shiftEnd));
          isMissing = allBefore || allAfter;
        }

        if (isMissing) {
          logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          results.add(
            _MissingCheckinRow(
              date: d,
              empId: emp.empId ?? '',
              name: emp.name ?? '',
              group: emp.group ?? '',
              checkins: logs.map((l) => l.timestamp).toList(),
            ),
          );
        }
      }
    }

    results.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.group.compareTo(b.group);
    });
    return results;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _exportMissingCheckinToExcel(
    List<_MissingCheckinRow> rows,
  ) async {
    final overlay = context.loaderOverlay;
    overlay.show();
    try {
      final excel = Excel.createExcel();
      final sheet = excel['MissingCheckin'];
      excel.delete('Sheet1');
      final headers = ['No', 'Date', 'Emp ID', 'Name', 'Group', 'Checkins'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      MyFunctions.styleHeader(sheet, headers.length);
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(DateFormat('dd/MM/yyyy').format(r.date)),
          TextCellValue(r.empId),
          TextCellValue(r.name),
          TextCellValue(r.group),
          TextCellValue(
            r.checkins.map((t) => DateFormat('HH:mm').format(t)).join(', '),
          ),
        ]);
      }
      await MyFunctions.saveAndOpenExcel(
        excel,
        MyFunctions.exportFileName('MissingCheckin'),
      );
    } catch (e) {
      showToast('Export error: $e');
    }
    overlay.hide();
  }

  void _showMissingCheckinDialog() {
    final rows = _computeMissingCheckin();
    final range = App.gValue.dateRangeAtt;
    final dateStr = _isSingleDay
        ? DateFormat('dd/MM/yyyy').format(range[0])
        : '${DateFormat('dd/MM/yyyy').format(range[0])} – ${DateFormat('dd/MM/yyyy').format(range[1])}';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 800,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Missing Checkin — $dateStr (${rows.length} records)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: rows.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No missing checkin found.',
                              style: TextStyle(color: AppColors.textTertiary),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: DataTable(
                            columnSpacing: 16,
                            headingTextStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            dataTextStyle: const TextStyle(fontSize: 12),
                            columns: const [
                              DataColumn(label: Text('No')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Emp ID')),
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Group')),
                              DataColumn(label: Text('Checkins')),
                            ],
                            rows: List.generate(rows.length, (i) {
                              final r = rows[i];
                              return DataRow(
                                cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(r.date),
                                    ),
                                  ),
                                  DataCell(Text(r.empId)),
                                  DataCell(Text(r.name)),
                                  DataCell(Text(r.group)),
                                  DataCell(
                                    Text(
                                      r.checkins
                                          .map(
                                            (t) =>
                                                DateFormat('HH:mm').format(t),
                                          )
                                          .join(', '),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: rows.isEmpty
                        ? null
                        : () => _exportMissingCheckinToExcel(rows),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _empSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    logger.t(
      '_AttTabState initState: loading attendance logs: ${App.gValue.attLogs.length} logs',
    );
    App.gValue.attLogs.isNotEmpty
        ? setState(() {
            if (!mounted) return;
            attLogDataSource = AttLogDataSource(attLogs: App.gValue.attLogs);
          })
        : Future.delayed(const Duration(milliseconds: 2000)).then((_) async {
            if (!mounted) return;
            setState(() {
              attLogDataSource = AttLogDataSource(attLogs: App.gValue.attLogs);
            });
          });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 500,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mywidget.dateRangeWidget(App.gValue.dateRangeAtt),
                SfDateRangePicker(
                  controller: _pickerController,
                  initialSelectedRange: PickerDateRange(
                    DateTime.now().toBeginDay(),
                    DateTime.now().toEndDay(),
                  ),
                  backgroundColor: AppColors.surface,
                  headerStyle: DateRangePickerHeaderStyle(
                    backgroundColor: AppColors.surfaceAlt,
                    textStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  monthViewSettings: const DateRangePickerMonthViewSettings(
                    enableSwipeSelection: true,
                    showWeekNumber: false,
                    firstDayOfWeek: 1,
                    weekendDays: [7],
                  ),
                  enableMultiView: true,
                  minDate: DateTime.utc(2023, 12, 26),
                  maxDate: DateTime.now(),
                  todayHighlightColor: AppColors.primary,
                  selectionColor: AppColors.primary,
                  onSubmit: (value) {
                    if (value == null) {
                      App.gValue.dateRangeAtt = [
                        DateTime.now().toBeginDay(),
                        DateTime.now().toEndDay(),
                      ];
                    } else {
                      final parsed = MyFunctions.extractDateRangeFromPicker(
                        value,
                      );
                      if (parsed.length == 2) {
                        App.gValue.dateRangeAtt = parsed;
                      } else {
                        logger.w('extractDateRange failed for: $value');
                        return;
                      }
                    }

                    logger.t(
                      'Selected date range: ${App.gValue.dateRangeAtt.first}'
                      ' - ${App.gValue.dateRangeAtt.last}',
                    );

                    MyFunctions.loadData('attLog', context).then((_) {
                      if (!mounted) return;
                      setState(() {
                        attLogDataSource = AttLogDataSource(
                          attLogs: App.gValue.attLogs,
                        );
                      });
                    });
                  },
                  onCancel: () {
                    App.gValue.dateRangeAtt = [
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    ];
                    _pickerController.selectedRange = PickerDateRange(
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    );
                    MyFunctions.loadData('attLog', context).then((_) {
                      if (!mounted) return;
                      setState(() {
                        attLogDataSource = AttLogDataSource(
                          attLogs: App.gValue.attLogs,
                        );
                      });
                    });
                  },
                  showActionButtons: true,
                  selectionMode: DateRangePickerSelectionMode.range,
                ),

                Divider(),
                Container(
                  padding: EdgeInsets.all(8),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: _isSingleDay ? _showAbsentDialog : null,
                        icon: Icon(
                          Icons.supervised_user_circle,
                          color: _isSingleDay
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        label: Text(
                          'Absent list',
                          style: TextStyle(
                            color: _isSingleDay
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showMissingCheckinDialog,
                        icon: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'Missing Checkin',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: App.gValue.permission == 'edit'
                            ? () => _showAddAttDialog(context)
                            : null,
                        icon: Icon(
                          Icons.add,
                          color: App.gValue.permission == 'edit'
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        label: Text(
                          'Add',
                          style: TextStyle(
                            color: App.gValue.permission == 'edit'
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final overlay = context.loaderOverlay;
                          overlay.show();
                          await MyFunctions.exportGridToExcel(
                            source: attLogDataSource,
                            headers: [
                              'Finger ID',
                              'Employee ID',
                              'Name',
                              'Group',
                              'Timestamp',
                              'Machine No',
                            ],
                            type: 'AttLog',
                          );
                          overlay.hide();
                        },
                        icon: const Icon(
                          Icons.download,
                          color: AppColors.success,
                        ),
                        label: const Text('Export'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final overlay = context.loaderOverlay;
                          overlay.show();
                          await MyFunctions.exportTemplate(
                            headers: [
                              'Finger ID',
                              'Employee ID',
                              'Timestamp',
                              'Machine No',
                            ],
                            type: 'AttLog',
                            source: attLogDataSource,
                            columnIndices: [0, 1, 4, 5],
                          );
                          overlay.hide();
                        },
                        icon: const Icon(
                          Icons.attach_file,
                          color: AppColors.success,
                        ),
                        label: const Text(
                          'Template',
                          style: TextStyle(color: AppColors.success),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: App.gValue.permission != 'edit'
                            ? null
                            : () async {
                                final overlay = context.loaderOverlay;
                                final logs = await MyFunctions.importAttLogs();
                                if (logs == null || logs.isEmpty) return;
                                if (!mounted) return;
                                overlay.show();
                                await App.mongoDb.insertAttLogs(logs);
                                if (!mounted) return;
                                overlay.hide();
                                App.gValue.attLogs.addAll(logs);
                                attLogDataSource.insertRows(logs);
                                if (!mounted) return;
                                final fmt = DateFormat('yyyy-MM-dd HH:mm');
                                await showDialog(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                    title: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Import Summary'),
                                      ],
                                    ),
                                    content: SizedBox(
                                      width: 520,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                Column(
                                                  children: [
                                                    Text(
                                                      '${logs.length}',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                    ),
                                                    const Text(
                                                      'Imported',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 300,
                                            ),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: logs
                                                    .map(
                                                      (log) => ListTile(
                                                        dense: true,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        leading: const Icon(
                                                          Icons.check_circle,
                                                          color:
                                                              AppColors.success,
                                                          size: 18,
                                                        ),
                                                        title: Text(
                                                          '${log.empId}  ${log.name}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                        subtitle: Text(
                                                          '${fmt.format(log.timestamp)}  Machine: ${log.machineNo}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx2),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                        icon: const Icon(Icons.upload, color: AppColors.info),
                        label: const Text(
                          'Import',
                          style: TextStyle(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Sum by machine:\nTotal: ${App.gValue.attLogs.length}\n${getAttLogSummaryByMachine(App.gValue.attLogs)}",
                      ),
                      VerticalDivider(color: Colors.blue),
                      Text(
                        "Employee checkin summary:\n${getEmployeeCheckinSummary(App.gValue.attLogs, App.gValue.employees)}",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: SfDataGridTheme(
                data: SfDataGridThemeData(
                  selectionColor: AppColors.primaryTint,
                  headerColor: AppColors.primaryTint,
                  gridLineColor: AppColors.border,
                  gridLineStrokeWidth: 0.5,
                  rowHoverColor: AppColors.surfaceAlt,
                ),
                child: SfDataGrid(
                  controller: _dataGridController,
                  selectionMode: SelectionMode.single,
                  navigationMode: GridNavigationMode.cell,
                  source: attLogDataSource,
                  allowSorting: true,
                  allowFiltering: true,
                  allowMultiColumnSorting: true,
                  columnWidthMode: ColumnWidthMode.fill,
                  highlightRowOnHover: true,
                  showColumnHeaderIconOnHover: true,
                  gridLinesVisibility: GridLinesVisibility.horizontal,
                  headerGridLinesVisibility: GridLinesVisibility.horizontal,
                  onCellSecondaryTap: _handleAttCellAction,
                  columns: [
                    GridColumn(
                      columnName: 'attId',
                      label: Text('Finger ID'),
                      // width: 80,
                    ),
                    GridColumn(
                      columnName: 'empID',
                      label: Text('Employee ID'),
                      // width: 100,
                    ),
                    GridColumn(
                      columnName: 'name',
                      label: Text('Name'),
                      // width: 220,
                    ),
                    GridColumn(
                      columnName: 'group',
                      label: Text('Group'),
                      // width: 150,
                    ),
                    GridColumn(
                      columnName: 'timestamp',
                      label: Text('Time'),
                      // width: 220,
                    ),
                    GridColumn(
                      columnName: 'machineNo',
                      label: Text('Machine No'),
                      // width: 90,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeMultiSelect({VoidCallback? onChanged}) {
    final empMap =
        MyFunctions.getEmployeeMap(); // { empId: 'empId name group' }

    return MultiSelectDropdownSearchFormField<String>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: _empSearchController,
        decoration: const InputDecoration(
          hintText: 'Search employee...',
          prefixIcon: Icon(Icons.search, size: 14),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      suggestionsBoxController: _suggestionsBoxController,
      suggestionsCallback: (pattern) {
        final lower = pattern.toLowerCase();
        return empMap.entries
            .where((e) => e.value.toLowerCase().contains(lower))
            .map((e) => e.key)
            .toList();
      },
      itemBuilder: (context, empId) {
        final label = empMap[empId] ?? empId;
        return ListTile(
          dense: true,
          title: Text(label, style: const TextStyle(fontSize: 13)),
        );
      },
      chipBuilder: (context, empId) {
        final label = empMap[empId] ?? empId;
        final parts = label.split(' ');
        final shortLabel = parts.length >= 2
            ? '${parts[0]} ${parts[1]}'
            : empId;
        return Chip(
          label: Text(shortLabel, style: const TextStyle(fontSize: 11)),
          deleteIcon: const Icon(Icons.close, size: 14),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            setState(() => _selectedEmpIds.remove(empId));
            onChanged?.call();
          },
        );
      },
      onMultiSuggestionSelected: (empId, isSelected) {
        setState(() {
          if (isSelected) {
            _selectedEmpIds.add(empId);
          } else {
            _selectedEmpIds.remove(empId);
          }
        });
        onChanged?.call();
      },
      initiallySelectedItems: _selectedEmpIds,
      displayAllSuggestionWhenTap: true,
      noItemsFoundBuilder: (context) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No employee found', style: TextStyle(fontSize: 13)),
      ),
    );
  }

  String getAttLogSummaryByMachine(List<AttLog> attLogs) {
    String summary = '';
    Map<int, int> machineCounts = {};
    for (var log in attLogs) {
      machineCounts[log.machineNo] = (machineCounts[log.machineNo] ?? 0) + 1;
    }
    for (var entry in machineCounts.entries) {
      summary += 'Machine ${entry.key}: ${entry.value} logs\n';
    }
    // sort summary by machine number
    List<String> summaryLines = summary.trim().split('\n');
    summaryLines.sort((a, b) {
      int machineA = int.parse(a.split(' ')[1].replaceAll(':', ''));
      int machineB = int.parse(b.split(' ')[1].replaceAll(':', ''));
      return machineA.compareTo(machineB);
    });
    return summaryLines.join('\n');
  }

  getEmployeeCheckinSummary(List<AttLog> attLogs, List<Employee> employees) {
    // count employee have work status like 'Working', 'Maternity leave', 'Resigned'
    // count presence of each employee in attLogs, if employee have at least 1 log in attLogs, count as present, otherwise count as absent (exclude 'Maternity leave' and 'Resigned' employees)
    // return map  : Total employees Active : X, Present: Y, Absent: Z, Maternity leave: B
    int activeEmployees = employees
        .where(
          (e) =>
              e.workStatus!.contains('Working') ||
              e.workStatus!.contains('Maternity leave'),
        )
        .length;
    int maternityLeaveEmployees = employees
        .where((e) => e.workStatus!.contains('Maternity leave'))
        .length;
    int presentEmployees = attLogs.map((log) => log.empId).toSet().length;
    int absentEmployees =
        activeEmployees - presentEmployees - maternityLeaveEmployees;
    return 'Active: $activeEmployees\nPresent: $presentEmployees\nAbsent: $absentEmployees\nMaternity leave: $maternityLeaveEmployees';
  }
}

class AttLogDataSource extends DataGridSource {
  /// Creates the employee data source class with required details.
  AttLogDataSource({required List<AttLog> attLogs}) {
    logger.t('AttLogDataSource: initializing with ${attLogs.length} logs');
    final reversed = attLogs.reversed.toList();
    _objectIds = reversed.map((e) => e.objectId).toList();
    _attLogs = reversed
        .map<DataGridRow>(
          (e) => DataGridRow(
            cells: [
              DataGridCell<int>(columnName: 'attId', value: e.attFingerId),
              DataGridCell<String>(columnName: 'empID', value: e.empId),
              DataGridCell<String>(columnName: 'name', value: e.name),
              DataGridCell<String>(
                columnName: 'group',
                value: getGroup(e.empId),
              ),
              DataGridCell<DateTime>(
                columnName: 'timestamp',
                value: e.timestamp,
              ),
              DataGridCell<int>(columnName: 'machineNo', value: e.machineNo),
            ],
          ),
        )
        .toList();
    logger.t('AttLogDataSource: ${_attLogs.length} logs loaded');
  }

  List<DataGridRow> _attLogs = [];
  List<String> _objectIds = [];

  String getObjectId(int rowIndex) => _objectIds[rowIndex];

  void insertRows(List<AttLog> logs) {
    final newRows = logs
        .map<DataGridRow>(
          (e) => DataGridRow(
            cells: [
              DataGridCell<int>(columnName: 'attId', value: e.attFingerId),
              DataGridCell<String>(columnName: 'empID', value: e.empId),
              DataGridCell<String>(columnName: 'name', value: e.name),
              DataGridCell<String>(
                columnName: 'group',
                value: getGroup(e.empId),
              ),
              DataGridCell<DateTime>(
                columnName: 'timestamp',
                value: e.timestamp,
              ),
              DataGridCell<int>(columnName: 'machineNo', value: e.machineNo),
            ],
          ),
        )
        .toList();
    _attLogs.insertAll(0, newRows);
    _objectIds.insertAll(0, logs.map((e) => e.objectId).toList());
    notifyListeners();
  }

  void removeRow(int index) {
    _attLogs.removeAt(index);
    _objectIds.removeAt(index);
    notifyListeners();
  }

  void updateRow(int index, DateTime newTs) {
    final old = _attLogs[index].getCells();
    _attLogs[index] = DataGridRow(
      cells: [
        old[0], // attId
        old[1], // empID
        old[2], // name
        old[3], // group
        DataGridCell<DateTime>(columnName: 'timestamp', value: newTs),
        old[5], // machineNo
      ],
    );
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _attLogs;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isNum = cell.value is int || cell.value is double;
        final isLeft = cell.columnName == 'name';
        return Container(
          alignment: isLeft
              ? Alignment.centerLeft
              : isNum
              ? Alignment.centerRight
              : Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            cell.value is DateTime
                ? DateFormat('yyyy-MM-dd HH:mm').format(cell.value as DateTime)
                : cell.value.toString(),
          ),
        );
      }).toList(),
    );
  }

  getGroup(String empId) {
    final emp = App.gValue.employees.firstWhere(
      (element) => element.empId == empId,
      orElse: () => Employee(
        empId: '',
        attFingerId: 0,
        name: '',
        group: '',
        position: '',
        joiningDate: DateTime(1900),
        workStatus: '',
        resignOn: DateTime(2099),
      ),
    );
    return emp.group;
  }
}

class _TimeSpinnerField extends StatefulWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  const _TimeSpinnerField({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_TimeSpinnerField> createState() => _TimeSpinnerFieldState();
}

class _TimeSpinnerFieldState extends State<_TimeSpinnerField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.value.toString().padLeft(2, '0'),
    );
  }

  @override
  void didUpdateWidget(_TimeSpinnerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !FocusScope.of(context).hasFocus) {
      _ctrl.text = widget.value.toString().padLeft(2, '0');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          border: OutlineInputBorder(),
        ),
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null && n >= 0 && n <= widget.max) widget.onChanged(n);
        },
        onTap: () => _ctrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _ctrl.text.length,
        ),
        onEditingComplete: () {
          final n = int.tryParse(_ctrl.text);
          if (n == null || n < 0 || n > widget.max) {
            _ctrl.text = widget.value.toString().padLeft(2, '0');
          } else {
            _ctrl.text = n.toString().padLeft(2, '0');
          }
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}

class _MissingCheckinRow {
  final DateTime date;
  final String empId;
  final String name;
  final String group;
  final List<DateTime> checkins;

  const _MissingCheckinRow({
    required this.date,
    required this.empId,
    required this.name,
    required this.group,
    required this.checkins,
  });
}
