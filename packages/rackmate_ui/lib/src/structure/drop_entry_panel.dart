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
// `LocationsPanel` and `RackInspectorPanel` already use, so `rackmate_ui`
// stays free of the controller. What this file must not do is decide;
// what it must not do EITHER is swallow a sentence core produced.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// What the app does with a line the panel has planned.
@immutable
final class DropEntryActions {
  const DropEntryActions({
    required this.onCommit,
    required this.onCreateLocation,
    required this.onCreateStructure,
  });

  /// Apply these commands as ONE undo entry. The plan is already built
  /// against the current document; the app runs it and nothing else.
  final void Function(DropLinePlanReady plan) onCommit;

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
  });

  final RackDocument doc;
  final DropEntryActions actions;

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

  @override
  void initState() {
    super.initState();
    _text.addListener(_replan);
    _focus.requestFocus();
  }

  @override
  void didUpdateWidget(DropEntryPanel old) {
    super.didUpdateWidget(old);
    // The document moved under us — a committed line, or an undo. The
    // preview is a function of the document, so it has to be recomputed
    // or it will show labels that are already taken.
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
      _plan = switch (parsed) {
        DropLineBlank() => null,
        DropLineMalformed(:final reason, :final column) => DropLinePlanRefused(
          reason,
          column,
        ),
        final DropLineParsed p => planDropLine(
          doc: widget.doc,
          line: p,
          // Diagnostics only for the preview; the committed commands are
          // rebuilt by the app against its own clock and actor.
          now: DateTime.now(),
          actor: 'preview',
        ),
      };
    });
  }

  void _submit() {
    switch (_plan) {
      case DropLinePlanReady(:final commands) when commands.isNotEmpty:
        widget.actions.onCommit(_plan! as DropLinePlanReady);
        // CLEARED ONLY ON SUCCESS, and focus is never given up. This is
        // the loop.
        _text.clear();
        _focus.requestFocus();
      case DropLinePlanNeedsLocation(:final locationName):
        widget.actions.onCreateLocation(locationName);
        _focus.requestFocus();
      case DropLinePlanNeedsStructure():
        widget.actions.onCreateStructure();
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
        TextField(
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
                  fontFamily: 'monospace',
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
