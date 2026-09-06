// The control that finally lets somebody TYPE a mount note (`#839`,
// M5-L, DR-130 §11.129).
//
// ═════════════════════════════════════════════════════════════════════
// WHY A CONTROL IS THE DELIVERABLE AND NOT THE DECORATION
// ═════════════════════════════════════════════════════════════════════
// `OffRackPlacement.mountNote` was modelled, serialized, round-tripped
// and seeded, and no gesture ever wrote one. DR-125 priced the cabinet
// head end against it anyway. `SetMountNoteCommand` gave it a writer and
// the equipment sheet gave it a reader; without this widget the chain
// still ends one step short of a person, which is exactly the shape
// `#847` records for the whole DRC panel.
import 'package:flutter/material.dart';

/// The label the control shows, and the string a test looks for.
const String kMountNoteLabel = 'Mount note';

/// What it says when the field is empty.
///
/// THE HINT IS AN EXAMPLE, NOT AN INSTRUCTION. A person who has just
/// dropped a modem into a closet needs to see the SHAPE of the answer,
/// and "AV closet, top shelf, sideways" carries three facts the trade
/// actually records: which space, where in it, and how the box sits.
const String kMountNoteHint = 'AV closet, top shelf, sideways';

/// A single-line free-text control over `OffRackPlacement.mountNote`.
///
/// COMMITS ON EVERY KEYSTROKE, DELIBERATELY, because
/// `SetMountNoteCommand` declares a `mergeKey` over the device id and
/// consecutive edits collapse into ONE undo entry. Committing on submit
/// instead was the alternative and loses the note when the panel is
/// dismissed by clicking away, which is how the control is most often
/// left.
class MountNoteField extends StatefulWidget {
  const MountNoteField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The note currently on the placement, or null when there is none.
  final String? value;

  final ValueChanged<String> onChanged;

  @override
  State<MountNoteField> createState() => _MountNoteFieldState();
}

class _MountNoteFieldState extends State<MountNoteField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );

  @override
  void didUpdateWidget(MountNoteField old) {
    super.didUpdateWidget(old);
    // ONLY when the incoming value genuinely differs from what is on
    // screen. Assigning unconditionally would fight the user: every
    // keystroke commits, which rebuilds this widget with the value it
    // just sent, and resetting the text then moves the caret to the end
    // on every character.
    final incoming = widget.value ?? '';
    if (incoming != _controller.text) _controller.text = incoming;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: _controller,
      decoration: const InputDecoration(
        labelText: kMountNoteLabel,
        hintText: kMountNoteHint,
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    ),
  );
}
