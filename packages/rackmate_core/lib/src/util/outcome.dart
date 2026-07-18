// A result type for operations whose failures are expected, recoverable
// outcomes rather than programmer errors — chiefly the persistence layer's
// migration/decode path (docs/03-architecture.md §9.2, CR-093): "a file
// from a newer build" is a value the caller branches on, not a thrown
// exception. Modelled as a sealed class so callers pattern-match
// exhaustively with a `switch` instead of `is`-checking.

/// Either a success ([Ok]) or a failure ([Err]); never thrown, always
/// returned. Pattern-match with a `switch`:
///
/// ```dart
/// final outcome = migrateToCurrent(raw);
/// switch (outcome) {
///   case Ok(:final value, :final openReadOnly):
///     ...
///   case Err(:final error):
///     ...
/// }
/// ```
sealed class Outcome<T> {
  const Outcome();
}

/// Success, carrying [value].
///
/// [openReadOnly] is true for the one success-but-not-quite case the
/// migration chain defines (docs/03-architecture.md §9.2): a file whose
/// `schemaVersion` is newer than this build's `kSchemaVersion` but whose
/// `minReaderVersion` this build still satisfies. It opens, its unknown
/// fields preserved, but saving back over it would be lossy, so callers
/// are expected to treat this as "Save As only".
final class Ok<T> extends Outcome<T> {
  const Ok(this.value, {this.openReadOnly = false});

  final T value;
  final bool openReadOnly;
}

/// Failure. [error] is deliberately a bare `Object` rather than a
/// project-wide error hierarchy (out of scope for this package) —
/// callers that care about a specific failure reason (e.g.
/// `NewerSchemaError` from migrations.dart) test for it with
/// `error is NewerSchemaError`.
final class Err<T> extends Outcome<T> {
  const Err(this.error);

  final Object error;
}
