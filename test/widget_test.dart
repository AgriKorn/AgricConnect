import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agriconnect/main.dart';

void main() {
  testWidgets('Welcome screen shows brand and entry points', (WidgetTester tester) async {
    await tester.pumpWidget(const AgriConnectApp());

    expect(find.text('AgriConnect'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Already have an account? Log In'), findsOneWidget);
  });

  testWidgets('Get Started leads to role selection', (WidgetTester tester) async {
    await tester.pumpWidget(const AgriConnectApp());

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Farmer'), findsOneWidget);
    expect(find.text('Buyer'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
  });
}
