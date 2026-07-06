import 'package:flutter_test/flutter_test.dart';
import 'package:deenmate_sdp2/main.dart';

void main() {
  testWidgets('Auth screen flow test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Initially, it should build successfully.
    expect(find.byType(MyApp), findsOneWidget);

    // Let the splash screen finish (runs for 5 seconds)
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // Verify that the Login Page is visible by checking for "Welcome Back" text
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Tap on the "Register" text to navigate to the Registration screen
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    // Verify that the Registration Page is visible by checking for "Create Your Account" text
    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);

    // Tap on "Login" to navigate back to the Login screen
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Verify we are back on the Login page
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
