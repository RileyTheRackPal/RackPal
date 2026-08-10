// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

/// conduit|jhook|tray|plenumSpace|riser|directBury|exterior|attic|
/// crawlspace.
///
/// NINE VALUES, and the last two are DR-031 (canon §11.30) discharging
/// DR-020 §11.19.4, which left them open and dated the question *"Owed at
/// M3, when `Pathway` gets its editor"*.
///
/// THE OBJECTION WAS THAT BOTH ARE SPACES AND `Location` ALREADY MODELS
/// SPACES. It does, and that is a different fact: `Location` models where
/// a room IS, this models what a cable PASSES THROUGH. A run from the
/// rack to a bedroom crosses an attic that is nobody's room and belongs
/// to no room's subtree, and [Pathway.fromLocationId] /
/// [Pathway.toLocationId] are ENDPOINTS, so a space in the middle has no
/// field to live in.
///
/// WHAT A VALUE CARRIES IS A CONSEQUENCE, which is why these two sit
/// beside `plenumSpace` rather than in a taxonomy: `attic` obliges
/// temperature derating and rodent exposure, `crawlspace` obliges
/// moisture and vermin, as `plenumSpace` obliges a jacket rating
/// (NEC 800.154, `CODE-002`).
///
/// **NEITHER IS AN ERROR AND NEITHER ADDS A RULE.** The v1 catalogue
/// stays at 28. G2 requires the document be able to represent the world
/// as found, and in a retrofit an attic run is the ordinary case.
///
/// SERIALISED BY NAME, which is why DR-020 deferred the question to the
/// day the editor lands rather than settling it earlier or later: the
/// enum is complete before any gesture can write it, so no document
/// records `conduit` for a run its author would have called `attic`.
enum PathwayKind {
  conduit,
  jhook,
  tray,
  plenumSpace,
  riser,
  directBury,
  exterior,
  attic,
  crawlspace,
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
