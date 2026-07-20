// Unit tests for CompactionPreviewController — the UI-owned state behind
// docs/04-rack-editor.md §3.6's preview overlay. Pure state, no widget tree:
// the SCREEN-level behaviour (ghosts, dimming, Enter/Esc, the stale-plan
// guard) is exercised by rack_compaction_test.dart against real gestures.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

CompactionMove _move(String id, {int from = 4, int to = 2, int h = 2}) =>
    CompactionMove(
      deviceId: Uuid(id),
      designator: id.toUpperCase(),
      fromRuIndex: from,
      toRuIndex: to,
      deviceH: h,
      face: Face.front,
    );

CompactionPlan _plan({
  CompactDirection direction = CompactDirection.down,
  List<CompactionMove> moves = const [],
  int freedU = 0,
}) => CompactionPlan(
  direction: direction,
  face: Face.front,
  moves: moves,
  freedU: freedU,
);

void main() {
  test('an EMPTY plan is refused rather than shown', () {
    // §3.4's "never silently do nothing", read carefully: an already-packed
    // rack is a real answer, and the caller needs to be able to SAY so. A
    // controller that happily "showed" an empty plan would put a bar on
    // screen offering to move zero devices, and the screen would have no way
    // to tell that case from a real one.
    final c = CompactionPreviewController();
    addTearDown(c.dispose);

    expect(c.show(_plan(), documentSequence: 7), isFalse);
    expect(c.isActive, isFalse);
    expect(c.plan, isNull);
  });

  test('a non-empty plan becomes active and captures the document '
      'sequence', () {
    final c = CompactionPreviewController();
    addTearDown(c.dispose);

    expect(
      c.show(
        _plan(moves: [_move('dev-a')], freedU: 2),
        documentSequence: 41,
      ),
      isTrue,
    );
    expect(c.isActive, isTrue);
    // The captured sequence is what the screen's stale-plan guard compares
    // against; a controller that forgot it would make that guard vacuous.
    expect(c.documentSequence, 41);
  });

  test("barLabel is §3.6's exact sentence, for both directions and for "
      'the singular case', () {
    final c = CompactionPreviewController();
    addTearDown(c.dispose);

    c.show(
      _plan(
        direction: CompactDirection.up,
        moves: [_move('a'), _move('b'), _move('c'), _move('d')],
        freedU: 3,
      ),
      documentSequence: 1,
    );
    // The spec's own worked example, verbatim: "Compact Up — 4 devices move
    // — 3U freed".
    expect(c.barLabel, 'Compact Up — 4 devices move — 3U freed');

    c
      ..cancel()
      ..show(
        _plan(moves: [_move('a')], freedU: 1),
        documentSequence: 2,
      );
    expect(c.barLabel, 'Compact Down — 1 device moves — 1U freed');
  });

  test('movingDeviceIds / moves() name exactly the devices that MOVE — a '
      'device that stays put is not part of the proposal', () {
    // The §3.6 dimming ("current positions dimmed to 25%") is driven off
    // this. Dimming a device that is not moving would tell the user the
    // whole rack is about to change.
    final c = CompactionPreviewController();
    addTearDown(c.dispose);
    c.show(
      _plan(moves: [_move('dev-amp'), _move('dev-sw')], freedU: 2),
      documentSequence: 1,
    );

    expect(c.movingDeviceIds, {'dev-amp', 'dev-sw'});
    expect(c.moves('dev-amp'), isTrue);
    expect(c.moves('dev-ups'), isFalse);
  });

  test('cancel() clears everything and stops reporting movers', () {
    var notifications = 0;
    final c = CompactionPreviewController()
      ..show(_plan(moves: [_move('dev-amp')], freedU: 1), documentSequence: 3);
    addTearDown(c.dispose);
    c
      ..addListener(() => notifications++)
      ..cancel();
    expect(c.isActive, isFalse);
    expect(c.plan, isNull);
    expect(c.moves('dev-amp'), isFalse);
    expect(notifications, 1);

    // Idempotent: a second cancel is a no-op and must not fire a spurious
    // notification (the screen rebuilds on these).
    c.cancel();
    expect(notifications, 1);
  });
}
