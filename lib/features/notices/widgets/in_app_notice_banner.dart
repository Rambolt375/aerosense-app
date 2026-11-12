import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/features/notices/in_app_notice_notifier.dart';

/// In-app notice banner displayed at the top of non-Dashboard screens.
///
/// Follows DESIGN.md §5: 1 px border, flat container color, icon + text,
/// dismiss button with tooltip, and liveRegion semantics for screen readers.
class InAppNoticeBanner extends ConsumerWidget {
  const InAppNoticeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(inAppNoticeProvider);
    if (notice == null) return const SizedBox.shrink();

    final tierColors = context.tierColors;

    Color containerColor;
    Color solidColor;
    IconData icon;

    switch (notice.type) {
      case NoticeType.danger:
        containerColor = tierColors.dangerContainer;
        solidColor = tierColors.danger;
        icon = Icons.error_outline;
      case NoticeType.caution:
        containerColor = tierColors.mediumContainer;
        solidColor = tierColors.medium;
        icon = Icons.warning_amber_outlined;
      case NoticeType.deviceOffline:
        containerColor = tierColors.mediumContainer;
        solidColor = tierColors.medium;
        icon = Icons.wifi_off_outlined;
      case NoticeType.deviceOnline:
        containerColor = tierColors.safeContainer;
        solidColor = tierColors.safe;
        icon = Icons.wifi;
    }

    return Semantics(
      liveRegion: true,
      label: notice.message,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: solidColor, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: solidColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notice.message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: solidColor, fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: solidColor, size: 18),
              tooltip: 'Dismiss notice',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                ref.read(inAppNoticeProvider.notifier).dismiss();
              },
            ),
          ],
        ),
      ),
    );
  }
}
