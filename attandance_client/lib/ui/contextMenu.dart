import 'package:flutter/material.dart';
import 'package:attandance_client/appColors.dart';

/// Shows a compact context menu at [position] with edit and/or delete icon buttons.
///
/// If [onEdit] is null, the edit button is hidden.
/// If [onDelete] is null, the delete button is hidden.
void showContextMenu(
  BuildContext context,
  Offset position, {
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final menuWidth = (onEdit != null && onDelete != null) ? 96.0 : 48.0;
  final menuHeight = 40.0;

  // Clamp so the menu stays within the screen
  final dx = position.dx.clamp(0.0, overlay.size.width - menuWidth);
  final dy = position.dy.clamp(0.0, overlay.size.height - menuHeight);

  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    builder: (ctx) => Stack(
      children: [
        Positioned(
          left: dx,
          top: dy,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.surface,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: AppColors.info,
                      tooltip: 'Edit',
                      onPressed: () {
                        Navigator.pop(ctx);
                        onEdit();
                      },
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      color: AppColors.danger,
                      tooltip: 'Delete',
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
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
