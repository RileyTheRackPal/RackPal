// T0.01's blocks 2 to 6 (docs/08 §5.4, DR-208, M6-B3 `#319`, M6-B4
// `#320`).
//
// "WHAT THE SET PRINTS" IS ASSERTED IN BOTH DIRECTIONS: a mark or a border
// the set uses is on the sheet, and one it does not use is not. A test of
// only the first would pass a legend that printed everything.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

final Registries _seed = buildSeedRegistries();

DeviceInstance _device(String id, String template, LifecycleStatus status) =>
    DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(template),
        version: 1,
        contentHash: 'h',
      ),
      designator: id.toUpperCase(),
      name: id,
      placement: const RailPlacement(
        rackId: Uuid('rack'),
        ruIndex: 1,
        face: Face.front,
      ),
      meta: testMeta(),
      lifecycleStatus: status,
    );

TemplateSnapshot _snap(String id, TemplateBody body) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'h',
  body: body,
  capturedAt: DateTime.utc(2026, 9, 30),
);

List<String> _legendTexts({
  Iterable<DeviceInstance> devices = const [],
  Map<String, TemplateSnapshot> templates = const {},
  Iterable<PlanPinCarrier> carriers = const [],
}) {
  final built = buildLegendSheet(
    sheet: SheetSet.forRacks(<Rack>[testRack()]).sheets.first,
    info: fullProjectInfo(),
    settings: ProjectSettings(),
    revisions: const <RevisionEntry>[],
    fileName: 'legend.rppj',
    issuedAt: DateTime.utc(2026, 9, 30),
    measurer: FakeMeasurer(),
    registries: _seed,
    familiesInUse: const [],
    devices: devices,
    templates: templates,
    planCarriers: carriers,
  );
  expect(built.omittedBlocks, isEmpty, reason: 'every block fits');
  return textsOf(built.scene.ops);
}

final Map<String, TemplateSnapshot> _templates = {
  'AMP@1': _snap(
    'AMP',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'A',
      displayName: 'Amp',
      frontU: 2,
      glyph: DeviceGlyph.amplifier,
    ),
  ),
  'BLANK@1': _snap(
    'BLANK',
    TemplateBody(
      manufacturer: 'Demo',
      model: 'B',
      displayName: 'Blank',
      frontU: 1,
      category: kCatPassive,
    ),
  ),
};

void main() {
  group('symbols (M6-B3)', () {
    test(
      'A MARK THE SET USES IS EXPLAINED, and one it does not use is not',
      () {
        final texts = _legendTexts(
          devices: [_device('amp', 'AMP', LifecycleStatus.new_)],
          templates: _templates,
        );
        expect(texts, contains(deviceGlyphLabel(DeviceGlyph.amplifier)));
        expect(texts, isNot(contains(deviceGlyphLabel(DeviceGlyph.camera))));
      },
    );

    test('a device that prints on no elevation contributes no mark', () {
      final staged = DeviceInstance(
        id: const Uuid('amp'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('AMP'),
          version: 1,
          contentHash: 'h',
        ),
        designator: 'AMP-1',
        name: 'amp',
        placement: const StagedPlacement(),
        meta: testMeta(),
      );
      final texts = _legendTexts(devices: [staged], templates: _templates);
      expect(texts, isNot(contains(deviceGlyphLabel(DeviceGlyph.amplifier))));
    });

    test('the plan markers appear only when the set has a plan', () {
      expect(
        _legendTexts(),
        isNot(contains(planMarkerLabel(PlanPinCarrier.outlet))),
      );
      expect(
        _legendTexts(carriers: const [PlanPinCarrier.outlet]),
        contains(planMarkerLabel(PlanPinCarrier.outlet)),
      );
    });
  });

  group('conventions (M6-B3)', () {
    test('THE BORDERS THE SET DRAWS, and only those', () {
      final texts = _legendTexts(
        devices: [_device('amp', 'AMP', LifecycleStatus.existing)],
        templates: _templates,
      );
      expect(
        texts,
        contains('Border: ${lifecycleLabel(LifecycleStatus.existing)}'),
      );
      expect(
        texts,
        isNot(contains('Border: ${lifecycleLabel(LifecycleStatus.future)}')),
      );
    });

    test('the hatch is explained only when a passive is in the set', () {
      const hatch = 'Hatched: a blank, vent or shelf';
      expect(
        _legendTexts(
          devices: [_device('amp', 'AMP', LifecycleStatus.new_)],
          templates: _templates,
        ),
        isNot(contains(hatch)),
      );
      expect(
        _legendTexts(
          devices: [_device('blk', 'BLANK', LifecycleStatus.new_)],
          templates: _templates,
        ),
        contains(hatch),
      );
    });
  });

  group('the device block (M6-B3)', () {
    test('is drawn by the layer the elevation uses, labelled, and says it is '
        'an example', () {
      final texts = _legendTexts();
      expect(texts, contains(kAnatomyDesignator));
      expect(texts, contains(kAnatomySpan));
      expect(texts, contains('Designator, and its mark'));
      expect(
        texts,
        contains('An example block, not a device in this project.'),
      );
    });
  });

  group('identifiers (M6-B4)', () {
    test(
      'EVERY TOKEN THE GRAMMAR KNOWS has a meaning and an example value',
      () {
        expect(kIdTokenExamples.keys.toSet(), kIdFormatTokens);
      },
    );

    test('the active templates expand, with a line per token', () {
      final texts = _legendTexts();
      expect(texts, contains('W{SEQ:3}  →  W001'));
      expect(texts, contains('SEQ = 1, sequence number'));
    });
  });

  group('abbreviations and notes (M6-B4)', () {
    test(
      'the tag prefixes come from the registries, with the seeded notes',
      () {
        final texts = _legendTexts();
        final net = _seed.signalDomains.values.singleWhere(
          (d) => d.tagPrefix == 'NET',
        );
        expect(texts, contains('${net.displayName} (a tag prefix)'));
        expect(texts, containsAll(kLegendGeneralNotes));
      },
    );
  });
}
