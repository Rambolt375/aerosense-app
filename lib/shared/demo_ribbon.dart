import 'package:flutter/material.dart';

/// Persistent ribbon shown at the top of the app when Demo Mode is active.
///
/// Per DESIGN.md §5: 24 dp strip at the top, #0F1B2A background, white
/// "DEMO MODE" in ALL CAPS. Always visible in demo mode so fake data is never
/// mistaken for live telemetry.
class DemoRibbon extends StatelessWidget {
  const DemoRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: double.infinity,
      color: const Color(0xFF0F1B2A),
      alignment: Alignment.center,
      child: const Text(
        'DEMO MODE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
