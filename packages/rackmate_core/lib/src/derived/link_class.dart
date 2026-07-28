// AC-026's auto-classification, as narrowed by DR-008 §11.8.1.
//
// ═══════════════════════════════════════════════════════════════════════
// THE RULE, AND THE TWO LIMBS THAT ARE NOT IN IT
// ═══════════════════════════════════════════════════════════════════════
// A jumper is a `Link` WITH BOTH ENDS IN THE SAME RACK. Length does not
// enter into it. Neither does whether the cable was factory-assembled.
//
// AC-026's supporting prose gestured at a short run of factory-assembly
// media, and both of those extra limbs were struck by DR-008 for reasons
// worth keeping next to the code:
//
//   * THE CORPUS'S OWN REFERENCE JUMPER FAILS THE FACTORY LIMB. docs/02
//     shows W002 as `"linkClass": "jumper"` with `"media": "media.cat6"` —
//     bulk box cable. Either the reference violates AC-026, or the limb was
//     never a conjunct.
//   * NOTHING COULD EVALUATE EITHER LIMB. `MediaTypeDef` has no
//     factory-assembly flag in the code or in canon §6.5's own field list;
//     and a freshly-drawn link has all three of AC-024's lengths null, so a
//     length test is unevaluable at exactly the moment classification
//     happens.
//   * SAME-RACK IS THE FACT THE SCHEDULE WANTS. A jumper is off the Pull
//     Sheet because nobody pulls it through a wall — a statement about
//     where its ends are, not how long it is. A 3 m service loop inside one
//     rack is still not a pull; a 1 m run between two racks still is.
//
// ═══════════════════════════════════════════════════════════════════════
// UNDETERMINED IS AN ANSWER, AND IT IS NOT `fieldCable`
// ═══════════════════════════════════════════════════════════════════════
// If either end fails to resolve to a rack, this returns `null` — NOT a
// guess. That is G4 applied to a classifier: an unknown is counted and
// shown, never defaulted into a real category.
//
// The distinction has teeth on the Pull Sheet. Defaulting an undetermined
// link to `fieldCable` puts it on a sheet an installer works from, asserting
// a pull nobody has established; defaulting it to `jumper` hides it from
// that sheet entirely. Both are worse than a count of links whose class
// could not be determined, which is what `null` lets a caller render.
//
// A `PlaceEndpoint` — a home run to "the projector shelf, beam 3" — always
// resolves to `null` rack, so a link with one field end is never a jumper
// and never undetermined-for-lack-of-data: it is a `fieldCable`, which is
// exactly right. See [linkClassOf] for how that case is separated from a
// genuine failure to resolve.

import 'package:rackmate_core/src/derived/endpoint_resolution.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// What the classifier believes [link] is, or `null` when it cannot tell.
///
/// Advisory ONLY. Per DR-008 §11.8.2 a user-set class outranks this and is
/// never overwritten by it; callers wanting the effective value must consult
/// the stored `Link.linkClass` first. This function deliberately knows
/// nothing about the override — keeping the classifier ignorant of it is
/// what makes "the classifier disagrees with the user" a computable
/// statement rather than a lost one.
///
/// Returns `null` when either end lands on a port this document cannot
/// resolve to a rack — a port that is not materialised, a device that is
/// missing, or a shelf chain that never reaches a rack.
LinkClass? linkClassOf(RackDocument doc, Link link) {
  final conductors = link.conductors;
  if (conductors.isEmpty) return null;

  // A Link's ends ARE its conductors' ends. CR-014 fixes each conductor at
  // exactly two, and every conductor of one cable shares the same pair of
  // physical ends, so the first conductor speaks for the link.
  final first = conductors.first;
  final a = _resolve(doc, first.from);
  final b = _resolve(doc, first.to);
  if (a == null || b == null) return null; // unresolved — see [_End]

  // BOTH ENDS IN ONE RACK, AND THERE IS A RACK. The second half is not
  // redundant: two field ends both carry a null rack, and letting those
  // compare equal would classify a wall-to-wall home run as a jumper and
  // drop it off the Pull Sheet. That is the bug this shape exists to make
  // unwritable.
  if (a.rackId != null && a.rackId == b.rackId) return LinkClass.jumper;

  return LinkClass.fieldCable;
}

/// One resolved end.
///
/// The nesting is the point, and it is why this is a type rather than a
/// bare `Uuid?`. `_resolve` returns `null` for **failed to resolve**;
/// `_End.rackId` is `null` for **resolved, and it is not in a rack**. A
/// `PlaceEndpoint` running to "the projector shelf, beam 3" is the second —
/// a fact about the job. A `PortEndpoint` naming a port this document does
/// not contain is the first — something is wrong, and answering
/// `fieldCable` for it would invent a pull.
class _End {
  const _End(this.rackId);

  /// Null means "resolved, and lands in no rack".
  final Uuid? rackId;
}

_End? _resolve(RackDocument doc, Endpoint e) {
  if (e is PortEndpoint) {
    // A materialised port always belongs to a device, so a port endpoint
    // that reaches no rack is UNRESOLVED rather than rack-less — the device
    // is missing, off-rack, staged, or on a shelf chain that never lands.
    // The classifier has nothing useful to say about any of those.
    final rack = rackOfEndpoint(doc, e);
    return rack == null ? null : _End(rack);
  }
  // PlaceEndpoint / OpenEndpoint: genuinely no rack, and that is an answer.
  return const _End(null);
}
