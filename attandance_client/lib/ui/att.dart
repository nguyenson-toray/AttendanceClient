import 'dart:async';
import 'dart:io';
import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/main.dart';
import 'package:attandance_client/functions/myFunctions.dart';
import 'package:attandance_client/services/update_service.dart';
import 'package:attandance_client/ui/updateDialog.dart';
import 'package:oktoast/oktoast.dart';
import 'package:attandance_client/ui/shiftTab.dart';
import 'package:attandance_client/ui/attTab.dart';
import 'package:attandance_client/ui/employeeTab.dart';
import 'package:attandance_client/ui/historyTab.dart';
import 'package:attandance_client/ui/overtimeTab.dart';
import 'package:attandance_client/ui/timesheetTab.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';

class Att extends StatefulWidget {
  const Att({super.key});

  @override
  State<Att> createState() => _AttState();
}

class _AttState extends State<Att> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  final GlobalKey<OvertimeTabState> _overtimeKey = GlobalKey();
  final GlobalKey<ShiftTabState> _shiftKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      _resetDupState();
      setState(() {
        _selectedIndex = _tabController.index;
      });
      print("Selected Index: " + _tabController.index.toString());
    });
    Future.delayed(const Duration(milliseconds: 200)).then((_) async {
      if (!mounted) return;

      // Show update dialog if new version available
      final pendingUpdate = App.gValue.pendingUpdate;
      if (pendingUpdate != null) {
        if (!mounted) return;
        final shouldUpdate = await showUpdateDialog(context, pendingUpdate);
        if (shouldUpdate) {
          await performUpdate();
          return;
        }
      }

      final overlay = context.loaderOverlay;
      overlay.show();

      final permission = await App.mongoDb.checkPermission(
        Platform.localHostname,
      );
      App.gValue.permission = permission;
      if (permission == 'deny') {
        if (!mounted) return;
        overlay.hide();
        setState(() {});
        return;
      }

      // 1. Load employees first → show UI immediately
      // ignore: use_build_context_synchronously
      await MyFunctions.loadData('employee', context);
      if (!mounted) return;
      overlay.hide();
      setState(() {});

      // 2. Load remaining data in background (no overlay blocking)
      unawaited(_loadRemainingData());
    });
  }

  // Load checkin → overtime → shift → history in background (no overlay)
  Future<void> _loadRemainingData() async {
    final steps = <(String, Future<void> Function())>[
      (
        'Checkin',
        () async {
          App.gValue.attLogs = await App.mongoDb.getAttLogs(
            App.gValue.dateRangeAtt,
          );
        },
      ),
      (
        'Overtime',
        () async {
          App.gValue.otRegisters = await App.mongoDb.getOvertime(
            App.gValue.dateRangeOvertime,
          );
        },
      ),
      (
        'Shift',
        () async {
          App.gValue.shiftRegisters = await App.mongoDb.getShiftRegisters(
            App.gValue.dateRangeShift,
          );
        },
      ),
      (
        'History',
        () async {
          App.gValue.histories = await App.mongoDb.getHistory(
            App.gValue.dateRangeHistory,
          );
        },
      ),
    ];
    for (final (label, fn) in steps) {
      if (!mounted) return;
      showToast('Loading $label...', backgroundColor: AppColors.textSecondary);
      await fn();
      if (!mounted) return;
      setState(() {});
    }
  }

  // State for 2-step duplicate removal
  List<int> _dupIdsToDelete = [];
  bool _isDupChecked = false;

  Future<void> _handleDuplicateButton() async {
    if (!_isDupChecked) {
      // Step 1: Check duplicates — filter and show on grid
      await _checkOtDuplicates();
    } else {
      // Step 2: Remove duplicates
      await _removeOtDuplicates();
    }
  }

  Future<void> _checkOtDuplicates() async {
    if (App.gValue.otRegisters.isEmpty) {
      showToast('No OT records to check');
      return;
    }

    final idsToDelete = _overtimeKey.currentState?.filterDuplicates() ?? [];

    if (idsToDelete.isEmpty) {
      showToast('No duplicates found');
      return;
    }

    setState(() {
      _dupIdsToDelete = idsToDelete;
      _isDupChecked = true;
    });
    showToast(
      'Found ${idsToDelete.length} duplicate(s). Review and press again to remove.',
    );
  }

  Future<void> _removeOtDuplicates() async {
    if (_dupIdsToDelete.isEmpty) return;

    final overlay = context.loaderOverlay;
    overlay.show();
    await App.mongoDb.deleteOtRegistersByIds(_dupIdsToDelete);
    final idSet = _dupIdsToDelete.toSet();
    App.gValue.otRegisters.removeWhere((e) => idSet.contains(e.id));
    if (!mounted) return;
    overlay.hide();

    final count = _dupIdsToDelete.length;
    setState(() {
      _dupIdsToDelete = [];
      _isDupChecked = false;
    });
    _overtimeKey.currentState?.refreshData();
    showToast('Removed $count duplicate OT record(s)');
  }

  void _resetDupState() {
    if (_isDupChecked) {
      setState(() {
        _dupIdsToDelete = [];
        _isDupChecked = false;
      });
      _overtimeKey.currentState?.refreshData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedIndex == 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FloatingActionButton(
                mini: true,
                heroTag: 'removeDupOT',
                backgroundColor: _isDupChecked
                    ? AppColors.danger
                    : AppColors.warning,
                onPressed: () => _handleDuplicateButton(),
                tooltip: _isDupChecked
                    ? 'Remove Duplicates'
                    : 'Check Duplicates',
                child: Icon(
                  _isDupChecked ? Icons.delete_sweep : Icons.find_replace,
                  size: 20,
                ),
              ),
            ),
          if (_selectedIndex == 2 || _selectedIndex == 3)
            FloatingActionButton(
              mini: true,
              heroTag: 'checkOverlap',
              backgroundColor: AppColors.warning,
              onPressed: () {
                if (_selectedIndex == 2) {
                  _overtimeKey.currentState?.filterOverlaps();
                } else {
                  _shiftKey.currentState?.filterOverlaps();
                }
              },
              tooltip: 'Check Overlap',
              child: const Icon(Icons.bug_report, size: 20),
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            heroTag: 'refresh',
            onPressed: () async {
              int tabIndex = _tabController.index;
              switch (tabIndex) {
                case 0:
                  MyFunctions.loadData('employee', context);
                  break;
                case 1:
                  MyFunctions.loadData('attLog', context);
                  break;
                case 2:
                  await MyFunctions.loadData('overtime', context);
                  _overtimeKey.currentState?.refreshData();
                  break;
                case 3:
                  await MyFunctions.loadData('shift', context);
                  _shiftKey.currentState?.refreshData();
                  break;
                case 5:
                  MyFunctions.loadData('history', context);
                  break;
                default:
              }
            },
            tooltip: 'Refresh',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController, // Link controller to TabBar
          padding: EdgeInsets.symmetric(horizontal: 10),
          indicatorWeight: 5,
          // indicatorColor: Colors.teal,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(
              icon: Icon(Icons.supervised_user_circle),
              text: 'Employee',
              key: Key('employeeTab'),
            ),
            Tab(
              icon: Icon(Icons.fingerprint_sharp),
              text: 'Checkin',
              key: Key('attTab'),
            ),
            Tab(
              icon: Icon(Icons.notes_sharp),
              text: 'Overtime',
              key: Key('overtimeTab'),
            ),
            Tab(
              icon: Icon(Icons.punch_clock),
              text: 'Shift',
              key: Key('shiftTab'),
            ),
            Tab(
              icon: Icon(Icons.calculate),
              text: 'Calculate Timesheet',
              key: Key('timesheetTab'),
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'History',
              key: Key('historyTab'),
            ),
          ],
        ),
        title: Text(
          'Version - ${App.gValue.packageInfo.version}',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ),
      body: App.gValue.permission == 'deny'
          ? _buildDenyScreen()
          : TabBarView(
              controller: _tabController,
              children: [
                EmployeeTab(),
                AttTab(),
                OvertimeTab(key: _overtimeKey),
                ShiftTab(key: _shiftKey),
                TimesheetTab(),
                HistoryTab(),
              ],
            ),
    );
  }

  Widget _buildDenyScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block, size: 80, color: AppColors.danger),
          const SizedBox(height: 16),
          const Text(
            'Bạn không có quyền truy cập ứng dụng này.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'PC: ${Platform.localHostname}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => exit(0),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Thoát'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
