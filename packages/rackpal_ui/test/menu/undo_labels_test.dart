// DR-159 §11.158.7 — every `LabelKey` has a menu label, and there is no
// fallback that could hide a missing one.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY A GATE AND NOT A DERIVATION
// ═══════════════════════════════════════════════════════════════════════
// De-camel-casing the enum name is one line. It is also wrong for exactly
// the values that were split BECAUSE the obvious wording names the wrong
// act: `commitPortSort` would read "Commit Port Sort", `clearRoomEstimate`
// would read "Clear Room Estimate" where the enum's own comment argues
// the menu must not name the opposite act, and `removeTemplateFromProject`
// would read "Remove Template From Project".
//
// So the map is explicit, and this file is what makes adding a `LabelKey`
// without naming it a red build instead of a silent hole. Same shape as
// `registry_parity.py` and the AC-051 pair gate.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  group('DR-159 §11.158.7: the map covers the enum', () {
    test('every LabelKey value has a label', () {
      final missing = [
        for (final key in LabelKey.values)
          if (!kUndoLabels.containsKey(key)) key.name,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'these command kinds would print a bare "Undo" in the Edit '
            'menu, which is the surface docs/03 §13.3 specified and '
            'DR-159 built. Name them in undo_labels.dart; do NOT add a '
            'fallback, because a default is a hole the next LabelKey '
            'falls into silently.',
      );
    });

    test('and names nothing the enum does not have', () {
      // THE OTHER DIRECTION, which a containsKey check cannot see. A
      // label for a deleted value is a line nobody can act on, and it
      // makes the map read as larger coverage than it has.
      final names = {for (final key in LabelKey.values) key};
      final orphans = [
        for (final key in kUndoLabels.keys)
          if (!names.contains(key)) key.name,
      ];
      expect(orphans, isEmpty, reason: 'delete these rows');
    });

    test('the map is the size of the enum, counted rather than asserted', () {
      // ANTI-VACUITY. The two checks above both pass over an EMPTY enum
      // and an empty map, which is what a broken import or a renamed
      // symbol looks like.
      expect(
        LabelKey.values.length,
        greaterThanOrEqualTo(100),
        reason:
            'LabelKey stopped resolving. Fix the import rather than '
            'lowering this.',
      );
      expect(kUndoLabels, hasLength(LabelKey.values.length));
    });
  });

  group('the labels read correctly after the word "Undo"', () {
    test('no label is empty, or ends in a full stop, or starts lower case', () {
      // §13.3's own example fixes the shape: "Undo Move device". The verb
      // is capitalised because it starts the phrase; nothing terminates.
      final bad = <String>[];
      for (final entry in kUndoLabels.entries) {
        final v = entry.value;
        if (v.isEmpty) bad.add('${entry.key.name}: empty');
        if (v.endsWith('.')) bad.add('${entry.key.name}: ends in a stop');
        if (v[0] != v[0].toUpperCase()) {
          bad.add('${entry.key.name}: starts lower case');
        }
        if (v.trim() != v) bad.add('${entry.key.name}: padded');
      }
      expect(bad, isEmpty);
    });

    test('no two commands share a label where the enum split them', () {
      // THE SPLIT VALUES ARE THE POINT OF THE MAP. `setRoomEstimate` and
      // `clearRoomEstimate` are two values precisely so the menu does not
      // name the opposite act; giving them one string would undo the
      // split in the one place it was made for.
      const pairs = <(LabelKey, LabelKey)>[
        (LabelKey.setRoomEstimate, LabelKey.clearRoomEstimate),
        (LabelKey.setPlanPin, LabelKey.movePlanPin),
        (LabelKey.setPlanPin, LabelKey.clearPlanPin),
        (LabelKey.drawRoomOutline, LabelKey.reshapeRoomOutline),
        (LabelKey.drawRoomOutline, LabelKey.clearRoomOutline),
        (LabelKey.acknowledgeFinding, LabelKey.unacknowledgeFinding),
        (LabelKey.commitPortSort, LabelKey.reorderPorts),
        (LabelKey.saveTemplateToProject, LabelKey.removeTemplateFromProject),
        (LabelKey.pairPassthrough, LabelKey.unpairPassthrough),
        (LabelKey.addGang, LabelKey.removeGang),
      ];
      for (final (a, b) in pairs) {
        expect(
          kUndoLabels[a],
          isNot(kUndoLabels[b]),
          reason:
              '${a.name} and ${b.name} are two LabelKey values because the '
              'menu must tell them apart. One string undoes that.',
        );
      }
    });
  });

  group('what the menu actually renders', () {
    test('a named key reads "Undo Move device"', () {
      expect(
        undoMenuLabel(LabelKey.moveDevice.name),
        'Undo Move device',
        reason: "docs/03 §13.3's own worked example, verbatim",
      );
      expect(redoMenuLabel(LabelKey.moveDevice.name), 'Redo Move device');
    });

    test('an EMPTY stack reads the bare verb', () {
      expect(undoMenuLabel(null), 'Undo');
      expect(redoMenuLabel(null), 'Redo');
    });

    test('an unknown key reads the bare verb rather than a guess', () {
      // It cannot happen while the gate above is green. What matters is
      // that if it ever does, the menu says "Undo" and not a mangled
      // identifier that reads like a bug report to the user.
      expect(undoMenuLabel('someKeyNobodyNamed'), 'Undo');
      expect(undoLabelFor(LabelKey.moveDevice), 'Move device');
    });

    test('the newest commands are named, not just the M0 ones', () {
      // A canary on the habit this gate exists to enforce: the two most
      // recently added LabelKey values.
      expect(
        undoMenuLabel(LabelKey.removeTemplateFromProject.name),
        'Undo Remove template',
      );
      expect(
        undoMenuLabel(LabelKey.clearRoomEstimate.name),
        'Undo Clear room estimate',
      );
    });
  });
}
