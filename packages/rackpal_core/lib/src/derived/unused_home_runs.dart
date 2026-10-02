// rackpal_core/src/derived/unused_home_runs.dart — pure Dart.
//
// The rows of T6.20, Unused Home Runs (docs/08 §2.2 row n+3, M6-E1 `#332`,
// DR-220).
//
// ═══════════════════════════════════════════════════════════════════════
// A HOME RUN WITH AN OPEN END, AT EITHER END (DR-220 §11.219.1)
// ═══════════════════════════════════════════════════════════════════════
// A home run is a `Link` carrying a `StructureOrigin`. It is unused when
// its rack end OR its field end is an `OpenEndpoint`. The user widened
// canon §4.3's "an unbound rack end" to the room end too: a run landed and
// dressed at the rack and left as a coil at the room is just as unused.
//
// docs/01's "terminated at the DD with no device on it" was NOT taken. It
// is a different sheet, and on Whole House, which draws no patch cords, it
// would list every run the project has.
//
// WHICH END IS THE RACK END IS THE SCHEDULE'S ORIENTATION, NOT A SECOND
// RULE. `buildSchedule` puts the end in a rack at `to` when exactly one end
// is, and otherwise keeps the conductor's own order, whose `to` is where
// `AddHomeRunCommand` writes the rack end and where `plan_length.dart`
// reads it. So the rack end is always `entry.to` and the field end always
// `entry.from`, and this file reads them rather than re-deciding them.
//
// THIS FILE FILTERS AND ORDERS; IT FORMATS NOTHING. Every cell the sheet
// shares with the Schedule view is `ScheduleEntry.cell`, so the two cannot
// print one run two ways.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Which end of an unused home run is open (DR-220 §11.219.3).
enum OpenEnd {
  /// The rack end is a coil; the room end is a place or a port.
  rack('RACK'),

  /// The rack end has landed; the room end is a coil.
  room('ROOM'),

  /// Neither end is terminated anywhere.
  both('BOTH');

  const OpenEnd(this.label);

  /// What the `OPEN` column prints.
  final String label;
}

/// One row of T6.20: a schedule row, and which of its ends is open.
@immutable
final class UnusedHomeRun {
  const UnusedHomeRun({required this.entry, required this.open});

  /// The schedule's own row for this run, so every shared cell is the
  /// Schedule view's string.
  final ScheduleEntry entry;
  final OpenEnd open;

  /// The end at the room: the schedule's `from` (see the file header).
  ScheduleEnd get fieldEnd => entry.from;

  /// The end at the rack: the schedule's `to`.
  ScheduleEnd get rackEnd => entry.to;
}

/// One room's runs on T6.20: a band and its rows.
@immutable
final class UnusedHomeRunRoom {
  const UnusedHomeRunRoom({
    required this.roomId,
    required this.title,
    required this.runs,
  });

  /// Null for the runs whose room nobody recorded.
  final Uuid? roomId;

  /// The room's name, or [kUngroupedTitle] for [roomId] null.
  final String title;
  final List<UnusedHomeRun> runs;
}

/// Which end of [entry] is open, or null when neither is.
///
/// Public so the one predicate T6.20 lists by is the one a test can call
/// on a single row.
OpenEnd? openEndOf(ScheduleEntry entry) {
  final rackOpen = entry.to.kind == ScheduleEndKind.open;
  final roomOpen = entry.from.kind == ScheduleEndKind.open;
  return switch ((rackOpen, roomOpen)) {
    (true, true) => OpenEnd.both,
    (true, false) => OpenEnd.rack,
    (false, true) => OpenEnd.room,
    (false, false) => null,
  };
}

/// T6.20's rows for [doc], in bands by room.
///
/// [schedule] is the export's one `buildSchedule(doc)`, handed in rather
/// than rebuilt, for CR-107's reason: two derivations of one row can
/// disagree.
///
/// ORDER (DR-220 §11.219.2, §11.219.4). Rooms by name, natural, with the
/// room id breaking a tie between two rooms of one name so neither band
/// splits; [kUngroupedTitle] last. Within a room, cable ID natural, ending
/// in the link id so the chain is TOTAL (Dart's `List.sort` is not
/// stable). Empty when nothing is unused, which is what makes the sheet
/// `AUTO`.
List<UnusedHomeRunRoom> unusedHomeRunsOf(
  Schedule schedule,
  RackDocument doc,
) {
  final runs = <UnusedHomeRun>[
    for (final entry in schedule.rows)
      if (doc.links[entry.linkId]?.structureOrigin != null)
        if (openEndOf(entry) case final open?)
          UnusedHomeRun(entry: entry, open: open),
  ];
  int byRoom(UnusedHomeRun a, UnusedHomeRun b) {
    final ra = a.entry.roomName;
    final rb = b.entry.roomName;
    // NULLS LAST, the schedule's own rule for a room nobody recorded.
    if (ra == null || rb == null) {
      if (ra != rb) return ra == null ? 1 : -1;
    } else {
      final byName = compareDesignators(ra, rb);
      if (byName != 0) return byName;
    }
    return (a.entry.roomId?.v ?? '').compareTo(b.entry.roomId?.v ?? '');
  }

  runs.sort((a, b) {
    final room = byRoom(a, b);
    if (room != 0) return room;
    final byId = compareDesignators(a.entry.designator, b.entry.designator);
    return byId != 0 ? byId : a.entry.linkId.v.compareTo(b.entry.linkId.v);
  });

  final rooms = <UnusedHomeRunRoom>[];
  var band = <UnusedHomeRun>[];
  void close() {
    if (band.isEmpty) return;
    final first = band.first.entry;
    rooms.add(
      UnusedHomeRunRoom(
        roomId: first.roomId,
        title: first.roomName ?? kUngroupedTitle,
        runs: List.unmodifiable(band),
      ),
    );
    band = <UnusedHomeRun>[];
  }

  for (final run in runs) {
    if (band.isNotEmpty && byRoom(band.first, run) != 0) close();
    band.add(run);
  }
  close();
  return List.unmodifiable(rooms);
}
