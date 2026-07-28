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
        reason: 'recording what went in the wall must not rewrite what '
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

  group('NORMALISATION — pulling the convention colour is not an '
      'exception', () {
    test('an override EQUAL to the convention is stored as null', () {
      // MUTATION: delete the `pulledId == link.jacketColorId ? null :`
      // ternary in `apply()` and this fails. Without it, "no exception"
      // would have TWO on-disk spellings (absent, and present-but-equal),
      // which breaks CR-117's byte canonicality — two documents meaning
      // the same thing would encode differently — and inflates any
      // exceptions count with no-op overrides.
      final doc = _doc(convention: _blue);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _blue,
      ).apply(doc);

      expect(_link(doc).jacketColorPulledId, isNull);
    });

    test('and the resolver agrees it is not an exception', () {
      final doc = _doc(convention: _blue);
      SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _blue,
      ).apply(doc);

      expect(
        resolveJacketColor(
          _link(doc),
          doc.settings.jacketColorConventions,
        ).isException,
        isFalse,
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

    test('normalisation reads the CURRENT convention, so the same command '
        'value is an exception on one run and not on another', () {
      // Whether a pulled colour is an exception is a question about the
      // document at the moment of application, not about the command.
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
      expect(_link(onYellow).jacketColorPulledId, isNull);
    });

    test('revert after a normalised write restores the prior value', () {
      final doc = _doc(convention: _blue, pulled: _yellow);
      final cmd = SetLinkPulledJacketColorCommand(
        linkId: _linkId,
        pulledId: _blue,
      )..apply(doc);
      expect(_link(doc).jacketColorPulledId, isNull);

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
