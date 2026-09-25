// #948 (AC-014). The first line-coverage measurement this repository took
// (2026-09-24) found two of the eight `mergeWith` overrides that no test
// had ever executed, and one command whose undo nothing had checked.
//
// A MERGE IS WHERE AN UNDO LIES QUIETLY. Two edits inside the window become
// one stack entry, built as a FRESH command that never had `apply()` called
// on it, so its before-values are whatever the merge copied across. Copy
// the second edit's `from` instead of the first's, or drop the meta triple,
// and one undo lands on a state the user never had, with every assertion
// about the merged command's own fields still passing.
//
// So every case here asserts the ARTIFACT: the saved bytes after the edits
// and ONE undo equal the saved bytes before the first edit. The only key
// excluded is the envelope's `sequence`, which CR-094 advances on every
// commit AND every undo, so it differs by design.

import 'dart:convert';
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _fixed = DateTime.utc(2026, 9, 24, 12);

/// The richest starter, decoded fresh. Run from the package directory.
RackDocument _house() {
  final bytes = File(
    '../../apps/rackpal/assets/starters/whole_house.rppj',
  ).readAsBytesSync();
  return switch (_codec.read(bytes)) {
    Ok(:final value) => value,
    final other => fail('whole_house.rppj did not decode: $other'),
  };
}

/// The document as saved, minus the one key an undo moves on purpose.
Map<String, Object?> _saved(RackDocument doc) {
  final root =
      jsonDecode(utf8.decode(_codec.write(doc))) as Map<String, Object?>;
  return root..remove('sequence');
}

void main() {
  group('RenameEntityCommand.mergeWith', () {
    test('three renames in the window are ONE undo, and it restores the '
        'name AND the meta the first rename overwrote', () {
      final doc = _house();
      final device = doc.devices.values.first;
      final original = device.name;
      final before = _saved(doc);
      final controller = DocumentController(doc, clock: FixedClock(_fixed));

      var from = original;
      for (final to in ['A', 'Am', 'Amp 9']) {
        controller.run(
          RenameEntityCommand(
            targetKind: RenameTargetKind.device,
            id: device.id,
            from: from,
            to: to,
            now: _fixed,
            actor: 'typist',
          ),
        );
        from = to;
      }
      expect(doc.devices[device.id]!.name, 'Amp 9');

      controller.undoLast();

      expect(
        doc.devices[device.id]!.name,
        original,
        reason: 'one undo undoes the whole run, not only its last keystroke',
      );
      expect(_saved(doc), before);
    });

    test('a rename of a DIFFERENT device does not merge into it', () {
      final doc = _house();
      final [first, second, ...] = doc.devices.values.toList();
      final controller = DocumentController(doc, clock: FixedClock(_fixed))
        ..run(
          RenameEntityCommand(
            targetKind: RenameTargetKind.device,
            id: first.id,
            from: first.name,
            to: 'One',
            now: _fixed,
            actor: 'typist',
          ),
        );
      final afterFirst = _saved(doc);
      controller
        ..run(
          RenameEntityCommand(
            targetKind: RenameTargetKind.device,
            id: second.id,
            from: second.name,
            to: 'Two',
            now: _fixed,
            actor: 'typist',
          ),
        )
        ..undoLast();

      expect(_saved(doc), afterFirst);
    });
  });

  group('SetRackHeightCommand.mergeWith', () {
    test('three height steps in the window are ONE undo, back to the '
        'original height and meta', () {
      final doc = _house();
      final rack = doc.racks.values.first;
      final original = rack.heightU;
      final before = _saved(doc);
      final controller = DocumentController(doc, clock: FixedClock(_fixed));

      var from = original;
      for (final to in [original + 1, original + 2, original + 3]) {
        controller.run(
          SetRackHeightCommand(
            id: rack.id,
            fromHeightU: from,
            toHeightU: to,
            now: _fixed,
            actor: 'spinner',
          ),
        );
        from = to;
      }
      expect(doc.racks[rack.id]!.heightU, original + 3);

      controller.undoLast();

      expect(doc.racks[rack.id]!.heightU, original);
      expect(_saved(doc), before);
    });
  });

  group('SetZeroUSpanCommand', () {
    test('undo restores the span byte for byte, and redo lands where the '
        'first apply did', () {
      final doc = _house();
      final device = doc.devices.values.firstWhere(
        (d) => d.placement is ZeroUPlacement,
        orElse: () => fail('whole_house has no zero-U device'),
      );
      final before = _saved(doc);
      final controller = DocumentController(doc, clock: FixedClock(_fixed));
      final planned = planSetZeroUSpan(
        doc: doc,
        id: device.id,
        span: const Len(6 * Len.nmPerInch),
        now: _fixed,
        actor: 'test',
      );
      final command = switch (planned) {
        ZeroUReady(:final command) => command,
        ZeroURefused(:final reason) => fail('refused: $reason'),
      };

      controller.run(command);
      final applied = _saved(doc);
      expect(applied, isNot(before), reason: 'the premise: it changed');

      controller.undoLast();
      expect(_saved(doc), before);

      controller.redoLast();
      expect(_saved(doc), applied);
    });
  });
}
