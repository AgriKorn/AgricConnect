import 'package:flutter/material.dart';

import 'agri_button.dart';

/// Shared confirmation dialog (checklist Non-Negotiable Rules — never a raw
/// showDialog with ad-hoc styling). Returns true if the user confirmed.
Future<bool?> showAgriDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: [
            AgriButton(
              label: cancelLabel,
              variant: AgriButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
              expand: false,
            ),
            AgriButton(
              label: confirmLabel,
              variant: destructive
                  ? AgriButtonVariant.destructive
                  : AgriButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
              expand: false,
            ),
          ],
        ),
      ],
    ),
  );
}
