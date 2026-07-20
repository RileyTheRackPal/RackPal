// Unit tests for ResizePreviewController — the UI-owned state behind
// docs/04-rack-editor.md §4.1's THIRD way to change rack height, the top-edge
// drag with its "24U (+3)" readout and its red doomed-U hatch.
//
// PURE STATE, NO WIDGET TREE, matching its two sibling controllers'
// tests. What is deliberately NOT here, because it is not this class's:
// the 8px grab band, `EditingOverlayPainter._paintResizePreview`'s actual
// canvas ops, and the pointer-up hand-off into the screen's height funnel.
// Those need real gestures and a recording canvas against
// `RackCanvasScreen`, and as of this file they remain UNTESTED — an
// adversarial review killed a mutation that blanked the hatch painting
// outright with the whole rackmate_ui suite still green.

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

const _rect = DBox.fromLtwh(10, 20, 100, 40);

void main() {
  test("the readout is §4.1's own three spellings: bare at the identity "
      'position, signed while growing, signed while shrinking', () {
    final c = ResizePreviewController();
    addTearDown(c.dispose);

    c.begin(12);
    // "the candidate starts EQUAL to the original" — a `(+0)` would be noise.
    expect(c.readout, '12U');
    expect(c.candidateHeightU, 12);
    expect(c.originalHeightU, 12);

    c.update(candidateHeightU: 24, cursorGlobal: null, doomedRects: const []);
    expect(c.readout, '24U (+12)');

    c.update(candidateHeightU: 9, cursorGlobal: null, doomedRects: const []);
    expect(c.readout, '9U (-3)');

    c.update(candidateHeightU: 12, cursorGlobal: null, doomedRects: const []);
    expect(c.readout, '12U', reason: 'back at the identity position');
  });

  test('the doomed hatch data survives update() and is counted per '
      'occupant, not per rect by accident', () {
    final c = ResizePreviewController();
    addTearDown(c.dispose);

    c.begin(24);
    expect(c.doomedRects, isEmpty);
    expect(c.doomedCount, 0);

    c.update(
      candidateHeightU: 12,
      cursorGlobal: const Offset(40, 50),
      doomedRects: const [_rect, DBox.fromLtwh(10, 80, 100, 40)],
    );

    // The mutation this kills: `update()` storing `const []` / `0`, which
    // silently removes §4.1's "the collision is visible BEFORE release".
    expect(c.doomedRects, hasLength(2));
    expect(c.doomedRects.first.left, 10);
    expect(c.doomedRects.first.top, 20);
    expect(c.doomedCount, 2);
    expect(c.cursorGlobal, const Offset(40, 50));
  });

  test('growing produces no hatch, so "growing is always safe" needs no '
      'special case', () {
    final c = ResizePreviewController();
    addTearDown(c.dispose);

    c
      ..begin(12)
      ..update(
        candidateHeightU: 30,
        cursorGlobal: null,
        doomedRects: const [],
      );

    expect(c.doomedRects, isEmpty);
    expect(c.doomedCount, 0);
    expect(c.readout, '30U (+18)');
  });

  test('update() before begin() is ignored — an unarmed controller cannot '
      'be driven into a half-live state by a stray move event', () {
    final c = ResizePreviewController();
    addTearDown(c.dispose);

    c.update(
      candidateHeightU: 4,
      cursorGlobal: Offset.zero,
      doomedRects: const [_rect],
    );

    expect(c.isActive, isFalse);
    expect(c.candidateHeightU, 0);
    expect(c.doomedRects, isEmpty);
  });

  test('cancel() clears every field and notifies exactly once; a second '
      'cancel is silent', () {
    final c = ResizePreviewController();
    addTearDown(c.dispose);

    var notifications = 0;
    c
      ..addListener(() => notifications++)
      ..begin(12)
      ..update(
        candidateHeightU: 6,
        cursorGlobal: const Offset(1, 2),
        doomedRects: const [_rect],
      );
    expect(c.isActive, isTrue);
    expect(notifications, 2);

    c.cancel();
    expect(c.isActive, isFalse);
    expect(c.candidateHeightU, 12, reason: 'nothing was ever committed');
    expect(c.cursorGlobal, isNull);
    expect(c.doomedRects, isEmpty);
    expect(c.doomedCount, 0);
    expect(notifications, 3);

    // "already clear — avoid a spurious notify".
    c.cancel();
    expect(notifications, 3);
  });

  test('update() notifies on EVERY move, even when the snapped height does '
      'not change — the chip and hatch track the cursor', () {
    final c = ResizePreviewController();
    addTearDown(c.dispose);

    c.begin(12);
    var notifications = 0;
    c
      ..addListener(() => notifications++)
      ..update(
        candidateHeightU: 12,
        cursorGlobal: Offset.zero,
        doomedRects: const [],
      )
      ..update(
        candidateHeightU: 12,
        cursorGlobal: const Offset(0, 3),
        doomedRects: const [],
      );

    expect(notifications, 2);
    expect(c.cursorGlobal, const Offset(0, 3));
  });
}
