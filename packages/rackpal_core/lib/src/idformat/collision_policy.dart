// Project-wide designator collision policy (CR-045), STORED AND NOT
// APPLIED since DR-201.
//
// This header used to say one policy governed every call site that
// allocates a designator. None ever read it: every allocator picks the
// lowest unused designator, so a minted one cannot collide, and a typed
// duplicate is allowed and flagged by validation (a duplicate is never a
// hard error that blocks an export; CR-022/G3). `#945` found the resolver
// uncalled, and DR-201 took the setting out of Project Settings. The enum
// stays for the stored field.

/// How a freshly-computed designator that already exists gets resolved.
///
/// STORED, NOT APPLIED (DR-201). Allocation picks the lowest unused
/// designator, so a computed one never collides, and nothing typed is
/// checked against this; the resolver that read it had no caller and was
/// deleted with the Project Settings row. The enum stays because
/// `ProjectSettings.collisionPolicy` is typed by it and is kept on the
/// wire, so existing files re-save byte for byte (CR-117).
enum CollisionPolicy {
  /// Append A, B, C, ... Z, AA, AB, ... to the candidate until free.
  suffixLetter,

  /// Append 2, 3, 4, ... to the candidate until free.
  suffixNumber,

  /// Reject the collision outright.
  error,
}
