// M5-D `#812` — P4's `role` parameter, and the receiver `SIG-001`'s remedy
// needs to exist before it can insert one.
//
// THE ASSERTIONS ARE AGAINST THE SPEC, NOT AGAINST THE CODE THAT READS IT.
// docs/catalog/seed-devices.md §540 and §575 list both halves port by port,
// so these tests name those ports rather than reading them back out of the
// body under test — which would prove only that a map equals itself.
//
// AND THE FIRST THING ASSERTED IS THE THING P4 REJECTS. A role variant that
// leaked into `buildSeedCatalog()` would be the "separate TX and RX
// templates" the corpus refused by name, and it would be invisible except
// as a count moving in a different file.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = buildSeedCatalog();
  final variants = buildSeedRoleVariants();

  /// The port keys of [body], in declared order.
  List<String> keysOf(TemplateBody body) => [
    for (final p in body.ports) p.key.v,
  ];

  group('a variant is not a template (P4, §540)', () {
    test('the seed catalog still ships one body per id, and 48 of them', () {
      // P4's rejected alternative is *"four separate templates, which
      // spends four of thirty rack-side slots on two products"*, and §540
      // repeats it for V06: *"Rejected alternative: separate TX and RX
      // templates."* If a variant ever reaches this map, that ruling has
      // been reversed by accident rather than by amendment.
      expect(catalog, hasLength(48));
      for (final id in variants.keys) {
        expect(
          catalog.containsKey(id),
          isFalse,
          reason: '$id is a DERIVED half and must not be a catalog entry',
        );
      }
    });

    test('every variant id names a base that ships, and a role it offers', () {
      // The other direction: a variant keyed to nothing is a body nothing
      // can reach, which is worse than an absent one because it looks
      // present.
      expect(variants, isNotEmpty);
      for (final id in variants.keys) {
        final base = id.split(':').first;
        final roleName = id.split(':').last;
        expect(catalog.containsKey(base), isTrue, reason: '$id has no base');
        final role = TemplateRole.values.firstWhere((r) => r.name == roleName);
        expect(
          rolesFor(base),
          contains(role),
          reason: '$base does not offer ${role.name}',
        );
      }
    });

    test(
      'P4 says the parameter is used EXACTLY TWICE, so two ids carry it',
      () {
        // A count with a source. P4: *"The `role` parameter is used exactly
        // twice (V06, V07)."* Derived from the catalog rather than typed, so
        // a third use fails here instead of quietly contradicting the doc.
        final parametric = [
          for (final id in catalog.keys)
            if (rolesFor(id).isNotEmpty) id,
        ];
        expect(parametric, ['V06', 'V07']);
        expect(variants, hasLength(2));
      },
    );
  });

  group("V06's receiver, port for port (§540)", () {
    final rx = variants['V06:receiver']!;

    test('six ports, in the order the spec lists them', () {
      // §540's receiver block, transcribed:
      //   HDBT IN · HDMI OUT · IR IN · IR OUT · RS-232 · 12V DC IN (opt)
      expect(keysOf(rx), [
        'hdbt.in',
        'hdmi.out',
        'ir.in',
        'ir.out',
        'rs232',
        'dc.in',
      ]);
    });

    test(
      'it is a SINK on video.hdbaset, which is what makes it insertable',
      () {
        // The whole reason this body exists. `SIG-001` fires on an HDBaseT
        // source landing on a terminating `net.ethernet` port, and the
        // remedy inserts something that ACCEPTS the HDBaseT run — so the
        // receiver's first port must be a sink on that family, or the
        // remedy would insert a device the cable still cannot reach.
        final hdbt = rx.ports.firstWhere((p) => p.key.v == 'hdbt.in');
        expect(hdbt.signalFamily.v, 'video.hdbaset');
        expect(hdbt.direction, PortDirection.sink);
        expect(hdbt.connector.v, 'conn.rj45');
      },
    );

    test('and a source on HDMI, so the run can continue past it', () {
      final out = rx.ports.firstWhere((p) => p.key.v == 'hdmi.out');
      expect(out.signalFamily.v, 'video.hdmi.2_0');
      expect(out.direction, PortDirection.source);
    });

    test('the transmitter is NOT a sink on hdbaset — the halves differ', () {
      // The premise the test above depends on, asserted rather than
      // assumed: if V06's shipped half already took an HDBaseT run, the
      // variant would be unnecessary and this whole file would be
      // elaborate scaffolding around a duplicate.
      final tx = catalog['V06']!;
      expect(
        tx.ports.where(
          (p) =>
              p.signalFamily.v == 'video.hdbaset' &&
              p.direction == PortDirection.sink,
        ),
        isEmpty,
      );
    });

    test('0 W is MEASURED ZERO, not unknown (G4/CR-114, §540)', () {
      // §540: *"The receiver draws 0 W from the rack and its
      // `outletsConsumed` is 0 — its power comes down the `net.poh`
      // conductor."* Absent would put this device in the power rollup's
      // UNKNOWN column, which is the opposite of what is true about it.
      expect(rx.power.typicalWatts, 0);
      expect(rx.power.nameplateWatts, 0);
      expect(rx.power.outletsConsumed, 0);
    });

    test(
      'PoH is a role with NO standard, because PoeStandard is IEEE-only',
      () {
        // §540's `[poh:pd]`, §367's mapping to a `PoeSpec`, and G4 for the
        // rest. `PoeStandard` is `{af, at, btType3, btType4}`; docs/01:470
        // says PoH *"is based on 802.3at but modified, and is NOT
        // interoperable with a standard PoE PSE"*. Naming one of those four
        // would be a false standard on a safety-adjacent field.
        final hdbt = rx.ports.firstWhere((p) => p.key.v == 'hdbt.in');
        expect(hdbt.poe?.role, PoeRole.pd);
        expect(
          hdbt.poe?.standard,
          isNull,
          reason: 'PoH is not an IEEE 802.3 standard and must not claim one',
        );
      },
    );

    test('it is notInRack, so it occupies nothing', () {
      expect(rx.mountMethod, MountMethod.notInRack);
      expect(rx.frontU, 0);
      expect(rx.rearU, 0);
    });

    test("it shares the kit's physical facts with the transmitter", () {
      // P4's stated reason for one template rather than two: *"the halves
      // share every physical fact"*. Weight is the one this can check
      // against the base directly.
      expect(rx.weight, catalog['V06']!.weight);
    });
  });

  group("V07's decoder, port for port (§575)", () {
    final dec = variants['V07:decoder']!;

    test('six ports, in the order the spec lists them', () {
      expect(keysOf(dec), [
        'network',
        'hdmi.out',
        'analog.out',
        'ir.out',
        'rs232',
        'dc.in',
      ]);
    });

    test("every physical fact is the encoder's (§575 states one set)", () {
      final enc = catalog['V07']!;
      expect(dec.weight, enc.weight);
      expect(dec.bodyDepth, enc.bodyDepth);
      expect(dec.connectorProjection, enc.connectorProjection);
      expect(dec.mountMethod, enc.mountMethod);
      expect(dec.power.typicalWatts, enc.power.typicalWatts);
    });
  });

  group('resolving a role', () {
    test('the shipped half resolves to the catalog body itself', () {
      expect(
        resolveTemplateRole(catalog, 'V06', TemplateRole.transmitter),
        same(catalog['V06']),
        reason: 'the base role is not a copy — it IS the shipped template',
      );
    });

    test('the derived half resolves to the variant', () {
      final rx = resolveTemplateRole(catalog, 'V06', TemplateRole.receiver);
      expect(rx, isNotNull);
      expect(rx!.typePrefix, 'RX');
    });

    test('a role a template does not offer is null, not a throw', () {
      // Reachable and normal: asking a patch panel for its decoder half is
      // a reasonable question with a true answer.
      expect(
        resolveTemplateRole(catalog, 'N03', TemplateRole.decoder),
        isNull,
      );
      expect(
        resolveTemplateRole(catalog, 'V06', TemplateRole.decoder),
        isNull,
        reason: 'V06 carries a role parameter but not THAT role',
      );
    });

    test('every role of every parametric id resolves', () {
      // The completeness check the two above cannot make between them.
      for (final id in ['V06', 'V07']) {
        for (final role in rolesFor(id)) {
          expect(
            resolveTemplateRole(catalog, id, role),
            isNotNull,
            reason: '$id offers ${role.name} and must resolve it',
          );
        }
      }
    });

    test('a variant id is stable and collision-proof', () {
      // The id is what a document stores (AC-041 snapshots the resolved
      // body under it), so it is a byte-surface fact even though no NEW
      // field was added. A colon is the one punctuation neither a catalog
      // id nor a Device Builder fork produces.
      expect(
        roleVariantTemplateId('V06', TemplateRole.receiver),
        'V06:receiver',
      );
      for (final id in catalog.keys) {
        expect(id, isNot(contains(':')));
      }
    });
  });

  group('the halves are shippable templates in their own right', () {
    test('every variant obeys the catalog invariants its bases obey', () {
      // DR-002/P1: generic archetypes, never real SKUs. A variant that
      // escaped this rule would be the one real-SKU body in the catalog.
      for (final entry in variants.entries) {
        expect(entry.value.manufacturer, 'Generic', reason: entry.key);
        expect(entry.value.model, isNotEmpty, reason: entry.key);
        expect(entry.value.displayName, isNotEmpty, reason: entry.key);
        expect(entry.value.ports, isNotEmpty, reason: entry.key);
      }
    });

    test('every port names a family and a connector the registries seed', () {
      // The same check that keeps a base honest: a body referencing a
      // family nobody seeds resolves to slate and draws as "unknown",
      // which is a defect that only shows up on a sheet.
      final registries = buildSeedRegistries();
      for (final entry in variants.entries) {
        for (final port in entry.value.ports) {
          expect(
            registries.signalFamilies.containsKey(port.signalFamily),
            isTrue,
            reason: '${entry.key}/${port.key.v}: ${port.signalFamily.v}',
          );
          expect(
            registries.connectorTypes.containsKey(port.connector),
            isTrue,
            reason: '${entry.key}/${port.key.v}: ${port.connector.v}',
          );
        }
      }
    });

    test(
      'typePrefix matches the role, and no half borrows its sibling one',
      () {
        for (final entry in variants.entries) {
          final role = TemplateRole.values.firstWhere(
            (r) => r.name == entry.key.split(':').last,
          );
          expect(entry.value.typePrefix, role.typePrefix, reason: entry.key);
        }
        expect(catalog['V06']!.typePrefix, TemplateRole.transmitter.typePrefix);
        expect(catalog['V07']!.typePrefix, TemplateRole.encoder.typePrefix);
      },
    );
  });
}
