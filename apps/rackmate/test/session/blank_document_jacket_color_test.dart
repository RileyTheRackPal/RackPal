// WHAT `Ctrl+N` STARTS WITH, for the shop's cable-colour convention.
//
// The convention is seeded at document CREATION and NOT defaulted on
// `ProjectSettings` — that is the whole point of the design, because
// `ProjectSettings()` is also what a decoded OLD file is built from, and
// a file whose author never chose a convention must not come back
// carrying seven entries. So there are exactly two seeding sites in the
// application: `StarterAuthor.newDocument` (covered by
// `test/starters/starter_assets_test.dart`, off the shipped bytes) and
// `buildBlankDocument`, which is this file.
//
// A SEPARATE FILE FROM `blank_document_test.dart` deliberately: this is
// about one feature of the blank document rather than about its overall
// shape, and it keeps the two independently readable.
//
// EXPECTATIONS ARE LITERALS. Asserting the result equals
// `buildDefaultJacketColorConvention()` would be the constant confirming
// itself — the shape this project has shipped before and is trying not
// to ship again.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/src/session/blank_document.dart';
import 'package:rackmate_core/rackmate_core.dart';

RackDocument _blank() => buildBlankDocument(
  now: DateTime.utc(2026, 7, 27, 10),
  appVersion: '0.1.0',
  id: const Uuid('0190e3c1-0000-7000-8000-0000000000c1'),
  rackId: const Uuid('0190e3c1-0000-7000-8000-0000000000c2'),
  // The 48-template catalog is irrelevant here and slow to build.
  catalog: const {},
);

void main() {
  test('a new project starts with the seven-colour convention', () {
    final settings = _blank().settings;
    expect(settings.jacketColorConventions.keys.map((k) => k.v).toList(), [
      'jc.yellow',
      'jc.blue',
      'jc.green',
      'jc.grey',
      'jc.white',
      'jc.red',
      'jc.black',
    ]);
    final control =
        settings.jacketColorConventions[const JacketColorId('jc.blue')]!;
    expect(control.displayName, 'Blue');
    expect(control.abbr, 'BLU');
    expect(
      control.meaning,
      'Control — touchscreen / IR balun / RS-232 balun',
    );
  });

  test('and no links, so nothing references it yet', () {
    // The honest state of this stage: the convention ships, and there is
    // no Link-creation surface until M2 for a user to point at it.
    expect(_blank().links, isEmpty);
  });

  test('two new documents get two SEPARATE map instances', () {
    // WHAT THIS CAN AND CANNOT CATCH, STATED RATHER THAN IMPLIED.
    //
    // This test used to end on `hasLength(7)` and `displayName == 'Blue'`
    // after editing a first document, with a reason string blaming "a
    // shared mutable seed map [that] would repaint every subsequent
    // project silently". It could not fail for that: `buildBlankDocument`
    // calls `.addAll(…)` INTO the `{}` that `ProjectSettings()` allocates
    // per instance, so a cached seed map still gets COPIED and the two
    // surviving assertions merely restated the first test in this file.
    // (The cached-seed mutant is caught — by
    // `rackmate_core`'s `each call returns a FRESH map`, which owns that
    // property.)
    //
    // So the assertion that carries weight here is the one that is NOT a
    // restatement: the two documents hold two different map OBJECTS. It
    // is a FORWARD guard, not a mutation-killable one — nothing in this
    // build can violate it, and the refactor it exists to stop is
    // rewriting the seeding line to hand the same map to both documents
    // (`doc.settings.jacketColorConventions = someSharedSeed;`). The
    // production shape is deliberately left as the safe one; a test is
    // not a reason to make an aliasing bug reachable.
    final first = _blank().settings.jacketColorConventions;
    final second = _blank().settings.jacketColorConventions;
    expect(identical(first, second), isFalse);

    first
      ..remove(const JacketColorId('jc.red'))
      ..[const JacketColorId('jc.blue')] = const JacketColorDef(
        displayName: 'Navy',
        abbr: 'NVY',
        color: Rgb(0x0B, 0x2E, 0x5C),
      );
    expect(first, hasLength(6));
    expect(second, hasLength(7));
    expect(second[const JacketColorId('jc.blue')]!.displayName, 'Blue');
  });

  test('a blank project survives a byte-exact round trip carrying it', () {
    // The convention is the newest thing in `settings`, so it is the
    // most likely thing to break CR-117 on a `Ctrl+N` document.
    const codec = JsonDocumentCodec();
    final bytes = codec.write(_blank());
    final decoded = codec.read(bytes);
    expect(decoded, isA<Ok<RackDocument>>());
    final reread = (decoded as Ok<RackDocument>).value;
    expect(reread.settings.jacketColorConventions, hasLength(7));
    expect(codec.write(reread), orderedEquals(bytes));
  });
}
