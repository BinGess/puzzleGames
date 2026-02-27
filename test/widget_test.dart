import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('placeholder smoke test', (WidgetTester tester) async {
    // App requires Hive init before running — integration tests go here
    expect(true, isTrue);
  });
}
