// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sheyaka_landing/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SheyakaApp());
    await tester.pumpAndSettle(); // التأكد من انتهاء جميع الرسوم المتحركة قبل بدء الفحص

    // Verify that the app loads without crashing
    expect(find.text('شياكة بيت ✨'), findsOneWidget);
    expect(find.text('اختيارك لأفضل أدوات تنظيم المنزل العصرية'), findsOneWidget);
  });
}
