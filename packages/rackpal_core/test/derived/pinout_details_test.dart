// What turns T5.01 on (M6-E2b `#975`, DR-221 §11.220.2 to §11.220.5).
//
// On the real starters, and on them edited: Home Theatre places six
// `xantech-stereo` receiver jacks and Whole House five (IRB-1, the
// connecting block), so two starters print T5.01 as shipped. DR-221 first
// said one: the census that measured it crashed on Whole House before
// printing and its silence was read as "none". This file is what found
// it. CTL-1's six RS-232 euroblocks in Home Theatre are the real ports a
// terminal order is recorded on here.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

RackDocument _starter(String name) =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/$name.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

PinoutDetails _details(RackDocument doc) =>
    pinoutDetailsOf(doc, buildSchedule(doc));

/// CTL-1's template port [key] in [doc], as placed.
PortDef _ctlPort(RackDocument doc, String key) {
  final device = doc.devices.values.singleWhere(
    (d) => d.designator == 'CTL-1',
  );
  return bodyFor(
    device,
    doc.templates,
  )!.ports.singleWhere((p) => p.key.v == key);
}

void main() {
  group('AS SHIPPED', () {
    test('HOME THEATRE prints its six receiver jacks, with the ruled pin map '
        '(ring +12 V, sleeve GND)', () {
      final details = _details(_starter('home_theatre'));
      expect(details.irPorts, hasLength(6));
      expect(details.irPorts.map((r) => r.variant).toSet(), {
        'xantech-stereo',
      });
      expect(
        details.irPorts.map((r) => r.pinMap).toSet(),
        {'TIP IR · RING +12 V · SLEEVE GND'},
      );
      expect(
        details.irPorts.map((r) => r.port.family.v).toSet(),
        {'ctl.ir_receiver'},
      );
      expect(details.wiringExceptions, isEmpty);
      expect(details.nullModems, isEmpty);
      expect(details.terminalOrders, isEmpty);
    });

    test('WHOLE HOUSE prints IRB-1’s five receiver jacks', () {
      final details = _details(_starter('whole_house'));
      expect(details.irPorts, hasLength(5));
      expect(details.irPorts.map((r) => r.port.deviceDesignator).toSet(), {
        'IRB-1',
      });
    });

    test('Apartment and Small Office have nothing non-standard: no T5.01', () {
      for (final name in ['apartment', 'small_office']) {
        expect(_details(_starter(name)).isEmpty, isTrue, reason: name);
      }
    });

    test('MONO TIP-SLEEVE IS THE STANDARD: every starter places some, and '
        'none is listed', () {
      final doc = _starter('apartment');
      final mono = doc.devices.values.any(
        (d) =>
            bodyFor(d, doc.templates)?.ports.any(
              (p) => p.pinoutVariant == kStandardIrVariant,
            ) ??
            false,
      );
      expect(mono, isTrue, reason: 'precondition: Apartment places mono TS');
      expect(_details(doc).irPorts, isEmpty);
    });
  });

  group('TERMINAL ORDER (§11.220.5)', () {
    test('an RS-232 euroblock recorded in another order is listed, with '
        'the standard beside it', () {
      final doc = _starter('home_theatre');
      _ctlPort(doc, 'com.1').terminalRoles = ['G', 'TX', 'RX'];
      final rows = _details(doc).terminalOrders;
      expect(rows, hasLength(1));
      expect(rows.single.port.deviceDesignator, 'CTL-1');
      expect(rows.single.roles, ['G', 'TX', 'RX']);
      expect(rows.single.standard, ['TX', 'RX', 'G']);
    });

    test('the standard order, or none recorded, is not listed', () {
      final doc = _starter('home_theatre');
      _ctlPort(doc, 'com.1').terminalRoles = ['TX', 'RX', 'G'];
      expect(_details(doc).terminalOrders, isEmpty);
    });

    test('A WRONG COUNT differs from the standard and is listed: the reason '
        'the cell checks no count', () {
      final doc = _starter('home_theatre');
      _ctlPort(doc, 'com.2').terminalRoles = ['TX', 'RX'];
      expect(_details(doc).terminalOrders, hasLength(1));
    });

    test('a family with no declared standard never counts, whatever the '
        'order', () {
      expect(
        isNonStandardTerminalOrder(const SignalFamilyId('audio.line_bal'), [
          'G',
          '-',
          '+',
        ]),
        isFalse,
      );
      expect(
        isNonStandardTerminalOrder(const SignalFamilyId('ctl.cresnet'), [
          'G',
          'Z',
          'Y',
          '24',
        ]),
        isTrue,
      );
    });
  });

  group('CABLES', () {
    test('a cable whose standard differs from the project’s is listed; '
        'one that matches is not', () {
      final doc = _starter('whole_house');
      doc.settings.wiringStandard = WiringStandard.t568b;
      final cat6 = doc.links.values.firstWhere(
        (l) => l.media.v.startsWith('media.cat6'),
      )..wiringStandard = WiringStandard.t568b;
      expect(_details(doc).wiringExceptions, isEmpty, reason: 'it matches');
      cat6.wiringStandard = WiringStandard.t568a;
      expect(_details(doc).wiringExceptions.map((r) => r.designator), [
        cat6.designator,
      ]);
    });

    test('a null-modem cable is listed (nothing in the UI sets one yet, '
        '#973)', () {
      final doc = _starter('whole_house');
      final link = doc.links.values.first..crossover = CrossoverKind.nullModem;
      expect(_details(doc).nullModems.map((r) => r.designator), [
        link.designator,
      ]);
    });
  });
}
