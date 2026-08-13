// DR-025 (canon §11.24), board #587 / #690 — `@signal=` names the family
// and `@service=` names the label. They are two words because they are two
// facts.
//
// PROBED END TO END RATHER THAN READ. Four holes in this exact chain have
// been found by driving it and none by reading it, the most recent being
// DR-046's: a parameter that parsed, planned, and then vanished because
// `buildAddHomeRunCommand` took it without forwarding it, with every layer
// correct in isolation. So these cases start at a typed string and finish
// at the applied document, and the parser-level case below exists only to
// localise a failure, never to stand in for the chain.
//
// §11.24.6 IS THE CLAUSE MOST LIKELY TO BE GOT WRONG: the family is stored
// TWICE, on `Service.signalFamily` and on `Net.signalFamily`. Only the
// first is consumed today, so a build that set one and not the other would
// pass every rendering test and leave the file carrying two answers to one
// question. Both are asserted.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final DateTime _now = DateTime.utc(2026, 8, 13);

const _undetermined = SignalFamilyId('structure.undetermined');

RackDocument _project() {
  final doc = RackDocument(
    id: const Uuid('doc-sig'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
  )..registries = buildSeedRegistries();
  AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'test',
  ).apply(doc);
  AddLocationCommand(
    name: 'Living Room',
    code: 'LR',
    order: nextLocationOrder(doc),
    now: _now,
    actor: 'test',
  ).apply(doc);
  return doc;
}

DropLinePlan _plan(RackDocument doc, String line) {
  final parsed = parseDropLine(line);
  expect(parsed, isA<DropLineParsed>(), reason: 'did not parse: $line');
  return planDropLine(
    doc: doc,
    line: parsed as DropLineParsed,
    now: _now,
    actor: 'test',
  );
}

RackDocument _applied(String line) {
  final doc = _project();
  final plan = _plan(doc, line);
  expect(plan, isA<DropLinePlanReady>(), reason: '$plan');
  for (final c in (plan as DropLinePlanReady).commands) {
    c.apply(doc);
  }
  return doc;
}

/// Every family the document records for its links, read off BOTH places
/// the fact is stored (§11.24.6).
({Set<SignalFamilyId> services, Set<SignalFamilyId> nets}) _families(
  RackDocument doc,
) => (
  services: {
    for (final l in doc.links.values)
      for (final s in l.services) s.signalFamily,
  },
  nets: {for (final n in doc.nets.values) n.signalFamily},
);

void main() {
  group('@signal= sets the family, on both fields', () {
    test('a short tag reaches the applied document', () {
      final doc = _applied('Living Room: 2x Cat6 @signal=hbt');
      final f = _families(doc);
      expect(f.services, {const SignalFamilyId('video.hdbaset')});
      expect(
        f.nets,
        {const SignalFamilyId('video.hdbaset')},
        reason:
            '§11.24.6: both or neither, and only the Service is read '
            'today, so a build that set one would look correct',
      );
    });

    test('the id tail and the display name land too', () {
      // §11.24.3's widest-last chain: shortTag, then the id tail, then
      // displayName. `hbt`, `hdbaset` and `avoip` all resolve.
      expect(
        _families(_applied('Living Room: 1x Cat6 @signal=hdbaset')).services,
        {const SignalFamilyId('video.hdbaset')},
      );
      expect(
        _families(_applied('Living Room: 1x Cat6 @signal=avoip')).services,
        {const SignalFamilyId('video.avoip')},
      );
    });

    test('every drop on the line carries it', () {
      final doc = _applied('Living Room: 4x Cat6 @signal=avoip');
      expect(doc.links, hasLength(4));
      expect(
        doc.links.values.every(
          (l) => l.services.every(
            (s) => s.signalFamily == const SignalFamilyId('video.avoip'),
          ),
        ),
        isTrue,
        reason: 'the family is a fact about the run, so it is line-level',
      );
    });
  });

  group('the default is unchanged, which is what DR-025 does NOT touch', () {
    test('a line with no @signal= leaves undetermined', () {
      final f = _families(_applied('Living Room: 2x Cat6'));
      expect(f.services, {_undetermined});
      expect(f.nets, {_undetermined});
    });

    test('@service= sets the LABEL and never the family', () {
      // The decisive case. If one word carried both, this would come out
      // as a family and SIG-001 would fire or not according to a naming
      // decision (§11.24.2).
      final doc = _applied('Living Room: 2x Cat6 @service=camera');
      expect(_families(doc).services, {_undetermined});
      expect(
        doc.links.values.map((l) => l.structureOrigin?.fieldLabel),
        ['LR-CAM-1', 'LR-CAM-2'],
        reason:
            'DR-023 step 1 resolved `camera` through the seeded outlet '
            "template's TAG rather than upper-casing the word, which is "
            'the chain working and not merely a string arriving',
      );
    });

    test('both words on one line do their own jobs', () {
      // The mixed job DR-025 was ruled for: an HDBaseT run to a projector
      // that is labelled for what it serves.
      final doc = _applied(
        'Living Room: 1x Cat6 @service=projector @signal=hbt',
      );
      expect(_families(doc).services, {
        const SignalFamilyId('video.hdbaset'),
      });
      expect(
        doc.links.values.single.structureOrigin?.fieldLabel,
        contains('PROJECTOR'),
      );
    });
  });

  group('an unresolved family REFUSES and never invents one', () {
    test('a typo refuses the whole line', () {
      final doc = _project();
      final plan = _plan(doc, 'Living Room: 2x Cat6 @signal=hdbaset-typo');
      expect(plan, isA<DropLinePlanRefused>());
      expect((plan as DropLinePlanRefused).reason, contains('hdbaset-typo'));
    });

    test('a refused line creates NOTHING', () {
      // The artifact, not the return type: a refusal that had already
      // minted a family would satisfy the case above and still be wrong.
      final doc = _project();
      _plan(doc, 'Living Room: 2x Cat6 @signal=nonsense');
      expect(doc.links, isEmpty);
      expect(doc.nets, isEmpty);
      expect(
        doc.registries.signalFamilies.containsKey(
          const SignalFamilyId('nonsense'),
        ),
        isFalse,
        reason: 'families are catalog-updated; media types are not',
      );
    });
  });

  group('the parser, to localise a failure rather than stand in for one', () {
    test('@signal= is a known modifier and does not warn as unknown', () {
      final parsed =
          parseDropLine('Living Room: 1x Cat6 @signal=hbt') as DropLineParsed;
      expect(parsed.signal, 'hbt');
      expect(parsed.unknownModifiers, isEmpty);
    });

    test('@signal= and @service= are carried separately', () {
      final parsed =
          parseDropLine('LR: 1x Cat6 @service=tv @signal=avoip')
              as DropLineParsed;
      expect(parsed.service, 'tv');
      expect(parsed.signal, 'avoip');
    });
  });
}
