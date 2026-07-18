import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/main.dart';

void main() {
  testWidgets('RackMateApp renders the M0 placeholder screen', (tester) async {
    await tester.pumpWidget(const RackMateApp());
    expect(find.text('RackMate — M0 foundations'), findsOneWidget);
  });
}
