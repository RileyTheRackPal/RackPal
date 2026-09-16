// DR-171 §11.170.3: the two `PowerProfile` keys every format drops on read.
//
// ═════════════════════════════════════════════════════════════════════════
// ONE STEP, THREE FORMATS
// ═════════════════════════════════════════════════════════════════════════
// `.rppj` v5 to v6, and `.rpdx` and `.rpda` v2 to v3, all carry the same
// template body as `templateBodyToJson` writes it, so they strip the same
// keys and re-hash by the same rule. Three copies would be three chances to
// disagree about whether an older file was edited.
//
// ═════════════════════════════════════════════════════════════════════════
// THE HASH MOVES ONLY WHERE IT ATTESTED THE BYTES IT WAS TAKEN OVER
// ═════════════════════════════════════════════════════════════════════════
// A stored `contentHash` is tamper evidence over the body's canonical bytes,
// and stripping a key changes those bytes. DR-134's `.rpdx` step recomputed
// unconditionally and stated the cost: a recomputed hash cannot attest to
// what the exporter wrote. This step checks first. A hash that matched the
// body as stored is re-taken over the body as it will be stored; one that
// did not match, or is not a hash at all, is carried unchanged, so a body
// edited outside the product still reports as edited after its file is
// migrated.
//
// ═════════════════════════════════════════════════════════════════════════
// OVER THE RAW MAP, NOT A DECODED BODY, BECAUSE THIS IS A CHAIN STEP
// ═════════════════════════════════════════════════════════════════════════
// docs/03 §9.2 keeps migration on raw maps because migrating typed objects
// would keep historical class shapes alive forever. A step that decoded a
// v5 body with this build's decoder would be right only until the next
// format change, when a v6-shaped map meets a v7 decoder in the middle of
// the chain. The canonical bytes of the stripped map are exactly what
// `templateContentHash` takes today, which `migration_corpus_test` asserts
// on a real file, and they stay the hash of THIS step's output whatever a
// later step does.
import 'package:crypto/crypto.dart';
import 'package:rackpal_core/src/library/template_hash.dart' show kSha256Prefix;
import 'package:rackpal_core/src/persistence/json_util.dart';

/// The keys DR-171 retired, as a pre-v6 body's `power` map spelled them.
const List<String> kRetiredOutletKeys = ['outletsConsumed', 'outletsProvided'];

/// `sha256:` over [body]'s canonical bytes, [body] being a raw JSON map.
String canonicalBodyHash(Map<Object?, Object?> body) =>
    '$kSha256Prefix${sha256.convert(encodeCanonicalJsonBytes(body))}';

/// Strips [kRetiredOutletKeys] from [body]'s `power` map IN PLACE, and
/// returns the `contentHash` to store beside it afterwards.
///
/// [storedHash] comes back unchanged when nothing was stripped, and when
/// it did not attest [body] as it was stored. See the file header.
Object? retireOutletKeys(Map<Object?, Object?> body, Object? storedHash) {
  final power = body['power'];
  if (power is! Map) return storedHash;
  if (!kRetiredOutletKeys.any(power.containsKey)) return storedHash;
  final attested =
      storedHash is String && storedHash == canonicalBodyHash(body);
  for (final key in kRetiredOutletKeys) {
    power.remove(key);
  }
  return attested ? canonicalBodyHash(body) : storedHash;
}
