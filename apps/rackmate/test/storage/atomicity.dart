// One executable statement of "written atomically", shared by the three
// small JSON stores.
//
// ==================================================================
// WHY THIS EXISTS
// ==================================================================
// `snapshot_store_test.dart`, `recents_store_test.dart` and
// `prefs_store_test.dart` each claimed atomicity in a test NAME and then
// asserted only the final set of files: "no .tmp survives", "no .bak
// survives", "the keys are exactly [prefs.json]". Every one of those is
// trivially true of a plain, non-atomic `fs.writeBytes` — a one-shot write
// leaves no siblings at all. So replacing
//
//     writer.write(paths: ..., keepBackup: false)
//
// with `await fs.writeBytes(path, bytes)` in any of the three passed the
// whole suite, while a crash mid-write went from "the previous good copy
// survives" to "the file is truncated". `atomic_writer_crash_test.dart`
// makes exactly this argument about itself at its stray-sweeping group —
// "a test using that shape proves nothing about the sweep at all" — and
// the same shape was then used in all three of these files.
//
// Atomicity is a property of the INSTANTS DURING the write, not of the
// state after it, so it is asserted where those instants exist: over every
// prefix of the journal, under a process kill and under power loss.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'fake_file_store.dart';

/// Asserts that everything in [fs]'s CURRENT journal wrote [target]
/// atomically.
///
/// The caller arranges for the journal to cover exactly the write under
/// test — usually by calling [FakeFileStore.resetJournal] first, so a
/// second write replays against "the first write's output is now the
/// previous good copy".
///
/// [previous] is the complete content the file held before the write, or
/// null for a first write. [expected] is what it holds afterwards.
///
/// Three things are checked, and the first is the one a plain
/// `writeBytes` fails:
///
///  1. AT EVERY PREFIX the file is absent, exactly [previous], or exactly
///     [expected] — never `Indeterminate`, which is the model's honest
///     name for "some unknown number of the bytes are there".
///  2. When [previous] is non-null the file NEVER VANISHES: a reader that
///     opens between the two instants finds a file, not a gap.
///  3. The new content ARRIVES BY RENAME. A rename is the one operation
///     the whole design rests on being all-or-nothing, and `contract`
///     proves the real filesystem agrees.
void expectAtomicWrite(
  FakeFileStore fs, {
  required String target,
  required Uint8List expected,
  Uint8List? previous,
  String what = 'the file',
}) {
  expect(
    fs.journal,
    isNotEmpty,
    reason: 'a write that journalled nothing proves nothing',
  );

  for (final powerLoss in [false, true]) {
    for (var k = 0; k <= fs.journal.length; k++) {
      final state = powerLoss
          ? fs.replayPrefixAfterPowerLoss(k)
          : fs.replayPrefix(k);
      final content = state.files[target];
      final where =
          '$what: ${powerLoss ? 'POWER LOSS' : 'process kill'} at prefix '
          '$k/${fs.journal.length}'
          '${k < fs.journal.length ? ' (next: ${fs.journal[k]})' : ''}';

      if (previous != null) {
        expect(
          content,
          isNotNull,
          reason:
              '$where: $target DOES NOT EXIST. A one-shot write, or a '
              'rename of the target out of the way, leaves a gap here.',
        );
      }
      if (content == null) continue;

      expect(
        content,
        anyOf(<Matcher>[
          isA<Bytes>().having((b) => b.value, 'bytes', orderedEquals(expected)),
          if (previous != null)
            isA<Bytes>().having(
              (b) => b.value,
              'bytes',
              orderedEquals(previous),
            ),
        ]),
        reason:
            '$where: $target is $content — neither the previous good '
            'copy nor the new one. A crash at this instant leaves a '
            'TRUNCATED file where the previous good one used to be.',
      );
    }
  }

  expect(
    fs.journal.whereType<Renamed>().where((op) => op.to == target),
    isNotEmpty,
    reason:
        '$what never arrived by rename. A rename is the only operation '
        'this design treats as all-or-nothing; anything else is a window '
        'in which the file is neither version.',
  );
}

/// Asserts the write left none of `AtomicWriter`'s working files behind.
///
/// The weaker half, and the one the old tests had on its own: it is
/// satisfied by a non-atomic write, which is why it is never the only
/// assertion in a test named "atomic".
void expectNoWorkingFiles(FakeFileStore fs, {required String target}) {
  expect(
    fs.state.files.keys.where((f) => f.startsWith('$target.')),
    isEmpty,
    reason: 'a .tmp, .bak or .bak.tmp sibling survived the write',
  );
}
