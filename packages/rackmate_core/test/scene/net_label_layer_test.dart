// `buildNetLabelLayer` — DR-001's DEFAULT render of a `Link`.
//
// ─────────────────────────────────────────────────────────────────────
// THE THREE CLAIMS WITH TEETH, AND WHY EACH IS HERE
// ─────────────────────────────────────────────────────────────────────
//  1. A LINK IS A PAIR OF LABELS AND NOT A WIRE. That is canon §11.1's
//     ruling and it is "not to be re-argued in any document", so it is
//     asserted rather than assumed: two labels per link, the identical
//     string on both, and no `OpPolyline` anywhere in the layer.
//  2. THE OPS PARTITION BY DOMAIN, CONTIGUOUSLY. The per-domain
//     sub-picture is "what lets a domain filter switch to drawn mode
//     without rebuilding seven other pictures" (roadmap M2 risks), and it
//     only exists if every one of a domain's ops is inside one `IntRange`
//     and no other domain's op is. Scatter them and the ranges still
//     look plausible while the optimisation is gone, so the test checks
//     the partition itself, not the presence of the map.
//  3. HUE IS NEVER ALONE ON A STUB. Every leader carries its family's
//     effective dash and weight, and every pennant carries its family
//     token — the three channels that survive a CVD, a greyscale laser
//     and a photocopy (docs/05 §6.1). A regression that dropped them
//     would leave a drawing that looks right on a screen and fails for
//     the ~8% of installers the palette exists for.
//
// The fixture is built with the SEEDED registries (DR-010) and spreads
// its links across four domains on purpose: a single-domain document
// cannot fail claim 2 at all.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

import 'op_digest.dart';

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

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 7, 28),
  updatedAt: DateTime.utc(2026, 7, 28),
  updatedBy: 'test',
);

const _position = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

PortDef _port(
  String key,
  String family, {
  required PortDirection direction,
  required int order,
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: _position,
  order: FracIndex('a${order.toString().padLeft(3, '0')}'),
  direction: direction,
);

/// One wiring row: source device/port, sink device/port, the `Service`
/// family (null ⇒ no service at all, so the link has no net to name), and
/// whether a `Net` backs it.
typedef _Wire = ({
  String fromKey,
  String toKey,
  String? service,
  bool named,
});

/// A four-domain document.
///
/// [reversed] flips every insertion order without changing the content —
/// the probe for a hash-iteration order leaking into the drawing, exactly
/// as `schematic_scene_test.dart` uses it.
RackDocument _document({
  bool reversed = false,
  bool seedRegistries = true,
  List<_Wire>? wiring,
  Map<SignalFamilyId, Rgb> overrides = const {},
}) {
  final doc = RackDocument(
    id: const Uuid('0190f200-0000-7000-8000-000000000000'),
    appVersion: 'test',
    createdAt: DateTime.utc(2026, 7, 28),
    modifiedAt: DateTime.utc(2026, 7, 28),
    meta: _meta(),
  );
  if (seedRegistries) {
    doc.registries.signalDomains.addAll(buildSeedSignalDomains());
    doc.registries.signalFamilies.addAll(buildSeedSignalFamilies());
  }
  doc.settings.familyColorOverrides.addAll(overrides);

  final rack = Rack(
    id: const Uuid('0190f201-0000-7000-8000-000000000001'),
    name: 'RACK',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.racks[rack.id] = rack;

  // A source and a sink, each carrying several ports. `net.` lands on the
  // TOP edge and `power.` on the BOTTOM (docs/05 §3's rule), so the fixture
  // exercises all four sides.
  //
  // TWO PORTS ON EACH VERTICAL EDGE, DELIBERATELY. A top or bottom pennant
  // is horizontal and far wider than the 2 gu pin pitch, so with one pin an
  // edge the comb that staggers them is unreachable and a mutation deleting
  // it survives every assertion here — which is exactly what happened. Two
  // is the smallest number that makes the overlap test able to see it.
  const families = <(String, String)>[
    ('vid', 'video.hdmi.2_0'),
    ('aud', 'audio.line_unbal'),
    ('net', 'net.ethernet'),
    ('net2', 'net.poe'),
    ('pwr', 'power.ac_iec'),
    ('pwr2', 'power.ac_branch'),
  ];
  TemplateBody body(PortDirection direction) => TemplateBody(
    manufacturer: 'Generic',
    model: direction == PortDirection.source ? 'SRC' : 'SNK',
    displayName: 'D',
    frontU: 1,
    side: OccupancySide.front,
    mountMethod: MountMethod.rackEars,
    ports: [
      for (var i = 0; i < families.length; i++)
        _port(families[i].$1, families[i].$2, direction: direction, order: i),
    ],
  );

  final bodies = <String, TemplateBody>{
    'SRC': body(PortDirection.source),
    'SNK': body(PortDirection.sink),
  };
  for (final id in reversed ? bodies.keys.toList().reversed : bodies.keys) {
    doc.templates['$id@1'] = TemplateSnapshot(
      templateId: TemplateId(id),
      version: 1,
      contentHash: 'sha256:$id',
      body: bodies[id]!,
      capturedAt: DateTime.utc(2026, 7, 28),
    );
  }

  const roster = <(String, String, int)>[
    ('SRC-1', 'SRC', 10),
    ('SNK-1', 'SNK', 9),
  ];
  final devices = <String, DeviceInstance>{};
  for (final row in reversed ? roster.reversed : roster) {
    final ordinal = roster.indexOf(row).toString().padLeft(12, '0');
    final id = Uuid('0190f202-0000-7000-8000-$ordinal');
    final device = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(row.$2),
        version: 1,
        contentHash: 'sha256:${row.$2}',
      ),
      designator: row.$1,
      name: '',
      placement: RailPlacement(
        rackId: rack.id,
        ruIndex: row.$3,
        face: Face.front,
      ),
      meta: _meta(),
    );
    doc.devices[id] = device;
    devices[row.$1] = device;
  }

  Port materialise(String designator, String key) {
    final device = devices[designator]!;
    final id = derivePortId(device.id, PortKey(key));
    return doc.ports[id] ??= Port(
      id: id,
      deviceId: device.id,
      designator: key,
      templatePortKey: PortKey(key),
    );
  }

  final rows =
      wiring ??
      <_Wire>[
        for (final f in families)
          (
            fromKey: f.$1,
            toKey: f.$1,
            service: f.$2,
            named: true,
          ),
      ];
  final ordered = reversed ? rows.reversed.toList() : rows;
  for (var n = 0; n < ordered.length; n++) {
    final row = ordered[n];
    // The INDEX IN `rows`, not in the walk order, so `reversed` changes
    // insertion order and nothing else. `indexOf` would collapse two
    // identical rows onto one id, which is how a 40-link fixture quietly
    // became a 1-link one.
    final index = reversed ? rows.length - 1 - n : n;
    final pad = index.toString().padLeft(12, '0');
    final id = Uuid('0190f203-0000-7000-8000-$pad');
    final from = materialise('SRC-1', row.fromKey);
    final to = materialise('SNK-1', row.toKey);

    final services = <Service>[];
    if (row.service != null) {
      final netId = Uuid('0190f204-0000-7000-8000-$pad');
      if (row.named) {
        doc.nets[netId] = Net(
          id: netId,
          // `IdFormat('N{SEQ:3}')`, ProjectSettings' own default.
          name: 'N${(index + 1).toString().padLeft(3, '0')}',
          signalFamily: SignalFamilyId(row.service!),
          meta: _meta(),
        );
      }
      services.add(
        Service(
          id: 's$index',
          signalFamily: SignalFamilyId(row.service!),
          netId: netId,
        ),
      );
    }

    doc.links[id] = Link(
      id: id,
      designator: 'W${index.toString().padLeft(3, '0')}',
      media: const MediaTypeId('media.cat6'),
      order: FracIndex('a$index'),
      meta: _meta(),
      services: services,
      conductors: [
        Conductor(from: PortEndpoint(from.id), to: PortEndpoint(to.id)),
      ],
    );
  }
  return doc;
}

SchematicScene _build(RackDocument doc) =>
    buildSchematicScene(doc: doc, measurer: _Measurer());

/// The four channels this document's `net.ethernet` link should draw in,
/// resolved through the same public entry point production uses.
SignalStyle _styleOf(RackDocument doc, String family) => resolveSignalStyle(
  family: SignalFamilyId(family),
  registries: doc.registries,
  colorOverrides: doc.settings.familyColorOverrides,
);

void main() {
  group('DR-001 — a Link is a pair of labels, not a wire', () {
    test('two labels per link, one per pin, and no polyline anywhere', () {
      final doc = _document();
      final built = _build(doc);

      expect(built.netLabels, hasLength(2 * doc.links.length));
      expect(built.scene.ops.whereType<OpPolyline>(), isEmpty);
      for (final link in doc.links.values) {
        final pair = built.netLabels.where((l) => l.linkId == link.id).toList();
        expect(pair, hasLength(2));
        // §11.5: "both flags of a net show the identical string".
        expect(pair[0].netName, pair[1].netName);
        // One at each end, never twice at the same pin.
        expect(pair[0].deviceId, isNot(pair[1].deviceId));
      }
    });

    test('the layer has no density term — the same link count draws the '
        'same way at 4 links and at 40', () {
      // DR-001 §11.1.1: render mode is a function of the ACTIVE FILTER,
      // "not a user setting and not a threshold". A per-link op count that
      // changed with document size would be the deleted auto-degradation
      // (canon §11.1.3 item 8) growing back.
      final small = _build(_document());
      const big = 40;
      final wide = _build(
        _document(
          wiring: <_Wire>[
            for (var i = 0; i < big; i++)
              (
                fromKey: 'vid',
                toKey: 'vid',
                service: 'video.hdmi.2_0',
                named: true,
              ),
          ],
        ),
      );
      final perLabelSmall =
          (small.scene.ops.length - _symbolOps(small)) / small.netLabels.length;
      final perLabelWide =
          (wide.scene.ops.length - _symbolOps(wide)) / wide.netLabels.length;
      expect(perLabelWide, perLabelSmall);
      expect(wide.netLabels, hasLength(2 * big));
    });
  });

  group('per-domain sub-pictures — the M2-E dependency', () {
    test('every domain’s ops are ONE contiguous range, and the ranges '
        'partition the whole label layer', () {
      final built = _build(_document());
      final ranges = built.domainFragments.values.toList()
        ..sort((a, b) => a.start.compareTo(b.start));

      expect(ranges, hasLength(4), reason: 'four domains are wired');
      expect(built.unresolvedDomainFragment, isNull);

      // Contiguous, in order, no gaps and no overlaps.
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].start, ranges[i - 1].end);
      }
      // …and together they cover exactly the ops that are not symbols.
      final covered = ranges.fold<int>(0, (n, r) => n + r.end - r.start);
      expect(covered, built.scene.ops.length - _symbolOps(built));
    });

    test('a domain fragment contains EVERY op of its domain and NO op of '
        'another — the property that makes a filter cheap', () {
      final doc = _document();
      final built = _build(doc);

      for (final entry in built.domainFragments.entries) {
        final hue = _domainHue(doc, entry.key);
        final ops = built.scene.ops.sublist(entry.value.start, entry.value.end);
        // Every leader inside the range is this domain's hue…
        for (final line in ops.whereType<OpLine>()) {
          expect(line.s.argb, hue);
        }
        // …and no leader of this domain's hue sits outside it.
        for (var i = 0; i < built.scene.ops.length; i++) {
          if (i >= entry.value.start && i < entry.value.end) continue;
          final op = built.scene.ops[i];
          if (op is OpLine && op.s.argb == hue) {
            fail('a $hue leader at op $i escaped ${entry.key.v}’s fragment');
          }
        }
      }
    });

    test('fragmentFor reaches a domain sub-picture by key', () {
      final built = _build(_document());
      final domain = built.domainFragments.keys.first;
      final sub = built.scene.fragmentFor(domainFragmentKey(domain));
      expect(
        sub.ops,
        hasLength(
          built.domainFragments[domain]!.end -
              built.domainFragments[domain]!.start,
        ),
      );
    });

    test('domains emit in ascending id and the UNRESOLVED run comes last', () {
      // Ascending id rather than §11.2's filter-bar order, because no
      // model field carries that order — see the layer's header. What is
      // load-bearing is only that the order is TOTAL.
      final doc = _document(
        wiring: <_Wire>[
          (fromKey: 'net', toKey: 'net', service: 'net.ethernet', named: true),
          (fromKey: 'vid', toKey: 'vid', service: 'nope.nope', named: true),
          (
            fromKey: 'aud',
            toKey: 'aud',
            service: 'audio.line_unbal',
            named: true,
          ),
        ],
      );
      final built = _build(doc);
      final ordered = built.domainFragments.entries.toList()
        ..sort((a, b) => a.value.start.compareTo(b.value.start));
      expect(
        ordered.map((e) => e.key.v).toList(),
        <String>['audio.analog', 'net'],
      );
      expect(built.unresolvedDomainFragment, isNotNull);
      expect(
        built.unresolvedDomainFragment!.start,
        greaterThanOrEqualTo(ordered.last.value.end),
      );
    });

    test('an unresolved run is registered as a fragment but is NOT a ninth '
        'domain', () {
      final built = _build(_document(seedRegistries: false));
      expect(built.domainFragments, isEmpty);
      expect(built.unresolvedDomainFragment, isNotNull);
      expect(
        built.scene.fragments[kUnresolvedDomainFragmentKey],
        built.unresolvedDomainFragment,
      );
    });
  });

  group('the four channels reach the ops', () {
    test('hue, dash and weight land on the leader, exactly as '
        'resolveSignalStyle answers', () {
      final doc = _document();
      final built = _build(doc);
      final style = _styleOf(doc, 'audio.line_unbal');
      final range =
          built.domainFragments[const SignalDomainId('audio.analog')]!;
      final leaders = built.scene.ops
          .sublist(range.start, range.end)
          .whereType<OpLine>()
          .toList();

      expect(leaders, hasLength(2));
      for (final leader in leaders) {
        expect(leader.s.argb, style.argb);
        expect(leader.s.dash, style.dash);
        expect(leader.s.widthPt, style.widthPt);
      }
      // The dash is real, not null-by-accident: analog audio is 6,3.
      expect(style.dash, isNotNull);
    });

    test('SOLID reaches the op as `null`, never as an empty dash list', () {
      // `effectiveDashPattern` spells solid `[]`; `Stroke` spells it
      // `null`, and an empty pattern handed to `dashPath`/`PdfGraphics` is
      // not a solid line — it is a different drawing or a hang.
      final doc = _document(
        wiring: <_Wire>[
          (fromKey: 'net', toKey: 'net', service: 'net.ethernet', named: true),
        ],
      );
      final built = _build(doc);
      final leaders = built.scene.ops
          .whereType<OpLine>()
          .where(
            (l) => l.s.argb == _domainHue(doc, const SignalDomainId('net')),
          )
          .toList();
      expect(leaders, hasLength(2));
      for (final leader in leaders) {
        expect(leader.s.dash, isNull);
      }
    });

    test('the family token is drawn on every pennant, so no label is '
        'hue-only', () {
      // § 6.1's glyph+tag is ONE channel and it must reach every flag,
      // because hue alone is the one thing that section forbids. Since
      // #124 it reaches in TWO ops rather than one — the glyph as a path
      // whose width is computed, the tag as a measured run — so the claim
      // is asserted over both halves. Asserting only the text would pass
      // with the glyph silently dropped, which is the failure mode the
      // whole four-channel design exists to prevent.
      final doc = _document();
      final built = _build(doc);
      final style = _styleOf(doc, 'video.hdmi.2_0');
      final texts = built.scene.ops.whereType<OpText>().map((t) => t.text);
      expect(style.familyToken, '▲ VID·HD20');
      expect(style.tag, 'VID·HD20');
      expect(texts, contains(style.tag));
      // Two labels per link and one tag run each.
      expect(
        built.scene.ops.whereType<OpText>().where((t) => t.text == style.tag),
        hasLength(2),
      );
      // AND THE GLYPH, AS GEOMETRY. The raw character must NOT be drawn
      // anywhere — that is the defect: Jost measures it near-zero and the
      // screen falls back to a face that paints it full width.
      expect(texts, isNot(contains(style.familyToken)));
      expect(texts.where((t) => t.contains(style.glyph)), isEmpty);
      final range =
          built.domainFragments[const SignalDomainId('video.digital')]!;
      expect(
        _glyphPaths(built.scene.ops.sublist(range.start, range.end)),
        hasLength(2),
      );
    });

    test('AC-054: a familyColorOverride reaches the drawn leader, and only '
        'that family’s', () {
      // `net.ethernet` and `net.poe` share the `net` domain and therefore
      // share a sub-picture. Overriding ONE splits the hue inside a single
      // domain range — which is what AC-054's "override any hue" means at
      // the drawing, and what a per-DOMAIN override would not do.
      final doc = _document(
        overrides: {const SignalFamilyId('net.ethernet'): const Rgb(1, 2, 3)},
      );
      final built = _build(doc);
      final range = built.domainFragments[const SignalDomainId('net')]!;
      final hues = built.scene.ops
          .sublist(range.start, range.end)
          .whereType<OpLine>()
          .map((l) => l.s.argb)
          .toSet();
      expect(hues, <int>{
        0xFF010203,
        _domainHue(doc, const SignalDomainId('net')),
      });
    });

    test('the pennant fill is the hue at 12% and its outline is the hue at '
        'full strength (§11.5)', () {
      final doc = _document();
      final built = _build(doc);
      final style = _styleOf(doc, 'video.hdmi.2_0');
      final range =
          built.domainFragments[const SignalDomainId('video.digital')]!;
      final pennants = _pennantPaths(
        built.scene.ops.sublist(range.start, range.end),
      );
      expect(pennants, hasLength(2));

      // ── THE FILL IS OPAQUE, AND STILL THE 12% COLOUR ───────────────
      // docs/05 §11.5's "domain colour at 12%" is what the flag LOOKS
      // like; it was emitted as a translucent fill, which composites
      // against whatever is behind — the sheet on an unfiltered sheet,
      // and a drawn wire once one is routed under it. The blend is done
      // at build time now, so the same colour lands regardless of what is
      // underneath, which is the whole of the field's complaint.
      final paper = const SchematicPalette().bodyFill;
      for (final pennant in pennants) {
        expect(pennant.stroke!.argb, style.argb);
        expect(
          pennant.fill!.argb >> 24,
          0xFF,
          reason: 'a translucent flag shows the wire under it',
        );
        // The composite is between the hue and the paper on every
        // channel — not the hue itself, and not the paper itself.
        for (final shift in <int>[16, 8, 0]) {
          final got = (pennant.fill!.argb >> shift) & 0xFF;
          final hue = (style.argb >> shift) & 0xFF;
          final base = (paper >> shift) & 0xFF;
          final lo = hue < base ? hue : base;
          final hi = hue < base ? base : hue;
          expect(got, inInclusiveRange(lo, hi));
          // 12% of the way from paper toward the hue, +-1 for rounding.
          expect((got - (hue * 31 / 255 + base * (1 - 31 / 255))).abs(),
              lessThanOrEqualTo(1));
        }
      }
    });

    test('the inset GROWS WITH THE TYPE, so bigger text is not tighter '
        'against its own outline', () {
      // ═══════════════════════════════════════════════════════════════
      // THE PROPERTY, NOT THE NUMBER
      // ═══════════════════════════════════════════════════════════════
      // A constant inset is the defect: the pennant's CONTENT is measured
      // text, so it scales with the type, while a fixed padGu does not —
      // the glyphs creep toward the outline until the mark reads as one
      // smear. Asserting a width in units would freeze today's type size
      // into the test and say nothing about that. Asserting the RELATION
      // is what has to hold.
      //
      // The measured content is held EQUAL across the two builds (same
      // token, same net name, same measurer), so the whole of any width
      // difference is inset.
      final doc = _document();
      final small = buildNetLabelLayer(
        doc: doc,
        symbols: _build(doc).symbols,
        measurer: _Measurer(),
        palette: const SchematicPalette(),
        unitsPerGrid: kSchematicUnitsPerGrid,
        style: const NetLabelStyle(nameSizePt: 8),
      );
      final large = buildNetLabelLayer(
        doc: doc,
        symbols: _build(doc).symbols,
        measurer: _Measurer(),
        palette: const SchematicPalette(),
        unitsPerGrid: kSchematicUnitsPerGrid,
        style: const NetLabelStyle(nameSizePt: 24),
      );

      expect(small.labels, hasLength(large.labels.length));
      var grew = 0;
      for (var i = 0; i < small.labels.length; i++) {
        final a = small.labels[i].pennant;
        final b = large.labels[i].pennant;
        final along = small.labels[i].side == SymbolSide.left ||
                small.labels[i].side == SymbolSide.right
            ? (a.width, b.width)
            : (a.width, b.width);
        if (along.$2 > along.$1) grew++;
      }
      expect(
        grew,
        small.labels.length,
        reason: 'every flag must widen when its type does; a constant inset '
            'widens none of them beyond the text itself',
      );
    });

    test('and the grid figure survives as a FLOOR, not as the answer', () {
      // padGu stops a very small type collapsing the inset to nothing. The
      // two are a max, so a tiny `nameSizePt` must still leave the grid
      // inset intact rather than scaling below it.
      final doc = _document();
      NetLabelLayerBuild at(double pt, double padGu) => buildNetLabelLayer(
        doc: doc,
        symbols: _build(doc).symbols,
        measurer: _Measurer(),
        palette: const SchematicPalette(),
        unitsPerGrid: kSchematicUnitsPerGrid,
        style: NetLabelStyle(nameSizePt: pt, padGu: padGu),
      );
      // At 1 pt the em inset is a fraction of a unit, so the floor decides —
      // and a wider floor must therefore produce a wider flag.
      final tight = at(1, 0.5);
      final roomy = at(1, 4);
      for (var i = 0; i < tight.labels.length; i++) {
        expect(
          roomy.labels[i].pennant.width,
          greaterThan(tight.labels[i].pennant.width),
          reason: 'padGu stopped acting as a floor',
        );
      }
    });

    test('the NET NAME is drawn in ink, not in the domain hue', () {
      // The one run the reader is actually reading stays at maximum
      // contrast; hue is already on the other four marks. See
      // `SchematicPalette.netLabelText`.
      final doc = _document();
      final built = _build(doc);
      const palette = SchematicPalette();
      final names = built.scene.ops
          .whereType<OpText>()
          .where((t) => t.text.startsWith('N0'))
          .toList();
      expect(names, hasLength(2 * doc.links.length));
      for (final name in names) {
        expect(name.style.argb, palette.netLabelText);
      }
    });
  });

  group('resolution — which family, which name', () {
    test('the SERVICE decides the family, and it outranks the pin', () {
      // The pins are HDMI; the service says analog audio. §5: colour
      // "resolves from `Service.signalFamily`, never from the `Link`".
      final doc = _document(
        wiring: <_Wire>[
          (
            fromKey: 'vid',
            toKey: 'vid',
            service: 'audio.line_unbal',
            named: true,
          ),
        ],
      );
      final built = _build(doc);
      expect(
        built.domainFragments.keys.map((d) => d.v),
        <String>['audio.analog'],
      );
      expect(built.netLabels.first.style.familyId.v, 'audio.line_unbal');
    });

    test('with NO service the SOURCE pin’s declared family is used — a real '
        'model fact, not an estimate', () {
      final doc = _document(
        wiring: <_Wire>[
          (fromKey: 'pwr', toKey: 'pwr', service: null, named: false),
        ],
      );
      final built = _build(doc);
      expect(built.netLabels.first.style.familyId.v, 'power.ac_iec');
      expect(built.domainFragments.keys.map((d) => d.v), <String>['pwr']);
    });

    test('ONE family per link even when the two pins disagree — a link may '
        'not straddle two domain sub-pictures', () {
      // The balun case: an HDMI jack at one end, an RJ45 at the other. If
      // each end resolved independently, filtering to `video.digital`
      // would show one flag of the pair and hide the other.
      final doc = _document(
        wiring: <_Wire>[
          (fromKey: 'vid', toKey: 'net', service: null, named: false),
        ],
      );
      final built = _build(doc);
      expect(built.netLabels, hasLength(2));
      expect(
        built.netLabels.map((l) => l.style.domainId!.v).toSet(),
        <String>{'video.digital'},
      );
      expect(built.domainFragments, hasLength(1));
    });

    test('an unnamed link is DRAWN and COUNTED, with the unknown token — '
        'never with its W### designator', () {
      final doc = _document(
        wiring: <_Wire>[
          (fromKey: 'vid', toKey: 'vid', service: null, named: false),
          (
            fromKey: 'aud',
            toKey: 'aud',
            service: 'audio.line_unbal',
            named: true,
          ),
        ],
      );
      final built = _build(doc);
      expect(built.unnamedLinkIds, hasLength(1));
      final unnamed = built.netLabels
          .where((l) => l.linkId == built.unnamedLinkIds.single)
          .toList();
      expect(unnamed, hasLength(2));
      for (final label in unnamed) {
        expect(label.netName, kUnknownCell);
      }
      // A cable tag is a different fact about a different thing (G4).
      expect(
        built.scene.ops.whereType<OpText>().map((t) => t.text),
        isNot(contains('W000')),
      );
      // The named one really is named, so the check is not vacuous.
      expect(
        built.netLabels
            .where((l) => l.linkId != built.unnamedLinkIds.single)
            .map((l) => l.netName)
            .toSet(),
        <String>{'N002'},
      );
    });

    test('a link with an end off the drawn graph still labels the end it '
        'has, and a link with neither is COUNTED', () {
      final doc = _document();
      // Re-terminate one link's sink onto the field (AC-018's
      // `PlaceEndpoint`) and strand another entirely.
      final ids = doc.links.keys.toList()..sort((a, b) => a.v.compareTo(b.v));
      final half = doc.links[ids.first]!;
      half.conductors[0] = Conductor(
        from: half.conductors.first.from,
        to: const PlaceEndpoint(description: 'wall plate'),
      );
      final none = doc.links[ids[1]]!;
      none.conductors[0] = const Conductor(
        from: OpenEndpoint('spare'),
        to: PlaceEndpoint(description: 'wall plate'),
      );

      final built = _build(doc);
      expect(built.unlabelledLinkIds, <Uuid>[none.id]);
      expect(built.netLabels.where((l) => l.linkId == half.id), hasLength(1));
    });
  });

  group('geometry', () {
    test('a pennant is never taller than the pin pitch, or two adjacent '
        'pins’ labels overlap', () {
      // DERIVED, not transcribed: the constraint is `kPinPitch` grid units
      // in diagram units, and both terms come from the same constants the
      // symbol layer sizes itself with.
      final built = _build(_document());
      final pitch = kPinPitch * kSchematicUnitsPerGrid;
      for (final label in built.netLabels) {
        if (label.side == SymbolSide.left || label.side == SymbolSide.right) {
          expect(
            label.pennant.height,
            lessThan(pitch),
            reason:
                'a side pennant taller than the 2 gu pin pitch overlaps '
                'its neighbour on every multi-pin symbol',
          );
        }
      }
    });

    test('no two labels overlap on the same symbol edge', () {
      final built = _build(_document());
      final boxes = built.netLabels.map((l) => l.pennant).toList();
      for (var i = 0; i < boxes.length; i++) {
        for (var j = i + 1; j < boxes.length; j++) {
          expect(
            boxes[i].intersects(boxes[j]),
            isFalse,
            reason: 'labels $i and $j overlap: ${boxes[i]} vs ${boxes[j]}',
          );
        }
      }
    });

    test('two links on ONE pin stack outward instead of stacking on top of '
        'each other', () {
      // A multidrop tap: the same source pin feeding two runs.
      final doc = _document(
        wiring: <_Wire>[
          (
            fromKey: 'vid',
            toKey: 'vid',
            service: 'video.hdmi.2_0',
            named: true,
          ),
          (
            fromKey: 'vid',
            toKey: 'aud',
            service: 'video.hdmi.2_0',
            named: true,
          ),
        ],
      );
      final built = _build(doc);
      final atSource = built.netLabels
          .where((l) => l.portKey == 'vid' && l.deviceId != l.linkId.v)
          .where((l) => l.side == SymbolSide.right)
          .toList();
      expect(atSource, hasLength(2));
      expect(atSource[0].pennant.intersects(atSource[1].pennant), isFalse);
    });

    test('a label’s text sits INSIDE its own pennant', () {
      final built = _build(_document());
      final measurer = _Measurer();
      for (final label in built.netLabels) {
        final ops = built.scene.ops
            .whereType<OpText>()
            .where((t) => label.pennant.contains(t.at))
            .toList();
        expect(
          ops.length,
          greaterThanOrEqualTo(2),
          reason: 'the token and the name both belong inside ${label.pennant}',
        );
        for (final op in ops) {
          final width = measurer.measureText(op.text, op.style).advanceWidth;
          expect(
            op.at.x + width,
            lessThanOrEqualTo(label.pennant.right + 1e-9),
          );
        }
      }
    });

    test('a domain run is LAYERED — every leader, then every pennant, then '
        'every text', () {
      // ═══════════════════════════════════════════════════════════════
      // THIS USED TO ASSERT FOUR OPS PER STUB, INTERLEAVED, AND THAT WAS
      // THE DEFECT
      // ═══════════════════════════════════════════════════════════════
      // Each stub emitted leader, pennant, text in sequence, so stub N's
      // LEADER landed after stub N-1's PENNANT and painted over it. A
      // leader carries the family hue, dash and weight — it looks like a
      // wire — so on a combed edge, where the outermost flag's leader runs
      // past every inner flag, the field reported it as labels drawing
      // under the wires.
      //
      // The op COUNT is unchanged at four per flag; only the grouping
      // moved, and the grouping is now the claim. `schematic_perf_test`
      // still asserts the count.
      //
      // PER DOMAIN RUN, NOT PER SHEET. Each run must stay one contiguous
      // `IntRange` for the filter to replay it, so the layering is
      // asserted INSIDE a run — which is also the honest limit of the
      // fix: a later domain's leader can still cross an earlier domain's
      // pennant, and no ordering that keeps the ranges contiguous can
      // prevent that.
      final built = _build(_document());
      for (final range in built.domainFragments.values) {
        final run = built.scene.ops.sublist(range.start, range.end);
        expect(run, isNotEmpty);

        final kindOf = <int>[
          for (final op in run)
            switch (op) {
              OpLine() => 0,
              OpPath() => 1,
              OpText() => 2,
              _ => -1,
            },
        ];
        expect(kindOf, isNot(contains(-1)), reason: 'unexpected op kind');
        // Non-decreasing IS the layering: any leader after a pennant, or
        // any pennant after a text, breaks it.
        for (var i = 1; i < kindOf.length; i++) {
          expect(
            kindOf[i],
            greaterThanOrEqualTo(kindOf[i - 1]),
            reason: 'op $i of this run is out of layer order — a leader '
                'drawn after a pennant is the defect this fixes',
          );
        }
        // One leader per flag; TWO `OpPath`s — the pennant and, since
        // #124, the family glyph drawn as geometry; two texts — the
        // family tag and the net name.
        //
        // THE GLYPH IS INSIDE THE SAME KIND AS THE PENNANT and that is not
        // a coincidence to paper over: it has to paint after every fill in
        // its run, so ranking it with the pennants is what keeps the
        // non-decreasing check above meaningful for it. `_glyphPaths`
        // separates the two where a test needs one or the other.
        final leaders = kindOf.where((k) => k == 0).length;
        expect(kindOf.where((k) => k == 1).length, 2 * leaders);
        expect(kindOf.where((k) => k == 2).length, 2 * leaders);
        // ...and every glyph lands AFTER every pennant, which the kind
        // ranking cannot see because they share a kind.
        final paths = run.whereType<OpPath>().toList();
        final firstGlyph = paths.indexWhere(_isGlyphPath);
        final lastPennant = paths.lastIndexWhere((p) => !_isGlyphPath(p));
        expect(
          firstGlyph,
          greaterThan(lastPennant),
          reason: "a glyph drawn before another flag's fill is covered by "
              'it — 96-I again, wearing a different shape',
        );
      }
      expect(
        built.scene.ops.length,
        _symbolOps(built) + 5 * built.netLabels.length,
      );
    });

    test('the pennant’s apex points AWAY from its pin, and its attach '
        'edge is flat against the leader', () {
      // §11.5's chevrons — `J09 ├──⟩ NAME` and `NAME ⟨──┤ J03` — both
      // point away from their pin, which is what makes "right-pointing is
      // leaving, left-pointing is arriving" true at the same time: §3 puts
      // sinks on the left edge and sources on the right. The pentagon is
      // that one rule, so ONE vertex sits at the outward extreme (the
      // apex, on the cross-axis centre line) and TWO sit at the pin end
      // (the flat edge the leader meets).
      //
      // Without this, the shape is unasserted: a mutation that pulled the
      // attach edge in by a tip — turning the signpost into a lozenge —
      // passed every other test in this suite.
      final built = _build(_document());
      final base = _symbolOps(built);
      // BY KIND, NOT BY STRIDE. The run is layered now — every leader, then
      // every pennant, then every glyph, then every text — so
      // `base + 4 * i + 1` no longer names a pennant. Pennants keep
      // emission order within a domain and domains are appended in order,
      // so the i-th one still belongs to `netLabels[i]`.
      //
      // NOT `whereType<OpPath>()` ALONE any more: since #124 the family
      // glyph is an `OpPath` too. `_pennantPaths` is the discriminator and
      // it reads a real structural fact rather than a position — a pennant
      // is the only path carrying BOTH a fill and a stroke.
      final paths = _pennantPaths(built.scene.ops.skip(base));
      expect(paths, hasLength(built.netLabels.length));
      for (var i = 0; i < built.netLabels.length; i++) {
        final label = built.netLabels[i];
        final path = paths[i];
        final xs = <double>[];
        final ys = <double>[];
        for (final c in path.p.commands) {
          if (c is MoveTo) {
            xs.add(c.x);
            ys.add(c.y);
          } else if (c is LineTo) {
            xs.add(c.x);
            ys.add(c.y);
          }
        }
        expect(xs, hasLength(5), reason: 'a pentagon has five vertices');

        final box = label.pennant;
        final (outward, attach, cross) = switch (label.side) {
          SymbolSide.left => (box.left, box.right, ys),
          SymbolSide.right => (box.right, box.left, ys),
          SymbolSide.top => (box.top, box.bottom, xs),
          SymbolSide.bottom => (box.bottom, box.top, xs),
        };
        final along = switch (label.side) {
          SymbolSide.left || SymbolSide.right => xs,
          SymbolSide.top || SymbolSide.bottom => ys,
        };
        final apex = <int>[
          for (var k = 0; k < along.length; k++)
            if ((along[k] - outward).abs() < 1e-9) k,
        ];
        expect(
          apex,
          hasLength(1),
          reason:
              'exactly one vertex is the point, and it is the OUTWARD one '
              '(${label.side.name}, $box)',
        );
        expect(
          cross[apex.single],
          closeTo(
            (label.side == SymbolSide.left || label.side == SymbolSide.right)
                ? (box.top + box.bottom) / 2
                : (box.left + box.right) / 2,
            1e-9,
          ),
        );
        expect(
          along.where((v) => (v - attach).abs() < 1e-9),
          hasLength(2),
          reason: 'the leader meets a FLAT edge, not a second point',
        );
      }
    });

    test('the layer’s ink bounds agree with a replay through BoundsCanvas — '
        'the measured shortcut stays honest', () {
      // `NetLabelLayerBuild.inkBounds` is computed from the pennant boxes
      // rather than by replaying 2,400 ops through a measuring canvas. The
      // shortcut is only sound while the pennant really does bound its own
      // text, so it is checked against the slow answer here rather than
      // trusted.
      final built = _build(_document());
      final labelOps = built.scene.ops.sublist(_symbolOps(built));
      final replayed = inkBoundsOf(labelOps, measurer: _Measurer())!;
      final claimed = built.netLabels
          .map((l) => l.pennant)
          .reduce((a, b) => a.union(b));
      // The replayed box also contains the leaders, which start at the
      // pins, so it can only be LARGER — never smaller than the pennants.
      expect(replayed.left, lessThanOrEqualTo(claimed.left + 1e-9));
      expect(replayed.right, greaterThanOrEqualTo(claimed.right - 1e-9));
      // ALL FOUR EDGES. Checking only the right edge is not enough and
      // was not: the rightmost thing on this sheet is the last layer's
      // symbol, not a pennant, so a scene that dropped the label ink
      // entirely still had the right answer on that one side.
      const why =
          'the scene bounds must contain the labels on every side, or '
          'scale-to-fit clips a pennant off the printed sheet';
      expect(
        built.scene.bounds.left,
        lessThanOrEqualTo(replayed.left + 1e-9),
        reason: why,
      );
      expect(
        built.scene.bounds.top,
        lessThanOrEqualTo(replayed.top + 1e-9),
        reason: why,
      );
      expect(
        built.scene.bounds.right,
        greaterThanOrEqualTo(replayed.right - 1e-9),
        reason: why,
      );
      expect(
        built.scene.bounds.bottom,
        greaterThanOrEqualTo(replayed.bottom - 1e-9),
        reason: why,
      );
    });
  });

  group('determinism — the M2 exit criterion, with labels in the scene', () {
    test('a REORDERED-BUT-EQUIVALENT document draws a byte-identical '
        'display list', () {
      expect(
        digestScene(_build(_document(reversed: true)).scene),
        digestScene(_build(_document()).scene),
      );
    });

    test('the same document draws identically twice', () {
      final doc = _document();
      expect(
        digestScene(_build(doc).scene),
        digestScene(_build(doc).scene),
      );
    });
  });

  group('the glyph gap is reported, not silent', () {
    test('every drawn family whose shape cannot be verified is counted', () {
      final built = _build(_document());
      // Four families are wired and all four sit in domains that declare a
      // second shape no model field selects — see `signal_style.dart`.
      expect(built.underGlyphedFamilyIds.map((f) => f.v).toList(), <String>[
        'audio.line_unbal',
        'net.ethernet',
        'net.poe',
        'power.ac_branch',
        'power.ac_iec',
        'video.hdmi.2_0',
      ]);
    });

    test('an unresolved family is NOT counted — it has no glyph at all, '
        'which is a different gap', () {
      final built = _build(_document(seedRegistries: false));
      expect(built.underGlyphedFamilyIds, isEmpty);
      expect(built.netLabels, isNotEmpty);
    });
  });
}

/// Whether [op] is a family GLYPH rather than a pennant.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A STRUCTURAL FACT, NOT A POSITION
/// ═══════════════════════════════════════════════════════════════════════
/// Since #124 the layer emits two kinds of `OpPath`, and every test that
/// wanted "the pennants" used to get them with a bare `whereType<OpPath>()`
/// — which now silently picks up glyphs and would let a test claiming to
/// check a pentagon check a triangle instead.
///
/// The discriminator is the emitter's own construction and is pinned by
/// `a pennant is the only path carrying both a fill and a stroke` below:
/// a pennant is a tinted card WITH an outline, a filled glyph has a fill
/// and no stroke, a hollow glyph has a stroke and no fill. Exactly one
/// side of that is ever true at a time.
bool _isGlyphPath(OpPath op) => op.fill == null || op.stroke == null;

/// The pennants among [ops], in emission order.
List<OpPath> _pennantPaths(Iterable<DiagramOp> ops) =>
    ops.whereType<OpPath>().where((p) => !_isGlyphPath(p)).toList();

/// The family glyphs among [ops], in emission order.
List<OpPath> _glyphPaths(Iterable<DiagramOp> ops) =>
    ops.whereType<OpPath>().where(_isGlyphPath).toList();

/// How many ops the SYMBOL half of [scene] emitted — everything before the
/// first label op. Derived from the fragments rather than assumed, so it
/// survives a change to the symbol layer.
int _symbolOps(SchematicScene scene) {
  var first = scene.scene.ops.length;
  for (final range in scene.domainFragments.values) {
    if (range.start < first) first = range.start;
  }
  final unresolved = scene.unresolvedDomainFragment;
  if (unresolved != null && unresolved.start < first) first = unresolved.start;
  return first;
}

int _domainHue(RackDocument doc, SignalDomainId domain) {
  final c = doc.registries.signalDomains[domain]!.color;
  return (c.a << 24) | (c.r << 16) | (c.g << 8) | c.b;
}
