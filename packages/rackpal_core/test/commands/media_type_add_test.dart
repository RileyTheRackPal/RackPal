// `AddMediaTypeCommand` adds a type and never replaces one (`#935`).
//
// Its file header has said since M3-F that "revert removes the type only
// if this command is what put it there". The code did not: `apply`
// overwrote whatever held the id and `revert` removed it unconditionally,
// so an add handed an id already in use would replace a shop's own type
// and then, on undo, delete it. Every existing caller mints the id with
// `mediaTypeIdFor`, which skips registered ids, so the guard was only ever
// the caller's. That is the precondition a command must hold itself: the
// next caller is the one that forgets.
//
// The case that reaches it today is one CSV import naming the same cable
// twice with spellings that slug alike (`Plenum Speaker 14/4` and
// `plenum-speaker 14-4`): both adds are built before either applies, so
// both get one id. The second now refuses, the first spelling's type
// stands, and undo leaves the registry exactly as it found it.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _id = MediaTypeId('media.plenum_speaker_14_4');

RackDocument _blank() => RackDocument(
  id: const Uuid('doc-media-add'),
  appVersion: 'test',
  createdAt: DateTime.utc(2026, 9, 23),
  modifiedAt: DateTime.utc(2026, 9, 23),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026, 9, 23),
    updatedAt: DateTime.utc(2026, 9, 23),
    updatedBy: 'test',
  ),
);

AddMediaTypeCommand _add(String spelling) => AddMediaTypeCommand(
  id: _id,
  displayName: spelling,
  shortTag: 'SPK',
  aliases: [spelling],
);

void main() {
  test('an add over a free id adds, and its undo removes it', () {
    final doc = _blank();
    final add = _add('Plenum Speaker 14/4');

    expect(add.apply(doc), isTrue);
    expect(doc.registries.mediaTypes[_id]?.displayName, 'Plenum Speaker 14/4');

    add.revert(doc);
    expect(doc.registries.mediaTypes.containsKey(_id), isFalse);
  });

  test('an add over an id already registered REFUSES and replaces nothing', () {
    final doc = _blank();
    final first = _add('Plenum Speaker 14/4')..apply(doc);
    expect(first, isNotNull);

    final second = _add('plenum-speaker 14-4');
    expect(
      second.apply(doc),
      isFalse,
      reason: 'a refusal is how a command says it changed nothing',
    );
    expect(
      doc.registries.mediaTypes[_id]?.displayName,
      'Plenum Speaker 14/4',
      reason: 'the type that held the id is still the one there',
    );
    expect(doc.registries.mediaTypes[_id]?.aliases, ['Plenum Speaker 14/4']);
  });

  test('and undoing the refused add leaves the existing type standing', () {
    final doc = _blank();
    _add('Plenum Speaker 14/4').apply(doc);
    // `Transaction.revert` walks every child, refused or not, so a refused
    // add is reverted whenever the import that built it is undone.
    _add('plenum-speaker 14-4')
      ..apply(doc)
      ..revert(doc);

    expect(
      doc.registries.mediaTypes[_id]?.displayName,
      'Plenum Speaker 14/4',
      reason:
          'this is the defect: undo of an add that added nothing deleted '
          'the type somebody else had registered',
    );
  });

  test('the pair undoes, in the order a transaction uses, to where it '
      'began', () {
    final doc = _blank();
    final before = {...doc.registries.mediaTypes};
    final pair = [_add('Plenum Speaker 14/4'), _add('plenum-speaker 14-4')];

    // `Transaction` applies its children in order and reverts them in
    // reverse, every one of them; this is that, without the selection
    // snapshots a transaction also carries.
    void apply() {
      for (final c in pair) {
        c.apply(doc);
      }
    }

    void revert() {
      for (final c in pair.reversed) {
        c.revert(doc);
      }
    }

    apply();
    expect(doc.registries.mediaTypes[_id]?.displayName, 'Plenum Speaker 14/4');
    revert();
    expect(doc.registries.mediaTypes, before);

    // Alternation, the Command contract: apply again lands the same state.
    apply();
    expect(doc.registries.mediaTypes[_id]?.displayName, 'Plenum Speaker 14/4');
  });
}
