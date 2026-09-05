// DR-010 §11.10 — the seeded signal registries.
//
// WHAT THIS FILE CAN AND CANNOT PROVE, stated up front because the
// distinction is the whole reason `tools/registry_parity.py` exists.
//
// It CANNOT prove the palette values are right. Asserting `video.sdi`
// draws `10,3` here against a constant that says `10,3` is the constant
// confirming itself — the self-referential shape this project has
// shipped before, and the exact method that signed PAL-1 off as clear
// three times against fourteen collisions. The authority is
// `tools/pal1_check.py` and the gate that binds this seed to it is
// `tools/registry_parity.py`, which runs in CI beside `palette_parity`.
//
// What it CAN prove is everything that is structural rather than
// numeric, and every one of these is a real failure mode:
//   * the shape (8 domains, 57 families) the doc's own summary states;
//   * referential integrity — every family's domain resolves, every
//     default connector resolves or is a declared footprint exemption;
//   * that map keys agree with the ids inside them, so a lookup by id
//     cannot return a different entity;
//   * that the OVERRIDE FALLBACK works in both directions, including
//     the one case (`audio.line_bal`) where an EMPTY dash override means
//     "solid", not "no override" — the distinction the nullable
//     `dashOverride` exists for;
//   * that the type-within-domain channel actually discriminates, which
//     is the thing DR-010 §11.10.3 was written to restore: without it
//     all eight digital-video families draw as one identical solid line.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  final domains = buildSeedSignalDomains();
  final families = buildSeedSignalFamilies();
  final footprints = buildSeedConnectorFootprints();

  group('shape (docs/catalog/seed-devices.md §4.3/§4.4)', () {
    test("exactly 8 domains ship, and they are §4.3's eight", () {
      // The ninth row of §4.3's table is the *(reserved)* selection
      // yellow `#F0E442`, which PAL-2 says "is never a cable". A ninth
      // entry here would put a swatch in the legend and a column in the
      // domain filter bar for something no `Service` can resolve to.
      expect(domains.keys.map((k) => k.v).toSet(), {
        'video.digital',
        'video.analog',
        'audio.analog',
        'audio.digital',
        'net',
        'ctl',
        'pwr',
        'str',
      });
    });

    test('exactly 57 families ship — the count §4.2 and pal1_check.py '
        'both state', () {
      expect(families, hasLength(57));
    });

    test('every family lands in one of the eight domains', () {
      for (final f in families.values) {
        expect(
          domains.containsKey(f.domain),
          isTrue,
          reason:
              '${f.id.v} names domain ${f.domain.v}, which no '
              'SignalDomainDef declares — it would render as the '
              'unknown() placeholder for ever',
        );
      }
    });

    test('all eight domains are populated — none is an empty filter row', () {
      final used = families.values.map((f) => f.domain.v).toSet();
      expect(used, domains.keys.map((k) => k.v).toSet());
    });
  });

  group('referential integrity', () {
    test('each map key equals the id of the def it holds', () {
      for (final e in domains.entries) {
        expect(e.key, e.value.id, reason: 'domain key/id disagree');
      }
      for (final e in families.entries) {
        expect(e.key, e.value.id, reason: 'family key/id disagree');
      }
    });

    test('every defaultConnector resolves in the footprint registry, or '
        'is one of the three exemptions §5.1 declares', () {
      // The same rule `seed_catalog_test.dart` applies to template ports
      // (AC-050/A2.2), applied to the family registry: a family whose
      // default connector names nothing would hand the Quick Add DSL and
      // the rear-panel renderer an id neither can resolve.
      // The `|| kFootprintExemptConnectors.contains(id)` escape hatch that
      // used to be here was the workaround that hid the defect: the four
      // families defaulting to an exempt connector really did name an id
      // that resolved to nothing. Now every family's default resolves, so
      // membership is required outright and footprint-ness is checked
      // separately in seed_catalog_test.dart.
      for (final f in families.values) {
        final id = f.defaultConnector.v;
        expect(
          footprints.containsKey(f.defaultConnector),
          isTrue,
          reason:
              '${f.id.v} defaults to connector "$id", which does not '
              'resolve in the connector registry',
        );
      }
    });

    test('every user of a footprint-exempt connector is one the doc '
        'states', () {
      // Guards the ONE invented value declared in the seed's header:
      // §4.4 prints "—" for `structure.pathway`'s connector and the field
      // is non-nullable. If that spreads to families whose connector the
      // doc really does state, this test says so.
      //
      // THE NAME USED TO SAY "the two structure families are the only
      // users", which was never true: the two power families are here as
      // well and always were. It is a list, not a count, and `ctl.vantage`
      // joining it is what made the difference visible.
      final exemptUsers = {
        for (final f in families.values)
          if (kFootprintExemptConnectors.contains(f.defaultConnector.v))
            f.id.v: f.defaultConnector.v,
      };
      expect(exemptUsers, {
        'power.ac_hardwired': 'conn.hardwired',
        'power.bonding': 'conn.ground_lug',
        // NOT INVENTED, WHICH IS WHAT THIS TEST IS ABOUT. Vantage joins
        // its bus with Wago or wire nut connections (DR-120 §11.119.4),
        // so it has no connector for the same reason hardwired AC has
        // none, and §4.4 states it.
        'ctl.vantage': 'conn.hardwired',
        'structure.undetermined': 'conn.unterminated',
        'structure.pathway': 'conn.unterminated',
      });
    });
  });

  group('the tag pill (§4.2: the encoding that never fails)', () {
    test('every family carries a shortTag and every domain a tagPrefix', () {
      for (final d in domains.values) {
        expect(d.tagPrefix, isNotEmpty, reason: '${d.id.v} has no tagPrefix');
      }
      for (final f in families.values) {
        expect(
          f.shortTag,
          isNotNull,
          reason:
              '${f.id.v} has no shortTag — the TYPE cell on the schedule '
              'would fall back to displayName',
        );
        expect(f.shortTag, isNotEmpty, reason: '${f.id.v} has an empty tag');
      }
    });

    test('no two families share a shortTag', () {
      // A duplicate tag makes two different cables print the same pill,
      // which is the one encoding §4.2 promises never fails.
      final seen = <String, String>{};
      for (final f in families.values) {
        final tag = f.shortTag!;
        expect(
          seen.containsKey(tag),
          isFalse,
          reason: '${f.id.v} and ${seen[tag]} both print "$tag"',
        );
        seen[tag] = f.id.v;
      }
    });

    test('no domain tagPrefix collides with a system designator prefix', () {
      // `seed_catalog_test.dart` guards template typePrefixes against the
      // same set (C4, CR-043). `N` for Network — which
      // docs/02-data-model.md §6.2's worked JSON shows as the tagPrefix —
      // is exactly the collision this catches; §3.5's `NET` does not.
      const systemPrefixes = {'STR', 'RK', 'W', 'N', 'J'};
      for (final d in domains.values) {
        if (d.id.v == 'str') continue; // `STR` IS the structure domain
        expect(
          systemPrefixes.contains(d.tagPrefix),
          isFalse,
          reason:
              '${d.id.v} tagPrefix "${d.tagPrefix}" collides with a '
              'system designator prefix',
        );
      }
    });
  });

  group('dash encoding (CR-079: permille-points, never a float)', () {
    test('every stored dash is an even-length list of positive permille '
        'values, or empty for solid', () {
      final patterns = <String, List<int>>{
        for (final d in domains.values) 'domain ${d.id.v}': d.dashPattern,
        for (final f in families.values)
          if (f.dashOverride != null) 'family ${f.id.v}': f.dashOverride!,
      };
      for (final e in patterns.entries) {
        expect(
          e.value.length.isEven,
          isTrue,
          reason:
              '${e.key} has an odd number of dash entries — marks and '
              'gaps alternate, so a trailing mark has no gap',
        );
        for (final v in e.value) {
          expect(
            v,
            greaterThan(0),
            reason:
                '${e.key} has a zero-or-negative '
                'dash entry; "no stroke is ever emitted at 0" (§4.2)',
          );
        }
      }
    });

    test('every dash period clears the 4.5 pt print floor', () {
      // §4.2: below 4.5 pt (1.5875 mm) a dash blurs to solid at 300 dpi.
      // `pal1_check.py` asserts this over effective values too; this
      // catches a *stored* value that is only reachable through the
      // fallback, e.g. a domain base no family inherits verbatim.
      for (final f in families.values) {
        final dash = f.effectiveDashPattern(domains[f.domain]!);
        if (dash.isEmpty) continue;
        final period = dash.reduce((a, b) => a + b);
        expect(
          period,
          greaterThanOrEqualTo(4500),
          reason: '${f.id.v} has a ${period / 1000} pt period',
        );
      }
    });
  });

  group('the type-within-domain channel (DR-010 §11.10.3)', () {
    test('an absent override inherits the domain, a present one wins', () {
      // Both directions, on two families chosen because they sit in the
      // same domain and differ only in whether they override.
      final ctl = domains[const SignalDomainId('ctl')]!;
      final irEmitter = families[const SignalFamilyId('ctl.ir_emitter')]!;
      final rs232 = families[const SignalFamilyId('ctl.rs232')]!;

      expect(irEmitter.dashOverride, isNull);
      expect(irEmitter.effectiveDashPattern(ctl), ctl.dashPattern);
      expect(
        irEmitter.effectiveLineWeightPermille(ctl),
        ctl.lineWeightPermille,
      );

      expect(rs232.dashOverride, isNotNull);
      expect(rs232.effectiveDashPattern(ctl), isNot(ctl.dashPattern));
      expect(rs232.effectiveDashPattern(ctl), rs232.dashOverride);
    });

    test('audio.line_bal overrides to SOLID with an EMPTY list, which is '
        'not the same as no override', () {
      // THE CASE THE NULLABLE FIELD EXISTS FOR. `audio.analog`'s base
      // dash is `6,3`; `audio.line_bal` draws solid (§4.4: "the one place
      // a dashOverride reaches for solid inside a dashed domain"). A
      // non-nullable `List<int>` defaulting to `const []` could not tell
      // this apart from "inherit" and would redraw every analog-audio
      // family solid.
      final audio = domains[const SignalDomainId('audio.analog')]!;
      final balanced = families[const SignalFamilyId('audio.line_bal')]!;
      final unbalanced = families[const SignalFamilyId('audio.line_unbal')]!;

      expect(audio.dashPattern, isNotEmpty);
      expect(balanced.dashOverride, isEmpty);
      expect(balanced.effectiveDashPattern(audio), isEmpty);
      expect(unbalanced.dashOverride, isNull);
      expect(unbalanced.effectiveDashPattern(audio), audio.dashPattern);
    });

    test('the eight digital-video families are pairwise distinguishable on '
        'dash or weight alone', () {
      // THE REGRESSION DR-010 §11.10.3 NAMES: with no dash and no weight
      // on the family, "ALL EIGHT DIGITAL VIDEO FAMILIES DRAW AS ONE
      // IDENTICAL SOLID LINE". PAL-1's within-domain limb requires any
      // two families in one domain to differ in dash, weight or glyph,
      // and glyph is per-domain here, so dash or weight must do it.
      final vid = domains[const SignalDomainId('video.digital')]!;
      final rendered = <String, String>{};
      for (final f in families.values) {
        if (f.domain != vid.id) continue;
        final key =
            '${f.effectiveDashPattern(vid)}'
            '@${f.effectiveLineWeightPermille(vid)}';
        expect(
          rendered.containsKey(key),
          isFalse,
          reason: '${f.id.v} and ${rendered[key]} render identically ($key)',
        );
        rendered[key] = f.id.v;
      }
      expect(rendered, hasLength(8));
    });

    test('no two families anywhere render identically within their domain', () {
      // The general form of the check above — PAL-1's within-domain limb
      // over all 55. `pal1_check.py` runs this too; it is here because it
      // is the one PAL-1 limb decidable from the Dart alone, and a
      // failure here is a bug in the SEED rather than in the palette.
      final seen = <String, String>{};
      for (final f in families.values) {
        final d = domains[f.domain]!;
        final key =
            '${f.domain.v}|${f.effectiveDashPattern(d)}'
            '|${f.effectiveLineWeightPermille(d)}';
        expect(
          seen.containsKey(key),
          isFalse,
          reason: '${f.id.v} and ${seen[key]} are indistinguishable',
        );
        seen[key] = f.id.v;
      }
    });
  });

  group('buildSeedRegistries — what a new document starts from', () {
    final seeded = buildSeedRegistries();

    test('carries the domains, families and connector footprints', () {
      expect(seeded.signalDomains, hasLength(8));
      expect(seeded.signalFamilies, hasLength(57));
      // `buildSeedConnectorFootprints()` shipped at M1 and was consumed
      // ONLY by its own test, which is why DR-010's finding reads
      // "connectors: 0" everywhere. This is the line that made it live.
      expect(seeded.connectorTypes, isNotEmpty);
      expect(seeded.connectorTypes, hasLength(footprints.length));
    });

    test('leaves cableSpecs EMPTY', () {
      // Out of DR-010's scope and deliberately not invented (G4). This
      // asserts the absence so that populating it later is a visible
      // change to a stated expectation rather than a silent one.
      //
      // TWO IDS HAVE LEFT THIS TEST, and the tripwire did its job both
      // times. `mediaTypes` went to M3-C/6, because the drop DSL
      // (docs/07 §4.3, `4x Cat6`) had nothing to resolve a media name
      // against. `outletTemplates` went to M3-C/4, because seventeen
      // outlets in the whole-house starter named ids inside it.
      expect(seeded.cableSpecs, isEmpty);
    });

    test("carries canon §6.5's media types, which it did not before", () {
      // Kept beside the absence above so the three read as one list:
      // what a new document starts from, and what it still does not.
      expect(seeded.mediaTypes, hasLength(38));
    });

    test("carries CR-108's outlet templates, which it did not before", () {
      // Six named recipes plus TIA-570-D Grade 1/2/3. Contents are
      // gated in `seed_outlet_templates_test.dart`; this is the line
      // that puts them in a new document.
      expect(seeded.outletTemplates, hasLength(9));
      expect(seeded.outletTemplates['outlet.tv_location']!.tag, 'TV');
    });

    test('two calls are independent — a document may edit its own copy', () {
      // Registries are ordinary editable stored data after the seed copy
      // (docs/03-architecture.md §5.6: library operations are not
      // undoable). A shared const map would make one project's edit
      // reach into another's.
      final a = buildSeedRegistries();
      final b = buildSeedRegistries();
      a.signalFamilies.remove(const SignalFamilyId('net.ethernet'));
      expect(b.signalFamilies, hasLength(57));
      // DERIVED, NOT A SECOND LITERAL. The property is that `a` is one
      // shorter than `b`, and writing that arithmetic out as a number
      // made this the one site the family count broke when `ctl.vantage`
      // landed: every other 55 was a 55, and this one was a 54.
      expect(a.signalFamilies, hasLength(b.signalFamilies.length - 1));
    });
  });
}
