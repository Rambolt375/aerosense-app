import 'package:flutter/material.dart';
import 'package:aerosense_app/features/history/history_pipeline.dart';

/// Segmented range selector for history time window (1 h / 6 h / 24 h / 7 d).
class RangeSelector extends StatelessWidget {
  const RangeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final HistoryRange selected;
  final ValueChanged<HistoryRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<HistoryRange>(
      segments: HistoryRange.values.map((range) {
        return ButtonSegment<HistoryRange>(
          value: range,
          label: Text(range.label),
        );
      }).toList(),
      selected: {selected},
      onSelectionChanged: (newSelection) {
        if (newSelection.isNotEmpty) {
          onSelected(newSelection.first);
        }
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
