import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_mobile_frontend/main.dart';

void main() {
  testWidgets('App shows Smart Chess title and core controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // App bar title
    expect(find.text('Smart Chess'), findsOneWidget);

    // Difficulty selector should be present (DropdownButton)
    expect(find.byType(DropdownButton), findsOneWidget);

    // Control buttons present
    expect(find.widgetWithIcon(ElevatedButton, Icons.refresh), findsOneWidget);
    expect(find.widgetWithIcon(OutlinedButton, Icons.undo), findsOneWidget);
    expect(find.widgetWithIcon(OutlinedButton, Icons.redo), findsOneWidget);

    // Move history expansion tile
    expect(find.text('Move history'), findsOneWidget);
  });
}
