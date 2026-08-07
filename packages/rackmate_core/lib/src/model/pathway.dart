// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

/// conduit|jhook|tray|plenumSpace|riser|directBury|exterior.
enum PathwayKind {
  conduit,
  jhook,
  tray,
  plenumSpace,
  riser,
  directBury,
  exterior,
}

/// A conduit / j-hook / tray / trunk a `Link` may be routed through
/// (CR-016, AC-027). First-class rather than an opaque `conduitId`
/// string, because `CODE-001`/`CODE-002` need `containsLineVoltage` and
/// `kind` to protect the user from an actual code citation.
final class Pathway {
  Pathway({
    required this.id,
    required String name,
    required this.order,
    required this.meta,
    this.kind = PathwayKind.conduit,
    this.containsLineVoltage = false,
    Uuid? fromLocationId,
    Uuid? toLocationId,
    this.nominalLength,
    this.pathwayMedia,
    String? notes,
  }) : _name = name,
       _notes = notes,
       _fromLocationId = fromLocationId,
       _toLocationId = toLocationId;

  final Uuid id;

  /// "B03".
  String _name;
  String get name => _name;
  @internal
  set name(String v) => _name = v;

  String? _notes;
  String? get notes => _notes;
  @internal
  set notes(String? v) => _notes = v;

  /// THE TWO FIELDS A GREP FOR `locationId` DOES NOT FIND, which is why
  /// DR-021 enumerates the nine carriers rather than describing them.
  /// `RemoveLocationCommand` clears both when the room at either end of a
  /// pathway is deleted (§11.20.2), and that wiring is the AC-013
  /// retrofit.
  Uuid? _fromLocationId;
  Uuid? get fromLocationId => _fromLocationId;
  @internal
  set fromLocationId(Uuid? v) => _fromLocationId = v;

  Uuid? _toLocationId;
  Uuid? get toLocationId => _toLocationId;
  @internal
  set toLocationId(Uuid? v) => _toLocationId = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  PathwayKind kind;

  /// `CODE-001` depends on it.
  bool containsLineVoltage;
  Len? nominalLength;

  /// `isPathwayOnly` media (CR-109).
  MediaTypeId? pathwayMedia;
  FracIndex order;
  EntityMeta meta;
}
