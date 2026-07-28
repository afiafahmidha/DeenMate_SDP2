import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deenmate_sdp2/screens/calendar_tab.dart';

void main() {
  testWidgets('Calendar tab uses the active theme scaffold background in dark mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: CalendarTab(onOpenZakatCalculator: () {}, isDarkMode: true),
      ),
    );

    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);

    expect(scaffold.backgroundColor, equals(ThemeData.dark().scaffoldBackgroundColor));
  });
}
