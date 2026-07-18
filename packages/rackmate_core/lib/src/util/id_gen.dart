// A fresh UUIDv7 for newly-created entities (docs/03-architecture.md §5.1:
// "Commands never allocate IDs at apply time... AddDeviceCommand generates
// its UUIDv7 in its constructor, so redo recreates the entity with the
// identical ID"). Time-ordered, unlike the UUIDv5 `derivePortId` uses
// (port.dart) for deterministic template-bound port ids — a different
// generation strategy for a different purpose, both from the same
// `package:uuid` dependency.
import 'package:rackmate_core/src/units/ids.dart';
import 'package:uuid/uuid.dart' as pkg_uuid;

const _generator = pkg_uuid.Uuid();

/// A fresh, time-ordered UUIDv7. Call this exactly once per entity, at
/// Command construction time — never inside `apply()`, or redo would mint
/// a new id and every command stacked on top of it would dangle.
Uuid newEntityId() => Uuid(_generator.v7());
