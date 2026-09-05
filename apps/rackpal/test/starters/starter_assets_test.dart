// THE ROADMAP'S GLOBAL RULE, MADE MECHANICAL.
//
// docs/09-roadmap.md §4: *"**Every milestone ends green**: CI passes,
// goldens pass, the app opens the four starter projects."* §8.5 restates
// it as the regression net: *"They are goldens, perf fixtures and
// screenshot source at once, and every milestone must open all four."*
//
// This file is that rule. It does NOT construct documents in memory and
// check them: it reads the four `.rmpj` files off the disk they ship
// on, through `DocumentStore` over `DartIoFileStore` — the same class,
// the same codec, the same error classification a user's own file goes
// through — and then, separately, through the PRODUCTION `rootBundle`
// loader the running application uses. A starter that would not open is
// a red suite.
//
// The five things it proves, in order of how much they would cost to
// discover late:
//
//   1. All four open. Through the real read path, from real files.
//   2. All four round-trip BYTE-EXACTLY (CR-117). `write(read(bytes)) ==
//      bytes`, which is the property the whole persistence layer rests on
//      and which these files — the largest and most varied documents in
//      the repository — are the strongest available test of.
//   3. All four are structurally clean by every rule this build can
//      decide. See `starter_integrity.dart` for what that can honestly
//      mean before the DRC exists.
//   4. The checked-in bytes are exactly what `tool/starters/` produces,
//      so a hand-edited asset or a codec change fails here rather than
//      in a screenshot six weeks later.
//   5. Each file stays under its asserted size ceiling — `RISK-11`'s own
//      early-warning ("the four starter projects act as size fixtures
//      with an asserted ceiling").
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/starter_projects.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/document_store.dart';
import 'package:rackpal/src/storage/io_file_store.dart';
import 'package:rackpal/src/storage/recovery_store.dart';
import 'package:rackpal/src/storage/serialization.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../../tool/starters/authoring.dart';
import '../../tool/starters/starter_sources.dart';
import 'starter_integrity.dart';

/// The per-file ceiling, in bytes.
///
/// WHERE THE NUMBER COMES FROM. An empty document carrying the 48-template
/// seed catalog AND the seeded registries is ~698 KB, and every document
/// this build writes carries both (see `StarterAuthor.newDocument` and
/// `buildBlankDocument` for why). The largest starter's own content is a
/// further ~158 KB. 1 MB leaves room for a starter to grow with each
/// milestone — AC-052 requires exactly that — while still tripping long
/// before the format itself is in question. `RISK-11`'s trigger is "a
/// starter project crossing its asserted byte budget"; this is the
/// assertion.
///
/// DR-010 §11.10 ADDED ~37 KB TO EACH OF THE FOUR, which is the 8 domains,
/// 56 families and 46 connector footprints that every document had been
/// carrying as three empty maps. The ceiling did not move for it: the
/// largest starter went 819 KB → 856 KB, still 84 % of budget.
const int kStarterByteCeiling = 1024 * 1024;

/// The real read path over the real filesystem.
DocumentStore _diskStore() {
  const fs = DartIoFileStore();
  final writer = AtomicWriter(fs: fs, queue: SaveQueue());
  return DocumentStore(
    fs: fs,
    writer: writer,
    recovery: RecoveryStore(fs: fs, writer: writer, dataRoot: '.'),
    // Inline rather than the isolate pair: `serialization_test.dart`
    // already proves the isolate produces byte-identical output, and
    // spawning one per starter would buy nothing here.
    serializer: inlineSerializer,
    deserializer: inlineDeserializer,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = _diskStore();

  test('there are exactly four starter projects, and the runtime list '
      'agrees with the authoring list', () {
    // FOUR, from docs/04 §9 and AC-052. Asserted here rather than in the
    // `StartCard` widget, because "there are four" is a fact about the
    // assets.
    expect(kStarterProjects, hasLength(4));
    expect(kStarterSources, hasLength(4));
    expect(
      [for (final s in kStarterProjects) p.basename(s.assetPath)],
      [for (final s in kStarterSources) s.fileName],
      reason:
          'the runtime list and the authoring list must name the same '
          'four files, in the same order — a starter the card offers and '
          'the generator does not write is a card entry that fails at '
          'the moment it is pressed',
    );
    expect(
      kStarterProjects.map((s) => s.id).toSet(),
      hasLength(4),
      reason: 'ids are used as widget keys and by the shell lookup',
    );
  });

  for (final starter in kStarterProjects) {
    group(starter.title, () {
      final path = starter.assetPath;

      test('opens through the real read path, from disk', () async {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path is missing; run tool/generate_starters.dart',
        );

        final opened = await store.open(path);
        expect(
          opened,
          isA<Ok<OpenedDocument>>(),
          reason:
              'THE ROADMAP GATE: "every milestone ends with the app '
              'opening the four starter projects". ${starter.title} did '
              'not open: ${opened is Err ? (opened as Err).error : ''}',
        );

        final document = (opened as Ok<OpenedDocument>).value;
        expect(document.openReadOnly, isFalse);
        expect(
          document.migratedFromSchemaVersion,
          isNull,
          reason:
              'a starter shipped by THIS build must already be at '
              'kSchemaVersion — a migration on open means the assets '
              'were generated by an older codec',
        );
        expect(document.document.racks, isNotEmpty);
        expect(document.document.templates, hasLength(49));
      });

      test('round-trips byte-exactly (CR-117)', () async {
        final bytes = File(path).readAsBytesSync();
        final decoded = const JsonDocumentCodec().read(bytes);
        expect(decoded, isA<Ok<RackDocument>>());
        final rewritten = const JsonDocumentCodec().write(
          (decoded as Ok<RackDocument>).value,
        );
        expect(
          rewritten,
          orderedEquals(bytes),
          reason:
              '${starter.title} does not survive a read/write cycle '
              'unchanged. CR-117 (sorted keys at every level, '
              'absent-key-not-null, unit-suffixed names) is the property '
              'every save in this application depends on.',
        );
      });

      test(
        'is structurally clean by every rule this build can decide',
        () async {
          final opened = await store.open(path);
          expectStarterIsStructurallyClean(
            (opened as Ok<OpenedDocument>).value.document,
            of: starter.title,
          );
        },
      );

      test('stays under the asserted size ceiling (RISK-11)', () {
        final length = File(path).lengthSync();
        expect(
          length,
          lessThan(kStarterByteCeiling),
          reason:
              '${starter.title} is $length bytes. RISK-11 uses the four '
              'starters as size fixtures precisely so this shows up as a '
              'test failure and not as a support ticket.',
        );
      });

      test('loads through the production rootBundle loader', () async {
        // The one place the SHIPPING asset loader is exercised. Everything
        // else in the suite injects a loader; this asserts the injected
        // seam has a real implementation behind it that finds the file
        // the pubspec declares.
        final bytes = await loadStarterAssetFromBundle(path);
        expect(
          bytes,
          orderedEquals(File(path).readAsBytesSync()),
          reason:
              'the bundled asset and the file on disk must be the same '
              'bytes — a ByteData view taken with the wrong offset would '
              'differ here and nowhere else',
        );
      });
    });
  }

  group('the checked-in bytes are what tool/starters/ produces', () {
    for (final source in kStarterSources) {
      test(source.fileName, () {
        final produced = const JsonDocumentCodec().write(source.build());
        final onDisk = File(
          '$kStarterAssetDirectory/${source.fileName}',
        ).readAsBytesSync();
        expect(
          produced,
          orderedEquals(onDisk),
          reason:
              '${source.fileName} on disk differs from what its builder '
              'produces. Either the asset was hand-edited, or a builder '
              'changed and `dart run tool/generate_starters.dart` was '
              'not re-run. Regenerating is the fix; hand-editing a '
              'golden is not.',
        );
      });
    }

    test('regenerating twice produces identical bytes', () {
      // DETERMINISM IS WHAT MAKES THEM GOLDENS. `StarterAuthor.mint`
      // exists because `newEntityId()` is random; if that ever leaked
      // back in, the assets would churn on every regeneration and the
      // check above would fail for a reason nobody could act on. This
      // catches it at the source instead.
      for (final source in kStarterSources) {
        const codec = JsonDocumentCodec();
        expect(
          codec.write(source.build()),
          orderedEquals(codec.write(source.build())),
          reason: '${source.fileName} is not deterministic',
        );
      }
    });
  });

  group('jacket colour ships as real data, off real disk', () {
    // THE VACUITY GUARD for check 12 in `starter_integrity.dart`. That
    // check iterates `Link.jacketColorId` and would pass by iterating
    // nothing at all, so the corpus has to be shown to actually contain
    // the thing it guards. Three of the four starters carry zero links;
    // `whole_house` carries all 27.
    //
    // EXPECTATIONS ARE LITERALS. Comparing against
    // `buildDefaultJacketColorConvention()` would be the constant
    // confirming itself — the self-referential shape this project has
    // shipped before.
    Future<RackDocument> read(String fileName) async {
      final opened = await _diskStore().open(
        '$kStarterAssetDirectory/$fileName',
      );
      return (opened as Ok<OpenedDocument>).value.document;
    }

    for (final source in kStarterSources) {
      test(
        '${source.fileName} carries the seven-entry seed convention',
        () async {
          final doc = await read(source.fileName);
          expect(
            doc.settings.jacketColorConventions.keys.map((k) => k.v).toSet(),
            {
              'jc.yellow',
              'jc.blue',
              'jc.green',
              'jc.grey',
              'jc.white',
              'jc.red',
              'jc.black',
            },
            reason:
                'the convention is seeded at document CREATION. If it is '
                'missing here, either the seeding line was dropped from '
                '`StarterAuthor.newDocument` or the assets predate it.',
          );
          final blue =
              doc.settings.jacketColorConventions[const JacketColorId(
                'jc.blue',
              )]!;
          expect(blue.abbr, 'BLU');
          expect(blue.displayName, 'Blue');
        },
      );
    }

    test('whole_house pulls colour on its category runs and NOT on the '
        'others', () async {
      final doc = await read('whole_house.rmpj');
      final coloured = [
        for (final l in doc.links.values)
          if (l.jacketColorId != null) l,
      ];
      expect(
        coloured,
        hasLength(15),
        reason:
            'the fifteen Cat6 home runs each carry a jacket colour. If '
            'this is zero, check 12 in starter_integrity.dart is '
            'iterating an empty list and proving nothing.',
      );
      expect(
        coloured.every((l) => l.media.v == 'media.cat6'),
        isTrue,
        reason:
            "the integrator's convention is about CATEGORY CABLE. A "
            'coloured RG6, speaker or fibre run is an invented fact.',
      );
      expect(
        doc.links.values.where((l) => l.jacketColorId == null),
        hasLength(12),
        reason:
            'the twelve non-category runs must stay NULL — unknown, not '
            'guessed (G4).',
      );
      // Set EQUALITY carries the "which five" question alone. Two
      // `isNot(contains(…))` lines for red and black used to follow,
      // reading as guards on the third state; they guarded nothing,
      // because any state in which either appears has already failed the
      // equality above.
      final used = coloured.map((l) => l.jacketColorId!.v).toSet();
      expect(used, {'jc.yellow', 'jc.blue', 'jc.green', 'jc.grey', 'jc.white'});
      expect(
        doc.settings.jacketColorConventions.keys.map((k) => k.v),
        containsAll(<String>['jc.red', 'jc.black']),
        reason:
            'the third state the format exists to express: STOCKED but '
            'not pulled. Both must be in the legend while no run claims '
            'them — a convention pruned to what this job happens to use '
            'would delete the shop’s convention.',
      );
    });

    test('the colour of a run follows its PURPOSE, not its media', () async {
      // Fifteen runs, one media type, five different colours. A build
      // that derived colour from `media` — the obvious wrong shortcut —
      // would give all fifteen the same one and still pass every
      // referential check above.
      final doc = await read('whole_house.rmpj');
      String colourOf(String fieldLabel) => doc.links.values
          .firstWhere((l) => l.structureOrigin?.fieldLabel == fieldLabel)
          .jacketColorId!
          .v;

      expect(colourOf('GR-DATA-1'), 'jc.yellow'); // general data drop
      expect(colourOf('GR-DATA-3'), 'jc.blue'); // touchpanel back box
      expect(colourOf('GR-DATA-4'), 'jc.grey'); // ceiling access point
      expect(colourOf('GAR-DATA-1'), 'jc.white'); // driveway camera
      expect(colourOf('MED-DATA-1'), 'jc.green'); // HDBaseT distribution
    });
  });

  group('the signal registries ship as real data, off real disk', () {
    // THE END-TO-END CLAIM DR-010 §11.10 EXISTS TO MAKE. M2-B was the
    // first code ever to read `doc.registries` and found every map empty
    // in every document — all six maps, all four starters, all six
    // fixtures — because the `assets/catalog/registries.json` that
    // `registries.dart` cited had never existed. Every unit test in
    // `rackpal_core` could pass with the seeding line deleted from
    // `StarterAuthor.newDocument`; only reading the shipped bytes back off
    // the disk catches that, which is why this is here and not there.
    Future<RackDocument> read(String fileName) async {
      final opened = await _diskStore().open(
        '$kStarterAssetDirectory/$fileName',
      );
      return (opened as Ok<OpenedDocument>).value.document;
    }

    for (final source in kStarterSources) {
      test('${source.fileName} resolves its own families end to end', () async {
        final doc = await read(source.fileName);
        expect(
          doc.registries.signalDomains.keys.map((k) => k.v).toSet(),
          {
            'video.digital',
            'video.analog',
            'audio.analog',
            'audio.digital',
            'net',
            'ctl',
            'pwr',
            'str',
          },
          reason:
              'the registries are seeded at document CREATION. If they '
              'are missing here, either the seeding line was dropped '
              'from `StarterAuthor.newDocument` or the assets predate it.',
        );
        expect(doc.registries.signalFamilies, hasLength(56));
        expect(doc.registries.connectorTypes, isNotEmpty);

        // EXPECTATIONS ARE LITERALS, for the same reason the jacket-colour
        // group above says so: comparing against `buildSeedRegistries()`
        // would be the constant confirming itself. These four are read
        // off the disk and checked against §4.3/§4.4's printed values.
        final ctl =
            doc.registries.signalDomains[const SignalDomainId(
              'ctl',
            )]!;
        expect(ctl.displayName, 'Control');
        expect(ctl.tagPrefix, 'CTL');
        expect(ctl.color.toHex(), '#CC79A7');
        expect(ctl.dashPattern, [1500, 3000]);
        expect(ctl.lineWeightPermille, 750);

        // The type-within-domain channel, surviving a real save/load:
        // three solid HDMI generations that separate on weight alone.
        final vid =
            doc.registries.signalDomains[const SignalDomainId(
              'video.digital',
            )]!;
        int weightOf(String id) => doc
            .registries
            .signalFamilies[SignalFamilyId(id)]!
            .effectiveLineWeightPermille(vid);
        expect(weightOf('video.hdmi.1_4'), 750);
        expect(weightOf('video.hdmi.2_0'), 1000);
        expect(weightOf('video.hdmi.2_1'), 1250);
      });
    }

    test('every family a starter actually USES resolves in its own '
        'registries', () async {
      // The vacuity guard, and the thing M2-B's unresolved counts were.
      // `whole_house` is the only starter with links; a `Service` naming
      // a family the file does not carry renders grey with the raw id as
      // its tag (§6.2's `unknown(rawId)`), which is correct behaviour and
      // the wrong outcome for a shipped fixture.
      final doc = await read('whole_house.rmpj');
      final used = {
        for (final link in doc.links.values)
          for (final service in link.services) service.signalFamily,
      };
      expect(
        used,
        isNotEmpty,
        reason:
            'no link carries a Service — this '
            'assertion would prove nothing',
      );
      for (final id in used) {
        final family = doc.registries.signalFamilies[id];
        expect(
          family,
          isNotNull,
          reason: '${id.v} is used by a link and resolves to nothing',
        );
        expect(
          doc.registries.signalDomains.containsKey(family!.domain),
          isTrue,
          reason:
              '${id.v} names domain ${family.domain.v}, which the '
              'file does not carry',
        );
      }
    });
  });

  test('every device kind in a starter matches what the palette would '
      'have produced', () {
    // `starterDeviceKindFor` is a transcription of
    // `buildPlaceFromCatalogCommand`'s own private `_kindFor`. This runs
    // the REAL command for all 48 catalog ids and compares, so the
    // transcription cannot drift into a starter whose blank panels are
    // typed as ordinary devices.
    final catalog = buildSeedCatalog();
    final doc = RackDocument(
      id: const Uuid('kind-parity'),
      appVersion: '0.1.0',
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
      meta: EntityMeta(
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        updatedBy: 'test',
      ),
    );
    for (final entry in catalog.entries) {
      doc.templates[catalogTemplateKey(entry.key)] = TemplateSnapshot(
        templateId: TemplateId(entry.key),
        version: 1,
        contentHash: 'sha256:seed-${entry.key}',
        capturedAt: DateTime.utc(2026),
        body: entry.value,
      );
    }
    final rack = Rack(
      id: const Uuid('kind-parity-rack'),
      name: 'r',
      designator: 'RK-1',
      heightU: 60,
      order: const FracIndex('a0'),
      meta: doc.meta,
    );
    doc.racks[rack.id] = rack;

    var compared = 0;
    for (final entry in catalog.entries) {
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: entry.key,
        targetRack: rack,
        now: DateTime.utc(2026),
        actor: 'test',
      );
      // P01 is refused by the command (it is a 0U occupant added from the
      // inspector, AC-044), so there is nothing to compare for it — the
      // starters place it through `addZeroUDevice`, which is the path
      // AC-044 names.
      if (result is! CatalogPlacementReady) continue;
      compared++;
      expect(
        starterDeviceKindFor(entry.key, entry.value),
        result.command.kind,
        reason: '${entry.key}: starter authoring and the palette disagree',
      );
    }
    expect(compared, greaterThan(40), reason: 'a vacuous scan proves nothing');
  });

  test('two copies of the same starter never share a document id', () async {
    // The property `DocumentStore.decodeBytes`'s `asNewDocumentId` exists
    // for: a shared id means a shared recovery snapshot path
    // (`recovery/<docUuid>.rmpj`), so recovering one copy would offer
    // the other's work.
    final bytes = await loadStarterAssetFromBundle(
      kStarterProjects.first.assetPath,
    );
    final a = await store.decodeBytes(
      path: null,
      bytes: bytes,
      asNewDocumentId: 'copy-a',
    );
    final b = await store.decodeBytes(
      path: null,
      bytes: bytes,
      asNewDocumentId: 'copy-b',
    );
    expect((a as Ok<OpenedDocument>).value.document.id.v, 'copy-a');
    expect((b as Ok<OpenedDocument>).value.document.id.v, 'copy-b');
    expect(a.value.path, isNull, reason: 'a starter opens as untitled');

    // And the rewrite touches ONLY the id: everything else is the file.
    final untouched = await store.decodeBytes(path: null, bytes: bytes);
    expect(
      (untouched as Ok<OpenedDocument>).value.document.racks.length,
      a.value.document.racks.length,
    );
    expect(
      untouched.value.document.info.projectName,
      a.value.document.info.projectName,
    );
  });

  test('the four are genuinely different documents', () {
    // A guard against the failure mode where four files exist and three
    // of them are copies. Compares the shape of each, not the bytes.
    final shapes = <String>{};
    for (final source in kStarterSources) {
      final doc = source.build();
      shapes.add(
        '${doc.racks.length}/${doc.devices.length}/${doc.links.length}/'
        '${doc.outlets.length}/${doc.locations.length}/'
        '${doc.racks.values.map((r) => r.heightU).join(",")}',
      );
    }
    expect(shapes, hasLength(4), reason: 'two starters have the same shape');
  });

  test('an asset handed back as a ByteData VIEW yields only its own '
      'bytes', () {
    // THIS TEST EXISTS BECAUSE THE MUTATION SURVIVED. Replacing
    // `bytesOfAssetData`'s offset-aware conversion with
    // `buffer.asUint8List()` left the entire starter suite GREEN: every
    // `ByteData` this bundle returns happens to span its whole buffer,
    // so nothing could tell the two apart. A bundle implementation that
    // packs assets into one buffer — which `AssetBundle` is explicitly
    // allowed to do — would then hand the codec a file with its
    // neighbours glued to both ends.
    final buffer = Uint8List.fromList([
      ...List<int>.filled(7, 0xAA),
      ...utf8.encode('the asset'),
      ...List<int>.filled(5, 0xBB),
    ]);
    final view = ByteData.view(buffer.buffer, 7, 9);
    expect(utf8.decode(bytesOfAssetData(view)), 'the asset');
    expect(bytesOfAssetData(view), hasLength(9));
  });

  test('rootBundle serves the DECLARED bundle, not the working '
      'directory', () async {
    // THE CONTROL FOR THE FOUR `rootBundle` TESTS ABOVE. Without it,
    // "the starter loads through rootBundle" would also pass if
    // `rootBundle` were quietly reading files relative to the package
    // root — and the four assets would then be absent from the SHIPPED
    // application while every test stayed green, which is a failure only
    // a user would find.
    //
    // `pubspec.yaml` certainly exists on disk and is certainly not
    // declared under `flutter: assets:`. It must fail to load.
    expect(File('pubspec.yaml').existsSync(), isTrue);
    Object? thrown;
    try {
      await rootBundle.load('pubspec.yaml');
      // A caught-and-recorded throw rather than `expectLater(...,
      // throwsA)`: `rootBundle` is a `CachingAssetBundle` and caches the
      // FAILED future, which the test zone then reports as an unhandled
      // error before the matcher ever sees it.
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      thrown = error;
    }
    expect(
      thrown,
      isNotNull,
      reason:
          'rootBundle loaded an undeclared file, so the four passing '
          'starter loads prove nothing about pubspec.yaml',
    );
  });
}
