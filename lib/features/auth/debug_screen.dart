import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/shared/connection_chip.dart';

/// Debug screen showing the raw `/system` RTDB snapshot.
///
/// Only accessible in debug builds (kDebugMode). Linked from the
/// dashboard placeholder. Not in production navigation.
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawSystem = ref.watch(rawSystemProvider);
    final connected = ref.watch(connectedProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final theme = Theme.of(context);
    final user = authRepo.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug — Raw /system'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: connected.when(
              data: (c) => ConnectionChip(isConnected: c),
              loading: () => const ConnectionChip(isConnected: false),
              error: (_, _) => const ConnectionChip(isConnected: false),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Text('User', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'UID: ${user?.uid ?? '—'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            Text(
              'Email: ${user?.email ?? '—'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 20),

            // Raw /system snapshot
            Text('Raw /system snapshot', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: rawSystem.when(
                data: (value) {
                  final formatted = const JsonEncoder.withIndent('  ')
                      .convert(value);
                  return SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        formatted,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Error: $e',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sign out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                onPressed: () => authRepo.signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
