// What a bulk operation is about to do to one row, before it does it.
// DR-078 §11.77.3, M4-F7/F8/F9.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE SHAPE, BECAUSE THE RULING GAVE THREE DIALOGS ONE PREVIEW
// ═══════════════════════════════════════════════════════════════════════
// `Renumber…`, `Find & replace` and `Change type…` each write across N
// rows at once, and DR-078 rules that each shows a per-row before-and-after
// list before it fires. Three typedefs would be three widgets and three
// spellings of "before"; this is the shape all three produce, so
// `rackmate_ui` draws one list.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THE PREVIEW AND THE WRITE ARE ONE WALK, NOT TWO
// ═══════════════════════════════════════════════════════════════════════
// Every `build…` in this family derives its commands FROM its own preview
// rather than computing the same thing twice, and each has a test asserting
// the two agree. A preview that is a second implementation of the write is
// a preview that can lie, and a lying preview is worse than none: it is the
// screen a person trusts while approving something else.
//
// STRINGS, NOT VALUES. A preview is read, not acted on, so a row carries
// what a cell would PRINT rather than a typed value. That is what lets one
// list show a label rewrite, a key rename and a connector change without
// knowing what any of them are, and it is why `Change type…`'s rows can say
// `HDMI Type A -> RJ45` in the trade's words rather than in ids.

/// One row of a bulk operation's impact list.
///
/// `note` is the clause that makes this list worth showing rather than
/// counting: it is where a row says what ELSE the write will do to it, or
/// why it is exempt. `Change type…` uses it to name a value the family's
/// default would overwrite (DR-060), and `Find & replace` uses it to say
/// that a key was already published when the builder opened (CR-051).
/// Null is the ordinary case and prints nothing.
typedef PortImpactRow = ({
  String key,
  String before,
  String after,
  String? note,
});

/// Whether `rows` holds anything a person needs to look at twice.
///
/// A count of rows carrying a `note`, which is what a dialog puts in its
/// summary line: "12 rows, 3 with something to check" is a sentence a
/// person can act on, and "12 rows" is not.
int portImpactNoteCount(Iterable<PortImpactRow> rows) =>
    rows.where((row) => row.note != null).length;

/// The rows whose value actually changes.
///
/// A NO-OP ROW STILL SHOWS. A person who searched for something that
/// matches twelve rows and changes none of them has learned the most
/// useful thing the dialog can tell them, and hiding those rows would
/// leave an empty list under a non-zero count.
Iterable<PortImpactRow> portImpactChanges(Iterable<PortImpactRow> rows) =>
    rows.where((row) => row.before != row.after);
