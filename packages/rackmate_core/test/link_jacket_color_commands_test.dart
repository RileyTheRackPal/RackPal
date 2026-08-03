// THE TWO COMMANDS that write per-run jacket colour, and the one piece
// of cleverness either of them contains (normalisation).
//
// Every user-visible edit routes through a Command so it undoes. These
// two are the write path for facts recorded by two different people at
// two different times — the designer names the convention entry at
// design time, the tech records the wrong-colour pull at prewire — so
// the properties worth pinning are: each edits ONE fact, neither
// cascades into the other, and both restore exactly on revert.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _blue = JacketColorId('jc.blue');
const _yellow = JacketColorId('jc.yellow');
const _linkId = Uuid('0190e3c1-cf80-75bb-96ac-d3b7ef294cab');

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026, 7, 27, 9),
  updatedAt: DateTime.utc(2026, 7, 27, 9),
  updatedBy: 'rriley',
);

RackDocument _doc({JacketColorId? convention, JacketColorId? pulled}) {
  final doc = RackDocument(
    id: const Uuid('0190e3c1-0000-7000-8000-0000000000ab'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026, 7, 27, 9),
    modifiedAt: DateTime.utc(2026, 7, 27, 9),
    meta: _meta(),
  );
  doc.links[_linkId] = Link(
    id: _linkId,
    designator: 'W001',
    media: const MediaTypeId('media.cat6_utp'),
    order: const FracIndex('a0'),
    meta: _meta(),
    jacketColorId: convention,
    jacketColorPulledId: pulled,
  );
  return doc;
}

Link _link(RackDocument doc) => doc.links[_linkId]!;

void main() {
  group('SetLinkJacketColorCommand — what the run IS', () {
    test('sets the convention id', () {
      final doc = _doc();
      SetLinkJacketColorCommand(
        linkId: _linkId,
        conventionId: _blue,
      ).apply(doc);
      expect(_link(doc).jacketColorId, _blue);
    });

    test('revert restores the PRIOR value, not null', () {
      // The `RemoveLinkCommand` pattern: the before-value is captured in
      // `apply()`. A command that reverted to null would silently erase
      // an earlier designer's choice on every undo.
      final doc = _doc(convention: _blue);
      final cmd = SetLinkJacketColorCommand(
        linkId: _linkId,
        conventionId: _yellow,
      )..apply(doc);
      expect(_link(doc).jacketColorId, _yellow);

      cmd.revert(doc);
      expect(_link(doc).jacketColorId, _blue);
    });

    test('clearing to null undoes back to the prior value', () {
      final doc = _doc(convention: _blue);
      final cmd = SetLinkJacketColorCommand(
        linkId: _linkId,
        conventionId: null,
      )..apply(doc);
      expect(_link(doc).jacketColorId, isNull);

      cmd.revert(doc);
      expect(
        _link(doc).jacketColorId,
        _blue,
        reason:
            'null is a legitimate NEW value here, so "did I run?" cannot '
            'be inferred from the captured value being null',
      );
    });

    test('idempotent under alternation (apply; revert; apply)', () {
      final doc = _doc(convention: _blue);
      SetLinkJacketColorCommand(linkId: _linkId, conventionId: _yellow)
        ..apply(doc)
        ..revert(doc)
        ..apply(doc);
      expect(_link(doc).jacketColorId, _yellow);
    });

    test('CLEARING THE CONVENTION DOES NOT CASCADE-CLEAR THE OVERRIDE', () {
      // Deliberate. "Override only, no convention" is a legal state — a
      // tech observed a yellow jacket; nobody has said what the run is
      // for — and discarding that observation because the semantic field
      // was cleared would destroy an observed physical fact. Cascades
      // are also undo hazards.
      final doc = _doc(convention: _blue, pulled: _yellow);
      SetLinkJacketColorCommand(linkId: _linkId, conventionId: null).apply(doc);

      expect(_link(doc).jacketColorId, isNull);
      expect(_link(doc).jacketColorPulledId, _yellow);
    });

    test('declares the wires epoch and the link it affects', () {
      final cmd = SetLinkJacketColorCommand(
        linkId: _linkId,
        conventionId: _blue,
      );
      expect(cmd.touches.has(EpochMask.wires), isTrue);
      expect(cmd.affects, [_linkId]);
      expect(cmd.label, LabelKey.setLinkJacketColor);
    });
  });

  group('SetLinkPulledJacketColorCommand — what was actually PULLED', () {
    test('records the exception', () {
      final doc = _doc(convention: _blue);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _yellow,
      ).apply(doc);

      expect(_link(doc).jacketColorPulledId, _yellow);
      expect(
        _link(doc).jacketColorId,
        _blue,
        reason:
            'recording what went in the wall must not rewrite what '
            'the run is FOR',
      );
    });

    test('NEVER PROMOTES an override into the convention field', () {
      // Promoting would assert "this is a general data drop", which
      // nobody has said (G4).
      final doc = _doc();
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _yellow,
      ).apply(doc);

      expect(_link(doc).jacketColorPulledId, _yellow);
      expect(_link(doc).jacketColorId, isNull);
    });

    test('revert restores the prior override', () {
      final doc = _doc(convention: _blue, pulled: _yellow);
      final cmd = SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: null,
      )..apply(doc);
      expect(_link(doc).jacketColorPulledId, isNull);

      cmd.revert(doc);
      expect(_link(doc).jacketColorPulledId, _yellow);
    });

    test('declares the wires epoch and the link it affects', () {
      final cmd = SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _yellow,
      );
      expect(cmd.touches.has(EpochMask.wires), isTrue);
      expect(cmd.affects, [_linkId]);
      expect(cmd.label, LabelKey.setLinkPulledJacketColor);
    });

    test('the two commands carry DIFFERENT labels — two gestures, two '
        'undo entries', () {
      expect(
        LabelKey.setLinkJacketColor,
        isNot(LabelKey.setLinkPulledJacketColor),
      );
    });
  });

  group('ABSOLUTE STORAGE — an observation is about the wall, not the '
      'drawing', () {
    test('an override EQUAL to the convention is STORED, not discarded — it '
        'means "somebody checked", which null does not', () {
      // This asserted the opposite until the delta-storage defect was
      // found. Normalising a matching observation to null threw away the
      // difference between "a tech confirmed the cable matches" and
      // "nobody has been out there yet", and made the confirming command a
      // no-op. The old comment justified it on CR-117 byte canonicality —
      // but the two spellings do not mean the same thing, so collapsing
      // them was not canonicalisation, it was data loss.
      final doc = _doc(convention: _blue);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _blue,
      ).apply(doc);

      expect(_link(doc).jacketColorPulledId, _blue);
      expect(
        resolveJacketColor(
          _link(doc),
          doc.settings.jacketColorConventions,
        ).isException,
        isFalse,
        reason:
            'it matches the convention TODAY, so it is not an exception '
            'today — but the observation is on record',
      );
    });

    test('RE-DESIGNATING the convention turns a confirmed-matching run into '
        'an exception — the cable did not move', () {
      // THE REGRESSION THIS GROUP EXISTS FOR, and the one the previous
      // cross-check could not see. Under delta storage the observation was
      // erased at write time, so this scenario silently reported the NEW
      // convention colour as as-built, isException false, and zero
      // exceptions in the rollup — a real divergence invisible to every
      // accessor.
      final doc = _doc(convention: _blue);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _blue,
      ).apply(doc);
      // Weeks later the designer re-designates the run. Nobody re-pulls it.
      SetLinkJacketColorCommand(
        linkId: _linkId,
        conventionId: _yellow,
      ).apply(doc);

      final r = resolveJacketColor(
        _link(doc),
        doc.settings.jacketColorConventions,
      );
      expect(r.asBuiltColorId, _blue, reason: 'the wall still holds BLUE');
      expect(
        r.keystoneColorId,
        _yellow,
        reason:
            'the keystone follows the '
            'convention — it is fitted later, out of the yellow box',
      );
      expect(r.isException, isTrue);
    });

    test('the same real-world history recorded in EITHER ORDER yields the '
        'same stored state', () {
      // The delta form was order-dependent: convention-then-observation
      // erased the observation, while observation-then-convention kept it.
      // Two identical histories, two stored states, one of them lying.
      final conventionFirst = _doc(convention: _blue);
      SetLinkJacketColorCommand(
        linkId: _linkId,
        conventionId: _blue,
      ).apply(conventionFirst);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _blue,
      ).apply(conventionFirst);

      final observationFirst = _doc(convention: _blue);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _blue,
      ).apply(observationFirst);
      SetLinkJacketColorCommand(
        linkId: _linkId,
        conventionId: _blue,
      ).apply(observationFirst);

      expect(
        _link(conventionFirst).jacketColorPulledId,
        _link(observationFirst).jacketColorPulledId,
      );
      expect(
        _link(conventionFirst).jacketColorId,
        _link(observationFirst).jacketColorId,
      );
    });

    test('a DIFFERING override is stored as given — normalisation is not '
        'a blanket clear', () {
      // Vacuity guard: if `apply()` always stored null the test above
      // would pass while the feature did nothing at all.
      final doc = _doc(convention: _blue);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _yellow,
      ).apply(doc);

      expect(_link(doc).jacketColorPulledId, _yellow);
    });

    test('the SAME observation stores the SAME value regardless of the '
        'convention it lands on', () {
      // This asserted the opposite, and the assertion WAS the defect: the
      // write path read the link's convention and stored a delta, so an
      // identical physical observation persisted differently depending on
      // what the drawing happened to say at that moment. An observation is
      // about the wall, not about the drawing.
      final onBlue = _doc(convention: _blue);
      final onYellow = _doc(convention: _yellow);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _yellow,
      ).apply(onBlue);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _yellow,
      ).apply(onYellow);

      expect(_link(onBlue).jacketColorPulledId, _yellow);
      expect(_link(onYellow).jacketColorPulledId, _yellow);

      // Exception-ness is derived at READ time, and there the two differ.
      expect(
        resolveJacketColor(
          _link(onBlue),
          onBlue.settings.jacketColorConventions,
        ).isException,
        isTrue,
      );
      expect(
        resolveJacketColor(
          _link(onYellow),
          onYellow.settings.jacketColorConventions,
        ).isException,
        isFalse,
      );
    });

    test('revert restores the prior observation', () {
      final doc = _doc(convention: _blue, pulled: _yellow);
      final cmd = SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _blue,
      )..apply(doc);
      expect(_link(doc).jacketColorPulledId, _blue);

      cmd.revert(doc);
      expect(_link(doc).jacketColorPulledId, _yellow);
    });
  });

  group('a missing link is a no-op, not a crash', () {
    test('applying to an absent link changes nothing', () {
      final doc = _doc();
      const missing = Uuid('no-such-link');
      SetLinkJacketColorCommand(
        linkId: missing,
        conventionId: _blue,
      ).apply(doc);
      SetLinkPulledJacketColorCommand(
        linkId: missing,
        pulledId: _yellow,
      ).apply(doc);

      expect(doc.links, hasLength(1));
      expect(_link(doc).jacketColorId, isNull);
    });
  });
}
