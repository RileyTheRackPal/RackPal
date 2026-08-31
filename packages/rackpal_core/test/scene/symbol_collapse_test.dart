// CR-103 bank collapse: a bank over eight draws as ONE vector pin.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FLAG IS THE POINT, AND SO IS ITS DEFAULT
// ═══════════════════════════════════════════════════════════════════════
// CR-103 rules that banks over 8 auto-collapse "on first layout AND in the
// symbol preview". `#229` builds it in the SHARED builder, so both callers
// could have it at once — and turning it on for the schematic canvas in
// the same commit would invalidate `schematic_perf_test.dart`'s op-count
// baselines (M2-C's record) and every schematic golden, mid-M4, for a
// canvas nobody is currently editing.
//
// So it is OFF by default and the device builder's preview passes `true`.
// The first test here is the one that says the canvas did not move, and it
// is deliberately first: it is the assertion that makes the rest of this
// change safe to land.
//
// `collapseInSymbol` was the other half. It has defaulted to `true` since
// board 96-L and NOTHING HAS EVER READ IT — 22 seeded banks above the
// threshold carried the value inertly. This is the code that reads it, so
// these tests are also the first evidence that the field does anything.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final class _Measurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

BankDef _bank(String key, {String abbr = 'IN', bool collapse = true}) =>
    BankDef(
      key: key,
      label: 'Bank $key',
      abbr: abbr,
      order: const FracIndex('a0'),
      // `symbolSide` is left deliberately UNSTATED, which is its default:
      // these fixtures test collapse, and pinning the edge here would hide
      // the fact that `layOutSymbolEdges` collapses per (edge, bank).
      collapseInSymbol: collapse,
    );

PortDef _port(int i, {String? bank}) => PortDef(
  key: PortKey('p$i'),
  label: 'IN$i',
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  order: FracIndex('a${i.toString().padLeft(3, '0')}'),
  bankKey: bank,
);

TemplateBody _body({
  required int ports,
  String? bank = 'b1',
  bool collapse = true,
}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'SW',
  displayName: 'Switch',
  frontU: 1,
  ports: [for (var i = 0; i < ports; i++) _port(i, bank: bank)],
  banks: bank == null ? [] : [_bank(bank, collapse: collapse)],
);

int _pinCount(RenderedSymbol s) =>
    SymbolSide.values.fold(0, (n, side) => n + s.ports[side]!.length);

RenderedSymbol _sized(TemplateBody body, {required bool collapse}) =>
    sizeSymbolForBody(
      id: 'preview',
      designator: 'SW-1',
      name: '',
      body: body,
      measurer: _Measurer(),
      collapseBanks: collapse,
    ).geometry;

void main() {
  group('collapse is OFF unless asked, which is what protects the canvas', () {
    test('a seeded 48-port switch still draws 48 pins by default', () {
      final body = buildSeedCatalog()['N01']!;
      final drawn = _sized(body, collapse: false);
      expect(
        _pinCount(drawn),
        body.ports.length,
        reason: 'the schematic canvas moved, and its baselines did not',
      );
      expect(
        drawn.allPorts.where((p) => p.isCollapsed),
        isEmpty,
        reason: 'nothing may collapse while the flag is false',
      );
    });

    test('the default really is false — an omitted flag collapses nothing', () {
      final body = _body(ports: 24);
      final implicit = sizeSymbolForBody(
        id: 'preview',
        designator: 'SW-1',
        name: '',
        body: body,
        measurer: _Measurer(),
      ).geometry;
      expect(_pinCount(implicit), 24);
    });
  });

  group('with collapse on, a bank over eight becomes one vector pin', () {
    test('a seeded 48-port bank draws as one pin labelled 1..48', () {
      final body = buildSeedCatalog()['N01']!;
      final drawn = _sized(body, collapse: true);
      final collapsed = drawn.allPorts.where((p) => p.isCollapsed).toList();
      expect(collapsed, isNotEmpty, reason: 'N01 has a bank of 48');

      final biggest = collapsed.reduce(
        (a, b) => a.collapsedCount >= b.collapsedCount ? a : b,
      );
      expect(biggest.collapsedCount, greaterThan(kBankCollapseThreshold));
      expect(
        biggest.label,
        endsWith('[1..${biggest.collapsedCount}]'),
        reason: 'CR-103 asks for the bracketed count in the label',
      );
      expect(
        _pinCount(drawn),
        lessThan(body.ports.length),
        reason: 'collapsing must actually remove pins',
      );
    });

    test('the collapsed pin keeps a REAL port key, so it stays clickable', () {
      final body = _body(ports: 12);
      final drawn = _sized(body, collapse: true);
      final pin = drawn.allPorts.single;
      expect(pin.collapsedCount, 12);
      expect(
        body.ports.map((p) => p.key.v),
        contains(pin.key),
        reason: 'a synthesised key would make the pin unhittable',
      );
      expect(pin.bankKey, 'b1');
    });

    test('exactly eight does NOT collapse and nine DOES — the threshold is '
        '"over 8", not "8 or more"', () {
      expect(kBankCollapseThreshold, 8);
      expect(_pinCount(_sized(_body(ports: 8), collapse: true)), 8);
      expect(_pinCount(_sized(_body(ports: 9), collapse: true)), 1);
    });

    test('collapseInSymbol: false is the per-bank opt-out and is honoured', () {
      final body = _body(ports: 24, collapse: false);
      expect(_pinCount(_sized(body, collapse: true)), 24);
    });

    test('an unbanked port never collapses, however many there are', () {
      final body = _body(ports: 20, bank: null);
      expect(_pinCount(_sized(body, collapse: true)), 20);
    });
  });

  group('the sizer and the builder cannot disagree about the count', () {
    test('the reserved box shrinks with the pin run, on every seeded '
        'template that has a bank over the threshold', () {
      final seed = buildSeedCatalog();
      var checked = 0;
      for (final entry in seed.entries) {
        final body = entry.value;
        final over = body.banks.where((b) {
          final n = body.ports.where((p) => p.bankKey == b.key).length;
          return b.collapseInSymbol && n > kBankCollapseThreshold;
        });
        if (over.isEmpty) continue;
        checked++;

        final loose = sizeSymbolForBody(
          id: 'x',
          designator: 'X-1',
          name: '',
          body: body,
          measurer: _Measurer(),
        );
        final tight = sizeSymbolForBody(
          id: 'x',
          designator: 'X-1',
          name: '',
          body: body,
          measurer: _Measurer(),
          collapseBanks: true,
        );
        final who = entry.key;
        expect(
          _pinCount(tight.geometry),
          lessThan(_pinCount(loose.geometry)),
          reason: who,
        );

        // THE INVARIANT THIS WHOLE REFACTOR EXISTS FOR, and it is stated
        // DIRECTLY rather than through a proxy, because the proxy was
        // wrong. The first draft asserted that collapsing never makes the
        // reserved box taller. V01 refuted it: 67gu loose, 69gu tight.
        //
        // That is CORRECT and it is worth understanding. The reserved
        // height carries the top/bottom LABEL BANDS, whose depth is the
        // WIDEST label on those edges, because #96-A turned those labels a
        // quarter turn to read inward. Collapsing replaces sixteen short
        // labels with one long `AUX[1..16]`, so the band gets deeper even
        // as the pin run gets shorter. A rule that forbade it would have
        // forced the sizer to reserve less room than the builder draws in.
        //
        // What must actually hold is that the box the LAYOUT reserves
        // contains the box the BUILDER draws — the property the scene
        // builder's own comment describes as rounding "UP to at least the
        // drawn one". A sizer counting 48 pins while the builder draws 1
        // breaks it in one direction; a band the sizer never measured
        // breaks it in the other, and nothing else here would report
        // either.
        for (final sized in [loose, tight]) {
          expect(
            sized.heightGu * kSchematicUnitsPerGrid,
            greaterThanOrEqualTo(sized.geometry.bodyRect.height - 1e-9),
            reason: '$who reserved less height than it draws',
          );
          expect(
            sized.widthGu * kSchematicUnitsPerGrid,
            greaterThanOrEqualTo(sized.geometry.bodyRect.width - 1e-9),
            reason: '$who reserved less width than it draws',
          );
        }
      }
      expect(
        checked,
        greaterThan(0),
        reason:
            'no seeded template has a collapsible bank over 8; the '
            'threshold or the seed changed and this test now proves nothing',
      );
    });
  });

  group('the vector pin is drawn, and only for collapsed pins', () {
    test('a collapsed symbol emits the bus tick; an uncollapsed one does '
        'not', () {
      final body = _body(ports: 12);
      final measurer = _Measurer();
      const palette = SchematicPalette();

      final plain = buildSymbolLayer(
        _sized(body, collapse: false),
        palette: palette,
        measurer: measurer,
      );
      final collapsed = buildSymbolLayer(
        _sized(body, collapse: true),
        palette: palette,
        measurer: measurer,
      );

      expect(
        plain.ops.whereType<OpLine>().where(
          (o) => o.s.argb == palette.portStroke,
        ),
        isEmpty,
        reason: 'no pin collapsed, so no bus tick may be drawn',
      );
      expect(
        collapsed.ops.whereType<OpLine>().where(
          (o) => o.s.argb == palette.portStroke,
        ),
        hasLength(1),
        reason: 'one collapsed pin, one tick',
      );
    });
  });
}
