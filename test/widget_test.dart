import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('WAVY app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WavyApp());
    expect(find.text('WAVY'), findsOneWidget);
  });
}