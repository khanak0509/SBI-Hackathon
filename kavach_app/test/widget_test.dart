import 'package:flutter_test/flutter_test.dart';
import 'package:kavach_app/app.dart';
import 'package:kavach_app/services/kavach_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('KAVACH shell renders', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => KavachService(),
        child: const KavachApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('KAVACH'), findsWidgets);
  });
}
