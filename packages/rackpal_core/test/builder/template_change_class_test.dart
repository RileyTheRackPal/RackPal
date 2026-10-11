// docs/06 §7.2 and CR-050: the change class a template edit falls into,
// computed from the diff and shown before save. Board #197, M4-C/2.
//
// These assert the ARTIFACT: the verdict and the reasons under it. None
// of them asserts how the diff is walked, because the diff is walked over
// the encoded body and the encoder is free to change shape as long as the
// same edits keep classifying the same way.
//
// The exhaustive field-by-field table is gated separately, by
// `template_change_class_coverage_test.dart`, which compares it against
// the codec's own encoders. What is asserted HERE is the reasoning: the
// examples docs/06 §7.2 names by hand, plus the four rules that had to be
// derived because the doc gives examples and not a specification.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _origin = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _port(
  String key, {
  String label = 'HDMI IN 01',
  String connector = 'conn.hdmi_a',
  String signalFamily = 'video.hdmi.2_0',
  PortDirection direction = PortDirection.sink,
  Face face = Face.rear,
  int maxConnections = 1,
  String order = 'a0',
  List<String> acceptedFamilies = const [],
  int? conductorCount,
  String? notes,
}) => PortDef(
  key: PortKey(key),
  label: label,
  connector: ConnectorTypeId(connector),
  signalFamily: SignalFamilyId(signalFamily),
  face: face,
  position: _origin,
  order: FracIndex(order),
  direction: direction,
  maxConnections: maxConnections,
  acceptedFamilies: [for (final f in acceptedFamilies) SignalFamilyId(f)],
  conductorCount: conductorCount,
  notes: notes,
);

TemplateBody _body({
  String displayName = 'HDMI Matrix 8x8',
  int frontU = 4,
  Len? bodyDepth,
  bool isPassthrough = false,
  int? typicalWatts,
  List<PortDef>? ports,
  List<BankDef>? banks,
}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'MTX-8',
  displayName: displayName,
  frontU: frontU,
  bodyDepth: bodyDepth,
  isPassthrough: isPassthrough,
  power: PowerProfile(typicalWatts: typicalWatts),
  ports: ports ?? [_port('hdmi-in-01')],
  banks: banks,
);

/// The single path a report should be blaming, so a test names its
/// subject rather than counting entries.
Matcher _blames(String path, TemplateChangeClass expected) =>
    predicate<TemplateChangeReport>(
      (r) =>
          r.changeClass == expected &&
          r.changes.length == 1 &&
          r.changes.single.path == path,
      'a ${expected.name} report blaming exactly "$path"',
    );

void main() {
  group('no edit at all', () {
    test('is unchanged, and reads as safe rather than as a fourth class', () {
      final report = classifyTemplateChange(_body(), _body());

      expect(report.isUnchanged, isTrue);
      expect(report.changes, isEmpty);
      expect(report.changeClass, TemplateChangeClass.safe);
    });
  });

  group("docs/06 §7.2's own named examples", () {
    test('a rename is safe', () {
      final report = classifyTemplateChange(
        _body(),
        _body(displayName: 'HDMI Matrix 8x8 (rev B)'),
      );

      expect(report, _blames('displayName', TemplateChangeClass.safe));
    });

    test('a port label change is safe', () {
      final report = classifyTemplateChange(
        _body(),
        _body(ports: [_port('hdmi-in-01', label: 'HDMI INPUT 1')]),
      );

      expect(
        report,
        _blames('ports[hdmi-in-01].label', TemplateChangeClass.safe),
      );
    });

    test('port reordering is safe', () {
      final report = classifyTemplateChange(
        _body(),
        _body(ports: [_port('hdmi-in-01', order: 'a5')]),
      );

      expect(
        report,
        _blames('ports[hdmi-in-01].order', TemplateChangeClass.safe),
      );
    });

    test('a wattage change is safe', () {
      final report = classifyTemplateChange(
        _body(typicalWatts: 40),
        _body(typicalWatts: 55),
      );

      expect(
        report,
        _blames('power.typicalWatts', TemplateChangeClass.safe),
      );
    });

    test('a new port is additive', () {
      final report = classifyTemplateChange(
        _body(),
        _body(
          ports: [
            _port('hdmi-in-01'),
            _port('hdmi-in-02', order: 'a1'),
          ],
        ),
      );

      expect(
        report,
        _blames('ports[hdmi-in-02]', TemplateChangeClass.additive),
      );
      expect(report.changes.single.kind, TemplateChangeKind.elementAdded);
    });

    test('a new bank is additive', () {
      final report = classifyTemplateChange(
        _body(),
        _body(
          banks: [
            BankDef(
              key: 'hdmi-in',
              label: 'HDMI Inputs',
              abbr: 'IN',
              order: const FracIndex('a0'),
            ),
          ],
        ),
      );

      expect(report, _blames('banks[hdmi-in]', TemplateChangeClass.additive));
    });

    test('a deleted port is breaking', () {
      final report = classifyTemplateChange(
        _body(
          ports: [
            _port('hdmi-in-01'),
            _port('hdmi-in-02', order: 'a1'),
          ],
        ),
        _body(),
      );

      expect(
        report,
        _blames('ports[hdmi-in-02]', TemplateChangeClass.breaking),
      );
      expect(report.changes.single.kind, TemplateChangeKind.elementRemoved);
    });

    test('a reversed direction is breaking', () {
      final report = classifyTemplateChange(
        _body(),
        _body(
          ports: [_port('hdmi-in-01', direction: PortDirection.source)],
        ),
      );

      expect(
        report,
        _blames('ports[hdmi-in-01].direction', TemplateChangeClass.breaking),
      );
    });

    test('a retyped connector is breaking', () {
      final report = classifyTemplateChange(
        _body(),
        _body(ports: [_port('hdmi-in-01', connector: 'conn.hdmi_d')]),
      );

      expect(
        report,
        _blames('ports[hdmi-in-01].connector', TemplateChangeClass.breaking),
      );
    });

    test('a toggled isPassthrough is breaking', () {
      final report = classifyTemplateChange(
        _body(),
        _body(isPassthrough: true),
      );

      expect(report, _blames('isPassthrough', TemplateChangeClass.breaking));
    });

    test('a changed frontU is breaking', () {
      final report = classifyTemplateChange(_body(), _body(frontU: 2));

      expect(report, _blames('frontU', TemplateChangeClass.breaking));
    });
  });

  group('the rules the doc gives examples for and does not state', () {
    test('a changed depth is SAFE though frontU is breaking, because depth '
        'moves nothing: it changes a number M5 raises a finding from, and '
        'a finding is not a migration', () {
      final report = classifyTemplateChange(
        _body(bodyDepth: const Len(330_000_000)),
        _body(bodyDepth: const Len(410_000_000)),
      );

      expect(report, _blames('bodyDepthNm', TemplateChangeClass.safe));
    });

    test('filling in a previously absent port fact is additive, whatever '
        'the field would cost to change', () {
      final report = classifyTemplateChange(
        _body(),
        _body(ports: [_port('hdmi-in-01', conductorCount: 19)]),
      );

      expect(
        report,
        _blames(
          'ports[hdmi-in-01].conductorCount',
          TemplateChangeClass.additive,
        ),
      );
      expect(report.changes.single.kind, TemplateChangeKind.filledIn);
    });

    test('clearing a fact is NOT additive: it reports as cleared, and takes '
        "the field's own class", () {
      final report = classifyTemplateChange(
        _body(ports: [_port('hdmi-in-01', notes: 'via the rear gland')]),
        _body(),
      );

      expect(
        report,
        _blames('ports[hdmi-in-01].notes', TemplateChangeClass.safe),
      );
      expect(report.changes.single.kind, TemplateChangeKind.cleared);
    });

    test('a list that only GREW is additive, because nothing that existed '
        'stopped existing', () {
      final report = classifyTemplateChange(
        _body(
          ports: [
            _port('hdmi-in-01', acceptedFamilies: ['video.hdmi.2_0']),
          ],
        ),
        _body(
          ports: [
            _port(
              'hdmi-in-01',
              acceptedFamilies: ['video.hdmi.2_0', 'video.hdmi.1_4'],
            ),
          ],
        ),
      );

      expect(
        report,
        _blames(
          'ports[hdmi-in-01].acceptedFamilies',
          TemplateChangeClass.additive,
        ),
      );
    });

    test('the same list SHRINKING is breaking, because a link relying on '
        'the entry that went can no longer be made', () {
      final report = classifyTemplateChange(
        _body(
          ports: [
            _port(
              'hdmi-in-01',
              acceptedFamilies: ['video.hdmi.2_0', 'video.hdmi.1_4'],
            ),
          ],
        ),
        _body(
          ports: [
            _port('hdmi-in-01', acceptedFamilies: ['video.hdmi.2_0']),
          ],
        ),
      );

      expect(
        report,
        _blames(
          'ports[hdmi-in-01].acceptedFamilies',
          TemplateChangeClass.breaking,
        ),
      );
    });

    test('raising maxConnections is additive and lowering it is breaking, '
        'by the same rule applied to a number', () {
      final raised = classifyTemplateChange(
        _body(),
        _body(ports: [_port('hdmi-in-01', maxConnections: 4)]),
      );
      final lowered = classifyTemplateChange(
        _body(ports: [_port('hdmi-in-01', maxConnections: 4)]),
        _body(),
      );

      expect(
        raised,
        _blames(
          'ports[hdmi-in-01].maxConnections',
          TemplateChangeClass.additive,
        ),
      );
      expect(
        lowered,
        _blames(
          'ports[hdmi-in-01].maxConnections',
          TemplateChangeClass.breaking,
        ),
      );
    });

    test('moving a port from the rear face to the front is breaking: the '
        'cable now lands somewhere else', () {
      final report = classifyTemplateChange(
        _body(),
        _body(ports: [_port('hdmi-in-01', face: Face.front)]),
      );

      expect(
        report,
        _blames('ports[hdmi-in-01].face', TemplateChangeClass.breaking),
      );
    });
  });

  group('the verdict over several changes', () {
    test('is the most severe one, and the safe edits are still reported', () {
      final report = classifyTemplateChange(
        _body(
          ports: [
            _port('hdmi-in-01'),
            _port('hdmi-in-02', order: 'a1'),
          ],
        ),
        _body(displayName: 'renamed', typicalWatts: 55),
      );

      expect(report.changeClass, TemplateChangeClass.breaking);
      expect(
        report.changes.map((c) => c.path),
        containsAll(<String>[
          'displayName',
          'power.typicalWatts',
          'ports[hdmi-in-02]',
        ]),
      );
    });

    test('names only the deciding changes when asked, so a UI can lead with '
        'what made it breaking rather than with what sorts first', () {
      final report = classifyTemplateChange(
        _body(
          ports: [
            _port('hdmi-in-01'),
            _port('hdmi-in-02', order: 'a1'),
          ],
        ),
        _body(displayName: 'renamed'),
      );

      expect(report.decidingChanges.map((c) => c.path), ['ports[hdmi-in-02]']);
    });

    test('is deterministic: the same pair of bodies gives the same list in '
        'the same order, every time', () {
      TemplateChangeReport run() => classifyTemplateChange(
        _body(
          ports: [
            _port('hdmi-in-01'),
            _port('hdmi-in-02', order: 'a1'),
          ],
        ),
        _body(
          displayName: 'renamed',
          frontU: 2,
          ports: [_port('hdmi-in-01', label: 'IN 1')],
        ),
      );

      final first = run().changes;
      final second = run().changes;

      expect(second, first);
      expect(
        first.map((c) => c.path).toList(),
        [
          'displayName',
          'frontU',
          'ports[hdmi-in-01].label',
          'ports[hdmi-in-02]',
        ],
        reason: 'sorted by path, which is unique within a report',
      );
    });
  });

  group('provenance', () {
    test('recording a fork is additive by the absent-fact rule, not '
        'breaking: nothing a downstream reader resolves is touched', () {
      final forked = _body()
        ..derivedFrom = const TemplateOrigin(
          templateId: TemplateId('cat.video.v04'),
          version: 1,
        );

      final report = classifyTemplateChange(_body(), forked);

      expect(report, _blames('derivedFrom', TemplateChangeClass.additive));
    });
  });
}
