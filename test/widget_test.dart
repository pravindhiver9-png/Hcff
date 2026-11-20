import 'package:flutter_test/flutter_test.dart';
import 'package:hamari_chit_fund_family/app.dart';

void main() {
  testWidgets('dashboard screen opens', (tester) async {
    await tester.pumpWidget(const ChitFundApp());

    expect(find.text('समूह का हिसाब'), findsOneWidget);
    expect(find.text('त्वरित एंट्री'), findsOneWidget);
  });
}
