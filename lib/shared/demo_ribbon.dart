import 'package:flutter/material.dart';

/// Persistent ribbon shown at the top of the app when Demo Mode is active.
///
/// Per DESIGN.md §5: 24 dp strip at the top, #0F1B2A background, white
/// "DEMO MODE" in ALL CAPS. Always visible in demo mode so fake data is never
/// mistaken for live telemetry.
///
/// Extends into the status bar / notch via [MediaQuery.paddingOf(context).top]
/// while the content below is de-padded with [MediaQuery.removePadding].
class DemoRibbon extends StatelessWidget {
  const DemoRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      color: const Color(0xFF0F1B2A),
      padding: EdgeInsets.only(top: topPadding),
      child: const SizedBox(
        height: 24,
        width: double.infinity,
        child: Center(
          child: Text(
            'DEMO MODE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
