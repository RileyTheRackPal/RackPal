// `TemplateSnapshot.contentHash`, made real (`#795`, AC-042).
//
// ==================================================================
// WHAT THIS REPLACED, AND WHY IT WAS NOT MERELY UNTIDY
// ==================================================================
// Every `contentHash` in this repository was a LABELLED PLACEHOLDER:
// `unhashed:<id>@1` from the two fork sites and the builder's save,
// `sha256:seed-<id>` from the two seeders, `sha256:demo-<id>` from the
// demo document. `device_builder_actions.dart` explained the choice and
// was right about it: a fake that LOOKS like a sha256 is worse than one
// that plainly is not, because AC-042 makes a mismatch a warning badge
// and a badge that fires on every template teaches people to ignore it.
//
// **The three `sha256:`-prefixed ones were that mistake anyway.** They
// were the right call while nothing hashed and nothing compared, and the
// moment real hashes exist beside them they are three values claiming an
// algorithm they never ran.
//
// ==================================================================
// A HASH WITH NOTHING COMPARING IT IS STILL AN UNREACHABLE FIELD
// ==================================================================
// The census that opened this task found something its own description
// did not claim: `contentHash` had **no verifying reader anywhere**. It
// was written, round-tripped through the codec and never compared, so
// AC-042's warning had no implementation at all rather than a placeholder
// input. Making the hash real and stopping there would have moved the
// failure one step along instead of closing it, which is
// `a modelled field is not a reachable one` in its usual form. So
// [templateHashMatches] ships in the same change as [templateContentHash],
// and `#236`'s import is its first caller.
//
// ==================================================================
// WHICH BYTES, SORTED HOW: DR-100 ALREADY ANSWERED
// ==================================================================
// `device_builder_actions.dart` recorded that question as the reason the
// real hash was deferred. DR-100 §11.99 settled it for the file format
// and the same answer serves here, which is the point of there being one:
// `encodeCanonicalJsonBytes(templateBodyToJson(body))`, the pair that is
// the single description of a `TemplateBody` and the one already under
// CR-117's byte gate. A second byte convention would be a second thing to
// keep true, and the two would disagree on the first field somebody adds.
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/persistence/json_codec.dart';
import 'package:rackpal_core/src/persistence/json_util.dart';

/// The prefix a real content hash carries.
///
/// **NAMED SO THE PREFIX CANNOT BE TYPED BY ACCIDENT.** Three placeholders
/// used to spell it by hand, and the one that survives this change
/// ([kNoTemplateContentHash]) deliberately does not.
const String kSha256Prefix = 'sha256:';

/// What a `TemplateRef` carries when there is no template to hash.
///
/// **THE ONE SURVIVING SENTINEL, AND IT IS RE-SPELLED** (`#795`). A
/// Structure device names `kStructureTemplateRef`, which resolves to
/// nothing on purpose: there is no body, so there is nothing to hash and
/// no hash to compare. It used to read `sha256:structure-no-template`,
/// which was harmless while no value in the tree was a real sha256 and is
/// a lie the moment one is. It now says what it is.
const String kNoTemplateContentHash = 'no-template:structure';

/// The content hash of [body]: `sha256:` and 64 lowercase hex digits.
///
/// **OVER THE CANONICAL BYTES, WHICH IS DR-100's ANSWER AND NOT A SECOND
/// ONE.** `templateBodyToJson` is the single description of a
/// `TemplateBody` and `encodeCanonicalJsonBytes` is the single sorting
/// convention; a field either pair fails to carry is a field the FILE
/// fails to carry, and CR-117's gate fails first.
///
/// **DETERMINISTIC ACROSS MACHINES AND RUNS**, because both halves already
/// are: the key sort is total and the encoder writes no timestamp, no
/// locale-dependent number and no map iteration order. Two people who
/// author byte-identical bodies get the same hash, which is what makes a
/// mismatch mean "this was edited" rather than "this came from elsewhere".
String templateContentHash(TemplateBody body) {
  final bytes = Uint8List.fromList(
    encodeCanonicalJsonBytes(templateBodyToJson(body)),
  );
  return '$kSha256Prefix${sha256.convert(bytes)}';
}

/// Whether [claimed] is the hash [body] actually has.
///
/// **A NON-HASH ANSWERS `null`, NOT `false`**, and the tri-state is the
/// ruling G4 has been making all along. `false` asserts "this was edited";
/// `null` says "there is nothing here to check against". A Structure
/// device's [kNoTemplateContentHash], a snapshot written by a build older
/// than `#795` carrying `unhashed:tpl.foo@1`, and a hand-typed string all
/// land in the third state, and **none of them is evidence of tampering.**
///
/// Collapsing them into `false` would put a "this file was modified"
/// badge on every device in every project saved before this change, which
/// is AC-042's own reasoning arriving from the other side: refusing to
/// trust a document because a field was not computed yet is a data-loss
/// event dressed as a safety feature, one notch quieter.
bool? templateHashMatches(TemplateBody body, String claimed) {
  if (!claimed.startsWith(kSha256Prefix)) return null;
  final digest = claimed.substring(kSha256Prefix.length);
  // A `sha256:` prefix over something that is not 64 hex digits is not a
  // hash either. `sha256:seed-catalog_audio.a01` used to be exactly that
  // shape, and treating it as a comparable value would report a mismatch
  // on every seeded template in every project written before this.
  if (digest.length != 64 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
    return null;
  }
  return templateContentHash(body) == claimed;
}
