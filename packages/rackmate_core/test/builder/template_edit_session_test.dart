// M4-A/4, CR-106: the Device Builder's own stack, over a `TemplateBody`
// and not a `RackDocument`.
//
// The artifact these tests assert is "the same machinery works on a
// second aggregate, and the copy the session edits is genuinely its own".
// They deliberately do NOT re-test undo/redo mechanics that
// `undo_stack_test` already covers on the document — a second copy of
// those would pin the mechanism twice and the behaviour once.
//
// WATCHED FAILING, and the result divided the copy tests in two. With
// `copyTemplateBody` replaced by `(b) => b` — the shallow-copy defect —
// the two "edits a copy" tests fail and the byte sweep PASSES, because a
// body compared against itself is trivially byte-identical. So the three
// are not redundant and neither covers the other: the byte sweep catches
// a copy that LOSES a field, and the identity tests catch a copy that
// SHARES one. A future edit that deletes either half on the grounds that
// the other is there is deleting the only cover for one of the two
// defects.
import 'dart:typed_data';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _panelPosition = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len(0),
  yFineNm: Len(0),
);

TemplateBody _body() => TemplateBody(
  manufacturer: 'Extron',
  model: 'DTP CrossPoint 84',
  displayName: 'DTP CrossPoint 84 IPCP MA 70',
  typePrefix: 'MTX',
  frontU: 2,
  ports: [
    PortDef(
      key: const PortKey('in.1'),
      label: 'IN 1',
      connector: const ConnectorTypeId('conn.hdmi'),
      signalFamily: const SignalFamilyId('video.hdmi'),
      face: Face.rear,
      position: _panelPosition,
      order: const FracIndex('a0'),
    ),
  ],
  tags: ['matrix'],
);

EntityMeta _meta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'seed',
);

/// A document whose only content is [body], so the codec's bytes for it
/// are a faithful stand-in for "what the file would say about this
/// template". The `TemplateBody` encoder is private to `json_codec.dart`
/// and stays that way; going through the public document codec is what
/// keeps this test asserting the ARTIFACT (the bytes) rather than the
/// mechanism.
Uint8List _bytesFor(TemplateBody body) {
  final doc = RackDocument(
    id: const Uuid('doc-template-copy-test'),
    appVersion: '0.1.0',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    meta: _meta(),
  );
  doc.templates['tpl.probe@1'] = TemplateSnapshot(
    templateId: const TemplateId('tpl.probe'),
    version: 1,
    contentHash: 'probe',
    body: body,
    capturedAt: DateTime.utc(2026),
  );
  return const JsonDocumentCodec().write(doc);
}

/// The merge window is 400 ms, so a fixed clock is what decides whether
/// two edits coalesce — not a `sleep`.
final class _StepClock implements Clock {
  _StepClock(this._now);

  DateTime _now;

  void advance(Duration d) => _now = _now.add(d);

  @override
  DateTime nowUtc() => _now;
}

void main() {
  group('the session edits a copy', () {
    test('the original is untouched by anything the session does', () {
      final original = _body();
      final session = TemplateEditSession(original)
        ..run(
          const SetTemplateFieldCommand<String>(
            field: TemplateBodyField.manufacturer,
            from: 'Extron',
            to: 'Crestron',
          ),
        );

      expect(session.body.manufacturer, 'Crestron');
      expect(
        original.manufacturer,
        'Extron',
        reason:
            'the session must edit a copy — a session mutating the '
            'library body in place makes CR-106s discard-on-close a '
            'comment rather than a behaviour',
      );
    });

    test('the copy is DEEP: its lists are not the originals', () {
      final original = _body();
      final session = TemplateEditSession(original);

      expect(identical(session.body.ports, original.ports), isFalse);
      expect(identical(session.body.tags, original.tags), isFalse);
      expect(
        identical(session.body.ports.single, original.ports.single),
        isFalse,
        reason:
            'a shallow list copy shares the PortDefs, so editing a port '
            'in the builder would edit the library template and '
            'cancelling would not take it back',
      );

      session.body.ports.clear();
      session.body.tags.add('scratch');
      expect(original.ports, hasLength(1));
      expect(original.tags, ['matrix']);
    });

    test('every seeded template survives the copy byte-identically', () {
      // The assertion that stays true when somebody adds field 51,
      // because it never names a field: if the copy loses one, the
      // bytes differ. Run over the whole shipped catalog rather than
      // one hand-built fixture, on the census habit — a fixture agrees
      // with whatever assumption built it.
      final seeds = buildSeedCatalog();
      expect(
        seeds,
        hasLength(greaterThan(40)),
        reason:
            'the sweep below is only worth having over the real catalog; '
            'a shrunken map here would pass vacuously',
      );
      for (final entry in seeds.entries) {
        expect(
          _bytesFor(copyTemplateBody(entry.value)),
          _bytesFor(entry.value),
          reason: '${entry.key} did not survive copyTemplateBody',
        );
      }
    });
  });

  group('undo over a TemplateBody', () {
    test('apply, revert, apply lands where a single apply does', () {
      const edit = SetTemplateFieldCommand<int>(
        field: TemplateBodyField.frontU,
        from: 2,
        to: 4,
      );
      final body = TemplateEditSession(_body()).body;

      edit.apply(body);
      final once = body.frontU;
      edit.revert(body);
      expect(body.frontU, 2);
      edit.apply(body);
      expect(body.frontU, once);
    });

    test('undo and redo move the working copy and the dirty flag', () {
      final session = TemplateEditSession(_body());
      expect(session.isDirty, isFalse);

      session.run(
        const SetTemplateFieldCommand<String?>(
          field: TemplateBodyField.typePrefix,
          from: 'MTX',
          to: 'SW',
        ),
      );
      expect(session.body.typePrefix, 'SW');
      expect(session.isDirty, isTrue);
      expect(session.editsSinceSave, 1);

      expect(session.undoLast(), isTrue);
      expect(session.body.typePrefix, 'MTX');
      expect(
        session.isDirty,
        isFalse,
        reason:
            'undoing back to the save point must read as clean, or '
            'closing the builder prompts about an edit that is no '
            'longer there',
      );

      expect(session.redoLast(), isTrue);
      expect(session.body.typePrefix, 'SW');
      expect(session.isDirty, isTrue);
    });

    test('undo and redo report nothing to do rather than throwing', () {
      final session = TemplateEditSession(_body());
      expect(session.undoLast(), isFalse);
      expect(session.redoLast(), isFalse);
    });

    test('markSaved moves the save point without touching the stack', () {
      final session = TemplateEditSession(_body())
        ..run(
          const SetTemplateFieldCommand<String>(
            field: TemplateBodyField.model,
            from: 'DTP CrossPoint 84',
            to: 'DTP CrossPoint 108',
          ),
        )
        ..markSaved();
      expect(session.isDirty, isFalse);
      expect(session.editsSinceSave, 0);
      expect(session.undo.canUndo, isTrue);

      expect(session.undoLast(), isTrue);
      expect(
        session.isDirty,
        isTrue,
        reason: 'undoing PAST a save point is as dirty as editing forward',
      );
    });
  });

  group('coalescing', () {
    test('a run of keystrokes in one field is one undo entry', () {
      final clock = _StepClock(DateTime.utc(2026, 8, 13, 12));
      final session = TemplateEditSession(_body(), clock: clock)
        ..run(
          const SetTemplateFieldCommand<String>(
            field: TemplateBodyField.displayName,
            from: 'DTP CrossPoint 84 IPCP MA 70',
            to: 'D',
          ),
        );
      clock.advance(const Duration(milliseconds: 100));
      session.run(
        const SetTemplateFieldCommand<String>(
          field: TemplateBodyField.displayName,
          from: 'D',
          to: 'DT',
        ),
      );

      expect(session.undo.depth, 1);
      expect(session.undoLast(), isTrue);
      expect(
        session.body.displayName,
        'DTP CrossPoint 84 IPCP MA 70',
        reason:
            'the merged entry must span from where the first keystroke '
            'started to where the last one ended',
      );
    });

    test('a different field starts a new entry', () {
      final clock = _StepClock(DateTime.utc(2026, 8, 13, 12));
      final session = TemplateEditSession(_body(), clock: clock)
        ..run(
          const SetTemplateFieldCommand<String>(
            field: TemplateBodyField.manufacturer,
            from: 'Extron',
            to: 'Crestron',
          ),
        );
      clock.advance(const Duration(milliseconds: 10));
      session.run(
        const SetTemplateFieldCommand<String>(
          field: TemplateBodyField.model,
          from: 'DTP CrossPoint 84',
          to: 'DM-MD8X8',
        ),
      );

      expect(session.undo.depth, 2);
    });

    test('the same field past the window starts a new entry', () {
      final clock = _StepClock(DateTime.utc(2026, 8, 13, 12));
      final session = TemplateEditSession(_body(), clock: clock)
        ..run(
          const SetTemplateFieldCommand<String>(
            field: TemplateBodyField.manufacturer,
            from: 'Extron',
            to: 'E',
          ),
        );
      clock.advance(const Duration(seconds: 2));
      session.run(
        const SetTemplateFieldCommand<String>(
          field: TemplateBodyField.manufacturer,
          from: 'E',
          to: 'Ex',
        ),
      );

      expect(session.undo.depth, 2);
    });
  });

  group('the mask stays honest', () {
    test('a builder command declares NO epoch, not an empty one', () {
      const edit = SetTemplateFieldCommand<int>(
        field: TemplateBodyField.frontU,
        from: 2,
        to: 4,
      );
      expect(
        edit.touches,
        isNull,
        reason:
            'EpochMask.none would assert this command dirties no document '
            'epoch; null says a TemplateBody has no epoch model at all, '
            'and only the second is true',
      );
      expect(edit.affects, isEmpty);
    });

    test('a transaction of them folds to null, not to none', () {
      final txn = Transaction<TemplateBody>(
        LabelKey.setTemplateProperty,
        [
          const SetTemplateFieldCommand<int>(
            field: TemplateBodyField.frontU,
            from: 2,
            to: 4,
          ),
          const SetTemplateFieldCommand<String>(
            field: TemplateBodyField.model,
            from: 'a',
            to: 'b',
          ),
        ],
        null,
        null,
      );
      expect(txn.touches, isNull);
    });
  });

  group('a closed session is inert', () {
    test('editing after close throws rather than silently doing nothing', () {
      final session = TemplateEditSession(_body())..close();
      expect(session.isClosed, isTrue);
      expect(
        () => session.run(
          const SetTemplateFieldCommand<int>(
            field: TemplateBodyField.frontU,
            from: 2,
            to: 4,
          ),
        ),
        throwsStateError,
      );
      expect(session.undoLast, throwsStateError);
      expect(session.redoLast, throwsStateError);
    });
  });

  group('the field table', () {
    test('every key is unique, because half of mergeKey is that key', () {
      final keys = TemplateBodyField.all.map((f) => f.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('no two fields are the same field, written then read as a set', () {
      // The census this repo asks for before trusting a descriptor table.
      //
      // WRITE ALL, THEN READ ALL — not write-then-read one at a time,
      // which is the version this test started as and which is weaker in
      // exactly the way that matters. A `get`/`set` pair copied from the
      // row above and only HALF repointed fails either version; a pair
      // copied and not repointed AT ALL, so that two rows both drive
      // `manufacturer`, passes the one-at-a-time version and fails this
      // one, because the second write clobbers the first and the first
      // read comes back wrong.
      final body = _body();
      final written = <String, Object?>{};
      for (final field in TemplateBodyField.all) {
        switch (field) {
          case TemplateField<String>():
            written[field.key] = 'probe-${field.key}';
            field.set(body, 'probe-${field.key}');
          case TemplateField<String?>():
            written[field.key] = 'probe-${field.key}';
            field.set(body, 'probe-${field.key}');
          case TemplateField<int>():
            // Distinct per field for the same reason the strings are.
            final v = 70 + TemplateBodyField.all.indexOf(field);
            written[field.key] = v;
            field.set(body, v);
          default:
            fail('${field.key} has an unhandled field type');
        }
      }
      for (final field in TemplateBodyField.all) {
        expect(
          field.get(body),
          written[field.key],
          reason:
              '${field.key} did not read back its own probe — two rows of '
              'TemplateBodyField are pointing at one field of TemplateBody',
        );
      }
    });
  });
}
