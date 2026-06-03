import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/ui/contextMenu.dart';
import 'package:attandance_client/main.dart';
import 'package:attandance_client/model/employee.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:oktoast/oktoast.dart';
import 'package:attandance_client/appLogger.dart';

class EmployeeTab extends StatefulWidget {
  const EmployeeTab({super.key});

  @override
  State<EmployeeTab> createState() => _EmployeeTabState();
}

class _EmployeeTabState extends State<EmployeeTab> {
  EmployeeDataSource employeeDataSource = EmployeeDataSource(
    employeeData: App.gValue.employees,
  );

  @override
  void initState() {
    logger.t('EmployeeTab initState');
    App.gValue.employees.length > 0
        ? setState(() {
            employeeDataSource = EmployeeDataSource(
              employeeData: App.gValue.employees,
            );
          })
        : Future.delayed(const Duration(milliseconds: 2000)).then((_) async {
            if (!mounted) return;
            setState(() {
              employeeDataSource = EmployeeDataSource(
                employeeData: App.gValue.employees,
              );
            });
          });

    super.initState();
  }

  static final DateTime _nullDate = DateTime.utc(2099, 12, 31);
  static final DateFormat _fmt = DateFormat('dd-MM-yyyy');

  Employee _findEmployee(String empId) {
    return App.gValue.employees.firstWhere(
      (e) => e.empId == empId,
      orElse: () => Employee(empId: empId),
    );
  }

  Future<void> _showEditMaternityDialog(Employee emp) async {
    DateTime mBegin = emp.maternityBegin ?? _nullDate;
    DateTime mlBegin = emp.maternityLeaveBegin ?? _nullDate;
    DateTime mlEnd = emp.maternityLeaveEnd ?? _nullDate;
    DateTime mEnd = emp.maternityEnd ?? _nullDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget dateRow(
            String label,
            DateTime value,
            ValueChanged<DateTime> onChanged,
          ) {
            final isNull = value.year == 2099;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: isNull ? DateTime.now() : value,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2099, 12, 31),
                        );
                        if (picked != null) setLocal(() => onChanged(picked));
                      },
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
                              isNull ? '—' : _fmt.format(value),
                              style: TextStyle(
                                fontSize: 13,
                                color: isNull
                                    ? AppColors.textTertiary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (!isNull)
                              GestureDetector(
                                onTap: () =>
                                    setLocal(() => onChanged(_nullDate)),
                                child: const Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: AppColors.textTertiary,
                                ),
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

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            titlePadding: EdgeInsets.zero,
            title: Container(
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                  const Expanded(
                    child: Text(
                      'Edit Maternity',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${emp.empId}  ·  ${emp.name}',
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
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          '${emp.empId}  ·  ${emp.name}  ·  ${emp.group ?? ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  dateRow(
                    'Maternity Begin / Ngày bắt đầu chế độ mang thai',
                    mBegin,
                    (d) => mBegin = d,
                  ),
                  dateRow(
                    'Maternity Leave Begin / Ngày bắt đầu nghỉ thai sản',
                    mlBegin,
                    (d) => mlBegin = d,
                  ),
                  dateRow(
                    'Maternity Leave End / Ngày kết thúc nghỉ thai sản',
                    mlEnd,
                    (d) => mlEnd = d,
                  ),
                  dateRow(
                    'Maternity End / Ngày kết thúc chế độ con nhỏ',
                    mEnd,
                    (d) => mEnd = d,
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save'),
                onPressed: () {
                  final hasBegin = mBegin.year != 2099;
                  final hasEnd = mEnd.year != 2099;
                  final hasLBegin = mlBegin.year != 2099;
                  final hasLEnd = mlEnd.year != 2099;

                  // Phải có cả maternityBegin và maternityEnd
                  if ((hasBegin || hasEnd) && !(hasBegin && hasEnd)) {
                    showToast('Phải nhập cả Maternity Begin và Maternity End');
                    return;
                  }
                  // Nếu có maternityLeaveBegin thì phải có maternityLeaveEnd
                  if (hasLBegin != hasLEnd) {
                    showToast(
                      'Phải nhập cả Maternity Leave Begin và Maternity Leave End',
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
              ),
            ],
          );
        },
      ),
    );

    if (saved != true || !mounted) return;

    final overlay = context.loaderOverlay;
    overlay.show();

    final oldValues =
        [
              emp.maternityBegin,
              emp.maternityLeaveBegin,
              emp.maternityLeaveEnd,
              emp.maternityEnd,
            ]
            .map((d) => d == null || d.year == 2099 ? 'null' : _fmt.format(d))
            .join(', ');
    final newValues = [
      mBegin,
      mlBegin,
      mlEnd,
      mEnd,
    ].map((d) => d.year == 2099 ? 'null' : _fmt.format(d)).join(', ');

    await App.mongoDb.updateEmployeeMaternity(
      emp.empId!,
      maternityBegin: mBegin,
      maternityLeaveBegin: mlBegin,
      maternityLeaveEnd: mlEnd,
      maternityEnd: mEnd,
      logDetail: '${emp.empId} (${emp.name}) [$oldValues] → [$newValues]',
    );

    // Update local employee object
    emp.maternityBegin = mBegin;
    emp.maternityLeaveBegin = mlBegin;
    emp.maternityLeaveEnd = mlEnd;
    emp.maternityEnd = mEnd;

    if (!mounted) return;
    overlay.hide();
    setState(() {
      employeeDataSource = EmployeeDataSource(
        employeeData: App.gValue.employees,
      );
    });
    showToast('Updated maternity for ${emp.empId}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
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
            source: employeeDataSource,
            selectionMode: SelectionMode.single,
            navigationMode: GridNavigationMode.row,
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
            onCellSecondaryTap: (details) {
              if (App.gValue.permission != 'edit') return;
              final rowIndex = details.rowColumnIndex.rowIndex - 1;
              final effectiveRows = employeeDataSource.effectiveRows;
              if (rowIndex < 0 || rowIndex >= effectiveRows.length) return;
              final cells = effectiveRows[rowIndex].getCells();
              final empId =
                  cells.firstWhere((c) => c.columnName == 'empID').value
                      as String;
              final emp = _findEmployee(empId);
              if (emp.gender!.startsWith('M')) {
                showToast('Maternity edit only available for female employees');
                return;
              }
              final pos = details.globalPosition;
              showContextMenu(
                context,
                pos,
                onEdit: () {
                  _showEditMaternityDialog(emp);
                },
              );
            },
            columns: [
              GridColumn(
                columnName: 'empID',
                label: const Center(child: Text('ID')),
              ),
              GridColumn(
                columnName: 'attId',
                label: const Center(child: Text('Att ID')),
              ),
              GridColumn(columnName: 'name', label: const Text('  Full Name')),
              GridColumn(columnName: 'group', label: const Text('  Group')),
              GridColumn(
                columnName: 'position',
                label: const Text('  Position'),
              ),
              GridColumn(
                columnName: 'joiningDate',
                label: const Center(child: Text('Joining Date')),
              ),
              GridColumn(
                columnName: 'workStatus',
                label: const Center(child: Text('Work Status')),
              ),
              GridColumn(
                columnName: 'resignOn',
                label: const Center(child: Text('Resign On')),
              ),
              GridColumn(
                columnName: 'maternityBegin',
                width: 110,
                label: const Center(child: Text('Mat. Begin')),
              ),
              GridColumn(
                columnName: 'maternityLeaveBegin',
                width: 120,
                label: const Center(child: Text('Mat. L.Begin')),
              ),
              GridColumn(
                columnName: 'maternityLeaveEnd',
                width: 120,
                label: const Center(child: Text('Mat. L.End')),
              ),
              GridColumn(
                columnName: 'maternityEnd',
                width: 110,
                label: const Center(child: Text('Mat. End')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeDataSource extends DataGridSource {
  /// Creates the employee data source class with required details.
  EmployeeDataSource({required List<Employee> employeeData}) {
    _employeeData = employeeData
        .map<DataGridRow>(
          (e) => DataGridRow(
            cells: [
              DataGridCell<String>(columnName: 'empID', value: e.empId),
              DataGridCell<int>(columnName: 'attId', value: e.attFingerId),
              DataGridCell<String>(columnName: 'name', value: e.name),
              DataGridCell<String>(columnName: 'group', value: e.group),
              DataGridCell<String>(columnName: 'position', value: e.position),
              DataGridCell<String>(
                columnName: 'joiningDate',
                value: e.joiningDate?.year != 1900
                    ? DateFormat('dd-MM-yyyy').format(e.joiningDate!)
                    : '',
              ),
              DataGridCell<String>(
                columnName: 'workStatus',
                value: e.workStatus,
              ),
              DataGridCell<String>(
                columnName: 'resignOn',
                value: e.resignOn?.year != 2099
                    ? DateFormat('dd-MM-yyyy').format(e.resignOn!)
                    : '',
              ),
              DataGridCell<String>(
                columnName: 'maternityBegin',
                value:
                    e.maternityBegin != null && e.maternityBegin!.year != 2099
                    ? DateFormat('dd-MM-yyyy').format(e.maternityBegin!)
                    : '',
              ),
              DataGridCell<String>(
                columnName: 'maternityLeaveBegin',
                value:
                    e.maternityLeaveBegin != null &&
                        e.maternityLeaveBegin!.year != 2099
                    ? DateFormat('dd-MM-yyyy').format(e.maternityLeaveBegin!)
                    : '',
              ),
              DataGridCell<String>(
                columnName: 'maternityLeaveEnd',
                value:
                    e.maternityLeaveEnd != null &&
                        e.maternityLeaveEnd!.year != 2099
                    ? DateFormat('dd-MM-yyyy').format(e.maternityLeaveEnd!)
                    : '',
              ),
              DataGridCell<String>(
                columnName: 'maternityEnd',
                value: e.maternityEnd != null && e.maternityEnd!.year != 2099
                    ? DateFormat('dd-MM-yyyy').format(e.maternityEnd!)
                    : '',
              ),
            ],
          ),
        )
        .toList();
  }

  List<DataGridRow> _employeeData = [];

  @override
  List<DataGridRow> get rows => _employeeData;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    const leftCols = {'name', 'group', 'position'};
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        final isLeft = leftCols.contains(cell.columnName);
        return Container(
          alignment: isLeft ? Alignment.centerLeft : Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color:
              cell.columnName == 'workStatus' &&
                  cell.value.toString() == 'Resigned'
              ? AppColors.border
              : null,
          child: Text(cell.value.toString()),
        );
      }).toList(),
    );
  }
}
