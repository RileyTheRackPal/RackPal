// docs/03-architecture.md §4.3 (epochs) and §5.1 (the Command interface),
// quoted in full there and transcribed here. D2: the document is one
// mutable aggregate, mutated only through `Command`s; change detection is
// by these epoch counters, not equality.
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/simple_notifier.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Bit flags a Command declares. The controller bumps matching epochs on
/// commit. An `extension type` over `int` — zero runtime overhead, same
/// convention as the `Uuid`/`Len`/etc. wrappers in `units/`.
extension type const EpochMask(int bits) {
  static const none = EpochMask(0);

  /// placement add/remove/move/rotate/face.
  static const structure = EpochMask(1 << 0);

  /// Link/Service/Conductor/Net add/remove/retype.
  static const wires = EpochMask(1 << 1);

  /// heightU, rack add/remove, rails, depth.
  static const rack = EpochMask(1 << 2);

  /// designators, names, notes, ProjectInfo.
  static const meta = EpochMask(1 << 3);

  /// per-family colour overrides, ProjectSettings.
  static const style = EpochMask(1 << 4);

  /// SheetItem positions, pinning, collapse.
  static const sheet = EpochMask(1 << 5);

  EpochMask operator |(EpochMask o) => EpochMask(bits | o.bits);

  bool has(EpochMask o) => bits & o.bits != 0;
}

/// The document's epoch counters, plus the `sequence` cursor. Each field
/// is a [SimpleNotifier] so `rackmate_ui` can subscribe to exactly the
/// epochs one widget cares about instead of rebuilding on every commit.
class DocEpochs {
  final sequence = SimpleNotifier<int>(0);
  final structure = SimpleNotifier<int>(0);
  final wires = SimpleNotifier<int>(0);
  final rack = SimpleNotifier<int>(0);
  final meta = SimpleNotifier<int>(0);
  final style = SimpleNotifier<int>(0);
  final sheet = SimpleNotifier<int>(0);

  /// Bumps every epoch [m] touches, plus [sequence] unconditionally —
  /// every commit, undo AND redo advances it (CR-094). [doc] is an
  /// addition beyond docs/03-architecture.md §4.3's elided sketch: CR-094
  /// requires this same call to ALSO advance the *persisted*
  /// `RackDocument.sequence` counter, and every commit/undo/redo already
  /// funnels through this one method, so this is the one place that can
  /// keep the two in lockstep without a second call site to forget.
  /// [sequence] itself becomes the observable mirror of `doc.sequence` —
  /// what `rackmate_ui` actually subscribes to, since a plain `int` field
  /// on `RackDocument` is not itself a `Listenable`.
  void bump(EpochMask m, RackDocument doc) {
    doc.sequence++;
    sequence.value = doc.sequence;
    if (m.has(EpochMask.structure)) structure.value++;
    if (m.has(EpochMask.wires)) wires.value++;
    if (m.has(EpochMask.rack)) rack.value++;
    if (m.has(EpochMask.meta)) meta.value++;
    if (m.has(EpochMask.style)) style.value++;
    if (m.has(EpochMask.sheet)) sheet.value++;
  }
}

/// One undoable change to a [RackDocument]. Transcribed from
/// docs/03-architecture.md §5.1 exactly, with `RackFace` read as `Face`
/// per this package's naming-drift note (placement.dart).
///
/// Three properties MUST hold, verified by `command_roundtrip_test.dart`:
///  * `apply`/`revert`, not `undo`/`redo` — redo is `apply()` again.
///  * A command is idempotent under alternation: `apply; revert; apply`
///    lands in the identical state as a single `apply`.
///  * Commands store before-values, not whole entities, and never
///    allocate ids at `apply` time — ids are minted in the constructor
///    (see `newEntityId()`, util/id_gen.dart), so redo recreates the
///    identical entity and anything stacked on top of it still resolves.
abstract base class Command {
  const Command();

  LabelKey get label;
  EpochMask get touches;
  Iterable<Uuid> get affects;
  Object? get mergeKey => null;

  void apply(RackDocument doc);
  void revert(RackDocument doc);

  Command? mergeWith(Command next) => null;
}
