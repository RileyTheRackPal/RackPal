// The non-rack device path (`#246`, AC-031, DR-107 §11.106.2).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS PATH HAD NO TEST, AND THAT IS HOW IT WAS BLOCKED IN SILENCE
// ═══════════════════════════════════════════════════════════════════════
// AC-049's save gate accepted a zero RU height only when
// `side == zeroUVertical`. Every one of AC-031's 18 shipped field
// templates is `{front: 0, rear: 0, side: none, notInRack}`, so `Save`
// was disabled for all of them and stayed disabled whatever the person
// typed: the 18 ship in the seed catalog and nobody could author a
// nineteenth.
//
// A rack device cannot reach that state, so every existing builder test
// passed. The first test below is the one that would have caught it, and
// it is deliberately first.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final class _Measurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

final Registries _registries = buildSeedRegistries();
final Map<String, TemplateBody> _seed = buildSeedCatalog();

/// A field device exactly as `catalog_field.dart` builds one.
TemplateBody _field({String name = 'Ceiling Speaker'}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'SPK',
  displayName: name,
  typePrefix: 'SPK',
  category: 'Field Devices',
  frontU: 0,
  rearU: 0,
  side: OccupancySide.none,
  mountMethod: MountMethod.notInRack,
);

TemplateBody _rack() => TemplateBody(
  manufacturer: 'Generic',
  model: 'AMP',
  displayName: 'Amplifier',
  typePrefix: 'AMP',
  frontU: 2,
  rearU: 2,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
);

Future<TemplateBody?> _pump(
  WidgetTester tester,
  TemplateBody body, {
  Size size = const Size(1740, 1000),
}) async {
  TemplateBody? saved;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeviceBuilderScreen(
          template: body,
          registries: _registries,
          measurer: _Measurer(),
          actions: DeviceBuilderActions(
            onSave: (b) {
              saved = b;
              return null;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

Future<void> _open(WidgetTester tester, String section) async {
  await tester.tap(find.text(section).first);
  await tester.pumpAndSettle();
}

void main() {
  group('the save gate admits a field device', () {
    test('the 19 shipped field templates are all zero-occupancy notInRack, '
        'which is the state the gate used to refuse', () {
      final field = _seed.values.where(
        (b) => b.mountMethod == MountMethod.notInRack,
      );
      expect(field, hasLength(19), reason: 'AC-031 ships exactly 18');
      for (final b in field) {
        expect(b.frontU, 0, reason: b.displayName);
        expect(b.rearU, 0, reason: b.displayName);
        expect(b.side, OccupancySide.none, reason: b.displayName);
      }
    });

    testWidgets('a field device with a name and a prefix CAN be saved', (
      tester,
    ) async {
      final body = _field();
      await _pump(tester, body);
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save').first,
      );
      expect(
        save.onPressed,
        isNotNull,
        reason: 'every one of AC-031’s 18 templates is in this state',
      );
    });

    testWidgets('a BLANK new template still cannot, which is the hole the '
        'default change closed', (tester) async {
      // THE REGRESSION THIS PAIR EXISTS TO PIN. `notInRack` used to be
      // TemplateBody's default, so admitting it at the gate let a blank
      // template save with no RU height -- the stall AC-049 exists to
      // prevent, re-opened by the fix for #246. The default is `rackEars`
      // now, so this body is a rack device with an untouched zero and is
      // correctly refused.
      final blank = TemplateBody(
        manufacturer: 'Generic',
        model: '',
        displayName: 'Named',
      )..typePrefix = 'AMP';
      expect(blank.mountMethod, MountMethod.rackEars);
      await _pump(tester, blank);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save').first,
            )
            .onPressed,
        isNull,
        reason: 'a default cannot be evidence that a zero was MEANT',
      );
    });

    testWidgets('and a RACK device with a zero height still cannot, because '
        'that zero is an untouched default rather than a meant one', (
      tester,
    ) async {
      final body = _rack()
        ..frontU = 0
        ..rearU = 0;
      await _pump(tester, body);
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save').first,
      );
      expect(
        save.onPressed,
        isNull,
        reason:
            'AC-049 wants three facts SUPPLIED; this is the stall it '
            'exists to prevent, and admitting notInRack must not weaken it',
      );
    });
  });

  group('the form is stripped, not greyed out', () {
    testWidgets('a field device shows five sections and no Panel', (
      tester,
    ) async {
      await _pump(tester, _field());
      expect(find.text('Panel'), findsNothing);
      for (final s in [
        'Identity',
        'Ports',
        'Physical',
        'Power',
        'Appearance',
      ]) {
        expect(find.text(s), findsWidgets, reason: s);
      }
    });

    testWidgets('a rack device still shows all six', (tester) async {
      await _pump(tester, _rack());
      expect(find.text('Panel'), findsWidgets);
    });

    test('the rule is a pure function, so it is asserted without a widget', () {
      expect(visibleSections(_rack()), BuilderSection.values);
      expect(visibleSections(_field()), isNot(contains(BuilderSection.panel)));
      expect(visibleSections(_field()), hasLength(5));
    });

    // TALL ON PURPOSE. `Physical` is a `ListView`, so a short viewport
    // never BUILDS its last rows -- and `findsNothing` against a row that
    // was merely below the fold proves nothing at all. At 2400 every row
    // of the rack form builds, which is what makes the pair below a real
    // comparison rather than two independent guesses.
    const tall = Size(1740, 2400);

    testWidgets('Physical drops its rack rows and keeps the two that are not '
        'rack geometry', (tester) async {
      await _pump(tester, _field(), size: tall);
      await _open(tester, 'Physical');

      // KEPT. Mount method is the way back out, and a speaker has a weight.
      expect(find.text('Mount method'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);

      // GONE. AC-031: no RU, no rack depth, no thermal class.
      for (final gone in [
        'RU height (rear)',
        'Occupies',
        'Width class',
        'Width in twelfths of a rack',
        'Body depth',
        'Chassis width',
        'Max unsupported mass',
        'Clearance above (U)',
        'Clearance below (U)',
        'Thermal class',
        'Passthrough',
        'Container',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('not in the rack'), findsOneWidget);
    });

    testWidgets('and a rack device keeps every one of them', (tester) async {
      await _pump(tester, _rack(), size: tall);
      await _open(tester, 'Physical');
      for (final kept in [
        'RU height (rear)',
        'Occupies',
        'Mount method',
        'Thermal class',
        'Weight',
      ]) {
        expect(find.text(kept), findsOneWidget, reason: kept);
      }
    });
  });

  group('a section cannot vanish under the person standing in it', () {
    testWidgets('opening Panel, then making the device a field device, lands '
        'on Ports rather than on nothing', (tester) async {
      final body = _rack();
      await _pump(tester, body);
      await _open(tester, 'Panel');
      expect(find.textContaining('Customize panel layout'), findsOneWidget);

      await _open(tester, 'Physical');
      // The label is `_mountLabel(notInRack)`, which is 'Not in a rack'.
      // The first draft guessed 'Not in rack' and the finder threw rather
      // than passing on the wrong widget, which is the behaviour worth
      // having.
      await tester.tap(find.text('Rack ears').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not in a rack').last);
      await tester.pumpAndSettle();

      expect(find.text('Panel'), findsNothing);
      expect(
        find.textContaining('Customize panel layout'),
        findsNothing,
        reason:
            'the pane must not keep drawing a canvas for a device that '
            'no longer has a panel',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
