// LEN-A/1: the room outline, the marker beside it, and the stamp that
// keeps an older build from deleting a drawing (`#857`, DR-050 §11.49).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIRST GROUP IS ABOUT A LIST, AND THAT IS NOT A FORMALITY
// ═══════════════════════════════════════════════════════════════════════
// Dart compares a `List` by IDENTITY. `RoomOutline` is the first
// list-bearing value type in `model/`, and the last time a collection
// entered machinery built for scalars it broke four separate sites at
// once and every one failed silently: a no-op check that never skipped, a
// batch summary reading `Mixed (8 values)` over a selection that agreed
// completely, a grid setter with the same bug inline, and an alias census
// that caught itself.
//
// So equality is asserted before anything is built on it, in both
// directions, and the aliasing the constructor must prevent is asserted
// too.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 10);
const _underlayId = Uuid('0190e100-0000-7000-8000-0000000000a0');
const _otherUnderlayId = Uuid('0190e100-0000-7000-8000-0000000000a1');
const _roomId = Uuid('0190e100-0000-7000-8000-0000000000b0');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'tester');

/// A square room, four vertices, implicitly closed.
RoomOutline _square() => RoomOutline(
  underlayId: _underlayId,
  vertices: const [
    PxPt(100, 100),
    PxPt(400, 100),
    PxPt(400, 300),
    PxPt(100, 300),
  ],
);

Location _room({
  RoomOutline? outline,
  RunLengthOrigin? origin,
  Len? estimate,
}) => Location(
  id: _roomId,
  kind: LocationKind.room,
  name: 'Great Room',
  code: 'GR',
  order: const FracIndex('a0'),
  meta: _meta(),
  planOutline: outline,
  estimatedRunLengthOrigin: origin,
  estimatedRunLengthFromRack: estimate,
);

RackDocument _doc({RoomOutline? outline, RunLengthOrigin? origin, Len? est}) {
  final doc = RackDocument(
    id: const Uuid('0190e100-0000-7000-8000-000000000000'),
    appVersion: '0.6.48',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.locations[_roomId] = _room(
    outline: outline,
    origin: origin,
    estimate: est,
  );
  return doc;
}

RackDocument _reread(RackDocument doc) =>
    (_codec.read(_codec.write(doc)) as Ok<RackDocument>).value;

void main() {
  group('a List in a value type (the four-sites lesson)', () {
    test('two outlines built from equal vertices are EQUAL, which the '
        'default == would deny', () {
      expect(_square(), _square());
      expect(_square().hashCode, _square().hashCode);
    });

    test('and a different vertex is a different outline', () {
      final moved = RoomOutline(
        underlayId: _underlayId,
        vertices: const [
          PxPt(100, 100),
          PxPt(400, 100),
          PxPt(400, 301),
          PxPt(100, 300),
        ],
      );
      expect(moved, isNot(_square()));
    });

    test('ORDER IS THE SHAPE, so the same four points reordered is a '
        'different room', () {
      // Not a pedantic case: these exact four points in this exact order
      // are a bow tie rather than a rectangle. A set comparison would
      // call them the same room.
      final bowTie = RoomOutline(
        underlayId: _underlayId,
        vertices: const [
          PxPt(100, 100),
          PxPt(400, 300),
          PxPt(400, 100),
          PxPt(100, 300),
        ],
      );
      expect(bowTie, isNot(_square()));
    });

    test('an outline on another underlay is a different outline', () {
      expect(
        RoomOutline(underlayId: _otherUnderlayId, vertices: _square().vertices),
        isNot(_square()),
      );
    });

    test('a shorter outline is not equal, and does not throw comparing', () {
      expect(
        RoomOutline(
          underlayId: _underlayId,
          vertices: const [PxPt(100, 100), PxPt(400, 100), PxPt(400, 300)],
        ),
        isNot(_square()),
      );
    });

    test('the constructor COPIES, so two rooms cannot share one list', () {
      // The aliasing half of the same lesson: a constructor that stored
      // the caller's list would let editing one room's shape edit
      // another's.
      final source = <PxPt>[
        const PxPt(0, 0),
        const PxPt(10, 0),
        const PxPt(10, 10),
      ];
      final outline = RoomOutline(underlayId: _underlayId, vertices: source);
      source.add(const PxPt(0, 10));

      expect(outline.vertices, hasLength(3));
    });

    test('and the getter hands back the SAME object every time, so an '
        'alias census is not defeated by a fresh copy', () {
      // `acceptedFamilies` returned `List.unmodifiable` from its GETTER,
      // so every probe reported the field as having moved and the census
      // written against it caught itself. Copying once in the constructor
      // is what avoids that.
      final outline = _square();
      expect(identical(outline.vertices, outline.vertices), isTrue);
    });

    test('the stored list refuses to be written through', () {
      expect(
        () => _square().vertices.add(const PxPt(9, 9)),
        throwsUnsupportedError,
      );
    });
  });

  group('usable is about geometry, and unusable is held rather than '
      'refused', () {
    test('three vertices is a room and two is not', () {
      expect(_square().isUsable, isTrue);
      expect(
        RoomOutline(
          underlayId: _underlayId,
          vertices: const [PxPt(0, 0), PxPt(1, 1), PxPt(2, 0)],
        ).isUsable,
        isTrue,
      );
      for (final short in <List<PxPt>>[
        const [],
        const [PxPt(0, 0)],
        const [PxPt(0, 0), PxPt(1, 1)],
      ]) {
        expect(
          RoomOutline(underlayId: _underlayId, vertices: short).isUsable,
          isFalse,
          reason: '${short.length} vertices',
        );
      }
    });

    test('CR-093: a two-point outline READS, and comes back intact', () {
      // `PlanScale` settled this for a calibration whose points coincide:
      // the decoder must read whatever is on disk, so this is reported
      // rather than thrown and never silently dropped. Dropping it would
      // be an edit to somebody's file that nothing told them about.
      final doc = _doc(
        outline: RoomOutline(
          underlayId: _underlayId,
          vertices: const [PxPt(5, 5), PxPt(6, 6)],
        ),
      );
      final back = _reread(doc).locations[_roomId]!.planOutline!;

      expect(back.vertices, hasLength(2));
      expect(back.isUsable, isFalse);
    });
  });

  group('the wire', () {
    test('an outline round-trips, vertices and order intact', () {
      final back = _reread(_doc(outline: _square())).locations[_roomId]!;

      expect(back.planOutline, _square());
      expect(
        back.planOutline!.vertices.map((v) => '${v.px},${v.py}').toList(),
        ['100,100', '400,100', '400,300', '100,300'],
        reason: 'the order is the shape, so the format must preserve it',
      );
    });

    test('CR-117: write(read(bytes)) == bytes with an outline on it', () {
      final bytes = _codec.write(_doc(outline: _square()));
      expect(_codec.write(_reread(_doc(outline: _square()))), bytes);
    });

    test('ABSENT WHEN NULL, so every document written before this field '
        'existed re-encodes byte for byte (G4)', () {
      final json = _codec.write(_doc());
      final text = String.fromCharCodes(json);

      expect(text, isNot(contains('planOutline')));
      expect(text, isNot(contains('estimatedRunLengthOrigin')));
    });

    test('the marker round-trips, both values', () {
      for (final origin in RunLengthOrigin.values) {
        final back = _reread(
          _doc(origin: origin, est: const Len(12000000000)),
        ).locations[_roomId]!;
        expect(back.estimatedRunLengthOrigin, origin, reason: origin.name);
        expect(back.estimatedRunLengthFromRack, const Len(12000000000));
      }
    });

    test('and an absent marker stays absent rather than becoming typed', () {
      // The G4 case. A default of `typed` would claim somebody entered a
      // figure in every document written before this field existed.
      final back = _reread(
        _doc(est: const Len(9000000000)),
      ).locations[_roomId]!;
      expect(back.estimatedRunLengthOrigin, isNull);
      expect(back.estimatedRunLengthFromRack, const Len(9000000000));
    });
  });

  group('minReaderVersion: an outline is a drawing, not a number', () {
    int stampOf(RackDocument doc) => documentMinReaderVersion(doc);

    test('a document with an outline stamps 5', () {
      expect(stampOf(_doc(outline: _square())), kPlanMinReaderVersion);
    });

    test('and one with neither an outline nor a pin stamps the ordinary '
        'version, so this predicate is not simply always 5', () {
      // The control. Without it the case above passes against a predicate
      // that returned 5 unconditionally.
      expect(stampOf(_doc()), kMinReaderVersion);
      expect(kMinReaderVersion, isNot(kPlanMinReaderVersion));
    });

    test('THE UNDERLAY CHECK DOES NOT COVER IT, WHICH IS WHY THE OUTLINE '
        'HAS ITS OWN', () {
      // LOAD-BEARING. An outline names an underlay, so while one is
      // present the first line of the predicate already returns 5 and an
      // outline-specific check looks redundant. It is redundant only
      // while `RemovePlanUnderlayCommand` clears what it orphans, which
      // is an invariant of the COMMANDS and not of the format: CR-093
      // lets a hand-edited file carry exactly this document.
      //
      // If this ever fails, an older build opens that file read-write and
      // deletes the room outline on save, which is DR-019 §11.18.1's
      // hazard exactly.
      final doc = _doc(outline: _square());
      expect(doc.underlays, isEmpty, reason: 'the case is the orphan');
      expect(stampOf(doc), kPlanMinReaderVersion);
    });

    test('the marker alone does NOT stamp 5, because it is a number '
        'somebody can retype', () {
      // The line this predicate draws, applied to this chapter's own two
      // fields: `riseAllowance` is excluded on exactly this test and the
      // marker is the same kind of thing. Only the drawing counts.
      expect(
        stampOf(_doc(origin: RunLengthOrigin.typed, est: const Len(1))),
        kMinReaderVersion,
      );
    });
  });
}
