import 'package:flutter/material.dart';
import 'package:aerosense_app/core/theme.dart';

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
    final appColors = context.appColors;

    return Container(
      color: appColors.demoRibbonBackground,
      padding: EdgeInsets.only(top: topPadding),
      child: SizedBox(
        height: 24,
        width: double.infinity,
        child: Center(
          child: Text(
            'DEMO MODE',
            style: TextStyle(
              color: appColors.demoRibbonText,
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
