// docs/04-rack-editor.md §4.1's shrink-below-occupancy modal.
//
// Two halves, deliberately:
//
//  1. `resolveShrink` / `defaultShrinkChoice` / `shrinkChoiceAvailable` as
//     PURE UNIT TESTS — the file header of shrink_rack_dialog.dart says this
//     logic is "worth testing without a widget tree", and until now nothing
//     did, so the always-available `keepSmallest` arm could have stranded
//     devices outside the rack undetected.
//
//  2. THE TILE AGAINST THE DECISION. §4.1's option 3 subtitle used to be the
//     constant "Nothing is moved and nothing is lost.", which a BOTTOM trim
//     falsifies — `resolveShrink` re-plans at the smaller height and returns
//     `shiftMoves` relocating every survivor. These tests flip the real radio
//     with a real tap and then press the real Apply button, asserting that
//     what the tile SAID and what the dialog POPPED are the same outcome.
//     That is the same live-preview-agrees-with-commit property this codebase
//     has already had to fix twice for the drag gestures.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

const _rackId = Uuid('rack-shrink');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

TemplateSnapshot _template(String id, int h) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'sha256:$id',
  capturedAt: DateTime.utc(2026),
  body: TemplateBody(
    manufacturer: 'Generic',
    model: id,
    displayName: id,
    frontU: h,
    rearU: h,
    side: OccupancySide.both,
    mountMethod: MountMethod.rackEars,
  ),
);

typedef _Occ = ({String d, int ru, int h});

_Occ _at(String d, int ru, int h) => (d: d, ru: ru, h: h);

RackDocument _doc(
  int heightU,
  List<_Occ> occupants, {
  Set<String> locked = const <String>{},
}) {
  final doc = RackDocument(
    id: const Uuid('doc-shrink'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Media Closet',
    designator: 'RK-1',
    heightU: heightU,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  for (final o in occupants) {
    final tid = 'tpl.h${o.h}';
    doc.templates['$tid@1'] = _template(tid, o.h);
    doc.devices[Uuid('dev-${o.d}')] = DeviceInstance(
      id: Uuid('dev-${o.d}'),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(tid),
        version: 1,
        contentHash: 'sha256:$tid',
      ),
      designator: o.d,
      name: 'Device ${o.d}',
      placement: RailPlacement(
        rackId: _rackId,
        ruIndex: o.ru,
        face: Face.front,
        // BUILT LOCKED, never set afterwards: `placement`'s setter is
        // `@internal` (AC-013), so a test in this package reaching for it
        // is reaching past the access control rather than through it.
        locked: locked.contains(o.d),
      ),
      meta: _meta(),
    );
  }
  return doc;
}

RackShrinkPlan _plan(RackDocument doc, int to, TrimFrom trim) =>
    planRackShrink(doc: doc, rackId: _rackId, toHeightU: to, trimFrom: trim);

Map<String, int> _targets(List<CompactionMove> m) => {
  for (final x in m) x.designator: x.toRuIndex,
};

/// §4.1's own worked example, and the finding's: a 20U rack with A at U5 (1U)
/// and B at U18 (2U), asked to become 12U.
///
///  * TOP trim   — B (U18–U19) is doomed; nobody is renumbered; the smallest
///                 height that fits without moving anything is 19U.
///  * BOTTOM trim — the floor rises 8U, so A (U5) is doomed; the smallest
///                 lossless height is 20 - (5-1) = 16U, and reaching it
///                 shifts BOTH survivors down by 4U.
RackDocument _example({Set<String> locked = const <String>{}}) =>
    _doc(20, [_at('A', 5, 1), _at('B', 18, 2)], locked: locked);

void main() {
  group('resolveShrink — the pure decision half', () {
    test('keepSmallest under a TOP trim keeps the smallest fitting height '
        'and renumbers nobody', () {
      final doc = _example();
      final plan = _plan(doc, 12, TrimFrom.top);
      expect(plan.smallestFittingHeightU, 19);

      final decision = resolveShrink(
        doc: doc,
        plan: plan,
        choice: ShrinkChoice.keepSmallest,
        designator: 'RK-1',
      );

      // NOT `plan.toHeightU` (12). Applying the requested height here would
      // push B outside the rack — §4.1 rule 3's "never destroy, never
      // silently move" is exactly what this arm exists to honour.
      expect(decision.toHeightU, 19);
      expect(decision.moves, isEmpty);
      expect(decision.summary, contains('Kept RK-1 at 19U'));
      expect(decision.summary, contains('smallest that fits'));
    });

    test('keepSmallest under a BOTTOM trim RE-PLANS: it relocates every '
        'survivor, sized to the height actually reached', () {
      final doc = _example();
      final plan = _plan(doc, 12, TrimFrom.bottom);
      expect(plan.smallestFittingHeightU, 16);
      // The plan's OWN shiftMoves were sized to the requested 12U (an 8U
      // drop) and would be wrong to reuse at 16U.
      expect(_targets(plan.shiftMoves), {'B': 10});

      final decision = resolveShrink(
        doc: doc,
        plan: plan,
        choice: ShrinkChoice.keepSmallest,
        designator: 'RK-1',
      );

      expect(decision.toHeightU, 16);
      // Re-planned at 16U: a 4U drop, and A is no longer doomed, so BOTH
      // occupants move. This is the outcome the option-3 tile used to deny.
      expect(_targets(decision.moves), {'A': 1, 'B': 14});
      expect(decision.summary, contains('2 devices shifted down 4U'));
    });

    test("asRequested carries the plan's own shift list unchanged", () {
      final doc = _doc(20, [_at('A', 12, 1)]);
      final plan = _plan(doc, 16, TrimFrom.bottom);

      expect(plan.hasCasualties, isFalse);
      final decision = resolveShrink(
        doc: doc,
        plan: plan,
        choice: ShrinkChoice.asRequested,
        designator: 'RK-1',
      );

      expect(decision.toHeightU, 16);
      expect(_targets(decision.moves), {'A': 8});
    });

    test('CR-038: a height derived from an occupant that ALREADY overhangs '
        'the rack is clamped to 60U, and the summary stops claiming to fit '
        'what it cannot', () {
      // `boltedOccupantsOnFace` deliberately does not clip occupants to the
      // rack extent, and JSON decode is the non-validating path — so a
      // 60U rack can carry a 5U device at U58, whose top U is 62.
      final doc = _doc(60, [_at('A', 2, 1), _at('B', 58, 5)]);
      final plan = _plan(doc, 30, TrimFrom.top);
      expect(
        plan.smallestFittingHeightU,
        62,
        reason: 'the planner reports the raw, unclamped requirement',
      );

      final decision = resolveShrink(
        doc: doc,
        plan: plan,
        choice: ShrinkChoice.keepSmallest,
        designator: 'RK-1',
      );

      // Unclamped, this reaches SetRackHeightCommand and trips
      // `Rack.heightU`'s `[1, 60]` assert in debug / violates CR-038 in
      // release.
      expect(decision.toHeightU, kMaxRackHeightU);
      expect(decision.summary, contains('60U'));
      expect(
        decision.summary,
        contains('B'),
        reason: 'the occupant still over the line must be named',
      );
      expect(
        decision.summary,
        isNot(contains('smallest that fits its contents')),
        reason: '60U does NOT fit B, so it must not claim to',
      );
    });
  });

  group('defaultShrinkChoice / shrinkChoiceAvailable', () {
    test('a lossless direction preselects and offers asRequested', () {
      final plan = _plan(_doc(20, [_at('A', 2, 1)]), 12, TrimFrom.top);

      expect(plan.hasCasualties, isFalse);
      expect(defaultShrinkChoice(plan), ShrinkChoice.asRequested);
      expect(shrinkChoiceAvailable(plan, ShrinkChoice.asRequested), isTrue);
    });

    test('with casualties and no rescue, option 3 is preselected and '
        'asRequested is not offerable', () {
      // One device, already packed at the bottom: compaction cannot help it,
      // so `plan.rescue` is null (rule 1).
      final plan = _plan(_doc(20, [_at('A', 1, 12)]), 6, TrimFrom.top);

      expect(plan.hasCasualties, isTrue);
      expect(plan.rescue, isNull);
      expect(defaultShrinkChoice(plan), ShrinkChoice.keepSmallest);
      expect(shrinkChoiceAvailable(plan, ShrinkChoice.asRequested), isFalse);
      expect(shrinkChoiceAvailable(plan, ShrinkChoice.compactFirst), isFalse);
      // Rule: option 3 is ALWAYS offerable.
      expect(shrinkChoiceAvailable(plan, ShrinkChoice.keepSmallest), isTrue);
    });

    test('a full rescue preselects compactFirst (rule 2)', () {
      final doc = _doc(20, [_at('A', 1, 2), _at('B', 18, 2)]);
      final plan = _plan(doc, 12, TrimFrom.top);

      expect(plan.rescue?.isFull, isTrue);
      expect(defaultShrinkChoice(plan), ShrinkChoice.compactFirst);
      expect(shrinkChoiceAvailable(plan, ShrinkChoice.compactFirst), isTrue);
    });
  });

  group('the option-3 tile states the outcome Apply actually produces', () {
    /// Opens the REAL dialog and returns a READER for whatever it eventually
    /// pops.
    ///
    /// A closure rather than a value, and that is the whole point. This
    /// helper used to be declared `Future<ShrinkDecision?>` and `return
    /// popped;`, which could only ever return null: `popped` is assigned in
    /// the `showDialog` continuation, and that continuation cannot have run
    /// while the dialog is still open — which it necessarily is, since the
    /// caller has not pressed anything yet. The return type was dead, and a
    /// caller that "checked the decision" by looking at it was checking
    /// nothing.
    Future<ShrinkDecision? Function()> pump(
      WidgetTester tester,
      RackDocument doc,
    ) async {
      ShrinkDecision? popped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  popped = await showDialog<ShrinkDecision>(
                    context: context,
                    builder: (_) => ShrinkRackDialog(
                      doc: doc,
                      rackId: _rackId,
                      requestedHeightU: 12,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => popped;
    }

    testWidgets('TOP trim: the tile promises stillness, and Apply really '
        'does pop a 19U decision with NO moves', (tester) async {
      // THE SECOND HALF OF THIS TITLE USED TO BE FICTION. The test called
      // the helper above, threw the (always-null) return value away, and
      // asserted two `find.text` strings — it never selected option 3,
      // never pressed Apply, and never looked at a `ShrinkDecision`. Any
      // mutation confined to the Apply path under a TOP trim — say
      // `resolveShrink`'s keepSmallest arm returning a non-empty `moves`
      // list while the tile text stayed put — was invisible to it.
      final doc = _example();
      final read = await pump(tester, doc);

      expect(
        find.text('Keep rack at 19U (smallest that fits)'),
        findsOneWidget,
      );
      expect(
        find.text('Nothing is moved and nothing is lost.'),
        findsOneWidget,
      );

      // A TOP trim on this document HAS a full rescue, so compactFirst is
      // the preselection — option 3 has to be chosen, with a real tap on
      // the real radio, exactly as its bottom-trim sibling does.
      await tester.tap(find.text('Keep rack at 19U (smallest that fits)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      // WHAT THE TILE SAID, NOW AS THE POPPED DECISION.
      final popped = read();
      expect(popped, isNotNull, reason: 'Apply must pop a decision');
      expect(popped!.toHeightU, 19);
      expect(
        popped.moves,
        isEmpty,
        reason:
            '"Nothing is moved" is a promise about the decision, not '
            'just about the tile text',
      );
      expect(popped.summary, contains('Kept RK-1 at 19U'));
    });

    testWidgets('`#913`, DR-186: A LOCK REFUSES THE BOTTOM TRIM AND NAMES '
        'THE DEVICE, because that trim moves every rail device down', (
      tester,
    ) async {
      await pump(tester, _example(locked: {'A'}));

      expect(
        find.textContaining('A is locked'),
        findsOneWidget,
        reason: 'a disabled radio with no reason reads as broken',
      );
      final bottom = tester.widget<RadioListTile<TrimFrom>>(
        find.widgetWithText(RadioListTile<TrimFrom>, 'Bottom'),
      );
      expect(bottom.enabled, isFalse);

      // AND THE TOP TRIM IS UNTOUCHED: it moves nobody, so a lock has
      // nothing to say about it and every option stays lossless.
      final top = tester.widget<RadioListTile<TrimFrom>>(
        find.widgetWithText(RadioListTile<TrimFrom>, 'Top'),
      );
      expect(top.enabled, isTrue);
      expect(
        find.text('Keep rack at 19U (smallest that fits)'),
        findsOneWidget,
      );
    });

    testWidgets('and with nothing locked the radio is offered as before', (
      tester,
    ) async {
      // The control for the case above: without it, a `Bottom` radio that
      // was disabled for some unrelated reason would pass it.
      await pump(tester, _example());

      expect(find.textContaining('is locked'), findsNothing);
      final bottom = tester.widget<RadioListTile<TrimFrom>>(
        find.widgetWithText(RadioListTile<TrimFrom>, 'Bottom'),
      );
      expect(bottom.enabled, isTrue);
    });

    testWidgets('FLIPPING TO BOTTOM REWRITES THE TILE: it names the two '
        'devices that move and the 4U they move by, and Apply pops exactly '
        'those moves', (tester) async {
      final doc = _example();
      final read = await pump(tester, doc);

      // The real radio, tapped the way a user taps it.
      await tester.tap(find.text('Bottom'));
      await tester.pumpAndSettle();

      expect(
        find.text('Keep rack at 16U (smallest that fits)'),
        findsOneWidget,
      );
      expect(
        find.text('2 devices shift down 4U. Nothing leaves the rack.'),
        findsOneWidget,
      );
      expect(
        find.text('Nothing is moved and nothing is lost.'),
        findsNothing,
        reason: 'a bottom trim moves everyone; the tile must not deny it',
      );

      // Select option 3 explicitly (a bottom trim here has a rescue, so the
      // preselection is compactFirst), then Apply.
      await tester.tap(
        find.text('Keep rack at 16U (smallest that fits)'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      // THE PREVIEW AND THE COMMIT AGREE.
      final popped = read();
      expect(popped, isNotNull);
      expect(popped!.toHeightU, 16);
      expect(_targets(popped.moves), {'A': 1, 'B': 14});
    });
  });

  // ── THE DOCUMENT, NOT THE PLAN ────────────────────────────────────────
  //
  // Everything above asserts a `ShrinkDecision`. That is one step short of
  // the property §4.1 rule 3 actually promises: a plan object can look
  // perfectly well-formed while the document it produces has a device
  // hanging outside the rack. The finding's own mutation — `keepSmallest`
  // returning `plan.toHeightU` instead of `plan.smallestFittingHeightU` —
  // is exactly that shape, and it is invisible to any assertion that stops
  // at the decision.
  //
  // So these APPLY the decision through the real core commands, in the same
  // order and composition `RackCanvasScreen._openShrinkDialog` uses
  // (`shrinkDisplacementCommands` first, `SetRackHeightCommand` last, one
  // transaction), and then interrogate the RESULTING DOCUMENT.
  group('the document after Apply', () {
    /// Applies [decision] the way the screen does and returns the
    /// controller, so the caller can inspect the document AND the undo
    /// stack.
    DocumentController apply(RackDocument doc, ShrinkDecision decision) {
      final controller = DocumentController(
        doc,
        clock: FixedClock(DateTime.utc(2026, 7, 18)),
      );
      controller.transact(LabelKey.resizeRack, (tx) {
        for (final c in shrinkDisplacementCommands(
          decision.moves,
          now: controller.clock.nowUtc(),
          actor: controller.actor,
        )) {
          tx.add(c);
        }
        // The screen's own no-phantom-entry guard.
        if (decision.toHeightU != doc.racks[_rackId]!.heightU) {
          tx.add(
            SetRackHeightCommand(
              id: _rackId,
              fromHeightU: doc.racks[_rackId]!.heightU,
              toHeightU: decision.toHeightU,
              now: controller.clock.nowUtc(),
              actor: controller.actor,
            ),
          );
        }
      });
      return controller;
    }

    /// Every rail occupant's `ruIndex`, by designator — read back off the
    /// document rather than off the plan that claimed to move them.
    Map<String, int> positions(RackDocument doc) => {
      for (final d in doc.devices.values)
        if (d.placement case final RailPlacement p) d.designator: p.ruIndex,
    };

    /// §4.1 rule 3's actual promise, as a checkable property of the result:
    /// NOBODY is left standing outside the rack. This is what "strand
    /// devices outside the rack undetected" means, and it holds for every
    /// option because every option is lossless.
    void expectAllInside(RackDocument doc) {
      final rack = doc.racks[_rackId]!;
      for (final d in doc.devices.values) {
        if (d.placement case final RailPlacement p) {
          final ref = d.templateRef;
          final h =
              doc.templates['${ref.templateId.v}@${ref.version}']!.body.frontU;
          expect(
            p.ruIndex,
            greaterThanOrEqualTo(1),
            reason: '${d.designator} fell below U1',
          );
          expect(
            p.ruIndex + h - 1,
            lessThanOrEqualTo(rack.heightU),
            reason:
                '${d.designator} (U${p.ruIndex}, ${h}U) is outside a '
                '${rack.heightU}U rack',
          );
        }
      }
    }

    testWidgets('EVERY choice, under EVERY trim direction, leaves every '
        'occupant inside the rack', (tester) async {
      // The matrix the finding asks for, asserted on the one property that
      // makes all three options honest. Each case is re-planned from a fresh
      // document, because applying one mutates it.
      for (final trim in TrimFrom.values) {
        for (final choice in ShrinkChoice.values) {
          final doc = _example();
          final plan = _plan(doc, 12, trim);
          if (!shrinkChoiceAvailable(plan, choice)) continue;

          final decision = resolveShrink(
            doc: doc,
            plan: plan,
            choice: choice,
            designator: 'RK-1',
          );
          apply(doc, decision);

          expect(
            doc.racks[_rackId]!.heightU,
            decision.toHeightU,
            reason:
                'the document must reach the height the tile showed '
                '($choice / $trim)',
          );
          expectAllInside(doc);
        }
      }
    });

    test('keepSmallest under a TOP trim: the rack really becomes 19U and '
        'NOBODY is renumbered', () {
      final doc = _example();
      final plan = _plan(doc, 12, TrimFrom.top);
      final controller = apply(
        doc,
        resolveShrink(
          doc: doc,
          plan: plan,
          choice: ShrinkChoice.keepSmallest,
          designator: 'RK-1',
        ),
      );

      expect(doc.racks[_rackId]!.heightU, 19);
      expect(positions(doc), {'A': 5, 'B': 18});
      expectAllInside(doc);

      // Rule 6: ONE undo entry for the whole Apply.
      expect(controller.undo.canUndo, isTrue);
      controller.undo.undo(doc);
      expect(doc.racks[_rackId]!.heightU, 20);
      expect(positions(doc), {'A': 5, 'B': 18});
      expect(controller.undo.canUndo, isFalse);
    });

    test('keepSmallest under a BOTTOM trim: the rack becomes 16U AND both '
        'survivors are really relocated, by the re-planned 4U', () {
      // The arm the option-3 tile used to deny ("Nothing is moved"). If
      // `resolveShrink` reused the plan's own 8U-sized `shiftMoves` here,
      // A would land at U-3 and this document would be corrupt.
      final doc = _example();
      final plan = _plan(doc, 12, TrimFrom.bottom);
      final controller = apply(
        doc,
        resolveShrink(
          doc: doc,
          plan: plan,
          choice: ShrinkChoice.keepSmallest,
          designator: 'RK-1',
        ),
      );

      expect(doc.racks[_rackId]!.heightU, 16);
      expect(positions(doc), {'A': 1, 'B': 14});
      expectAllInside(doc);

      controller.undo.undo(doc);
      expect(doc.racks[_rackId]!.heightU, 20);
      expect(
        positions(doc),
        {'A': 5, 'B': 18},
        reason: 'one undo restores the height AND every displacement',
      );
    });

    test("THE FINDING'S MUTATION, as a document property: shrinking to the "
        'REQUESTED height instead would push B outside the rack', () {
      // Not a mutation test in disguise — a positive statement of what
      // `keepSmallest` is for. Applying `plan.toHeightU` (12U) to this same
      // document with no moves leaves B at U18–U19 in a 12U rack, which is
      // the state rule 3 exists to prevent. Asserting that the honest choice
      // does NOT produce it is only meaningful alongside knowing the
      // dishonest one does.
      final doc = _example();
      final plan = _plan(doc, 12, TrimFrom.top);
      apply(
        doc,
        ShrinkDecision(
          toHeightU: plan.toHeightU, // the mutant's height
          moves: const [],
          summary: 'mutant',
        ),
      );
      expect(doc.racks[_rackId]!.heightU, 12);
      expect(
        () => expectAllInside(doc),
        throwsA(isA<TestFailure>()),
        reason:
            'this is the corruption keepSmallest avoids; if this ever '
            'stops throwing, expectAllInside has gone blind and every '
            'assertion above it is worthless',
      );
    });

    test('compactFirst applies its rescue moves AND reaches the achievable '
        'height', () {
      // Option 1's own document-level check: the compaction really happens,
      // and the height really lands where the tile said.
      final doc = _doc(20, [_at('A', 1, 2), _at('B', 18, 2)]);
      final plan = _plan(doc, 12, TrimFrom.top);
      expect(plan.rescue, isNotNull);
      final decision = resolveShrink(
        doc: doc,
        plan: plan,
        choice: ShrinkChoice.compactFirst,
        designator: 'RK-1',
      );

      apply(doc, decision);

      expect(doc.racks[_rackId]!.heightU, decision.toHeightU);
      expect(
        doc.racks[_rackId]!.heightU,
        lessThanOrEqualTo(20),
        reason: 'a shrink must not grow the rack',
      );
      expectAllInside(doc);
    });
  });

  // ── the casualty table tells the truth about its own U ranges ─────────
  //
  // `rack_shrink.dart` emits a SUBSTITUTE footprint for any occupant it
  // cannot model, so the occupant is named rather than silently skipped:
  // an unmodellable rail device gets `deviceH: 1` ("the least it can
  // possibly occupy") and a 0U occupant gets its CHANNEL's span (the whole
  // rack when the channel cannot be found). The table used to render all
  // three kinds through the same `U3` / `U1–U20` formatter, so the user
  // consented to displacing a device whose footprint the app had just told
  // them it knew. `grep kind shrink_rack_dialog.dart` returned nothing.
  group('the casualty table marks a substituted footprint as substituted', () {
    /// A 20U rack holding one ordinary 2U device at U18, one rail device
    /// whose template gives it ZERO U on the face it claims (the
    /// `DoomedKind.unmodelledRail` shape — reachable in the shipped app by
    /// quick-adding a 0U-vertical template onto the rails), and one 0U
    /// occupant naming a channel the rack does not have
    /// (`DoomedKind.zeroU`, reported as spanning the whole rack).
    RackDocument mixedDoc() {
      final doc = _doc(20, [_at('RAIL', 18, 2)]);

      // Front-mounted, but the template is rear-only: `boltedOccupantsOnFace`
      // resolves 0U on the front and skips it, which is exactly the case
      // `unmodelledRail` exists for.
      doc.templates['tpl.rearonly@1'] = TemplateSnapshot(
        templateId: const TemplateId('tpl.rearonly'),
        version: 1,
        contentHash: 'sha256:tpl.rearonly',
        capturedAt: DateTime.utc(2026),
        body: TemplateBody(
          manufacturer: 'Generic',
          model: 'rearonly',
          displayName: 'rearonly',
          rearU: 1,
          side: OccupancySide.rear,
          mountMethod: MountMethod.rackEars,
        ),
      );
      doc.devices[const Uuid('dev-GHOST')] = DeviceInstance(
        id: const Uuid('dev-GHOST'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.rearonly'),
          version: 1,
          contentHash: 'sha256:tpl.rearonly',
        ),
        designator: 'GHOST',
        name: 'Unmodelled device',
        placement: const RailPlacement(
          rackId: _rackId,
          ruIndex: 19,
          face: Face.front,
        ),
        meta: _meta(),
      );

      doc.devices[const Uuid('dev-PDU')] = DeviceInstance(
        id: const Uuid('dev-PDU'),
        kind: DeviceKind.pdu,
        templateRef: const TemplateRef(
          templateId: TemplateId('tpl.rearonly'),
          version: 1,
          contentHash: 'sha256:tpl.rearonly',
        ),
        designator: 'PDU-1',
        name: 'Vertical PDU',
        placement: const ZeroUPlacement(
          rackId: _rackId,
          channelId: 'no-such-channel',
          offsetFromChannelStart: Len.zero,
          orientation: ZeroUOrientation.vertical,
        ),
        meta: _meta(),
      );
      return doc;
    }

    Future<void> open(WidgetTester tester, RackDocument doc) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShrinkRackDialog(
              doc: doc,
              rackId: _rackId,
              requestedHeightU: 12,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Every string rendered by the dialog, so an assertion can be about
    /// what the USER reads rather than about a widget key.
    List<String> texts(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();

    testWidgets('the fixture really does produce all three kinds — otherwise '
        'everything below is vacuous', (tester) async {
      final plan = _plan(mixedDoc(), 12, TrimFrom.top);
      expect(
        plan.doomed.map((d) => d.kind).toSet(),
        {DoomedKind.rail, DoomedKind.unmodelledRail, DoomedKind.zeroU},
      );
      expect(plan.hasUnmodelledOccupants, isTrue);
    });

    testWidgets('an unmodelled rail device is NOT shown as a plain 1U '
        'occupant', (tester) async {
      await open(tester, mixedDoc());

      final rendered = texts(tester);
      // The bug, stated as an assertion: `U19 front` with nothing else on
      // it is indistinguishable from a genuinely 1U panel at U19.
      expect(
        rendered,
        isNot(contains('U19 front')),
        reason: 'a substituted 1U footprint must not read as a measured one',
      );
      expect(rendered, contains('U19 front †'));
      // And the marker is explained, not left as decoration.
      expect(
        rendered.any((t) => t.startsWith('†') && t.contains('LEAST')),
        isTrue,
        reason: 'the dagger needs a legend saying the range is a floor',
      );
    });

    testWidgets('a 0U occupant is NOT shown as a 20U-tall device', (
      tester,
    ) async {
      await open(tester, mixedDoc());

      final rendered = texts(tester);
      expect(
        rendered,
        isNot(contains('U1–U20 front')),
        reason: "the span is the CHANNEL's, not the device's height",
      );
      expect(rendered, contains('U1–U20 front ‡'));
      expect(
        rendered.any((t) => t.startsWith('‡') && t.contains('channel')),
        isTrue,
      );
    });

    testWidgets('a genuinely measured rail footprint carries NO marker and '
        'NO legend', (tester) async {
      // The guard on the guard: marking everything would be as useless as
      // marking nothing.
      await open(tester, _doc(20, [_at('RAIL', 18, 2)]));

      final rendered = texts(tester);
      expect(rendered, contains('U18–U19 front'));
      expect(rendered.any((t) => t.contains('†')), isFalse);
      expect(rendered.any((t) => t.contains('‡')), isFalse);
    });
  });
}
