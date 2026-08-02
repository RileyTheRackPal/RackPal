// M2-D's performance contract, asserted rather than described.
//
// `net_label_layer.dart`'s header states it: "M2-E replays seven domains'
// label runs unchanged and rebuilds only the eighth." The word that carries
// the weight is UNCHANGED, and "we did not rebuild it" is exactly the kind
// of claim that rots into a comment while the code quietly starts copying
// ops. So the assertion below is `identical` on the op INSTANCES, which is
// false the moment anything reconstructs one — a `copyWith`, a recolour, a
// re-measure — and cannot be satisfied by a list that merely compares
// equal.
//
// The second group is the `b560a50` background defect, pinned at the level
// where it is a structural property rather than a pixel: the sheet ground
// is op ZERO of the same list as everything else, so there is no second
// draw that could pick up a different transform.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

import 'schematic_test_document.dart';

void main() {
  late RackDocument doc;
  late SchematicScene scene;
  late List<SignalDomainId> domains;

  setUp(() {
    doc = buildSchematicTestDocument();
    scene = buildFixtureScene(doc);
    domains = schematicDomainOrder(
      doc.registries,
    ).where(scene.domainFragments.containsKey).toList();
  });

  SchematicPaintPlan planFor(
    SchematicViewFilter filter, {
    String? altHovered,
    Set<String> focused = const <String>{},
  }) {
    final scope = resolveDrawnScope(
      scene: scene,
      filter: filter,
      altHoveredDeviceId: altHovered,
      focusedDeviceIds: focused,
      designatorOf: (id) => doc.devices[Uuid(id)]?.designator ?? id,
    );
    return buildSchematicPaintPlan(
      scene: scene,
      doc: doc,
      filter: filter,
      scope: scope,
      measurer: const FakeMeasurer(),
      palette: const SchematicPalette(),
      groundArgb: 0xFFFFFFFF,
    );
  }

  test('the fixture really does put several domains on the sheet', () {
    // Every arithmetic assertion below is vacuous on a one-domain sheet.
    expect(domains.map((d) => d.v).toList(), kFixtureDomains);
  });

  test('the chip order is ASCENDING ID and total — arbitrary, but the same '
      'arbitrary order M2-D emits the label runs in', () {
    // Asserted against `sort` rather than against a transcribed list, and
    // asserted at all because every other test compares the bar to
    // `schematicDomainOrder` — i.e. to the same function — so nothing else
    // in the suite can see the order stop being an order. §11.2's figure
    // prints VID · RF · AUD · DIG · NET · CTL · PWR · STR; no model field
    // carries that, and inventing one would be fabricating a fact (G4).
    final order = schematicDomainOrder(doc.registries);
    expect(order, hasLength(doc.registries.signalDomains.length));
    expect(
      order.map((d) => d.v).toList(),
      order.map((d) => d.v).toList()..sort(),
    );
    expect(order.toSet(), hasLength(order.length));
  });

  group('the replay is a replay', () {
    test('an unfiltered sheet replays every domain run, op instance for op '
        'instance, out of the already-built scene', () {
      final plan = planFor(const SchematicViewFilter());
      expect(plan.replayedDomainRuns, domains.length);
      expect(plan.rebuiltDomainRuns, 0);
      expect(plan.hiddenDomainRuns, 0);

      for (final domain in domains) {
        final range = scene.domainFragments[domain]!;
        final at = _indexOfRun(plan.ops, scene.scene.ops, range);
        expect(
          at,
          isNotNull,
          reason:
              "${domain.v}'s run is not in the plan in one contiguous piece",
        );
        for (var i = range.start; i < range.end; i++) {
          expect(
            identical(plan.ops[at! + (i - range.start)], scene.scene.ops[i]),
            isTrue,
            reason:
                'op $i of ${domain.v} is a DIFFERENT instance in the plan. '
                'Something rebuilt a label run M2-D published so it could '
                'be replayed untouched.',
          );
        }
      }
    });

    test('soloing one domain rebuilds exactly that one and replays the '
        'rest untouched', () {
      final soloed = domains.first;
      final plan = planFor(
        SchematicViewFilter(
          visibleDomains: <SignalDomainId>{soloed},
          explicit: true,
        ),
      );

      expect(plan.rebuiltDomainRuns, 1);
      expect(plan.replayedDomainRuns, 0, reason: 'the others are HIDDEN');
      expect(plan.hiddenDomainRuns, domains.length - 1);
      expect(plan.mode, SheetRenderMode.drawn);

      // The soloed domain's LABELS are gone from the plan…
      final range = scene.domainFragments[soloed]!;
      expect(
        _indexOfRun(plan.ops, scene.scene.ops, range),
        isNull,
        reason:
            'a soloed domain must render as wires, not as wires AND '
            'labels — §11.1.1 replaces the rendering, it does not add to it',
      );
      // …and its WIRES are there instead.
      expect(plan.ops.whereType<OpPolyline>(), isNotEmpty);
      expect(
        plan.drawnWires.map((w) => w.style.domainId).toSet(),
        <SignalDomainId>{soloed},
      );
    });

    test('Ctrl+clicking two domains visible is NOT drawn — §11.1.1 says '
        'EXACTLY ONE', () {
      final plan = planFor(
        SchematicViewFilter(
          visibleDomains: <SignalDomainId>{domains[0], domains[1]},
          explicit: true,
        ),
      );
      expect(plan.mode, SheetRenderMode.netLabels);
      expect(plan.ops.whereType<OpPolyline>(), isEmpty);
      expect(plan.replayedDomainRuns, 2);
      expect(plan.rebuiltDomainRuns, 0);
    });

    test('Alt-hover draws its wires UNDER an untouched label layer, and '
        'rebuilds no run at all', () {
      // The asymmetry `DrawnScope.replacesDomainRun` states: a soloed
      // domain's every link is in scope so its whole run can be replaced,
      // while a hover scopes a handful of links out of the middle of
      // several contiguous ranges — and there is no such thing as
      // replaying part of an `IntRange`.
      final mtx = deviceNamed(doc, 'MTX-1');
      final plan = planFor(
        const SchematicViewFilter(),
        altHovered: mtx.id.v,
      );
      expect(plan.mode, SheetRenderMode.drawn);
      expect(plan.rebuiltDomainRuns, 0);
      expect(plan.replayedDomainRuns, domains.length);
      expect(plan.ops.whereType<OpPolyline>(), isNotEmpty);
      for (final domain in domains) {
        final range = scene.domainFragments[domain]!;
        expect(_indexOfRun(plan.ops, scene.scene.ops, range), isNotNull);
      }
    });

    test('and the ordering is asserted, not just the presence: every label '
        'run is emitted AFTER the last wire op', () {
      // ═══════════════════════════════════════════════════════════════
      // THE TITLE ABOVE USED TO SAY "OVER" AND NOTHING CHECKED IT
      // ═══════════════════════════════════════════════════════════════
      // The sibling test asserts that each run is PRESENT and that some
      // polyline exists. Both hold whichever way round they are emitted,
      // so the claim in the title was carried by the title alone — and
      // when the order was deliberately reversed, nothing failed.
      //
      // ALT-HOVER IS THE CASE THAT CAN SEE IT. A soloed domain REPLACES
      // its own run, so its wires cross no flags of their own; a hover
      // replays every run and draws wires as well, which is the only
      // arrangement where both kinds of mark are on the sheet at once.
      //
      // `OpPolyline` IS THE WIRE. A pennant is an `OpPath`, its leader an
      // `OpLine`, its text an `OpText` — the netLabels-mode test two above
      // asserts `whereType<OpPolyline>()` is EMPTY, which is what makes
      // this identification a checked fact rather than an assumption.
      final mtx = deviceNamed(doc, 'MTX-1');
      final plan = planFor(
        const SchematicViewFilter(),
        altHovered: mtx.id.v,
      );

      var lastWire = -1;
      for (var i = 0; i < plan.ops.length; i++) {
        if (plan.ops[i] is OpPolyline) lastWire = i;
      }
      expect(lastWire, greaterThanOrEqualTo(0), reason: 'wires were drawn');

      for (final domain in domains) {
        final range = scene.domainFragments[domain]!;
        final at = _indexOfRun(plan.ops, scene.scene.ops, range);
        expect(at, isNotNull, reason: '$domain run is on the sheet');
        expect(
          at,
          greaterThan(lastWire),
          reason:
              "$domain's flags are emitted before the wires, so a wire "
              'paints over their outlines and their net names',
        );
      }
    });
  });

  group('the sheet ground (the b560a50 offset defect, structurally)', () {
    test('the ground is op ZERO of the same list as everything else', () {
      // The deleted canvas drew its background BESIDE its content and
      // therefore under a different transform. There is no "beside" here:
      // if the ground is in the list, it is under the one matrix.
      final plan = planFor(const SchematicViewFilter());
      expect(plan.ops.first, isA<OpRect>());
      expect((plan.ops.first as OpRect).r, plan.ground);
      expect((plan.ops.first as OpRect).fill, const Fill(0xFFFFFFFF));
    });

    test('the ground contains every symbol the sheet draws', () {
      final plan = planFor(const SchematicViewFilter());
      for (final symbol in scene.symbols) {
        expect(
          plan.ground.contains(symbol.bodyRect.topLeft) &&
              plan.ground.contains(symbol.bodyRect.bottomRight),
          isTrue,
          reason: '${symbol.designator} is off the paper',
        );
      }
    });
  });

  group('symbols', () {
    test('every symbol fragment is replayed inside its own translate, from '
        'the published body rect', () {
      // M2-D: `fragmentFor(deviceId)` hands back LOCAL ops WITHOUT the
      // bracketing translate, "so a widget that positions the fragment
      // itself must not re-apply it". This plan positions them, so it must
      // re-emit exactly one bracket per symbol.
      //
      // WALKED BY INDEX, not counted by type: a symbol fragment contains
      // `OpTransform`s of its own (a pin's arrowhead is rotated), so a
      // global count would be measuring the arrowheads and would pass on a
      // plan that positioned nothing.
      final plan = planFor(const SchematicViewFilter());
      var at = 1; // op 0 is the sheet ground.
      for (final symbol in scene.symbols) {
        final range = scene.scene.fragments[symbol.id]!;
        final origin = symbol.bodyRect.topLeft;
        expect(plan.ops[at], isA<OpSave>(), reason: symbol.designator);
        final transform = plan.ops[at + 1];
        expect(transform, isA<OpTransform>(), reason: symbol.designator);
        expect((transform as OpTransform).m.storage[12], origin.x);
        expect(transform.m.storage[13], origin.y);
        final length = range.end - range.start;
        for (var i = 0; i < length; i++) {
          expect(
            identical(plan.ops[at + 2 + i], scene.scene.ops[range.start + i]),
            isTrue,
            reason: "op $i of ${symbol.designator}'s fragment was rebuilt",
          );
        }
        expect(plan.ops[at + 2 + length], isA<OpRestore>());
        at += length + 3;
      }
    });

    test('the document reaches the plan — the designators on the sheet are '
        "the DOCUMENT's", () {
      // THE b560a50 DEFECT #1, at the level below the widget: an empty
      // scene would produce a plan with no text at all, and the canvas
      // that shipped filled that hole by MANUFACTURING `Pin1`/`Pout1`.
      final plan = planFor(const SchematicViewFilter());
      final texts = plan.ops.whereType<OpText>().map((t) => t.text).toSet();
      for (final designator in kFixtureDesignators) {
        if (designator == kFixturePortlessDesignator) continue;
        expect(
          texts,
          contains(designator),
          reason: '$designator is in the document and not on the sheet',
        );
      }
      // And nothing on the sheet is a fabricated port label.
      expect(
        texts.where((t) => RegExp(r'^P?(in|out)\d+$').hasMatch(t)),
        isEmpty,
      );
    });
  });

  group('[None], and the unresolved run', () {
    test('[None] hides every domain and draws no wire', () {
      final plan = planFor(const SchematicViewFilter(explicit: true));
      expect(plan.mode, SheetRenderMode.netLabels);
      expect(plan.hiddenDomainRuns, domains.length);
      expect(plan.replayedDomainRuns, 0);
      // The symbols stay — [None] filters CABLES, not equipment.
      final texts = plan.ops.whereType<OpText>().map((t) => t.text).toSet();
      expect(texts, contains('MTX-1'));
    });

    test('the unresolved-domain run rides the unfiltered sheet and gets no '
        'chip of its own', () {
      // M2-D kept the unresolved bucket out of `domainFragments` because
      // "minting a fake id would put a ninth chip in the domain filter
      // bar … for something no `Service` can resolve to". This asserts the
      // consequence: the bar has as many chips as there are real domains.
      expect(
        schematicDomainOrder(doc.registries),
        hasLength(doc.registries.signalDomains.length),
      );
      expect(
        schematicDomainOrder(doc.registries).map((d) => d.v),
        isNot(contains('?')),
      );
      expect(const SchematicViewFilter().showsUnresolved, isTrue);
      expect(
        const SchematicViewFilter(explicit: true).showsUnresolved,
        isFalse,
      );
    });
  });
}

/// Where [run] of [source] begins inside [ops], as ONE contiguous stretch
/// of the identical op instances, or null when it is not there whole.
int? _indexOfRun(
  List<DiagramOp> ops,
  List<DiagramOp> source,
  IntRange run,
) {
  if (run.end <= run.start) return null;
  final first = source[run.start];
  for (var i = 0; i + (run.end - run.start) <= ops.length; i++) {
    if (!identical(ops[i], first)) continue;
    var all = true;
    for (var j = 0; j < run.end - run.start; j++) {
      if (!identical(ops[i + j], source[run.start + j])) {
        all = false;
        break;
      }
    }
    if (all) return i;
  }
  return null;
}
