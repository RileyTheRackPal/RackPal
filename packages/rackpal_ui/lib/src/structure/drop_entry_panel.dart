// docs/07 §4.3's command mode, as a surface. Board M3-C/1 (#147), DR-023.
//
// ═══════════════════════════════════════════════════════════════════════
// THE REPEAT LOOP IS THE FEATURE, AND M1 IS WHY
// ═══════════════════════════════════════════════════════════════════════
// #147's own instruction: *"M1's drill was REFUTED because each placement
// broke the repeat loop, and the first re-run failed AGAIN for reasons
// nothing predicted and 2206 tests could not see. 60 drops in 15 minutes
// is ~15 seconds per drop INCLUDING thinking."*
//
// So the loop is the design, and everything else is subordinate to it:
//
//   * the field NEVER loses focus. Committing clears the text and leaves
//     the caret where it was, so the next line starts with a letter and
//     not with a click;
//   * `Enter` is the only commit and there is no button beside it that
//     also commits. Two ways to do the same thing is two things to look
//     at while typing;
//   * a refusal does NOT clear the field. The line stays, the caret goes
//     to the column that failed, and one keystroke fixes it. Clearing on
//     error is how a surface makes a person retype nine drops because
//     they wrote `Cat9`;
//   * the preview is live and costs nothing, because `planDropLine`
//     mutates no document and can run on every keystroke.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PREVIEW SHOWS LABELS, NOT A COUNT
// ═══════════════════════════════════════════════════════════════════════
// "9 drops" is a number a person cannot check. `LR-C6-1 … LR-22/4-1` is
// the thing that will be printed on cable, and seeing it before Enter is
// the only moment where a wrong room code costs one keystroke instead of
// a re-label. CR-048 stores a designator once at creation, so this
// preview is the last cheap moment there is.
//
// ═══════════════════════════════════════════════════════════════════════
// NO COMMANDS RUN HERE
// ═══════════════════════════════════════════════════════════════════════
// The panel takes the document and callbacks, the shape
// `LocationsPanel` and `RackInspectorPanel` already use, so `rackpal_ui`
// stays free of the controller. What this file must not do is decide;
// what it must not do EITHER is swallow a sentence core produced.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';

/// The loop with its "just added" tail.
///
/// THERE WAS A `showDropEntryPanel` DIALOG HERE AND IT IS GONE, which is
/// what this file's header always said would happen: "board #148's
/// Structure editor is where this lives permanently, as its command mode
/// beside table mode", and the dialog existed only so that a loop nobody
/// could reach was not a loop nobody had driven. `StructureEditorScreen`
/// embeds this widget as the quick-add bar across the top of the table,
/// which is where docs/07 §4 draws it. Keeping the dialog as a second
/// route would be a second surface to keep true, opening a panel over
/// whichever tab happened to be showing.
///
/// [currentDoc] is read on EVERY build rather than captured once, and
/// that is what makes the loop work across commits. A host holding one
/// document reference would plan the second line against the state before
/// the first one landed, and offer labels the first line just spent.
class DropEntryLoop extends StatefulWidget {
  const DropEntryLoop({
    required this.actions,
    required this.currentDoc,
    super.key,
    this.structureBodyId,
  });

  final DropEntryActions actions;

  /// The Structure body the editor's picker is on (M3-E/3, #158). Null on
  /// a project with one body, where there is nothing to disambiguate.
  final Uuid? structureBodyId;

  /// Read on every build. See the class doc.
  final RackDocument Function() currentDoc;

  @override
  State<DropEntryLoop> createState() => _DropEntryLoopState();
}

class _DropEntryLoopState extends State<DropEntryLoop> {
  final List<String> _recent = [];

  @override
  Widget build(BuildContext context) => DropEntryPanel(
    doc: widget.currentDoc(),
    recent: _recent,
    structureBodyId: widget.structureBodyId,
    actions: DropEntryActions(
      onCommit: (line, {structureBodyId}) {
        // The LOOP's body wins over anything a caller passed, because the
        // loop is the thing sitting under the picker.
        final committed = widget.actions.onCommit(
          line,
          structureBodyId: structureBodyId ?? widget.structureBodyId,
        );
        // The tail reports what the APP did, not what the preview
        // predicted, for the same reason `onCommit` takes the line.
        if (committed is DropLinePlanReady) {
          setState(() => _recent.insert(0, committed.fieldLabels.join(', ')));
        }
        return committed;
      },
      onCreateLocation: (name) {
        widget.actions.onCreateLocation(name);
        setState(() {});
      },
      onCreateStructure: () {
        widget.actions.onCreateStructure();
        setState(() {});
      },
    ),
  );
}

/// What the app does with a line the panel has planned.
@immutable
final class DropEntryActions {
  const DropEntryActions({
    required this.onCommit,
    required this.onCreateLocation,
    required this.onCreateStructure,
  });

  /// Commit one line, and report what actually happened.
  ///
  /// THE PARSED LINE CROSSES THIS BOUNDARY, NOT THE PREVIEW'S PLAN, and
  /// that is deliberate. The preview is planned on every keystroke with
  /// a throwaway clock and no real actor, because it exists to be looked
  /// at; those values reach `EntityMeta.createdAt` and `.updatedBy` on
  /// every command a plan holds. Handing the preview's commands to the
  /// app would write the preview's timestamp and the string `preview`
  /// onto sixty cables, and nothing downstream would ever question it.
  ///
  /// So the app re-plans against its OWN clock and actor and returns the
  /// result, which the panel then displays. Re-planning is free
  /// (`planDropLine` mutates nothing) and gives the same labels, because
  /// nothing changed between the last keystroke and `Enter` — a property
  /// `drop_line_planner_test.dart` asserts directly rather than assumes.
  ///
  /// `structureBodyId` is the body the editor's picker is on (M3-E/3,
  /// #158). Passed PER COMMIT rather than captured when the action is
  /// built, because the app builds this once as the editor opens and the
  /// picker moves afterwards.
  final DropLinePlan Function(
    DropLineParsed line, {
    Uuid? structureBodyId,
  })
  onCommit;

  /// The room the line named does not exist. Creating it is the user's
  /// call, taken with one keystroke, and never this panel's.
  final void Function(String name) onCreateLocation;

  /// The project has no Structure device to hang an outlet on.
  final VoidCallback onCreateStructure;
}

/// One text field and a live preview of what it will create.
class DropEntryPanel extends StatefulWidget {
  const DropEntryPanel({
    required this.doc,
    required this.actions,
    super.key,
    this.recent = const [],
    this.structureBodyId,
  });

  final RackDocument doc;
  final DropEntryActions actions;

  /// The Structure body the editor's picker is on (M3-E/3, #158).
  final Uuid? structureBodyId;

  /// What the last few committed lines produced, newest first. Shown so
  /// the loop has a visible tail: a person entering sixty drops needs to
  /// see that the last line landed without looking away from the field.
  final List<String> recent;

  @override
  State<DropEntryPanel> createState() => _DropEntryPanelState();
}

class _DropEntryPanelState extends State<DropEntryPanel> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  DropLinePlan? _plan;

  /// The line behind [_plan], kept so `Enter` can hand the APP the line
  /// rather than the preview's commands.
  DropLineParsed? _parsed;

  @override
  void initState() {
    super.initState();
    _text.addListener(_replan);
    _focus.requestFocus();
  }

  @override
  void didUpdateWidget(DropEntryPanel old) {
    super.didUpdateWidget(old);
    // A DIFFERENT DOCUMENT — a file opened, a new project. The preview is
    // a function of the document, so it has to be recomputed or it will
    // show labels that are already taken.
    //
    // THIS CANNOT SEE AN IN-PLACE EDIT, AND IT NEVER COULD. Commands
    // mutate `RackDocument` in place, so `identical` is true across every
    // commit this panel makes; the reason the loop still works is that
    // committing CLEARS the field, and clearing fires the text listener,
    // which re-plans. The two arms that do not clear the field re-plan
    // for themselves. See [_submit].
    if (!identical(old.doc, widget.doc)) _replan();
  }

  @override
  void dispose() {
    _text
      ..removeListener(_replan)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  void _replan() {
    final parsed = parseDropLine(_text.text);
    setState(() {
      _parsed = parsed is DropLineParsed ? parsed : null;
      _plan = switch (parsed) {
        DropLineBlank() => null,
        DropLineMalformed(:final reason, :final column) => DropLinePlanRefused(
          reason,
          column,
        ),
        // PREVIEW VALUES, AND THEY NEVER REACH A DOCUMENT. See
        // `DropEntryActions.onCommit`: the app re-plans on commit with
        // its own clock and actor, because these two would otherwise be
        // written onto every drop's `EntityMeta`.
        final DropLineParsed p => planDropLine(
          doc: widget.doc,
          line: p,
          now: DateTime.now(),
          actor: 'preview',
        ),
      };
    });
  }

  void _submit() {
    switch (_plan) {
      case DropLinePlanReady(:final commands) when commands.isNotEmpty:
        final committed = widget.actions.onCommit(
          _parsed!,
          structureBodyId: widget.structureBodyId,
        );
        // THE APP'S ANSWER WINS over the preview's, including when it
        // disagrees. It cannot today, but a panel that showed its own
        // guess after the fact would hide the day it starts to.
        if (committed is! DropLinePlanReady) {
          _focus.requestFocus();
          return;
        }
        // CLEARED ONLY ON SUCCESS, and focus is never given up. This is
        // the loop.
        _text.clear();
        _focus.requestFocus();
      // ═══════════════════════════════════════════════════════════════
      // THE TWO OFFER ARMS RE-PLAN, AND WITHOUT THAT THE OFFER IS A TRAP
      // ═══════════════════════════════════════════════════════════════
      // Each accepts an offer by changing the document and then KEEPS THE
      // LINE, so the same `Enter` that took the offer can commit it. But
      // `_plan` is a value computed from a document that has just changed
      // underneath it, and `didUpdateWidget` cannot notice: commands
      // mutate `RackDocument` in place, so the reference is `identical`.
      //
      // Without the re-plan, `_plan` is still `NeedsStructure` on the
      // second press, so the second `Enter` creates a SECOND Structure
      // device instead of the drops — and a third makes a third. The
      // commit arm is safe only because clearing the field fires the text
      // listener. Found by `structure_editor_route_test.dart`, driving
      // the loop from a blank project, which is the state every new
      // project is in and therefore the first thing a new user meets.
      case DropLinePlanNeedsLocation(:final locationName):
        widget.actions.onCreateLocation(locationName);
        _replan();
        _focus.requestFocus();
      case DropLinePlanNeedsStructure():
        widget.actions.onCreateStructure();
        _replan();
        _focus.requestFocus();
      case _:
        // A refusal keeps the text. See the file header.
        _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ═══════════════════════════════════════════════════════════
        // AN EMPTY BOX HANDS `Ctrl+Z` BACK TO THE DOCUMENT (DR-159
        // §11.158.8)
        // ═══════════════════════════════════════════════════════════
        // This field AUTOFOCUSES, because typing a drop is what somebody
        // comes to this tab to do, and `_submit` refocuses it and clears
        // it after every entry. So on the one tab whose primary verb is
        // bulk data entry, a text field held focus permanently, and
        // `DefaultTextEditingShortcuts` therefore claimed `Ctrl+Z` for
        // `UndoTextIntent`. With nothing typed there was nothing to
        // restore, so the key did nothing at all: the very complaint
        // `#874` was filed about, surviving inside its own fix.
        //
        // **THE CONDITION IS THE WHOLE DESIGN.** A box with text in it
        // has typing worth taking back and keeps the key. An EMPTY one
        // has none, so it forwards, and this `Shortcuts` sits nearer the
        // field than `DefaultTextEditingShortcuts` does and therefore
        // wins. The panel already rebuilds on every keystroke
        // (`_text.addListener(_replan)`), so the swap tracks the box.
        Shortcuts(
          shortcuts: _text.text.isEmpty
              ? <ShortcutActivator, Intent>{
                  keymapActivator(KeyBindingId.undo): const UndoIntent(),
                  keymapActivator(KeyBindingId.redo): const RedoIntent(),
                  keymapActivator(
                    KeyBindingId.redoAlternate,
                  ): const RedoIntent(),
                }
              : const <ShortcutActivator, Intent>{},
          child: TextField(
            controller: _text,
            focusNode: _focus,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Add drops',
              hintText: 'Living Room: 4x Cat6, 2x RG6',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 8),
        _Preview(plan: _plan, text: _text.text),
        if (widget.recent.isNotEmpty) ...[
          const Divider(height: 24),
          Text('Just added', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          for (final line in widget.recent.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: theme.textTheme.bodySmall),
            ),
        ],
      ],
    );
  }
}

/// The line below the field: what will happen, or why it will not.
class _Preview extends StatelessWidget {
  const _Preview({required this.plan, required this.text});

  final DropLinePlan? plan;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (plan) {
      case null:
        return Text(
          'One room per line. Enter adds the drops and clears the field.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );

      case DropLinePlanReady(
        :final dropCount,
        :final fieldLabels,
        :final outletCreated,
        :final warnings,
      ):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$dropCount ${dropCount == 1 ? "drop" : "drops"}'
              '${outletCreated ? ", a new outlet" : ""}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            // THE LABELS THEMSELVES. Elided in the middle rather than
            // truncated at the end, because the LAST one is the one a
            // person is checking the sequence of.
            Text(
              _elide(fieldLabels),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  w,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.tertiary,
                  ),
                ),
              ),
          ],
        );

      case DropLinePlanNeedsLocation(:final locationName):
        // AN OFFER, NOT AN ERROR. Same key that commits a good line.
        return Text(
          'No room called "$locationName" yet. Enter creates it.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
        );

      case DropLinePlanNeedsStructure():
        return Text(
          'This project has no Structure device yet. Enter creates one.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
        );

      case DropLinePlanRefused(:final reason, :final column):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (column != null && column <= text.length)
              Text(
                '${" " * column}^',
                style: theme.textTheme.bodySmall?.copyWith(
                  // RackMono: the caret above is placed by counting
                  // spaces, so a proportional fallback puts it under the
                  // wrong character and nothing fails.
                  fontFamily: 'RackMono',
                  color: scheme.error,
                ),
              ),
            Text(
              reason,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        );
    }
  }

  /// `LR-C6-1, LR-C6-2 … LR-22/4-1` — first two and last, when there are
  /// more than four. The middle of a run of nine is the part nobody
  /// checks; the ends are what say whether the sequence started and
  /// finished where it should.
  static String _elide(List<String> labels) {
    if (labels.length <= 4) return labels.join(', ');
    return '${labels[0]}, ${labels[1]} … ${labels.last}';
  }
}
