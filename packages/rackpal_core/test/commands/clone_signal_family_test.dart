// SFE-B (`#819`): a signal family is cloned from one that ships, and the
// clone is refused where PAL-1 says the print could not tell it apart.
// DR-122 §11.121.2, DR-243, DR-244.
import 'dart:convert';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

const _cresnet = SignalFamilyId('ctl.cresnet');
const _vantage = SignalFamilyId('ctl.vantage');

/// A document carrying the full seed, as `blank_document.dart` makes one.
RackDocument _doc() => RackDocument(
  id: const Uuid('doc-clone-family'),
  appVersion: 'test',
  createdAt: DateTime.utc(2026, 10, 7),
  modifiedAt: DateTime.utc(2026, 10, 7),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026, 10, 7),
    updatedAt: DateTime.utc(2026, 10, 7),
    updatedBy: 'test',
  ),
)..registries = buildSeedRegistries();

/// The first option still free for a new family in [domain].
Pal1Option _free(RackDocument doc, String domain) {
  final menu = pal1ClassVocabulary(pal1EntriesOf(buildSeedRegistries()));
  return pal1Headroom(
    palette: pal1EntriesOf(doc.registries),
    domain: doc.registries.signalDomains[SignalDomainId(domain)]!,
    vocabulary: menu,
  ).free.first;
}

CloneSignalFamilyResult _clone(
  RackDocument doc, {
  SignalFamilyId parent = _cresnet,
  String name = 'Vantage',
  String tag = 'VNT',
  List<int>? dash,
  int? weight,
  ConnectorTypeId? connector,
}) {
  final option = _free(doc, 'ctl');
  return buildCloneSignalFamily(
    doc,
    parent: parent,
    displayName: name,
    shortTag: tag,
    dashPermille: dash ?? option.dashPermille,
    weightPermille: weight ?? option.weightPermille,
    connector: connector,
  );
}

CloneSignalFamilyCommand _ready(CloneSignalFamilyResult r) => switch (r) {
  CloneSignalFamilyReady(:final command) => command,
  CloneSignalFamilyRefused(:final reason) => fail('refused: $reason'),
};

String _refused(CloneSignalFamilyResult r) => switch (r) {
  CloneSignalFamilyRefused(:final reason) => reason,
  CloneSignalFamilyReady() => fail('expected a refusal'),
};

void main() {
  group('SFE-B1: the clone, and the id derived from the spelling', () {
    test('Vantage cloned from Cresnet: the case DR-122 was ruled on', () {
      // DR-244's whole question: clone Cresnet, rename, change the
      // connector to conn.hardwired. The id is the spelling under the
      // PARENT's prefix, and `ctl.vantage` already ships (DR-120), so the
      // clone takes the next free one rather than shadowing it.
      final doc = _doc();
      final command = _ready(
        _clone(doc, connector: const ConnectorTypeId('conn.hardwired')),
      );
      expect(command.apply(doc), isTrue);

      final made = doc.registries.signalFamilies[command.family.id]!;
      final parent = doc.registries.signalFamilies[_cresnet]!;
      expect(made.id, const SignalFamilyId('ctl.vantage_2'));
      expect(made.displayName, 'Vantage');
      expect(made.shortTag, 'VNT');
      expect(made.defaultConnector, const ConnectorTypeId('conn.hardwired'));
      // DR-244 §11.243.3: these three are the parent's and are not offered.
      expect(made.domain, parent.domain);
      expect(made.defaultDirection, parent.defaultDirection);
      expect(made.defaultTopology, parent.defaultTopology);
      expect(made.glyphOverride, parent.glyphOverride);
      // SFE-C3: the parent is recorded, so a picker can say what this
      // was cloned from; and no shipped family carries the field.
      expect(made.clonedFrom, _cresnet);
      expect(parent.clonedFrom, isNull);
      // Aliases are NOT inherited: they are how a typed token finds a
      // family, and a copy would make `cresnet` resolve two ways.
      expect(made.aliases, isEmpty);
    });

    test("the default connector is the parent's unless one is chosen", () {
      final doc = _doc();
      final made = _ready(_clone(doc)).family;
      expect(
        made.defaultConnector,
        doc.registries.signalFamilies[_cresnet]!.defaultConnector,
      );
    });

    test('a shipped id is never taken, even by a document older than it', () {
      // A file written before DR-120 carries no `ctl.vantage`. Checked
      // only against the document, the clone would take the shipped id
      // and the day that family is used, the two would be one.
      final doc = _doc();
      doc.registries.signalFamilies.remove(_vantage);
      expect(
        _ready(_clone(doc)).family.id,
        const SignalFamilyId('ctl.vantage_2'),
      );
    });

    test('a spelling that is not an id still makes one', () {
      final doc = _doc();
      expect(
        _ready(_clone(doc, name: 'Savant  RS-485 / Bus!')).family.id,
        const SignalFamilyId('ctl.savant_rs_485_bus'),
      );
    });

    test('undo removes the clone, and an add never replaces', () {
      final doc = _doc();
      final command = _ready(_clone(doc));
      expect(command.apply(doc), isTrue);
      command.revert(doc);
      expect(
        doc.registries.signalFamilies.containsKey(command.family.id),
        isFalse,
      );

      // Two clones built before either applies carry the same id. The
      // second refuses, and its undo must not delete the first.
      final a = _ready(_clone(doc));
      final b = _ready(_clone(doc));
      expect(a.family.id, b.family.id);
      expect(a.apply(doc), isTrue);
      expect(b.apply(doc), isFalse);
      b.revert(doc);
      expect(doc.registries.signalFamilies[a.family.id], same(a.family));
    });

    test('a clone is refused without a parent, a name, a tag, or a real '
        'connector', () {
      final doc = _doc();
      expect(
        _refused(_clone(doc, parent: const SignalFamilyId('ctl.nonesuch'))),
        contains('ctl.nonesuch'),
      );
      expect(_refused(_clone(doc, name: '   ')), contains('name'));
      expect(_refused(_clone(doc, tag: '')), contains('short tag'));
      expect(
        _refused(
          _clone(doc, connector: const ConnectorTypeId('conn.invented')),
        ),
        contains('conn.invented'),
      );
    });

    test("a dash or weight off DR-243's menu is refused", () {
      final doc = _doc();
      // 1100 is no shipped weight, and `5,2` is no class's pattern.
      expect(_refused(_clone(doc, weight: 1100)), contains('dash and weight'));
      expect(
        _refused(_clone(doc, dash: const [5000, 2000], weight: 1000)),
        contains('dash and weight'),
      );
    });
  });

  group('SFE-B2: the command refuses a collision, and says with what', () {
    test('inside the domain, it names the family already drawing it', () {
      // `10,3` at 1.00x is Lutron QS's line, and the long class's pattern.
      final r = _clone(_doc(), dash: const [10000, 3000], weight: 1000);
      expect(_refused(r), contains('ctl.lutron_qs'));
      expect(
        (r as CloneSignalFamilyRefused).collisions
            .whereType<Pal1WithinDomainDuplicate>(),
        hasLength(1),
      );
    });

    test('across domains, it names every family the print would confuse '
        'it with', () {
      // §14.3's TOSLINK fix in reverse: a dot at 1.00x in digital audio is
      // within the band of both IR families at 0.75x.
      final reason = _refused(
        _clone(
          _doc(),
          parent: const SignalFamilyId('audio.spdif_optical'),
          name: 'Mini TOSLINK',
          tag: 'MTOS',
          dash: const [1500, 3000],
          weight: 1000,
        ),
      );
      expect(reason, contains('ctl.ir_emitter'));
      expect(reason, contains('ctl.ir_direct'));
      expect(reason, contains('black and white'));
    });

    test('a clone collides with an earlier clone as surely as with a '
        'shipped family', () {
      final doc = _doc();
      final first = _ready(_clone(doc));
      expect(first.apply(doc), isTrue);
      final reason = _refused(
        _clone(
          doc,
          name: 'Vantage again',
          dash: first.family.dashOverride,
          weight: first.family.lineWeightPermilleOverride,
        ),
      );
      expect(reason, contains(first.family.id.v));
    });

    test('the refusal is the same sentence every time', () {
      String once() => _refused(
        _clone(_doc(), dash: const [10000, 3000], weight: 1000),
      );
      expect(once(), once());
    });
  });

  group('SFE-B4: a cloned family round-trips byte-exact (CR-117)', () {
    test('write(read(bytes)) == bytes with a clone in the document', () {
      // Expected to pass on arrival, since `signalFamilies` is already a
      // serialised map; worth its place because M5-B found two codec
      // entries with no writer that CR-117 had never been carried across.
      final doc = _doc();
      final clone = _ready(
        _clone(doc, connector: const ConnectorTypeId('conn.hardwired')),
      );
      expect(clone.apply(doc), isTrue);

      final bytes = _codec.write(doc);
      final read = _codec.read(bytes);
      final back = (read as Ok<RackDocument>).value;
      expect(utf8.decode(_codec.write(back)), utf8.decode(bytes));

      // And the clone is IN those bytes, every field it was made with, so
      // the comparison above is not passing over a family that was
      // dropped on write.
      final made = back.registries.signalFamilies[clone.family.id]!;
      expect(made.displayName, 'Vantage');
      expect(made.shortTag, 'VNT');
      expect(made.defaultConnector, const ConnectorTypeId('conn.hardwired'));
      expect(made.dashOverride, clone.family.dashOverride);
      expect(made.clonedFrom, _cresnet);
      expect(
        made.lineWeightPermilleOverride,
        clone.family.lineWeightPermilleOverride,
      );
    });
  });

  group('SFE-C: what the clone dialog reads agrees with the command', () {
    test('a name already in the domain is refused, because the picker '
        'shows a family by its label', () {
      expect(
        _refused(_clone(_doc(), name: '  cresnet ')),
        contains('ctl.cresnet'),
      );
    });

    test('a clone is cloned from a shipped family, never from a clone', () {
      final doc = _doc();
      final first = _ready(_clone(doc));
      expect(first.apply(doc), isTrue);
      final reason = _refused(
        _clone(doc, parent: first.family.id, name: 'Vantage Pro'),
      );
      expect(reason, contains('itself a clone'));
      expect(reason, contains('Cresnet'));
      expect(
        cloneableFamilies(doc).signalFamilies.containsKey(first.family.id),
        isFalse,
      );
    });

    test('every option the dialog draws, free or taken, is the verdict the '
        'command reaches, in the same words', () {
      // The dialog draws before the person chooses and the command refuses
      // after. Over every option of the most crowded domain by family
      // count, a free option must build and a taken one must refuse with
      // the exact sentence the dialog showed.
      final doc = _doc();
      final room = cloneHeadroom(doc, const SignalDomainId('ctl'))!;
      expect(room.options, hasLength(cloneMenu().dashes.length * 5));
      expect(room.free, isNotEmpty);
      expect(room.options.where((o) => !o.isFree), isNotEmpty);
      for (final o in room.options) {
        final r = _clone(
          doc,
          dash: o.dashPermille,
          weight: o.weightPermille,
        );
        final where = '${o.dashPermille} @ ${o.weightPermille}';
        if (o.isFree) {
          expect(r, isA<CloneSignalFamilyReady>(), reason: where);
        } else {
          expect(
            _refused(r),
            cloneCollisionSentence(doc, o.blockers),
            reason: where,
          );
        }
      }
    });
  });
}
