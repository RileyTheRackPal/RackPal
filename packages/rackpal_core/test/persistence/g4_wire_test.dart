// #947, item 2: the codec read for G4.
//
// G4 and CR-114: `null` means UNKNOWN, everywhere, and unknown is an ABSENT
// KEY on the wire, never an explicit `null` (canon §9700, §15067). And its
// other half: `0` is a MEASUREMENT, so a measured zero must survive a save
// as a `0` and never collapse into "unknown".
//
// Until this file the rule was asserted field by field, in whichever test
// shipped that field (pathway_designator_codec_test, derived_from_wire_test,
// ...), which covers the fields somebody remembered. This walks every
// inspector-editable field in `SetEntityPropertyCommand`'s tables, on real
// entities from `whole_house.rppj`, so a field added to a table and
// forgotten in the codec fails here without anybody having to name it.
//
// The tables are typed per field and their `all` lists erase the type, so
// the value is set dynamically and a `TypeError` means "not that kind of
// field" (a non-nullable field refuses null; a String field refuses 0).
// The census test at the bottom asserts both passes actually ran over
// fields, so a table that stopped yielding any cannot pass vacuously.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

final Uint8List _houseBytes = File(
  '../../apps/rackpal/assets/starters/whole_house.rppj',
).readAsBytesSync();

RackDocument _read(Uint8List bytes) => switch (_codec.read(bytes)) {
  Ok(:final value) => value,
  final other => fail('did not decode: $other'),
};

/// Every path in [node] whose value is an explicit JSON `null`.
List<String> _nullsIn(Object? node, [String at = '']) => switch (node) {
  null => [at],
  final Map<String, Object?> map => [
    for (final e in map.entries) ..._nullsIn(e.value, '$at/${e.key}'),
  ],
  final List<Object?> list => [
    for (var i = 0; i < list.length; i++) ..._nullsIn(list[i], '$at[$i]'),
  ],
  _ => const [],
};

/// One table: its fields, and how to find the entity a field is set on in
/// a given document (the first one of that kind in `whole_house`).
typedef _Table = ({
  String name,
  List<EntityField<Object?, Object?>> fields,
  Object Function(RackDocument doc) first,
});

final List<_Table> _tables = [
  (
    name: 'Outlet',
    fields: OutletField.all,
    first: (doc) => doc.outlets.values.first,
  ),
  (
    name: 'StructureBody',
    fields: StructureBodyField.all,
    first: (doc) => doc.structures.values.first,
  ),
  (name: 'Rack', fields: RackField.all, first: (doc) => doc.racks.values.first),
  (
    name: 'DeviceInstance',
    fields: DeviceField.all,
    first: (doc) => doc.devices.values.first,
  ),
  (name: 'Link', fields: LinkField.all, first: (doc) => doc.links.values.first),
  (
    name: 'Location',
    fields: LocationField.all,
    first: (doc) => doc.locations.values.first,
  ),
  (
    name: 'Pathway',
    fields: PathwayField.all,
    first: (doc) => doc.pathways.values.first,
  ),
];

/// Sets [field] to [value] on the first entity of [table] in [doc], or
/// returns false when the field's type refuses the value.
bool _trySet(RackDocument doc, _Table table, Object field, Object? value) {
  try {
    // The tables erase each field's type in `all`, so the set is dynamic
    // and the field's own parameter type is what accepts or refuses.
    // ignore: avoid_dynamic_calls
    (field as dynamic).set(table.first(doc), value);
    return true;
    // Caught ON PURPOSE: a TypeError here IS the answer "this field does
    // not take that value", which is how the pass tells field kinds apart.
    // ignore: avoid_catching_errors
  } on TypeError {
    return false;
  }
}

Object? _get(RackDocument doc, _Table table, Object field) =>
    // Dynamic for `_trySet`'s reason: `all` erases the field's type.
    // ignore: avoid_dynamic_calls
    (field as dynamic).get(table.first(doc));

/// The two zeros a measured field can take: a count, or a length.
const List<Object?> _zeros = [0, Len.zero];

void main() {
  final cleared = <String>[];
  final zeroed = <String>[];

  group('G4 on the wire, for every inspector field (#947)', () {
    for (final table in _tables) {
      for (final field in table.fields) {
        final name = '${table.name}.${(field as dynamic).key}';

        test('$name cleared: no JSON null, reads back unknown, re-saves '
            'byte for byte', () {
          final doc = _read(_houseBytes);
          if (!_trySet(doc, table, field, null)) return; // non-nullable
          cleared.add(name);

          final bytes = _codec.write(doc);
          final tree = jsonDecode(utf8.decode(bytes));
          expect(
            _nullsIn(tree),
            isEmpty,
            reason: 'unknown is an ABSENT key, never an explicit null (G4)',
          );
          final back = _read(bytes);
          expect(_get(back, table, field), isNull, reason: 'still unknown');
          expect(_codec.write(back), bytes, reason: 'CR-117');
        });

        test('$name set to a measured zero: the 0 survives, and is not '
            'read back as unknown', () {
          for (final zero in _zeros) {
            final doc = _read(_houseBytes);
            if (!_trySet(doc, table, field, zero)) continue;
            zeroed.add(name);

            final back = _read(_codec.write(doc));
            expect(
              _get(back, table, field),
              zero,
              reason: 'a measured zero is a value, not an absence (G4)',
            );
            return;
          }
        });
      }
    }

    // THE PASSES ABOVE RETURN QUIETLY for a field that refuses the value,
    // so a table that stopped yielding any nullable or numeric field would
    // pass with nothing checked. MEASURED when written, 2026-09-25: 31
    // nullable fields cleared, and 12 measured fields zeroed (mount height,
    // the four link lengths, splice count, rack depth and weight capacity,
    // floor numbers, rise allowance, a pathway's and an outlet's nominal
    // run). A floor, since a new field should raise it, not fail it.
    test('both passes ran over real fields', () {
      expect(cleared.length, greaterThanOrEqualTo(31), reason: '$cleared');
      expect(zeroed.length, greaterThanOrEqualTo(12), reason: '$zeroed');
    });
  });

  group('a file that DOES carry an explicit null (hand-edited, or another '
      'writer)', () {
    test('reads it as unknown, and re-saves it as an absent key', () {
      // Liberal in what it accepts: `asIntOrNull` and its siblings read an
      // explicit null exactly as an absent key. What it writes back is the
      // absent key, so CR-117's byte identity holds for files RackPal
      // wrote, and a foreign null is normalised rather than preserved.
      final tree = jsonDecode(utf8.decode(_houseBytes)) as Map<String, Object?>;
      final document = tree['document']! as Map<String, Object?>;
      final links = document['links']! as Map<String, Object?>;
      final link = links.values.first! as Map<String, Object?>;
      expect(link.containsKey('routedLengthNm'), isTrue, reason: 'premise');
      link['routedLengthNm'] = null;

      final doc = _read(Uint8List.fromList(utf8.encode(jsonEncode(tree))));
      expect(doc.links.values.first.routedLength, isNull);

      final rewritten = jsonDecode(utf8.decode(_codec.write(doc)));
      expect(_nullsIn(rewritten), isEmpty);
    });
  });
}
