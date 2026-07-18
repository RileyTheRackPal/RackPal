import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/main.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

void main() {
  testWidgets('RackMateApp renders the rack canvas with a zoom readout',
      (tester) async {
    await tester.pumpWidget(const RackMateApp());
    // M1 walking skeleton: the placeholder Text is replaced by the pannable/
    // zoomable canvas, whose HUD shows the live zoom at 100% on first frame.
    expect(find.byType(RackCanvasScreen), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}
