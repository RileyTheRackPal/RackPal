// M4-G2's gate: the mini-DSL, parsed against the real seeded registries.
//
// THE ARTIFACT IS THE PLAN, because the plan is what the summary line
// reads and what a build consumes. Every assertion below is a fact a
// user could see on screen: how many ports, which family, which
// connector, which bank, what the labels say.
//
// THE THIRTEEN-STEP PATH IS THE CENTREPIECE. docs/06 §9.1 is the
// walkthrough M4's exit criterion is measured against, so it is typed
// out here verbatim and asserted to produce 68 ports across 6 banks. If
// that group goes red, the milestone's exit criterion is unreachable
// regardless of what the UI does, which is exactly the kind of thing a
// widget test cannot tell anyone.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

QuickAddPlan planOk(Registries r, String command) {
  final result = parseQuickAdd(r, command);
  expect(
    result,
    isA<QuickAddPlan>(),
    reason:
        '"$command" should have parsed; '
        'got ${result is QuickAddFailure ? result.message : result}',
  );
  return result as QuickAddPlan;
}

/// A minimal body to derive bank names against. `order` is a
/// `FracIndex`, not an int: banks sort by fractional index so a reorder
/// never renumbers its neighbours.
TemplateBody emptyBody() =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D');

BankDef bank(String key, String label) =>
    BankDef(key: key, label: label, abbr: 'AB', order: const FracIndex('a0'));

QuickAddFailure planFail(Registries r, String command) {
  final result = parseQuickAdd(r, command);
  expect(
    result,
    isA<QuickAddFailure>(),
    reason: '"$command" should have been refused, and was not',
  );
  return result as QuickAddFailure;
}

void main() {
  final r = buildSeedRegistries();

  group('docs/06 §4.1, the grammar', () {
    test('16 hdmi in resolves both halves and the direction', () {
      final p = planOk(r, '16 hdmi in');
      expect(p.quantity, 16);
      expect(p.family?.v, 'video.hdmi.2_0');
      expect(p.connector?.v, 'conn.hdmi_a');
      expect(p.direction, PortDirection.sink);
    });

    test('hdbt and rj45 give the SAME connector and DIFFERENT families', () {
      // CR-058's orthogonality claim, which had nothing behind it until
      // DR-060. This is the assertion that proves the ruling landed.
      final hdbt = planOk(r, '16 hdbt out');
      final rj45 = planOk(r, '1 rj45 in');
      expect(hdbt.connector?.v, 'conn.rj45');
      expect(rj45.connector?.v, 'conn.rj45');
      expect(hdbt.family?.v, 'video.hdbaset');
      expect(rj45.family?.v, 'net.ethernet');
      expect(hdbt.family, isNot(rj45.family));
    });

    test('everything after the quantity is order-insensitive', () {
      final a = planOk(r, '16 hdmi in rear "IN {n}" @Sources');
      final b = planOk(r, '16 @Sources rear "IN {n}" hdmi in');
      expect(b.family, a.family);
      expect(b.connector, a.connector);
      expect(b.direction, a.direction);
      expect(b.face, a.face);
      expect(b.bankName, a.bankName);
      expect(b.labels, a.labels);
    });

    test('a second type token REFINES rather than replaces', () {
      // An HDBaseT signal on an explicitly named 8P8C. Both tokens name
      // the same connector here, which is the point: they agree.
      final p = planOk(r, '16 rj45 hdbaset out');
      expect(p.connector?.v, 'conn.rj45');
      expect(
        p.family?.v,
        'net.ethernet',
        reason: 'the FIRST token to name a family wins it',
      );
    });

    test("A NAMED CONNECTOR BEATS AN EARLIER TOKEN'S FAMILY DEFAULT", () {
      // Found by the render/parse round-trip, not by reading. The first
      // draft merged with `connector ??= connectorHit?.id ??
      // familyHit?.defaultConnector`, so the FIRST token's family
      // DEFAULT occupied the slot and no later token could name a
      // connector: this command resolved to a binding post, because
      // `speaker` claimed it before `euro2` was read. DR-060 §11.59.4's
      // rule is "a default loses to a named one" and that draft applied
      // it within a token but not ACROSS tokens.
      final p = planOk(r, '16 speaker euro2 out');
      expect(p.family?.v, 'audio.speaker_lowz');
      expect(p.connector?.v, 'conn.euroblock_2');
    });

    test('and order does not matter to that either', () {
      final a = planOk(r, '16 speaker euro2 out');
      final b = planOk(r, '16 euro2 speaker out');
      expect(b.family, a.family);
      expect(b.connector, a.connector);
    });

    test('a bank name may contain spaces', () {
      expect(
        planOk(r, '16 hdmi out @Mirror Outputs').bankName,
        'Mirror Outputs',
      );
    });

    test('a bank name stops at a quoted label', () {
      final p = planOk(r, '24 rj45 @Ports "{n:2}"');
      expect(p.bankName, 'Ports');
      expect(p.labels.first, '01');
      expect(p.labels.last, '24');
    });

    test('both doubles the ports and leaves the quantity alone', () {
      // A 24-position passthrough panel is 24 positions and 48 ports.
      // Reporting 48 as the quantity would read as a miscount.
      final p = planOk(r, '24 rj45 pass both "{n:2}"');
      expect(p.quantity, 24);
      expect(p.portCount, 48);
      expect(p.bothFaces, isTrue);
      expect(p.passthrough, isTrue);
    });

    test('face defaults to null, meaning rear, rather than to a guess', () {
      expect(planOk(r, '16 hdmi in').face, isNull);
      expect(planOk(r, '16 hdmi in front').face, Face.front);
      expect(planOk(r, '16 hdmi in rear').face, Face.rear);
    });

    test('a quoted token is a label even when it reads like a keyword', () {
      final p = planOk(r, '2 hdmi "out"');
      expect(p.labels, ['out', 'out']);
      expect(p.direction, isNull, reason: 'the quotes disambiguated it');
    });
  });

  group('unknown is a real answer (G4 / CR-114)', () {
    test('xlr sets the connector and leaves the family blank', () {
      final p = planOk(r, '4 xlr in');
      expect(p.connector?.v, 'conn.xlr3');
      expect(p.family, isNull);
    });

    test('euro2 defaults to low-Z, and lands on the euroblock', () {
      // DR-060 §11.59.10(b), a user call against the recommendation.
      // The family's own default connector is a binding post, so this
      // asserts the named connector wins: authoring a speaker port on
      // the wrong connector is the failure this pair guards.
      final p = planOk(r, '16 euro2 out');
      expect(p.family?.v, 'audio.speaker_lowz');
      expect(p.connector?.v, 'conn.euroblock_2');
    });

    test('direction is null when unstated, for the family to fill in', () {
      expect(planOk(r, '16 hdmi').direction, isNull);
    });
  });

  group('docs/06 §9.1, the thirteen steps the criterion measures', () {
    // Steps 6 to 13 verbatim. Steps 1 to 5 are the metadata form and
    // are not this parser's business.
    const steps = <String>[
      '16 hdmi in "HDMI IN {n:2}"',
      '16 hdbt out "HDBT OUT {n:2}"',
      '16 hdmi out "MIRROR {n:2}" @Mirror Outputs',
      '16 ir35 out "IR OUT {n:2}"',
      '1 rj45 in "LAN" @Control',
      '1 de9 bi "RS-232" @Control',
      '1 ir35 in "IR IN" @Control',
      '1 c14 in',
    ];

    test('every step parses', () {
      for (final step in steps) {
        expect(
          parseQuickAdd(r, step),
          isA<QuickAddPlan>(),
          reason: step,
        );
      }
    });

    test('THE EIGHT STEPS TOTAL 68 PORTS', () {
      // The number the exit criterion names, computed from the commands
      // rather than restated.
      final total = steps
          .map((s) => planOk(r, s).portCount)
          .fold<int>(0, (a, b) => a + b);
      expect(total, 68);
    });

    test('and they name three explicit banks, all of them Control', () {
      final named = steps
          .map((s) => planOk(r, s).bankName)
          .where((b) => b != null)
          .toList();
      expect(named, ['Mirror Outputs', 'Control', 'Control', 'Control']);
    });

    test('the patterned banks label sixteen ports distinctly each', () {
      for (final step in steps.take(4)) {
        final labels = planOk(r, step).labels;
        expect(labels, hasLength(16), reason: step);
        expect(labels.toSet(), hasLength(16), reason: step);
        expect(labels.first, endsWith('01'), reason: step);
        expect(labels.last, endsWith('16'), reason: step);
      }
    });

    test('the C14 inlet is power.ac_iec, not a direction called inlet', () {
      // CR-058 / CR-060: inlet and outlet are a role on a power family,
      // never directions. `in` is the direction and it means sink.
      final p = planOk(r, '1 c14 in');
      expect(p.family?.v, 'power.ac_iec');
      expect(p.connector?.v, 'conn.iec_c14');
      expect(p.direction, PortDirection.sink);
    });
  });

  group('bank derivation (M4-H3, DR-060 §11.59.10(a))', () {
    // The rule is the family's FIRST ALIAS then shortTag, NOT the
    // display name docs/06 §4.2 used to state. The assertions below are
    // the strings §4.1's example table and §2's layout sketch print.
    test('16 hdmi in derives "HDMI Inputs", as §4.1 prints it', () {
      expect(deriveBankName(r, planOk(r, '16 hdmi in')), 'HDMI Inputs');
    });

    test('16 hdbt out derives "HDBT Outputs", as §2 prints it', () {
      expect(deriveBankName(r, planOk(r, '16 hdbt out')), 'HDBT Outputs');
    });

    test('the display-name rule would have produced neither', () {
      // Guards the correction itself: if someone "restores" §4.2's
      // stated rule, these two names come back and this test says why
      // they are wrong.
      final hdmi = r.signalFamilies[const SignalFamilyId('video.hdmi.2_0')]!;
      expect(hdmi.displayName, 'HDMI 2.0 (18 Gbps)');
      expect(
        deriveBankName(r, planOk(r, '16 hdmi in')),
        isNot(contains('18 Gbps')),
      );
    });

    test('ir35 derives "IR Outputs" because ir is seeded first', () {
      // The alias is there for this and nothing else: `ir` already
      // resolved through shortTag, so it adds a display fact.
      expect(deriveBankName(r, planOk(r, '16 ir35 out')), 'IR Outputs');
    });

    test('EVERY DELIBERATELY ORDERED ALIAS LIST DERIVES ITS INTENDED HEAD', () {
      // The alias list's ORDER is display data (§11.59.10(a)), and six
      // families were reordered specifically so their banks read as an
      // installer writes them. This is the artifact that ordering
      // exists for, so it is pinned here rather than left to a rule:
      // an attempt to gate it structurally is recorded as failed in
      // `signal_family_alias_test.dart`.
      const wanted = <String, String>{
        '16 hdmi in': 'HDMI Inputs',
        '16 hdbt out': 'HDBT Outputs',
        '16 ir35 out': 'IR Outputs',
        '1 de9 bi': 'RS232 Ports',
        '24 rj45 in': 'LAN Inputs',
        '1 c14 in': 'IEC Inputs',
        '8 5-15r out': 'AC Outputs',
        '16 euro2 out': 'SPEAKER Outputs',
      };
      for (final row in wanted.entries) {
        expect(
          deriveBankName(r, planOk(r, row.key)),
          row.value,
          reason: row.key,
        );
      }
    });

    test('a direction with no plural noun falls back to Ports', () {
      expect(deriveBankName(r, planOk(r, '1 de9 bi')), 'RS232 Ports');
    });

    test('an unfamilied plan names itself from the connector', () {
      // `16 xlr in` has to land somewhere, and "Inputs" alone would
      // collide with every other unfamilied bank on the first try.
      expect(deriveBankName(r, planOk(r, '16 xlr in')), 'XLR Inputs');
    });

    test('direction falls back to the family default when unstated', () {
      // `video.hdmi.2_0` is a source, so a bare `16 hdmi` is Outputs.
      expect(deriveBankName(r, planOk(r, '16 hdmi')), 'HDMI Outputs');
    });

    test('an explicit @bank wins over any derivation', () {
      expect(
        uniqueBankName(r, emptyBody(), planOk(r, '16 hdmi in @Sources')),
        'Sources',
      );
    });

    test('an EXPLICIT name never suffixes, because @Control means it', () {
      // §9.1 types @Control three times and the exit criterion says the
      // finished template has SIX banks. Suffixing an explicit name
      // gives Control, Control 2, Control 3 and a template with eight.
      final body = emptyBody()..banks.add(bank('c', 'Control'));
      expect(
        uniqueBankName(r, body, planOk(r, '1 de9 bi @Control')),
        'Control',
      );
    });

    test('collisions take a numeric suffix, compared on the LABEL', () {
      final body = emptyBody()..banks.add(bank('a', 'HDMI Inputs'));
      expect(uniqueBankName(r, body, planOk(r, '16 hdmi in')), 'HDMI Inputs 2');

      body.banks.add(bank('b', 'HDMI Inputs 2'));
      expect(uniqueBankName(r, body, planOk(r, '16 hdmi in')), 'HDMI Inputs 3');
    });

    test('the 13-step path produces six distinct bank names', () {
      // The exit criterion says 68 ports across 6 banks. Five banks are
      // derived and one is named, and no two may collide, because two
      // banks reading the same thing is what the suffix exists to stop.
      const steps = <String>[
        '16 hdmi in "HDMI IN {n:2}"',
        '16 hdbt out "HDBT OUT {n:2}"',
        '16 hdmi out "MIRROR {n:2}" @Mirror Outputs',
        '16 ir35 out "IR OUT {n:2}"',
        '1 rj45 in "LAN" @Control',
        '1 c14 in',
      ];
      final body = emptyBody();
      final names = <String>[];
      for (final step in steps) {
        final name = uniqueBankName(r, body, planOk(r, step));
        if (!names.contains(name)) {
          names.add(name);
          body.banks.add(bank('k${body.banks.length}', name));
        }
      }
      expect(names, hasLength(6));
      expect(
        names,
        containsAll(<String>[
          'HDMI Inputs',
          'HDBT Outputs',
          'Mirror Outputs',
          'IR Outputs',
          'Control',
        ]),
      );
    });
  });

  group('building a plan into ports', () {
    /// Runs a command list against a body, the way a `transact` would.
    TemplateBody apply(TemplateBody body, String command) {
      for (final c in buildQuickAdd(r, body, planOk(r, command))) {
        c.apply(body);
      }
      return body;
    }

    test('16 hdbt out lands sixteen ports in one new bank', () {
      final body = apply(emptyBody(), '16 hdbt out "HDBT OUT {n:2}"');
      expect(body.ports, hasLength(16));
      expect(body.banks, hasLength(1));
      expect(body.banks.single.label, 'HDBT Outputs');
      expect(body.ports.first.label, 'HDBT OUT 01');
      expect(body.ports.last.label, 'HDBT OUT 16');
      expect(
        body.ports.every((p) => p.bankKey == body.banks.single.key),
        isTrue,
      );
    });

    test('every port key is distinct, which a shared snapshot would break', () {
      // Keys are allocated against a GROWING set: all sixteen commands
      // are built before any runs, so allocating against `body` as it
      // stands would mint sixteen identical keys.
      final body = apply(emptyBody(), '16 hdmi in "HDMI IN {n:2}"');
      expect(body.ports.map((p) => p.key.v).toSet(), hasLength(16));
    });

    test('and every order is distinct and ascending', () {
      final body = apply(emptyBody(), '16 hdmi in "HDMI IN {n:2}"');
      final orders = body.ports.map((p) => p.order.v).toList();
      expect(orders.toSet(), hasLength(16));
      final sorted = [...orders]..sort();
      expect(orders, sorted, reason: 'ports arrive in the order typed');
    });

    test('the family fills in direction and topology when unstated', () {
      final body = apply(emptyBody(), '4 hdmi');
      expect(body.ports.first.direction, PortDirection.source);
      expect(body.ports.first.topology, PortTopology.p2p);
    });

    test('an unresolved family is written as the empty id, not a guess', () {
      final body = apply(emptyBody(), '4 xlr in');
      expect(body.ports.first.signalFamily.v, '');
      expect(body.ports.first.connector.v, 'conn.xlr3');
    });

    test('a second command into the same bank name reuses the bank', () {
      final body = emptyBody();
      apply(body, '1 rj45 in "LAN" @Control');
      apply(body, '1 de9 bi "RS-232" @Control');
      expect(body.banks, hasLength(1), reason: 'no second Control bank');
      expect(body.ports, hasLength(2));
      expect(body.ports[0].bankKey, body.ports[1].bankKey);
    });

    test('both makes two ports per position, front and rear', () {
      final body = apply(emptyBody(), '2 rj45 pass both "{n:2}"');
      expect(body.ports, hasLength(4));
      expect(body.ports.map((p) => p.face).toList(), [
        Face.front,
        Face.rear,
        Face.front,
        Face.rear,
      ]);
      // The pairing itself is M4-J (#181), named in `buildQuickAdd` and
      // asserted absent here so its arrival is a visible diff.
      expect(body.passthroughPairs, isEmpty);
    });

    test('the bank is the FIRST command, so no port dangles', () {
      // `revert` runs a transaction backwards, so a bank added after
      // its ports would be removed before them on undo.
      final commands = buildQuickAdd(r, emptyBody(), planOk(r, '2 hdmi in'));
      expect(commands.first, isA<AddBankCommand>());
      expect(commands.skip(1).every((c) => c is AddPortCommand), isTrue);
    });

    test('and reverting the whole list leaves the body as it was', () {
      final body = emptyBody();
      final commands = buildQuickAdd(r, body, planOk(r, '16 hdmi in'));
      for (final c in commands) {
        c.apply(body);
      }
      for (final c in commands.reversed) {
        c.revert(body);
      }
      expect(body.ports, isEmpty);
      expect(body.banks, isEmpty);
    });

    test('THE THIRTEEN-STEP PATH BUILDS 68 PORTS IN 6 BANKS', () {
      // The exit criterion's own numbers, produced by running the eight
      // commands a user types rather than by asserting a constant.
      const steps = <String>[
        '16 hdmi in "HDMI IN {n:2}"',
        '16 hdbt out "HDBT OUT {n:2}"',
        '16 hdmi out "MIRROR {n:2}" @Mirror Outputs',
        '16 ir35 out "IR OUT {n:2}"',
        '1 rj45 in "LAN" @Control',
        '1 de9 bi "RS-232" @Control',
        '1 ir35 in "IR IN" @Control',
        '1 c14 in',
      ];
      final body = emptyBody();
      for (final step in steps) {
        apply(body, step);
      }
      expect(body.ports, hasLength(68));
      expect(body.banks, hasLength(6));
      expect(
        body.ports.map((p) => p.key.v).toSet(),
        hasLength(68),
        reason: 'no two of the 68 ports may share a key',
      );
      expect(
        body.banks.map((b) => b.label).toList(),
        containsAll(<String>[
          'HDMI Inputs',
          'HDBT Outputs',
          'Mirror Outputs',
          'IR Outputs',
          'Control',
          'IEC Inputs',
        ]),
      );
    });
  });

  group('IR direction picks the family (DR-060 §11.59.11)', () {
    // The catalog states the hazard where the IR families are declared:
    // emitter and receiver have incompatible pinouts, and plugging one
    // into the other's jack destroys the emitter and can damage the
    // supply. docs/06 §9.1 types `ir35 out` for emitters at step 9 and
    // `1 ir35 in "IR IN"` at step 12 for a matrix's IR INPUT. Settled by
    // the user on 2026-08-15.
    //
    // THE DESTINATION OF THE SWAP MOVED AT DR-126 §11.125. This block
    // used to end "which is a receiver", and a matrix's IR IN is not one:
    // it is a passive jack an emitter lead lands on, and
    // `ctl.ir_receiver` now means only the powered receiver-eye circuit.
    // The swap itself, and the reason for it, are untouched.
    test('ir35 out is an emitter', () {
      final p = planOk(r, '16 ir35 out "IR OUT {n:2}"');
      expect(p.family?.v, 'ctl.ir_emitter');
      expect(p.connector?.v, 'conn.3_5mm_ts');
    });

    test('AND ir35 in IS A DIRECT INPUT, which an emitter lead lands on', () {
      final p = planOk(r, '1 ir35 in "IR IN"');
      expect(p.family?.v, 'ctl.ir_direct');
      expect(
        p.connector?.v,
        'conn.3_5mm_ts',
        reason:
            'a passive device input takes the emitter’s own TS plug: '
            'DR-126 §11.125.4 makes the direct-connect lead the same '
            'object at both ends',
      );
    });

    test('typing ir35 in cannot reach the family that is the hazard', () {
      // The powered receiver-eye circuit is where an emitter lead does
      // damage, so no token resolves to it by direction alone. Reaching
      // it costs naming the family outright, which is the point.
      expect(planOk(r, '1 ir35 in').family?.v, isNot('ctl.ir_receiver'));
      expect(planOk(r, '1 ir35 out').family?.v, isNot('ctl.ir_receiver'));
      expect(planOk(r, '1 irrx in').family?.v, 'ctl.ir_receiver');
    });

    test('a NAMED connector still wins over the family default', () {
      // §11.59.4's rule survives the swap: a person being explicit is
      // not overruled by a table.
      //
      // TRS, NOT TS. This read `1 ir35 in 3_5mm_ts` and asserted TS,
      // which was a real check while `ir35 in` swapped to a TRS-default
      // family. DR-126 gave `ctl.ir_direct` a TS default, so that command
      // now proves nothing: it would pass with the named connector
      // ignored entirely. The named value has to DIFFER from the default
      // for this test to be able to fail.
      final p = planOk(r, '1 ir35 in 3_5mm_trs');
      expect(p.family?.v, 'ctl.ir_direct');
      expect(p.connector?.v, 'conn.3_5mm_trs');
    });

    test('and no other family swaps on direction', () {
      // The table holds one row on purpose. `hdmi in` must stay HDMI.
      expect(planOk(r, '16 hdmi in').family?.v, 'video.hdmi.2_0');
      expect(planOk(r, '16 hdmi out').family?.v, 'video.hdmi.2_0');
      expect(planOk(r, '1 rj45 in').family?.v, 'net.ethernet');
    });

    test('the swapped plan still round-trips', () {
      final first = planOk(r, '1 ir35 in "IR IN"');
      final second = planOk(r, renderQuickAdd(r, first));
      expect(second.family, first.family);
      expect(second.connector, first.connector);
    });
  });

  group('rendering a plan back to a command (M4-G3)', () {
    /// The property the bidirectional binding rests on: what field mode
    /// writes, command mode reads back as the same thing.
    void roundTrips(String command) {
      final first = planOk(r, command);
      final rendered = renderQuickAdd(r, first);
      final second = planOk(r, rendered);

      expect(second.quantity, first.quantity, reason: rendered);
      expect(second.family, first.family, reason: rendered);
      expect(second.connector, first.connector, reason: rendered);
      expect(second.direction, first.direction, reason: rendered);
      expect(second.bothFaces, first.bothFaces, reason: rendered);
      expect(second.passthrough, first.passthrough, reason: rendered);
      expect(second.bankName, first.bankName, reason: rendered);
      expect(second.labels, first.labels, reason: rendered);
      expect(
        second.face ?? Face.rear,
        first.face ?? Face.rear,
        reason: rendered,
      );
    }

    test('EVERY STEP OF THE THIRTEEN-STEP PATH ROUND-TRIPS', () {
      // If any of these lost a field, a user who touched one dropdown
      // would silently change something they never looked at.
      for (final step in const <String>[
        '16 hdmi in "HDMI IN {n:2}"',
        '16 hdbt out "HDBT OUT {n:2}"',
        '16 hdmi out "MIRROR {n:2}" @Mirror Outputs',
        '16 ir35 out "IR OUT {n:2}"',
        '1 rj45 in "LAN" @Control',
        '1 de9 bi "RS-232" @Control',
        '1 ir35 in "IR IN" @Control',
        '1 c14 in',
      ]) {
        roundTrips(step);
      }
    });

    test('and so do the awkward ones', () {
      roundTrips('4 xlr in');
      roundTrips('16 euro2 out');
      roundTrips('24 rj45 pass both "{n:2}"');
      roundTrips('16 hdmi');
      roundTrips('8 5-15r out @Power');
      roundTrips('16 euro2 out "ZONE {n@2} {L,R}"');
    });

    test('the family token is the trade spelling, not the display name', () {
      // `HDMI 2.0 (18 Gbps)` resolves, but nobody types it, and putting
      // it on the command line would teach the wrong vocabulary.
      expect(renderQuickAdd(r, planOk(r, '16 hdmi in')), '16 hdmi in rear');
    });

    test('the connector is written only when it is not the default', () {
      // `16 hdmi hdmi in` parses and reads like an argument.
      expect(
        renderQuickAdd(r, planOk(r, '16 hdmi in')),
        isNot(contains('hdmi hdmi')),
      );
      // `c13` DOES differ from its family's default, so it is written.
      expect(renderQuickAdd(r, planOk(r, '1 c13 out')), contains('c13'));
    });

    test('the family comes first, so no token has to override another', () {
      final rendered = renderQuickAdd(r, planOk(r, '1 c13 out'));
      expect(rendered.indexOf('iec'), lessThan(rendered.indexOf('c13')));
    });

    test('an unfamilied plan still names its connector', () {
      expect(renderQuickAdd(r, planOk(r, '4 xlr in')), '4 xlr in rear');
    });

    test('it writes the face it INFERRED, which is the point', () {
      // Field mode shows `rear`, so field mode must write `rear`. A
      // render that omitted it would make the fields and the command
      // line disagree about what will happen.
      expect(renderQuickAdd(r, planOk(r, '16 hdmi in')), endsWith('rear'));
    });
  });

  group('inline autocomplete (M4-G4, AC-050 / A2.4)', () {
    /// Completes at the end of the string, which is where a typing user
    /// is. The caret is passed explicitly because the offer depends on
    /// it and a default would hide that.
    QuickAddCompletion? complete(String text) =>
        quickAddCompletion(r, text, text.length);

    test('a prefix offers the rest of the word', () {
      expect(complete('16 hdb')?.token, 'hdbt');
      expect(complete('16 hdb')?.suffix, 't');
    });

    test('THE OFFER IS DETERMINISTIC AND SHORTEST-FIRST', () {
      // A ghost that moves cannot be learned, and the short spellings
      // are what the grammar is built from. `i` must be `in`, not
      // whichever entry a map happened to yield first.
      expect(complete('16 hdmi i')?.token, 'in');
      for (var n = 0; n < 5; n++) {
        expect(complete('16 hdmi i')?.token, 'in', reason: 'run $n');
      }
    });

    test('it reaches vocabulary the user could not have guessed', () {
      // The whole point: someone who has seen the tool once does not
      // know `hdbaset` exists. AC-050's discoverability argument.
      expect(complete('16 hdba')?.token, 'hdbaset');
      expect(complete('1 c1')?.token, 'c13');
      expect(complete('16 spd')?.token, 'spdif');
    });

    test('a completed word offers nothing, rather than offering itself', () {
      // Ghost text repeating what is already typed is noise.
      expect(complete('16 hdbt'), isNull);
      expect(complete('16 hdmi in'), isNull);
    });

    test('THE QUANTITY IS NEVER COMPLETED', () {
      // It is a number being chosen, not a word being recalled.
      expect(complete('1'), isNull);
      expect(complete('16'), isNull);
    });

    test('nothing inside quotes is completed', () {
      // A label is the user's own vocabulary; a tool guessing at it is
      // a tool fighting them.
      expect(complete('16 hdmi in "HDMI IN'), isNull);
      expect(complete('16 hdmi in "hdb'), isNull);
    });

    test("a bank name is not completed, which is M4-J's offer to make", () {
      expect(complete('16 hdmi in @Contr'), isNull);
    });

    test('MID-WORD, THE CARET IS LEFT ALONE', () {
      // '16 hdb out' — offset 5 sits between `d` and `b`, so the next
      // character is not a space. Completing here would rewrite text
      // the user is standing in the middle of.
      expect(quickAddCompletion(r, '16 hdb out', 5), isNull);
    });

    test('but at the END of a token it completes, even mid-command', () {
      // Offset 6 in the same string is the end of `hdb`, with more
      // command after it. That is a real place to be typing.
      expect(quickAddCompletion(r, '16 hdb out', 6)?.token, 'hdbt');
      expect(quickAddCompletion(r, '16 hdb', 6)?.token, 'hdbt');
    });

    test('an unknown prefix offers nothing rather than a wrong guess', () {
      expect(complete('16 zzz'), isNull);
    });

    test('completions never throw, on any prefix of a real command', () {
      const full = '16 hdmi out "MIRROR {n:2}" @Mirror Outputs';
      for (var i = 0; i <= full.length; i++) {
        expect(
          () => quickAddCompletion(r, full.substring(0, i), i),
          returnsNormally,
          reason: 'caret $i',
        );
      }
    });

    test('and every offer, once accepted, still parses or explains', () {
      // A suggestion that produces a command the parser refuses would
      // be teaching the wrong vocabulary.
      for (final stem in ['16 hd', '16 rj', '1 c1', '16 hdmi i', '4 xl']) {
        final offer = complete(stem);
        expect(offer, isNotNull, reason: stem);
        expect(
          () => parseQuickAdd(r, '$stem${offer!.suffix}'),
          returnsNormally,
        );
      }
    });
  });

  group('parse failures are designed, never thrown', () {
    test('a command with no quantity says so and offers one', () {
      final f = planFail(r, 'hdmi in');
      expect(f.message, contains('how many ports'));
      expect(f.repair, '16 hdmi in');
    });

    test('a zero or negative quantity is refused', () {
      expect(planFail(r, '0 hdmi in').message, contains('at least 1'));
    });

    test('an unrecognised word is quoted back with a quoting repair', () {
      final f = planFail(r, '16 wibble in');
      expect(f.span, 'wibble');
      expect(f.message, contains('not a connector'));
      expect(f.repair, '16 "wibble" in');
    });

    test('and the repair itself parses', () {
      final f = planFail(r, '16 wibble in');
      // Quoting turns the offending word into a label, which needs a
      // type token to still be missing... so this particular repair
      // moves the user to the NEXT error rather than to success. That
      // is correct and is asserted so nobody "fixes" it into a lie.
      expect(parseQuickAdd(r, f.repair), isA<QuickAddFailure>());
      expect(
        (parseQuickAdd(r, f.repair) as QuickAddFailure).message,
        contains('Name a connector or a signal family'),
      );
    });

    test('a command naming no type at all is refused', () {
      final f = planFail(r, '16 in rear');
      expect(f.message, contains('Name a connector or a signal family'));
    });

    test('a bad label pattern reports the PATTERN error, shifted', () {
      final f = planFail(r, '16 hdmi in "IN {x}"');
      expect(f.message, contains('not a pattern token'));
      expect(
        f.span,
        '{x}',
        reason: 'the span is shifted into the command, not the pattern',
      );
      expect(f.repair, '16 hdmi in "IN {n}"');
    });

    test('a bare @ says what it wants', () {
      final f = planFail(r, '16 hdmi in @');
      expect(f.message, contains('bank name'));
    });

    test('an empty command asks for the shape', () {
      expect(planFail(r, '   ').repair, '16 hdmi in');
    });
  });

  group('the bar parses on every keystroke, so it must not be hostile', () {
    test('an unterminated quote is a label, not an error', () {
      // Refusing mid-word would paint an error under the user's hands
      // as they type `"HDMI IN`.
      final p = planOk(r, '16 hdmi in "HDMI IN');
      expect(p.labels, hasLength(16));
      expect(p.labels.first, 'HDMI IN');
    });

    test('every prefix of a valid command either parses or explains', () {
      const full = '16 hdmi out "MIRROR {n:2}" @Mirror Outputs';
      for (var i = 1; i <= full.length; i++) {
        final prefix = full.substring(0, i);
        expect(
          () => parseQuickAdd(r, prefix),
          returnsNormally,
          reason: 'typing "$prefix" must not throw',
        );
      }
    });

    test('a pile of malformed input all returns without throwing', () {
      const nasty = [
        '',
        '  ',
        '16',
        '16 ',
        '""',
        '16 ""',
        '@@@',
        '16 hdmi @ @ @',
        '999999999999999999999999 hdmi in',
        '16 hdmi in "',
      ];
      for (final input in nasty) {
        expect(
          () => parseQuickAdd(r, input),
          returnsNormally,
          reason: '"$input" must not throw',
        );
      }
    });
  });
}
