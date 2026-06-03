import 'package:attandance_client/appColors.dart';
import 'package:attandance_client/services/update_service.dart';
import 'package:flutter/material.dart';

Future<bool> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(Icons.system_update_alt, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Cập nhật phiên bản mới'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phiên bản mới đã sẵn sàng trên server.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _versionChip('Hiện tại', info.localVersion, AppColors.textTertiary),
              SizedBox(width: 12),
              Icon(Icons.arrow_forward, size: 16, color: AppColors.textTertiary),
              SizedBox(width: 12),
              _versionChip('Mới', info.serverVersion, AppColors.success),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'App sẽ tắt và tự khởi động lại sau khi cập nhật.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Bỏ qua', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text('Cập nhật ngay'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Widget _versionChip(String label, String version, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '$label: v$version',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
    ),
  );
}
