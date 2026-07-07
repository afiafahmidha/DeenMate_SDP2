import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deenmate_sdp2/main.dart';
import 'package:deenmate_sdp2/screens/login_page.dart';

void main() {
  testWidgets('Auth screen flow and Dashboard navigation test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Initially, it should build successfully.
    expect(find.byType(MyApp), findsOneWidget);

    // Let the splash screen finish (runs for 5 seconds)
    await tester.pump(const Duration(seconds: 6));

    // Verify that the Login Page is visible by checking for "Assalamu Alaikum" and "Welcome Back" text
    expect(find.text('Assalamu Alaikum'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Tap on the "Register" text span to navigate to the Registration screen
    final RichText registerRichText = tester.widget(
      find.byWidgetPredicate((widget) => 
        widget is RichText && 
        widget.text is TextSpan && 
        (widget.text as TextSpan).children != null && 
        (widget.text as TextSpan).children!.isNotEmpty &&
        widget.text.toPlainText().contains('Register')
      ).first
    );
    final TextSpan registerSpan = (registerRichText.text as TextSpan).children!.firstWhere(
      (span) => span is TextSpan && span.text == 'Register',
    ) as TextSpan;
    (registerSpan.recognizer as TapGestureRecognizer).onTap!();
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify that the Registration Page is visible by checking for "Create Your Account" text
    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);

    // Tap on "Login" to navigate back to the Login screen
    final RichText loginRichText = tester.widget(
      find.byWidgetPredicate((widget) => 
        widget is RichText && 
        widget.text is TextSpan && 
        (widget.text as TextSpan).children != null && 
        (widget.text as TextSpan).children!.isNotEmpty &&
        widget.text.toPlainText().contains('Login')
      ).first
    );
    final TextSpan loginSpan = (loginRichText.text as TextSpan).children!.firstWhere(
      (span) => span is TextSpan && span.text == 'Login',
    ) as TextSpan;
    (loginSpan.recognizer as TapGestureRecognizer).onTap!();
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify we are back on the Login page
    expect(find.text('Welcome Back'), findsOneWidget);

    // Enter valid login credentials to bypass form validation, targeting specifically the active LoginPage descendants
    final emailField = find.descendant(
      of: find.byType(LoginPage),
      matching: find.byType(TextFormField),
    ).at(0);
    final passwordField = find.descendant(
      of: find.byType(LoginPage),
      matching: find.byType(TextFormField),
    ).at(1);
    
    await tester.enterText(emailField, 'fahmidha.rahman@gmail.com');
    await tester.enterText(passwordField, 'password123');
    await tester.pump();

    // Ensure the Log In button is scrolled into view, then tap it
    final loginButton = find.descendant(
      of: find.byType(LoginPage),
      matching: find.text('Log In'),
    );
    await tester.ensureVisible(loginButton);
    await tester.pump();
    await tester.tap(loginButton);
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify we are on the Dashboard Screen (MyDeen layout)
    expect(find.text('MyDeen'), findsOneWidget);
    expect(find.text('Jummada 24, 1448 AH'), findsOneWidget);
    expect(find.text('Zakat Calculator'), findsOneWidget);

    // Verify SOS trigger button exists and can be tapped
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    // Verify SOS Panic Dialog is displayed
    expect(find.text('SOS Panic Alert Triggered'), findsOneWidget);
    await tester.tap(find.text('Cancel Alert'));
    await tester.pump();
  });
}
