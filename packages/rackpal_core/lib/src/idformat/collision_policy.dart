// Project-wide designator collision policy (CR-045). One policy governs
// every call site that allocates a designator: device, port, link, drop
// field label, drop rack label. Per canonical-decisions.md, a duplicate is
// never a hard error that blocks a whole export (that reading of
// design-pdf-export.md §3.4 does not survive CR-022/G3) — CollisionPolicy
// only controls what happens at the moment a *new* designator is minted.

/// How a freshly-computed designator that already exists gets resolved.
enum CollisionPolicy {
  /// Append A, B, C, ... Z, AA, AB, ... to the candidate until free.
  suffixLetter,

  /// Append 2, 3, 4, ... to the candidate until free.
  suffixNumber,

  /// Reject the collision outright — see [DesignatorCollisionException].
  error,
}

/// Thrown by [resolveDesignatorCollision] under [CollisionPolicy.error].
///
// TODO(rackpal): this package has no `Outcome`/result type yet (M0 scope
// note); once one exists, consider returning a failed Outcome from
// resolveDesignatorCollision instead of throwing.
final class DesignatorCollisionException implements Exception {
  const DesignatorCollisionException(this.candidate);

  /// The designator that was already in use.
  final String candidate;

  @override
  String toString() =>
      'DesignatorCollisionException: designator "$candidate" is already '
      'in use and CollisionPolicy.error forbids resolving it '
      'automatically.';
}

/// Resolves [candidate] against the already-used set [used], per [policy].
///
/// Returns [candidate] unchanged when it is not already in [used]. Never
/// mutates [used] — the caller is responsible for recording whatever
/// designator is ultimately chosen.
String resolveDesignatorCollision(
  String candidate,
  Set<String> used,
  CollisionPolicy policy,
) {
  if (!used.contains(candidate)) {
    return candidate;
  }
  switch (policy) {
    case CollisionPolicy.error:
      throw DesignatorCollisionException(candidate);
    case CollisionPolicy.suffixLetter:
      var i = 0;
      while (true) {
        final attempt = '$candidate${_letterSuffix(i)}';
        if (!used.contains(attempt)) {
          return attempt;
        }
        i++;
      }
    case CollisionPolicy.suffixNumber:
      var n = 2;
      while (true) {
        final attempt = '$candidate$n';
        if (!used.contains(attempt)) {
          return attempt;
        }
        n++;
      }
  }
}

/// Bijective base-26 letter suffix: 0 -> "A", 1 -> "B", ..., 25 -> "Z",
/// 26 -> "AA", 27 -> "AB", ...
String _letterSuffix(int i) {
  var n = i;
  final letters = <String>[];
  do {
    letters.add(String.fromCharCode(65 + n % 26));
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return letters.reversed.join();
}
