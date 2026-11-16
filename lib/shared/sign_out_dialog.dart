import 'package:flutter/material.dart';
import 'package:aerosense_app/core/strings.dart';

/// Sign-out confirmation shared by the account menu and the profile screen.
///
/// One dialog for both entry points so a mis-tap never signs the visitor out.
/// Returns true only when the visitor explicitly confirms.
Future<bool> showSignOutConfirmationDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(AppStrings.signOut),
      content: const Text(AppStrings.signOutConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(AppStrings.profileCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(AppStrings.signOut),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
