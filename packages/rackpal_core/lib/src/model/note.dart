import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/pt.dart';

/// A free-standing project or device-attached annotation.
///
/// M0 MINIMAL SHAPE: docs/02-data-model.md lists `Note` only in the
/// entity-relationship overview (§2) and the RackDocument field table;
/// no field list is given in §4 itself. The shape below (id, optional
/// target, text, optional schematic position) is the minimal reading per
/// this package's governing instructions; `meta` is added for
/// consistency with every other entity in `RackDocument`'s top-level
/// maps.
final class Note {
  Note({
    required this.id,
    required this.text,
    required this.meta,
    this.targetId,
    this.position,
  });

  final Uuid id;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// The entity this note is attached to, if any; a project-level note
  /// when null.
  Uuid? targetId;
  String text;
  Pt? position;
  EntityMeta meta;
}
