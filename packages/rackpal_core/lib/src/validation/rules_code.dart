// Tier-3 code rules: `CODE-001` and `CODE-002` (`#290`, `#291`).
//
// ═════════════════════════════════════════════════════════════════════
// THESE TWO ASK THE USER TO VERIFY. THEY DO NOT ASSERT A VIOLATION
// ═════════════════════════════════════════════════════════════════════
// DR-079 demoted both from error to warning and gave the reason in each
// case, and the reason is the same shape: **this product cannot see the
// thing the code article turns on.**
//
//  * `CODE-001` cites NEC 725.136, and §11.78.3 records that the article
//    *"has permitted arrangements this product does not model"* —
//    barriers, listed assemblies, separations. So a Class 2 conductor in
//    a line-voltage pathway is a thing to CHECK, not a thing this
//    product knows is wrong.
//  * `CODE-002` cites NEC 800.154 and names 300.22(C)'s metal-raceway
//    exception, which this product cannot see because it models no
//    raceway.
//
// The sentences therefore say "verify" and name the article, and neither
// says "violates". A DRC that overstated its reach on a code question
// would be worse than one that stayed silent, because somebody would
// believe it.
//
// ═════════════════════════════════════════════════════════════════════
// `lszh` IS NOT A LISTING, AND ACCEPTING IT WAS A FALSE PASS
// ═════════════════════════════════════════════════════════════════════
// DR-079 §11.78.1 removed it from `CODE-002`'s predicate: LSZH is a
// jacket COMPOUND, an IEC and European concern about smoke and halogen,
// and a plenum listing rests on a US flame-and-smoke test (UL 910 /
// NFPA 262). An LSZH cable may carry no plenum listing at all. So this
// file asks `isPlenumRated`, which judges a listing inside its own
// article, and never looks at a compound.

import 'package:rackpal_core/src/model/enums.dart' show Severity;
import 'package:rackpal_core/src/model/jacket_substitution.dart';
import 'package:rackpal_core/src/model/pathway.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/validation/finding.dart';

/// `CODE-001` — a Class 2/3 conductor shares a pathway with line voltage.
List<Finding> ruleCode001(RackDocument doc) {
  final out = <Finding>[];
  for (final pathway in doc.pathways.values) {
    if (!pathway.containsLineVoltage) continue;
    for (final link in doc.links.values) {
      if (link.pathwayId != pathway.id) continue;
      // THE CABLE'S OWN LISTING NAMES ITS ARTICLE, which is what makes
      // this answerable at all: a `cl2`-family listing IS the Class 2/3
      // declaration, so there is no separate flag to invent.
      //
      // NO LISTING IS UNKNOWN AND SKIPS (G4). A cable nobody has
      // specified is not a Class 2 cable in a line-voltage conduit; it
      // is a cable nobody has specified, and reporting it would put a
      // code question on a row whose data is simply absent.
      final listing = link.jacket;
      if (listing == null) continue;
      if (classifyJacketListing(listing).article !=
          JacketArticle.classTwoThree) {
        continue;
      }
      out.add(
        Finding(
          ruleId: 'CODE-001',
          severity: Severity.warning,
          message:
              '${link.designator} is a Class 2/3 cable in ${pathway.name}, '
              'which carries line voltage. Verify against NEC 725.136: the '
              'article permits arrangements this product does not model, '
              'such as barriers and listed assemblies, so this is a check '
              'rather than a violation.',
          targets: [link.id, pathway.id],
          primaryEntityId: link.id,
        ),
      );
    }
  }
  return out;
}

/// `CODE-002` — a cable in a plenum space is not plenum-listed.
List<Finding> ruleCode002(RackDocument doc) {
  final out = <Finding>[];
  for (final pathway in doc.pathways.values) {
    if (pathway.kind != PathwayKind.plenumSpace) continue;
    for (final link in doc.links.values) {
      if (link.pathwayId != pathway.id) continue;
      // UNKNOWN AND SKIPS, which docs/02 §5.3 states for this rule
      // explicitly: *"A listing from another article, or none at all, is
      // unknown and skips (G4)."* A cable with no listing recorded is
      // not a failing cable; it is an unspecified one.
      final listing = link.jacket;
      if (listing == null) continue;
      if (isPlenumRated(listing)) continue;
      out.add(
        Finding(
          ruleId: 'CODE-002',
          severity: Severity.warning,
          message:
              '${link.designator} runs through ${pathway.name}, a plenum '
              'space, and its ${listing.name.toUpperCase()} listing is not '
              'plenum-rated. Verify against NEC 800.154; 300.22(C) permits '
              'a metal raceway, which this product does not model.',
          targets: [link.id, pathway.id],
          primaryEntityId: link.id,
        ),
      );
    }
  }
  return out;
}
