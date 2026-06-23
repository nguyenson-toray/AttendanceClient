import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/functions/myFunctions.dart';
import 'package:attandance_client/main.dart';
import 'package:attandance_client/model/history.dart';
import 'package:attandance_client/ui/myWidget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  HistoryDataSource _histDataSource = HistoryDataSource(
    histories: App.gValue.histories,
  );

  final DateRangePickerController _pickerController =
      DateRangePickerController();

  PickerDateRange get _initialSelectedRange => PickerDateRange(
    App.gValue.dateRangeHistory[0],
    App.gValue.dateRangeHistory[1],
  );

  @override
  void initState() {
    super.initState();
    if (App.gValue.histories.isNotEmpty) {
      setState(() {
        _histDataSource = HistoryDataSource(histories: App.gValue.histories);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 2000)).then((_) {
        if (!mounted) return;
        _reload();
      });
    }
  }

  Future<void> _reload() async {
    final overlay = context.loaderOverlay;
    overlay.show();
    App.gValue.histories = await App.mongoDb.getHistory(
      App.gValue.dateRangeHistory,
    );
    if (!mounted) return;
    overlay.hide();
    setState(() {
      _histDataSource = HistoryDataSource(histories: App.gValue.histories);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 400,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mywidget.dateRangeWidget(App.gValue.dateRangeHistory),
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
                  maxDate: DateTime.now(),
                  todayHighlightColor: AppColors.primary,
                  selectionColor: AppColors.primary,
                  onSubmit: (value) {
                    if (value == null) {
                      App.gValue.dateRangeHistory = [
                        DateTime.now()
                            .subtract(const Duration(days: 7))
                            .toBeginDay(),
                        DateTime.now().toEndDay(),
                      ];
                    } else {
                      App.gValue.dateRangeHistory =
                          MyFunctions.extractDateRange(value.toString());
                    }
                    _reload();
                  },
                  onCancel: () {
                    App.gValue.dateRangeHistory = [
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    ];
                    _pickerController.selectedRange = PickerDateRange(
                      DateTime.now().toBeginDay(),
                      DateTime.now().toEndDay(),
                    );
                    _reload();
                  },
                  showActionButtons: true,
                  selectionMode: DateRangePickerSelectionMode.range,
                ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Total history records: ${App.gValue.histories.length}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
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
                  source: _histDataSource,
                  allowMultiColumnSorting: true,
                  allowColumnsDragging: true,
                  allowFiltering: true,
                  allowSorting: true,
                  columnWidthMode: ColumnWidthMode.fill,
                  highlightRowOnHover: true,
                  showColumnHeaderIconOnHover: true,
                  gridLinesVisibility: GridLinesVisibility.horizontal,
                  headerGridLinesVisibility: GridLinesVisibility.horizontal,
                  columns: [
                    GridColumn(
                      columnName: 'time',
                      label: const Text('Time'),
                      width: 150,
                    ),
                    GridColumn(
                      columnName: 'pcName',
                      label: const Text('PC Name'),
                      width: 130,
                    ),
                    GridColumn(columnName: 'log', label: const Text('Log')),
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

class HistoryDataSource extends DataGridSource {
  HistoryDataSource({required List<History> histories}) {
    _rows = histories.map<DataGridRow>((e) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(
            columnName: 'time',
            value: DateFormat('yyyy-MM-dd HH:mm:ss').format(e.time),
          ),
          DataGridCell<String>(columnName: 'pcName', value: e.pcName),
          DataGridCell<String>(columnName: 'log', value: e.log),
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
        final isLog = cell.columnName == 'log';
        return Container(
          alignment: isLog ? Alignment.centerLeft : Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            cell.value.toString(),
            style: TextStyle(
              fontSize: 12,
              color: isLog ? AppColors.textSecondary : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
