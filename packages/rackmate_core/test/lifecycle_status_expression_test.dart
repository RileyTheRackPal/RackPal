// `LifecycleStatus` reaches paper as its OWN thing, on every surface that
// expresses it. Board M3-A/3 (#142).
//
// =====================================================================
// THE PROPERTY, IN THE TASK'S OWN WORDS
// =====================================================================
// "A value that renders identically to `new_` everywhere is a value the
// model carries and the drawing cannot express." Two surfaces already
// decided what `designIntent` looks like — `lifecycleStroke` gives it the
// dash-dot that is the drafting convention for intent, and
// `lifecycleLabel` prints `DESIGN INTENT` — but NOTHING PINNED EITHER.
// `equipment_list_test.dart` checks the labels are non-empty and carry no
// stray underscore; it never checks that two of them differ, so collapsing
// `designIntent` onto `new_` in either table would have passed every gate.
//
// =====================================================================
// WHAT THIS FILE FOUND AND DOES NOT FIX, RECORDED SO IT IS NOT REDISCOVERED
// =====================================================================
// #142's premise is that the fifth value is "unused by any surface". That
// is STALE for the elevation and the equipment list, which both express it
// and are pinned below. It is TRUE, and stays true, for two others:
//
//  * THE SCHEDULE CARRIES IT AND NEVER READS IT. `ScheduleEntry
//    .lifecycleStatus` is populated (`schedule.dart`) and no `cell()` case
//    or `ScheduleColumnId` consumes it, so a `designIntent` run prints on
//    the Pull Sheet indistinguishable from a `new_` one — as do `future`,
//    `removed` and `existing`. NOT FIXED HERE ON PURPOSE: docs/08 §3.2 and
//    §3.3 enumerate both presets' columns at exact widths and neither has a
//    status column, so adding one is a scope change to a specified sheet
//    and needs a ruling under roadmap §8.3, not a test author's opinion.
//
//  * NOTHING CAN SET IT. `lifecycleStatus` appears nowhere in
//    `rackmate_ui/lib` or `apps/rackmate/lib`, so every value except the
//    `new_` default is reachable only by hand-authoring a file. The
//    elevation's five borders are correct and, today, four of them are
//    unreachable through the app.
//
// Both are board items rather than silent gaps.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const int _argb = 0xFF000000;

void main() {
  group('the elevation border tells the five states apart', () {
    test('every status gets a DISTINCT stroke', () {
      // The guard the task is actually about. Mutual distinctness, not
      // "designIntent is not new_", because collapsing any pair loses a
      // state the model claims to carry.
      final byStatus = <LifecycleStatus, Stroke>{
        for (final s in LifecycleStatus.values) s: lifecycleStroke(s, _argb),
      };

      expect(
        byStatus.values.toSet(),
        hasLength(LifecycleStatus.values.length),
        reason:
            'two lifecycle states share one border, so the elevation cannot '
            'express a distinction the model carries: $byStatus',
      );
    });

    test('designIntent is not new_, specifically', () {
      // Named on its own because `new_` is the DEFAULT every device the app
      // creates gets, so this is the collapse that would hide in plain
      // sight: every drawing would look right.
      expect(
        lifecycleStroke(LifecycleStatus.designIntent, _argb),
        isNot(lifecycleStroke(LifecycleStatus.new_, _argb)),
      );
    });

    test('the channel is DASH and WEIGHT, never hue (P4)', () {
      // The sheet is routinely printed on a greyscale laser and photocopied
      // (AC-054), so a state encoded as colour alone does not survive the
      // deliverable. Every stroke must carry the argb it was handed.
      for (final status in LifecycleStatus.values) {
        expect(
          lifecycleStroke(status, _argb).argb,
          _argb,
          reason: '$status tinted its own border, which P4 prohibits',
        );
      }
    });

    test('designIntent uses a dash pattern, not merely a weight', () {
      // A weight-only difference is the one that does not survive a
      // photocopy or a 0.5pt print floor.
      final stroke = lifecycleStroke(LifecycleStatus.designIntent, _argb);
      expect(stroke.dash, isNotNull);
      expect(stroke.dash, isNotEmpty);
    });
  });

  group('the equipment list prints the five states apart', () {
    test('every status gets a DISTINCT label', () {
      final labels = <String>[
        for (final s in LifecycleStatus.values) lifecycleLabel(s),
      ];

      expect(
        labels.toSet(),
        hasLength(LifecycleStatus.values.length),
        reason: 'two states print the same word on T6.30: $labels',
      );
    });

    test('designIntent prints DESIGN INTENT, not NEW', () {
      expect(lifecycleLabel(LifecycleStatus.designIntent), 'DESIGN INTENT');
      expect(
        lifecycleLabel(LifecycleStatus.designIntent),
        isNot(lifecycleLabel(LifecycleStatus.new_)),
      );
    });
  });

  group('the whole enum is expressed, not just the four that predate it', () {
    test('adding a sixth value fails both tables rather than defaulting', () {
      // `lifecycleStroke` and `lifecycleLabel` are both exhaustive
      // `switch` expressions over the enum, so a new value is a COMPILE
      // error in each rather than a silent fall-through to `new_`. This
      // asserts the count the two tables are exhaustive over, so the day
      // someone adds a sixth state this file names what else it owes.
      expect(
        LifecycleStatus.values,
        hasLength(5),
        reason:
            'the enum grew: give the new value its own border and its own '
            'label, and check whether the schedule and the UI gaps in this '
            "file's header still stand",
      );
    });
  });
}
