import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/ui/contextMenu.dart';
import 'package:attandance_client/functions/myFunctions.dart';
import 'package:attandance_client/model/employee.dart';
import 'package:attandance_client/model/shiftRegister.dart';
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

class ShiftTab extends StatefulWidget {
  const ShiftTab({super.key});

  @override
  State<ShiftTab> createState() => ShiftTabState();
}

class ShiftTabState extends State<ShiftTab> {
  ShiftRegisterDataSource _shiftDataSource = ShiftRegisterDataSource(
    shiftRegisters: App.gValue.shiftRegisters,
  );
  final DataGridController _dataGridController = DataGridController();
  final List<String> _selectedEmpIds = [];
  final TextEditingController _empSearchController = TextEditingController();
  final SuggestionsBoxController _suggestionsBoxController =
      SuggestionsBoxController();
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _selectedShift = 'Shift 1';
  static const List<String> _shiftOptions = ['Shift 1', 'Shift 2'];

  bool _isFilteringOverlaps = false;

  void _handleShiftCellAction(DataGridCellTapDetails details) {
    if (App.gValue.permission != 'edit') return;
    final visualIndex = details.rowColumnIndex.rowIndex - 1;
    final effectiveRows = _shiftDataSource.effectiveRows;
    if (visualIndex < 0 || visualIndex >= effectiveRows.length) return;
    final row = effectiveRows[visualIndex];
    final cells = row.getCells();
    final empId =
        cells.firstWhere((c) => c.columnName == 'empId').value as String;
    final name =
        cells.firstWhere((c) => c.columnName == 'name').value as String;
    final fromDateStr =
        cells.firstWhere((c) => c.columnName == 'fromDate').value as String;
    final toDateStr =
        cells.firstWhere((c) => c.columnName == 'toDate').value as String;
    final shift =
        cells.firstWhere((c) => c.columnName == 'shift').value as String;
    final dataIndex = _shiftDataSource.rows.indexOf(row);
    if (dataIndex < 0) return;
    final objectId = _shiftDataSource.getObjectId(dataIndex);
    final fromDate = DateTime.tryParse(fromDateStr) ?? DateTime.now();
    final toDate = DateTime.tryParse(toDateStr) ?? DateTime.now();
    final pos = details.globalPosition;
    showContextMenu(
      context,
      pos,
      onEdit: () {
        _showEditShiftDialog(
          objectId,
          fromDate,
          toDate,
          shift,
          dataIndex,
          empId: empId,
          name: name,
        );
      },
      onDelete: () {
        _showDeleteShiftConfirm(
          objectId,
          empId,
          name,
          fromDateStr,
          toDateStr,
          shift,
          dataIndex,
        );
      },
    );
  }

  final DateRangePickerController _pickerController =
      DateRangePickerController();

  PickerDateRange get _initialSelectedRange => PickerDateRange(
    App.gValue.dateRangeShift[0],
    App.gValue.dateRangeShift[1],
  );

  @override
  void initState() {
    super.initState();
    App.gValue.shiftRegisters.isNotEmpty
        ? setState(() {
            _shiftDataSource = ShiftRegisterDataSource(
              shiftRegisters: App.gValue.shiftRegisters,
            );
          })
        : Future.delayed(const Duration(milliseconds: 2000)).then((_) {
            if (!mounted) return;
            setState(() {
              _shiftDataSource = ShiftRegisterDataSource(
                shiftRegisters: App.gValue.shiftRegisters,
              );
            });
          });
  }

  @override
  void dispose() {
    _empSearchController.dispose();
    super.dispose();
  }

  void refreshData() {
    setState(() {
      _isFilteringOverlaps = false;
      _shiftDataSource = ShiftRegisterDataSource(
        shiftRegisters: App.gValue.shiftRegisters,
      );
    });
  }

  void filterOverlaps() {
    final fmt = DateFormat('yyyy-MM-dd');
    final records = App.gValue.shiftRegisters;
    final overlaps = <ShiftRegister>{};
    for (int i = 0; i < records.length; i++) {
      for (int j = i + 1; j < records.length; j++) {
        final a = records[i];
        final b = records[j];
        if (a.empId != b.empId) continue;
        // Skip exact duplicates (same dates & shift)
        if (a.fromDate == b.fromDate &&
            a.toDate == b.toDate &&
            a.shift == b.shift) {
          continue;
        }
        if (!a.fromDate.isAfter(b.toDate) && !a.toDate.isBefore(b.fromDate)) {
          overlaps.add(a);
          overlaps.add(b);
        }
      }
    }
    setState(() {
      _isFilteringOverlaps = overlaps.isNotEmpty;
      _shiftDataSource = ShiftRegisterDataSource(
        shiftRegisters: overlaps.toList(),
      );
    });
    final range = App.gValue.dateRangeShift;
    showToast(
      overlaps.isEmpty
          ? 'No Shift overlaps (${fmt.format(range[0])} → ${fmt.format(range[1])})'
          : '${overlaps.length} overlapping Shift records found',
    );
  }

  Future<void> _showAddShiftDialog(BuildContext ctx) async {
    _selectedEmpIds.clear();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _selectedShift = _shiftOptions.first;
    await showDialog(
      context: ctx,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add shift record'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select employees:'),
                const SizedBox(height: 8),
                _buildEmployeeMultiSelect(onChanged: () => setLocal(() {})),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('From: '),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('yyyy-MM-dd').format(_fromDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: _fromDate,
                          firstDate: DateTime(2023, 12, 26),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) setLocal(() => _fromDate = picked);
                      },
                    ),
                    const SizedBox(width: 12),
                    const Text('To: '),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('yyyy-MM-dd').format(_toDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: _toDate,
                          firstDate: DateTime(2023, 12, 26),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) setLocal(() => _toDate = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Shift: '),
                    ..._shiftOptions.map(
                      (s) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(
                            value: s,
                            groupValue: _selectedShift,
                            onChanged: (v) {
                              if (v != null) setLocal(() => _selectedShift = v);
                            },
                          ),
                          Text(s),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ],
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
              onPressed: _selectedEmpIds.isEmpty
                  ? null
                  : () async {
                      // ── Overlap validation ────────────────────────────────
                      final overlaps = _findOverlaps(
                        _selectedEmpIds,
                        _fromDate,
                        _toDate,
                      );
                      if (overlaps.isNotEmpty) {
                        await showDialog(
                          context: ctx,
                          builder: (ctx2) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: AppColors.danger,
                                ),
                                SizedBox(width: 8),
                                Text('Overlapping shift records'),
                              ],
                            ),
                            content: SizedBox(
                              width: 480,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cannot save. The following existing records overlap:',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 260,
                                    ),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: overlaps
                                            .map(
                                              (sr) => Card(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 3,
                                                    ),
                                                color: AppColors.dangerTint,
                                                child: ListTile(
                                                  dense: true,
                                                  leading: const Icon(
                                                    Icons.block,
                                                    color: AppColors.danger,
                                                    size: 18,
                                                  ),
                                                  title: Text(
                                                    '${sr.empId}  ${sr.name}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    '${DateFormat('yyyy-MM-dd').format(sr.fromDate)}'
                                                    ' → ${DateFormat('yyyy-MM-dd').format(sr.toDate)}'
                                                    '  [${sr.shift}]',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
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
                        return;
                      }
                      // ── Proceed to save ───────────────────────────────────
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      await _saveShiftRegisters(context);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditShiftDialog(
    String objectId,
    DateTime currentFrom,
    DateTime currentTo,
    String currentShift,
    int rowIndex, {
    String empId = '',
    String name = '',
  }) async {
    DateTime editFrom = currentFrom;
    DateTime editTo = currentTo;
    String editShift = _shiftOptions.contains(currentShift)
        ? currentShift
        : _shiftOptions.first;
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
                    'Edit Shift Record',
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'From',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: editFrom,
                              firstDate: DateTime(2023, 12, 26),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null)
                              setLocal(() => editFrom = picked);
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
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('yyyy-MM-dd').format(editFrom),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'To',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: editTo,
                              firstDate: DateTime(2023, 12, 26),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) setLocal(() => editTo = picked);
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
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('yyyy-MM-dd').format(editTo),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Shift',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._shiftOptions.map(
                    (s) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(
                          value: s,
                          groupValue: editShift,
                          onChanged: (v) {
                            if (v != null) setLocal(() => editShift = v);
                          },
                        ),
                        Text(s),
                        const SizedBox(width: 8),
                      ],
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
                await App.mongoDb.updateShiftRegister(
                  objectId,
                  editFrom,
                  editTo,
                  editShift,
                  logDetail:
                      '${empId.isNotEmpty ? "$empId ($name) " : ""}[${DateFormat("yyyy-MM-dd").format(currentFrom)}→${DateFormat("yyyy-MM-dd").format(currentTo)}] $currentShift → [${DateFormat("yyyy-MM-dd").format(editFrom)}→${DateFormat("yyyy-MM-dd").format(editTo)}] $editShift',
                );
                // Update in-memory list
                final idx = App.gValue.shiftRegisters.indexWhere(
                  (e) => e.objectId == objectId,
                );
                if (idx != -1) {
                  App.gValue.shiftRegisters[idx].fromDate = editFrom;
                  App.gValue.shiftRegisters[idx].toDate = editTo;
                  App.gValue.shiftRegisters[idx].shift = editShift;
                }
                if (!mounted) return;
                overlay.hide();
                _shiftDataSource.updateRow(
                  rowIndex,
                  editFrom,
                  editTo,
                  editShift,
                );
                showToast('Shift record updated');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteShiftConfirm(
    String objectId,
    String empId,
    String name,
    String fromDateStr,
    String toDateStr,
    String shift,
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
                'Delete Shift Record',
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
                            'From',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            fromDateStr,
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
                            'To',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            toDateStr,
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
                            'Shift',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            shift,
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
              await App.mongoDb.deleteShiftRegister(
                objectId,
                logDetail: '$empId ($name) $shift [$fromDateStr → $toDateStr]',
              );
              App.gValue.shiftRegisters.removeWhere(
                (e) => e.objectId == objectId,
              );
              if (!mounted) return;
              overlay.hide();
              _shiftDataSource.removeRow(rowIndex);
              showToast('Shift record deleted');
            },
          ),
        ],
      ),
    );
  }

  /// Returns all existing [ShiftRegister] records for the given [empIds]
  /// whose [fromDate..toDate] range overlaps with [newFrom..newTo].
  List<ShiftRegister> _findOverlaps(
    List<String> empIds,
    DateTime newFrom,
    DateTime newTo,
  ) {
    final newFromDay = newFrom.toBeginDay();
    final newToDay = newTo.toBeginDay();
    return App.gValue.shiftRegisters.where((sr) {
      if (!empIds.contains(sr.empId)) return false;
      // Overlap condition: existing.from <= newTo AND existing.to >= newFrom
      return !sr.fromDate.toBeginDay().isAfter(newToDay) &&
          !sr.toDate.toBeginDay().isBefore(newFromDay);
    }).toList();
  }

  Future<void> _saveShiftRegisters(BuildContext ctx) async {
    final shift = _selectedShift;
    final srs = _selectedEmpIds.map((empId) {
      final emp = App.gValue.employees.firstWhere(
        (e) => e.empId == empId,
        orElse: () => Employee(empId: empId, attFingerId: 0, name: empId),
      );
      return ShiftRegister(
        objectId: '',
        empId: empId,
        name: emp.name ?? empId,
        fromDate: _fromDate,
        toDate: _toDate,
        shift: shift,
      );
    }).toList();

    final overlay = context.loaderOverlay;
    overlay.show();
    await App.mongoDb.insertShiftRegisters(srs);
    if (!mounted) return;
    overlay.hide();
    App.gValue.shiftRegisters.addAll(srs);
    _shiftDataSource.insertRows(srs);
    setState(() {
      _selectedEmpIds.clear();
    });
    showToast('Saved ${srs.length} shift record(s)');
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
                Mywidget.dateRangeWidget(App.gValue.dateRangeShift),
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
                  maxDate: DateTime.now().add(const Duration(days: 365)),
                  todayHighlightColor: AppColors.primary,
                  selectionColor: AppColors.primary,
                  onSubmit: (value) {
                    if (value == null) {
                      App.gValue.dateRangeShift = [
                        DateTime.now().toBeginDay(),
                        DateTime.now().toEndDay(),
                      ];
                    } else {
                      final parsed = MyFunctions.extractDateRangeFromPicker(
                        value,
                      );
                      if (parsed.length == 2) {
                        App.gValue.dateRangeShift = parsed;
                      } else {
                        return;
                      }
                    }
                    MyFunctions.loadData('shift', context).then((_) {
                      if (!mounted) return;
                      setState(() {
                        _isFilteringOverlaps = false;
                        _shiftDataSource = ShiftRegisterDataSource(
                          shiftRegisters: App.gValue.shiftRegisters,
                        );
                      });
                    });
                  },
                  onCancel: () {
                    App.gValue.dateRangeShift = [
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    ];
                    _pickerController.selectedRange = PickerDateRange(
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    );
                    MyFunctions.loadData('shift', context).then((_) {
                      if (!mounted) return;
                      setState(() {
                        _shiftDataSource = ShiftRegisterDataSource(
                          shiftRegisters: App.gValue.shiftRegisters,
                        );
                      });
                    });
                  },
                  showActionButtons: true,
                  selectionMode: DateRangePickerSelectionMode.range,
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton.icon(
                        onPressed: App.gValue.permission == 'edit'
                            ? () => _showAddShiftDialog(context)
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
                            source: _shiftDataSource,
                            headers: [
                              'From Date',
                              'To Date',
                              'Shift',
                              'Emp ID',
                              'Name',
                              'Group',
                            ],
                            type: 'Shift',
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
                            headers: [
                              'From Date',
                              'To Date',
                              'Shift',
                              'Emp ID',
                            ],
                            type: 'Shift',
                            source: _shiftDataSource,
                            columnIndices: [0, 1, 2, 3],
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
                                final srs =
                                    await MyFunctions.importShiftRegisters();
                                if (srs == null || srs.isEmpty) return;
                                if (!mounted) return;
                                // Check overlaps for imported records
                                final overlaps = <ShiftRegister>[];
                                for (final sr in srs) {
                                  final found = _findOverlaps(
                                    [sr.empId],
                                    sr.fromDate,
                                    sr.toDate,
                                  );
                                  overlaps.addAll(found);
                                }
                                // Split into pass / fail by overlap check
                                final passed = <ShiftRegister>[];
                                final failed = <ShiftRegister>[];
                                for (final sr in srs) {
                                  final found = _findOverlaps(
                                    [sr.empId],
                                    sr.fromDate,
                                    sr.toDate,
                                  );
                                  if (found.isNotEmpty) {
                                    failed.add(sr);
                                  } else {
                                    passed.add(sr);
                                  }
                                }
                                // Save only non-overlapping records
                                if (passed.isNotEmpty) {
                                  final overlay = context.loaderOverlay;
                                  overlay.show();
                                  await App.mongoDb.insertShiftRegisters(
                                    passed,
                                  );
                                  if (!mounted) return;
                                  overlay.hide();
                                  App.gValue.shiftRegisters.addAll(passed);
                                  _shiftDataSource.insertRows(passed);
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
                                                      '${srs.length}',
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
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxHeight: 300,
                                            ),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  ...passed.map(
                                                    (sr) => ListTile(
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
                                                        '${sr.empId}  ${sr.name}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        '${DateFormat('yyyy-MM-dd').format(sr.fromDate)} → ${DateFormat('yyyy-MM-dd').format(sr.toDate)}  [${sr.shift}]',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  ...failed.map(
                                                    (sr) => ListTile(
                                                      dense: true,
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      leading: const Icon(
                                                        Icons.cancel,
                                                        color: AppColors.danger,
                                                        size: 18,
                                                      ),
                                                      title: Text(
                                                        '${sr.empId}  ${sr.name}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              AppColors.danger,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        '${DateFormat('yyyy-MM-dd').format(sr.fromDate)} → ${DateFormat('yyyy-MM-dd').format(sr.toDate)}  [${sr.shift}]  (overlap)',
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
                _ShiftSummaryBox(App.gValue.shiftRegisters),
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
                  source: _shiftDataSource,
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
                  onCellSecondaryTap: _handleShiftCellAction,
                  columns: [
                    GridColumn(
                      columnName: 'fromDate',
                      label: const Text('From Date'),
                      width: 110,
                    ),
                    GridColumn(
                      columnName: 'toDate',
                      label: const Text('To Date'),
                      width: 110,
                    ),
                    GridColumn(
                      columnName: 'shift',
                      label: const Text('Shift'),
                      width: 100,
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

class ShiftRegisterDataSource extends DataGridSource {
  ShiftRegisterDataSource({required List<ShiftRegister> shiftRegisters}) {
    final reversed = shiftRegisters.reversed.toList();
    _objectIds = reversed.map((e) => e.objectId).toList();
    _rows = reversed.map<DataGridRow>((e) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'fromDate',
            value: DateFormat('yyyy-MM-dd').format(e.fromDate),
          ),
          DataGridCell<String>(
            columnName: 'toDate',
            value: DateFormat('yyyy-MM-dd').format(e.toDate),
          ),
          DataGridCell<String>(columnName: 'shift', value: e.shift),
          DataGridCell<String>(columnName: 'empId', value: e.empId),
          DataGridCell<String>(columnName: 'name', value: e.name),
          DataGridCell<String>(columnName: 'group', value: _getGroup(e.empId)),
        ],
      );
    }).toList();
  }

  List<DataGridRow> _rows = [];
  List<String> _objectIds = [];

  String getObjectId(int rowIndex) => _objectIds[rowIndex];

  void insertRows(List<ShiftRegister> srs) {
    final newRows = srs.map<DataGridRow>((e) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'fromDate',
            value: DateFormat('yyyy-MM-dd').format(e.fromDate),
          ),
          DataGridCell<String>(
            columnName: 'toDate',
            value: DateFormat('yyyy-MM-dd').format(e.toDate),
          ),
          DataGridCell<String>(columnName: 'shift', value: e.shift),
          DataGridCell<String>(columnName: 'empId', value: e.empId),
          DataGridCell<String>(columnName: 'name', value: e.name),
          DataGridCell<String>(columnName: 'group', value: _getGroup(e.empId)),
        ],
      );
    }).toList();
    _rows.insertAll(0, newRows);
    _objectIds.insertAll(0, srs.map((e) => e.objectId).toList());
    notifyListeners();
  }

  void removeRow(int index) {
    _rows.removeAt(index);
    _objectIds.removeAt(index);
    notifyListeners();
  }

  void updateRow(int index, DateTime fromDate, DateTime toDate, String shift) {
    final old = _rows[index].getCells();
    _rows[index] = DataGridRow(
      cells: [
        DataGridCell<String>(
          columnName: 'fromDate',
          value: DateFormat('yyyy-MM-dd').format(fromDate),
        ),
        DataGridCell<String>(
          columnName: 'toDate',
          value: DateFormat('yyyy-MM-dd').format(toDate),
        ),
        DataGridCell<String>(columnName: 'shift', value: shift),
        old[3], // empId
        old[4], // name
        old[5], // group
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

// ── Shift Summary ─────────────────────────────────────────────────────────────

class _ShiftSummaryBox extends StatelessWidget {
  const _ShiftSummaryBox(this.records);
  final List<ShiftRegister> records;

  @override
  Widget build(BuildContext context) {
    final totalRecords = records.length;
    final totalEmployees = records.map((r) => r.empId).toSet().length;
    final shift1Count = records.where((r) => r.shift == 'Shift 1').length;
    final shift2Count = records.where((r) => r.shift == 'Shift 2').length;

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
          row('Shift 1', '$shift1Count'),
          row('Shift 2', '$shift2Count'),
        ],
      ),
    );
  }
}
