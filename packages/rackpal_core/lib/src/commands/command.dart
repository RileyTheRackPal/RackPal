// docs/03-architecture.md §4.3 (epochs) and §5.1 (the Command interface),
// quoted in full there and transcribed here. D2: the document is one
// mutable aggregate, mutated only through `Command`s; change detection is
// by these epoch counters, not equality.
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/simple_notifier.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

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

  /// Reserved for a change to how the document LOOKS that is not about
  /// any one entity. docs/03 §4.3 names per-family colour overrides and
  /// ProjectSettings, and **no command declares it today** (`#933`):
  /// `SetFamilyColorOverrideCommand` declares `meta`, which on the
  /// Schematic rebuilds the symbols and keeps the layout, and that is the
  /// cheaper right answer for a colour. The Schematic still listens to
  /// this epoch and reads it as a re-layout, so a command that declares it
  /// will move every symbol and, through DR-187's freeze, write their
  /// positions into the file. Declare it only for an edit that should.
  static const style = EpochMask(1 << 4);

  /// SheetItem positions, pinning, collapse.
  static const sheet = EpochMask(1 << 5);

  EpochMask operator |(EpochMask o) => EpochMask(bits | o.bits);

  bool has(EpochMask o) => bits & o.bits != 0;
}

/// The document's epoch counters, plus the `sequence` cursor. Each field
/// is a [SimpleNotifier] so `rackpal_ui` can subscribe to exactly the
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
  /// what `rackpal_ui` actually subscribes to, since a plain `int` field
  /// on `RackDocument` is not itself a `Listenable`.
  ///
  /// [m] became NULLABLE at M4-A, and `null` is not `EpochMask.none`:
  /// `none` asserts a command touched no epoch, `null` says the command's
  /// aggregate has no epoch model to touch at all — a
  /// `Command<TemplateBody>` on the Device Builder's stack (CR-106). G4's
  /// shape, applied to a mask: a measured zero and an inapplicable
  /// question are different answers and must not share a value.
  /// `DocumentController` is the only caller and never passes null today;
  /// the parameter is nullable because `Transaction<A>.touches` is, and
  /// saying so in the type beats making every call site guess a mask.
  /// The [sequence] bump happens either way, because CR-094 makes it a
  /// property of *a commit having happened*, not of what it touched.
  void bump(EpochMask? m, RackDocument doc) {
    doc.sequence++;
    sequence.value = doc.sequence;
    if (m == null) return;
    if (m.has(EpochMask.structure)) structure.value++;
    if (m.has(EpochMask.wires)) wires.value++;
    if (m.has(EpochMask.rack)) rack.value++;
    if (m.has(EpochMask.meta)) meta.value++;
    if (m.has(EpochMask.style)) style.value++;
    if (m.has(EpochMask.sheet)) sheet.value++;
  }
}

/// One undoable change to an aggregate of type [A]. Transcribed from
/// docs/03-architecture.md §5.1, with `RackFace` read as `Face` per this
/// package's naming-drift note (placement.dart), and with the type
/// parameter §5.1 does not carry — see below.
///
/// **The type parameter is CR-106's, and it arrived late on purpose.**
/// §5.1 hard-types `apply`/`revert` to `RackDocument` and M0 transcribed
/// that literally; `UndoStack<A>` has carried `<A>` since M0 for CR-106's
/// documented intent while its own `undo`/`redo` still took a concrete
/// document, and `undo_stack.dart`'s header named the gap as deferred
/// debt to close *"if/when the Device Builder's own stack is built"*.
/// M4-A is that moment. CR-106 rules **one `Command` machinery, three
/// stacks**: the document's, the Device Builder's over the `TemplateBody`
/// being edited, and none at all for settings and library operations,
/// which are individually confirmable instead. Making this generic AFTER
/// the builder's UI existed would have meant migrating the builder's own
/// commands too, which is the whole reason M4-A runs first.
///
/// Three properties MUST hold, verified by `command_roundtrip_test.dart`:
///  * `apply`/`revert`, not `undo`/`redo` — redo is `apply()` again.
///  * A command is idempotent under alternation: `apply; revert; apply`
///    lands in the identical state as a single `apply`.
///  * Commands store before-values, not whole entities, and never
///    allocate ids at `apply` time — ids are minted in the constructor
///    (see `newEntityId()`, util/id_gen.dart), so redo recreates the
///    identical entity and anything stacked on top of it still resolves.
abstract base class Command<A> {
  const Command();

  LabelKey get label;

  /// The document epochs this command invalidates, or `null` when [A] has
  /// no epoch model — see [DocEpochs.bump] for why that is not
  /// [EpochMask.none]. Every `Command<RackDocument>` returns non-null;
  /// the nullability exists for the aggregates that are not documents.
  EpochMask? get touches;

  Iterable<Uuid> get affects;
  Object? get mergeKey => null;

  bool apply(A aggregate);
  void revert(A aggregate);

  Command<A>? mergeWith(Command<A> next) => null;
}
