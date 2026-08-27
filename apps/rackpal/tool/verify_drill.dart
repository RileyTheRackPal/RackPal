// Checks a saved `.rmpj` against AC-018, clause by clause. Board M3-G/3
// (#165), docs/16-m3g-drill.md.
//
// ═════════════════════════════════════════════════════════════════════
// WHY A TOOL AND NOT A TEST
// ═════════════════════════════════════════════════════════════════════
// Every clause below is already gated somewhere in the suite against a
// document a test built. That is not what this is for. M3-G's artifact is
// a file a PERSON made, in the app, under a stopwatch, and the question
// is whether THAT file satisfies the criterion. A test cannot ask it,
// because a test has no such file.
//
// So this reads the person's file and prints numbers. It does not time
// anybody and it cannot: fifteen seconds per drop including thinking is a
// human fact, and #164's conditions form is the only instrument for it.
//
// ═════════════════════════════════════════════════════════════════════
// IT REPORTS EVERY CLAUSE, NEVER ONLY THE FIRST FAILURE
// ═════════════════════════════════════════════════════════════════════
// A drill run costs a person fifteen minutes. Stopping at the first FAIL
// would send them back for a second run to discover the second problem,
// which is exactly the cost M1's re-run paid twice.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';

/// AC-018's own numbers, transcribed rather than parameterised.
const _expectedDrops = 60;
const _expectedOpen = 14;
const _expectedRooms = 10;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/verify_drill.dart <file.rmpj>');
    exit(2);
  }
  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('No such file: ${args.first}');
    exit(2);
  }

  final read = const JsonDocumentCodec().read(file.readAsBytesSync());
  final RackDocument doc;
  switch (read) {
    case Err(:final error):
      stderr.writeln('Could not read it: $error');
      exit(2);
    case Ok(value: final d):
      doc = d;
  }

  final drops = [
    for (final l in doc.links.values)
      if (l.structureOrigin != null) l,
  ];
  final open = [
    for (final l in drops)
      if (l.conductors.isNotEmpty && l.conductors.first.to is! PortEndpoint) l,
  ];
  final landed = drops.length - open.length;
  final withField = drops.where((l) => _has(l.structureOrigin?.fieldLabel));
  final landedWithRack = [
    for (final l in drops)
      if (!open.contains(l) && _has(l.structureOrigin?.rackLabel)) l,
  ];
  final openWithRack = [
    for (final l in open)
      if (_has(l.structureOrigin?.rackLabel)) l,
  ];

  // CR-113 at the artifact, and as a SET rather than a count: a duplicate
  // hides perfectly inside a matching total.
  final fieldLabels = [
    for (final l in drops)
      if (l.structureOrigin?.fieldLabel case final f?) f,
  ];
  final rackLabels = [
    for (final l in drops)
      if (l.structureOrigin?.rackLabel case final r?) r,
  ];

  final schedule = buildSchedule(doc);
  final scheduled = {for (final r in schedule.rows) r.linkId};
  final withW = schedule.rows.where((r) => r.designator.trim().isNotEmpty);
  final openScheduled = open.where((l) => scheduled.contains(l.id));
  final openWithW = schedule.rows.where(
    (r) => open.any((l) => l.id == r.linkId) && r.designator.trim().isNotEmpty,
  );

  final rooms = <Uuid>{
    for (final l in drops)
      if (l.conductors.isNotEmpty)
        if (l.conductors.first.from case PlaceEndpoint(:final locationId?))
          locationId,
  };

  final results = <_Check>[
    _Check('sixty drops reached the document', drops.length, _expectedDrops),
    _Check('across ten rooms', rooms.length, _expectedRooms),
    _Check('every drop carries a fieldLabel', withField.length, drops.length),
    _Check(
      'every fieldLabel is unique, project-wide (CR-113)',
      fieldLabels.toSet().length,
      fieldLabels.length,
    ),
    _Check(
      'fourteen far ends are UNBOUND (AC-018)',
      open.length,
      _expectedOpen,
    ),
    _Check(
      'the other forty-six are LANDED on a port',
      landed,
      _expectedDrops - _expectedOpen,
    ),
    _Check(
      'every landed drop carries a rackLabel',
      landedWithRack.length,
      landed,
    ),
    // THE CONVERSE, AND IT IS THE ONE THAT CATCHES A FABRICATION. A build
    // that invented a label for an unbound end would pass every count
    // above; nothing may name a panel position a cable has not reached
    // (G4).
    _Check(
      'and NO unbound drop carries one (G4: nothing is fabricated)',
      openWithRack.length,
      0,
    ),
    _Check(
      'every rackLabel is unique where set (CR-113)',
      rackLabels.toSet().length,
      rackLabels.length,
    ),
    _Check('every drop schedules', scheduled.length, doc.links.length),
    _Check(
      'every scheduled row carries a W number',
      withW.length,
      scheduled.length,
    ),
    _Check(
      'the fourteen unbound ones schedule too',
      openScheduled.length,
      _expectedOpen,
    ),
    _Check(
      '...and each of those carries a W number',
      openWithW.length,
      _expectedOpen,
    ),
  ];

  stdout.writeln('AC-018 against ${file.path}\n');
  for (final r in results) {
    stdout.writeln(r);
  }

  final failed = results.where((r) => !r.ok).length;
  stdout
    ..writeln()
    ..writeln(
      failed == 0
          ? 'ALL ${results.length} CLAUSES MET.\n\n'
                'This is the FILE half of the criterion and not the whole of '
                'it. The clock and the operator conditions are #164, and the '
                'sheet is M6 (#574). Write the verdict into '
                'docs/16-m3g-drill.md §5 either way.'
          : '$failed of ${results.length} clauses REFUTED.\n\n'
                'Record it as a refutation rather than as a to-do (#165). '
                "M1's refutation is the most useful record on the board "
                'precisely because it was written that way.',
    );
  if (failed > 0) exit(1);
}

bool _has(String? s) => s != null && s.trim().isNotEmpty;

class _Check {
  _Check(this.what, this.got, this.want);

  final String what;
  final int got;
  final int want;

  bool get ok => got == want;

  @override
  String toString() =>
      '${ok ? 'PASS' : 'FAIL'}  $what  (got $got, expected $want)';
}
