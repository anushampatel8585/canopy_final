import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canopy/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CanopyApp smoke test mounts without errors', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CanopyApp());
    await tester.pump();

    expect(find.byType(CanopyApp), findsOneWidget);
  });
}
