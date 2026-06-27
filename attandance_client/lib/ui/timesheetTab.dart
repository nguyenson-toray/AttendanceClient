import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/functions/myFunctions.dart';
import 'package:attandance_client/functions/timesheetFunctions.dart';
import 'package:attandance_client/main.dart';
import 'package:attandance_client/model/attLog.dart';
import 'package:attandance_client/model/otRegister.dart';
import 'package:attandance_client/model/timeSheetDate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:oktoast/oktoast.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class TimesheetTab extends StatefulWidget {
  const TimesheetTab({super.key});

  @override
  State<TimesheetTab> createState() => _TimesheetTabState();
}

class _TimesheetTabState extends State<TimesheetTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  TimesheetResult? _tsResult;
  List<TimeSheetDate> _timesheets = [];
  TimesheetDataSource _dataSource = TimesheetDataSource([]);
  TimesheetSummaryDataSource _summaryDataSource = TimesheetSummaryDataSource(
    [],
  );
  bool _showSummary = false;

  final DateRangePickerController _pickerController =
      DateRangePickerController();

  // Settings controllers
  late TextEditingController _minOtCtrl;
  late TextEditingController _otBlockCtrl;
  late TextEditingController _workBlockCtrl;
  late TextEditingController _excludeEmpCtrl;

  @override
  void initState() {
    super.initState();
    _minOtCtrl = TextEditingController(
      text: App.gValue.timesheetSettings.minOtMinute.toString(),
    );
    _otBlockCtrl = TextEditingController(
      text: App.gValue.timesheetSettings.otBlockMinute.toString(),
    );
    _workBlockCtrl = TextEditingController(
      text: App.gValue.timesheetSettings.workingBlockMinute.toString(),
    );
    _excludeEmpCtrl = TextEditingController(
      text: App.gValue.timesheetSettings.excludeEmpIds.join(', '),
    );
  }

  @override
  void dispose() {
    _minOtCtrl.dispose();
    _otBlockCtrl.dispose();
    _workBlockCtrl.dispose();
    _excludeEmpCtrl.dispose();
    super.dispose();
  }

  void _applyInt(
    TextEditingController ctrl,
    int defaultVal,
    void Function(int) setter,
  ) {
    final v = int.tryParse(ctrl.text);
    if (v != null && v > 0) {
      setter(v);
    } else {
      ctrl.text = defaultVal.toString();
      setter(defaultVal);
    }
  }

  PickerDateRange get _initialRange => PickerDateRange(
    App.gValue.dateRangeTimesheet[0],
    App.gValue.dateRangeTimesheet[1],
  );

  // ── Calculate ─────────────────────────────────────────────────────────────

  Future<void> _calculate() async {
    final overlay = context.loaderOverlay;
    overlay.show();
    try {
      showToast(
        'Loading data for timesheet...',
        backgroundColor: AppColors.textSecondary,
      );

      // Load fresh data for the timesheet date range (do not overwrite global state)
      final List<AttLog> attLogs = await App.mongoDb.getAttLogs(
        App.gValue.dateRangeTimesheet,
      );
      final List<OtRegister> otRegisters = await App.mongoDb.getOvertime(
        App.gValue.dateRangeTimesheet,
      );

      if (!mounted) return;
      showToast(
        'Calculating ${attLogs.length} logs for '
        '${App.gValue.employees.length} employees...',
        backgroundColor: AppColors.textSecondary,
      );

      final tsResult = TimesheetFunctions.createTimesheets(
        employees: App.gValue.employees,
        attLogs: attLogs,
        shiftRegisters: App.gValue.shiftRegisters,
        otRegisters: otRegisters,
        dateRange: App.gValue.dateRangeTimesheet,
      );

      if (!mounted) return;
      setState(() {
        _tsResult = tsResult;
        _timesheets = tsResult.data;
        _dataSource = TimesheetDataSource(tsResult.data);
        _summaryDataSource = TimesheetSummaryDataSource(tsResult.data);
      });
      showToast(
        'Done: ${tsResult.data.length} records'
        '${tsResult.anomalies.isNotEmpty ? " — ⚠ ${tsResult.anomalies.length} anomalies" : ""}',
        backgroundColor: AppColors.primary,
      );
    } catch (e) {
      showToast('Error: $e');
    } finally {
      if (mounted) overlay.hide();
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _export() async {
    final overlay = context.loaderOverlay;
    overlay.show();
    try {
      await TimesheetFunctions.exportTimesheets(
        _tsResult!,
        employees: App.gValue.employees,
        dateRange: App.gValue.dateRangeTimesheet,
      );
    } finally {
      if (mounted) overlay.hide();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          // ── Left panel ─────────────────────────────────────────────────────
          Container(
            width: 350,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Range: '
                  '${DateFormat('dd/MM/yyyy').format(App.gValue.dateRangeTimesheet[0])}'
                  ' → '
                  '${DateFormat('dd/MM/yyyy').format(App.gValue.dateRangeTimesheet[1])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
                SfDateRangePicker(
                  controller: _pickerController,
                  initialSelectedRange: _initialRange,
                  backgroundColor: AppColors.surface,
                  headerStyle: DateRangePickerHeaderStyle(
                    backgroundColor: AppColors.surfaceAlt,
                    textStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  monthViewSettings: const DateRangePickerMonthViewSettings(
                    enableSwipeSelection: true,
                    firstDayOfWeek: 1,
                    weekendDays: [7],
                  ),
                  enableMultiView: true,
                  minDate: DateTime.utc(2023, 12, 26),
                  maxDate: DateTime.now(),
                  todayHighlightColor: AppColors.primary,
                  selectionColor: AppColors.primary,
                  showActionButtons: true,
                  selectionMode: DateRangePickerSelectionMode.range,
                  onSubmit: (value) {
                    if (value == null) return;
                    final parsed = MyFunctions.extractDateRangeFromPicker(
                      value,
                    );
                    if (parsed.length == 2) {
                      setState(() {
                        App.gValue.dateRangeTimesheet = parsed;
                      });
                    }
                    _calculate();
                  },
                  onCancel: () {
                    App.gValue.dateRangeTimesheet = [
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    ];
                    _pickerController.selectedRange = PickerDateRange(
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    );
                    setState(() {});
                    _calculate();
                  },
                ),
                const Divider(),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _tsResult == null ? null : _export,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Text('Summary', style: TextStyle(fontSize: 12)),
                      Switch(
                        value: _showSummary,
                        activeColor: AppColors.primary,
                        onChanged: _timesheets.isEmpty
                            ? null
                            : (v) => setState(() => _showSummary = v),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable bottom section ────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary row
                        if (_timesheets.isNotEmpty) ...[
                          _SummaryTable(_timesheets),
                        ],

                        const Divider(),
                        // ── Shift Info ────────────────────────────────
                        const Text(
                          'Shift Parameters',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (App.gValue.shiftParams.isEmpty)
                          const Text(
                            'No shift records in DB — using defaults',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          )
                        else
                          ...App.gValue.shiftParams.map(
                            (s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${s.name}: ${s.beginHour.toString().padLeft(2, '0')}:${s.beginMin.toString().padLeft(2, '0')}'
                                '–${s.endHour.toString().padLeft(2, '0')}:${s.endMin.toString().padLeft(2, '0')}'
                                '  rest: ${s.restHour}h'
                                '  (${DateFormat('yyyy-MM-dd').format(s.effectiveFrom)}'
                                ' → ${DateFormat('yyyy-MM-dd').format(s.effectiveTo)})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),

                        const Divider(),
                        // ── Timesheet Settings ──────────────────────────
                        const Text(
                          'Timesheet Settings',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIntField(
                          label: 'Min OT - Minutes',
                          hint: 'default 30',
                          controller: _minOtCtrl,
                          onSubmit: () => _applyInt(
                            _minOtCtrl,
                            30,
                            (v) => App.gValue.timesheetSettings.minOtMinute = v,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIntField(
                          label: 'OT Block - Minutes',
                          hint: 'default 30',
                          controller: _otBlockCtrl,
                          onSubmit: () => _applyInt(
                            _otBlockCtrl,
                            30,
                            (v) =>
                                App.gValue.timesheetSettings.otBlockMinute = v,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIntField(
                          label: 'Working Block - Minutes',
                          hint: 'default 1',
                          controller: _workBlockCtrl,
                          onSubmit: () => _applyInt(
                            _workBlockCtrl,
                            1,
                            (v) =>
                                App
                                        .gValue
                                        .timesheetSettings
                                        .workingBlockMinute =
                                    v,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(
                              width: 150,
                              child: Text(
                                'Allow OT In Rest Time 12-13h',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            Switch(
                              value: App
                                  .gValue
                                  .timesheetSettings
                                  .allowOtInRestTime,
                              activeColor: AppColors.primary,
                              onChanged: (v) => setState(() {
                                App.gValue.timesheetSettings.allowOtInRestTime =
                                    v;
                              }),
                            ),
                            Text(
                              App.gValue.timesheetSettings.allowOtInRestTime
                                  ? 'Yes'
                                  : 'No',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    App
                                        .gValue
                                        .timesheetSettings
                                        .allowOtInRestTime
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Exclude Employee IDs',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _excludeEmpCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'TIQN-0001, TIQN-0002, ...',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onSubmitted: (v) {
                            final ids = v
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            setState(() {
                              App.gValue.timesheetSettings.excludeEmpIds = ids;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Right panel: data grid ────────────────────────────────────────
          Expanded(
            child: _timesheets.isEmpty
                ? const Center(
                    child: Text(
                      'Check Timesheet setting ➡️ Select a date range ➡️ OK ➡️ Export.',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 20,
                      ),
                    ),
                  )
                : Container(
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
                      child: _showSummary
                          ? _buildSummaryGrid()
                          : _buildDetailGrid(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required VoidCallback onSubmit,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: const OutlineInputBorder(),
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 11),
            ),
            onEditingComplete: onSubmit,
            onTapOutside: (_) => onSubmit(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailGrid() {
    return SfDataGrid(
      source: _dataSource,
      allowSorting: true,
      allowFiltering: true,
      allowMultiColumnSorting: true,
      columnWidthMode: ColumnWidthMode.fill,
      highlightRowOnHover: true,
      showColumnHeaderIconOnHover: true,
      gridLinesVisibility: GridLinesVisibility.horizontal,
      headerGridLinesVisibility: GridLinesVisibility.horizontal,
      columns: [
        GridColumn(
          columnName: 'date',
          label: const Center(child: Text('Date')),
          width: 95,
        ),
        GridColumn(
          columnName: 'empId',
          label: const Center(child: Text('Emp ID')),
          width: 90,
        ),
        GridColumn(
          columnName: 'name',
          label: const Center(child: Text('Name')),
        ),
        GridColumn(
          columnName: 'group',
          label: const Center(child: Text('Group')),
          width: 110,
        ),
        GridColumn(
          columnName: 'shift',
          label: const Center(child: Text('Shift')),
          width: 70,
        ),
        GridColumn(
          columnName: 'firstIn',
          label: const Center(child: Text('In')),
          width: 65,
        ),
        GridColumn(
          columnName: 'lastOut',
          label: const Center(child: Text('Out')),
          width: 65,
        ),
        GridColumn(
          columnName: 'normalHours',
          label: const Center(child: Text('Hours')),
          width: 65,
        ),
        GridColumn(
          columnName: 'workingDay',
          label: const Center(child: Text('Day')),
          width: 60,
        ),
        GridColumn(
          columnName: 'otActual',
          label: const Center(child: Text('OT Act')),
          width: 65,
        ),
        GridColumn(
          columnName: 'otApproved',
          label: const Center(child: Text('OT Approve')),
          width: 65,
        ),
        GridColumn(
          columnName: 'otFinal',
          label: const Center(child: Text('OT Final')),
          width: 70,
        ),
        GridColumn(
          columnName: 'notes',
          label: const Center(child: Text('Notes')),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid() {
    return SfDataGrid(
      source: _summaryDataSource,
      allowSorting: true,
      allowFiltering: true,
      allowMultiColumnSorting: true,
      columnWidthMode: ColumnWidthMode.fill,
      highlightRowOnHover: true,
      showColumnHeaderIconOnHover: true,
      gridLinesVisibility: GridLinesVisibility.horizontal,
      headerGridLinesVisibility: GridLinesVisibility.horizontal,
      columns: [
        GridColumn(
          columnName: 'no',
          label: const Center(child: Text('No')),
          width: 50,
        ),
        GridColumn(
          columnName: 'empId',
          label: const Center(child: Text('Emp ID')),
          width: 90,
        ),
        GridColumn(
          columnName: 'name',
          label: const Center(child: Text('Name')),
        ),
        GridColumn(
          columnName: 'department',
          label: const Center(child: Text('Dept')),
          width: 90,
        ),
        GridColumn(
          columnName: 'section',
          label: const Center(child: Text('Section')),
          width: 90,
        ),
        GridColumn(
          columnName: 'group',
          label: const Center(child: Text('Group')),
          width: 110,
        ),
        GridColumn(
          columnName: 'totalHours',
          label: const Center(child: Text('W.Hours')),
          width: 75,
        ),
        GridColumn(
          columnName: 'totalDays',
          label: const Center(child: Text('W.Days')),
          width: 70,
        ),
        GridColumn(
          columnName: 'otActual',
          label: const Center(child: Text('OT Act')),
          width: 70,
        ),
        GridColumn(
          columnName: 'otApproved',
          label: const Center(child: Text('OT Appr')),
          width: 70,
        ),
        GridColumn(
          columnName: 'otFinal',
          label: const Center(child: Text('OT Final')),
          width: 75,
        ),
      ],
    );
  }
}

// ── Summary DataGridSource ───────────────────────────────────────────────────

class TimesheetSummaryDataSource extends DataGridSource {
  TimesheetSummaryDataSource(List<TimeSheetDate> data) {
    // Group by empId, preserving first-seen order
    final empOrder = <String>[];
    final totals = <String, _SummaryRow>{};
    for (final ts in data) {
      if (!totals.containsKey(ts.empId)) {
        empOrder.add(ts.empId);
        totals[ts.empId] = _SummaryRow(
          empId: ts.empId,
          name: ts.name,
          department: ts.department,
          section: ts.section,
          group: ts.group,
        );
      }
      final s = totals[ts.empId]!;
      s.totalHours += ts.normalHours;
      s.totalDays += ts.normalDays;
      s.otActual += ts.otHours;
      s.otApproved += ts.otHoursApproved;
      s.otFinal += ts.otHoursFinal;
    }

    _rows = [];
    for (int i = 0; i < empOrder.length; i++) {
      final s = totals[empOrder[i]]!;
      _rows.add(
        DataGridRow(
          cells: [
            DataGridCell<int>(columnName: 'no', value: i + 1),
            DataGridCell<String>(columnName: 'empId', value: s.empId),
            DataGridCell<String>(columnName: 'name', value: s.name),
            DataGridCell<String>(columnName: 'department', value: s.department),
            DataGridCell<String>(columnName: 'section', value: s.section),
            DataGridCell<String>(columnName: 'group', value: s.group),
            DataGridCell<double>(columnName: 'totalHours', value: s.totalHours),
            DataGridCell<double>(columnName: 'totalDays', value: s.totalDays),
            DataGridCell<double>(columnName: 'otActual', value: s.otActual),
            DataGridCell<double>(columnName: 'otApproved', value: s.otApproved),
            DataGridCell<double>(columnName: 'otFinal', value: s.otFinal),
          ],
        ),
      );
    }
  }

  List<DataGridRow> _rows = [];

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isNum = cell.value is double;
        final isName = cell.columnName == 'name';
        return Container(
          alignment: isName
              ? Alignment.centerLeft
              : isNum
              ? Alignment.centerRight
              : Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            isNum
                ? (cell.value as double) == 0
                      ? ''
                      : (cell.value as double).toStringAsFixed(
                          const {
                                'totalHours',
                                'totalDays',
                              }.contains(cell.columnName)
                              ? 2
                              : 1,
                        )
                : cell.value.toString(),
            style: isNum && (cell.value as double) > 0
                ? TextStyle(
                    color: cell.columnName == 'otFinal'
                        ? AppColors.warningText
                        : null,
                    fontWeight: cell.columnName == 'otFinal'
                        ? FontWeight.bold
                        : null,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _SummaryRow {
  final String empId, name, department, section, group;
  double totalHours = 0, totalDays = 0;
  double otActual = 0, otApproved = 0, otFinal = 0;
  _SummaryRow({
    required this.empId,
    required this.name,
    required this.department,
    required this.section,
    required this.group,
  });
}

// ── Detail DataGridSource ────────────────────────────────────────────────────

class TimesheetDataSource extends DataGridSource {
  TimesheetDataSource(List<TimeSheetDate> data) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');
    _rows = data.map<DataGridRow>((ts) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'date',
            value: dateFmt.format(ts.date),
          ),
          DataGridCell<String>(columnName: 'empId', value: ts.empId),
          DataGridCell<String>(columnName: 'name', value: ts.name),
          DataGridCell<String>(columnName: 'group', value: ts.group),
          DataGridCell<String>(columnName: 'shift', value: ts.shift),
          DataGridCell<String>(
            columnName: 'firstIn',
            value: ts.firstIn != null ? timeFmt.format(ts.firstIn!) : '',
          ),
          DataGridCell<String>(
            columnName: 'lastOut',
            value: ts.lastOut != null ? timeFmt.format(ts.lastOut!) : '',
          ),
          DataGridCell<double>(
            columnName: 'normalHours',
            value: ts.normalHours,
          ),
          DataGridCell<double>(columnName: 'workingDay', value: ts.normalDays),
          DataGridCell<double>(columnName: 'otActual', value: ts.otHours),
          DataGridCell<double>(
            columnName: 'otApproved',
            value: ts.otHoursApproved,
          ),
          DataGridCell<double>(columnName: 'otFinal', value: ts.otHoursFinal),
          DataGridCell<String>(
            columnName: 'notes',
            value: [
              ts.attNote2,
              ts.attNote3,
            ].where((n) => n.isNotEmpty).join(' | '),
          ),
        ],
      );
    }).toList();
  }

  List<DataGridRow> _rows = [];

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        // Right-align numeric columns; left-align text
        final isNum = cell.value is double;
        final isNote = cell.columnName == 'notes' || cell.columnName == 'name';
        return Container(
          alignment: isNote
              ? Alignment.centerLeft
              : isNum
              ? Alignment.centerRight
              : Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            isNum
                ? (cell.value as double) == 0
                      ? ''
                      : (cell.value as double).toStringAsFixed(
                          const {
                                'normalHours',
                                'workingDay',
                              }.contains(cell.columnName)
                              ? 2
                              : 1,
                        )
                : cell.value.toString(),
            style: isNum && (cell.value as double) > 0
                ? TextStyle(
                    color: cell.columnName == 'otFinal'
                        ? AppColors.warningText
                        : null,
                    fontWeight: cell.columnName == 'otFinal'
                        ? FontWeight.bold
                        : null,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── Summary table ─────────────────────────────────────────────────────────────

class _SummaryTable extends StatelessWidget {
  const _SummaryTable(this.rows);
  final List<TimeSheetDate> rows;

  @override
  Widget build(BuildContext context) {
    final totalRecords = rows.length;
    final totalEmployees = rows.map((r) => r.empId).toSet().length;
    final totalNormal = rows.fold(0.0, (s, r) => s + r.normalHours);
    final totalWDay = totalNormal / 8;
    final totalOtActual = rows.fold(0.0, (s, r) => s + r.otHours);
    final totalOtApproved = rows.fold(0.0, (s, r) => s + r.otHoursApproved);
    final totalOtFinal = rows.fold(0.0, (s, r) => s + r.otHoursFinal);

    const labelStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    const valueStyle = TextStyle(
      fontSize: 12,
      color: AppColors.primary,
      fontWeight: FontWeight.bold,
    );

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: valueStyle),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Total Records', '$totalRecords'),
          row('Total Employees', '$totalEmployees'),
          row('Total Working Hrs', totalNormal.toStringAsFixed(1)),
          row('Total Working Days', totalWDay.toStringAsFixed(2)),
          row('Total OT Actual', totalOtActual.toStringAsFixed(1)),
          row('Total OT Approved', totalOtApproved.toStringAsFixed(1)),
          row('Total OT Final', totalOtFinal.toStringAsFixed(1)),
        ],
      ),
    );
  }
}
