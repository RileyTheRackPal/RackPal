/// A deleted entity's grave marker (CR-095, G5). Ships in v1 even though no
/// history UI exists yet: without it a later sync cannot distinguish "the
/// peer deleted this" from "the peer never had it", and delete commands
/// would not be trivially invertible for undo.
final class Tombstone {
  Tombstone({
    required this.deletedAt,
    required this.entityType,
    required this.by,
  });

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart. A Tombstone is conceptually
  // write-once, but no M0 command currently constructs one, so the
  // conversion is deferred rather than guessed at.
  DateTime deletedAt;
  String entityType;
  String by;
}
