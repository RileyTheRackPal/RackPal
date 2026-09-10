// rackpal_core/src/persistence/plan_hash.dart — whether an underlay's
// stored bytes are the ones its `contentHash` was taken over (AC-042,
// DR-154 §11.153.5, `PLAN-I/1`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SAME SHAPE AS `library/template_hash.dart`, DELIBERATELY
// ═══════════════════════════════════════════════════════════════════════
// That file exists because a census found `TemplateSnapshot.contentHash`
// *"had no verifying reader anywhere"*: written, round-tripped through the
// codec and never compared, so AC-042's warning had no implementation at
// all rather than a placeholder input. `PlanUnderlay.contentHash` was in
// exactly that state until `PLAN-I`.
//
// The algorithm has ONE description and it is here, in core, so the
// importer that writes a hash and the rule that checks one cannot drift.
// The BYTES are not here, because `RackDocument` holds none: an underlay
// names a container member and the members ride on the session (DR-019,
// `PLAN-B`). So the caller supplies them, which is also what keeps a
// sha256 over several megabytes off the widget build path.
//
// ═══════════════════════════════════════════════════════════════════════
// A NON-HASH ANSWERS `null`, NOT `false`
// ═══════════════════════════════════════════════════════════════════════
// `templateHashMatches` settled this for the same question about the same
// kind of field, and its reasoning transfers whole: `false` asserts *"this
// was edited"* and `null` says *"there is nothing here to check against"*.
// Collapsing them would put a tampering badge on a file nobody touched,
// which is AC-042's own argument arriving from the other side.
//
// **THE POPULATIONS DIFFER AND THE ANSWER DOES NOT.** Every underlay this
// product has ever written carries a real `sha256:` hash, because
// `importFloorplanBytes` computes one on every path, so the null case here
// is a hand-edited file rather than an older build's placeholder. That
// makes null RARER than it is for a template and no less honest: a value
// this product cannot parse is a value it cannot testify about.
import 'package:crypto/crypto.dart';
import 'package:rackpal_core/src/library/template_hash.dart' show kSha256Prefix;
import 'package:rackpal_core/src/model/plan.dart';

/// The `sha256:` hash of an underlay member's [bytes].
///
/// Over the STORED bytes, which is what `importFloorplanBytes` hashes: a
/// flattened PNG when the source had alpha, and the architect's own file
/// byte for byte when it did not.
String planUnderlayHash(List<int> bytes) =>
    '$kSha256Prefix${sha256.convert(bytes)}';

/// Whether [bytes] are the bytes [underlay]'s `contentHash` was taken
/// over, or null when that hash is not one this product can check.
///
/// `false` is the only answer `PLN-004` fires on. See the file header for
/// why the third state is not folded into it.
bool? planUnderlayHashMatches(PlanUnderlay underlay, List<int> bytes) {
  final claimed = underlay.contentHash;
  if (!claimed.startsWith(kSha256Prefix)) return null;
  final digest = claimed.substring(kSha256Prefix.length);
  // A `sha256:` prefix over something that is not 64 hex digits is not a
  // hash either, which `template_hash.dart` learned from a seeded
  // catalogue writing `sha256:seed-catalog_audio.a01`.
  if (digest.length != 64 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
    return null;
  }
  return planUnderlayHash(bytes) == claimed;
}
