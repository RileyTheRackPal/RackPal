// AC-024's cable footage rollup by media type, with the waste factor.
// Board M3-D/3 (#154), the derivation half DR-027 §11.26.2 keeps in M3.
//
// THE THREE THINGS THIS FILE EXISTS TO MAKE UNWRITABLE:
//
//  1. **A subtotal of zero for a media type nobody has measured.** `0`
//     means "buy none" to the person reading it. The task's own first
//     line is that a subtotal with no known contributor is NULL, not
//     zero (G4, CR-114).
//  2. **A purchase quantity that includes something nobody established
//     is a pull.** Jumpers, power cords, internal links and rows whose
//     class is undetermined are excluded, and each exclusion is counted
//     rather than dropped.
//  3. **A waste factor baked into a stored length.** It is applied at
//     the rollup and the `Link` is never touched.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 9);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _cat6 = MediaTypeId('media.cat6');
const _rg6 = MediaTypeId('media.rg6');
const _unresolved = MediaTypeId('media.somebody_elses');

Len _ft(int feet) => Len(feet * 12 * Len.nmPerInch);

/// A document under construction. Deliberately small: this file needs
/// links with a media type and a length, and nothing else.
final class _Doc {
  _Doc({Permille? waste})
    : doc = RackDocument(
        id: const Uuid('doc-footage'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      ) {
    if (waste != null) doc.settings.cableWasteFactor = waste;
    doc.registries.mediaTypes[_cat6] = const MediaTypeDef(
      id: _cat6,
      displayName: 'Cat6 U/UTP',
      shortTag: 'C6',
    );
    doc.registries.mediaTypes[_rg6] = const MediaTypeDef(
      id: _rg6,
      displayName: 'RG6 quad shield',
      shortTag: 'RG6',
    );
  }

  final RackDocument doc;
  int _seq = 0;

  Uuid _mint(String prefix) => Uuid('$prefix-${_seq++}');

  Uuid room(String name) {
    final id = _mint('loc');
    doc.locations[id] = Location(
      id: id,
      kind: LocationKind.room,
      name: name,
      code: 'RM',
      order: FracIndex('a$_seq'),
      meta: _meta(),
    );
    return id;
  }

  Uuid outlet(Uuid locationId, {Len? nominalRunLength}) {
    final id = _mint('outlet');
    doc.outlets[id] = Outlet(
      id: id,
      structureBodyId: const Uuid('structure-1'),
      designation: 'O$_seq',
      locationId: locationId,
      order: FracIndex('a$_seq'),
      meta: _meta(),
      nominalRunLength: nominalRunLength,
    );
    return id;
  }
}

/// One run in the document.
///
/// A FREE FUNCTION AND NOT A METHOD, which is `schedule_test.dart`'s own
/// idiom (`_link(d, ...)`) and is not a style preference here. A test
/// that states three drops in a row calls the same receiver three times,
/// and `cascade_invocations` would then have the scenario written as a
/// `..` chain that reads nothing like the job it describes.
Uuid _run(
  _Doc d, {
  MediaTypeId media = _cat6,
  Len? cutLength,
  LinkClass linkClass = LinkClass.fieldCable,
  bool linkClassLocked = false,
  Uuid? locationId,
  Uuid? outletId,
}) {
  final id = d._mint('link');
  final where = locationId ?? d.room('Kitchen');
  d.doc.links[id] = Link(
    id: id,
    designator: 'W${d._seq.toString().padLeft(3, '0')}',
    media: media,
    order: FracIndex('a${d._seq.toString().padLeft(4, '0')}'),
    meta: _meta(),
    linkClass: linkClass,
    linkClassLocked: linkClassLocked,
    cutLength: cutLength,
    conductors: [
      Conductor(
        from: PlaceEndpoint(description: 'drop', locationId: where),
        to: const OpenEndpoint('coil'),
      ),
    ],
    structureOrigin: StructureOrigin(
      structureBodyId: const Uuid('structure-1'),
      outletId: outletId ?? const Uuid('outlet-none'),
      fieldLabel: 'K-${d._seq}',
    ),
  );
  return id;
}

CableFootageLine _lineFor(CableFootage f, MediaTypeId id) =>
    f.lines.firstWhere((l) => l.mediaId == id);

void main() {
  group('the quantity, by media type', () {
    test('two media types are two lines, each summing its own runs', () {
      final d = _Doc();
      final kitchen = d.room('Kitchen');
      _run(d, cutLength: _ft(40), locationId: kitchen);
      _run(d, cutLength: _ft(60), locationId: kitchen);
      _run(d, media: _rg6, cutLength: _ft(25), locationId: kitchen);

      final f = buildCableFootage(d.doc);
      expect(f.lines, hasLength(2));
      expect(_lineFor(f, _cat6).footage.value, _ft(100));
      expect(_lineFor(f, _rg6).footage.value, _ft(25));
      expect(f.runCount, 3);
    });

    test('the order is total and does not depend on map iteration', () {
      // §8.4: two builds of an unmodified document produce the identical
      // table. Sorted by display name, so RG6 follows Cat6.
      final d = _Doc();
      _run(d, media: _rg6, cutLength: _ft(25));
      _run(d, cutLength: _ft(40));

      final first = buildCableFootage(d.doc).lines.map((l) => l.mediaId);
      final second = buildCableFootage(d.doc).lines.map((l) => l.mediaId);
      expect(first, orderedEquals([_cat6, _rg6]));
      expect(second, orderedEquals(first));
    });

    test('a media type the document does not carry still gets a line', () {
      // Dropping it would make the takeoff quietly smaller than the
      // schedule. The buyer needs to know there are 30 ft of something
      // this document cannot name.
      final d = _Doc();
      _run(d, media: _unresolved, cutLength: _ft(30));

      final f = buildCableFootage(d.doc);
      final line = _lineFor(f, _unresolved);
      expect(line.media, isNull);
      expect(line.footage.value, _ft(30));
    });

    test('an empty project has no lines and no zeroes', () {
      final f = buildCableFootage(_Doc().doc);
      expect(f.isEmpty, isTrue);
      expect(f.runCount, 0);
      expect(f.unknownLengthCount, 0);
    });
  });

  group('G4 — a subtotal with no known contributor is NULL, not zero', () {
    test('three runs and no lengths is unknown, and says so', () {
      // The failure this whole task is about: a room whose lengths have
      // not been entered must not print as if it needed no cable.
      final d = _Doc();
      final kitchen = d.room('Kitchen');
      for (var i = 0; i < 3; i++) {
        _run(d, locationId: kitchen);
      }

      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(line.footage.isUnknown, isTrue);
      expect(line.footage.value, isNull);
      expect(line.footage.knownCount, 0);
      expect(line.footage.unknownCount, 3);
      expect(line.runCount, 3);
    });

    test('and the waste factor of an unknown subtotal is also unknown', () {
      // 10% of "we do not know" is not a number, and it must not be 0.
      final d = _Doc();
      _run(d);

      expect(_lineFor(buildCableFootage(d.doc), _cat6).withWaste, isNull);
    });

    test('some known lengths sum those and count the rest', () {
      final d = _Doc();
      final kitchen = d.room('Kitchen');
      _run(d, cutLength: _ft(40), locationId: kitchen);
      _run(d, locationId: kitchen);

      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(line.footage.value, _ft(40));
      expect(line.footage.knownCount, 1);
      expect(
        line.footage.unknownCount,
        1,
        reason:
            'a subtotal without its unknown count is a number that is '
            'quietly wrong by an unstated amount',
      );
      expect(buildCableFootage(d.doc).unknownLengthCount, 1);
    });
  });

  group('the waste factor', () {
    test("AC-024's own worked example, in whole feet", () {
      // "Cat6: 2,140 ft estimated + 10% = 2,354 ft". The default
      // `cableWasteFactor` is 100 permille, which is that 10%.
      final d = _Doc();
      final kitchen = d.room('Kitchen');
      _run(d, cutLength: _ft(2000), locationId: kitchen);
      _run(d, cutLength: _ft(140), locationId: kitchen);

      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(line.footage.value, _ft(2140));
      expect(line.withWaste, _ft(2354));
    });

    test('it is applied at the rollup and never to a stored length', () {
      final d = _Doc();
      final id = _run(d, cutLength: _ft(100));

      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(line.withWaste, _ft(110));
      expect(
        d.doc.links[id]!.cutLength,
        _ft(100),
        reason:
            'baking waste into the Link would make the sheet disagree '
            'with the tape measure it was written from',
      );
    });

    test('a project that sets none gets the subtotal back unchanged', () {
      final d = _Doc(waste: Permille.zero);
      _run(d, cutLength: _ft(100));

      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(line.withWaste, _ft(100));
      expect(buildCableFootage(d.doc).wasteFactor, Permille.zero);
    });

    test('the arithmetic is integer and loses no printed foot (CR-001)', () {
      // 333 ft + 15% is 382.95 ft. The stored value stays in nanometres
      // and nothing rounds to a foot until something prints it.
      final d = _Doc(waste: const Permille(150));
      _run(d, cutLength: _ft(333));

      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(line.withWaste!.nm, (_ft(333).nm * 1150) ~/ 1000);
      expect(line.withWaste!.nm, greaterThan(_ft(382).nm));
      expect(line.withWaste!.nm, lessThan(_ft(383).nm));
    });
  });

  group('what a purchase may not include', () {
    test('a jumper is bought by the piece, not by the foot', () {
      final d = _Doc();
      _run(d, cutLength: _ft(40));
      _run(
        d,
        cutLength: _ft(3),
        linkClass: LinkClass.jumper,
        linkClassLocked: true,
      );

      final f = buildCableFootage(d.doc);
      expect(_lineFor(f, _cat6).footage.value, _ft(40));
      expect(f.excludedJumpers, 1);
      expect(f.excludedTotal, 1);
    });

    test('a power cord and an internal link are out too, and counted', () {
      final d = _Doc();
      _run(d, cutLength: _ft(40));
      _run(
        d,
        cutLength: _ft(6),
        linkClass: LinkClass.powerCord,
        linkClassLocked: true,
      );
      _run(
        d,
        cutLength: _ft(1),
        linkClass: LinkClass.internal,
        linkClassLocked: true,
      );

      final f = buildCableFootage(d.doc);
      expect(_lineFor(f, _cat6).footage.value, _ft(40));
      expect(f.excludedPowerCords, 1);
      expect(f.excludedInternal, 1);
    });

    test('AND A RUN NOBODY HAS CLASSED IS EXCLUDED, which is the one that '
        'looks like an omission', () {
      // `kUndeterminedClassGroupTitle`'s comment: its footage "must not
      // join a room's subtotal ... it is the number an installer orders
      // cable against". Ordering IS the purpose here, so the argument is
      // stronger, not weaker.
      final d = _Doc();
      _run(d, cutLength: _ft(40));
      final id = _run(d, cutLength: _ft(500));
      d.doc.links[id]!.conductors.clear();

      final f = buildCableFootage(d.doc);
      expect(
        _lineFor(f, _cat6).footage.value,
        _ft(40),
        reason:
            '500 ft nobody has established is a pull may not reach a '
            'purchase order',
      );
      expect(f.excludedUndeterminedClass, 1);
    });
  });

  group('estimates count, and the reader is told how many', () {
    test("an outlet's nominal is a quantity and is flagged (AC-024, "
        'DR-026 §11.25.2)', () {
      // AC-024's example is explicitly an ESTIMATED total plus waste, so
      // a takeoff made before anybody pulled anything is the ordinary
      // case rather than a degraded one.
      final d = _Doc();
      final kitchen = d.room('Kitchen');
      final o = d.outlet(kitchen, nominalRunLength: _ft(70));
      _run(d, locationId: kitchen, outletId: o);

      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(line.footage.value, _ft(70));
      expect(line.estimatedCount, 1);
    });

    test('a cut length is not counted as an estimate', () {
      final d = _Doc();
      final kitchen = d.room('Kitchen');
      final o = d.outlet(kitchen, nominalRunLength: _ft(70));
      _run(d, cutLength: _ft(66), locationId: kitchen, outletId: o);

      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(line.footage.value, _ft(66));
      expect(line.estimatedCount, 0);
    });
  });

  group('the takeoff and the Pull Sheet cannot disagree', () {
    test('both read the same derivation, so a promoted row moves both', () {
      // The seam this file is built on: `cableFootageOf` takes the rows
      // `buildSchedule` produced. A length edit that changed one number
      // and not the other is what "one derivation, two views" exists to
      // prevent.
      final d = _Doc();
      final kitchen = d.room('Kitchen');
      final o = d.outlet(kitchen, nominalRunLength: _ft(70));
      final id = _run(d, locationId: kitchen, outletId: o);

      expect(_lineFor(buildCableFootage(d.doc), _cat6).footage.value, _ft(70));

      buildSetEntityProperty(
        doc: d.doc,
        id: id,
        field: LinkField.cutLength,
        to: _ft(66),
        now: _when,
        actor: 'tester',
      )!.apply(d.doc);

      final view = scheduleViewOf(d.doc, preset: SchedulePreset.pullSheet);
      final line = _lineFor(buildCableFootage(d.doc), _cat6);
      expect(view.footage.value, _ft(66));
      expect(line.footage.value, _ft(66));
      expect(line.estimatedCount, 0);
    });
  });
}
