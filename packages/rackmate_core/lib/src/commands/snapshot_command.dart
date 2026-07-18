// Deferred for M0 (docs/03-architecture.md §5.5). `SnapshotCommand` is
// the escape hatch for bulk operations that are awkward to hand-invert —
// auto-arrange, catalog import, "renumber all designators", "shrink rack
// and re-flow" — snapshotting only the affected entities' JSON before and
// after, rather than writing fragile per-operation inverse logic:
//
//   final class SnapshotCommand extends Command {
//     SnapshotCommand(this.label, this.touches, this.affects, this.before,
//         this.after);
//     final Map<Uuid, JsonMap?> before, after;   // null value == absent
//     @override void apply(RackDocument doc) => doc.restoreEntities(after);
//     @override void revert(RackDocument doc) => doc.restoreEntities(before);
//   }
//
// None of M0's commands need it — AddDevice/RemoveDevice/MoveDevice/
// AddLink/RemoveLink/RenameEntity/SetRackHeight all have small, precise
// inverses. Building it for real needs two things this milestone does not
// have: `RackDocument.restoreEntities(Map<Uuid, JsonMap?>)`, and a
// per-entity-type encode/decode dispatch table exposed OUTSIDE
// json_codec.dart's current private `_encodeXxx`/`_decodeXxx` functions
// (which are deliberately unexported — see that file's own header
// comment). This file exists, per the directory tree in
// docs/03-architecture.md §2.2, purely as a marker for where that lands;
// it deliberately defines no class so nothing here reads as more built
// than it is (this package's honesty-over-false-completeness principle).
