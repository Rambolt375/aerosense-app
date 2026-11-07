import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/app.dart';

void main() {
  testWidgets('AeroSenseApp launches to dashboard screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AeroSenseApp()));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
  });
}
