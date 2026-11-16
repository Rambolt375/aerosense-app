import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/account_name.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/models/account_info.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/shared/account_avatar.dart';
import 'package:aerosense_app/shared/sign_out_dialog.dart';

/// Account profile page at the top-level `/profile` route.
///
/// Outside the navigation shell, so there is no bottom navigation. Only the
/// display name is editable; the email and the photo come from the provider and
/// stay read-only. Editing the name changes the Firebase Auth profile only, not
/// the device or any database node.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(accountProvider).asData?.value;
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 16.0 : 24.0;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: EdgeInsets.all(padding),
              children: [
                Center(
                  child: AccountAvatar(
                    size: 96,
                    initial: account?.initial ?? '?',
                    photoUrl: account?.photoUrl,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  account == null
                      ? AppStrings.placeholderValue
                      : account.displayLabel,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  account == null || account.email.isEmpty
                      ? AppStrings.placeholderValue
                      : account.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Center(child: _ProviderChip(kind: account?.kind)),
                const SizedBox(height: 24),
                _NameEditor(account: account),
                const SizedBox(height: 12),
                Text(
                  AppStrings.profileCaption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(AppStrings.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showSignOutConfirmationDialog(context);
    if (!confirmed || !context.mounted) return;
    await ref.read(authRepositoryProvider).signOut();
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.kind});

  final AccountProviderKind? kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      AccountProviderKind.google => AppStrings.providerGoogle,
      AccountProviderKind.team => AppStrings.providerTeam,
      AccountProviderKind.demo => AppStrings.providerDemo,
      null => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

/// Inline display-name editor.
///
/// The open/closed state, the controller, the saving flag and the validation
/// message are purely local and ephemeral, so they live in `setState`; the
/// persisted name comes from [accountProvider].
class _NameEditor extends ConsumerStatefulWidget {
  const _NameEditor({required this.account});

  final AccountInfo? account;

  @override
  ConsumerState<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends ConsumerState<_NameEditor> {
  final TextEditingController _controller = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _error = null;
      _controller.text = widget.account?.displayName ?? '';
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _error = null;
      _saving = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final clean = normalizeDisplayName(_controller.text);
    if (clean == null) {
      setState(() => _error = AppStrings.profileNameInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).updateDisplayName(clean);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppStrings.profileNameSaved),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AppStrings.profileNameSaveFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDemo = widget.account?.isDemo ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_editing)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(AppStrings.profileEditName),
            ),
          )
        else ...[
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: displayNameMaxLength,
            textInputAction: TextInputAction.done,
            enabled: !_saving,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: AppStrings.profileNameLabel,
              errorText: _error,
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: _saving ? null : _cancelEditing,
                child: const Text(AppStrings.profileCancel),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text(AppStrings.profileSave),
              ),
            ],
          ),
        ],
        if (isDemo) ...[
          const SizedBox(height: 8),
          Text(
            AppStrings.profileDemoNotSaved,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
