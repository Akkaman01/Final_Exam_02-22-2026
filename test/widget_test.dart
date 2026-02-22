import 'package:flutter_test/flutter_test.dart';

import 'package:exam/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Election Watch'), findsOneWidget);
  });
}
