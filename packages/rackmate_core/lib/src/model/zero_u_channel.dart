// M0 MINIMAL SHAPE: docs/02-data-model.md §4.2 lists `ZeroUChannel` only as
// "sub-objects, string-keyed, no EntityMeta" without a field list. The
// shape below is transcribed from the annotated JSON example in §6.2
// (`{ "endU": 12, "id": "ch-rear-l", "side": "rearLeft", "startU": 1 }`),
// plus a `name` field per this package's governing instructions.

/// Which vertical rail channel of the rack this is.
///
/// M0 MINIMAL SHAPE: only the single example value `"rearLeft"` appears
/// in the corpus (docs/02-data-model.md §6.2); the four-corner set below
/// is the obvious minimal completion for a rack's 0U vertical channels.
enum ZeroUChannelSide { frontLeft, frontRight, rearLeft, rearRight }

/// A 0U vertical cable-management channel on a `Rack`. A sub-object with
/// a plain `String` id local to the rack — not a document-level entity,
/// so it has no `Uuid` identity and no `EntityMeta`.
final class ZeroUChannel {
  ZeroUChannel({
    required this.id,
    required this.side,
    required this.startU,
    required this.endU,
    this.name = '',
  });

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  String id;
  String name;
  ZeroUChannelSide side;
  int startU;
  int endU;
}
