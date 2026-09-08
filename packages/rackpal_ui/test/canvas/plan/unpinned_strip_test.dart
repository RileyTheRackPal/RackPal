// PLAN-E/4: the strip along the bottom (docs/15 §6, DR-140, DR-142).
//
// THE ROWS ARE FOUND BY KEY, NOT BY TEXT OR BY TYPE. A strip legitimately
// renders the same designator a canvas label does, and `byType().first`
// in a list finds whichever row the layout happened to build first: both
// locate the wrong widget and PASS. `UnpinnedStrip.rowKey` exists so a
// case can say which row it means.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

UnpinnedCarrier _row(String designator, PinCarrier carrier, {String? name}) =>
    UnpinnedCarrier(
      entityId: Uuid('id-$designator'),
      carrier: carrier,
      designator: designator,
      name: name,
    );

void main() {
  Future<void> pump(
    WidgetTester tester,
    UnpinnedCarriers carriers, {
    void Function(UnpinnedCarrier, PointerDownEvent)? onArmDrag,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: UnpinnedStrip(carriers: carriers, onArmDrag: onArmDrag),
          ),
        ),
      ),
    ),
  );

  group('the count', () {
    testWidgets('IS THE CARRIER COUNT, which is the whole of DR-140', (
      tester,
    ) async {
      // Three devices and one rack: the two plausible answers are 3 and
      // 4, and only a strip that knows a rack is a carrier says 4.
      await pump(
        tester,
        UnpinnedCarriers(
          rows: [
            _row('RK-1', PinCarrier.rack),
            _row('D-1', PinCarrier.offRackDevice),
            _row('D-2', PinCarrier.offRackDevice),
            _row('D-3', PinCarrier.offRackDevice),
          ],
          unlocatedCount: 0,
        ),
      );

      expect(find.text('4 $kUnpinnedStripCountSuffix'), findsOneWidget);
    });

    testWidgets('says so plainly when there is nothing left', (tester) async {
      await pump(
        tester,
        const UnpinnedCarriers(rows: [], unlocatedCount: 0),
      );

      expect(find.text(kUnpinnedStripEmptyLabel), findsOneWidget);
    });
  });

  group('the unknown count (G4, CR-114)', () {
    testWidgets('is its own line, so the two are not merged into a total', (
      tester,
    ) async {
      await pump(
        tester,
        UnpinnedCarriers(
          rows: [_row('D-1', PinCarrier.offRackDevice)],
          unlocatedCount: 2,
        ),
      );

      expect(find.text('1 $kUnpinnedStripCountSuffix'), findsOneWidget);
      expect(find.text('2 $kUnpinnedStripUnlocatedSuffix'), findsOneWidget);
      // AND NOT 3 ANYWHERE. Merging them is the failure this line exists
      // to prevent: a reader who adds them gets a number that claims the
      // strip can place two things it cannot.
      expect(find.text('3 $kUnpinnedStripCountSuffix'), findsNothing);
    });

    testWidgets('is absent at zero rather than reading "0"', (tester) async {
      // A permanent zero trains the reader to stop seeing the line.
      await pump(
        tester,
        UnpinnedCarriers(
          rows: [_row('D-1', PinCarrier.offRackDevice)],
          unlocatedCount: 0,
        ),
      );

      expect(find.text('0 $kUnpinnedStripUnlocatedSuffix'), findsNothing);
    });
  });

  group('a row', () {
    testWidgets('shows its designator, and its name when it has one', (
      tester,
    ) async {
      await pump(
        tester,
        UnpinnedCarriers(
          rows: [
            _row('RK-1', PinCarrier.rack, name: 'Head end'),
            _row('D-014', PinCarrier.outlet),
          ],
          unlocatedCount: 0,
        ),
      );

      expect(find.text('RK-1'), findsOneWidget);
      expect(find.text('Head end'), findsOneWidget);
      expect(find.text('D-014'), findsOneWidget);
      // An outlet has a designation and no name. G4's absent key, drawn
      // as nothing rather than as a blank second line.
      expect(
        find.descendant(
          of: find.byKey(UnpinnedStrip.rowKey(const Uuid('id-D-014'))),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ARMS THE ROW IT IS, not whichever one is first', (
      tester,
    ) async {
      final armed = <String>[];
      await pump(
        tester,
        UnpinnedCarriers(
          rows: [
            _row('RK-1', PinCarrier.rack),
            _row('D-1', PinCarrier.offRackDevice),
            _row('D-2', PinCarrier.offRackDevice),
          ],
          unlocatedCount: 0,
        ),
        onArmDrag: (row, _) => armed.add(row.designator),
      );

      await tester.startGesture(
        tester.getCenter(
          find.byKey(UnpinnedStrip.rowKey(const Uuid('id-D-2'))),
        ),
      );

      expect(armed, ['D-2']);
    });

    testWidgets('carries the writer a pin on it would use', (tester) async {
      // The row exists to become a `SetPlanPinCommand`, and the carrier
      // is the half of that command a designator cannot supply.
      final armed = <PinCarrier>[];
      await pump(
        tester,
        UnpinnedCarriers(
          rows: [
            _row('RK-1', PinCarrier.rack),
            _row('D-014', PinCarrier.outlet),
          ],
          unlocatedCount: 0,
        ),
        onArmDrag: (row, _) => armed.add(row.carrier),
      );

      await tester.startGesture(
        tester.getCenter(
          find.byKey(UnpinnedStrip.rowKey(const Uuid('id-RK-1'))),
        ),
      );

      expect(armed, [PinCarrier.rack]);
    });

    testWidgets('DOES NOT OVERFLOW, at any of five widths, named or not', (
      tester,
    ) async {
      // THIS CASE EXISTS BECAUSE IT FIRED. A named row is two lines and
      // the strip was 56 high, which left 28 for them after the list's
      // padding and the chip's: `RenderFlex overflowed by 6.0 pixels`,
      // the first time a row with a name was rendered.
      //
      // FIVE WIDTHS AND NOT ONE, because a `RenderFlex` reports an
      // overflow ONCE per render object: a single pump measures a single
      // layout and reads as "clean" for every width it did not try.
      final carriers = UnpinnedCarriers(
        rows: [
          _row('RK-1', PinCarrier.rack, name: 'Head end rack, hall closet'),
          _row('D-014', PinCarrier.outlet),
          _row('SPK-1', PinCarrier.offRackDevice, name: 'Ceiling speaker'),
        ],
        unlocatedCount: 3,
      );
      for (final width in [220.0, 320.0, 600.0, 900.0, 1440.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: UnpinnedStrip(carriers: carriers),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'the strip overflowed at ${width}px',
        );
      }
    });

    testWidgets('is readable and inert when the host offers no drop', (
      tester,
    ) async {
      // NULL IS A SUPPORTED MODE, on `PlanCanvasScreen.arm`'s precedent: a
      // host with no canvas to drop on shows the count and the rows and
      // arms nothing.
      await pump(
        tester,
        UnpinnedCarriers(
          rows: [_row('D-1', PinCarrier.offRackDevice)],
          unlocatedCount: 0,
        ),
      );

      await tester.startGesture(
        tester.getCenter(
          find.byKey(UnpinnedStrip.rowKey(const Uuid('id-D-1'))),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('D-1'), findsOneWidget);
    });
  });
}
