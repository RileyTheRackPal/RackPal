// packages/rackpal_ui/lib/src/canvas/compaction_preview_controller.dart
//
// UI-owned observable state for docs/04-rack-editor.md §3.6's compaction
// PREVIEW: "Compact Down and Compact Up ship; they never apply silently.
// Each opens a preview overlay — proposed positions as solid ghosts,
// current positions dimmed to 25%, and a floating bar 'Compact Up — 4
// devices move — 3U freed [Apply] [Cancel]'. Enter applies as one undo
// entry, Esc cancels."
//
// This class holds a `CompactionPlan` and nothing else of substance. The
// PLAN is pure core (`rackpal_core/src/commands/compaction.dart`); this is
// the UI's answer to "is one currently on screen, and which document did it
// come from". Never persisted, never itself undone — only the eventual
// `Transaction` an Apply runs is undoable.
//
// WHY NOT `DragPreviewController`. That controller's entire vocabulary is
// "ONE device landing at ONE ruIndex": `subjectId`, `deviceH`, `face`,
// `evaluation.ruIndex`, `blocked`, `blockingRect`. A compaction preview has
// N devices, N target RUs, and — crucially — no blocked verdict at all: a
// plan is either empty (nothing to do, refused with a status message) or
// entirely applicable. Forcing it through that shape would mean a
// `subjectId` meaning a third thing and a nullable `evaluation` that is
// never consulted. The two DO share the discipline that matters — UI-owned
// state holder, evaluate-then-commit, painter and floating chrome as
// readers, timers owned by the screen — and they share the PAINTER, which
// is where the real duplication risk lived.
//
// STALENESS IS A REAL BUG CLASS HERE, not a hypothetical. A plan is computed
// against a document snapshot and then sits on screen until the user
// decides. If anything mutates the document in between — Ctrl+Z, a palette
// placement, a keyboard nudge — the plan's `fromRuIndex` values describe a
// world that no longer exists, and Apply would issue `MoveDeviceCommand`s
// whose `fromRuIndex` is a lie (which `revert()` would then faithfully
// restore, putting a device somewhere it never was). [documentSequence]
// records `RackDocument.sequence` at plan time so the screen can compare and
// cancel; see `RackCanvasScreen._onDocumentSequenceChanged`.

import 'package:flutter/foundation.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// The observable "a compaction preview is on screen" state. See the file
/// header for what it deliberately does not share with
/// `DragPreviewController`.
class CompactionPreviewController extends ChangeNotifier {
  CompactionPlan? _plan;
  int _documentSequence = -1;

  /// The plan being previewed, or null when nothing is on screen.
  CompactionPlan? get plan => _plan;

  /// `RackDocument.sequence` at the moment [show] captured [plan]. Compared
  /// against the live sequence to detect a plan that has gone stale under a
  /// concurrent edit (see the file header).
  int get documentSequence => _documentSequence;

  /// Whether a preview is on screen. Deliberately requires a NON-EMPTY plan:
  /// an empty plan is "nothing to compact", which §3.4's "never silently do
  /// nothing" says must be REPORTED, not rendered as an overlay with a bar
  /// offering to move zero devices.
  bool get isActive => _plan != null;

  /// The devices whose CURRENT position should render dimmed (§3.6's
  /// "current positions dimmed to 25%") — exactly the ones that move.
  /// A device that stays put is not part of the proposal and must keep its
  /// full-strength rendering, or the overlay would imply the whole rack is
  /// about to change.
  Set<String> get movingDeviceIds => {
    for (final m in _plan?.moves ?? const <CompactionMove>[]) m.deviceId.v,
  };

  /// Whether [deviceId] is one of the devices this preview proposes to move.
  bool moves(String deviceId) {
    final plan = _plan;
    if (plan == null) return false;
    for (final m in plan.moves) {
      if (m.deviceId.v == deviceId) return true;
    }
    return false;
  }

  /// §3.6's floating bar, verbatim in shape: "Compact Up — 4 devices move —
  /// 3U freed". Built here rather than in the bar widget so the label and
  /// the plan can never disagree, and so a test can assert the exact string
  /// without pumping a widget tree.
  ///
  /// The em dashes and the pluralisation are the spec's own; "1 device
  /// moves" rather than "1 devices move" is the one thing added, since a
  /// single-device compaction is entirely ordinary.
  String get barLabel {
    final plan = _plan;
    if (plan == null) return '';
    final direction = plan.direction == CompactDirection.down
        ? 'Compact Down'
        : 'Compact Up';
    final n = plan.moves.length;
    final devices = n == 1 ? '1 device moves' : '$n devices move';
    return '$direction — $devices — ${plan.freedU}U freed';
  }

  /// Opens a preview for [plan], captured against document sequence
  /// [documentSequence].
  ///
  /// Returns false — and shows NOTHING — for an empty plan, so the caller
  /// can report "Nothing to compact" instead of putting a do-nothing bar on
  /// screen (§3.4). That is the only reason this returns a value.
  bool show(CompactionPlan plan, {required int documentSequence}) {
    if (plan.isEmpty) return false;
    _plan = plan;
    _documentSequence = documentSequence;
    notifyListeners();
    return true;
  }

  /// Tears the preview down: Apply, Esc/Cancel, a stale-document cancel, or
  /// any other interaction claiming the screen (see the screen's
  /// preview-exclusivity invariant).
  void cancel() {
    if (_plan == null) return; // already clear — avoid a spurious notify.
    _plan = null;
    _documentSequence = -1;
    notifyListeners();
  }
}
