import 'package:flutter_test/flutter_test.dart';
import 'package:vunaflow_app/main.dart';

void main() {
  testWidgets('VunaFlow app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VunaFlowApp());
    expect(find.byType(VunaFlowApp), findsOneWidget);
  });
}
