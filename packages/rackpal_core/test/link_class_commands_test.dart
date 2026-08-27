// DR-008 §11.8.2's two commands, and the undo behaviour that makes the
// override safe to offer at all.
//
// THE CASE THIS FILE EXISTS FOR is `revert restores the PREVIOUS
// assertion, not the default`. Both commands are one-line writes, so the
// obvious `revert()` is a one-line write back — and the obvious constant
// to write back is `false`. That is correct exactly once: the first time a
// link is ever classed by hand. Re-class a link that was ALREADY locked,
// undo, and the hardcoded version silently hands the link to the
// classifier — discarding an assertion the user never touched, on the undo
// of an action that was supposed to restore it.
//
// Nothing about that failure is visible in the document. The link keeps a
// plausible class (the classifier's), so the only symptom is that a
// deliberate override quietly stopped applying.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 7, 28);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _linkId = Uuid('lnk-1');

/// A document holding one link, optionally pre-asserted.
RackDocument _doc({LinkClass? asserted}) {
  final doc = RackDocument(
    id: const Uuid('doc-lcc'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  doc.links[_linkId] = Link(
    id: _linkId,
    designator: 'W001',
    media: const MediaTypeId('media.cat6_utp'),
    order: const FracIndex('a0'),
    meta: _meta(),
    linkClass: asserted ?? LinkClass.fieldCable,
    linkClassLocked: asserted != null,
  );
  return doc;
}

Link _link(RackDocument doc) => doc.links[_linkId]!;

void main() {
  group('SetLinkClassCommand', () {
    test('writes the class AND the bit saying a person put it there', () {
      final doc = _doc();
      SetLinkClassCommand(
        linkId: _linkId,
        linkClass: LinkClass.powerCord,
      ).apply(doc);

      expect(_link(doc).linkClass, LinkClass.powerCord);
      expect(
        _link(doc).linkClassLocked,
        isTrue,
        reason:
            'writing the value without the lock leaves an assertion the '
            'classifier is free to contradict on the next document change, '
            'which is the single thing §11.8.2 forbids',
      );
    });

    test('locks even when the user AGREES with the classifier', () {
      // Same value the classifier would produce. It is still an assertion,
      // and demoting it to "unlocked because it matches today" would drop
      // the user's word the moment the document moved.
      final doc = _doc();
      SetLinkClassCommand(
        linkId: _linkId,
        linkClass: LinkClass.fieldCable,
      ).apply(doc);
      expect(_link(doc).linkClassLocked, isTrue);
    });

    test('revert restores an UNLOCKED link to unlocked', () {
      final doc = _doc();
      SetLinkClassCommand(linkId: _linkId, linkClass: LinkClass.jumper)
        ..apply(doc)
        ..revert(doc);

      expect(_link(doc).linkClass, LinkClass.fieldCable);
      expect(_link(doc).linkClassLocked, isFalse);
    });

    test('REVERT RESTORES THE PREVIOUS ASSERTION, NOT THE DEFAULT', () {
      // The link was already classed by hand as a jumper. A second
      // classification is applied and undone; the FIRST assertion must
      // survive, lock and all.
      final doc = _doc(asserted: LinkClass.jumper);
      SetLinkClassCommand(linkId: _linkId, linkClass: LinkClass.powerCord)
        ..apply(doc)
        ..revert(doc);

      expect(_link(doc).linkClass, LinkClass.jumper);
      expect(
        _link(doc).linkClassLocked,
        isTrue,
        reason:
            'a hardcoded `linkClassLocked = false` in revert() passes every '
            'other test in this file and loses a user assertion here — '
            'silently, because the link keeps a plausible class',
      );
    });

    test('revert before apply throws rather than corrupting state', () {
      final doc = _doc();
      expect(
        () => SetLinkClassCommand(
          linkId: _linkId,
          linkClass: LinkClass.jumper,
        ).revert(doc),
        throwsStateError,
      );
    });

    test('a missing link is a no-op, not a crash', () {
      final doc = _doc();
      doc.links.clear();
      expect(
        () => SetLinkClassCommand(
          linkId: _linkId,
          linkClass: LinkClass.jumper,
        ).apply(doc),
        returnsNormally,
      );
    });

    test('labels itself distinctly from the clear command', () {
      final set = SetLinkClassCommand(
        linkId: _linkId,
        linkClass: LinkClass.jumper,
      );
      expect(set.label, LabelKey.setLinkClass);
      expect(set.touches, EpochMask.wires);
      expect(set.affects, [_linkId]);
    });
  });

  group('ClearLinkClassOverrideCommand', () {
    test('drops the lock and LEAVES the stored class alone', () {
      final doc = _doc(asserted: LinkClass.powerCord);
      ClearLinkClassOverrideCommand(linkId: _linkId).apply(doc);

      expect(_link(doc).linkClassLocked, isFalse);
      expect(
        _link(doc).linkClass,
        LinkClass.powerCord,
        reason:
            "rewriting the field to the classifier's current answer would "
            'store a value derivable from other stored facts — the thing '
            'CR-107 deleted StructureDrop for — and would be wrong again '
            'the next time the document moved',
      );
    });

    test('revert restores the assertion', () {
      final doc = _doc(asserted: LinkClass.jumper);
      ClearLinkClassOverrideCommand(linkId: _linkId)
        ..apply(doc)
        ..revert(doc);

      expect(_link(doc).linkClassLocked, isTrue);
      expect(_link(doc).linkClass, LinkClass.jumper);
    });

    test('clearing an ALREADY-unlocked link is inert both ways', () {
      final doc = _doc();
      final cmd = ClearLinkClassOverrideCommand(linkId: _linkId)..apply(doc);
      expect(_link(doc).linkClassLocked, isFalse);
      cmd.revert(doc);
      expect(
        _link(doc).linkClassLocked,
        isFalse,
        reason:
            'revert must restore what was there — false — rather than '
            'assume it is undoing a real unlock and set true',
      );
    });

    test('revert before apply throws rather than corrupting state', () {
      final doc = _doc(asserted: LinkClass.jumper);
      expect(
        () => ClearLinkClassOverrideCommand(linkId: _linkId).revert(doc),
        throwsStateError,
      );
    });

    test('a missing link is a no-op, not a crash', () {
      final doc = _doc();
      doc.links.clear();
      expect(
        () => ClearLinkClassOverrideCommand(linkId: _linkId).apply(doc),
        returnsNormally,
      );
    });

    test('carries its own label', () {
      final clear = ClearLinkClassOverrideCommand(linkId: _linkId);
      expect(clear.label, LabelKey.clearLinkClassOverride);
      expect(clear.touches, EpochMask.wires);
      expect(clear.affects, [_linkId]);
    });
  });

  group('the two commands compose', () {
    test('set, clear, undo, undo returns to the original state', () {
      final doc = _doc();
      final set = SetLinkClassCommand(
        linkId: _linkId,
        linkClass: LinkClass.jumper,
      )..apply(doc);
      final clear = ClearLinkClassOverrideCommand(linkId: _linkId)..apply(doc);
      expect(_link(doc).linkClassLocked, isFalse);

      clear.revert(doc);
      expect(_link(doc).linkClassLocked, isTrue);
      expect(_link(doc).linkClass, LinkClass.jumper);

      set.revert(doc);
      expect(_link(doc).linkClassLocked, isFalse);
      expect(_link(doc).linkClass, LinkClass.fieldCable);
    });
  });
}
