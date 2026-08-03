// The blank project (`Ctrl+N`) and docs/04 §9's New-rack dialog must agree
// about what a new rack is.
//
// blank_document.dart's header has always said the seeded rack is "a
// DEFAULT rather than a fabrication … When the New-rack dialog lands, this
// becomes its default row and the seeding moves there." The dialog has now
// landed and it does open on that row — but the two constants live in
// different packages (`kBlankProjectRackHeightU` here,
// `NewRackDialog.defaultHeightU` in `rackmate_ui`, which cannot import
// this app), so nothing but a test can hold them together.
//
// WHY THIS IS WORTH A TEST RATHER THAN A COMMENT. Both numbers are 42
// because M1's exit criterion says 42, and the promise the header makes —
// that `Ctrl+N` hands you exactly what the dialog would have created — is
// only true while they match. A silent divergence would leave the app
// giving new users one thing and creating another, with no symptom
// anywhere.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/src/session/blank_document.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

void main() {
  test(
    'the blank project seeds the height the New-rack dialog defaults to',
    () {
      expect(kBlankProjectRackHeightU, NewRackDialog.defaultHeightU);
      // Stated as a literal too, because "they match each other" is also
      // true of two constants that have both drifted to 24.
      expect(kBlankProjectRackHeightU, 42);
    },
  );

  test('and the rack it seeds is the same shape the dialog would build with '
      'no preset chosen', () {
    final now = DateTime.utc(2026, 7, 27);
    final seeded = buildBlankDocument(
      now: now,
      appVersion: '0.1.0',
      id: const Uuid('blank-doc'),
      rackId: const Uuid('blank-rack'),
    ).racks.values.single;

    // What `buildAddRackCommand` produces for the dialog's default row.
    final empty = RackDocument(
      id: const Uuid('for-command'),
      appVersion: '0.1.0',
      createdAt: now,
      modifiedAt: now,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'local'),
    );
    final built =
        (buildAddRackCommand(
                  doc: empty,
                  name: 'Rack 1',
                  heightU: NewRackDialog.defaultHeightU,
                  now: now,
                  actor: 'local',
                )
                as AddRackReady)
            .command
          ..apply(empty);
    final created = empty.racks.values.single;

    // EVERY COMPARISON IS AGAINST A LITERAL, not against the other side.
    // Three of these used to read `expect(created.X, seeded.X)` for fields
    // NEITHER producer sets — `ruNumbering`, `mirrorRearElevation`,
    // `locationId` — so both sides read `Rack`'s own constructor default and
    // the assertion compared a default to itself. Verified by mutation:
    // changing `Rack`'s defaults to `RuNumbering.topDown` and
    // `mirrorRearElevation: false` left this test green while
    // `packages/rackmate_core/test/rack_commands_test.dart`'s literal-valued
    // case correctly failed. A test whose two sides move together cannot
    // report that they moved.
    for (final rack in [created, seeded]) {
      expect(rack.heightU, 42);
      expect(rack.designator, 'RK-1');
      expect(rack.order.v, 'a0');
      expect(rack.formFactor, RackFormFactor.floorEnclosure);
      expect(rack.widthClass, RackWidthClass.eia19);
      expect(rack.railType, RailType.tapped10_32);
      expect(rack.ruNumbering, RuNumbering.bottomUpFromOne);
      expect(rack.mirrorRearElevation, isTrue);
      expect(rack.usableDepth, isNull);
      expect(rack.weightCapacity, isNull);
      expect(rack.locationId, isNull);
    }
    // NAME is the one field the dialog does not default: the user types it,
    // while `Ctrl+N` seeds `rackName`'s own default. The literal above is
    // what this test fed the command, so this asserts that `Ctrl+N`'s seeded
    // name is still the one the dialog would have produced for it — the last
    // cross-producer check left, and the only one that can move without
    // either constructor default moving with it.
    expect(built.name, 'Rack 1');
    expect(seeded.name, 'Rack 1');
  });
}
