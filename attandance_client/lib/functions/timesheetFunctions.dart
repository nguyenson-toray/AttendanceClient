import 'package:attandance_client/functions/myFunctions.dart';
import 'package:attandance_client/model/attLog.dart';
import 'package:attandance_client/model/employee.dart';
import 'package:attandance_client/model/otRegister.dart';
import 'package:attandance_client/model/shiftRegister.dart';
import 'package:attandance_client/model/timeSheetDate.dart';
import 'package:attandance_client/main.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:oktoast/oktoast.dart';

// ── Internal types ────────────────────────────────────────────────────────────

class _ShiftParam {
  final int beginHour, beginMin, endHour, endMin, restHour;
  const _ShiftParam(
    this.beginHour,
    this.beginMin,
    this.endHour,
    this.endMin,
    this.restHour,
  );
}

class _OtResult {
  final double otActual, otApproved, otFinal;
  const _OtResult(this.otActual, this.otApproved, this.otFinal);
}

// ── Public result wrapper ─────────────────────────────────────────────────────

class TimesheetResult {
  final List<TimeSheetDate> data;
  final List<String> anomalies;
  const TimesheetResult(this.data, this.anomalies);
}

// ── TimesheetFunctions ────────────────────────────────────────────────────────

class TimesheetFunctions {
  // ── Shift defaults (fallback when DB has no records) ─────────────────────
  static const _defaultShiftParams = <String, _ShiftParam>{
    'Day': _ShiftParam(8, 0, 17, 0, 1),
    'Shift 1': _ShiftParam(6, 0, 14, 0, 0),
    'Shift 2': _ShiftParam(14, 0, 22, 0, 0),
    'Canteen': _ShiftParam(7, 0, 16, 0, 1),
  };

  /// Find shift param from DB for a given shift name and date.
  /// Falls back to hardcoded defaults if no matching DB record.
  static _ShiftParam _getShiftParam(String shiftName, DateTime date) {
    final match = App.gValue.shiftParams.where((s) =>
        s.name == shiftName &&
        !date.isBefore(s.effectiveFrom) &&
        !date.isAfter(s.effectiveTo));
    if (match.isNotEmpty) {
      final s = match.first;
      return _ShiftParam(s.beginHour, s.beginMin, s.endHour, s.endMin, s.restHour);
    }
    return _defaultShiftParams[shiftName] ?? _defaultShiftParams['Day']!;
  }

  /// Floor OT hours to nearest block.
  /// Returns 0 if total minutes < minOtMinute.
  static double _floorToBlock(double hours) {
    final minOtMin = App.gValue.timesheetSettings.minOtMinute;
    final otBlock = App.gValue.timesheetSettings.otBlockMinute;
    final totalMin = (hours * 60).floor();
    if (totalMin < minOtMin) return 0;
    final blockedMin = (totalMin ~/ otBlock) * otBlock;
    return blockedMin / 60;
  }

  /// Floor working hours to nearest working block.
  static double _floorWorkingToBlock(double hours) {
    final workBlock = App.gValue.timesheetSettings.workingBlockMinute;
    if (workBlock <= 1) return hours;
    final totalMin = (hours * 60).floor();
    final blockedMin = (totalMin ~/ workBlock) * workBlock;
    return blockedMin / 60;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Treat the sentinel value 2099-12-31 (DB default = "not set") as null.
  static DateTime? _matDate(DateTime? d) =>
      (d == null || d.year >= 2099) ? null : d.toBeginDay();

  static String _note(String existing, String addition) {
    if (addition.isEmpty) return existing;
    return existing.isEmpty ? addition : '$existing ; $addition';
  }

  static DateTime? _parseShiftTime(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime.utc(date.year, date.month, date.day, h, m);
  }

  // ── Main entry point ─────────────────────────────────────────────────────────

  /// Compute [TimeSheetDate] records for every (employee × date) in [dateRange].
  static TimesheetResult createTimesheets({
    required List<Employee> employees,
    required List<AttLog> attLogs,
    required List<ShiftRegister> shiftRegisters,
    required List<OtRegister> otRegisters,
    required List<DateTime> dateRange,
  }) {
    final result = <TimeSheetDate>[];
    final anomalies = <String>[];
    if (employees.isEmpty || attLogs.isEmpty)
      return TimesheetResult(result, anomalies);

    // ── Pre-index data for O(1) lookups ────────────────────────────────────
    // AttLogs → Map<dayKey, Map<empId, List<AttLog>>>
    final logIndex = <String, Map<String, List<AttLog>>>{};
    final datesWithLogs = <String>{};
    for (final l in attLogs) {
      final dk = _dayKey(l.timestamp);
      datesWithLogs.add(dk);
      (logIndex[dk] ??= {}).putIfAbsent(l.empId, () => []).add(l);
    }
    // remove employees have workStatus = 'reSigned' and resignOn.year = 2099
    employees.removeWhere(
      (e) =>
          (e.workStatus ?? '').contains('Resigned') &&
          (e.resignOn == null || e.resignOn!.year >= 2099),
    );
    // remove excluded employee IDs from settings
    final excludeIds = App.gValue.timesheetSettings.excludeEmpIds;
    if (excludeIds.isNotEmpty) {
      employees.removeWhere((e) => excludeIds.contains(e.empId));
    }

    // ShiftRegisters → Map<dayKey, Map<shiftName, Set<empId>>>
    final shiftIndex = <String, Map<String, Set<String>>>{};
    for (final sr in shiftRegisters) {
      for (
        var d = sr.fromDate.toBeginDay();
        !d.isAfter(sr.toDate.toBeginDay());
        d = d.add(const Duration(days: 1))
      ) {
        final dk = _dayKey(d);
        (shiftIndex[dk] ??= {}).putIfAbsent(sr.shift, () => {}).add(sr.empId);
      }
    }

    // OtRegisters → Map<dayKey, Map<empId, List<OtRegister>>>
    final otIndex = <String, Map<String, List<OtRegister>>>{};
    for (final o in otRegisters) {
      final dk = _dayKey(o.otDate);
      (otIndex[dk] ??= {}).putIfAbsent(o.empId, () => []).add(o);
    }

    // Enumerate every date in [dateRange[0], dateRange[1]]
    final dates = <DateTime>[];
    for (
      var d = dateRange[0].toBeginDay();
      !d.isAfter(dateRange[1].toBeginDay());
      d = d.add(const Duration(days: 1))
    ) {
      dates.add(d);
    }

    for (final date in dates) {
      final dk = _dayKey(date);
      final dayLogMap = logIndex[dk];
      if (dayLogMap == null || dayLogMap.isEmpty) continue;

      // Shift assignments for this date (O(1) lookup)
      final shiftDay = shiftIndex[dk];
      final shift1Ids = shiftDay?['Shift 1'] ?? const {};
      final shift2Ids = shiftDay?['Shift 2'] ?? const {};

      // OT records for this date (O(1) lookup)
      final otByEmp = otIndex[dk] ?? const <String, List<OtRegister>>{};
      final empIdOT = otByEmp.keys.toSet();

      for (final emp in employees) {
        // Guard: date before joining date
        if (emp.joiningDate != null &&
            date.isBefore(emp.joiningDate!.toBeginDay()))
          continue;

        final empLogs = dayLogMap[emp.empId] ?? [];

        // Guard: resigned and absent → skip
        if (empLogs.isEmpty &&
            (emp.workStatus ?? '').contains('Resigned') &&
            emp.resignOn != null &&
            !date.isBefore(emp.resignOn!.toBeginDay()))
          continue;

        // ── Determine shift ─────────────────────────────────────────────────
        String shift = 'Day';
        if ((emp.group ?? '') == 'Canteen') shift = 'Canteen';
        if (shift1Ids.contains(emp.empId)) shift = 'Shift 1';
        if (shift2Ids.contains(emp.empId)) shift = 'Shift 2';
        if (date.weekday == DateTime.sunday)
          shift = 'Day'; // Sunday always Day base

        final p = _getShiftParam(shift, date);
        var shiftBegin = DateTime.utc(
          date.year,
          date.month,
          date.day,
          p.beginHour,
          p.beginMin,
        );
        var shiftEnd = DateTime.utc(
          date.year,
          date.month,
          date.day,
          p.endHour,
          p.endMin,
        );

        // Sunday → override shift window from OT register if employee has one
        if (date.weekday == DateTime.sunday) {
          final sunOt = otByEmp[emp.empId] ?? [];
          if (sunOt.isNotEmpty) {
            shiftBegin =
                _parseShiftTime(date, sunOt.last.otTimeBegin) ?? shiftBegin;
            shiftEnd = _parseShiftTime(date, sunOt.last.otTimeEnd) ?? shiftEnd;
          }
        }

        // Rest window: fixed 4 h after shift start
        final restBegin = shiftBegin.add(const Duration(hours: 4));
        final restEnd = restBegin.add(Duration(hours: p.restHour));

        // ── Per-employee variables ──────────────────────────────────────────
        double normalHrs = 0, otActual = 0, otApproved = 0, otFinal = 0;
        String noteCheckin = '', noteSunday = '';
        DateTime? firstIn, lastOut;

        // Regime detection — date-based only.
        // The timesheet date determines which regime applies, not the current workStatus.
        // This ensures correctness regardless of current employment status (active/resigned).
        // Prerequisite: maternity date fields must be filled correctly in the DB.
        //   Pregnant regime  : maternityBegin ≤ date < maternityLeaveBegin
        //   Young child regime: maternityLeaveEnd ≤ date ≤ maternityEnd
        bool isYoungChild = false;
        final mBegin = _matDate(emp.maternityBegin);
        final mLeaveBegin = _matDate(emp.maternityLeaveBegin);
        final mLeaveEnd = _matDate(emp.maternityLeaveEnd);
        final mEnd = _matDate(emp.maternityEnd);

        // Pregnant: mBegin ≤ date < (mLeaveBegin ?? mEnd)
        // If maternityLeaveBegin is not set, the employee is still working while
        // pregnant → use maternityEnd as the upper bound.
        final pregnantUpperBound = mLeaveBegin ?? mEnd;
        if (mBegin != null &&
            pregnantUpperBound != null &&
            !date.isBefore(mBegin) &&
            date.isBefore(pregnantUpperBound)) {
          isYoungChild = true;
          noteCheckin = 'Chế độ mang thai';
        } else if (mLeaveEnd != null &&
            mEnd != null &&
            !date.isBefore(mLeaveEnd) &&
            !date.isAfter(mEnd)) {
          isYoungChild = true;
          noteCheckin = 'Chế độ con nhỏ';
        }

        if (isYoungChild) {
          shiftEnd = shiftEnd.subtract(const Duration(hours: 1));
        }

        if (empLogs.isEmpty) {
          // absent — zeros
        } else if (empLogs.length == 1) {
          firstIn = empLogs.first.timestamp;
          noteCheckin = 'Chỉ có 1 lần chấm công';
        } else {
          var fi = empLogs.first.timestamp;
          var lo = fi;
          for (int i = 1; i < empLogs.length; i++) {
            final t = empLogs[i].timestamp;
            if (t.isBefore(fi)) fi = t;
            if (t.isAfter(lo)) lo = t;
          }
          firstIn = fi;
          lastOut = lo;

          if (lo.compareTo(shiftBegin) <= 0) {
            noteCheckin = 'Không chấm công RA';
          } else if (fi.compareTo(shiftEnd) >= 0) {
            noteCheckin = 'Không chấm công VÀO';
          } else if (fi != lo) {
            // ── Normal hours ──────────────────────────────────────────────
            double morning = 0, afternoon = 0;
            if (!fi.isAfter(restBegin)) {
              morning = _normalMorning(fi, lo, shiftBegin, restBegin);
            }
            if (isYoungChild) {
              // shiftEnd already reduced by 1h (= reducedShiftEnd)
              // Credit: 4h if arrived at reducedShiftEnd; else 4 - earlyBy
              afternoon = _youngChildAfternoon(lo, restEnd, shiftEnd);
            } else {
              if (!lo.isBefore(restEnd)) {
                afternoon = _normalAfternoon(fi, lo, shiftEnd, restEnd);
              }
            }
            normalHrs = _floorWorkingToBlock(
              (morning + afternoon).clamp(0, double.infinity),
            );

            // ── OT ─────────────────────────────────────────────────────
            bool otRestHour = false;

            // Base OT = time after shiftEnd (before consulting OT register)
            otActual = _floorToBlock(
              (lo.difference(shiftEnd).inMinutes / 60.0).clamp(
                0.0,
                double.infinity,
              ),
            );

            if (empIdOT.contains(emp.empId)) {
              // Deduplicate OT records for this employee
              var otRecs = (otByEmp[emp.empId] ?? []).toList();
              if (otRecs.length > 1) {
                final uniq = <String, OtRegister>{};
                for (final o in otRecs) {
                  if (!uniq.containsKey(o.uniqueKeyWithoutId) ||
                      o.id > uniq[o.uniqueKeyWithoutId]!.id) {
                    uniq[o.uniqueKeyWithoutId] = o;
                  }
                }
                otRecs = uniq.values.toList();
              }

              // Check OT record that covers rest hour — filter it out
              if (p.restHour > 0) {
                int restIdx = -1;
                for (int i = 0; i < otRecs.length; i++) {
                  final ob =
                      int.tryParse(otRecs[i].otTimeBegin.split(':')[0]) ?? 0;
                  final oe =
                      int.tryParse(otRecs[i].otTimeEnd.split(':')[0]) ?? 0;
                  if (ob <= restBegin.hour && oe >= restEnd.hour) {
                    otRestHour = true;
                    restIdx = i;
                    break;
                  }
                }
                if (restIdx >= 0) {
                  otRecs = [
                    for (int i = 0; i < otRecs.length; i++)
                      if (i != restIdx) otRecs[i],
                  ];
                }
              }

              // Calculate OT with before/after separation
              if (otRecs.isNotEmpty) {
                final otRes = _calcOtRecords(
                  date,
                  otRecs,
                  fi,
                  lo,
                  shiftBegin,
                  shiftEnd,
                  otActual,
                );
                otActual = otRes.otActual;
                otApproved = otRes.otApproved;
                otFinal = otRes.otFinal;
              }

              if (otRestHour &&
                  App.gValue.timesheetSettings.allowOtInRestTime) {
                otActual += p.restHour;
                otApproved += p.restHour;
                noteCheckin = _note(noteCheckin, 'OT giờ nghỉ trưa');
              }
            }

            otFinal = otActual.clamp(0.0, otApproved);

            // Late / early leave notes
            if (fi.isAfter(shiftBegin))
              noteCheckin = _note(noteCheckin, 'Vào trễ');
            if (lo.isBefore(shiftEnd))
              noteCheckin = _note(noteCheckin, 'Ra sớm');
          }
        }

        // ── Anomaly detection ─────────────────────────────────────────────
        if (empLogs.isNotEmpty && firstIn != null && lastOut != null) {
          final datStr = DateFormat('yyyy-MM-dd').format(date);
          final empTag = '${emp.empId} ${emp.name}';

          // 1. Has resignOn date and attendance on/after that date
          if (emp.resignOn != null &&
              emp.resignOn!.year < 2099 &&
              !date.isBefore(emp.resignOn!.toBeginDay())) {
            anomalies.add(
              '[Resigned + Att] $datStr $empTag — resigned on '
              '${DateFormat('yyyy-MM-dd').format(emp.resignOn!)}'
              ', has ${empLogs.length} log(s)',
            );
          }

          // 2. Day-shift employee leaves 16:xx without a regime — likely missing
          //    maternity/young-child dates in DB.
          if (shift == 'Day' &&
              (emp.workStatus ?? '') == 'Working' &&
              !isYoungChild &&
              date.weekday != DateTime.sunday &&
              lastOut.hour == 16) {
            anomalies.add(
              '[Ra 16-17h] $datStr $empTag — last out ${DateFormat('HH:mm').format(lastOut)}'
              ' (shift: $shift)',
            );
          }

          // 3. Came in ≥1h early but no OT register covering before-shift
          if (shiftBegin.difference(firstIn).inMinutes >= 60) {
            bool hasBefore =
                empIdOT.contains(emp.empId) &&
                (otByEmp[emp.empId] ?? []).any((r) {
                  final eh = int.tryParse(r.otTimeEnd.split(':')[0]) ?? 0;
                  return eh <= shiftBegin.hour;
                });
            if (!hasBefore) {
              noteCheckin = _note(
                noteCheckin,
                'Vào sớm ≥1h, không có ĐK OT trước ca',
              );
            }
          }

          // 4. Left ≥1h late but no OT register covering after-shift
          if (lastOut.difference(shiftEnd).inMinutes >= 60) {
            bool hasAfter =
                empIdOT.contains(emp.empId) &&
                (otByEmp[emp.empId] ?? []).any((r) {
                  final bh = int.tryParse(r.otTimeBegin.split(':')[0]) ?? 0;
                  return bh >= shiftEnd.hour;
                });
            if (!hasAfter) {
              noteCheckin = _note(
                noteCheckin,
                'Ra trễ ≥1h, không có ĐK OT sau ca',
              );
            }
          }
        }

        // ── Sunday: all worked hours become OT ────────────────────────────
        if (date.weekday == DateTime.sunday) {
          if (otApproved > 0) {
            otApproved = shiftEnd.difference(shiftBegin).inMinutes / 60;
            if (shiftBegin.hour < 12 && shiftEnd.hour > 13) otApproved -= 1;
          }
          otActual = normalHrs;
          normalHrs = 0;
          otFinal = otActual.clamp(0.0, otApproved);
          if (otActual > 0) {
            noteSunday = 'OT ngày CN';
            if (otActual > 4 &&
                firstIn != null &&
                lastOut != null &&
                lastOut.isAfter(restEnd) &&
                firstIn.isBefore(restBegin)) {
              noteSunday = _note(noteSunday, 'Có phụ cấp cơm trưa');
            }
          }
        }

        result.add(
          TimeSheetDate(
            date: date,
            empId: emp.empId ?? '',
            attFingerId: emp.attFingerId ?? 0,
            name: emp.name ?? '',
            department: emp.department ?? '',
            section: emp.section ?? '',
            group: emp.group ?? '',
            shift: shift,
            firstIn: firstIn,
            lastOut: lastOut,
            normalHours: normalHrs,
            otHours: otActual,
            otHoursApproved: otApproved,
            otHoursFinal: otFinal,
            attNote2: noteCheckin,
            attNote3: noteSunday,
          ),
        );
      }
    }

    return TimesheetResult(result, anomalies);
  }

  // ── Normal hours helpers ─────────────────────────────────────────────────────
  //
  //  Morning  = clipped work between [shiftBegin, restBegin]
  //  Afternoon= clipped work between [restEnd,    shiftEnd]
  //  When restHour == 0, restEnd == restBegin → the two halves are seamless.

  static double _normalMorning(
    DateTime fi,
    DateTime lo,
    DateTime shiftBegin,
    DateTime restBegin,
  ) {
    final start = fi.isBefore(shiftBegin) ? shiftBegin : fi;
    final end = lo.isBefore(restBegin) ? lo : restBegin;
    return (end.difference(start).inMinutes / 60).clamp(0, double.infinity);
  }

  static double _normalAfternoon(
    DateTime fi,
    DateTime lo,
    DateTime shiftEnd,
    DateTime restEnd,
  ) {
    final start = fi.isAfter(restEnd) ? fi : restEnd;
    final end = lo.isAfter(shiftEnd) ? shiftEnd : lo;
    return (end.difference(start).inMinutes / 60).clamp(0, double.infinity);
  }

  /// Afternoon hours for "young child / pregnant" employees.
  ///
  /// [shiftEnd] is already the **reduced** end (original − 1h).
  /// Rules:
  ///   • lo < restEnd              → 0 h  (didn't work the afternoon)
  ///   • lo ≥ reducedShiftEnd      → 4 h  (full afternoon credit)
  ///   • restEnd ≤ lo < shiftEnd   → 4 − earlyBy  where earlyBy = (shiftEnd − lo) in h
  ///   floor at 0; cap at 4.
  static double _youngChildAfternoon(
    DateTime lo,
    DateTime restEnd,
    DateTime reducedShiftEnd,
  ) {
    if (lo.isBefore(restEnd)) return 0;
    if (!lo.isBefore(reducedShiftEnd)) return 4; // on time or later
    // Left before the reduced end → partial credit
    final earlyBy = reducedShiftEnd.difference(lo).inMinutes / 60;
    return (4 - earlyBy).clamp(0, 4);
  }

  // ── OT calculation: process all records, split before/after shift ────────────

  /// Calculate OT from a list of OT records, separating before-shift and
  /// after-shift independently. Each part applies _floorToBlock and _minOtMin.
  /// Sunday full-day records are handled as a special case.
  static _OtResult _calcOtRecords(
    DateTime date,
    List<OtRegister> recs,
    DateTime fi,
    DateTime lo,
    DateTime shiftBegin,
    DateTime shiftEnd,
    double baseOtActual,
  ) {
    double totalActual = 0, totalApproved = 0, totalFinal = 0;
    // Classify records into before/after/sunday-full
    final beforeRecs = <OtRegister>[];
    final afterRecs = <OtRegister>[];
    OtRegister? sundayFullRec;

    for (final rec in recs) {
      final beginOT = _parseShiftTime(date, rec.otTimeBegin);
      final endOT = _parseShiftTime(date, rec.otTimeEnd);
      if (beginOT == null || endOT == null) continue;

      final bh = beginOT.hour, eh = endOT.hour;

      // Sunday full-day spanning noon
      if (date.weekday == DateTime.sunday && bh < 12 && eh > 13) {
        sundayFullRec = rec;
      }
      // Before shift: ends at or before shift start
      else if (eh <= shiftBegin.hour) {
        beforeRecs.add(rec);
      }
      // After shift: starts at or after shift end
      else if (bh >= shiftEnd.hour) {
        afterRecs.add(rec);
      }
    }

    // ── Sunday full-day ──
    if (sundayFullRec != null) {
      final beginOT = _parseShiftTime(date, sundayFullRec.otTimeBegin)!;
      final endOT = _parseShiftTime(date, sundayFullRec.otTimeEnd)!;
      double otApproved =
          endOT.difference(beginOT).inMinutes / 60.0 - 1; // deduct lunch
      double otActual = baseOtActual;
      if (fi.isBefore(shiftBegin) && fi.hour <= shiftBegin.hour) {
        otActual = (shiftBegin.difference(fi).inMinutes / 60.0).clamp(
          0.0,
          double.infinity,
        );
      }
      final double otFinal = otActual.clamp(0.0, otApproved);
      return _OtResult(otActual, otApproved, otFinal);
    }

    // ── Before shift ──
    if (beforeRecs.isNotEmpty) {
      // Use earliest begin and latest end across all before records
      DateTime? earliestBegin, latestEnd;
      for (final rec in beforeRecs) {
        final b = _parseShiftTime(date, rec.otTimeBegin);
        final e = _parseShiftTime(date, rec.otTimeEnd);
        if (b == null || e == null) continue;
        if (earliestBegin == null || b.isBefore(earliestBegin))
          earliestBegin = b;
        if (latestEnd == null || e.isAfter(latestEnd)) latestEnd = e;
      }
      if (earliestBegin != null && latestEnd != null) {
        final double otApproved =
            latestEnd.difference(earliestBegin).inMinutes / 60;
        // Actual = time employee arrived early, capped to approved window
        final earliestStart = shiftBegin.subtract(
          Duration(minutes: (otApproved * 60).toInt()),
        );
        double rawActual = fi.isBefore(earliestStart)
            ? otApproved
            : (shiftBegin.difference(fi).inMinutes / 60.0).clamp(
                0.0,
                double.infinity,
              );
        final otActual = _floorToBlock(rawActual);
        final double otFinal = otActual.clamp(0.0, otApproved);

        totalActual += otActual;
        totalApproved += otApproved;
        totalFinal += otFinal;
      }
    }

    // ── After shift ──
    if (afterRecs.isNotEmpty) {
      // Use earliest begin and latest end across all after records
      DateTime? earliestBegin, latestEnd;
      for (final rec in afterRecs) {
        final b = _parseShiftTime(date, rec.otTimeBegin);
        final e = _parseShiftTime(date, rec.otTimeEnd);
        if (b == null || e == null) continue;
        if (earliestBegin == null || b.isBefore(earliestBegin))
          earliestBegin = b;
        if (latestEnd == null || e.isAfter(latestEnd)) latestEnd = e;
      }
      if (earliestBegin != null && latestEnd != null) {
        final double otApproved =
            latestEnd.difference(earliestBegin).inMinutes / 60;
        // Actual = time employee stayed after shift end, capped to endOT
        double rawActual = 0;
        if (lo.isAfter(shiftEnd)) {
          final effectiveEnd = lo.isBefore(latestEnd) ? lo : latestEnd;
          rawActual = (effectiveEnd.difference(shiftEnd).inMinutes / 60.0)
              .clamp(0.0, double.infinity);
        }
        final otActual = _floorToBlock(rawActual);
        final double otFinal = otActual.clamp(0.0, otApproved);

        totalActual += otActual;
        totalApproved += otApproved;
        totalFinal += otFinal;
      }
    }

    // If no classified records matched, fall back to base OT (no register match)
    if (beforeRecs.isEmpty && afterRecs.isEmpty && sundayFullRec == null) {
      return _OtResult(_floorToBlock(baseOtActual), 0, 0);
    }

    return _OtResult(totalActual, totalApproved, totalFinal);
  }

  // ── Excel helpers ─────────────────────────────────────────────────────────────

  /// Round to 2 decimal places only at write time — never during calculation.
  static DoubleCellValue _d(double v) =>
      DoubleCellValue(double.parse(v.toStringAsFixed(2)));

  // ── Excel export ─────────────────────────────────────────────────────────────

  static Future<void> exportTimesheets(
    TimesheetResult tsResult, {
    required List<Employee> employees,
  }) async {
    final data = tsResult.data;
    final anomalies = tsResult.anomalies;
    if (data.isEmpty) {
      showToast('No timesheet data to export');
      return;
    }
    try {
      final excel = Excel.createExcel();
      // ── Sheet 0: Important Note ──────────────────────────────────────────────
      final noteSheet = excel['Important Note'];
      noteSheet.appendRow([
        TextCellValue(
          'Important Note — generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        ),
      ]);
      noteSheet.appendRow([TextCellValue('')]);
      noteSheet.appendRow([TextCellValue('Type'), TextCellValue('Detail')]);
      if (anomalies.isEmpty) {
        noteSheet.appendRow([
          TextCellValue(''),
          TextCellValue('No anomalies detected.'),
        ]);
      } else {
        for (final a in anomalies) {
          // Split "[$type] $rest" into two cells for readability
          final typeEnd = a.indexOf(']');
          final type = typeEnd > 0 ? a.substring(0, typeEnd + 1) : '';
          final detail = typeEnd > 0 ? a.substring(typeEnd + 2) : a;
          noteSheet.appendRow([TextCellValue(type), TextCellValue(detail)]);
        }
      }

      // ── Sheet 1: Detail ─────────────────────────────────────────────────────
      final detail = excel['Detail'];
      detail.appendRow(
        [
          'Date',
          'Emp ID',
          'Name',
          'Department',
          'Section',
          'Group',
          'Shift',
          'First In',
          'Last Out',
          'Normal Hrs',
          'Working Day',
          'OT Actual',
          'OT Approved',
          'OT Final',
          'Note Checkin',
          'Note Sunday',
        ].map((h) => TextCellValue(h)).toList(),
      );

      for (final ts in data) {
        detail.appendRow([
          DateCellValue(
            year: ts.date.year,
            month: ts.date.month,
            day: ts.date.day,
          ),
          TextCellValue(ts.empId),
          TextCellValue(ts.name),
          TextCellValue(ts.department),
          TextCellValue(ts.section),
          TextCellValue(ts.group),
          TextCellValue(ts.shift),
          ts.firstIn != null
              ? TimeCellValue(
                  hour: ts.firstIn!.hour,
                  minute: ts.firstIn!.minute,
                )
              : TextCellValue(''),
          ts.lastOut != null
              ? TimeCellValue(
                  hour: ts.lastOut!.hour,
                  minute: ts.lastOut!.minute,
                )
              : TextCellValue(''),
          _d(ts.normalHours),
          _d(ts.normalHours / 8),
          _d(ts.otHours),
          _d(ts.otHoursApproved),
          _d(ts.otHoursFinal),
          TextCellValue(ts.attNote2),
          TextCellValue(ts.attNote3),
        ]);
      }

      // ── Sheet 2: Summary ────────────────────────────────────────────────────
      // Group by empId, preserving the first-seen order
      final empOrder = <String>[];
      final totals = <String, _EmpSummary>{};
      for (final ts in data) {
        if (!totals.containsKey(ts.empId)) {
          empOrder.add(ts.empId);
          totals[ts.empId] = _EmpSummary(
            empId: ts.empId,
            name: ts.name,
            department: ts.department,
            section: ts.section,
            group: ts.group,
          );
        }
        final s = totals[ts.empId]!;
        s.totalNormalHours += ts.normalHours;
        s.totalWorkingDays += ts.normalHours / 8;
        s.totalOtActual += ts.otHours;
        s.totalOtApproved += ts.otHoursApproved;
        s.totalOtFinal += ts.otHoursFinal;
      }

      // Build employee lookup for joining/resign dates
      final empLookup = <String, Employee>{
        for (final e in employees)
          if (e.empId != null) e.empId!: e,
      };

      final summary = excel['Summary'];
      summary.appendRow(
        [
          'No',
          'Employee ID',
          'Full Name',
          'Department',
          'Section',
          'Group',
          'Total Working (hrs)',
          'Total Working (days)',
          'Total OT Actual (hrs)',
          'Total OT Approved (hrs)',
          'Total OT Final (hrs)',
          'Joining Date',
          'Resign Date',
        ].map((h) => TextCellValue(h)).toList(),
      );

      int no = 1;
      for (final empId in empOrder) {
        final s = totals[empId]!;
        final emp = empLookup[empId];
        final joiningDate =
            emp?.joiningDate != null && emp!.joiningDate!.year > 1900
            ? emp.joiningDate!
            : null;
        final resignDate =
            emp?.resignOn != null &&
                emp!.resignOn!.year < 2099 &&
                (emp.workStatus ?? '').contains('Resigned')
            ? emp.resignOn!
            : null;

        summary.appendRow([
          IntCellValue(no++),
          TextCellValue(s.empId),
          TextCellValue(s.name),
          TextCellValue(s.department),
          TextCellValue(s.section),
          TextCellValue(s.group),
          _d(s.totalNormalHours),
          _d(s.totalWorkingDays),
          _d(s.totalOtActual),
          _d(s.totalOtApproved),
          _d(s.totalOtFinal),
          joiningDate != null
              ? DateCellValue(
                  year: joiningDate.year,
                  month: joiningDate.month,
                  day: joiningDate.day,
                )
              : TextCellValue(''),
          resignDate != null
              ? DateCellValue(
                  year: resignDate.year,
                  month: resignDate.month,
                  day: resignDate.day,
                )
              : TextCellValue(''),
        ]);
      }

      // Remove default empty sheet created by Excel.createExcel()
      excel.delete('Sheet1');

      await MyFunctions.saveAndOpenExcel(
        excel,
        MyFunctions.exportFileName('Timesheet'),
      );
    } catch (e) {
      showToast('Export error: $e');
    }
  }
}

// ── Helper for summary aggregation ───────────────────────────────────────────

class _EmpSummary {
  final String empId, name, department, section, group;
  double totalNormalHours = 0;
  double totalWorkingDays = 0;
  double totalOtActual = 0;
  double totalOtApproved = 0;
  double totalOtFinal = 0;

  _EmpSummary({
    required this.empId,
    required this.name,
    required this.department,
    required this.section,
    required this.group,
  });
}
