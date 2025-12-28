// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:mobile/app.dart";

void main() {
  testWidgets("renders login screen with role toggle", (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SuAritmaApp()));
    await tester.pumpAndSettle();

    expect(find.text("FiltreFix"), findsOneWidget);
    expect(find.text("Admin Girişi"), findsOneWidget);
    expect(find.text("Personel Girişi"), findsOneWidget);
    expect(find.text("Giriş Yap"), findsOneWidget);
  });
}
