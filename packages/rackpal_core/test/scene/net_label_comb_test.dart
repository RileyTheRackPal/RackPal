// #96-H — the comb separates flags without climbing off the sheet.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THE EXISTING FIXTURE COULD NOT SEE THIS
// ═══════════════════════════════════════════════════════════════════════
// `net_label_layer_test.dart` puts TWO pins on each vertical edge, and its
// own comment says why: with one pin the comb is unreachable and a mutation
// deleting it survives. Two is the smallest number that proves the comb
// EXISTS.
//
// It is not enough to prove the comb is BOUNDED. With two pins, `i % lanes`
// equals `i` for every lane count of two or more, so the fixture cannot
// distinguish the staggered-forever version from the wrapped one. The field
// found the difference with a screenshot: pennants climbing diagonally off
// every wide symbol, because the i-th pin got a leader i pennant-heights
// long.
//
// So this file uses the widest edge the shipped catalog has. `N03` declares
// 48 `net.`-family ports, and docs/05 §3's edge rule sends that whole family
// to the TOP edge — which is exactly the symbol in the user's screenshot.
//
// ═══════════════════════════════════════════════════════════════════════
// TWO CLAIMS, AND THE SECOND IS THE ONE THAT REGRESSES
// ═══════════════════════════════════════════════════════════════════════
//   1. NO TWO FLAGS ON ONE EDGE OVERPRINT. This is what the unbounded comb
//      was buying and what the bounded one must keep buying. A cap picked
//      out of the air rather than computed would fail here.
//   2. THE REACH IS BOUNDED. Asserted against what the unbounded version
//      would have produced on this very symbol, so the number is derived
//      from the defect rather than typed in.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 2);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// TWO SWITCHES, AND THE SECOND ONE IS NOT DECORATION. They carry no link
/// between them, so Sugiyama puts both in layer 0 and STACKS them — which
/// is the only arrangement in which `SugiyamaParams.nodeGapGu` is the thing
/// separating two symbols, and therefore the only one where a comb can
/// reach a neighbour's body. With one device the over-a-body assertion
/// passes trivially, because a flag escapes outward from its own pin.
const _dev = Uuid('dev-switch');
const _dev2 = Uuid('dev-switch-2');

final class _Measurer implements TextMeasurer {
  const _Measurer();

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

/// One switch, with every top-edge pin carrying a cable.
///
/// THE FAR ENDS ARE OPEN, and that is a convenience with a citation rather
/// than a shortcut: AC-018 makes an unbound far end first-class, and
/// `_endsOf`'s own doc says a one-ended link still labels the end it has.
/// One link per pin, one pennant per link, and no second device whose own
/// comb would muddy the measurement.
({RackDocument doc, List<String> topPortKeys}) _fixture() {
  final catalog = buildSeedCatalog();
  final body = catalog['N03']!;

  // ═══════════════════════════════════════════════════════════════════
  // THE BANKS ARE OPTED OUT OF COLLAPSE, AND THAT IS THE FIXTURE'S POINT
  // ═══════════════════════════════════════════════════════════════════
  // `#801` turned CR-103's bank collapse on for the canvas, and N03's two
  // 24-port banks are precisely what it collapses: the scene would draw
  // two vector pins where this file needs twenty-four labelled pins.
  // Every test below is about a comb packing a WIDE edge without
  // overprinting, so a collapsed edge does not make them pass. It makes
  // them VACUOUS, which is worse, and the coverage assertion in group 0
  // is the thing that noticed.
  //
  // `collapseInSymbol` is CR-103's own per-bank opt-out for "a bank that
  // must always show every pin", so the fixture says this in the model
  // rather than reaching for a view flag the scene deliberately has not
  // got. A fresh `buildSeedCatalog()` is built above, so the mutation
  // does not reach any other test.
  for (final bank in body.banks) {
    bank.collapseInSymbol = false;
  }

  final doc = RackDocument(
    id: const Uuid('doc-1'),
    appVersion: '0.1.0+build.1',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
    info: ProjectInfo(projectName: '96-H'),
    registries: buildSeedRegistries(),
  );

  doc.templates['n03@1'] = TemplateSnapshot(
    templateId: const TemplateId('n03'),
    version: 1,
    contentHash: 'sha256:n03',
    capturedAt: _when,
    body: body,
  );
  var designator = 0;
  for (final id in <Uuid>[_dev, _dev2]) {
    designator++;
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('n03'),
        version: 1,
        contentHash: 'sha256:n03',
      ),
      designator: 'SW-$designator',
      name: body.displayName,
      placement: const OffRackPlacement(),
      meta: _meta(),
    );
  }

  // Which ports land on the top edge is `symbolSideForPort`'s answer, read
  // rather than assumed — the families that go there are catalog data.
  final banks = <String, BankDef>{for (final b in body.banks) b.key: b};
  final topKeys = <String>[
    for (final port in body.ports)
      if (symbolSideForPort(
            port,
            bank: port.bankKey == null ? null : banks[port.bankKey],
          ) ==
          SymbolSide.top)
        port.key.v,
  ];

  var n = 0;
  for (final device in <Uuid>[_dev, _dev2]) {
    for (final key in topKeys) {
      n++;
      final portId = derivePortId(device, PortKey(key));
      doc.ports[portId] = Port(
        id: portId,
        deviceId: device,
        designator: 'J${n.toString().padLeft(2, '0')}',
        templatePortKey: PortKey(key),
      );
      final netId = Uuid('net-$n');
      doc.nets[netId] = Net(
        id: netId,
        name: 'N${n.toString().padLeft(3, '0')}',
        signalFamily: const SignalFamilyId('net.ethernet'),
        meta: _meta(),
      );
      final linkId = Uuid('link-$n');
      doc.links[linkId] = Link(
        id: linkId,
        designator: 'W${n.toString().padLeft(3, '0')}',
        media: const MediaTypeId('media.cat6'),
        order: FracIndex('a${n.toString().padLeft(4, '0')}'),
        meta: _meta(),
        conductors: [
          Conductor(
            from: PortEndpoint(portId),
            to: const OpenEndpoint('field'),
          ),
        ],
        services: [
          Service(
            id: 'svc-$n',
            signalFamily: const SignalFamilyId('net.ethernet'),
            netId: netId,
          ),
        ],
      );
    }
  }

  return (doc: doc, topPortKeys: topKeys);
}

void main() {
  late RackDocument doc;
  late List<String> topKeys;
  late SchematicScene scene;
  late List<RenderedNetLabel> topLabels;

  setUpAll(() {
    final f = _fixture();
    doc = f.doc;
    topKeys = f.topPortKeys;
    scene = buildSchematicScene(doc: doc, measurer: const _Measurer());
    final keys = topKeys.toSet();
    topLabels = scene.netLabels
        .where((l) => l.deviceId == _dev.v && keys.contains(l.portKey))
        .toList();
  });

  group('0 — the fixture is the wide edge this is about', () {
    test('N03 puts many ports on one top edge, and every one is labelled', () {
      // THE COVERAGE ASSERTION. Everything below is vacuous on a narrow
      // edge, and "many" is checked rather than assumed because which
      // families reach the top edge is catalog data that can move.
      expect(
        topKeys.length,
        greaterThanOrEqualTo(24),
        reason: 'N03 should carry a wide top edge; the catalog changed',
      );
      expect(topLabels, hasLength(topKeys.length));
    });
  });

  group('1 — no two flags on one edge overprint', () {
    test('every pennant on the top edge is clear of every other', () {
      // The guarantee the unbounded comb bought. A lane count picked out of
      // the air instead of computed from the pennant width fails here.
      final boxes = [for (final l in topLabels) l.pennant];
      final hits = <String>[];
      for (var i = 0; i < boxes.length; i++) {
        for (var j = i + 1; j < boxes.length; j++) {
          final a = boxes[i];
          final b = boxes[j];
          final overlapX = a.left < b.right && b.left < a.right;
          final overlapY = a.top < b.bottom && b.top < a.bottom;
          if (overlapX && overlapY) {
            hits.add('${topLabels[i].portKey} x ${topLabels[j].portKey}');
          }
        }
      }
      expect(hits, isEmpty, reason: 'overlapping flags: ${hits.take(8)}');
    });
  });

  group('2 — and the comb does not climb off the sheet', () {
    test('the furthest flag is a small multiple of the nearest, not an '
        'N-fold one', () {
      // ═══════════════════════════════════════════════════════════════
      // A RATIO, BECAUSE THE FIRST DRAFT OF THIS WAS A TAUTOLOGY
      // ═══════════════════════════════════════════════════════════════
      // It asserted `spread < furthest`, which is true for any `nearest > 0`
      // whatever the comb does — and it duly PASSED with the unbounded comb
      // planted back, while the sibling test below caught it. Recorded
      // rather than quietly rewritten: an assertion that cannot fail is
      // worse than no assertion, because it reads like coverage.
      //
      // The honest discriminator is the RATIO of the outermost flag to the
      // innermost. With `lanes = ceil(widest / pitch)` — three to five on
      // the shipped catalog — the outermost flag sits a few steps beyond
      // the first. With one lane per pin it sits forty-eight steps beyond,
      // and the ratio is an order of magnitude larger.
      final symbol = scene.symbols.firstWhere((s) => s.id == _dev.v);
      final top = symbol.bodyRect.top;

      // Distance each flag reaches ABOVE the body edge. Top pins escape
      // upward, so a larger reach is a flag further out.
      final reaches = [for (final l in topLabels) top - l.pennant.top];
      final nearest = reaches.reduce((a, b) => a < b ? a : b);
      final furthest = reaches.reduce((a, b) => a > b ? a : b);

      expect(nearest, greaterThan(0), reason: 'flags escape upward');
      expect(
        furthest,
        lessThan(nearest * 10),
        reason:
            'the outermost flag is ${(furthest / nearest).toStringAsFixed(1)}x '
            'the innermost across ${topKeys.length} pins — the comb is '
            'still growing with the pin count',
      );
    });

    test('and no flag lands on a device body, which is what the gap is '
        'for', () {
      // ═══════════════════════════════════════════════════════════════
      // THE USER'S ACTUAL SENTENCE, AS AN ASSERTION
      // ═══════════════════════════════════════════════════════════════
      // "make sure netlabels don't draw directly over devices". Bounding
      // the comb shortened the fans; it did not by itself stop them
      // reaching a neighbour, because nothing reserved vertical room —
      // SugiyamaParams.nodeGapGu stayed at 4 gu however far a comb grew,
      // so a symbol stacked below another was placed into the space the
      // one above was labelling. `netLabelNodeGapGu` is what reserves it.
      //
      // EVERY BODY, INCLUDING THE FLAG'S OWN. A pennant escapes outward
      // from its pin, so it should clear the symbol it belongs to as well
      // as every other one. Exempting its own would hide the case where a
      // comb is drawn inward.
      final hits = <String>[];
      for (final label in scene.netLabels) {
        for (final symbol in scene.symbols) {
          if (!label.pennant.intersects(symbol.bodyRect)) continue;
          hits.add('${label.netName} over ${symbol.designator}');
        }
      }
      expect(hits, isEmpty, reason: 'flags over bodies: ${hits.take(8)}');
    });

    test('the number of DISTINCT depths is bounded, and well under the pin '
        'count', () {
      // THE DIRECT STATEMENT OF THE FIX, and the one that fails loudest if
      // the modulo is dropped: an unbounded comb gives one distinct depth
      // per pin, a bounded one gives `lanes` of them however many pins
      // there are.
      final symbol = scene.symbols.firstWhere((s) => s.id == _dev.v);
      final top = symbol.bodyRect.top;
      final depths = <String>{
        for (final l in topLabels) (top - l.pennant.top).toStringAsFixed(3),
      };
      expect(
        depths.length,
        lessThan(topKeys.length ~/ 2),
        reason:
            'got ${depths.length} distinct depths for ${topKeys.length} '
            'pins — the comb is still one lane per pin',
      );
      expect(depths.length, greaterThanOrEqualTo(2), reason: 'a comb exists');
    });
  });
}
