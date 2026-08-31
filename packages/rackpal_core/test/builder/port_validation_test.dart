// The port grid's live validation (M4-E4, #206).
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

TemplateBody _body() =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D');

PortDef _port(
  String key, {
  required String order,
  String family = 'video.hdmi.2_0',
  String? designatorHint,
  int? impedance,
  String? pinout,
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  order: FracIndex(order),
  designatorHint: designatorHint,
  impedanceOhms: impedance,
  pinoutVariant: pinout,
);

void main() {
  group('the ids these rules name still exist', () {
    // THE TEST THAT MAKES THE HARD-CODED IDS SAFE. The durable form of
    // these rules is a field on `SignalFamilyDef`, which is not built, so
    // a rename in the seeded registries would otherwise switch a safety
    // check off in silence rather than break anything.
    final registries = buildSeedRegistries();

    test('the S/PDIF coax family is still spelled that way', () {
      expect(
        registries.signalFamilies[kSpdifCoaxFamily],
        isNotNull,
        reason:
            'if this fails, the family was renamed and the impedance '
            'check stopped firing. Fix the constant, do not delete the '
            'test',
      );
    });

    test('both IR families are still spelled that way', () {
      for (final family in kIrFamilies) {
        expect(
          registries.signalFamilies[family],
          isNotNull,
          reason: '$family: the pinout check would have gone quiet',
        );
      }
    });

    test('there are exactly two of them, because the hazard is that they '
        'are two', () {
      // The seeded registries split emitter from receiver precisely
      // because the pinouts are opposite. A third IR family, or a merge
      // back to one, changes what this rule should say.
      final ir = registries.signalFamilies.keys.where(
        (k) => k.v.startsWith('ctl.ir_'),
      );
      expect(ir, hasLength(2));
    });
  });

  group('duplicate designators', () {
    test('both offending rows are flagged, not just the second', () {
      final body = _body()
        ..ports.addAll([
          _port('a', order: 'a0', designatorHint: 'J01'),
          _port('b', order: 'a1', designatorHint: 'J01'),
          _port('c', order: 'a2', designatorHint: 'J02'),
        ]);

      final issues = validatePorts(body);

      expect(issues.keys, unorderedEquals(['a', 'b']));
      expect(issues['a']!.single.severity, PortIssueSeverity.warning);
      expect(issues['a']!.single.column, PortColumnId.designator);
      expect(issues['a']!.single.message, contains('J01'));
    });

    test('automatic designators cannot collide, so they are not checked', () {
      // An automatic designator is rendered from the port's position in
      // the declared order, which is injective by construction.
      final body = _body()
        ..ports.addAll([
          _port('a', order: 'a0'),
          _port('b', order: 'a1'),
        ]);

      expect(validatePorts(body), isEmpty);
    });

    test('whitespace is not a designator', () {
      final body = _body()
        ..ports.addAll([
          _port('a', order: 'a0', designatorHint: '  '),
          _port('b', order: 'a1', designatorHint: ''),
        ]);

      expect(validatePorts(body), isEmpty);
    });
  });

  group('passthrough pairing', () {
    test('an unpaired port on a passthrough device is a NOTICE', () {
      final body = _body()
        ..isPassthrough = true
        ..ports.addAll([_port('f1', order: 'a0'), _port('r1', order: 'a1')]);

      final issues = validatePorts(body);

      expect(issues.keys, unorderedEquals(['f1', 'r1']));
      expect(
        issues['f1']!.single.severity,
        PortIssueSeverity.notice,
        reason:
            'docs/06 §4.6: missing pairs are a load warning rather than '
            'an error, so a half-paired panel mid-authoring must not '
            'shout',
      );
    });

    test('a paired port says nothing', () {
      final body = _body()
        ..isPassthrough = true
        ..ports.addAll([_port('f1', order: 'a0'), _port('r1', order: 'a1')])
        ..passthroughPairs.add(
          const PassthroughPairDef(
            frontKey: PortKey('f1'),
            rearKey: PortKey('r1'),
            sameNet: true,
          ),
        );

      expect(validatePorts(body), isEmpty);
    });

    test('a device that is not a passthrough is not asked to pair', () {
      final body = _body()..ports.add(_port('p1', order: 'a0'));

      expect(validatePorts(body), isEmpty);
    });
  });

  group('coaxial S/PDIF impedance', () {
    test('an unset impedance is flagged, and the sentence says what to do', () {
      final body = _body()
        ..ports.add(_port('p1', order: 'a0', family: 'audio.spdif_coax'));

      final issue = validatePorts(body)['p1']!.single;

      expect(issue.severity, PortIssueSeverity.notice);
      expect(issue.column, PortColumnId.impedanceOhms);
      expect(issue.message, contains('75'));
    });

    test('a WRONG impedance says what it found', () {
      final body = _body()
        ..ports.add(
          _port('p1', order: 'a0', family: 'audio.spdif_coax', impedance: 50),
        );

      expect(validatePorts(body)['p1']!.single.message, contains('50'));
    });

    test('75 ohm is silent', () {
      final body = _body()
        ..ports.add(
          _port('p1', order: 'a0', family: 'audio.spdif_coax', impedance: 75),
        );

      expect(validatePorts(body), isEmpty);
    });

    test('the rule follows the FAMILY, so it fires on a BNC too', () {
      // docs/06 §4.5 words this as "an RCA carrying spdif", but S/PDIF
      // coax is 75 ohm wherever it lands, and the seeded catalog's own
      // default connector for the family is `conn.rca75`.
      final body = _body()
        ..ports.add(
          _port('p1', order: 'a0', family: 'audio.spdif_coax')
            ..connector = const ConnectorTypeId('conn.bnc'),
        );

      expect(validatePorts(body), isNotEmpty);
    });
  });

  group('the IR pinout, which is the one about hardware', () {
    test('an IR port with no pinout is a WARNING, not a notice', () {
      final body = _body()
        ..ports.add(_port('p1', order: 'a0', family: 'ctl.ir_emitter'));

      final issue = validatePorts(body)['p1']!.single;

      expect(issue.severity, PortIssueSeverity.warning);
      expect(issue.column, PortColumnId.pinoutVariant);
      expect(issue.message, contains('destroys'));
    });

    test('both IR families are checked', () {
      for (final family in kIrFamilies) {
        final body = _body()
          ..ports.add(_port('p1', order: 'a0', family: family.v));
        expect(validatePorts(body), isNotEmpty, reason: family.v);
      }
    });

    test('a stated pinout is silent', () {
      final body = _body()
        ..ports.add(
          _port(
            'p1',
            order: 'a0',
            family: 'ctl.ir_emitter',
            pinout: 'tip = IR, sleeve = GND',
          ),
        );

      expect(validatePorts(body), isEmpty);
    });
  });

  group('what the gutter dot shows', () {
    test('a warning beats a notice on the same row', () {
      const issues = [
        PortIssue(
          severity: PortIssueSeverity.notice,
          column: null,
          message: 'a',
        ),
        PortIssue(
          severity: PortIssueSeverity.warning,
          column: null,
          message: 'b',
        ),
      ];

      expect(worstIssue(issues), PortIssueSeverity.warning);
    });

    test('nothing to say draws no dot at all', () {
      expect(worstIssue(null), isNull);
      expect(worstIssue(const []), isNull);
    });
  });

  group('none of it blocks anything', () {
    test('every message is plain English with no ruling id in it', () {
      // The gate M4-D earned the hard way, applied where these sentences
      // are written rather than where they are drawn.
      final citation = RegExp(r'\b(CR-\d|AC-\d|DR-\d|RJ-\d|G\d\b|§)');
      final body = _body()
        ..isPassthrough = true
        ..ports.addAll([
          _port('a', order: 'a0', designatorHint: 'J01'),
          _port('b', order: 'a1', designatorHint: 'J01'),
          _port('c', order: 'a2', family: 'audio.spdif_coax'),
          _port('d', order: 'a3', family: 'ctl.ir_emitter'),
        ]);

      final messages = [
        for (final list in validatePorts(body).values)
          for (final issue in list) issue.message,
      ];

      expect(messages, isNotEmpty);
      for (final message in messages) {
        expect(citation.hasMatch(message), isFalse, reason: message);
      }
    });
  });
}
