import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/shared/account_avatar.dart';
import 'package:aerosense_app/shared/sign_out_dialog.dart';

/// Items in the account menu. Exactly two, by design.
enum AccountMenuAction { profile, signOut }

/// Account avatar for the shell app bar.
///
/// 48 dp touch target, 40 dp visual, tooltip with the account name and the
/// accessible name "Account menu". Reads [accountProvider], so a display-name
/// edit repaints it immediately.
class AccountAvatarButton extends ConsumerWidget {
  const AccountAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider).asData?.value;

    return PopupMenuButton<AccountMenuAction>(
      tooltip: account?.displayLabel ?? AppStrings.accountMenu,
      // Drop the menu below the avatar instead of over it (the default would
      // hide the profile picture the user just tapped).
      position: PopupMenuPosition.under,
      onSelected: (action) => _handleSelection(context, ref, action),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AccountMenuAction.profile,
          child: _MenuItem(
            icon: Icons.person_outline,
            label: AppStrings.profileTitle,
          ),
        ),
        PopupMenuItem(
          value: AccountMenuAction.signOut,
          child: _MenuItem(icon: Icons.logout, label: AppStrings.signOut),
        ),
      ],
      child: Semantics(
        label: AppStrings.accountMenu,
        button: true,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AccountAvatar(
              size: 40,
              initial: account?.initial ?? '?',
              photoUrl: account?.photoUrl,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSelection(
    BuildContext context,
    WidgetRef ref,
    AccountMenuAction action,
  ) async {
    if (action == AccountMenuAction.profile) {
      context.push('/profile');
      return;
    }

    final confirmed = await showSignOutConfirmationDialog(context);
    if (!confirmed || !context.mounted) return;
    await ref.read(authRepositoryProvider).signOut();
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}
