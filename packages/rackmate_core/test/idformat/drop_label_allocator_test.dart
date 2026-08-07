// M3-D/1, #152 — the two drop labels, allocated through the ONE format
// engine (CR-044, CR-045, CR-049, DR-022).
//
// THE GAP THIS CLOSES. `ProjectSettings.outletFieldLabelFormat` and
// `.outletRackLabelFormat` have round-tripped since M0 with exactly one
// caller each, the codec — precisely where `netNameFormat` sat until M2-A
// wired it. A hand-built label ignores a project's customised pattern and
// is a wrong identifier printed on physical cable.
//
// FOUR CLAIMS:
//
//   1. both render through the project's OWN pattern, so a customised
//      scheme is honoured rather than bypassed, and both walk `SEQ` to the
//      lowest free value;
//   2. a missing required token is an OUTCOME, not an exception, and it
//      reports EVERY missing token rather than the first — which is the
//      whole reason `IdFormat.requiredTokens` exists;
//   3. the shipped `Residential CI` default really does fail on the drop
//      docs/07 §4.1 calls "first-class, encouraged", which is DR-022's
//      measurement kept as a gate rather than as a paragraph;
//   4. `SEQ` belongs to the walk: a caller who supplies one is overridden,
//      because a fixed sequence cannot find a free label.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// `LR-TV-1`'s worth of tokens: everything the shipped field pattern
/// needs. `SEQ` is deliberately absent — it is the walk's.
Map<String, Object?> _fieldValues({
  String room = 'LR',
  String? service = 'TV',
}) => {'ROOM_ABBR': room, if (service != null) 'SERVICE': service};

String _label(LabelAllocation a) => (a as LabelAllocated).label;

void main() {
  group('the field label', () {
    test("renders the corpus's own worked example", () {
      // docs/07 §5 and docs/01 §571 both print `LR-TV-1`. If this ever
      // stops matching, either the default pattern or the corpus moved.
      final result = allocateOutletFieldLabel(
        settings: ProjectSettings(),
        values: _fieldValues(),
        usedLabels: const {},
      );

      expect(_label(result), 'LR-TV-1');
    });

    test('walks SEQ to the lowest free value, not the next one', () {
      // `_lowestUnused`'s contract, stated at this call site: a project
      // whose LR-TV-2 was deleted gets it back rather than climbing.
      final result = allocateOutletFieldLabel(
        settings: ProjectSettings(),
        values: _fieldValues(),
        usedLabels: const {'LR-TV-1', 'LR-TV-3'},
      );

      expect(_label(result), 'LR-TV-2');
    });

    test('honours a project that customised its pattern', () {
      // The reason CR-045 has one engine at all. A hand-built
      // `'$room-$service-$n'` would produce `LR-TV-1` here and be wrong.
      final result = allocateOutletFieldLabel(
        settings: ProjectSettings(
          outletFieldLabelFormat: const IdFormat('{ROOM_ABBR}/{SERVICE:3}'),
        ),
        values: {'ROOM_ABBR': 'MBR', 'SERVICE': 7},
        usedLabels: const {},
      );

      expect(_label(result), 'MBR/007');
    });

    test("SEQ is the walk's, and a caller-supplied one is overridden", () {
      // A fixed SEQ would render one candidate forever and trip
      // DesignatorExhaustedException the moment it was taken.
      final result = allocateOutletFieldLabel(
        settings: ProjectSettings(),
        values: {..._fieldValues(), 'SEQ': 99},
        usedLabels: const {},
      );

      expect(_label(result), 'LR-TV-1');
    });
  });

  group('a missing token is an outcome, not an exception (DR-022)', () {
    test('THE SHIPPED DEFAULT FAILS ON A ROUGH-IN DROP, and that is the '
        'measurement DR-022 was ruled on', () {
      // docs/07 §4.1: `Service: undetermined` is "a first-class,
      // encouraged state ... at rough-in a Cat6 is just a Cat6". The
      // shipped `Residential CI` preset wraps nothing in `[...]`, so it
      // cannot render the state the product most encourages. Kept as a
      // gate so the next person to touch the default pattern learns it
      // here rather than at a sixty-drop entry session.
      final result = allocateOutletFieldLabel(
        settings: ProjectSettings(),
        values: _fieldValues(service: null),
        usedLabels: const {},
      );

      expect(result, isA<LabelTokensMissing>());
      expect((result as LabelTokensMissing).tokens, ['SERVICE']);
      expect(result.pattern, '{ROOM_ABBR}-{SERVICE}-{SEQ}');
    });

    test('reports EVERY missing token, not just the first', () {
      // The reason `IdFormat.requiredTokens` exists. `render` raises on
      // the first, so a caller repairing one learns of the next only on
      // the next attempt — sixty times, during the drill.
      final result = allocateOutletFieldLabel(
        settings: ProjectSettings(),
        values: const {},
        usedLabels: const {},
      );

      expect((result as LabelTokensMissing).tokens, ['ROOM_ABBR', 'SERVICE']);
    });

    test('a token inside an optional segment is not missing, it is '
        'omitted', () {
      // What DR-022 rejected as the ANSWER is still the engine's own
      // behaviour, and a project may customise its way into it.
      final result = allocateOutletFieldLabel(
        settings: ProjectSettings(
          outletFieldLabelFormat: const IdFormat(
            '{ROOM_ABBR}-[{SERVICE}-]{SEQ}',
          ),
        ),
        values: _fieldValues(service: null),
        usedLabels: const {},
      );

      expect(_label(result), 'LR-1');
    });

    test('nothing is written when a token is missing: no label, no '
        'fabricated placeholder', () {
      // G4. The alternative implementations both exist in the wild: a
      // blank segment, or a "TBD" that reaches a printed label.
      final result = allocateOutletFieldLabel(
        settings: ProjectSettings(),
        values: _fieldValues(service: null),
        usedLabels: const {},
      );

      expect(result, isNot(isA<LabelAllocated>()));
    });
  });

  group('the rack label', () {
    test("renders TIA-606 Class 2's worked example", () {
      // `1A-A12`, from docs/07 §5 and docs/01 §572.
      final result = allocateOutletRackLabel(
        settings: ProjectSettings(),
        values: {'FLOOR': 1, 'SPACE': 'A', 'PANEL': 'A', 'PORT': 12},
        usedLabels: const {},
      );

      expect(_label(result), '1A-A12');
    });

    test('an unbound far end reports PORT missing rather than inventing '
        'a jack (AC-018)', () {
      // FOURTEEN OF THE SIXTY drops in M3's exit criterion have unbound
      // far ends. `rackLabel` is OPTIONAL (CR-044), so the caller simply
      // does not set one; what must never happen is a rack label naming a
      // port nothing has landed on.
      final result = allocateOutletRackLabel(
        settings: ProjectSettings(),
        values: {'FLOOR': 1, 'SPACE': 'A', 'PANEL': 'A'},
        usedLabels: const {},
      );

      expect((result as LabelTokensMissing).tokens, ['PORT']);
    });

    test('a room with no floor or space number reports both', () {
      // Both are nullable on `Location` and neither is invented.
      final result = allocateOutletRackLabel(
        settings: ProjectSettings(),
        values: {'PANEL': 'A', 'PORT': 12},
        usedLabels: const {},
      );

      expect((result as LabelTokensMissing).tokens, ['FLOOR', 'SPACE']);
    });

    test('uniqueness is over the labels that EXIST, not over the drops', () {
      // `usedRackLabels` holds only the links that have one, because an
      // absent label is unknown and not a value competing for uniqueness
      // (G4, CR-114). Seeding the walk with the two that exist must not
      // make the third climb past them by accident.
      final result = allocateOutletRackLabel(
        settings: ProjectSettings(
          outletRackLabelFormat: const IdFormat('{PANEL}{SEQ:2}'),
        ),
        values: {'PANEL': 'A'},
        usedLabels: const {'A01', 'A02'},
      );

      expect(_label(result), 'A03');
    });
  });

  group('IdFormat.requiredTokens', () {
    test('is exactly the set render throws on', () {
      // Derived from the same parse as the throw site. A token inside
      // `[...]` cannot raise, so it is not required.
      expect(
        const IdFormat('{ROOM_ABBR}-[{SERVICE}-]{SEQ}').requiredTokens(),
        ['ROOM_ABBR', 'SEQ'],
      );
    });

    test('collapses a token named twice', () {
      expect(const IdFormat('{SEQ}-{SEQ}').requiredTokens(), ['SEQ']);
    });

    test('a pattern of pure literals requires nothing', () {
      expect(const IdFormat('FIXED').requiredTokens(), isEmpty);
    });

    test('and a pattern of pure literals therefore EXHAUSTS rather than '
        'spinning', () {
      // The `DesignatorExhaustedException` premise, reached from this
      // call site: a label pattern that does not vary with SEQ can
      // allocate exactly one label, and the second request must report
      // rather than hang the UI isolate.
      expect(
        () => allocateOutletFieldLabel(
          settings: ProjectSettings(
            outletFieldLabelFormat: const IdFormat('FIXED'),
          ),
          values: const {},
          usedLabels: const {'FIXED'},
        ),
        throwsA(isA<DesignatorExhaustedException>()),
      );
    });
  });
}
