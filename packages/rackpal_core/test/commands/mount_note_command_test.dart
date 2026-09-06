// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take;
// collapsing the pair into a cascade would delete the intermediate
// assertion.
//
// The producer `OffRackPlacement.mountNote` never had (`#839`, M5-L,
// DR-130 §11.129).
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT MADE THIS A CHAPTER RATHER THAN A ONE-LINE FIX
// ═══════════════════════════════════════════════════════════════════════
// DR-125 dispositioned the cabinet head end as "expressible as
// `OffRackPlacement` with a `mountNote`, but crude". The census found the
// crude option was not available either: no command wrote the field, no
// widget rendered it, no schedule printed it, and its only writers were
// the starter generator's. So the finding had been priced against a
// workaround reachable only by hand-editing JSON.
//
// The tests that matter here are therefore the round trip and the
// refusal, not the setter.
import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 6, 14);
final _later = DateTime.utc(2026, 9, 6, 15);
const _rackId = Uuid('rk-1');
const _closet = Uuid('loc-closet');
const _offRack = Uuid('dev-modem');
const _railed = Uuid('dev-amp');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-mount-note'),
    appVersion: '0.5.61',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.locations[_closet] = Location(
    id: _closet,
    name: 'AV Closet',
    code: 'AVC',
    kind: LocationKind.room,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Test Rack',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  doc.templates[catalogTemplateKey('X01')] = TemplateSnapshot(
    templateId: const TemplateId('X01'),
    version: 1,
    contentHash: 'sha256:x01',
    body: TemplateBody(
      manufacturer: 'Test',
      model: 'modem',
      displayName: 'Cable modem',
      typePrefix: 'MDM',
    ),
    capturedAt: _now,
  );
  doc.devices[_offRack] = DeviceInstance(
    id: _offRack,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('X01'),
      version: 1,
      contentHash: 'sha256:x01',
    ),
    designator: 'MDM-1',
    name: 'Cable modem',
    placement: const OffRackPlacement(locationId: _closet),
    meta: _meta(),
  );
  doc.devices[_railed] = DeviceInstance(
    id: _railed,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('X01'),
      version: 1,
      contentHash: 'sha256:x01',
    ),
    designator: 'AMP-1',
    name: 'Amplifier',
    placement: const RailPlacement(
      rackId: _rackId,
      ruIndex: 3,
      face: Face.front,
    ),
    meta: _meta(),
  );
  return doc;
}

SetMountNoteCommand _plan(RackDocument doc, Uuid id, String note) {
  final planned = planSetMountNote(
    doc: doc,
    id: id,
    note: note,
    now: _later,
    actor: 'Riley',
  );
  return (planned as MountNoteReady).command;
}

void main() {
  group('the writer the field never had', () {
    test('a cabinet head end can finally say where in the cabinet', () {
      final doc = _doc();
      final command = _plan(doc, _offRack, 'Top shelf, left, sideways');
      command.apply(doc);

      final placement = doc.devices[_offRack]!.placement as OffRackPlacement;
      expect(placement.mountNote, 'Top shelf, left, sideways');
      expect(
        placement.locationId,
        _closet,
        reason: 'the note refines the location, it does not replace it',
      );
    });

    test('and undo puts back the note that was there, not an empty one', () {
      final doc = _doc();
      _plan(doc, _offRack, 'First').apply(doc);
      final second = _plan(doc, _offRack, 'Second');
      second.apply(doc);
      expect(
        (doc.devices[_offRack]!.placement as OffRackPlacement).mountNote,
        'Second',
      );

      second.revert(doc);
      expect(
        (doc.devices[_offRack]!.placement as OffRackPlacement).mountNote,
        'First',
        reason: 'reverting to null would delete a note the user still had',
      );
    });

    test('undo restores the meta triple, which CR-117 needs byte-exact', () {
      final doc = _doc();
      final before = doc.devices[_offRack]!.meta;
      final at = before.updatedAt;
      final by = before.updatedBy;
      final rev = before.localRevision;

      final command = _plan(doc, _offRack, 'Behind the TV');
      command.apply(doc);
      expect(doc.devices[_offRack]!.meta.updatedBy, 'Riley');

      command.revert(doc);
      final after = doc.devices[_offRack]!.meta;
      expect(after.updatedAt, at);
      expect(after.updatedBy, by);
      expect(after.localRevision, rev);
    });
  });

  group('an empty note is an ABSENT key, never an empty string (G4)', () {
    test('normalizeMountNote trims, and blank becomes null', () {
      expect(normalizeMountNote('  Top shelf  '), 'Top shelf');
      expect(normalizeMountNote(''), isNull);
      expect(normalizeMountNote('   '), isNull);
    });

    test('so clearing the field leaves NO mountNote key in the bytes', () {
      final doc = _doc();
      _plan(doc, _offRack, 'Top shelf').apply(doc);
      final withNote = utf8.decode(_codec.write(doc));
      expect(withNote, contains('mountNote'));

      _plan(doc, _offRack, '   ').apply(doc);
      final cleared = utf8.decode(_codec.write(doc));
      expect(
        cleared,
        isNot(contains('mountNote')),
        reason:
            'an empty string round-trips as a note that exists and says '
            'nothing, which is exactly the state CR-114 forbids',
      );
    });

    test('and the note survives a byte round trip (CR-117)', () {
      final doc = _doc();
      _plan(doc, _offRack, 'Top shelf, left').apply(doc);
      final bytes = _codec.write(doc);
      final decoded = (_codec.read(bytes) as Ok<RackDocument>).value;
      expect(_codec.write(decoded), bytes);
      final back = decoded.devices[_offRack]!.placement;
      expect((back as OffRackPlacement).mountNote, 'Top shelf, left');
    });
  });

  group('what it refuses, and what it deliberately does not', () {
    test('a rail-placed device is refused, and the message says why', () {
      final doc = _doc();
      final planned = planSetMountNote(
        doc: doc,
        id: _railed,
        note: 'Top shelf',
        now: _later,
        actor: 'Riley',
      );
      expect(planned, isA<MountNoteRefused>());
      expect(
        (planned as MountNoteRefused).reason,
        contains('AMP-1'),
        reason: 'a refusal that does not name the device is a shrug',
      );
    });

    test('a device that is not in the document is refused, not thrown', () {
      final planned = planSetMountNote(
        doc: _doc(),
        id: const Uuid('dev-nope'),
        note: 'Anywhere',
        now: _later,
        actor: 'Riley',
      );
      expect(planned, isA<MountNoteRefused>());
    });

    test('NO RULE FIRES ON A MOUNT NOTE, which is DR-130 and not an '
        'oversight', () {
      // PLC-001 IS TIER 1, and this test originally asked
      // `evaluateDocument` for a PLC finding. It never emits one, for any
      // document, so the assertion passed on a rule it was not reaching.
      // The canary below is what caught it. The rule actually runs in
      // `evaluatePlacement`, at the gesture, so that is where the
      // silence has to be measured.
      final doc = _doc();
      _plan(doc, _offRack, 'Top shelf, left').apply(doc);
      expect(
        evaluatePlacement(
          doc: doc,
          placement: doc.devices[_offRack]!.placement,
          designator: 'MDM-1',
        ),
        isA<PlacementAllowed>(),
        reason:
            'the rule asks whether a rail position fits inside a rack, '
            'and a cabinet has neither; making it fire would fabricate a '
            'rack, which CR-114 forbids',
      );
    });

    test('and that silence is NOT the rule being asleep', () {
      // THE CANARY, and it has already earned its keep: it failed on the
      // first draft of the test above and proved the assertion was
      // vacuous. Same fixture, same call, a placement PLC-001 must
      // refuse. If this stops firing, the test above stops meaning
      // anything and fails rather than staying green.
      final doc = _doc();
      final verdict = evaluatePlacement(
        doc: doc,
        placement: const RailPlacement(
          rackId: _rackId,
          ruIndex: 99,
          face: Face.front,
        ),
        designator: 'AMP-1',
      );
      expect(verdict, isA<PlacementRefused>());
      expect((verdict as PlacementRefused).ruleId, 'PLC-001');
    });

    test('and the tier-3 half stays quiet on it too (RCK-002)', () {
      // PLC-001's extent half and RCK-002 are the same condition at two
      // moments, per placement_rules.dart's header. A cabinet head end
      // must be silent at BOTH, or a device gets a finding for sitting
      // in a closet.
      final doc = _doc();
      _plan(doc, _offRack, 'Top shelf, left').apply(doc);
      expect(
        evaluateDocument(doc).where(
          (f) => f.ruleId == 'RCK-002' && f.targets.contains(_offRack),
        ),
        isEmpty,
      );
    });
  });

  group('the undo entry a person actually sees', () {
    test('is its own label, not "Set Property"', () {
      final doc = _doc();
      expect(
        _plan(doc, _offRack, 'Top shelf').label,
        LabelKey.setMountNote,
      );
    });

    test('and typing merges into ONE entry rather than one per '
        'keystroke', () {
      final doc = _doc();
      final a = _plan(doc, _offRack, 'Top');
      a.apply(doc);
      final b = _plan(doc, _offRack, 'Top shelf');
      expect(
        b.mergeKey,
        a.mergeKey,
        reason:
            'without this, "Top shelf, left" is fifteen undo entries and '
            'getting back means pressing the shortcut fifteen times',
      );
    });

    test('but two DIFFERENT devices do not merge into each other', () {
      final doc = _doc();
      doc.devices[const Uuid('dev-other')] = DeviceInstance(
        id: const Uuid('dev-other'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('X01'),
          version: 1,
          contentHash: 'sha256:x01',
        ),
        designator: 'MDM-2',
        name: 'Second modem',
        placement: const OffRackPlacement(),
        meta: _meta(),
      );
      final a = _plan(doc, _offRack, 'Top shelf');
      final b = _plan(doc, const Uuid('dev-other'), 'Bottom shelf');
      expect(b.mergeKey, isNot(a.mergeKey));
    });
  });
}
