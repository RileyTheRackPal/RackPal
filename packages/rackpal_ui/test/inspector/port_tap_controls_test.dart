// The transformer controls on a constant-voltage pin (`#838`, M5-K,
// DR-131 §11.130 and DR-132 §11.131).
//
// ═══════════════════════════════════════════════════════════════════════
// THE PAIRING TEST IS THE POINT, AND IT IS HERE BECAUSE OF DR-129
// ═══════════════════════════════════════════════════════════════════════
// `SetPortFactCommand` switches exhaustively over `PortFactField`, so
// adding `tapWatts` and `lowZBypass` to that enum forced every branch in
// the COMMAND to be written. It forced nothing in the widget:
// `device_ports_section.dart` lists its controls by hand, so both new
// fields compiled green with no way to set either.
//
// That is DR-129's finding exactly, one layer along. `Finding.remedy`
// shipped with a writer, an implementation and a ruling saying the panel
// rendered it, and the panel never read the field. So the gate is the
// same shape `remedy_pairing_test.dart` uses: assert in BOTH directions
// that every port fact reaches a control a person can operate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final _now = DateTime.utc(2026, 9, 6);
const _deviceId = Uuid('0190e0ff-0002-7000-8000-000000000001');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

PortDef _def(String key, String family) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.euroblock_2'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  order: const FracIndex('a0'),
);

RackDocument _doc(String family) {
  final doc = RackDocument(
    id: const Uuid('doc-tap-ui'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  )..registries = buildSeedRegistries();
  doc.templates['spk@1'] = TemplateSnapshot(
    templateId: const TemplateId('spk'),
    version: 1,
    contentHash: 'unhashed:spk@1',
    body: TemplateBody(
      manufacturer: 'Test',
      model: 'spk',
      displayName: 'Speaker',
      ports: [_def('cv', family)],
    ),
    capturedAt: _now,
  );
  doc.devices[_deviceId] = DeviceInstance(
    id: _deviceId,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('spk'),
      version: 1,
      contentHash: 'unhashed:spk@1',
    ),
    designator: 'SPK-1',
    name: 'SPK-1',
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
  return doc;
}

/// Mounts the section and runs the REAL command on every edit, so a
/// control that reports the wrong field or value fails here rather than
/// looking right on screen.
Widget _host(RackDocument doc, List<PortFactField> touched) => MaterialApp(
  home: Scaffold(
    body: StatefulBuilder(
      builder: (context, setState) => SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: DevicePortsSection(
            doc: doc,
            device: doc.devices[_deviceId]!,
            onSetPortFact: (key, field, value, designator) {
              touched.add(field);
              SetPortFactCommand(
                deviceId: _deviceId,
                portKey: key,
                field: field,
                value: value,
                designatorIfMaterialised: designator,
                now: _now,
                actor: 'test',
              ).apply(doc);
              setState(() {});
            },
          ),
        ),
      ),
    ),
  ),
);

Port? _port(RackDocument doc) =>
    doc.ports[derivePortId(_deviceId, const PortKey('cv'))];

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The section collapses by default and a port's form is a second
/// disclosure, so both have to be opened before any control exists.
Future<void> _openPortForm(WidgetTester tester) async {
  await _tap(tester, find.textContaining('PORTS ('));
  await _tap(tester, find.byKey(const ValueKey('port-row-cv')));
}

void main() {
  group('every PortFactField reaches a control (the DR-129 gate)', () {
    testWidgets('all five are operable on one pin, and the enum is the '
        'list', (tester) async {
      // BOTH DIRECTIONS. A field the widget cannot set is a fact nobody
      // can record; a control for a field the enum does not have would
      // not compile. Named against the enum rather than counted, so a
      // sixth field fails here instead of shipping unreachable.
      expect(PortFactField.values, [
        PortFactField.userLabel,
        PortFactField.connector,
        PortFactField.signalFamily,
        PortFactField.tapWatts,
        PortFactField.lowZBypass,
      ]);

      final doc = _doc('audio.speaker_cv');
      final touched = <PortFactField>[];
      await tester.pumpWidget(_host(doc, touched));
      await _openPortForm(tester);

      // The two this milestone added, driven for real.
      await tester.enterText(find.byType(TextField).last, '15');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(touched, contains(PortFactField.tapWatts));
      expect(touched, contains(PortFactField.lowZBypass));
      expect(_port(doc)?.tapWatts, 15);
      expect(_port(doc)?.lowZBypass, isTrue);
    });
  });

  group('the controls appear where a transformer can be', () {
    testWidgets('a constant-voltage pin gets both', (tester) async {
      await tester.pumpWidget(_host(_doc('audio.speaker_cv'), []));
      await _openPortForm(tester);
      expect(find.text(kPortTapLabel), findsOneWidget);
      expect(find.text(kPortBypassLabel), findsOneWidget);
    });

    testWidgets('an ethernet pin gets neither, rather than a tap box on '
        'every one of 727 pins', (tester) async {
      await tester.pumpWidget(_host(_doc('net.ethernet'), []));
      await _openPortForm(tester);
      expect(find.text(kPortTapLabel), findsNothing);
      expect(find.text(kPortBypassLabel), findsNothing);
    });

    testWidgets('and a BYPASSED pin keeps them, so the switch is not a '
        'one-way door', (tester) async {
      // Bypass moves the resolved family to low-Z (DR-131), so gating on
      // the family alone would make the control that set it disappear
      // and leave no way to set it back.
      final doc = _doc('audio.speaker_cv');
      final id = derivePortId(_deviceId, const PortKey('cv'));
      doc.ports[id] = Port(
        id: id,
        deviceId: _deviceId,
        designator: 'SPK-1.CV',
        templatePortKey: const PortKey('cv'),
        lowZBypass: true,
      );
      await tester.pumpWidget(_host(doc, []));
      await _openPortForm(tester);
      expect(find.text(kPortBypassLabel), findsOneWidget);
    });
  });

  group('an empty tap box is a STATE, not a zero (G4)', () {
    testWidgets('the hint says which state it is', (tester) async {
      await tester.pumpWidget(_host(_doc('audio.speaker_cv'), []));
      await _openPortForm(tester);
      expect(find.text(kPortTapHint), findsOneWidget);
    });

    testWidgets('clearing it records null rather than 0', (tester) async {
      final doc = _doc('audio.speaker_cv');
      await tester.pumpWidget(_host(doc, []));
      await _openPortForm(tester);
      await tester.enterText(find.byType(TextField).last, '15');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_port(doc)?.tapWatts, 15);

      await tester.enterText(find.byType(TextField).last, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        _port(doc)?.tapWatts,
        isNull,
        reason:
            'ELE-005 counts an unrecorded tap as an unknown and NAMES the '
            'speaker, so clearing this is a statement rather than a reset',
      );
    });

    testWidgets('and a typo is left alone rather than read as cleared', (
      tester,
    ) async {
      final doc = _doc('audio.speaker_cv');
      await tester.pumpWidget(_host(doc, []));
      await _openPortForm(tester);
      await tester.enterText(find.byType(TextField).last, '15');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '1o');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        _port(doc)?.tapWatts,
        15,
        reason:
            'turning "1o" into "no tap recorded" would silently change '
            'what ELE-005 reports about this line',
      );
    });
  });
}
