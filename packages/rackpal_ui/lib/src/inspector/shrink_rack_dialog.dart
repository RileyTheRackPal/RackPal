// packages/rackpal_ui/lib/src/inspector/shrink_rack_dialog.dart
//
// docs/04-rack-editor.md §4.1's shrink-below-occupancy modal — the one place
// a height change is allowed to become a conversation.
//
// THE GOVERNING PRINCIPLE, quoted because every decision here follows from
// it: "never destroy, never silently move, always name the casualties." So
// this dialog lists every doomed occupant by designator, description, U range
// and LINK COUNT (rule 4 — "link counts are shown, because that is the real
// cost signal"), and NO option it offers removes a device from the document.
// Rule 3 — "DELETION IS NOT OFFERED. Conflating 'the rack got smaller' with
// 'delete my equipment' is how tools lose data" — therefore holds trivially
// rather than by vigilance: there is no delete path to forget to guard.
//
// THIS WIDGET DECIDES; IT DOES NOT MUTATE. It pops a [ShrinkDecision] — a
// height and a list of displacements — and the screen composes those into the
// single `Transaction` rule 6 demands ("Apply is ONE undo entry covering the
// resize and every displacement"). Keeping the command-running on the screen
// matches every other surface in this app and lets the dialog's real decision
// logic be unit-tested through [resolveShrink] without pumping a widget.
//
// THE CASUALTY LIST IS NOT STATIC ACROSS THE "TRIM FROM" RADIO, and §4.1's
// own mockup implies it is. That is a spec simplification, not a design: rule
// 5's "Trim from: Bottom shifts every occupant's ruIndex DOWN by the removed
// count" produces a COMPLETELY DIFFERENT casualty set — the devices near U1
// instead of the devices near the top — and can produce NO casualties at all
// (a rack occupied only near its top loses nobody when the floor rises). So
// the whole plan is recomputed per direction, the options recompute with it,
// and a trim direction that turns out to be lossless gets its own option
// (see [ShrinkChoice.asRequested]) rather than being hidden behind a
// "smallest that fits" that would understate what is possible.
//
// ── OPTION 2 IS BUILT (DR-205 §11.204.6, `#967`) ──────────────────────────
//
// §4.1's second option, "Move the N above to the Staging Bin", was rendered
// DISABLED WITH ITS REASON for as long as there was no bin: no command made
// a `StagedPlacement`, nothing listed one and nothing brought one back, so
// offering it would have stranded devices where nobody could see them. The
// disabled tile was deliberate, on CR-114's principle that a refusal the user
// can see beats an option that silently is not there, and it is why the
// Staging Bin was found missing at all.
//
// DR-205 built the bin, so the option is live. A staged device keeps its id,
// its ports and every link, so moving one there is not the deletion rule 3
// forbids. It is still refused, and still shown with its reason, when a
// casualty is LOCKED: a locked device does not move (DR-186 §11.185.1), and
// staging is a move.
//
// ── RULE 2'S PRESELECTION, NOW AS WRITTEN ─────────────────────────────────
//
// Rule 2: "Option 1 is preselected when it fully succeeds; otherwise option 2
// is." While option 2 did not exist, [defaultShrinkChoice] substituted option
// 3 ("keep at the smallest height that fits"), inverting the letter to keep
// the intent. With the bin built the user chose the letter (§11.204.6): Enter
// gives the height that was typed, and the devices that do not fit wait in
// the bin with their wiring, one Ctrl+Z away.
//
// AND OPTION 1'S PARTIAL FORM TAKES THE SPEC'S OWN LABEL, *"2 of 3 fit, 1
// goes to Staging Bin"* (§11.204.6): it compacts, sends the leftovers to the
// bin and reaches the requested height. It falls back to stopping taller
// only when a leftover is locked.
//
// Nothing is dropped under any selection. Every option keeps every device;
// they differ in the height reached and in where the devices end up.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// Which of §4.1's options the user settled on.
enum ShrinkChoice {
  /// The requested height, exactly, because THIS trim direction loses
  /// nobody. Offered only when the current plan has no casualties — which is
  /// reachable via the "Trim from" radio (see the file header) and is the
  /// one outcome that gives the user precisely what they asked for.
  asRequested,

  /// §4.1 option 1 — "Compact first, then shrink". Offered only when
  /// compaction actually helps (rule 1). On partial success it sends the
  /// leftovers to the Staging Bin and reaches the requested height; when a
  /// leftover is locked it stops at the smallest height the compacted
  /// layout permits instead.
  compactFirst,

  /// §4.1 option 2 — "Move the N above to the Staging Bin" (DR-205). Every
  /// casualty is staged with its wiring and the rack reaches the requested
  /// height. Refused when a casualty is locked.
  moveToBin,

  /// §4.1 option 3 — "Keep rack at 18U (smallest that fits)". Always
  /// available, always lossless.
  keepSmallest,
}

/// A resolved choice: the height to apply and every displacement that must
/// land in the same undo entry (rule 6).
@immutable
final class ShrinkDecision {
  const ShrinkDecision({
    required this.toHeightU,
    required this.moves,
    required this.summary,
    this.staged = const [],
  });

  /// The height actually applied — NOT necessarily the height requested. On
  /// [ShrinkChoice.keepSmallest], and on a partial [ShrinkChoice.compactFirst]
  /// whose leftovers cannot be staged, it is deliberately larger.
  final int toHeightU;

  /// Every `MoveDeviceCommand` the screen must run BEFORE the height change,
  /// so no intermediate state has an occupant standing above the rack top.
  final List<CompactionMove> moves;

  /// The devices to send to the Staging Bin, FIRST, before [moves]: staging
  /// frees the U they held, and a staged device can no longer be moved.
  final List<Uuid> staged;

  /// One line for the status bar, stating what actually happened — including
  /// when that differs from what was asked for.
  final String summary;
}

/// Rule 2's preselection, as written (DR-205 §11.204.6): option 1 when it
/// fully succeeds, otherwise option 2, and option 3 only when the bin
/// refuses a casualty.
///
/// [binRefusedBy] is [binRefusals] for the plan's casualties.
ShrinkChoice defaultShrinkChoice(
  RackShrinkPlan plan, {
  List<String> binRefusedBy = const [],
}) {
  if (!plan.hasCasualties) return ShrinkChoice.asRequested;
  if (plan.rescue?.isFull ?? false) return ShrinkChoice.compactFirst;
  if (binRefusedBy.isEmpty) return ShrinkChoice.moveToBin;
  return ShrinkChoice.keepSmallest;
}

/// Whether [choice] is offerable against [plan] — the single predicate the
/// radio list and the preselection consult, so a disabled option can never
/// be preselected.
bool shrinkChoiceAvailable(
  RackShrinkPlan plan,
  ShrinkChoice choice, {
  List<String> binRefusedBy = const [],
}) => switch (choice) {
  ShrinkChoice.asRequested => !plan.hasCasualties,
  // Rule 1: "Option 1 appears ONLY when compaction actually helps."
  // `planRackShrink` returns a null rescue in exactly that case, so the
  // rule is enforced by the planner rather than remembered here.
  ShrinkChoice.compactFirst => plan.rescue != null,
  ShrinkChoice.moveToBin => plan.hasCasualties && binRefusedBy.isEmpty,
  ShrinkChoice.keepSmallest => true,
};

/// The designators among [who] the Staging Bin would refuse: a LOCKED rail
/// device does not move (DR-186 §11.185.1), and staging is a move. The
/// same test `planStageDevice` applies, asked here without building
/// commands for a choice nobody has made yet.
List<String> binRefusals(RackDocument doc, Iterable<DoomedOccupant> who) => [
  for (final d in who)
    if (doc.devices[d.deviceId]?.placement case RailPlacement(locked: true))
      d.designator,
];

/// Turns a choice into the height + displacements Apply will run.
///
/// PURE, and separate from the widget on purpose: this is where §4.1's real
/// arithmetic lives (which height, which moves, sized to which shift), and it
/// is worth testing without a widget tree.
///
/// [ShrinkChoice.keepSmallest] RE-PLANS rather than reusing [plan]'s own
/// `shiftMoves`. Those were sized to the REQUESTED height; a bottom trim that
/// stops early must shift every occupant by the smaller amount it actually
/// took, and re-asking the planner is how that stays one arithmetic instead
/// of two.
ShrinkDecision resolveShrink({
  required RackDocument doc,
  required RackShrinkPlan plan,
  required ShrinkChoice choice,
  required String designator,
}) {
  switch (choice) {
    case ShrinkChoice.asRequested:
      return ShrinkDecision(
        toHeightU: plan.toHeightU,
        moves: plan.shiftMoves,
        summary:
            'Resized $designator to ${plan.toHeightU}U'
            '${_shiftSuffix(plan.shiftMoves, plan.removedU)}.',
      );

    case ShrinkChoice.moveToBin:
      final staged = plan.doomed;
      return ShrinkDecision(
        toHeightU: plan.toHeightU,
        moves: plan.shiftMoves,
        staged: [for (final d in staged) d.deviceId],
        summary:
            'Resized $designator to ${plan.toHeightU}U; ${_names(staged)} '
            '${staged.length == 1 ? 'is' : 'are'} in the Staging Bin, wiring '
            'kept${_shiftSuffix(plan.shiftMoves, plan.removedU)}.',
      );

    case ShrinkChoice.compactFirst:
      final rescue = plan.rescue!;
      // THE SPEC'S PARTIAL LABEL, honoured (DR-205 §11.204.6): the
      // leftovers go to the bin and the rack reaches the height asked for,
      // with `binMoves`, whose bottom-trim shift is sized to that height.
      if (rescue.stillDoomed.isNotEmpty &&
          binRefusals(doc, rescue.stillDoomed).isEmpty) {
        final leftovers = rescue.stillDoomed;
        return ShrinkDecision(
          toHeightU: plan.toHeightU,
          moves: rescue.binMoves,
          staged: [for (final d in leftovers) d.deviceId],
          summary:
              'Compacted $designator and resized to ${plan.toHeightU}U; '
              '${_names(leftovers)} ${leftovers.length == 1 ? 'is' : 'are'} '
              'in the Staging Bin, wiring kept.',
        );
      }
      // Clamped for the same reason [ShrinkChoice.keepSmallest] is (see
      // [_withinBounds]). `rescue.moves` stay consistent with a clamped
      // height under both trim directions: a TOP trim renumbers nobody
      // (`_planRescue`'s `shift` is 0), and a BOTTOM trim's
      // `achievableHeightU` is `fromHeightU - (lowestBottom - 1)`, already
      // bounded by the rack's own height — so the clamp can only bite on a
      // document whose rack ALREADY exceeds CR-038, a state this dialog
      // cannot repair and does not make worse.
      final reached = _withinBounds(rescue.achievableHeightU);
      final partial = rescue.stillDoomed.isNotEmpty;
      return ShrinkDecision(
        toHeightU: reached,
        moves: rescue.moves,
        summary: partial
            // Says the height it actually reached, and why it is not the one
            // asked for — a summary that quietly reported success at a
            // different number would be the "silently move" §4.1 forbids,
            // one step removed.
            ? 'Compacted $designator and resized to ${reached}U — '
                  '${plan.toHeightU}U would have stranded '
                  '${_names(rescue.stillDoomed)}.'
            : 'Compacted $designator and resized to ${reached}U — '
                  '${rescue.freedU}U of gaps removed, nothing displaced.',
      );

    case ShrinkChoice.keepSmallest:
      final height = _withinBounds(plan.smallestFittingHeightU);
      final replan = planRackShrink(
        doc: doc,
        rackId: plan.rackId,
        toHeightU: height,
        trimFrom: plan.trimFrom,
      );
      final shifted = _shiftSuffix(replan.shiftMoves, replan.removedU);
      final overhang = replan.doomed.length == 1 ? 'overhangs' : 'overhang';
      return ShrinkDecision(
        toHeightU: height,
        moves: replan.shiftMoves,
        summary: replan.hasCasualties
            // Only reachable when [_withinBounds] actually bit: the rack's
            // contents do not fit inside CR-038's largest rack at all, so
            // "the smallest that fits its contents" would be a claim this
            // height does not honour. Name who is still over the line
            // instead — "always name the casualties" gets no exemption for
            // the arithmetic edge.
            ? 'Kept $designator at ${height}U — the largest a rack may be; '
                  '${_names(replan.doomed)} still $overhang it.'
            : 'Kept $designator at ${height}U — the smallest that fits '
                  'its contents$shifted.',
      );
  }
}

/// CR-038's `[1, 60]`, applied to every height [resolveShrink] returns.
///
/// NOT redundant with the screen's own `target.clamp(1, 60)`: that one
/// bounds what the user ASKED FOR, while these two heights are DERIVED —
/// [RackShrinkPlan.smallestFittingHeightU] and
/// [CompactionRescue.achievableHeightU] are computed from raw occupant U
/// values that `boltedOccupantsOnFace` deliberately does not clip to the rack
/// extent (so an already-overflowing device stays visible rather than being
/// hidden). A document decoded from JSON — explicitly the non-validating
/// path — can carry a device whose top U exceeds 60, making "the smallest
/// height that fits it" 61 or more. `SetRackHeightCommand` does not clamp
/// and `Rack.heightU`'s setter asserts `[1, 60]`, so an unclamped return
/// here crashes a debug build and silently violates CR-038 in release.
///
/// Clamped HERE rather than at the screen so the number the option tile
/// SHOWS and the number Apply USES are the same one — the tiles read their
/// heights back out of this function's own [ShrinkDecision].
int _withinBounds(int heightU) => heightU.clamp(1, kMaxRackHeightU);

String _shiftSuffix(List<CompactionMove> moves, int removedU) => moves.isEmpty
    ? ''
    : ', ${_devices(moves.length)} shifted down ${removedU}U';

String _devices(int n) => n == 1 ? '1 device' : '$n devices';

String _names(List<DoomedOccupant> who) {
  final names = who.map((d) => d.designator).toList();
  if (names.length == 1) return names.single;
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  return '${names.take(names.length - 1).join(', ')} and ${names.last}';
}

/// §4.1's modal. Opened ONLY from the screen's one height funnel, and only
/// when the requested height would strand an occupant.
///
/// Pops a [ShrinkDecision] on Apply, or null on Cancel/`Esc` — and Cancel
/// really is nothing at all: no command, no document mutation, and the rack
/// keeps the height it had.
class ShrinkRackDialog extends StatefulWidget {
  const ShrinkRackDialog({
    required this.doc,
    required this.rackId,
    required this.requestedHeightU,
    super.key,
  });

  final RackDocument doc;
  final Uuid rackId;

  /// What the user asked for, already clamped to CR-038's `[1, 60]` by the
  /// funnel.
  final int requestedHeightU;

  @override
  State<ShrinkRackDialog> createState() => _ShrinkRackDialogState();
}

class _ShrinkRackDialogState extends State<ShrinkRackDialog> {
  TrimFrom _trimFrom = TrimFrom.top;
  late ShrinkChoice _choice = defaultShrinkChoice(
    _plan,
    binRefusedBy: _binRefusedBy(_plan),
  );

  List<String> _binRefusedBy(RackShrinkPlan plan) =>
      binRefusals(widget.doc, plan.doomed);

  /// Recomputed from the model on every build — cheap (a pure pass over the
  /// occupants), and it means the radio and the option list can never be
  /// showing answers from two different trim directions.
  RackShrinkPlan get _plan => planRackShrink(
    doc: widget.doc,
    rackId: widget.rackId,
    toHeightU: widget.requestedHeightU,
    trimFrom: _trimFrom,
  );

  String get _designator => widget.doc.racks[widget.rackId]?.designator ?? '';

  void _setTrim(TrimFrom trim) {
    setState(() {
      _trimFrom = trim;
      // The chosen option may not survive the flip (option 1 vanishes when
      // compaction stops helping in the new direction; option "as requested"
      // appears when the new direction loses nobody). Keep the user's choice
      // when it is still offerable, otherwise fall back to the preselection
      // rule rather than leaving a selected-but-unavailable radio.
      final plan = _plan;
      final refused = _binRefusedBy(plan);
      if (!shrinkChoiceAvailable(plan, _choice, binRefusedBy: refused)) {
        _choice = defaultShrinkChoice(plan, binRefusedBy: refused);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;

    return AlertDialog(
      title: Text(
        'Shrink $_designator to ${widget.requestedHeightU}U?',
        style: theme.textTheme.titleMedium,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CasualtyList(plan: plan),
              const SizedBox(height: 16),
              _TrimSelector(
                value: _trimFrom,
                onChanged: _setTrim,
                // DR-186 §11.185.1: a bottom trim moves every rail device
                // down, so one locked anywhere in the rack refuses it. The
                // top stays offered, and every option stays lossless.
                bottomLockedBy: lockedAgainstBottomTrim(
                  widget.doc,
                  widget.rackId,
                ).map((d) => d.designator).toList(),
              ),
              const Divider(height: 24),
              // `RadioGroup` rather than per-tile `groupValue`/`onChanged`,
              // which Flutter deprecated — the same idiom the inspector's
              // own `_RadioPair` uses.
              RadioGroup<ShrinkChoice>(
                groupValue: _choice,
                onChanged: _pick,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: _options(plan),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            resolveShrink(
              doc: widget.doc,
              plan: plan,
              choice: _choice,
              designator: _designator,
            ),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  List<Widget> _options(RackShrinkPlan plan) {
    final rescue = plan.rescue;
    // OPTION 3'S TILE IS RENDERED FROM THE DECISION APPLY WILL RUN, not from
    // a hand-written description of it. This subtitle used to be the constant
    // "Nothing is moved and nothing is lost.", which is true of a TOP trim
    // and false of a BOTTOM one: `resolveShrink` re-plans at the smaller
    // height and returns `shiftMoves` relocating every surviving occupant, so
    // the tile promised stillness while Apply moved the whole rack — and the
    // status line it produced then said so, leaving the dialog's two surfaces
    // contradicting each other. Calling the resolver is the only version of
    // this that cannot drift again: there is no second spelling of the
    // outcome to keep in sync. It is a pure pass over the occupants, `build`
    // already recomputes the plan itself on every frame for the same reason,
    // and `_setTrim`'s `setState` is what makes both track the radio.
    final keepSmallest = resolveShrink(
      doc: widget.doc,
      plan: plan,
      choice: ShrinkChoice.keepSmallest,
      designator: _designator,
    );
    final binRefusedBy = _binRefusedBy(plan);
    // The same test `resolveShrink` makes for option 1's partial form, so
    // the tile and Apply cannot disagree about where the leftovers go.
    final leftoversStage =
        rescue != null &&
        rescue.stillDoomed.isNotEmpty &&
        binRefusals(widget.doc, rescue.stillDoomed).isEmpty;
    return [
      if (shrinkChoiceAvailable(plan, ShrinkChoice.asRequested))
        _OptionTile(
          value: ShrinkChoice.asRequested,
          title: 'Shrink to ${plan.toHeightU}U as asked',
          subtitle: plan.shiftMoves.isEmpty
              ? 'Trimming from the ${plan.trimFrom.name} loses nobody.'
              : '${_devices(plan.shiftMoves.length)} shift down '
                    '${plan.removedU}U. Nothing leaves the rack.',
        ),
      if (rescue != null)
        _OptionTile(
          value: ShrinkChoice.compactFirst,
          // Rule 1: "its label states the outcome". Both spellings below are
          // the real outcome of pressing Apply with this selected — never a
          // hopeful one.
          title: rescue.isFull || leftoversStage
              ? 'Compact first, then shrink'
              : 'Compact first, then shrink to '
                    '${rescue.achievableHeightU}U',
          subtitle: rescue.isFull
              // §4.1's own example reads "Removes 6U of gaps. All 3 fit
              // below U12." for a 12U target — which is off by one against
              // this codebase's bottom-origin, inclusive RU indexing (a
              // device AT U12 is inside a 12U rack). "within 12U" says the
              // same thing without the boundary ambiguity.
              ? 'Removes ${rescue.freedU}U of gaps. '
                    '${rescue.rescued.length == 1 ? 'It fits' : 'All '
                              '${rescue.rescued.length} fit'} within '
                    '${plan.toHeightU}U.'
              // The spec's own partial label, "2 of 3 fit, 1 goes to
              // Staging Bin" (DR-205 §11.204.6).
              : leftoversStage
              ? 'Removes ${rescue.freedU}U of gaps. '
                    '${rescue.rescued.length} of '
                    '${rescue.rescued.length + rescue.stillDoomed.length} fit '
                    'within ${plan.toHeightU}U; '
                    '${_names(rescue.stillDoomed)} '
                    '${rescue.stillDoomed.length == 1 ? 'goes' : 'go'} to the '
                    'Staging Bin, wiring kept.'
              // A LOCKED leftover cannot be staged, so this stops taller and
              // displaces nobody.
              : 'Removes ${rescue.freedU}U of gaps. '
                    '${rescue.rescued.length} of '
                    '${rescue.rescued.length + rescue.stillDoomed.length} fit '
                    'within ${plan.toHeightU}U; ${rescue.achievableHeightU}U '
                    'is the smallest that also fits '
                    '${_names(rescue.stillDoomed)}.',
        ),
      if (plan.hasCasualties)
        if (binRefusedBy.isEmpty)
          _OptionTile(
            value: ShrinkChoice.moveToBin,
            title: plan.doomed.length == 1
                ? 'Move the 1 above to the Staging Bin'
                : 'Move the ${plan.doomed.length} above to the Staging Bin',
            subtitle:
                'Shrinks to ${plan.toHeightU}U. ${_names(plan.doomed)} '
                '${plan.doomed.length == 1 ? 'keeps its' : 'keep their'} '
                'wiring and can be put back from the bin.',
          )
        else
          _StagingBinRefused(
            count: plan.doomed.length,
            lockedBy: binRefusedBy,
          ),
      _OptionTile(
        value: ShrinkChoice.keepSmallest,
        // §4.1 option 3, verbatim in shape — but the height comes from the
        // resolved decision rather than `plan.smallestFittingHeightU`, so a
        // value CR-038's ceiling clamped cannot read one number here and
        // apply another.
        title: 'Keep rack at ${keepSmallest.toHeightU}U (smallest that fits)',
        subtitle: keepSmallest.moves.isEmpty
            ? 'Nothing is moved and nothing is lost.'
            : '${_devices(keepSmallest.moves.length)} shift down '
                  '${plan.fromHeightU - keepSmallest.toHeightU}U. '
                  'Nothing leaves the rack.',
      ),
    ];
  }

  void _pick(ShrinkChoice? choice) {
    if (choice == null) return;
    setState(() => _choice = choice);
  }
}

/// Rule 4's cost table: "designator, description, U range, and LINK COUNT".
///
/// AND [DoomedOccupant.kind], which this table used to drop on the floor.
/// `rack_shrink.dart` exists partly so an occupant it cannot model is
/// COUNTED rather than skipped: a rail device whose template resolves to
/// zero height on its claimed face is emitted with `deviceH: 1` because
/// that is "the least it can possibly occupy", and a 0U occupant is
/// emitted spanning its CHANNEL (the whole rack, when the channel it names
/// cannot be found). Both are deliberately conservative SUBSTITUTES.
/// Printing them through the same `U3` / `U1–U42` formatter as a measured
/// rail footprint hands the user a number the app does not actually know,
/// in the one dialog whose entire job is to state the cost of a
/// destructive-feeling action accurately. Every non-`rail` casualty is
/// therefore marked, and the marker is explained under the table.
class _CasualtyList extends StatelessWidget {
  const _CasualtyList({required this.plan});

  final RackShrinkPlan plan;

  /// The footnote marker for [kind], or null when the range is measured.
  static String? _marker(DoomedKind kind) => switch (kind) {
    DoomedKind.rail => null,
    DoomedKind.unmodelledRail => '†',
    DoomedKind.zeroU => '‡',
  };

  static String _footnote(DoomedKind kind) => switch (kind) {
    DoomedKind.rail => '',
    DoomedKind.unmodelledRail =>
      '†  Height not known. Nothing in the document says how tall this '
          'device is on the face it claims, so the U range shows the LEAST '
          'it can occupy. It may occupy more.',
    DoomedKind.zeroU =>
      "‡  0U occupant. The U range is its vertical channel's span — the "
          "range that must survive for it to keep a home — not the device's "
          'own height. A channel that cannot be found is shown as the whole '
          'rack.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (plan.doomed.isEmpty) {
      return Text(
        'Trimming from the ${plan.trimFrom.name} leaves every device with '
        'its U. Nothing is displaced out of the rack.',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          plan.doomed.length == 1
              ? '1 device would lose its U:'
              : '${plan.doomed.length} devices would lose their U:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (final d in plan.doomed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    d.designator,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: kConsoleEmphasis,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    d.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 124,
                  child: Builder(
                    builder: (context) {
                      final marker = _marker(d.kind);
                      final text = Text(
                        '${_uRange(d)} ${d.face.name}'
                        '${marker == null ? '' : ' $marker'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      );
                      if (marker == null) return text;
                      return Tooltip(
                        message: _footnote(d.kind),
                        child: text,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 64,
                  // Rule 4: "Link counts are shown, because that is the real
                  // cost signal." A REAL count — `linkCountForDevice` walks
                  // the device's materialised ports and the document's links
                  // — so a rack with no wiring yet truthfully reads 0 rather
                  // than showing a fabricated or unknown value.
                  child: Text(
                    d.linkCount == 1 ? '1 link' : '${d.linkCount} links',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // The legend, printed only for the markers actually on screen — in
        // the enum's own order so it does not shuffle between plans.
        for (final kind in DoomedKind.values)
          if (kind != DoomedKind.rail && plan.doomed.any((d) => d.kind == kind))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _footnote(kind),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
      ],
    );
  }

  static String _uRange(DoomedOccupant d) =>
      d.deviceH == 1 ? 'U${d.ruIndex}' : 'U${d.ruIndex}–U${d.topRu}';
}

/// §4.1's "Trim from: (o) Top ( ) Bottom" radio.
class _TrimSelector extends StatelessWidget {
  const _TrimSelector({
    required this.value,
    required this.onChanged,
    this.bottomLockedBy = const <String>[],
  });

  final TrimFrom value;
  final ValueChanged<TrimFrom> onChanged;

  /// The locked devices a bottom trim would move, by designator. Non-empty
  /// disables `Bottom` and says why (DR-186 §11.185.1).
  final List<String> bottomLockedBy;

  /// A stable handle for tests.
  static const Key lockedNoteKey = ValueKey('shrink-bottom-locked');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = bottomLockedBy;
    final row = Row(
      children: [
        Text('Trim from:', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 12),
        Expanded(
          child: RadioGroup<TrimFrom>(
            groupValue: value,
            onChanged: (v) {
              if (v != null && v != value) onChanged(v);
            },
            child: Row(
              children: [
                for (final trim in TrimFrom.values)
                  Expanded(
                    child: RadioListTile<TrimFrom>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      value: trim,
                      enabled: trim == TrimFrom.top || locked.isEmpty,
                      title: Text(
                        trim == TrimFrom.top ? 'Top' : 'Bottom',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    if (locked.isEmpty) return row;
    // NAMED, because a disabled radio with no reason is the "the app is
    // broken" silence docs/04 §3.4 refuses for a blocked nudge.
    final who = locked.length == 1
        ? '${locked.single} is locked'
        : '${locked.take(3).join(', ')}'
              '${locked.length > 3 ? ' and ${locked.length - 3} more' : ''}'
              ' are locked';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Text(
          'Bottom is unavailable: $who, and trimming from the bottom moves '
          'every device down.',
          key: lockedNoteKey,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final ShrinkChoice value;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RadioListTile<ShrinkChoice>(
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// §4.1's option 2 when a casualty is LOCKED, rendered disabled with its
/// reason: a locked device does not move (DR-186 §11.185.1), and staging is
/// a move. Shown rather than omitted, on CR-114's principle, because the
/// dialog is declining the height asked for and this is part of why.
///
/// DELIBERATELY NOT A `RadioListTile`. An inert radio tile would have to
/// carry [ShrinkChoice.moveToBin] and would then read as selectable. A plain
/// disabled `ListTile` with a radio-shaped leading icon reads as "an
/// option, unavailable" without joining the group at all.
class _StagingBinRefused extends StatelessWidget {
  const _StagingBinRefused({required this.count, required this.lockedBy});

  final int count;
  final List<String> lockedBy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return ListTile(
      enabled: false,
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.radio_button_unchecked, size: 20, color: disabled),
      title: Text(
        count == 1
            ? 'Move the 1 above to the Staging Bin'
            : 'Move the $count above to the Staging Bin',
        style: theme.textTheme.bodyMedium?.copyWith(color: disabled),
      ),
      subtitle: Text(
        '${lockedBy.join(', ')} ${lockedBy.length == 1 ? 'is' : 'are'} '
        'locked, and a locked device does not move. Unlock '
        '${lockedBy.length == 1 ? 'it' : 'them'} to use the bin.',
        style: theme.textTheme.bodySmall?.copyWith(color: disabled),
      ),
    );
  }
}
