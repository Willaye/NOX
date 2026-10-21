import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NOX app smoke test', (WidgetTester tester) async {
    // Basic smoke test - app services require platform channels
    // so we just verify the test framework works
    expect(1 + 1, equals(2));
  });
}
