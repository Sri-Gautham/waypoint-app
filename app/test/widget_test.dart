import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waypoint/main.dart';

void main() {
  testWidgets('Onboarding starts on the create-account step', (WidgetTester tester) async {
    await tester.pumpWidget(const WaypointApp());

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('FIRST NAME'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
  });
}
