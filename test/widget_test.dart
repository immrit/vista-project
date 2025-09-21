// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:Vista/main.dart';
import 'package:Vista/view/util/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  group('SupabaseHttpClient Tests', () {
    test(
        'should create new request objects for retries to avoid finalize error',
        () async {
      final client = SupabaseHttpClient();

      // Create a test request
      final request =
          http.Request('GET', Uri.parse('https://httpbin.org/status/500'));

      // This should not throw "Can't finalize a finalized Request" error
      // because we create new request objects for each retry attempt
      try {
        await client.send(request);
      } catch (e) {
        // We expect this to fail with a server error, but not with a finalize error
        expect(e.toString(),
            isNot(contains('Can\'t finalize a finalized Request')));
      }

      client.close();
    });
  });
}
