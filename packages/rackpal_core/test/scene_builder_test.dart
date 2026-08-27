// Unit tests for the M1 rack scene builders (draw/scene/*). Pure Dart, no
// Flutter: they exercise the RU-index → diagram-space geometry, device
// stacking/ordering, the front/rear filter, and the CR-086 fragment
// wiring, which is exactly the math the task brief says must be tested
// here without hardware or a real canvas.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

// ── a deterministic fake measurer (no TTF needed for geometry tests) ──────
final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) {
    // ~0.55em advance per char — enough to exercise the block-LOD fit check.
    final w = text.length * style.sizePt * 0.55;
    return TextMetrics(
      advanceWidth: w,
      ascent: style.sizePt * 0.75,
      descent: style.sizePt * 0.25,
      capHeight: style.sizePt * 0.7,
      xHeight: style.sizePt * 0.5,
      lineHeight: style.sizePt * 1.2,
    );
  }
}

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

Rack _rack({
  int heightU = 12,
  RuNumbering numbering = RuNumbering.bottomUpFromOne,
}) => Rack(
  id: const Uuid('rack-1'),
  name: 'Media Closet',
  designator: 'RK-1',
  heightU: heightU,
  order: const FracIndex('a0'),
  meta: _meta(),
  ruNumbering: numbering,
);

TemplateSnapshot _snapshot(
  String id, {
  required int frontU,
  int rearU = 0,
  String displayName = 'Generic device',
}) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'sha256:$id',
  capturedAt: DateTime.utc(2026),
  body: TemplateBody(
    manufacturer: 'ACME',
    model: id,
    displayName: displayName,
    frontU: frontU,
    rearU: rearU,
    side: rearU > 0 ? OccupancySide.both : OccupancySide.front,
  ),
);

DeviceInstance _device(
  String id, {
  required String designator,
  required String name,
  required String templateId,
  required int ruIndex,
  Face face = Face.front,
  int startTwelfth = 0,
  int spanTwelfths = 12,
}) => DeviceInstance(
  id: Uuid(id),
  kind: DeviceKind.rackDevice,
  templateRef: TemplateRef(
    templateId: TemplateId(templateId),
    version: 1,
    contentHash: 'sha256:$templateId',
  ),
  designator: designator,
  name: name,
  placement: RailPlacement(
    rackId: const Uuid('rack-1'),
    ruIndex: ruIndex,
    face: face,
    startTwelfth: startTwelfth,
    spanTwelfths: spanTwelfths,
  ),
  meta: _meta(),
);

void main() {
  final measurer = _FakeMeasurer();

  group('RackGeometry — RU index → diagram-space Y (CR-006, CR-025)', () {
    const geo = RackGeometry(12);

    test('the scene scale ties RU height to kRackUnit with no drift', () {
      // The whole "derive it, do not hardcode a second constant" guarantee:
      // one U of physical length converts to exactly unitsPerRu.
      expect(
        RackGeometry.unitsForLen(kRackUnit),
        closeTo(RackGeometry.unitsPerRu, 1e-9),
      );
      // …and N U's convert to N × unitsPerRu.
      expect(
        RackGeometry.unitsForLen(kRackUnit * 3),
        closeTo(3 * RackGeometry.unitsPerRu, 1e-9),
      );
    });

    test('U1 sits at the bottom, U[heightU] at the top (bottom origin)', () {
      // Top boundary of the topmost U is the rack top (y = 0).
      expect(geo.yTopOfU(12), 0);
      // Bottom boundary of U1 is the rack bottom (y = rackHeight).
      expect(geo.yBottomOfU(1), closeTo(geo.rackHeight, 1e-9));
      // Each U is exactly one unitsPerRu tall.
      expect(
        geo.yBottomOfU(5) - geo.yTopOfU(5),
        closeTo(RackGeometry.unitsPerRu, 1e-9),
      );
      // A higher ruIndex is drawn ABOVE (smaller Y) a lower one.
      expect(geo.yTopOfU(6), lessThan(geo.yTopOfU(3)));
    });

    test('a multi-U device rect spans its full U range at the right place', () {
      // A 2U device with its lowest U at ruIndex 3 occupies U3..U4.
      final rect = geo.deviceRect(3, 2);
      expect(rect.height, closeTo(2 * RackGeometry.unitsPerRu, 1e-9));
      // Top edge = top of U4; bottom edge = bottom of U3.
      expect(rect.top, closeTo(geo.yTopOfU(4), 1e-9));
      expect(rect.bottom, closeTo(geo.yBottomOfU(3), 1e-9));
      // Full-width device fills the clear opening.
      expect(rect.left, closeTo(geo.openingLeft, 1e-9));
      expect(rect.width, closeTo(RackGeometry.openingWidth, 1e-9));
    });

    test('lateral twelfths place a half-width device on the correct side', () {
      final left = geo.deviceRect(1, 1, spanTwelfths: 6);
      final right = geo.deviceRect(1, 1, startTwelfth: 6, spanTwelfths: 6);
      expect(left.width, closeTo(RackGeometry.openingWidth / 2, 1e-9));
      expect(
        right.left,
        closeTo(geo.openingLeft + RackGeometry.openingWidth / 2, 1e-9),
      );
      expect(left.right, closeTo(right.left, 1e-6));
    });
  });

  group('LodLevel.forScale — the docs/04 §2.1 thresholds', () {
    test('maps each zoom band to its tier', () {
      expect(LodLevel.forScale(0.2), LodLevel.block);
      expect(LodLevel.forScale(0.5), LodLevel.badge);
      expect(LodLevel.forScale(1), LodLevel.full);
      expect(LodLevel.forScale(2), LodLevel.detail);
      // boundaries are inclusive-low on the higher tier.
      expect(LodLevel.forScale(0.40), LodLevel.badge);
      expect(LodLevel.forScale(0.75), LodLevel.full);
      expect(LodLevel.forScale(1.50), LodLevel.detail);
    });
  });

  group('buildRackScene — composition, fragments and stacking (CR-086)', () {
    final templates = {
      'amp@1': _snapshot('amp', frontU: 2, displayName: '16-channel amplifier'),
      'sw@1': _snapshot('sw', frontU: 1, displayName: '24-port PoE switch'),
      'ups@1': _snapshot('ups', frontU: 2, displayName: 'Rack UPS'),
    };
    final devices = [
      _device(
        'dev-ups',
        designator: 'UPS-1',
        name: 'Main UPS',
        templateId: 'ups',
        ruIndex: 1,
      ),
      _device(
        'dev-amp',
        designator: 'AMP-1',
        name: 'LR Amp',
        templateId: 'amp',
        ruIndex: 4,
      ),
      _device(
        'dev-sw',
        designator: 'SW-1',
        name: 'Core Switch',
        templateId: 'sw',
        ruIndex: 7,
      ),
    ];

    test('registers a fragment for the chassis and every device', () {
      final result = buildRackScene(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      final frags = result.scene.fragments;
      expect(
        frags.keys,
        containsAll(<String>['rack-1', 'dev-ups', 'dev-amp', 'dev-sw']),
      );
      expect(result.devices, hasLength(3));

      // Every registered fragment slices cleanly (fragmentFor does not throw)
      // and the device fragments are non-empty.
      for (final id in frags.keys) {
        expect(result.scene.fragmentFor(id).ops, isNotEmpty);
      }
    });

    test('devices are emitted bottom-to-top by ruIndex, deterministically', () {
      final result = buildRackScene(
        rack: _rack(),
        devices: devices.reversed.toList(), // input order must not matter
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      expect(
        result.devices.map((d) => d.deviceId.v).toList(),
        ['dev-ups', 'dev-amp', 'dev-sw'],
      );
      // Their rects stack upward: UPS (U1-2) below AMP (U4-5) below SW (U7).
      final ys = result.devices.map((d) => d.rect.top).toList();
      expect(ys[0], greaterThan(ys[1]));
      expect(ys[1], greaterThan(ys[2]));
    });

    test(
      'device fragment ops are LOCAL (start at the origin, not absolute)',
      () {
        final result = buildRackScene(
          rack: _rack(),
          devices: devices,
          templates: templates,
          face: Face.front,
          lod: LodLevel.full,
          measurer: measurer,
        );
        // The AMP body is the first op of its fragment; a local body rect
        // begins at (0,0) regardless of the device's absolute rack position.
        final frag = result.scene.fragmentFor('dev-amp');
        final body = frag.ops.first;
        expect(body, isA<OpRoundRect>());
        final rr = body as OpRoundRect;
        expect(rr.r.left, 0);
        expect(rr.r.top, 0);
        // But its layout rect IS absolute and offset down/right into the rack.
        final layout = result.devices.firstWhere(
          (d) => d.deviceId.v == 'dev-amp',
        );
        expect(layout.rect.left, greaterThan(0));
        expect(layout.rect.top, greaterThan(0));
      },
    );

    test('whole-scene ops wrap each device in save/translate/restore', () {
      final result = buildRackScene(
        rack: _rack(),
        devices: [devices.first],
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      final ops = result.scene.ops;
      // Somewhere after the chassis there is a save then a translate op.
      final saveIdx = ops.indexWhere((o) => o is OpSave);
      expect(saveIdx, greaterThanOrEqualTo(0));
      expect(ops[saveIdx + 1], isA<OpTransform>());
      expect(ops.last, isA<OpRestore>());
    });

    test('hit regions are ABSOLUTE and match each device layout rect', () {
      final result = buildRackScene(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      expect(result.scene.hits, hasLength(3));
      for (final layout in result.devices) {
        final hit = result.scene.hits.firstWhere(
          (h) => h.entityId == layout.deviceId.v,
        );
        expect(hit.bounds, layout.rect);
      }
    });

    test('semantic label combines designator, name and type', () {
      final result = buildRackScene(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      final amp = result.devices.firstWhere((d) => d.deviceId.v == 'dev-amp');
      expect(amp.semanticLabel, 'AMP-1 — LR Amp, 16-channel amplifier');
    });

    test('scene.bounds is the INK extent, not the union of layout rects — '
        'it is what drives PDF scale-to-fit', () {
      final result = buildRackScene(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      final bounds = result.scene.bounds;
      final chassis = result.chassisBounds;

      // The enclosure frame is a 1.2pt stroke ON the chassis edge, so half
      // of it lands outside — a `bounds` that stopped at the layout rect
      // would clip it at the page margin.
      expect(bounds.top, closeTo(-0.6, 1e-9));
      expect(bounds.right, closeTo(chassis.right + 0.6, 1e-9));
      expect(bounds.bottom, closeTo(chassis.bottom + 0.6, 1e-9));

      // …and it still CONTAINS every device rect and the chassis, so the
      // ink pass only ever grew the box.
      expect(bounds.left, lessThanOrEqualTo(chassis.left));
      for (final d in result.devices) {
        expect(bounds.union(d.rect), bounds, reason: d.deviceId.v);
      }
    });

    test('bounds grows to hold a fragment that draws outside its own rect', () {
      // The property `symbol_layer` depends on, exercised through the one
      // scene builder that exists: a layer's ink is unioned in AFTER being
      // shifted by that fragment's translate, so ink that overhangs the
      // layout rect is inside `bounds` wherever the fragment sits.
      final result = buildRackScene(
        rack: _rack(),
        devices: devices,
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      for (final d in result.devices) {
        final ink = inkBoundsOf(
          result.scene.fragmentFor(d.deviceId.v).ops,
          measurer: measurer,
        )!.shift(d.rect.left, d.rect.top);
        expect(
          result.scene.bounds.union(ink),
          result.scene.bounds,
          reason: "${d.deviceId.v}'s ink escaped scene.bounds",
        );
      }
    });
  });

  // ====================================================================
  // OCCUPANCY DECIDES THE FACE, NOT THE MOUNT (docs/04 §2.2, CR-036)
  // ====================================================================
  // docs/04 §2.2: the face control "selects a coordinate, not a filter...
  // a 2U patch panel with {frontU: 2, rearU: 2} renders on both faces and
  // a rear lace bar renders only on rear."
  //
  // There used to be a `placement.face != face` line in `_visibleDevices`
  // as well, and it is why every shipped starter's T2.02 was an empty
  // frame: `whole_house` RK-1 mounts all 27 rail devices on the FRONT
  // rails and 19 of them have `rearU > 0`, so the rear elevation drew
  // nothing at all while its own summary band claimed 27 of 31 were on it.
  group('buildRackScene — the occupancy struct decides each face', () {
    final templates = {
      'amp@1': _snapshot('amp', frontU: 2, displayName: 'Amplifier'),
      'pp@1': _snapshot('pp', frontU: 0, rearU: 1, displayName: 'Patch panel'),
    };
    final devices = [
      _device(
        'dev-amp',
        designator: 'AMP-1',
        name: 'Amp',
        templateId: 'amp',
        ruIndex: 3,
      ),
      _device(
        'dev-pp',
        designator: 'PP-1',
        name: 'Patch',
        templateId: 'pp',
        ruIndex: 6,
        face: Face.rear,
      ),
    ];

    List<String> drawnOn(
      Face face, {
      List<DeviceInstance>? on,
      Map<String, TemplateSnapshot>? from,
    }) => buildRackScene(
      rack: _rack(),
      devices: on ?? devices,
      templates: from ?? templates,
      face: face,
      lod: LodLevel.full,
      measurer: measurer,
    ).devices.map((d) => d.deviceId.v).toList();

    test('front view shows what occupies FRONT U', () {
      expect(drawnOn(Face.front), ['dev-amp']);
    });

    test('rear view shows what occupies REAR U', () {
      expect(drawnOn(Face.rear), ['dev-pp']);
    });

    test('a device with 0U on the requested face is skipped', () {
      // Front-only occupancy, so no rear elevation draws it — whichever
      // rails it happens to be bolted to.
      final zeroRear = {
        'x@1': _snapshot('x', frontU: 1, displayName: 'Front-only'),
      };
      final rearMounted = [
        _device(
          'dev-x',
          designator: 'X-1',
          name: 'X',
          templateId: 'x',
          ruIndex: 2,
          face: Face.rear,
        ),
      ];
      expect(drawnOn(Face.rear, on: rearMounted, from: zeroRear), isEmpty);
      expect(drawnOn(Face.front, on: rearMounted, from: zeroRear), ['dev-x']);
    });

    test('a FRONT-MOUNTED device with rear occupancy reaches the REAR '
        'elevation', () {
      // THE SHIPPED DEFECT, in one fixture. `{frontU: 3, rearU: 3,
      // side: both}` on the front rails is a UPS, a matrix, an amplifier
      // — a technician standing behind the rack sees and reaches it.
      final both = {
        'ups@1': _snapshot('ups', frontU: 3, rearU: 3, displayName: 'UPS'),
      };
      final frontMounted = [
        _device(
          'dev-ups',
          designator: 'UPS-1',
          name: 'Head-end UPS',
          templateId: 'ups',
          ruIndex: 1,
        ),
      ];

      expect(drawnOn(Face.front, on: frontMounted, from: both), ['dev-ups']);
      expect(drawnOn(Face.rear, on: frontMounted, from: both), ['dev-ups']);
    });

    test('the two faces use each face OWN U-height, off one ruIndex', () {
      // A deep chassis with a shallow front panel: the model carries one
      // `ruIndex` per rail placement and two heights, so the rear block is
      // bottom-anchored at the same U and taller.
      final deep = {
        'deep@1': _snapshot('deep', frontU: 1, rearU: 3, displayName: 'Deep'),
      };
      final device = [
        _device(
          'dev-deep',
          designator: 'D-1',
          name: 'Deep',
          templateId: 'deep',
          ruIndex: 4,
        ),
      ];
      DBox rectOn(Face face) => buildRackScene(
        rack: _rack(),
        devices: device,
        templates: deep,
        face: face,
        lod: LodLevel.full,
        measurer: measurer,
      ).devices.single.rect;

      const geo = RackGeometry(12);
      expect(rectOn(Face.front).height, closeTo(RackGeometry.unitsPerRu, 1e-9));
      expect(
        rectOn(Face.rear).height,
        closeTo(3 * RackGeometry.unitsPerRu, 1e-9),
      );
      // Both rest on U4's bottom edge.
      expect(rectOn(Face.front).bottom, closeTo(geo.yBottomOfU(4), 1e-9));
      expect(rectOn(Face.rear).bottom, closeTo(geo.yBottomOfU(4), 1e-9));
    });
  });

  // ====================================================================
  // forPrint TAKES THE RECEIVER, AND THAT IS PINNED TWO WAYS
  // ====================================================================
  // `forPrint` forces all seven of today's fields, so no behavioural test
  // can distinguish `copyWith(...)` from `const RackSceneOptions()
  // .copyWith(...)` — reverting the fix left every suite green. The
  // regression it was written against is a field ADDED later and silently
  // discarded, so it is guarded where that regression is visible: the
  // completeness of `copyWith` (below) plus the source-level assertion in
  // `scene_options_source_test.dart` that `forPrint` delegates to it on
  // `this`.
  group('RackSceneOptions', () {
    const custom = RackSceneOptions(
      dualRuler: true,
      showRuSpan: true,
      lifecycleBorders: true,
      hatchPassive: true,
      loadGutter: true,
      units: UnitSystem.metric,
      typeScale: RackTypeScale(2),
    );

    test('copyWith carries EVERY field — the property forPrint stands on', () {
      // Every field non-default, so a field that `copyWith` forgets comes
      // back as its default and fails here.
      expect(custom.copyWith(), custom);
      expect(custom.copyWith(), isNot(RackSceneOptions.screen));
    });

    test('every field is reachable through copyWith, one at a time', () {
      // Guards the other direction: a `copyWith` parameter that is
      // accepted and then dropped.
      const screen = RackSceneOptions.screen;
      expect(screen.copyWith(dualRuler: true).dualRuler, isTrue);
      expect(screen.copyWith(showRuSpan: true).showRuSpan, isTrue);
      expect(screen.copyWith(lifecycleBorders: true).lifecycleBorders, isTrue);
      expect(screen.copyWith(hatchPassive: true).hatchPassive, isTrue);
      expect(screen.copyWith(loadGutter: true).loadGutter, isTrue);
      expect(
        screen.copyWith(units: UnitSystem.metric).units,
        UnitSystem.metric,
      );
      expect(
        screen.copyWith(typeScale: const RackTypeScale(2)).typeScale.factor,
        2,
      );
    });

    test('forPrint forces the five treatment flags AND the two arguments', () {
      final printed = RackSceneOptions.screen.forPrint(
        typeScale: const RackTypeScale(3),
        units: UnitSystem.metric,
      );
      expect(printed.dualRuler, isTrue);
      expect(printed.showRuSpan, isTrue);
      expect(printed.lifecycleBorders, isTrue);
      expect(printed.hatchPassive, isTrue);
      expect(printed.loadGutter, isTrue);
      expect(printed.units, UnitSystem.metric);
      expect(printed.typeScale.factor, 3);
    });
  });

  group('buildRackScene — LOD gating', () {
    final templates = {
      'amp@1': _snapshot('amp', frontU: 2, displayName: 'Amplifier'),
    };
    final device = _device(
      'dev-amp',
      designator: 'AMP-1',
      name: 'Amp',
      templateId: 'amp',
      ruIndex: 3,
    );

    test('block LOD draws a plain rect body; full LOD rounds it', () {
      final block = buildRackScene(
        rack: _rack(),
        devices: [device],
        templates: templates,
        face: Face.front,
        lod: LodLevel.block,
        measurer: measurer,
      );
      final full = buildRackScene(
        rack: _rack(),
        devices: [device],
        templates: templates,
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      expect(block.scene.fragmentFor('dev-amp').ops.first, isA<OpRect>());
      expect(full.scene.fragmentFor('dev-amp').ops.first, isA<OpRoundRect>());
    });

    test(
      'full LOD emits designator + name + type; block emits fewer texts',
      () {
        final block = buildRackScene(
          rack: _rack(),
          devices: [device],
          templates: templates,
          face: Face.front,
          lod: LodLevel.block,
          measurer: measurer,
        );
        final full = buildRackScene(
          rack: _rack(),
          devices: [device],
          templates: templates,
          face: Face.front,
          lod: LodLevel.full,
          measurer: measurer,
        );
        int textCount(DiagramScene s, String id) =>
            s.fragmentFor(id).ops.whereType<OpText>().length;
        // full: designator + badge + name + type = 4 text ops on a 2U body.
        expect(textCount(full.scene, 'dev-amp'), 4);
        // block: at most the single centred designator.
        expect(
          textCount(block.scene, 'dev-amp'),
          lessThan(textCount(full.scene, 'dev-amp')),
        );
      },
    );
  });

  group('buildRackLayer — the RU ruler', () {
    test('emits one figure per U at full LOD, bolder every 5th', () {
      final result = buildRackScene(
        rack: _rack(),
        devices: const [],
        templates: const {},
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      final labels = result.scene
          .fragmentFor('rack-1')
          .ops
          .whereType<OpText>()
          .toList();
      expect(labels, hasLength(12));
      // The figures 1..12 are all present.
      expect(
        labels.map((t) => t.text).toSet(),
        {for (var i = 1; i <= 12; i++) '$i'},
      );
    });

    test('top-down numbering flips the DISPLAYED figure, not the geometry', () {
      final result = buildRackScene(
        rack: _rack(numbering: RuNumbering.topDown),
        devices: const [],
        templates: const {},
        face: Face.front,
        lod: LodLevel.full,
        measurer: measurer,
      );
      final labels =
          result.scene.fragmentFor('rack-1').ops.whereType<OpText>().toList()
            // The label nearest the TOP of the rack (smallest Y) reads "1"
            // under top-down numbering, though it sits at the highest ruIndex.
            ..sort((a, b) => a.at.y.compareTo(b.at.y));
      expect(labels.first.text, '1');
      expect(labels.last.text, '12');
    });
  });

  group('RackSceneOptions.forPrint USES its receiver', () {
    // It built a fresh value from literals and ignored `this` entirely,
    // so `RackSceneOptions.screen.forPrint(…)` advertised "take these
    // options and add print" while discarding them. `screen` is
    // all-defaults, so nothing was wrong on paper — and any field added
    // to the class after today, or any per-rack override written as
    // `myOptions.forPrint(…)`, would have been silently dropped.

    test('the print treatment is applied', () {
      final print = RackSceneOptions.screen.forPrint(
        typeScale: const RackTypeScale.identity(),
        units: UnitSystem.metric,
      );

      expect(print.dualRuler, isTrue);
      expect(print.showRuSpan, isTrue);
      expect(print.lifecycleBorders, isTrue);
      expect(print.hatchPassive, isTrue);
      expect(print.loadGutter, isTrue);
      expect(print.units, UnitSystem.metric);
    });

    test('a field the treatment does NOT own survives the call', () {
      // `units` is the observable stand-in for "everything the receiver
      // carries": set it on the receiver, ask for print WITHOUT naming
      // it... except `forPrint` requires it. So the property is checked
      // through `copyWith`, which is the mechanism `forPrint` now goes
      // through and the one a future field would ride on.
      final custom = RackSceneOptions.screen.copyWith(
        units: UnitSystem.metric,
        typeScale: const RackTypeScale.identity(),
      );

      expect(custom.copyWith(loadGutter: true).units, UnitSystem.metric);
      expect(custom.copyWith(dualRuler: true).units, UnitSystem.metric);
    });

    test('copyWith replaces ONLY what it is given', () {
      const base = RackSceneOptions(
        dualRuler: true,
        showRuSpan: true,
        units: UnitSystem.metric,
      );
      final one = base.copyWith(loadGutter: true);

      expect(one.loadGutter, isTrue);
      expect(one.dualRuler, isTrue);
      expect(one.showRuSpan, isTrue);
      expect(one.units, UnitSystem.metric);
      expect(one.hatchPassive, isFalse);
      expect(one.lifecycleBorders, isFalse);
    });
  });
}
