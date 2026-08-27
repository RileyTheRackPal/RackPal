// AC-018 over a REAL starter: an unbound far end still schedules, gets a
// `W` number and gets a label. Board M3-A/2 (#141).
//
// =====================================================================
// WHY THIS EXISTS, AND WHAT IT DELIBERATELY DOES NOT CLAIM
// =====================================================================
// #141's own instruction is to VERIFY that M2-B's schedule already handles
// unbound ends "with a hand-built document rather than assuming it", so the
// remaining work is producing the drops rather than teaching the schedule.
// `derived/schedule_test.dart` already does the hand-built half well: it
// carries a `W041` row whose ends are a `PlaceEndpoint` and an
// `OpenEndpoint`, asserts its field label, and asserts that the Termination
// Schedule correctly EXCLUDES a row that lands in no rack while the Pull
// Sheet keeps it.
//
// What no test read until now is the REAL FILE. `whole_house.rmpj` carries
// 42 `place` and 27 `open` endpoints, and a synthetic fixture agreeing with
// itself is weaker evidence than the document a user actually opens. This
// asserts the AC-018 clause over that file.
//
// THE FOURTH CLAUSE, "PRINTS", IS NOT ASSERTED HERE AND CANNOT BE YET.
// `SheetRole` has exactly three values — front elevation, rear elevation,
// equipment list — so there is no Pull Sheet or Termination Schedule in the
// exporter at all. Those are M6 sheets, which is what M3-D's board task
// calls "the M6 straddle". Asserting "it prints" against a sheet that does
// not exist would be the empty check this repository's testing discipline
// warns about, so the clause is NAMED as owed rather than faked.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal/src/session/starter_projects.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// Whether [endpoint] is a far end with nothing on the other side of it.
bool _isUnbound(Endpoint endpoint) => switch (endpoint) {
  PortEndpoint() => false,
  PlaceEndpoint() => true,
  OpenEndpoint() => true,
};

void main() {
  final starter = kStarterProjects.firstWhere(
    (s) => s.assetPath.contains('whole_house'),
  );

  late RackDocument doc;

  setUpAll(() {
    final bytes = File(starter.assetPath).readAsBytesSync();
    doc = (const JsonDocumentCodec().read(bytes) as Ok<RackDocument>).value;
  });

  group('AC-018 over whole_house.rmpj', () {
    test('the fixture is what this test thinks it is', () {
      // The guard that stops this whole file going vacuous. If the starter
      // is ever regenerated without unbound ends, every assertion below
      // would pass over an empty set and prove nothing.
      final unbound = <Uuid>{};
      for (final link in doc.links.values) {
        for (final c in link.conductors) {
          if (_isUnbound(c.from) || _isUnbound(c.to)) unbound.add(link.id);
        }
      }

      expect(
        unbound,
        isNotEmpty,
        reason:
            'whole_house.rmpj carries no unbound endpoint, so AC-018 is not '
            'exercised by any real file and the assertions below are empty',
      );
    });

    test('every link with an unbound end still SCHEDULES', () {
      final scheduled = {for (final row in buildSchedule(doc).rows) row.linkId};

      for (final link in doc.links.values) {
        final unbound = link.conductors.any(
          (c) => _isUnbound(c.from) || _isUnbound(c.to),
        );
        if (!unbound) continue;
        expect(
          scheduled,
          contains(link.id),
          reason:
              '${link.designator} has an unbound end and fell out of the '
              'schedule entirely (AC-018)',
        );
      }
    });

    test('every one of them carries a W NUMBER and a LABEL', () {
      for (final row in buildSchedule(doc).rows) {
        final link = doc.links[row.linkId]!;
        final unbound = link.conductors.any(
          (c) => _isUnbound(c.from) || _isUnbound(c.to),
        );
        if (!unbound) continue;

        expect(
          row.designator,
          isNotEmpty,
          reason: 'an unbound run with no W number cannot be called for',
        );
        expect(
          row.designator,
          startsWith('W'),
          reason: 'AC-018 says the run still gets a `W` number',
        );
        // CR-113: the field label is REQUIRED and project-unique. It is
        // what the installer reads off the plate, and it is the only
        // identifier an unbound end has.
        expect(
          link.structureOrigin?.fieldLabel,
          isNotNull,
          reason:
              '${row.designator} is a home run with an unbound end and no '
              'fieldLabel, so nothing on the wall names it (CR-113)',
        );
      }
    });

    test('they reach the PULL SHEET, which is the sheet they belong on', () {
      final pull = scheduleViewOf(doc, preset: SchedulePreset.pullSheet);
      final onSheet = <Uuid>{
        for (final group in pull.groups)
          for (final row in group.rows) row.linkId,
      };

      for (final link in doc.links.values) {
        final unbound = link.conductors.any(
          (c) => _isUnbound(c.from) || _isUnbound(c.to),
        );
        if (!unbound) continue;
        expect(
          onSheet,
          contains(link.id),
          reason:
              '${link.designator} is a pull with an unbound far end and the '
              'Pull Sheet dropped it, which is the sheet an installer works '
              'from (AC-018)',
        );
      }
    });

    test('the TERMINATION SCHEDULE excludes them, and SAYS how many', () {
      // Not a contradiction of the clause above: a termination schedule is
      // about what lands in a rack, and a run whose far end is a coil in a
      // J-hook terminates nowhere. What AC-018 forbids is dropping them
      // SILENTLY, so the exclusion has to be counted and reported.
      final term = scheduleViewOf(
        doc,
        preset: SchedulePreset.terminationSchedule,
      );

      expect(
        term.exclusions.notLandingInRack,
        greaterThan(0),
        reason:
            'whole_house has unbound ends, so the Termination Schedule must '
            'report a non-zero excluded count rather than a silent drop',
      );
    });
  });
}
