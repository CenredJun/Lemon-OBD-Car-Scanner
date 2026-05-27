import 'package:flutter_test/flutter_test.dart';

import 'package:obd2_scanner/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const Obd2ScannerApp());
    await tester.pump();
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
