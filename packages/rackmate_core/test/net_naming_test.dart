// CR-049 — net names come out of the ONE format engine, on link creation.
//
// WHICH FIELD, AND WHY IT IS NOT OBVIOUS. `Net.designator`'s doc comment
// in `net.dart` says `"N012"`, and `Net.name`'s says only "generated,
// editable, never load-bearing" — so the model reads as though the
// N-format belongs on `designator`. It does not. CR-049's ruling is
// explicit: "`Net.name` is auto-filled from `ProjectSettings.netNameFormat`
// and may be overridden". The `N012` on `designator` comes from
// `design-data-model.md §2.9`, one of the two SOURCES CR-049 exists to
// reconcile, not from the ruling that reconciled them. This file pins the
// ruling's reading so the next person does not have to re-derive it from
// a comment that disagrees.
//
// THE OTHER TRAP is `designatorPad`. It exists because the DEVICE pattern
// `{TYPE_PREFIX}{SEP}{SEQ}` carries no width of its own. `N{SEQ:3}` does,
// so applying the pad here pads twice and silently turns `N001` into
// `N0001` on any project that set it — a project setting that has nothing
// to do with nets changing every net name in the document.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 7, 28);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-nn'),
  appVersion: '0.1.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: _meta(),
);

void _net(RackDocument doc, String id, String name) {
  doc.nets[Uuid(id)] = Net(
    id: Uuid(id),
    name: name,
    signalFamily: const SignalFamilyId('structure.undetermined'),
    meta: _meta(),
  );
}

void main() {
  group('allocateNetName', () {
    test('the first net is N001 — the format engine, not a concatenation', () {
      expect(
        allocateNetName(settings: ProjectSettings(), usedNames: const {}),
        'N001',
      );
    });

    test('takes the LOWEST unused, filling a gap rather than appending', () {
      expect(
        allocateNetName(
          settings: ProjectSettings(),
          usedNames: const {'N001', 'N003'},
        ),
        'N002',
        reason:
            'the device allocator searches for the lowest unused positive '
            'integer; a net allocator that tracked a high-water mark would '
            'diverge from it the first time a link was deleted',
      );
    });

    test('honours a project that customised the pattern', () {
      final settings = ProjectSettings()
        ..netNameFormat = const IdFormat('NET{SEQ}');
      expect(
        allocateNetName(settings: settings, usedNames: const {'NET1'}),
        'NET2',
      );
    });

    test('DESIGNATORPAD IS NOT APPLIED — the double-pad trap', () {
      // `designatorPad` is the DEVICE pattern's width knob. `N{SEQ:3}`
      // carries its own `:3`.
      //
      // THE PAD MUST EXCEED THE TOKEN WIDTH TO PROVE ANYTHING. At
      // `designatorPad = 2` the two implementations AGREE — pre-padding to
      // "01" and then letting `{SEQ:3}` widen it to "001" lands on exactly
      // the right answer, so a test at 2 passes whether or not the guard
      // exists. Five is past `:3`, where pre-padding survives into the
      // output and the bug becomes visible.
      final settings = ProjectSettings()..designatorPad = 5;
      expect(
        allocateNetName(settings: settings, usedNames: const {}),
        'N001',
        reason:
            'applying the device pad here gives N00001 and renames every '
            'net in a project whose device designators happen to be '
            'zero-padded — a setting about devices silently rewriting nets',
      );
    });
  });

  group('allocateNetNameFor', () {
    test('reads the names already in the document', () {
      final doc = _doc();
      _net(doc, 'n1', 'N001');
      _net(doc, 'n2', 'N002');
      expect(allocateNetNameFor(doc), 'N003');
    });

    test('an empty document starts at N001', () {
      expect(allocateNetNameFor(_doc()), 'N001');
    });

    test('a user-renamed net does not block the sequence', () {
      // CR-049 makes the name editable, so a renamed net simply stops
      // occupying its generated slot.
      final doc = _doc();
      _net(doc, 'n1', 'Living room ARC');
      expect(allocateNetNameFor(doc), 'N001');
    });
  });

  group('link creation names its implicit Net', () {
    test('AddLinkCommand writes the allocated name, not an empty string', () {
      final doc = _doc();
      AddLinkCommand(
        designator: 'W001',
        netName: allocateNetNameFor(doc),
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a0'),
        now: _when,
        actor: 'test',
        id: const Uuid('lnk-1'),
        netId: const Uuid('net-1'),
      ).apply(doc);

      expect(
        doc.nets[const Uuid('net-1')]!.name,
        'N001',
        reason:
            'this minted Net(name: "") before M2-A item 3 — the schedule '
            'and DR-001 net labels both render this string',
      );
    });

    test('two links in a row get N001 then N002', () {
      final doc = _doc();
      for (var i = 1; i <= 2; i++) {
        AddLinkCommand(
          designator: 'W00$i',
          netName: allocateNetNameFor(doc),
          media: const MediaTypeId('media.cat6_utp'),
          order: const FracIndex('a0'),
          now: _when,
          actor: 'test',
          id: Uuid('lnk-$i'),
          netId: Uuid('net-$i'),
        ).apply(doc);
      }
      expect(
        doc.nets.values.map((n) => n.name).toList()..sort(),
        ['N001', 'N002'],
      );
    });

    test('revert frees the name for the next allocation', () {
      final doc = _doc();
      final cmd = AddLinkCommand(
        designator: 'W001',
        netName: allocateNetNameFor(doc),
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a0'),
        now: _when,
        actor: 'test',
        id: const Uuid('lnk-1'),
        netId: const Uuid('net-1'),
      )..apply(doc);
      expect(allocateNetNameFor(doc), 'N002');

      cmd.revert(doc);
      expect(
        allocateNetNameFor(doc),
        'N001',
        reason:
            'the Net went with the Link, so its name is free again — an '
            'allocator holding a high-water mark would leak N001 forever',
      );
    });

    test('REDO REUSES THE ORIGINAL NAME — it does not re-allocate', () {
      // The name is captured at construction, like the ids. If `apply()`
      // allocated instead, a redo would see a different set of used names
      // and mint a different name than the run being redone.
      final doc = _doc();
      final cmd = AddLinkCommand(
        designator: 'W001',
        netName: allocateNetNameFor(doc),
        media: const MediaTypeId('media.cat6_utp'),
        order: const FracIndex('a0'),
        now: _when,
        actor: 'test',
        id: const Uuid('lnk-1'),
        netId: const Uuid('net-1'),
      )..apply(doc);

      _net(doc, 'other', 'N002');
      cmd
        ..revert(doc)
        ..apply(doc);

      expect(doc.nets[const Uuid('net-1')]!.name, 'N001');
    });
  });
}
