// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take;
// collapsing the pair into a cascade would delete the intermediate
// assertion.
//
// Writing and withdrawing an acknowledgement (`#259`, M5-B2).
//
// ═══════════════════════════════════════════════════════════════════════
// THE HALF THAT IS EASY TO SHIP WITHOUT NOTICING IS THE TOLERANT READER
// ═══════════════════════════════════════════════════════════════════════
// RJ-006's required reason is enforced in the COMMAND, not in
// `AckedFinding`'s constructor, because the codec calls that constructor.
// The strict half is cheap to test and the tolerant half is the one that
// silently regresses: put the check one layer lower and every test here
// still passes, while a hand-edited or older file with an empty
// project-wide reason stops opening. So this file asserts the refusal
// AND asserts that a document carrying exactly what the refusal forbids
// still reads, writes and round-trips.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 2, 11, 15);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-ack'),
  appVersion: '0.4.95',
  createdAt: _now,
  modifiedAt: _now,
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
);

AcknowledgeFindingCommand _cmd({
  String ruleId = 'LEN-001',
  String targetFingerprint = 'LEN-001:0123456789abcdef',
  String reason = 'Existing condition, to be corrected in Phase 2.',
  Severity demotedTo = Severity.off,
  Uuid? targetEntityId,
}) => AcknowledgeFindingCommand(
  ruleId: ruleId,
  targetFingerprint: targetFingerprint,
  reason: reason,
  demotedTo: demotedTo,
  targetEntityId: targetEntityId,
  now: _now,
  actor: 'R. Riley',
  id: const Uuid('ack-0001'),
);

void main() {
  group('acknowledging', () {
    test('writes the sentence, the author and the date, which is the '
        'whole reason RuleOverride replaced a bare severity map', () {
      final doc = _doc();
      _cmd().apply(doc);

      final ack = doc.ackedFindings[const Uuid('ack-0001')]!;
      expect(ack.ruleId, 'LEN-001');
      expect(ack.reason, 'Existing condition, to be corrected in Phase 2.');
      expect(ack.by, 'R. Riley');
      expect(ack.at, _now);
      expect(ack.demotedTo, Severity.off);
    });

    test('the id is minted in the constructor, so redo recreates the '
        'identical entity rather than a second one', () {
      final doc = _doc();
      final cmd = AcknowledgeFindingCommand(
        ruleId: 'LEN-001',
        targetFingerprint: 'LEN-001:0123456789abcdef',
        reason: '',
        demotedTo: Severity.off,
        now: _now,
        actor: 'R. Riley',
      );
      cmd.apply(doc);
      final first = doc.ackedFindings.keys.single;
      cmd.revert(doc);
      cmd.apply(doc);
      expect(doc.ackedFindings.keys.single, first);
    });

    test('apply, revert, apply lands on identical bytes (CR-117)', () {
      final doc = _doc();
      final before = _codec.write(doc);
      final cmd = _cmd();
      cmd.apply(doc);
      final applied = _codec.write(doc);
      cmd.revert(doc);
      expect(_codec.write(doc), before);
      cmd.apply(doc);
      expect(_codec.write(doc), applied);
    });
  });

  group('withdrawing', () {
    test('removes the entry and puts back the identical entity, meta '
        'triple included', () {
      final doc = _doc();
      _cmd().apply(doc);
      final acknowledged = _codec.write(doc);

      final withdraw = UnacknowledgeFindingCommand(
        id: const Uuid('ack-0001'),
      );
      withdraw.apply(doc);
      expect(doc.ackedFindings, isEmpty);
      withdraw.revert(doc);
      expect(_codec.write(doc), acknowledged);
    });

    test('and it names its own act, because an undo entry that said '
        '"Acknowledge" would name the thing being got rid of', () {
      expect(
        UnacknowledgeFindingCommand(id: const Uuid('ack-0001')).label,
        isNot(_cmd().label),
      );
    });
  });

  group('the writer refuses what the rules refuse', () {
    test('a project-wide mute with an empty reason cannot be built', () {
      expect(
        () => _cmd(targetFingerprint: kProjectWideFingerprint, reason: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('and a tier-1 rule cannot be acknowledged at all', () {
      expect(
        () => _cmd(ruleId: 'TOP-001', targetFingerprint: 'TOP-001:abc'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('while the same mute WITH a reason is exactly what CR-019 '
        'exists to allow, errors included', () {
      final doc = _doc();
      _cmd(
        targetFingerprint: kProjectWideFingerprint,
        reason: 'As-found survey. Remediation is Phase 2 scope.',
      ).apply(doc);
      expect(
        doc.ackedFindings.values.single.targetFingerprint,
        kProjectWideFingerprint,
      );
    });
  });

  group('the reader does not', () {
    test('a file carrying a project-wide mute with an empty reason still '
        'opens, and still round-trips byte for byte', () {
      // Exactly what the command above refuses. A hand-edited file, or
      // one written by a build before the rule existed, must not be
      // unopenable: refusing to show somebody their drawing to punish a
      // missing sentence is the failure mode this split avoids.
      final doc = _doc();
      doc.ackedFindings[const Uuid('ack-legacy')] = AckedFinding(
        id: const Uuid('ack-legacy'),
        ruleId: 'LEN-001',
        targetFingerprint: kProjectWideFingerprint,
        reason: '',
        by: '',
        at: _now,
        demotedTo: Severity.off,
        meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: ''),
      );
      final bytes = _codec.write(doc);

      final outcome = _codec.read(bytes);
      expect(outcome, isA<Ok<RackDocument>>());
      final reopened = (outcome as Ok<RackDocument>).value;
      expect(reopened.ackedFindings[const Uuid('ack-legacy')]!.reason, '');
      expect(_codec.write(reopened), bytes);
    });
  });
}
