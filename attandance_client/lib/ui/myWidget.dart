import 'package:attandance_client/appColors.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

class Mywidget {
  static dateRangeWidget(List<DateTime> dateRange) {
    return Padding(
      padding: EdgeInsetsGeometry.all(8),
      child: Text(
        'Range: '
        '${DateFormat('dd/MM/yyyy').format(dateRange.first)}'
        ' → '
        '${DateFormat('dd/MM/yyyy').format(dateRange.last)}',
        style: const TextStyle(fontSize: 14, color: AppColors.warning),
      ),
    );
  }
}
