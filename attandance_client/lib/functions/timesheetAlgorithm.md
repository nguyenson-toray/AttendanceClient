# Timesheet Algorithm — `timesheetFunctions.dart`

> Tài liệu này mô tả toàn bộ thuật toán tính timesheet theo code hiện tại.  
> Cập nhật: 2026-06-02

---

## 1. Tổng quan

Hàm chính: `TimesheetFunctions.createTimesheets()`

**Đầu vào:**
| Tham số | Kiểu | Mô tả |
|---|---|---|
| `employees` | `List<Employee>` | Danh sách nhân viên |
| `attLogs` | `List<AttLog>` | Bản ghi chấm công |
| `shiftRegisters` | `List<ShiftRegister>` | Đăng ký ca làm việc |
| `otRegisters` | `List<OtRegister>` | Đăng ký OT |
| `dateRange` | `List<DateTime>` | `[fromDate, toDate]` |

**Đầu ra:** `TimesheetResult`
- `data`: `List<TimeSheetDate>` — một record cho mỗi cặp (nhân viên × ngày)
- `anomalies`: `List<String>` — danh sách cảnh báo bất thường

**Model `TimeSheetDate`:**
| Field | Kiểu | Mô tả |
|---|---|---|
| `date` | `DateTime` | Ngày |
| `empId` | `String` | Mã nhân viên |
| `name` | `String` | Tên |
| `department`, `section`, `group` | `String` | Phân bổ tổ chức |
| `shift` | `String` | Ca làm việc |
| `firstIn`, `lastOut` | `DateTime?` | Giờ vào / ra |
| `normalHours` | `double` | Giờ làm bình thường |
| `otHours` | `double` | OT thực tế |
| `otHoursApproved` | `double` | OT được duyệt |
| `otHoursFinal` | `double` | OT cuối = min(otActual, otApproved) |
| `attNote1` | `String` | Ghi chú chấm công / sự kiện |
| `attNote2` | `String` | Trạng thái nhân viên đặc biệt |
| `attNote3` | `String` | Cảnh báo nhẹ (vào sớm / ra trễ không có OT) |

---

## 2. Hằng số ca làm việc

| Ca | Bắt đầu | Kết thúc | restHour | Nghỉ (restBegin → restEnd) |
|---|---|---|---|---|
| `Day` | 08:00 | 17:00 | 1 | 12:00 → 13:00 |
| `Canteen` | 07:00 | 16:00 | 1 | 11:00 → 12:00 |
| `Shift 1` | 06:00 | 14:00 | 0 | 10:00 → 10:00 (không nghỉ) |
| `Shift 2` | 14:00 | 22:00 | 0 | 18:00 → 18:00 (không nghỉ) |

> `restBegin = shiftBegin + 4h` ; `restEnd = restBegin + restHour`

---

## 2b. Cài đặt Timesheet (Setting Tab → `GValue`)

Các tham số cấu hình trong tab **Setting**, lưu trên `App.gValue` (in-memory, reset khi khởi động lại app):

| Setting | Field | Default | Mô tả |
|---|---|---|---|
| **Min OT Minute** | `minOtMinute` | 30 | Ngưỡng tối thiểu (phút) để tính OT. Nếu OT thực tế < giá trị này → 0 |
| **OT Block Minute** | `otBlockMinute` | 30 | Block làm tròn OT (phút). OT actual được floor xuống block gần nhất. VD: 45' → 30', 89' → 60' |
| **Working Block Minute** | `workingBlockMinute` | 1 | Block làm tròn giờ làm bình thường (phút). Mặc định 1 = không làm tròn. VD: nếu set 15 → 47' → 45' |
| **Allow OT In Rest Time** | `allowOtInRestTime` | false | Cho phép tính OT giờ nghỉ trưa. Khi `false`: bỏ qua OT record bao trùm giờ nghỉ. Khi `true`: tính `restHour` vào otActual/otApproved |

**Sử dụng trong `timesheetFunctions.dart`:**

| Setting | Hàm / vị trí sử dụng |
|---|---|
| `minOtMinute` | `_floorToBlock()` — ngưỡng tối thiểu ; Note "OT trước/sau ca" — ngưỡng phát hiện |
| `otBlockMinute` | `_floorToBlock()` — block làm tròn |
| `workingBlockMinute` | `_floorWorkingToBlock()` — áp dụng cho `normalHrs = morning + afternoon` |
| `allowOtInRestTime` | Gate cho việc cộng `restHour` vào otActual/otApproved khi có OT record bao trùm giờ nghỉ |

**`_floorToBlock(hours)`:**
```
minOtMin = App.gValue.minOtMinute          ← cấu hình, default 30
otBlock  = App.gValue.otBlockMinute         ← cấu hình, default 30
totalMin = floor(hours × 60)
if totalMin < minOtMin → return 0
return floor(totalMin / otBlock) × otBlock / 60
```

**`_floorWorkingToBlock(hours)`:**
```
workBlock = App.gValue.workingBlockMinute   ← cấu hình, default 1
if workBlock <= 1 → return hours            ← không làm tròn
totalMin = floor(hours × 60)
return floor(totalMin / workBlock) × workBlock / 60
```

---

## 3. Pre-indexing & Vòng lặp chính

### 3.1 Pre-index dữ liệu (O(1) lookup)

Trước vòng lặp chính, dữ liệu được index thành Map để tránh linear scan lặp lại:

```
// AttLogs → Map<dayKey, Map<empId, List<AttLog>>>
logIndex = {}
for log in attLogs:
    dk = dayKey(log.timestamp)      // 'yyyy-MM-dd'
    logIndex[dk][log.empId].add(log)

// ShiftRegisters → Map<dayKey, Map<shiftName, Set<empId>>>
shiftIndex = {}
for sr in shiftRegisters:
    for d in [sr.fromDate .. sr.toDate]:
        dk = dayKey(d)
        shiftIndex[dk][sr.shift].add(sr.empId)

// OtRegisters → Map<dayKey, Map<empId, List<OtRegister>>>
otIndex = {}
for ot in otRegisters:
    dk = dayKey(ot.otDate)
    otIndex[dk][ot.empId].add(ot)
```

### 3.2 Vòng lặp chính

```
for date in [fromDate .. toDate]:
    dk          = dayKey(date)
    dayLogMap   = logIndex[dk]              // Map<empId, List<AttLog>> — O(1)
    shift1Ids   = shiftIndex[dk]['Shift 1'] // Set<empId> — O(1)
    shift2Ids   = shiftIndex[dk]['Shift 2'] // Set<empId> — O(1)
    otByEmp     = otIndex[dk]               // Map<empId, List<OtRegister>> — O(1)
    empIdOT     = otByEmp.keys              // Set<empId> — O(1)

    for employee in employees:
        empLogs = dayLogMap[employee.empId]  // List<AttLog> — O(1)
        bỏ qua nếu date < employee.joiningDate
        bỏ qua nếu Resigned + không có log ngày đó (vắng mặt)
        → tính record TimeSheetDate
```

### 3.3 Độ phức tạp

| | Trước tối ưu | Sau tối ưu |
|--|-------|-----|
| **Time** | O(D × A × E + D × S + D × O) | O(A + S_expand + O + D × E) |
| **Space** | O(A) mỗi ngày (copy) | O(A + S_expand + O) cho indexes |

> D = số ngày, A = số att logs, E = số nhân viên, S = số shift registers, O = số OT registers  
> S_expand = tổng số ngày trong tất cả shift registers (thường nhỏ)

---

## 4. Xác định ca làm việc

Thứ tự ưu tiên (sau cùng thắng):

1. Mặc định: `Day`
2. Nếu `employee.group == 'Canteen'` → `Canteen`
3. Nếu `empId` có trong `shift1Ids` → `Shift 1`
4. Nếu `empId` có trong `shift2Ids` → `Shift 2`
5. Nếu là **Chủ nhật** → luôn về `Day`

> Shift 1/2 ghi đè Canteen. Nhân viên nhóm Canteen nhưng được đăng ký Shift 1/2 sẽ được xếp vào ca đó.

**Chủ nhật — override giờ từ OT register:**  
Nếu nhân viên có OT register vào Chủ nhật, `shiftBegin` / `shiftEnd` được lấy từ `otTimeBegin` / `otTimeEnd` của record đó.

---

## 5. Nhân viên nuôi con nhỏ / mang thai

Chế độ được xác định **theo ngày làm việc** (không dùng `workStatus`) để đảm bảo đúng ngay cả khi nhân viên đã nghỉ việc.

| Giai đoạn | Điều kiện ngày | note2 |
|---|---|---|
| Mang thai (đi làm) | `maternityBegin ≤ date < (maternityLeaveBegin ?? maternityEnd)` | `Chế độ mang thai` |
| Đang nghỉ thai sản | `maternityLeaveBegin ≤ date < maternityLeaveEnd` | *(không áp dụng — không đi làm)* |
| Nuôi con nhỏ (đi làm lại) | `maternityLeaveEnd ≤ date ≤ maternityEnd` | `Chế độ con nhỏ` |

> Default của các field maternity là `2099-12-31` hoặc null → coi như "chưa set", không áp dụng chế độ.
>
> **Yêu cầu dữ liệu:**
> - Chế độ **mang thai**: bắt buộc `maternityBegin` + `maternityEnd`. Nếu chưa nghỉ thai sản (`maternityLeaveBegin` chưa có), dùng `maternityEnd` làm cận trên.
> - Chế độ **con nhỏ**: bắt buộc `maternityLeaveEnd` + `maternityEnd`.
>
> Hai chế độ độc lập — không bắt buộc điền đủ 4 field cùng lúc.

| Thay đổi khi `isYoungChild = true` | Giá trị |
|---|---|
| `shiftEnd` | Giảm 1 giờ so với ca gốc |
| Tính buổi chiều | Dùng công thức `_youngChildAfternoon` (xem mục 6.3) |

> Buổi sáng vẫn tính bình thường. Chỉ buổi chiều áp dụng quy tắc riêng.

---

## 6. Tính giờ làm bình thường (normalHours)

### 6.1 Cấu trúc thời gian ca

```
shiftBegin ──── restBegin ──── restEnd ──── shiftEnd
     |           (begin+4h)    (rest+Nh)       |
     |←─ Buổi sáng ──→|←── Nghỉ ──→|←─ Buổi chiều ──→|
```

### 6.2 Điều kiện tính

- Buổi sáng chỉ tính nếu `firstIn <= restBegin`
- Buổi chiều chỉ tính nếu `lastOut >= restEnd`

### 6.3 Công thức

**Buổi sáng:**
```
morning = clamp(min(lastOut, restBegin) − max(firstIn, shiftBegin), 0, ∞)
```

**Buổi chiều — nhân viên bình thường:**
```
afternoon = clamp(min(lastOut, shiftEnd) − max(firstIn, restEnd), 0, ∞)
```

**Buổi chiều — nuôi con nhỏ / mang thai** (`shiftEnd` đã giảm 1h = `reducedShiftEnd`):

| Điều kiện | Kết quả |
|---|---|
| `lastOut < restEnd` | 0 h |
| `lastOut >= reducedShiftEnd` | 4 h |
| `restEnd <= lastOut < reducedShiftEnd` | `4 − (reducedShiftEnd − lastOut)` h, tối thiểu 0 |

```
normalHours = _floorWorkingToBlock(morning + afternoon)
```

> Với `workingBlockMinute = 1` (default): không làm tròn, giữ nguyên giá trị gốc.

---

## 7. Tính OT

> OT tính **đồng nhất cho tất cả ca** (Day, Canteen, Shift 1, Shift 2).  
> OT được **tách riêng trước ca và sau ca**, tính independent, rồi sum lại.

### 7.1 Base OT (trước khi tra OT register)

```
baseOtActual = _floorToBlock(max(lastOut − shiftEnd, 0))
otApproved = 0
```

**`_floorToBlock(hours)`:** *(xem chi tiết tại mục 2b)*

VD (default 30/30): 45' → 30' (0.5h), 89' → 60' (1.0h), 25' → 0

### 7.2 Có đăng ký OT — tiền xử lý

1. **Deduplicate:** Giữ record có `id` lớn nhất theo `uniqueKeyWithoutId`.
2. **Tách OT nghỉ trưa:** Nếu có record thỏa `otTimeBegin.hour <= restBegin.hour` AND `otTimeEnd.hour >= restEnd.hour` AND `restHour > 0` → đánh dấu `otRestHour = true`, bỏ record này ra khỏi danh sách.
3. Xử lý các OT records còn lại qua `_calcOtRecords`.

### 7.3 Phân loại OT records — `_calcOtRecords`

Mỗi OT record được phân loại vào 1 trong 3 nhóm:

| Nhóm | Điều kiện | Mô tả |
|---|---|---|
| **Trước ca** | `endHour <= shiftBegin.hour` | VD: 06:00–08:00 cho ca Day |
| **Sau ca** | `beginHour >= shiftEnd.hour` | VD: 17:00–19:00 cho ca Day |
| **Chủ nhật full-day** | `bh < 12` AND `eh > 13` (chỉ Chủ nhật) | Span qua trưa |

### 7.4 Tính OT trước ca

```
earliestBegin = min(beginOT) của tất cả records trước ca
latestEnd     = max(endOT) của tất cả records trước ca
otApproved    = latestEnd − earliestBegin               [giờ]
earliestStart = shiftBegin − otApproved                 [thời điểm]
rawActual     = if firstIn < earliestStart → otApproved
                else → shiftBegin − firstIn             [giờ, ≥ 0]
otActual      = _floorToBlock(rawActual)
otFinal       = clamp(otActual, 0, otApproved)
```

### 7.5 Tính OT sau ca

```
earliestBegin = min(beginOT) của tất cả records sau ca
latestEnd     = max(endOT) của tất cả records sau ca
otApproved    = latestEnd − earliestBegin               [giờ]
effectiveEnd  = min(lastOut, latestEnd)
rawActual     = if lastOut > shiftEnd → effectiveEnd − shiftEnd   [giờ, ≥ 0]
                else → 0
otActual      = _floorToBlock(rawActual)
otFinal       = clamp(otActual, 0, otApproved)
```

### 7.6 Chủ nhật full-day

```
otApproved = (endOT − beginOT) − 1h                    [trừ giờ nghỉ trưa]
otActual   = shiftBegin − firstIn                       [nếu vào sớm]
otFinal    = clamp(otActual, 0, otApproved)
```

### 7.7 Tổng hợp

```
otActual   = otActual_before + otActual_after
otApproved = otApproved_before + otApproved_after
otFinal    = otFinal_before + otFinal_after
```

### 7.8 OT giờ nghỉ trưa

```
if otRestHour AND allowOtInRestTime:
    otActual   += restHour
    otApproved += restHour
    note1      += 'OT giờ nghỉ trưa'
```

> Khi `allowOtInRestTime = false` (default): OT record bao trùm giờ nghỉ trưa vẫn bị filter ra khỏi danh sách OT records (tránh double-count), nhưng **không cộng thêm** restHour vào otActual/otApproved.

### 7.9 OT Final (sau tất cả cộng thêm)

```
otFinal = clamp(otActual, 0, otApproved)
```

### 7.10 Note OT trước/sau ca (cảnh báo thiếu đăng ký)

Note chỉ xuất hiện khi có OT thực tế nhưng **không có** OT register cho khoảng thời gian đó:

```
if ngày != Chủ nhật:
    if firstIn < shiftBegin AND (shiftBegin − firstIn) >= minOtMinute:
        if không có OT record mà otTimeEnd.hour <= shiftBegin.hour:
            noteOT += 'OT trước ca'
    if lastOut > shiftEnd AND (lastOut − shiftEnd) >= minOtMinute:
        if không có OT record mà otTimeBegin.hour >= shiftEnd.hour:
            noteOT += 'OT sau ca'
```

---

## 8. Xử lý ngày Chủ nhật

Áp dụng **sau** khi tính normalHours và OT:

```
otActual    = normalHours          ← toàn bộ giờ làm chuyển thành OT
normalHours = 0
otApproved  = shiftEnd − shiftBegin   (chỉ nếu có đăng ký OT)
              − 1h nếu span qua bữa trưa (begin < 12:00 AND end > 13:00)
otFinal     = clamp(otActual, 0, otApproved)

note1 = 'OT ngày CN'
        + 'Có phụ cấp cơm trưa'  nếu otActual > 4h AND lastOut > restEnd AND firstIn < restBegin
```

---

## 9. Ghi chú tự động (Notes)

Nhiều ghi chú trong cùng 1 field ngăn cách bằng ` ; `.

### Note OT Reg (attNote1) — liên quan đăng ký OT

> Note "OT trước/sau ca" chỉ xuất hiện khi **có OT thực tế** nhưng **không có OT register** cho khoảng thời gian đó. Nếu OT đã được đăng ký đầy đủ → không note.

| Điều kiện | Nội dung |
|---|---|
| Vào trước ca ≥ `minOtMinute` phút AND không có OT register trước ca | `OT trước ca` |
| Ra sau ca ≥ `minOtMinute` phút AND không có OT register sau ca | `OT sau ca` |
| OT bao trùm giờ nghỉ trưa AND `allowOtInRestTime = true` | `OT giờ nghỉ trưa` |

> **Kiểm tra "có OT register trước ca":** có ít nhất 1 OT record mà `otTimeEnd.hour <= shiftBegin.hour`  
> **Kiểm tra "có OT register sau ca":** có ít nhất 1 OT record mà `otTimeBegin.hour >= shiftEnd.hour`  
> Không áp dụng cho ngày Chủ nhật.

### Note Checkin (attNote2) — liên quan chấm công & chế độ

| Điều kiện | Nội dung |
|---|---|
| Chỉ 1 lần chấm công | `Chỉ có 1 lần chấm công` |
| `lastOut ≤ shiftBegin` | `Không chấm công RA` | 
| `firstIn ≥ shiftEnd` | `Không chấm công VÀO` |
| `firstIn > shiftBegin` | `Vào trễ` |
| `lastOut < shiftEnd` | `Ra sớm` |
| Chế độ mang thai (date-based) | `Chế độ mang thai` |
| Chế độ con nhỏ (date-based) | `Chế độ con nhỏ` |
| `shiftBegin − firstIn ≥ 60'` AND không có OT register | `Vào sớm ≥1h, Không có đăng ký OT` |
| `lastOut − shiftEnd ≥ 60'` AND không có OT register | `Ra trễ ≥1h, Không có đăng ký OT` |

### Note Sunday (attNote3) — liên quan đi làm Chủ nhật

| Điều kiện | Nội dung |
|---|---|
| Chủ nhật có OT | `OT ngày CN` |
| Chủ nhật + span qua buổi trưa + otActual > 4h | `OT ngày CN ; Có phụ cấp cơm trưa` |

---

## 10. Phát hiện dị thường (Anomalies → sheet "Important Note")

| Loại | Điều kiện |
|---|---|
| `[Resigned + Att]` | workStatus chứa `'Resigned'` AND có log chấm công sau `resignOn` |
| `[Ra 16-17h]` | shift **==** `'Day'` AND workStatus **==** `'Working'` AND `isYoungChild == false` AND không phải Chủ nhật AND `lastOut.hour == 16` |

**Mục đích:** Phát hiện nhân viên ca Day về lúc 16:xx mà không thuộc chế độ mang thai/con nhỏ — khả năng cao là chế độ chưa được cập nhật đủ ngày tháng trong DB (`maternityBegin`/`maternityEnd`).  
Canteen tự loại trừ vì shift của họ là `'Canteen'` (≠ `'Day'`).

---

## 11. Cột Working Day

```
workingDay = normalHours / 8
```

- Hiển thị trong DataGrid (cột `W.Day`)
- Cột `Working Day` trong sheet **Detail**
- Tổng `Working Day` trong sheet **Summary** = `Σ(normalHours / 8)` của nhân viên

---

## 12. Làm tròn số

| Ngữ cảnh | Quy tắc |
|---|---|
| OT | `_floorToBlock()` — floor xuống `otBlockMinute`, bỏ qua nếu < `minOtMinute` |
| Giờ làm bình thường | `_floorWorkingToBlock()` — floor xuống `workingBlockMinute` (default 1 = không làm tròn) |
| Xuất Excel | Làm tròn 2 chữ số thập phân qua `_d(v)` = `DoubleCellValue(double.parse(v.toStringAsFixed(2)))` |

---

## 13. Xuất Excel

File: `Timesheets_yyyyMMdd_HHmm.xlsx`

| Sheet | Các cột chính |
|---|---|
| **Important Note** | Type, Detail — danh sách anomalies |
| **Detail** | Date, Emp ID, Name, Dept, Section, Group, Shift, First In, Last Out, Normal Hrs, **Working Day**, OT Actual, OT Approved, OT Final, **Note OT Reg**, **Note Checkin**, **Note Sunday** |
| **Summary** | No, Emp ID, Full Name, Dept, Section, Group, Total Working Hrs, **Total Working Day**, Total OT Actual, Total OT Approved, Total OT Final, Joining Date, Resign Date |

---

## 14. Sơ đồ quyết định tổng quát

```
── Settings (từ App.gValue) ────────────────────────────────────
minOtMinute      = 30   ← ngưỡng tối thiểu OT
otBlockMinute    = 30   ← block làm tròn OT
workingBlockMin  = 1    ← block làm tròn giờ làm
allowOtInRest    = false ← cho phép OT giờ nghỉ trưa

── Pre-index (1 lần, trước vòng lặp) ──────────────────────────
logIndex   = attLogs  → Map<dayKey, Map<empId, List<AttLog>>>
shiftIndex = shifts   → Map<dayKey, Map<shiftName, Set<empId>>>
otIndex    = otRegs   → Map<dayKey, Map<empId, List<OtRegister>>>

── Vòng lặp chính ─────────────────────────────────────────────
for (date, employee):
    empLogs = logIndex[dayKey][empId]    ← O(1) lookup
    otRecs  = otIndex[dayKey][empId]     ← O(1) lookup

    ┌─ 0 logs ────────────────────────────────→ record rỗng (zeros)
    │
    ├─ 1 log ────────────────────────────────→ note2 = 'Chỉ có 1 lần chấm công'
    │
    └─ ≥2 logs:
        fi, lo = single-pass min/max(timestamps)
        ┌─ lo ≤ shiftBegin ──────────────────→ note2 = 'Không chấm công RA'
        ├─ fi ≥ shiftEnd ────────────────────→ note2 = 'Không chấm công VÀO'
        └─ fi ≠ lo:
            normalHours = _floorWorkingToBlock(morning + afternoon)
            workingDay  = normalHours / 8

            baseOtActual = _floorToBlock(max(lo − shiftEnd, 0))
            ┌─ has OT register:
            │   deduplicate → tách otRestHour
            │   → _calcOtRecords: phân loại trước/sau ca
            │     mỗi phần: _floorToBlock(rawActual), clamp(0, approved)
            │     sum lại
            │   if otRestHour AND allowOtInRest:
            │       otActual/otApproved += restHour
            └─ no OT register: otApproved = 0

            otFinal = clamp(otActual, 0, otApproved)

            Note OT trước/sau ca (không áp dụng Chủ nhật):
                if fi < shiftBegin ≥ minOtMinute AND no before-OT record → 'OT trước ca'
                if lo > shiftEnd ≥ minOtMinute AND no after-OT record   → 'OT sau ca'

        Sunday override:
            otActual = normalHours; normalHours = 0
            otApproved = span ca − lunch (nếu có OT register)
            otFinal = clamp(otActual, 0, otApproved)

        Anomaly checks → anomalies[]
        Note 3 checks  → note3
```
