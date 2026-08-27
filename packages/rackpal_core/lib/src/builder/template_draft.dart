// AC-049's `Draft` flag, which is DERIVED and never stored. Board #202,
// M4-D/4.
//
// ═════════════════════════════════════════════════════════════════════
// THE RULING IS NARROW ON PURPOSE, AND THE NARROWNESS IS THE POINT
// ═════════════════════════════════════════════════════════════════════
// The pre-AC-049 design had a broad one: *"a template can be saved
// incomplete at any point; it enters the library flagged Draft and is
// excluded from search unless Include drafts is on"*, with a `Publish`
// action moving Draft to Published. **AC-049 deleted the idea that a
// template can be incomplete** — three required fields, then ports, then
// done, and a template saved with three fields *is a template* — and kept
// the word for one case only:
//
//   > The `Draft` flag survives ONLY for templates saved with zero ports
//   > and no category.
//
// So it no longer means "unfinished". It means "there is genuinely
// nothing here yet", which is a different and much smaller claim.
//
// ═════════════════════════════════════════════════════════════════════
// AND THEREFORE IT IS COMPUTED, NOT STORED
// ═════════════════════════════════════════════════════════════════════
// Ruled with the user on 2026-08-14. A stored `isDraft` would be a
// second source of truth for a fact the body already states, and the two
// can disagree: a user ticks Draft, adds sixteen ports, and the flag is
// now a lie sitting in the file. This is CR-005's shape exactly, where
// BTU/hr is derived from watts and never stored so that no saved number
// can contradict the one it came from.
//
// **A user-togglable Draft would also re-introduce the very thing AC-049
// exists to delete.** The ruling's whole work is removing "incomplete"
// from the product's vocabulary; a checkbox that lets somebody mark a
// finished template as incomplete puts it straight back, and does it in
// the one place a person is most likely to believe it.
//
// Costs nothing on disk: no model field, no codec key, no migration, and
// `kSchemaVersion` does not move.
//
// WHY `category` AND NOT SOME OTHER FIELD. AC-049 names those two, and
// the pair is not arbitrary. A template with no ports might still be a
// real thing (a blank panel, a vent, a shelf: X01 through X03 all ship
// with zero ports), and what tells those apart from an empty stub is
// that somebody said what KIND of thing it is. Ports alone would mark
// three shipped catalog entries as drafts forever.
import 'package:rackpal_core/src/model/template.dart';

/// Whether [body] is a draft: nothing declared about it at all.
///
/// **Derived, never stored** (AC-049; see the file header). True only
/// when the template has zero ports AND no category, which is the one
/// state that says "this is a stub" rather than "this is a small
/// device".
///
/// Note what does NOT make a template a draft: a missing weight, a
/// missing depth, an unfilled power profile, or a blank model string.
/// Those are unknowns, they are honest, and every rollup that meets one
/// counts it (G4). A template made of three fields is finished.
bool isDraftTemplate(TemplateBody body) =>
    body.ports.isEmpty && body.category.trim().isEmpty;
