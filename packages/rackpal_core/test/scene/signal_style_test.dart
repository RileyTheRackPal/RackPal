// `resolveSignalStyle` — CR-078's four encoding channels, over the SEEDED
// registries rather than over a fixture invented here.
//
// ─────────────────────────────────────────────────────────────────────
// WHY THE SEED AND NOT A TOY
// ─────────────────────────────────────────────────────────────────────
// Every claim in docs/05 §6 is a claim about the 8 shipped domains and
// the 55 shipped families: that the hue set is Okabe–Ito and survives a
// CVD, that no two families in a domain render alike, that the effective
// dash and weight are the ones PAL-1 was cleared against. A two-family
// fixture can satisfy all of it and prove none of it. So the suite runs
// on `buildSeedSignalDomains()` / `buildSeedSignalFamilies()`, and its
// failure message tells you which family broke.
//
// WHAT THIS SUITE IS NOT. It is NOT a second PAL-1 check.
// `tools/pal1_check.py` is "the single authority for the palette itself"
// (DR-010 §11.10.1) and enumerates the 385 in-band cross-domain pairs;
// `tools/registry_parity.py` proves the Dart seed agrees with it. A third
// transcription here would be a fifth copy of the palette and would drift
// the way the first four did. What is asserted here is the RENDERING
// contract instead — that the values this file emits are the effective
// values those tools cleared, and that they arrive on the four separate
// channels rather than collapsing onto hue.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

Registries _seeded() => Registries(
  signalDomains: buildSeedSignalDomains(),
  signalFamilies: buildSeedSignalFamilies(),
);

SignalStyle _style(
  String family, {
  Registries? registries,
  Map<SignalFamilyId, Rgb> overrides = const {},
  SignalTheme theme = SignalTheme.light,
}) => resolveSignalStyle(
  family: SignalFamilyId(family),
  registries: registries ?? _seeded(),
  colorOverrides: overrides,
  theme: theme,
);

/// PAL-2's reserved selection/focus yellow. Never a cable.
const int _kSelectionYellow = 0xFFF0E442;

void main() {
  group('channel 1 — hue encodes DOMAIN, never family', () {
    test('every family of a domain renders the same hue, and the eight '
        'domains render eight distinct ones', () {
      final registries = _seeded();
      final byDomain = <String, Set<int>>{};
      for (final id in registries.signalFamilies.keys) {
        final style = _style(id.v, registries: registries);
        byDomain.putIfAbsent(style.domainId!.v, () => <int>{}).add(style.argb);
      }
      expect(byDomain, hasLength(8));
      for (final entry in byDomain.entries) {
        expect(
          entry.value,
          hasLength(1),
          reason:
              '${entry.key} rendered ${entry.value.length} hues. CR-078 '
              'moved colour from the family to the DOMAIN precisely '
              'because no categorical palette is CVD-safe past 8–9 '
              'categories; a per-family hue is the rejected alternative',
        );
      }
      // Eight domains, eight hues — a collision would make two domains
      // indistinguishable on the one channel that only encodes domain.
      expect(byDomain.values.map((s) => s.single).toSet(), hasLength(8));
    });

    test('the unresolved ink is not any shipped hue, in either theme, and '
        'is not PAL-2 selection yellow', () {
      final registries = _seeded();
      final hues = <int>{};
      for (final theme in SignalTheme.values) {
        for (final id in registries.signalFamilies.keys) {
          hues.add(_style(id.v, registries: registries, theme: theme).argb);
        }
      }
      expect(
        hues,
        isNot(contains(kUnresolvedSignalArgb)),
        reason:
            'an unresolved family would be indistinguishable from a '
            'resolved one, which is the opposite of what the value is for',
      );
      expect(kUnresolvedSignalArgb, isNot(_kSelectionYellow));
      expect(
        hues,
        isNot(contains(_kSelectionYellow)),
        reason:
            'PAL-2: yellow #F0E442 "is reserved for selection and focus '
            'and is never a cable"',
      );
    });

    test('only hue moves between themes — dash, weight, glyph and tag are '
        'identical (docs/05 §6.2)', () {
      final registries = _seeded();
      var moved = 0;
      for (final id in registries.signalFamilies.keys) {
        final light = _style(id.v, registries: registries);
        final dark = _style(
          id.v,
          registries: registries,
          theme: SignalTheme.dark,
        );
        if (light.argb != dark.argb) moved++;
        expect(dark.dash, light.dash);
        expect(dark.widthPt, light.widthPt);
        expect(dark.glyph, light.glyph);
        expect(dark.tag, light.tag);
      }
      // Every one of the 55 changes hue, so the comparison above is not
      // passing because the two themes are the same palette.
      expect(moved, registries.signalFamilies.length);
    });

    test('`pwr` INVERTS between themes — black is invisible on dark', () {
      final light = _style('power.ac_branch');
      final dark = _style('power.ac_branch', theme: SignalTheme.dark);
      expect(light.argb, 0xFF000000);
      expect(dark.argb, 0xFFE8E8E8);
    });
  });

  group('AC-054 — ProjectSettings.familyColorOverrides', () {
    test('an override replaces the domain hue for that family ALONE and '
        'flags itself as outside the palette', () {
      const overridden = SignalFamilyId('video.hdmi.2_0');
      final overrides = {overridden: const Rgb(1, 2, 3)};

      final hit = _style('video.hdmi.2_0', overrides: overrides);
      expect(hit.argb, 0xFF010203);
      expect(hit.hueIsOverridden, isTrue);

      // Its domain sibling is untouched: the override is per FAMILY.
      final sibling = _style('video.hdmi.2_1', overrides: overrides);
      expect(sibling.argb, _style('video.hdmi.2_1').argb);
      expect(sibling.hueIsOverridden, isFalse);
    });

    test('an override is theme-independent — a colour a user chose is not '
        'second-guessed for dark mode', () {
      final overrides = {
        const SignalFamilyId('power.ac_branch'): const Rgb(9, 9, 9),
      };
      // `pwr` is the domain that INVERTS between themes, so if any family
      // were going to be re-tinted it is this one.
      expect(_style('power.ac_branch', overrides: overrides).argb, 0xFF090909);
      expect(
        _style(
          'power.ac_branch',
          overrides: overrides,
          theme: SignalTheme.dark,
        ).argb,
        0xFF090909,
      );
    });

    test('an override leaves the other three channels alone', () {
      final overrides = {
        const SignalFamilyId('audio.spdif_coax'): const Rgb(0, 0, 0),
      };
      final plain = _style('audio.spdif_coax');
      final tinted = _style('audio.spdif_coax', overrides: overrides);
      expect(tinted.dash, plain.dash);
      expect(tinted.widthPt, plain.widthPt);
      expect(tinted.familyToken, plain.familyToken);
    });
  });

  group('channels 2 and 3 — the EFFECTIVE dash and weight', () {
    test('SOLID INSIDE A DASHED DOMAIN: `audio.line_bal` renders null, not '
        'the empty list and not its domain’s 6,3', () {
      // §6.3's own correction: `audio.line_bal` moved to solid, and §4.4
      // calls it "the one place a `dashOverride` reaches for solid inside
      // a dashed domain". `effectiveDashPattern` answers `[]`; `Stroke`
      // spells solid `null`, and handing `[]` to `dashPath` is not the
      // same drawing at all.
      final solid = _style('audio.line_bal');
      expect(solid.dash, isNull);
      // …and the domain it sits in really is dashed, so the assertion is
      // not passing because everything is solid.
      expect(_style('audio.line_unbal').dash, const <double>[6, 3]);
    });

    test('a family with NO override inherits its domain’s dash — the `str` '
        'correction reaches `structure.undetermined`', () {
      // §14.3 moved the `str` base from `4,4` to `6,3,3,3` precisely so
      // the inheriting family moved with it. Reading `dashOverride`
      // directly would leave this family on the retracted value.
      expect(
        _style('structure.undetermined').dash,
        const <double>[6, 3, 3, 3],
      );
    });

    test('permille converts to points exactly, and the three HDMI '
        'generations separate on weight ALONE', () {
      final hdmi14 = _style('video.hdmi.1_4');
      final hdmi20 = _style('video.hdmi.2_0');
      final hdmi21 = _style('video.hdmi.2_1');

      // All three solid — solid is the native carrier of digital video.
      expect(hdmi14.dash, isNull);
      expect(hdmi20.dash, isNull);
      expect(hdmi21.dash, isNull);

      expect(hdmi20.widthPt, kSignalBaseWeightPt);
      expect(hdmi14.widthPt, closeTo(kSignalBaseWeightPt * 0.75, 1e-12));
      expect(hdmi21.widthPt, closeTo(kSignalBaseWeightPt * 1.25, 1e-12));

      // THE RATIO IS THE POINT, not the absolute figure: PAL-1's limb (b)
      // is stated as a ratio and `tools/pal1_check.py` evaluates it on the
      // permille values. Rounding to docs/05 §5's display column would
      // have put 1.286 on paper where the authority cleared 1.25.
      expect(hdmi21.widthPt / hdmi14.widthPt, closeTo(1250 / 750, 1e-12));
    });

    test('the 0.5 pt minimum print stroke does not fire on the shipped '
        'palette — if it ever does, PAL-1 is being checked on values the '
        'sheet no longer draws', () {
      final registries = _seeded();
      final clamped = <String>[];
      for (final id in registries.signalFamilies.keys) {
        final def = registries.signalFamilies[id]!;
        final domain = registries.signalDomains[def.domain]!;
        final exact =
            kSignalBaseWeightPt *
            def.effectiveLineWeightPermille(domain) /
            1000;
        if (exact < kMinSignalStrokePt) clamped.add(id.v);
      }
      expect(
        clamped,
        isEmpty,
        reason:
            'these families are lighter than the 0.5 pt floor, so their '
            'emitted weights no longer stand in the permille ratio '
            'tools/pal1_check.py cleared them at, and that tool cannot '
            'see it: ${clamped.join(', ')}',
      );
    });

    test('no two families of ONE domain render alike on dash+weight — '
        'PAL-1’s within-domain limb, over emitted values', () {
      // §6.3: families in one domain "share a hue by construction" and
      // "must still differ in dash, weight, or glyph". THE GLYPH LIMB IS
      // UNAVAILABLE to this renderer — there is no field selecting
      // `glyph` from `glyphAlt` (see `signal_style.dart`'s header) — so
      // the whole burden falls on dash and weight, which makes this the
      // sharper claim rather than the weaker one.
      final registries = _seeded();
      final seen = <String, String>{};
      final collisions = <String>[];
      for (final id in registries.signalFamilies.keys) {
        final style = _style(id.v, registries: registries);
        final key =
            '${style.domainId!.v}|${style.dash?.join(',') ?? 'solid'}'
            '|${style.widthPt}';
        final first = seen[key];
        if (first != null) {
          collisions.add('${style.domainId!.v}: $first vs ${id.v}');
        }
        seen[key] = id.v;
      }
      expect(
        collisions,
        isEmpty,
        reason:
            'these families share a hue AND render identically on every '
            'channel this renderer can vary, so on a greyscale print they '
            'are one line:\n${collisions.join('\n')}',
      );
    });
  });

  group('channel 4 — glyph + tag, and the gap that is counted', () {
    test('the tag degrades one step at a time and never invents an '
        'abbreviation', () {
      final registries = _seeded();

      // Both halves.
      expect(_style('video.hdmi.2_0', registries: registries).tag, 'VID·HD20');
      // Neither: an empty registry is what EVERY document carried before
      // DR-010 seeded them.
      expect(
        _style('video.hdmi.2_0', registries: Registries()).tag,
        'video.hdmi.2_0',
      );
      // Family only — a family whose domain FK dangles.
      final orphan = Registries(
        signalFamilies: {
          const SignalFamilyId('x.y'): const SignalFamilyDef(
            id: SignalFamilyId('x.y'),
            displayName: 'X',
            domain: SignalDomainId('nope'),
            defaultConnector: ConnectorTypeId('conn.rj45'),
            defaultDirection: PortDirection.source,
            defaultTopology: PortTopology.p2p,
            shortTag: 'XY',
          ),
        },
      );
      expect(_style('x.y', registries: orphan).tag, 'XY');
      // Domain only — a family id nothing declares.
      expect(_style('nope.nope', registries: registries).tag, isNot('nope'));
    });

    test('the family token is never empty, so no label is hue-only', () {
      final registries = _seeded();
      for (final id in registries.signalFamilies.keys) {
        expect(_style(id.v, registries: registries).familyToken, isNotEmpty);
      }
      // Including the fully unresolved case, which falls back to the raw
      // id rather than to nothing.
      expect(
        _style('nope.nope', registries: Registries()).familyToken,
        'nope.nope',
      );
    });

    test('the NATIVE glyph is always what is drawn, and every affected '
        'family is flagged (DR-010 §11.10.4)', () {
      // THE DEFECT, PINNED. `SignalDomainDef` carries two shapes and
      // NOTHING SELECTS BETWEEN THEM: there is no tier field, and the
      // three candidate proxies each contradict docs/05 §6.4 (see
      // `signal_style.dart`'s header). So the native glyph is drawn and
      // the whole set is reported.
      final registries = _seeded();
      var flagged = 0;
      for (final id in registries.signalFamilies.keys) {
        final def = registries.signalFamilies[id]!;
        final domain = registries.signalDomains[def.domain]!;
        final style = _style(id.v, registries: registries);
        expect(style.glyph, domain.glyph);
        expect(style.glyph, isNot(domain.glyphAlt));
        if (style.glyphIsUnderdetermined) flagged++;
      }
      // All 55, because all eight domains declare a second shape. That is
      // the honest number and it is deliberately not narrowed: a count
      // that named only the two families with a missing THIRD shape would
      // under-report the gap by 53.
      expect(flagged, registries.signalFamilies.length);
    });

    test('the two families docs/05 §6.4 gives a THIRD shape are drawn with '
        'the domain’s first — recorded, not fixed', () {
      // §6.2 gives `audio.analog` ● / ◐ / ○ and `pwr` ⬢ / ⬡ / ⏚ against
      // two stored slots, so `audio.speaker_cv` (○) and `power.bonding`
      // (⏚) have nowhere to put their shape at all. DR-010 §11.10.4 keeps
      // a per-family glyph out of scope; this test exists so the wrong
      // shape is a KNOWN wrong shape.
      expect(_style('audio.speaker_cv').glyph, '●');
      expect(_style('power.bonding').glyph, '⬢');
      expect(_style('audio.speaker_cv').glyphIsUnderdetermined, isTrue);
      expect(_style('power.bonding').glyphIsUnderdetermined, isTrue);
    });
  });

  group('the degraded path is a real path, not a theoretical one', () {
    test('an EMPTY registry — every document written before DR-010 — '
        'resolves to the neutral ink, solid, 1.00×, and says so', () {
      final style = _style('video.hdmi.2_0', registries: Registries());
      expect(style.resolved, isFalse);
      expect(style.domainId, isNull);
      expect(style.argb, kUnresolvedSignalArgb);
      expect(style.glyph, isEmpty);
      expect(style.glyphIsUnderdetermined, isFalse);
      // The family's OWN overrides still apply where it has them — they
      // are its own declared facts, and discarding them would draw two
      // known-different families alike. `hdmi.2_0` declares neither.
      expect(style.dash, isNull);
      expect(style.widthPt, kSignalBaseWeightPt);
    });

    test('a family whose domain FK dangles keeps its own dash and weight, '
        'and inherits nothing', () {
      final orphan = Registries(
        signalFamilies: {
          const SignalFamilyId('x.y'): const SignalFamilyDef(
            id: SignalFamilyId('x.y'),
            displayName: 'X',
            domain: SignalDomainId('nope'),
            defaultConnector: ConnectorTypeId('conn.rj45'),
            defaultDirection: PortDirection.source,
            defaultTopology: PortTopology.p2p,
            dashOverride: [2000, 3000],
            lineWeightPermilleOverride: 1500,
          ),
        },
      );
      final style = _style('x.y', registries: orphan);
      expect(style.resolved, isFalse);
      expect(style.dash, const <double>[2, 3]);
      expect(style.widthPt, closeTo(kSignalBaseWeightPt * 1.5, 1e-12));
    });
  });

  group('determinism', () {
    test('the same family resolves to an EQUAL value every time — a style '
        'is a value, and a cache keyed on one has to hit', () {
      final a = _style('audio.spdif_optical');
      final b = _style('audio.spdif_optical');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // …and two different families do not collide, so the equality above
      // is not trivially true.
      expect(a, isNot(_style('audio.spdif_coax')));
    });
  });
}
