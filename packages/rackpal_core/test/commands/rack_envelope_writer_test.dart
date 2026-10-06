// DR-239 §11.238.1 (`#923`, ENV-2): the envelope has a writer.
//
// `#923`'s DONE clause, the half this package can prove: a value entered
// through the property command survives a save and a reload. For months
// these fields serialized with nothing able to set them, the fourth
// instance of the `Placement.locked` shape (§11.185.0).
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _rackId = Uuid('rack-env');
final _when = DateTime.utc(2026, 10, 6);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'seed');

Len _mm(int mm) => Len(mm * 1000000);

RackDocument _doc() =>
    RackDocument(
        id: const Uuid('doc-env'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      )
      ..racks[_rackId] = Rack(
        id: _rackId,
        name: 'Closet',
        designator: 'RK-1',
        heightU: 42,
        order: const FracIndex('a0'),
        meta: _meta(),
      );

void _set<T>(RackDocument doc, EntityField<Rack, T> field, T to) =>
    SetEntityPropertyCommand<Rack, T>(
      id: _rackId,
      field: field,
      from: field.get(doc.racks[_rackId]!),
      to: to,
      now: _when,
      actor: 'tester',
    ).apply(doc);

const _codec = JsonDocumentCodec();

Rack _reloaded(RackDocument doc) {
  final read = _codec.read(_codec.write(doc));
  expect(read, isA<Ok<RackDocument>>());
  return (read as Ok<RackDocument>).value.racks[_rackId]!;
}

void main() {
  test('EVERY ENVELOPE FIELD, ENTERED THROUGH THE COMMAND, survives a save '
      'and a reload', () {
    final doc = _doc();
    _set(doc, RackField.overallWidth, _mm(600));
    _set(doc, RackField.overallDepth, _mm(1000));
    _set(doc, RackField.overallHeight, _mm(2000));
    _set(doc, RackField.ownWeight, const Mass(68 * 1000000000));
    _set(doc, RackField.hasFrontDoor, true);
    _set(doc, RackField.hasRearDoor, true);
    _set(doc, RackField.frontRailClearance, _mm(75));
    _set(doc, RackField.frontDoorClearance, _mm(600));
    _set(doc, RackField.rearRailClearance, _mm(120));
    _set(doc, RackField.rearDoorClearance, _mm(550));

    final back = _reloaded(doc);
    expect(
      [
        back.overallWidth,
        back.overallDepth,
        back.overallHeight,
        back.ownWeight,
        back.hasFrontDoor,
        back.hasRearDoor,
        back.frontRailClearance,
        back.frontDoorClearance,
        back.rearRailClearance,
        back.rearDoorClearance,
      ],
      [
        _mm(600),
        _mm(1000),
        _mm(2000),
        const Mass(68 * 1000000000),
        true,
        true,
        _mm(75),
        _mm(600),
        _mm(120),
        _mm(550),
      ],
    );
  });

  test('UNDO OF A CLEARANCE LANDS THE SAVED BYTES EXACTLY (CR-117)', () {
    final doc = _doc();
    final before = _codec.write(doc);
    final cmd = SetEntityPropertyCommand<Rack, Len?>(
      id: _rackId,
      field: RackField.frontRailClearance,
      from: null,
      to: _mm(75),
      now: DateTime.utc(2026, 10, 7),
      actor: 'tester',
    )..apply(doc);
    expect(doc.racks[_rackId]!.frontRailClearance, _mm(75));
    cmd.revert(doc);
    expect(_codec.write(doc), before);
  });
}
