import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deenmate_sdp2/screens/emergency_sos_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sos_name': 'Muhammad Ali',
      'sos_passport': 'K98765432',
    });
  });

  Future<void> pumpTransition(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();
  }

  testWidgets('EmergencySosScreen widgets load correctly and can navigate tabs', (WidgetTester tester) async {
    // Build our screen.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmergencySosScreen(),
        ),
      ),
    );

    // Let any initial async operations run and trigger a rebuild
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify page title and subtitle exist
    expect(find.text('Emergency SOS'), findsOneWidget);
    expect(find.text('Live panic trigger & critical care'), findsOneWidget);

    // Verify the tabs are displayed
    expect(find.text('SOS Button'), findsOneWidget);
    expect(find.text('Medical Card'), findsOneWidget);
    expect(find.text('Maps & Guides'), findsOneWidget);
    expect(find.text('Group Hub'), findsOneWidget);

    // Verify key widgets on Tab 1 (SOS Button tab) are visible
    expect(find.text('PRESS & HOLD TO TRIGGER SOS'), findsOneWidget);
    expect(find.text('Silent SOS Mode'), findsOneWidget);

    // Scroll down the ListView to ensure the Location Card is fully built/visible in the viewport
    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);
    await tester.drag(listViewFinder, const Offset(0, -300));
    await pumpTransition(tester);

    // Verify location card is visible
    expect(find.text('Real-time GPS Status'), findsOneWidget);

    // Tap on the "Medical Card" tab
    await tester.tap(find.text('Medical Card'));
    await pumpTransition(tester);

    // Verify profile text details exist
    expect(find.text('MEDICAL EMERGENCY CARD'), findsOneWidget);
    expect(find.text('Profile Information Details'), findsOneWidget);

    // Tap on the "Maps & Guides" tab
    await tester.tap(find.text('Maps & Guides'));
    await pumpTransition(tester);

    // Verify elements in guides tab are loaded
    expect(find.text('Holy Sites Live Map'), findsOneWidget);

    // Scroll guides down to bring contacts into view
    await tester.drag(listViewFinder, const Offset(0, -250)).catchError((_){});
    await pumpTransition(tester);

    expect(find.text('Location-Aware Emergency Contacts'), findsOneWidget);
    expect(find.text('Saudi Red Crescent (Ambulance)'), findsOneWidget);
    
    // Tap on the "Group Hub" tab
    await tester.tap(find.text('Group Hub'));
    await pumpTransition(tester);

    // Scroll Group Hub down to bring simulation controls into viewport
    await tester.drag(listViewFinder, const Offset(0, -350)).catchError((_){});
    await pumpTransition(tester);

    // Verify simulation elements are loaded
    expect(find.text('Emergency Simulation Controls'), findsOneWidget);
    expect(find.text('Simulate Offline (No Internet)'), findsOneWidget);
  });
}
