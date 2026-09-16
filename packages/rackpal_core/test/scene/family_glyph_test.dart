// #124 — the family glyph drawn as geometry.
//
// ═════════════════════════════════════════════════════════════════════
// THE TEST THIS FILE EXISTS FOR IS `every seeded domain has a shape`
// ═════════════════════════════════════════════════════════════════════
// It is the gate that would have caught the defect, and it is the one
// that has to keep working. Before `family_glyph.dart`, ALL EIGHT domains
// went down the text path: the glyph was a character in a run measured by
// `PdfFontMeasurer` over Jost — a text face carrying none of the four
// Unicode blocks these symbols live in — and painted on screen by a
// `TextPainter` that fell back to a system face and drew it full width.
// Measured near-zero, drawn wide, net name on top of the token.
//
// Nothing asserted a relationship between the measured width and the
// painted one, which is why it reached a user rather than a build.
//
// The mapping is checked against `buildSeedSignalDomains()` ITSELF rather
// than against a transcribed list of characters, because a transcription
// is exactly what silently rots when a ninth domain is seeded.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// A measurer that returns ZERO for every string — the pathological case
/// the real one produced for the glyph, made total.
///
/// If the glyph still travelled through text, a pennant measured with this
/// would be the same width whether the glyph were there or not. The
/// geometry path is the only thing that can make the two differ.
final class _ZeroMeasurer implements TextMeasurer {
  const _ZeroMeasurer();

  @override
  TextMetrics measureText(String text, TextStyleSpec style) =>
      const TextMetrics(
        advanceWidth: 0,
        ascent: 0,
        descent: 0,
        capHeight: 0,
        xHeight: 0,
        lineHeight: 0,
      );
}

void main() {
  group('the mapping covers the shipped registry', () {
    test('EVERY seeded domain resolves a shape for BOTH its glyph and its '
        'glyphAlt', () {
      // Walked off the seed, not a transcription. A ninth domain, or a
      // changed character, lands here rather than in the fallback — where
      // it would look fine on any machine whose system font happens to
      // carry it, which is every developer's and no installer's.
      final domains = buildSeedSignalDomains();
      expect(domains, hasLength(8));

      final unmapped = <String>[];
      for (final domain in domains.values) {
        for (final glyph in [domain.glyph, domain.glyphAlt]) {
          if (familyGlyphFor(glyph) == null) {
            unmapped.add('${domain.id.v}: "$glyph"');
          }
        }
      }
      expect(
        unmapped,
        isEmpty,
        reason:
            'a seeded glyph with no shape falls back to a measured text '
            'run — which is the defect #124 fixed, arriving again',
      );
    });

    test('the eight NATIVE glyphs are eight DISTINCT shapes', () {
      // Channel 4a's whole job is telling eight domains apart in
      // greyscale (docs/05 §6.1). Two domains mapped to one shape would
      // pass the coverage test above and lose the channel anyway.
      final shapes = <FamilyGlyphShape>{
        for (final domain in buildSeedSignalDomains().values)
          familyGlyphFor(domain.glyph)!.shape,
      };
      expect(shapes, hasLength(8));
    });

    test('EVERY seeded FAMILY glyph resolves a shape too (DR-181)', () {
      // The domains' sixteen were covered above from the day this file
      // existed. DR-181 gave 26 families a glyph of their own, and two of
      // those codepoints — `○` and `⏚` — were in no domain slot and so in
      // no shape table: they would have fallen back to a measured text
      // run in a font that carries neither, which is `#124` arriving
      // again on a different row.
      final domains = buildSeedSignalDomains();
      final unmapped = <String>[];
      var stated = 0;
      for (final def in buildSeedSignalFamilies().values) {
        final glyph = def.effectiveGlyph(domains[def.domain]!);
        if (def.glyphOverride != null) stated++;
        if (familyGlyphFor(glyph) == null) {
          unmapped.add('${def.id.v}: "$glyph"');
        }
      }
      expect(stated, 26, reason: 'the overrides DR-181 §11.180.2 counted');
      expect(unmapped, isEmpty);
    });

    test('fill encodes tier — native is filled, the alternate is not', () {
      // docs/05 §5.
      for (final domain in buildSeedSignalDomains().values) {
        expect(familyGlyphFor(domain.glyph)!.filled, isTrue);
        expect(familyGlyphFor(domain.glyphAlt)!.filled, isFalse);
      }
    });

    test('the three tiers of a THREE-glyph domain are three DISTINCT '
        'drawings, not two (DR-181)', () {
      // THE CASE THIS GROUP GAINED AT `#82`. `◐` was mapped to the hollow
      // circle, which is `○`'s drawing. That was harmless for as long as
      // nothing drew `○` — and `audio.speaker_cv` draws it now, so the
      // mapping would have made a constant-voltage speaker run and a
      // low-impedance one THE SAME PICTURE. They are the pair on a job
      // that must never be confused, which is why the channel exists.
      for (final trio in [
        ['●', '◐', '○'],
        ['⬢', '⬡', '⏚'],
      ]) {
        final drawn = <FamilyGlyph>{};
        for (final g in trio) {
          final shape = familyGlyphFor(g);
          expect(shape, isNotNull, reason: g);
          drawn.add(shape!);
        }
        expect(drawn, hasLength(3), reason: trio.join(' '));
      }
    });

    test('an unknown glyph resolves to null — the defined fallback', () {
      // Registry data, extensible in M4. `null` is what routes the layer
      // back to the measured text run rather than drawing nothing, which
      // would drop one of the three channels that survive a greyscale
      // laser.
      expect(familyGlyphFor('¤'), isNull);
      expect(familyGlyphFor(''), isNull);
    });
  });

  group('the width is computed, which is the fix', () {
    test('the advance depends on the type size ALONE and on no font', () {
      // The defect in one line: a width that came from measuring a
      // character the font did not have. This one is arithmetic.
      expect(familyGlyphAdvance(8), closeTo(8 * (0.72 + 0.22), 1e-12));
      expect(familyGlyphAdvance(16), closeTo(2 * familyGlyphAdvance(8), 1e-12));
      expect(familyGlyphAdvance(0), 0);
    });

    test('the drawn shape fits INSIDE the advance it claims', () {
      // A shape wider than its advance is the same defect with the sign
      // flipped: the tag would land on the glyph instead of the glyph
      // being run over. Asserted over every shape, because the star and
      // the cross are the two whose extremes are not obvious from the
      // construction.
      //
      // OVER EVERY FAMILY GLYPH TOO SINCE DR-181, which is what puts the
      // new shapes under this: `⏚` is an open figure of four subpaths and
      // `◐` is the one shape whose geometry depends on its own tier, so
      // both are exactly the kind that could sit outside the box the
      // advance reserves without anything else noticing.
      const sizePt = 8.0;
      final advance = familyGlyphAdvance(sizePt);
      final domains = buildSeedSignalDomains();
      final everyGlyph = <String>{
        for (final domain in domains.values) ...[
          domain.glyph,
          domain.glyphAlt,
        ],
        for (final def in buildSeedSignalFamilies().values)
          def.effectiveGlyph(domains[def.domain]!),
      };
      for (final glyph in everyGlyph) {
        {
          final op =
              familyGlyphOp(
                    familyGlyphFor(glyph)!,
                    const DPt(0, 0),
                    sizePt,
                    0xFF000000,
                    hollowWidthPt: 0.5,
                  )
                  as OpPath;
          var minX = double.infinity;
          var maxX = double.negativeInfinity;
          var minY = double.infinity;
          var maxY = double.negativeInfinity;
          for (final c in op.p.commands) {
            final pts = switch (c) {
              MoveTo(:final x, :final y) => <(double, double)>[(x, y)],
              LineTo(:final x, :final y) => <(double, double)>[(x, y)],
              CubicTo(
                :final x1,
                :final y1,
                :final x2,
                :final y2,
                :final x3,
                :final y3,
              ) =>
                <(double, double)>[(x1, y1), (x2, y2), (x3, y3)],
              _ => const <(double, double)>[],
            };
            for (final (x, y) in pts) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
          final reason = '"$glyph"';
          expect(minX, greaterThanOrEqualTo(-1e-9), reason: reason);
          expect(maxX, lessThanOrEqualTo(advance + 1e-9), reason: reason);
          // AND VERTICALLY CENTRED on the line it was placed at, so it
          // sits on the tag's centre rather than hanging off it.
          expect(minY, closeTo(-maxY, 1e-9), reason: reason);
          // Inside the cap height it claims, which is what keeps it within
          // the pennant box the ink bounds are computed from.
          const cap = sizePt * kFamilyGlyphCapFactor;
          expect(maxY - minY, lessThanOrEqualTo(cap + 1e-9), reason: reason);
        }
      }
    });

    test('an INKED glyph carries a fill and NO stroke; a hollow one the '
        'reverse, and NEITHER carries both', () {
      // The invariant `net_label_layer_test`'s `_isGlyphPath` reads to
      // tell a glyph from a pennant — a pennant is the only path carrying
      // both. Pinned here so a change to the emitter breaks this rather
      // than quietly turning those tests into assertions about the wrong
      // shape.
      //
      // DR-181's HALF TIER IS WHY THIS CASE NOW SWEEPS ALL THREE. A
      // half-disc outlined for crispness carries both paints and would
      // have made every `audio.speaker_lowz` flag read as a pennant to
      // three scene tests, which would have counted the wrong paths and
      // still passed.
      OpPath opFor(FamilyGlyphFill fill) =>
          familyGlyphOp(
                FamilyGlyph(FamilyGlyphShape.square, fill: fill),
                const DPt(0, 0),
                8,
                0xFF102030,
                hollowWidthPt: 0.5,
              )
              as OpPath;

      for (final fill in [FamilyGlyphFill.filled, FamilyGlyphFill.half]) {
        final op = opFor(fill);
        expect(op.fill?.argb, 0xFF102030, reason: fill.name);
        expect(op.stroke, isNull, reason: fill.name);
      }

      final hollow = opFor(FamilyGlyphFill.hollow);
      expect(hollow.fill, isNull);
      expect(hollow.stroke?.argb, 0xFF102030);
      expect(hollow.stroke?.widthPt, 0.5);

      for (final fill in FamilyGlyphFill.values) {
        final op = opFor(fill);
        expect(
          op.fill != null && op.stroke != null,
          isFalse,
          reason: '${fill.name}: a glyph carrying both reads as a pennant',
        );
      }
    });
  });

  group('the parity the defect broke', () {
    test('a pennant is WIDER than its text when the font measures nothing', () {
      // ═══════════════════════════════════════════════════════════════
      // THE REGRESSION GATE, STATED AS THE THING THAT WENT WRONG
      // ═══════════════════════════════════════════════════════════════
      // Jost measured the glyph at ~0 and the screen drew it at full
      // width. Under a measurer that returns 0 for EVERYTHING, a pennant
      // whose channel 4 travels through TEXT has zero content width — so
      // its width is padding and tip alone, and anything drawn inside it
      // overflows. A pennant whose glyph is GEOMETRY still reserves the
      // glyph's advance, because that figure never went near a font.
      //
      // This is the property the old code could not have: the difference
      // between the two is exactly `familyGlyphAdvance`.
      const measurer = _ZeroMeasurer();
      const style = NetLabelStyle();

      final resolved = resolveSignalStyle(
        family: const SignalFamilyId('video.hdmi.2_0'),
        registries: buildSeedRegistries(),
      );
      expect(resolved.resolved, isTrue);
      expect(familyGlyphFor(resolved.glyph), isNotNull);

      final unresolved = resolveSignalStyle(
        family: const SignalFamilyId('nothing.at.all'),
        registries: buildSeedRegistries(),
      );
      expect(unresolved.resolved, isFalse);

      final withGlyph = netLabelTokenWidth(
        resolved,
        measurer: measurer,
        style: style,
      );
      final withoutGlyph = netLabelTokenWidth(
        unresolved,
        measurer: measurer,
        style: style,
      );

      expect(withoutGlyph, 0, reason: 'no shape, no text: the fallback');
      expect(
        withGlyph,
        closeTo(familyGlyphAdvance(style.tokenSizePt), 1e-12),
        reason:
            'the glyph reserves its own width without asking a font, '
            'which is the whole of #124',
      );
      expect(withGlyph, greaterThan(withoutGlyph));
    });
  });
}
