// M1 roadmap checklist #6 — the seeded catalog (docs/09-roadmap.md ~line
// 232, docs/catalog/seed-devices.md §3.10, §7): 30 rack-side archetypes +
// 18 field devices = 48 shipped templates, the connector-footprint CI
// assertion (AC-050/A2.2), and the idformat/designator-allocation wiring
// docs/04-rack-editor.md §7 calls for on catalog placement.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// System prefixes no catalog `typePrefix` may collide with
/// (docs/catalog/seed-devices.md §7.2 C4, CR-043).
const _kSystemPrefixes = {'STR', 'RK', 'W', 'N', 'J'};

void main() {
  final catalog = buildSeedCatalog();
  final footprints = buildSeedConnectorFootprints();

  group('catalog shape (§3.10 summary table)', () {
    test('exactly 48 templates ship', () {
      expect(catalog, hasLength(48));
    });

    test('category counts match the §3.10 summary table exactly', () {
      final counts = <String, int>{};
      for (final body in catalog.values) {
        counts[body.category] = (counts[body.category] ?? 0) + 1;
      }
      expect(counts[kCatVideo], 7);
      expect(counts[kCatAudio], 6);
      expect(counts[kCatNetwork], 4);
      expect(counts[kCatControl], 3);
      expect(counts[kCatSources], 2);
      expect(counts[kCatRf], 2);
      expect(counts[kCatPower], 3);
      expect(counts[kCatPassive], 3);
      expect(counts[kCatField], 18);
      expect(counts.values.reduce((a, b) => a + b), 48);
    });

    test('rack-side ids are V/A/N/C/S/R/P/X-prefixed, field ids are F01-F18', () {
      final fieldIds = catalog.entries
          .where((e) => e.value.category == kCatField)
          .map((e) => e.key)
          .toSet();
      expect(fieldIds, {
        for (var i = 1; i <= 18; i++) 'F${i.toString().padLeft(2, '0')}',
      });
    });
  });

  group('provenance-adjacent invariants (docs/catalog/seed-devices.md §7.2)', () {
    test('every manufacturer is "Generic" — no real SKU ships (DR-002, P1)', () {
      for (final entry in catalog.entries) {
        expect(
          entry.value.manufacturer,
          'Generic',
          reason: '${entry.key} must not claim a real manufacturer',
        );
      }
    });

    test('no typePrefix collides with another template\'s or a system '
        'prefix (C4, CR-043)', () {
      final seen = <String, String>{};
      for (final entry in catalog.entries) {
        final prefix = entry.value.typePrefix;
        expect(prefix, isNotNull, reason: '${entry.key} has no typePrefix');
        expect(
          _kSystemPrefixes.contains(prefix),
          isFalse,
          reason: '${entry.key} typePrefix "$prefix" collides with a '
              'system prefix',
        );
        // Extender/endpoint role halves (TX/RX, ENC/DEC) and multi-model
        // families (SPK, AMP) legitimately share a prefix across ids —
        // that is the designator series a user actually wants (AMP-1,
        // AMP-2, …), so this only asserts against the *system* set above,
        // matching C4's own scope.
        seen[prefix!] = entry.key;
      }
    });

    test('every field device is frontU/rearU 0, side none, notInRack, no '
        'body depth (C14)', () {
      for (final entry in catalog.entries) {
        if (entry.value.category != kCatField) continue;
        final body = entry.value;
        expect(body.frontU, 0, reason: entry.key);
        expect(body.rearU, 0, reason: entry.key);
        expect(body.side, OccupancySide.none, reason: entry.key);
        expect(body.mountMethod, MountMethod.notInRack, reason: entry.key);
        expect(body.bodyDepth, isNull, reason: entry.key);
      }
    });

    test('every rack-side template declares a body depth and a weight', () {
      for (final entry in catalog.entries) {
        if (entry.value.category == kCatField) continue;
        expect(entry.value.bodyDepth, isNotNull, reason: entry.key);
        expect(entry.value.weight, isNotNull, reason: entry.key);
      }
    });

    test('every rackEars template heavier than 7 kg carries '
        'maxUnsupportedMass (feeds RCK-013, C12)', () {
      // COUNTED, and the count is asserted. This test previously passed
      // because the catalog stored every mass 1000x too small, so the
      // `weightKg > 7` gate below never fired once and the assertion inside
      // it had never run in the life of the suite. A gate with no proof it
      // fires is not a test.
      var overLimit = 0;
      for (final entry in catalog.entries) {
        final body = entry.value;
        if (body.mountMethod != MountMethod.rackEars) continue;
        final weightKg = (body.weight?.ug ?? 0) / 1e9;
        if (weightKg > 7) {
          overLimit++;
          expect(
            body.maxUnsupportedMass,
            isNotNull,
            reason: '${entry.key} at ${weightKg}kg needs maxUnsupportedMass '
                'for RCK-013 to have an object to fire on',
          );
        }
      }
      expect(
        overLimit,
        greaterThanOrEqualTo(8),
        reason: 'the >7 kg branch must actually execute — a catalog where '
            'nothing clears 7 kg means the mass scale is wrong again, not '
            'that the fleet got lighter',
      );
    });
  });

  // ── MASS SCALE ─────────────────────────────────────────────────────────
  //
  // `Mass` is int64 MICROGRAMS (CR-003): 1 kg = 1e9 µg. Nine catalog files
  // each carried `Mass((v * 1_000_000).round())` — the factor that is right
  // for the neighbouring `Len` millimetre helper and wrong by 1000x here —
  // so all 48 shipped templates stored GRAMS. Nothing caught it: the only
  // weight assertions in this file were `isNotNull`, and presence is exactly
  // what a scale error survives.
  //
  // Everything below therefore pins MAGNITUDE, and pins it against numbers a
  // human authored in the catalog source and in docs/catalog/seed-devices.md,
  // not against whatever the code currently computes.
  group('shipped weights are real kilograms, not grams (CR-003)', () {
    Mass weightOf(String id) {
      final body = catalog[id];
      expect(body, isNotNull, reason: '$id is not in the catalog');
      final weight = body!.weight;
      expect(weight, isNotNull, reason: '$id has no weight');
      return weight!;
    }

    test('P03 stores exactly the 41.7 kg its own description claims', () {
      // catalog_power.dart's P03 description reads "A 41.7 kg device
      // instantly blows a wall-rack rating". The stored integer must BE that
      // sentence's number, to the microgram.
      expect(weightOf('P03').ug, 41_700_000_000);
    });

    test('a human reads back the kilograms a human authored', () {
      // The full loop the chip strip walks: authored kg -> stored µg ->
      // `unit_formatter` -> the string on screen.
      expect(weightOf('P03').toKilograms(fractionDigits: 1), '41.7 kg');
      expect(weightOf('A01').toKilograms(fractionDigits: 1), '17.2 kg');
      expect(weightOf('X01').toKilograms(), '0.45 kg');
      final shelfCapacity = catalog['X03']!.containerWeightCapacity!;
      expect(shelfCapacity.toKilograms(), '22.70 kg');
      expect(weightOf('P03').toPounds(fractionDigits: 1), '91.9 lb');
    });

    test('the chip strip cannot render a stocked rack as 0 lb', () {
      // The exact failure this scale error produced: `RackMetricsRow`
      // formats pounds with `fractionDigits: 0`, so a 1000x-small catalog
      // printed a confident "0 lb" for a 0.45 kg blank panel AND for a
      // 17.2 kg amplifier. Neither may round to zero.
      for (final id in ['X01', 'A01', 'P03', 'N01']) {
        expect(
          weightOf(id).toPoundsValue(fractionDigits: 0),
          isNot('0'),
          reason: '$id renders as a measured zero in the weight chip',
        );
      }
    });

    test('no rack-side template weighs less than 50 g, and the heaviest is '
        'UPS-class', () {
      var heaviest = Mass.zero;
      for (final entry in catalog.entries) {
        if (entry.value.category == kCatField) continue;
        final ug = entry.value.weight!.ug;
        expect(
          ug,
          greaterThan(50 * 1000 * 1000), // 50 g
          reason: '${entry.key} weighs ${ug / 1e9} kg — nothing rack-mounted '
              'is that light; the kg->µg factor is wrong',
        );
        if (ug > heaviest.ug) heaviest = Mass(ug);
      }
      // §3.7 ships a 41.7 kg UPS as the fleet's heaviest item, and the whole
      // point of shipping it is that it "instantly blows a wall-rack rating".
      expect(heaviest.ug, inInclusiveRange(30_000_000_000, 60_000_000_000));
    });

    test('maxUnsupportedMass is the documented 7 kg and is genuinely '
        'exceeded (AC-028)', () {
      var exceeded = 0;
      for (final entry in catalog.entries) {
        final limit = entry.value.maxUnsupportedMass;
        if (limit == null) continue;
        expect(
          limit.ug,
          7_000_000_000,
          reason: '${entry.key}: docs/catalog/seed-devices.md §3 fixes the '
              'rackEars front-ear limit at 7 kg',
        );
        if (entry.value.weight!.ug > limit.ug) exceeded++;
      }
      expect(
        exceeded,
        greaterThan(0),
        reason: 'C12: RCK-013 needs at least one template that actually '
            'trips its own limit',
      );
    });

    test('Mass.fromKilograms is the only kg conversion and it is 1e9', () {
      expect(Mass.ugPerKilogram, 1_000_000_000);
      expect(Mass.fromKilograms(1).ug, 1_000_000_000);
      expect(Mass.fromKilograms(0.001).ug, 1_000_000);
      expect(Len.fromMillimetres(1).nm, 1_000_000);
    });

    test('every 3.5 mm IR port carries a cited pinoutVariant (C7, AC-052)', () {
      for (final entry in catalog.entries) {
        for (final port in entry.value.ports) {
          final isIr = port.signalFamily == const SignalFamilyId('ctl.ir_emitter') ||
              port.signalFamily == const SignalFamilyId('ctl.ir_receiver');
          if (!isIr) continue;
          expect(
            port.pinoutVariant,
            isNotNull,
            reason: '${entry.key}:${port.key.v} is an IR port with no '
                'pinoutVariant — the destructive-pinout hazard is uncaught',
          );
        }
      }
    });

    test('every audio.spdif_coax port is 75 ohm; every audio.aes3 port is '
        '110 ohm (C8)', () {
      for (final entry in catalog.entries) {
        for (final port in entry.value.ports) {
          if (port.signalFamily == const SignalFamilyId('audio.spdif_coax')) {
            expect(port.impedanceOhms, 75, reason: '${entry.key}:${port.key.v}');
          }
          if (port.signalFamily == const SignalFamilyId('audio.aes3')) {
            expect(port.impedanceOhms, 110, reason: '${entry.key}:${port.key.v}');
          }
        }
      }
    });

    test('every PortDef.key is unique within its template (C5)', () {
      for (final entry in catalog.entries) {
        final keys = entry.value.ports.map((p) => p.key.v).toList();
        expect(
          keys.toSet(),
          hasLength(keys.length),
          reason: '${entry.key} has a duplicate PortDef.key',
        );
      }
    });
  });

  group('connector-footprint CI assertion (AC-050/A2.2, docs/09-roadmap.md '
      'M1 checklist #6)', () {
    test('every connector referenced by a shipped template has a footprint '
        'entry, except the three connectors §5.1 states have none', () {
      final missing = <String>{};
      for (final entry in catalog.entries) {
        for (final port in entry.value.ports) {
          final id = port.connector.v;
          if (kFootprintExemptConnectors.contains(id)) continue;
          final def = footprints[port.connector];
          if (def == null ||
              def.footprintWidth == null ||
              def.footprintHeight == null) {
            missing.add('${entry.key}:${port.key.v} -> $id');
          }
        }
      }
      expect(
        missing,
        isEmpty,
        reason: 'Connectors referenced with no footprint entry: $missing',
      );
    });

    test('the exempt connectors RESOLVE but carry no footprint (so the '
        'assertion above is not vacuous)', () {
      // This used to assert `def == null` — "no ConnectorTypeDef at all".
      // That was coherent while this map was only a footprint table, and
      // it stopped being coherent when DR-010 wired the same function in
      // as `Registries.connectorTypes`: it then asserted that three
      // connectors named by 35 seeded ports and four signal families were
      // absent from the connector registry entirely. Resolving with null
      // dimensions is the strictly stronger non-vacuity guarantee — it
      // pins the footprint AND the entry.
      for (final id in kFootprintExemptConnectors) {
        final def = footprints[ConnectorTypeId(id)];
        expect(
          def,
          isNotNull,
          reason: '$id is referenced by shipped templates and must resolve '
              'in the connector registry',
        );
        expect(def!.footprintWidth, isNull, reason: '$id: §5.1 states none');
        expect(def.footprintHeight, isNull, reason: '$id: §5.1 states none');
        expect(def.displayName, isNotEmpty);
      }
    });

    test('every connector a shipped port names resolves in the registry', () {
      // The gap the footprint assertion above cannot see: it SKIPS the
      // exempt ids, so a port naming one that is not in the registry at
      // all passed both tests. That is exactly what happened.
      final unresolved = <String>{};
      for (final entry in catalog.entries) {
        for (final port in entry.value.ports) {
          if (!footprints.containsKey(port.connector)) {
            unresolved.add('${entry.key}:${port.key.v} -> ${port.connector.v}');
          }
        }
      }
      expect(unresolved, isEmpty, reason: 'unresolved connectors: $unresolved');
    });

    test('the exempt set is reachable — at least one shipped port actually '
        'uses one of them', () {
      final used = <String>{};
      for (final body in catalog.values) {
        for (final port in body.ports) {
          if (kFootprintExemptConnectors.contains(port.connector.v)) {
            used.add(port.connector.v);
          }
        }
      }
      expect(used, isNotEmpty);
    });
  });

  group('idformat wiring (docs/04-rack-editor.md §7)', () {
    final settings = ProjectSettings();

    test('allocates {TYPE_PREFIX}{SEP}{SEQ} starting at 1', () {
      final d1 = allocateDeviceDesignator(
        settings: settings,
        typePrefix: 'MTX',
        usedDesignators: {},
      );
      expect(d1, 'MTX-1');
    });

    test('finds the lowest unused positive integer, including gaps', () {
      final d = allocateDeviceDesignator(
        settings: settings,
        typePrefix: 'AMP',
        usedDesignators: {'AMP-1', 'AMP-3'},
      );
      expect(d, 'AMP-2');
    });

    test('is honest about a fully-occupied low range', () {
      final d = allocateDeviceDesignator(
        settings: settings,
        typePrefix: 'SW',
        usedDesignators: {'SW-1', 'SW-2', 'SW-3'},
      );
      expect(d, 'SW-4');
    });
  });

  group('catalog placement (docs/04 §3.2 the faster paths, §7)', () {
    final now = DateTime.utc(2026, 7, 18);
    Rack rack() => Rack(
      id: const Uuid('rk-1'),
      name: 'Test Rack',
      designator: 'RK-1',
      heightU: 12,
      order: const FracIndex('a0'),
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'test'),
    );
    RackDocument docWithCatalog(Rack r) {
      final doc = RackDocument(
        id: const Uuid('doc-1'),
        appVersion: '0.1.0',
        createdAt: now,
        modifiedAt: now,
        meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'test'),
      );
      doc.racks[r.id] = r;
      for (final entry in catalog.entries) {
        doc.templates[catalogTemplateKey(entry.key)] = TemplateSnapshot(
          templateId: TemplateId(entry.key),
          version: 1,
          contentHash: 'sha256:seed-${entry.key}',
          body: entry.value,
          capturedAt: now,
        );
      }
      return doc;
    }

    test('places a rack-mountable template at the lowest free U with an '
        'allocated designator', () {
      final r = rack();
      final doc = docWithCatalog(r);
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V02',
        targetRack: r,
        now: now,
        actor: 'tester',
      );
      expect(result, isA<CatalogPlacementReady>());
      final cmd = (result as CatalogPlacementReady).command;
      expect(cmd.designator, 'MTX-1');
      final placement = cmd.placement as RailPlacement;
      expect(placement.ruIndex, 1);
      expect(placement.face, Face.front);
    });

    test('a second placement of the same template skips the occupied U '
        'and bumps the designator', () {
      final r = rack();
      final doc = docWithCatalog(r);
      final controller = DocumentController(doc, clock: FixedClock(now));

      final first = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V02',
        targetRack: r,
        now: now,
        actor: 'tester',
      ) as CatalogPlacementReady;
      controller.run(first.command);

      final second = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V02',
        targetRack: r,
        now: now,
        actor: 'tester',
      ) as CatalogPlacementReady;
      expect(second.command.designator, 'MTX-2');
      final placement = second.command.placement as RailPlacement;
      // V02 is 1U front; the first instance occupies U1, so the second
      // lands at U2 — the lowest free slot, not a random one.
      expect(placement.ruIndex, 2);
    });

    test('a field device places off-rack, not onto the rack rails', () {
      final r = rack();
      final doc = docWithCatalog(r);
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'F01',
        targetRack: r,
        now: now,
        actor: 'tester',
      ) as CatalogPlacementReady;
      expect(result.command.placement, isA<OffRackPlacement>());
      expect(result.command.designator, 'DISP-1');
    });

    test('placing into a full rack fails honestly rather than silently '
        'overflowing', () {
      final r = Rack(
        id: const Uuid('rk-tiny'),
        name: 'Tiny',
        designator: 'RK-2',
        heightU: 1,
        order: const FracIndex('a0'),
        meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'test'),
      );
      final doc = docWithCatalog(r);
      final controller = DocumentController(doc, clock: FixedClock(now));
      // V03 needs 4U front; a 1U rack can never fit it.
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V03',
        targetRack: r,
        now: now,
        actor: 'tester',
      );
      expect(result, isA<CatalogPlacementFailed>());
      expect(doc.devices, isEmpty);
      expect(controller.undo.canUndo, isFalse);
    });

    // ── 0U-vertical never becomes a rail placement ────────────────────
    //
    // P01 is `frontU: 0, rearU: 0, side: zeroUVertical`. Both quick-add
    // paths used to resolve `deviceH = 0` and commit a `RailPlacement`
    // anyway, because every guard between here and the command is a
    // range check that a zero-height device passes vacuously. The device
    // was then never painted (`scene_builder.dart` skips `deviceH <= 0`),
    // so the app announced a successful placement for something invisible
    // and unclickable, on the face the user was not looking at.
    test('a 0U-vertical template is refused at an explicit caret, not '
        'silently rail-placed (AC-044)', () {
      final r = rack();
      final doc = docWithCatalog(r);
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'P01',
        targetRack: r,
        now: now,
        actor: 'tester',
        explicitRuIndex: 3,
      );
      expect(result, isA<CatalogPlacementFailed>());
      final reason = (result as CatalogPlacementFailed).reason;
      expect(reason, contains('0U occupant'));
      expect(reason, contains('AC-044'));
      // The refusal must not blame rack space for a missing feature.
      expect(reason, isNot(contains('free')));
      expect(doc.devices, isEmpty);
    });

    test('a 0U-vertical template is refused on the lowest-free-U path too, '
        'and does not blame rack space', () {
      final r = rack();
      final doc = docWithCatalog(r);
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'P01',
        targetRack: r,
        now: now,
        actor: 'tester',
      );
      expect(result, isA<CatalogPlacementFailed>());
      final reason = (result as CatalogPlacementFailed).reason;
      expect(reason, contains('0U occupant'));
      expect(reason, isNot(contains('No 0U free')));
    });

    test('every template this factory DOES rail-place occupies at least 1U '
        'on the face it lands on', () {
      // The general invariant behind the P01 case: a `RailPlacement` this
      // function emits must be a footprint `scene_builder` will actually
      // draw, for every one of the 48 shipped templates — not just the one
      // that was noticed.
      final r = Rack(
        id: const Uuid('rk-tall'),
        name: 'Tall',
        designator: 'RK-9',
        heightU: 45,
        order: const FracIndex('a0'),
        meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'test'),
      );
      var railPlaced = 0;
      for (final id in catalog.keys) {
        final doc = docWithCatalog(r);
        final result = buildPlaceFromCatalogCommand(
          doc: doc,
          catalogId: id,
          targetRack: r,
          now: now,
          actor: 'tester',
          explicitRuIndex: 1,
        );
        if (result is! CatalogPlacementReady) continue;
        final placement = result.command.placement;
        if (placement is! RailPlacement) continue;
        railPlaced++;
        final body = catalog[id]!;
        final h = placement.face == Face.front ? body.frontU : body.rearU;
        expect(
          h,
          greaterThan(0),
          reason: '$id was rail-placed on the ${placement.face.name} face '
              'where it occupies ${h}U — it would never be drawn',
        );
      }
      expect(railPlaced, greaterThan(20), reason: 'the loop must do work');
    });

    test('placement round-trips through undo (device count restored)', () {
      final r = rack();
      final doc = docWithCatalog(r);
      final controller = DocumentController(doc, clock: FixedClock(now));
      final ready = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'X01',
        targetRack: r,
        now: now,
        actor: 'tester',
      ) as CatalogPlacementReady;
      controller.run(ready.command);
      expect(doc.devices, hasLength(1));
      controller.undoLast();
      expect(doc.devices, isEmpty);
    });
  });
}
