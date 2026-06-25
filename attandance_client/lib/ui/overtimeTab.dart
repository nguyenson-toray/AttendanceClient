import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/ui/contextMenu.dart';
import 'package:attandance_client/functions/myFunctions.dart';
import 'package:attandance_client/model/employee.dart';
import 'package:attandance_client/model/otRegister.dart';
import 'package:attandance_client/ui/myWidget.dart';
import 'package:flutter/material.dart';
import 'package:attandance_client/main.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:drop_down_search_field/drop_down_search_field.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:oktoast/oktoast.dart';

class OvertimeTab extends StatefulWidget {
  const OvertimeTab({super.key});

  @override
  State<OvertimeTab> createState() => OvertimeTabState();
}

class OvertimeTabState extends State<OvertimeTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  OtRegisterDataSource _otDataSource = OtRegisterDataSource(
    otRegisters: App.gValue.otRegisters,
  );
  final DataGridController _dataGridController = DataGridController();
  final List<String> _selectedEmpIds = [];
  final TextEditingController _empSearchController = TextEditingController();
  final SuggestionsBoxController _suggestionsBoxController =
      SuggestionsBoxController();
  List<DateTime> _otSelectedDates = [];
  final TextEditingController _otTimeBeginController = TextEditingController(
    text: '17:00',
  );
  final TextEditingController _otTimeEndController = TextEditingController(
    text: '19:00',
  );

  bool _isFilteringOverlaps = false;

  void _handleOtCellAction(DataGridCellTapDetails details) {
    if (App.gValue.permission != 'edit') return;
    final visualIndex = details.rowColumnIndex.rowIndex - 1;
    final effectiveRows = _otDataSource.effectiveRows;
    if (visualIndex < 0 || visualIndex >= effectiveRows.length) return;
    final row = effectiveRows[visualIndex];
    final cells = row.getCells();
    final empId =
        cells.firstWhere((c) => c.columnName == 'empId').value as String;
    final name =
        cells.firstWhere((c) => c.columnName == 'name').value as String;
    final otDateStr =
        cells.firstWhere((c) => c.columnName == 'otDate').value as String;
    final begin =
        cells.firstWhere((c) => c.columnName == 'otTimeBegin').value as String;
    final end =
        cells.firstWhere((c) => c.columnName == 'otTimeEnd').value as String;
    final dataIndex = _otDataSource.rows.indexOf(row);
    if (dataIndex < 0) return;
    final recordId = _otDataSource.getId(dataIndex);
    final otDate = DateTime.tryParse(otDateStr) ?? DateTime.now();
    final pos = details.globalPosition;
    showContextMenu(
      context,
      pos,
      onEdit: () {
        _showEditOtDialog(
          recordId,
          otDate,
          begin,
          end,
          dataIndex,
          empId: empId,
          name: name,
        );
      },
      onDelete: () {
        _showDeleteOtConfirm(
          recordId,
          empId,
          name,
          otDateStr,
          dataIndex,
          begin: begin,
          end: end,
        );
      },
    );
  }

  final DateRangePickerController _pickerController =
      DateRangePickerController();

  PickerDateRange get _initialSelectedRange => PickerDateRange(
    App.gValue.dateRangeOvertime[0],
    App.gValue.dateRangeOvertime[1],
  );

  @override
  void initState() {
    super.initState();
    App.gValue.otRegisters.isNotEmpty
        ? setState(() {
            _otDataSource = OtRegisterDataSource(
              otRegisters: App.gValue.otRegisters,
            );
          })
        : Future.delayed(const Duration(milliseconds: 2000)).then((_) {
            if (!mounted) return;
            setState(() {
              _otDataSource = OtRegisterDataSource(
                otRegisters: App.gValue.otRegisters,
              );
            });
          });
  }

  @override
  void dispose() {
    _empSearchController.dispose();
    _otTimeBeginController.dispose();
    _otTimeEndController.dispose();
    super.dispose();
  }

  void refreshData() {
    setState(() {
      _isFilteringOverlaps = false;
      _otDataSource = OtRegisterDataSource(otRegisters: App.gValue.otRegisters);
    });
  }

  /// Filter and show only duplicate OT records on the DataGrid.
  /// Returns the list of IDs to delete (duplicates, not the kept ones).
  List<int> filterDuplicates() {
    final ots = App.gValue.otRegisters;
    final fmt = DateFormat('yyyy-MM-dd');

    // Group by (otDate, otTimeBegin, otTimeEnd, empId)
    final groups = <String, List<OtRegister>>{};
    for (final ot in ots) {
      final key =
          '${fmt.format(ot.otDate)}_${ot.otTimeBegin}_${ot.otTimeEnd}_${ot.empId}';
      (groups[key] ??= []).add(ot);
    }

    // Find duplicates
    final allDuplicateRecords = <OtRegister>[];
    final idsToDelete = <int>[];
    for (final group in groups.values) {
      if (group.length <= 1) continue;
      // Sort: keep latest requestDate, then largest requestNo
      group.sort((a, b) {
        final cmp = b.requestDate.compareTo(a.requestDate);
        if (cmp != 0) return cmp;
        return b.requestNo.compareTo(a.requestNo);
      });
      allDuplicateRecords.addAll(group); // show ALL (including kept) on grid
      for (int i = 1; i < group.length; i++) {
        idsToDelete.add(group[i].id);
      }
    }

    if (allDuplicateRecords.isEmpty) {
      return [];
    }

    setState(() {
      _isFilteringOverlaps = true;
      _otDataSource = OtRegisterDataSource(otRegisters: allDuplicateRecords);
    });

    return idsToDelete;
  }

  void filterOverlaps() {
    final fmt = DateFormat('yyyy-MM-dd');
    final records = App.gValue.otRegisters;
    final overlaps = <OtRegister>{};
    for (int i = 0; i < records.length; i++) {
      for (int j = i + 1; j < records.length; j++) {
        final a = records[i];
        final b = records[j];
        if (a.empId != b.empId) continue;
        if (fmt.format(a.otDate) != fmt.format(b.otDate)) continue;
        // Skip exact duplicates (same begin & end times)
        if (a.otTimeBegin == b.otTimeBegin && a.otTimeEnd == b.otTimeEnd) {
          continue;
        }
        if (a.otTimeBegin.compareTo(b.otTimeEnd) < 0 &&
            a.otTimeEnd.compareTo(b.otTimeBegin) > 0) {
          overlaps.add(a);
          overlaps.add(b);
        }
      }
    }
    setState(() {
      _isFilteringOverlaps = overlaps.isNotEmpty;
      _otDataSource = OtRegisterDataSource(otRegisters: overlaps.toList());
    });
    final range = App.gValue.dateRangeOvertime;
    showToast(
      overlaps.isEmpty
          ? 'No OT overlaps (${fmt.format(range[0])} → ${fmt.format(range[1])})'
          : '${overlaps.length} overlapping OT records found',
    );
  }

  Future<void> _showAddOtDialog(BuildContext ctx) async {
    _selectedEmpIds.clear();
    _otSelectedDates = [];
    _otTimeBeginController.text = '17:00';
    _otTimeEndController.text = '19:00';
    await showDialog(
      context: ctx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add overtime record'),
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
                  const Text('Select OT dates:'),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 280,
                    child: SfDateRangePicker(
                      selectionMode: DateRangePickerSelectionMode.multiple,
                      initialSelectedDates: _otSelectedDates,
                      minDate: DateTime(2023, 12, 26),
                      maxDate: DateTime.now().add(const Duration(days: 60)),
                      monthViewSettings: const DateRangePickerMonthViewSettings(
                        firstDayOfWeek: 1,
                        weekendDays: [7],
                      ),
                      onSelectionChanged: (args) => setLocal(
                        () => _otSelectedDates = (args.value as List<DateTime>)
                            .toList(),
                      ),
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Text('Begin: '),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _otTimeBeginController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'HH:MM',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text('End: '),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _otTimeEndController,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'HH:MM',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_otSelectedDates.isNotEmpty)
                        Text(
                          '${_otSelectedDates.length} ngày đã chọn',
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
              onPressed: (_selectedEmpIds.isEmpty || _otSelectedDates.isEmpty)
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _saveOtRegisters(context);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditOtDialog(
    int recordId,
    DateTime currentOtDate,
    String currentBegin,
    String currentEnd,
    int rowIndex, {
    String empId = '',
    String name = '',
  }) async {
    DateTime editOtDate = currentOtDate;
    final beginCtrl = TextEditingController(text: currentBegin);
    final endCtrl = TextEditingController(text: currentEnd);
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
                const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Overtime Record',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
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
                'OT Date',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: editOtDate,
                    firstDate: DateTime(2023, 12, 26),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) setLocal(() => editOtDate = picked);
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
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy-MM-dd').format(editOtDate),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Begin',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: beginCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'HH:MM',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'End',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: endCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'HH:MM',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                final newBegin = beginCtrl.text.trim();
                final newEnd = endCtrl.text.trim();
                await App.mongoDb.updateOtRegister(
                  recordId,
                  editOtDate,
                  newBegin,
                  newEnd,
                  logDetail:
                      '${empId.isNotEmpty ? "$empId ($name) " : ""}${DateFormat("yyyy-MM-dd").format(currentOtDate)} $currentBegin-$currentEnd → ${DateFormat("yyyy-MM-dd").format(editOtDate)} $newBegin-$newEnd',
                );
                // Update in-memory list
                final idx = App.gValue.otRegisters.indexWhere(
                  (e) => e.id == recordId,
                );
                if (idx != -1) {
                  App.gValue.otRegisters[idx].otDate = editOtDate;
                  App.gValue.otRegisters[idx].otTimeBegin = newBegin;
                  App.gValue.otRegisters[idx].otTimeEnd = newEnd;
                }
                if (!mounted) return;
                overlay.hide();
                _otDataSource.updateRow(rowIndex, editOtDate, newBegin, newEnd);
                showToast('Overtime record updated');
              },
            ),
          ],
        ),
      ),
    );
    beginCtrl.dispose();
    endCtrl.dispose();
  }

  Future<void> _showDeleteOtConfirm(
    int recordId,
    String empId,
    String name,
    String otDateStr,
    int rowIndex, {
    String begin = '',
    String end = '',
  }) async {
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
              const Icon(
                Icons.delete_outline,
                color: AppColors.dangerText,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Delete Overtime Record',
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
              'Are you sure you want to delete this record?',
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
                            'OT Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            otDateStr,
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
                            '$begin – $end',
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
              await App.mongoDb.deleteOtRegister(
                recordId,
                logDetail: '$empId ($name) OT $otDateStr $begin–$end',
              );
              App.gValue.otRegisters.removeWhere((e) => e.id == recordId);
              if (!mounted) return;
              overlay.hide();
              _otDataSource.removeRow(rowIndex);
              showToast('Overtime record deleted');
            },
          ),
        ],
      ),
    );
  }

  /// Returns existing OT records that overlap with the given [empIds] × [dates] × [timeBegin–timeEnd].
  List<OtRegister> _findOtOverlaps(
    List<String> empIds,
    List<DateTime> dates,
    String timeBegin,
    String timeEnd,
  ) {
    final dateStrs = dates
        .map((d) => DateFormat('yyyy-MM-dd').format(d))
        .toSet();
    return App.gValue.otRegisters.where((ot) {
      if (!empIds.contains(ot.empId)) return false;
      final otDateStr = DateFormat('yyyy-MM-dd').format(ot.otDate);
      if (!dateStrs.contains(otDateStr)) return false;
      // Time overlap: existingBegin < newEnd AND existingEnd > newBegin
      return ot.otTimeBegin.compareTo(timeEnd) < 0 &&
          ot.otTimeEnd.compareTo(timeBegin) > 0;
    }).toList();
  }

  Future<void> _saveOtRegisters(BuildContext ctx) async {
    final baseId = DateTime.now().millisecondsSinceEpoch;
    final ots = <OtRegister>[];
    int index = 0;
    for (final empId in _selectedEmpIds) {
      final emp = App.gValue.employees.firstWhere(
        (e) => e.empId == empId,
        orElse: () => Employee(empId: empId, attFingerId: 0, name: empId),
      );
      for (final date in _otSelectedDates) {
        ots.add(
          OtRegister(
            id: baseId + index++,
            requestNo:
                '${DateFormat('yyyyMMddhhMM').format(DateTime.now())}_${emp.empId?.substring(5) ?? empId.substring(5)}',
            requestDate: DateTime.now(),
            otDate: date,
            otTimeBegin: _otTimeBeginController.text.trim(),
            otTimeEnd: _otTimeEndController.text.trim(),
            empId: empId,
            name: emp.name ?? empId,
          ),
        );
      }
    }

    // Split into pass / fail by per-record overlap check
    final passed = <OtRegister>[];
    final failed = <OtRegister>[];
    final failedOverlaps = <OtRegister, List<OtRegister>>{};
    for (final ot in ots) {
      final found = _findOtOverlaps(
        [ot.empId],
        [ot.otDate],
        ot.otTimeBegin,
        ot.otTimeEnd,
      );
      if (found.isNotEmpty) {
        failed.add(ot);
        failedOverlaps[ot] = found;
      } else {
        passed.add(ot);
      }
    }

    if (passed.isNotEmpty) {
      final overlay = context.loaderOverlay;
      overlay.show();
      await App.mongoDb.insertOtRegisters(passed);
      if (!mounted) return;
      overlay.hide();
      App.gValue.otRegisters.addAll(passed);
      _otDataSource.insertRows(passed);
      setState(() {
        _selectedEmpIds.clear();
        _otSelectedDates = [];
      });
    }

    if (!mounted) return;
    // Show summary
    await showDialog(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: Row(
          children: [
            Icon(
              failed.isEmpty ? Icons.check_circle : Icons.info_outline,
              color: failed.isEmpty ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 8),
            const Text('Save Summary'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${ots.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${passed.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        const Text(
                          'Success',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${failed.length}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: failed.isEmpty
                                ? AppColors.textTertiary
                                : AppColors.danger,
                          ),
                        ),
                        Text(
                          'Failed',
                          style: TextStyle(
                            fontSize: 12,
                            color: failed.isEmpty
                                ? AppColors.textTertiary
                                : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ...passed.map(
                        (ot) => ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 18,
                          ),
                          title: Text(
                            '${ot.empId}  ${ot.name}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            '${DateFormat('yyyy-MM-dd').format(ot.otDate)}  ${ot.otTimeBegin}–${ot.otTimeEnd}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      ...failed.map((ot) {
                        final overlaps = failedOverlaps[ot] ?? [];
                        final overlapDetail = overlaps
                            .map((o) =>
                                '${DateFormat('yyyy-MM-dd').format(o.otDate)} ${o.otTimeBegin}–${o.otTimeEnd}')
                            .join(', ');
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: const Icon(
                            Icons.cancel,
                            color: AppColors.danger,
                            size: 18,
                          ),
                          title: Text(
                            '${ot.empId}  ${ot.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.danger,
                            ),
                          ),
                          subtitle: Text(
                            '${DateFormat('yyyy-MM-dd').format(ot.otDate)}  ${ot.otTimeBegin}–${ot.otTimeEnd}\n'
                            '↳ overlap with: $overlapDetail',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.danger,
                            ),
                          ),
                        );
                      }),
                    ],
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
  }

  Widget _buildEmployeeMultiSelect({VoidCallback? onChanged}) {
    final empMap = MyFunctions.getEmployeeMap();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Mywidget.dateRangeWidget(App.gValue.dateRangeOvertime),

                SfDateRangePicker(
                  controller: _pickerController,
                  initialSelectedRange: _initialSelectedRange,
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
                    showWeekNumber: false,
                    firstDayOfWeek: 1,
                    weekendDays: [7],
                  ),
                  enableMultiView: true,
                  minDate: DateTime.utc(2023, 12, 26),
                  maxDate: DateTime.now().add(const Duration(days: 60)),
                  todayHighlightColor: AppColors.primary,
                  selectionColor: AppColors.primary,
                  onSubmit: (value) {
                    if (value == null) {
                      App.gValue.dateRangeOvertime = [
                        DateTime.now().toBeginDay(),
                        DateTime.now().toEndDay(),
                      ];
                    } else {
                      final parsed = MyFunctions.extractDateRangeFromPicker(
                        value,
                      );
                      if (parsed.length == 2) {
                        App.gValue.dateRangeOvertime = parsed;
                      } else {
                        return;
                      }
                    }
                    MyFunctions.loadData('overtime', context).then((_) {
                      if (!mounted) return;
                      setState(() {
                        _isFilteringOverlaps = false;
                        _otDataSource = OtRegisterDataSource(
                          otRegisters: App.gValue.otRegisters,
                        );
                      });
                    });
                  },
                  onCancel: () {
                    App.gValue.dateRangeOvertime = [
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    ];
                    _pickerController.selectedRange = PickerDateRange(
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    );
                    MyFunctions.loadData('overtime', context).then((_) {
                      if (!mounted) return;
                      setState(() {
                        _otDataSource = OtRegisterDataSource(
                          otRegisters: App.gValue.otRegisters,
                        );
                      });
                    });
                  },
                  showActionButtons: true,
                  selectionMode: DateRangePickerSelectionMode.range,
                ),

                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        onPressed: App.gValue.permission == 'edit'
                            ? () => _showAddOtDialog(context)
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

                      TextButton.icon(
                        onPressed: () async {
                          final overlay = context.loaderOverlay;
                          overlay.show();
                          await MyFunctions.exportGridToExcel(
                            source: _otDataSource,
                            headers: [
                              'Request No',
                              'Request Date',
                              'OT Date',
                              'Begin',
                              'End',
                              'Emp ID',
                              'Name',
                              'Group',
                            ],
                            type: 'Overtime',
                          );
                          overlay.hide();
                        },
                        icon: const Icon(
                          Icons.download,
                          color: AppColors.success,
                        ),
                        label: const Text(
                          'Export',
                          style: TextStyle(color: AppColors.success),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final overlay = context.loaderOverlay;
                          overlay.show();
                          await MyFunctions.exportTemplate(
                            headers: ['OT Date', 'Begin', 'End', 'Emp ID'],
                            type: 'Overtime',
                            source: _otDataSource,
                            columnIndices: [2, 3, 4, 5],
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
                                final ots =
                                    await MyFunctions.importOtRegisters();
                                if (ots == null || ots.isEmpty) return;
                                if (!mounted) return;
                                // Split into pass / fail by overlap check
                                final passed = <OtRegister>[];
                                final failed = <OtRegister>[];
                                for (final ot in ots) {
                                  final found = _findOtOverlaps(
                                    [ot.empId],
                                    [ot.otDate],
                                    ot.otTimeBegin,
                                    ot.otTimeEnd,
                                  );
                                  if (found.isNotEmpty) {
                                    failed.add(ot);
                                  } else {
                                    passed.add(ot);
                                  }
                                }
                                // Save only non-overlapping records
                                if (passed.isNotEmpty) {
                                  final overlay = context.loaderOverlay;
                                  overlay.show();
                                  await App.mongoDb.insertOtRegisters(passed);
                                  if (!mounted) return;
                                  overlay.hide();
                                  App.gValue.otRegisters.addAll(passed);
                                  _otDataSource.insertRows(passed);
                                }
                                if (!mounted) return;
                                // Show summary dialog
                                await showDialog(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                    title: Row(
                                      children: [
                                        Icon(
                                          failed.isEmpty
                                              ? Icons.check_circle
                                              : Icons.info_outline,
                                          color: failed.isEmpty
                                              ? AppColors.success
                                              : AppColors.warning,
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
                                          // Summary counts
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
                                                      '${ots.length}',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const Text(
                                                      'Total',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  children: [
                                                    Text(
                                                      '${passed.length}',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                    ),
                                                    const Text(
                                                      'Success',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  children: [
                                                    Text(
                                                      '${failed.length}',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: failed.isEmpty
                                                            ? AppColors
                                                                  .textTertiary
                                                            : AppColors.danger,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Failed',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: failed.isEmpty
                                                            ? AppColors
                                                                  .textTertiary
                                                            : AppColors.danger,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          // Detail list
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 300,
                                            ),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  ...passed.map(
                                                    (ot) => ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      leading: const Icon(
                                                        Icons.check_circle,
                                                        color:
                                                            AppColors.success,
                                                        size: 18,
                                                      ),
                                                      title: Text(
                                                        '${ot.empId}  ${ot.name}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        '${DateFormat('yyyy-MM-dd').format(ot.otDate)}  ${ot.otTimeBegin}–${ot.otTimeEnd}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  ...failed.map(
                                                    (ot) => ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      leading: const Icon(
                                                        Icons.cancel,
                                                        color: AppColors.danger,
                                                        size: 18,
                                                      ),
                                                      title: Text(
                                                        '${ot.empId}  ${ot.name}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              AppColors.danger,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        '${DateFormat('yyyy-MM-dd').format(ot.otDate)}  ${ot.otTimeBegin}–${ot.otTimeEnd}  (overlap)',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              AppColors.danger,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
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

                _OtSummaryBox(App.gValue.otRegisters),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _isFilteringOverlaps
                    ? AppColors.warningTint
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isFilteringOverlaps
                      ? AppColors.warning
                      : AppColors.border,
                  width: _isFilteringOverlaps ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SfDataGridTheme(
                data: SfDataGridThemeData(
                  selectionColor: AppColors.primaryTint,
                  headerColor: _isFilteringOverlaps
                      ? AppColors.warningTint
                      : AppColors.primaryTint,
                  gridLineColor: AppColors.border,
                  gridLineStrokeWidth: 0.5,
                  rowHoverColor: AppColors.surfaceAlt,
                ),
                child: SfDataGrid(
                  controller: _dataGridController,
                  source: _otDataSource,
                  selectionMode: SelectionMode.single,
                  navigationMode: GridNavigationMode.cell,
                  allowMultiColumnSorting: true,
                  allowColumnsDragging: true,
                  allowFiltering: true,
                  allowSorting: true,
                  allowPullToRefresh: true,
                  columnWidthMode: ColumnWidthMode.fill,
                  highlightRowOnHover: true,
                  showColumnHeaderIconOnHover: true,
                  gridLinesVisibility: GridLinesVisibility.horizontal,
                  headerGridLinesVisibility: GridLinesVisibility.horizontal,
                  onCellSecondaryTap: _handleOtCellAction,
                  columns: [
                    GridColumn(
                      columnName: 'requestNo',
                      label: const Text('Request No'),
                      width: 160,
                    ),
                    GridColumn(
                      columnName: 'requestDate',
                      label: const Text('Request Date'),
                      width: 110,
                    ),
                    GridColumn(
                      columnName: 'otDate',
                      label: const Text('OT Date'),
                      width: 100,
                    ),
                    GridColumn(
                      columnName: 'otTimeBegin',
                      label: const Text('Begin'),
                      width: 70,
                    ),
                    GridColumn(
                      columnName: 'otTimeEnd',
                      label: const Text('End'),
                      width: 70,
                    ),
                    GridColumn(
                      columnName: 'empId',
                      label: const Text('Emp ID'),
                      width: 90,
                    ),
                    GridColumn(columnName: 'name', label: const Text('Name')),
                    GridColumn(
                      columnName: 'group',
                      label: const Text('Group'),
                      width: 130,
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
}

class OtRegisterDataSource extends DataGridSource {
  OtRegisterDataSource({required List<OtRegister> otRegisters}) {
    final reversed = otRegisters.reversed.toList();
    _ids = reversed.map((e) => e.id).toList();
    _rows = reversed.map<DataGridRow>((e) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(columnName: 'requestNo', value: e.requestNo),
          DataGridCell<String>(
            columnName: 'requestDate',
            value: DateFormat('dd/MM/yyyy').format(e.requestDate),
          ),
          DataGridCell<String>(
            columnName: 'otDate',
            value: DateFormat('dd/MM/yyyy').format(e.otDate),
          ),
          DataGridCell<String>(columnName: 'otTimeBegin', value: e.otTimeBegin),
          DataGridCell<String>(columnName: 'otTimeEnd', value: e.otTimeEnd),
          DataGridCell<String>(columnName: 'empId', value: e.empId),
          DataGridCell<String>(columnName: 'name', value: e.name),
          DataGridCell<String>(columnName: 'group', value: _getGroup(e.empId)),
        ],
      );
    }).toList();
  }

  List<DataGridRow> _rows = [];
  List<int> _ids = [];

  int getId(int rowIndex) => _ids[rowIndex];

  void insertRows(List<OtRegister> ots) {
    final newRows = ots.map<DataGridRow>((e) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(columnName: 'requestNo', value: e.requestNo),
          DataGridCell<String>(
            columnName: 'requestDate',
            value: DateFormat('dd/MM/yyyy').format(e.requestDate),
          ),
          DataGridCell<String>(
            columnName: 'otDate',
            value: DateFormat('dd/MM/yyyy').format(e.otDate),
          ),
          DataGridCell<String>(columnName: 'otTimeBegin', value: e.otTimeBegin),
          DataGridCell<String>(columnName: 'otTimeEnd', value: e.otTimeEnd),
          DataGridCell<String>(columnName: 'empId', value: e.empId),
          DataGridCell<String>(columnName: 'name', value: e.name),
          DataGridCell<String>(columnName: 'group', value: _getGroup(e.empId)),
        ],
      );
    }).toList();
    _rows.insertAll(0, newRows);
    _ids.insertAll(0, ots.map((e) => e.id).toList());
    notifyListeners();
  }

  void removeRow(int index) {
    _rows.removeAt(index);
    _ids.removeAt(index);
    notifyListeners();
  }

  void updateRow(int index, DateTime otDate, String begin, String end) {
    final old = _rows[index].getCells();
    _rows[index] = DataGridRow(
      cells: [
        old[0], // requestNo
        old[1], // requestDate
        DataGridCell<String>(
          columnName: 'otDate',
          value: DateFormat('dd/MM/yyyy').format(otDate),
        ),
        DataGridCell<String>(columnName: 'otTimeBegin', value: begin),
        DataGridCell<String>(columnName: 'otTimeEnd', value: end),
        old[5], // empId
        old[6], // name
        old[7], // group
      ],
    );
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isNum = cell.value is int || cell.value is double;
        final isLeft = cell.columnName == 'name' || cell.columnName == 'group';
        return Container(
          alignment: isLeft
              ? Alignment.centerLeft
              : isNum
              ? Alignment.centerRight
              : Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(cell.value.toString()),
        );
      }).toList(),
    );
  }

  String _getGroup(String empId) {
    final emp = App.gValue.employees.firstWhere(
      (e) => e.empId == empId,
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
    return emp.group ?? '';
  }
}

// ── OT Summary ────────────────────────────────────────────────────────────────

class _OtSummaryBox extends StatelessWidget {
  const _OtSummaryBox(this.records);
  final List<OtRegister> records;

  @override
  Widget build(BuildContext context) {
    final totalRecords = records.length;
    final totalEmployees = records.map((r) => r.empId).toSet().length;
    final totalDates = records
        .map((r) => DateFormat('yyyy-MM-dd').format(r.otDate))
        .toSet()
        .length;

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
          row('Total OT Dates', '$totalDates'),
        ],
      ),
    );
  }
}
