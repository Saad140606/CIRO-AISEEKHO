
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ciro_mobile/providers/incident_provider.dart';
import 'package:ciro_mobile/main.dart';

void main() {
  testWidgets('App renders test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ],
        child: const CiroApp(),
      ),
    );
    expect(find.text('CIRO'), findsOneWidget);
  });
}
