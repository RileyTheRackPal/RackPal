// M5-I (`#307`-`#310`): no rule, at any severity, prevents a PDF.
//
// ═══════════════════════════════════════════════════════════════════════
// CR-022 AND G3, ASSERTED RATHER THAN ASSUMED
// ═══════════════════════════════════════════════════════════════════════
// docs/05 §8: *"Nothing blocks export. `blockExportOnErrors` is
// deleted."* That is easy to believe and easy to lose: the natural thing
// for somebody adding an export precondition is to refuse on an error,
// and the whole product argument against it lives in a document rather
// than in a check. This file is the check.
//
// ═══════════════════════════════════════════════════════════════════════
// THE STAMP `#310` NAMES DOES NOT EXIST YET, AND THAT CHANGES THE
// ASSERTION RATHER THAN EXCUSING IT
// ═══════════════════════════════════════════════════════════════════════
// `#310` asks to prove the `ISSUED FOR CONSTRUCTION` stamp is the ONLY
// thing an error gates, via `ExportSpec.issuedForConstruction`. Measured:
// neither exists. `ExportSpec` appears nowhere in shipped code, there is
// no stamp, and `ExportRequest` carries `documentJson`, `fontBytes`,
// `fileName` and `issuedAt` and nothing else. Canon describes a design
// that M6 will build.
//
// Asserting "the stamp is the only gated thing" against no stamp would be
// vacuous, which is the shape this repository keeps finding in its own
// suite. So the clause is proved in the stronger form available today:
// NOTHING IS GATED, AND THE TYPE SYSTEM SAYS SO. `ExportError` is sealed
// with three arms, and the exhaustive switch below fails to COMPILE if a
// fourth ever appears. When M6 adds the stamp, this file is where the
// tightening lands.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THE PLAN BAND PROVES ITS OWN FOUR (`#646`, PLAN-I/2)
// ═══════════════════════════════════════════════════════════════════════
// `#646` reads *"M5-I ... does not run until M5. This epic ships four
// rules before that milestone exists, so it proves its own four."* **M5-I
// HAS RUN** — that is what the three groups above are — so the brief is
// stale on the timing and right on the obligation: the groups above sweep
// `kRuleCatalogue`, which is one band of two since DR-154, and a `PLN-*`
// is outside every one of them.
//
// So the fourth group is the same property over the other band, and it is
// not a copy: `PLN-004` is a WARNING and the other three are advisories
// (DR-154 §11.153.5), the fixture needs a real raster member to resolve,
// and "a complete sheet set" is asserted on the PAGE rather than on a
// count, because `T1.01` is the sheet these four rules are about.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

import 'support/content_stream.dart';

const FontRef _font = FontRef('Jost');
const String _member = 'underlays/level-1.png';

void main() {
  final at = DateTime.utc(2026, 9, 4, 12);
  EntityMeta meta() => EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'i');

  Uuid id(int n) =>
      Uuid('0190e0ff-0000-7000-8000-${n.toString().padLeft(12, '0')}');

  const rackId = Uuid('0190e0ff-0000-7000-8000-0000000000ff');

  TemplateBody body({int frontU = 2, Mass? weight}) => TemplateBody(
    manufacturer: 'FX',
    model: 'fx',
    displayName: 'A device',
    frontU: frontU,
    side: OccupancySide.front,
    weight: weight,
  );

  void place(RackDocument doc, TemplateBody b, int ru, int seq, String des) {
    final key = 'fx$seq';
    doc.templates[templateKey(key, 1)] = TemplateSnapshot(
      templateId: TemplateId(key),
      version: 1,
      contentHash: 'sha256:$key',
      body: b,
      capturedAt: at,
    );
    doc.devices[id(seq)] = DeviceInstance(
      id: id(seq),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(key),
        version: 1,
        contentHash: 'sha256:$key',
      ),
      designator: des,
      name: 'A device',
      placement: RailPlacement(rackId: rackId, ruIndex: ru, face: Face.front),
      meta: meta(),
    );
  }

  /// `#308`: ONE project carrying an open finding at every severity.
  ///
  /// Three rules chosen because their severities differ and their
  /// conditions do not interfere: an RU overlap is an ERROR, a rack in
  /// `RCK-003`'s WARNING band (85% to capacity, DR-125) is a warning, and
  /// a home run still on the wall is an ADVISORY.
  RackDocument troubled() {
    final doc = RackDocument(
      id: id(0),
      appVersion: '0.5.54',
      createdAt: at,
      modifiedAt: at,
      meta: meta(),
      info: ProjectInfo(projectName: 'EVERY SEVERITY'),
      registries: buildSeedRegistries(),
    );
    doc.racks[rackId] = Rack(
      id: rackId,
      name: 'HEAD END',
      designator: 'RK-1',
      heightU: 24,
      order: const FracIndex('a0'),
      weightCapacity: Mass.fromKilograms(50),
      meta: meta(),
    );
    // ERROR: two devices in the same rack space. Their mass also has to
    // land RCK-003 in its WARNING band and not its error one, which is a
    // constraint DR-125 introduced: 44 of 50 kg is 88%, inside the 85%
    // warning band and under capacity.
    //
    // IT WAS 40 kg EACH AND THAT NOW READS AS AN ERROR. 80 of 50 kg is
    // 160%, so this fixture briefly carried two errors and no warning and
    // stopped being the every-severity fixture its own name promises. The
    // test caught it, which is the point of asserting the rules BY NAME
    // rather than asserting a set of severities.
    place(doc, body(weight: Mass.fromKilograms(22)), 1, 1, 'A-1');
    place(doc, body(weight: Mass.fromKilograms(22)), 2, 2, 'A-2');

    // ADVISORY: a home run whose far end is still on the wall.
    final link =
        Link(
            id: id(10),
            designator: 'W001',
            media: const MediaTypeId('media.rg6'),
            order: const FracIndex('a1'),
            conductors: [
              const Conductor(
                role: 'pair',
                from: PlaceEndpoint(description: 'wall'),
                to: PlaceEndpoint(description: 'wall'),
              ),
            ],
            services: [
              Service(
                id: 'svc',
                signalFamily: const SignalFamilyId('video.composite'),
                netId: id(11),
              ),
            ],
            meta: meta(),
          )
          ..structureOrigin = StructureOrigin(
            structureBodyId: id(12),
            outletId: id(13),
            fieldLabel: 'LR-1',
          );
    // NO `terminatedLength`: it is `@internal` (AC-013) and this test
    // lives in another package. An unmeasured run is itself a finding
    // (docs/02 §5.3), which costs this fixture nothing: it needs the
    // three severities open, not one particular rule.
    doc.links[link.id] = link;
    return doc;
  }

  /// A 2x2 opaque PNG. The image is not the subject; the sheet only has
  /// to resolve one, because an unresolvable underlay throws (docs/15
  /// §7).
  Uint8List png() {
    final image = im.Image(width: 2, height: 2, numChannels: 4)
      ..setPixelRgba(0, 0, 255, 255, 255, 255)
      ..setPixelRgba(1, 0, 0, 0, 0, 255)
      ..setPixelRgba(0, 1, 128, 128, 128, 255)
      ..setPixelRgba(1, 1, 255, 255, 255, 255);
    return Uint8List.fromList(im.encodePng(image));
  }

  const underlayId = Uuid('0190e0ff-0000-7000-8000-0000000000e0');
  const floorId = Uuid('0190e0ff-0000-7000-8000-0000000000e1');
  const roomId = Uuid('0190e0ff-0000-7000-8000-0000000000e2');
  const basementId = Uuid('0190e0ff-0000-7000-8000-0000000000e3');

  /// `#646`: ONE project on which all four `PLN-*` are open at once.
  ///
  /// Uncalibrated with a pinned drop (`PLN-001`), a second drop in the
  /// same room with no pin (`PLN-002`), the head end in the basement so
  /// nothing measures from the plan (`PLN-003`), and the bytes reported
  /// changed (`PLN-004`). One outlet cannot be both pinned and unpinned,
  /// which is why there are two.
  RackDocument troubledPlan() {
    final doc = RackDocument(
      id: id(20),
      appVersion: '0.6.46',
      createdAt: at,
      modifiedAt: at,
      meta: meta(),
      info: ProjectInfo(projectName: 'EVERY PLAN ADVISORY'),
      registries: buildSeedRegistries(),
    );
    for (final entry in const <Uuid, List<String>>{
      floorId: ['Level 1', 'L1'],
      basementId: ['Basement', 'B1'],
    }.entries) {
      doc.locations[entry.key] = Location(
        id: entry.key,
        kind: LocationKind.floor,
        name: entry.value[0],
        code: entry.value[1],
        order: FracIndex('a${entry.value[1]}'),
        meta: meta(),
      );
    }
    // THE ROOM IS A CHILD OF THE FLOOR, which is how the trade files a
    // job and the scope DR-154 §11.153.7a widened `PLN-002` to.
    doc.locations[roomId] = Location(
      id: roomId,
      kind: LocationKind.room,
      name: 'Great Room',
      code: 'GR',
      order: const FracIndex('a2'),
      parentId: floorId,
      meta: meta(),
    );
    doc.underlays[underlayId] = PlanUnderlay(
      id: underlayId,
      name: 'Level 1',
      imageMember: _member,
      format: PlanImageFormat.png,
      pixelWidth: 2,
      pixelHeight: 2,
      contentHash: 'sha256:${'0' * 64}',
      order: const FracIndex('a0'),
      meta: meta(),
      locationId: floorId,
    );
    doc.racks[rackId] = Rack(
      id: rackId,
      name: 'HEAD END',
      designator: 'RK-1',
      heightU: 24,
      order: const FracIndex('a0'),
      meta: meta(),
      locationId: basementId,
    );
    for (final (seq, pinned) in const <(int, bool)>[(30, true), (31, false)]) {
      doc.outlets[id(seq)] = Outlet(
        id: id(seq),
        structureBodyId: id(40),
        designation: 'WP-${seq - 29}',
        order: FracIndex('a$seq'),
        meta: meta(),
        locationId: roomId,
        gangs: <Gang>[Gang()],
        planPin: pinned
            ? const PlanPin(underlayId: underlayId, at: PxPt(1, 1))
            : null,
      );
    }
    return doc;
  }

  late Uint8List fontBytes;
  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  Future<Outcome<ExportedDocument>> exportOf(
    RackDocument doc, {
    Map<String, Uint8List> members = const <String, Uint8List>{},
  }) => buildExportDocument(
    ExportRequest(
      documentJson: const JsonDocumentCodec().write(doc),
      fontBytes: <FontRef, Uint8List>{_font: fontBytes},
      fileName: 'every-severity.rmpj',
      issuedAt: at,
      members: members,
    ),
  );

  group('#308 — the fixture really does carry every severity', () {
    test('error, warning and advisory are all open on it', () {
      // NOT VACUOUS: without this the export test below could pass over a
      // project with no findings at all, which is the assertion it is
      // supposed to be making the hard case for.
      final found = evaluateDocument(troubled());
      final severities = {for (final f in found) f.severity};
      // WHICH RULES, BY NAME, and not merely that three severities turned
      // up. A fixture edit that lost one source and gained another would
      // satisfy a set-of-severities assertion and quietly stop testing
      // what this file says it tests.
      expect(
        {for (final f in found) f.ruleId: f.severity.name},
        {
          'RCK-001': 'error',
          'RCK-003': 'warning',
          'LNK-020': 'advisory',
        },
      );
      expect(
        severities,
        containsAll(<Severity>[
          Severity.error,
          Severity.warning,
          Severity.advisory,
        ]),
        reason: 'found: ${found.map((f) => '${f.ruleId}:${f.severity.name}')}',
      );
    });
  });

  group('#309 — the bytes reach disk anyway', () {
    test('a project with open errors still exports', () async {
      final result = await exportOf(troubled());
      expect(
        result,
        isA<Ok<ExportedDocument>>(),
        reason: result is Err<ExportedDocument>
            ? (result.error as ExportError).message
            : null,
      );
    });

    test('and the bytes are a real PDF written to a real file', () async {
      // "REACH DISK" TAKEN LITERALLY. `buildExportDocument` hands back
      // bytes; a test that only checked the length would not have shown
      // that the deliverable survives being written, which is what a
      // person actually does with it.
      final result = await exportOf(troubled()) as Ok<ExportedDocument>;
      final dir = Directory.systemTemp.createTempSync('rackpal-m5i');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/every-severity.pdf')
        ..writeAsBytesSync(result.value.bytes);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), result.value.bytes.length);
      expect(file.lengthSync(), greaterThan(1000));
      // A PDF, not merely some bytes.
      expect(
        String.fromCharCodes(file.readAsBytesSync().take(5)),
        '%PDF-',
      );
      expect(result.value.sheetCount, greaterThan(0));
    });

    test('every severity, taken one at a time, still exports', () async {
      // The clause says "at ANY severity". A project whose only finding
      // is an error is the case somebody would most expect to be refused.
      for (final severity in <Severity>[
        Severity.error,
        Severity.warning,
        Severity.advisory,
      ]) {
        final doc = troubled();
        // Turn the other two off, leaving exactly one severity open.
        //
        // `kRulesById` AND NOT `kRuleCatalogue`, WHICH IS BOTH BANDS. On
        // this fixture the plan rules fire nothing, so the widening
        // changes no result here; it is the difference between a loop
        // that means "every rule" and one that happens to.
        for (final rule in kRulesById.values) {
          if (rule.defaultSeverity == null) continue;
          if (rule.defaultSeverity == severity) continue;
          doc.settings.ruleOverrides[rule.ruleId] = RuleOverride(
            severity: Severity.off,
            reason: 'scoped for this test',
            by: 'test',
            at: at,
          );
        }
        final open = {for (final f in evaluateDocument(doc)) f.severity};
        expect(open, isNotEmpty, reason: 'nothing left at ${severity.name}');
        expect(
          await exportOf(doc),
          isA<Ok<ExportedDocument>>(),
          reason: 'refused with only ${severity.name} findings open',
        );
      }
    });
  });

  group('#310 — nothing is gated, and the type system says so', () {
    test('no ExportError arm is about a rule, exhaustively', () {
      // THE SWITCH IS THE GATE. `ExportError` is sealed, so a fourth arm
      // makes this file fail to COMPILE, and whoever adds "export refused
      // because the project has errors" has to come here and argue with
      // CR-022 rather than ship past it.
      final arms = <ExportError>[
        ExportDocumentUnreadable(Exception('x')),
        const ExportNoRacks(),
        const ExportFontMissing(_font),
      ];
      for (final arm in arms) {
        final about = switch (arm) {
          ExportDocumentUnreadable() => 'the file could not be read back',
          ExportNoRacks() => 'the project has no racks to draw',
          ExportFontMissing() => 'a font was not supplied',
        };
        expect(about, isNotEmpty);
        expect(arm.message, isNotEmpty);
      }
    });

    test('the exporter asks for the findings in ONE place, to print them on '
        'T0.02, and reads nothing else of the rules', () {
      // A second cue, and the reason the switch above is honest.
      //
      // THIS TEST SAID "never consults the rules at all" UNTIL M6-C, and
      // that was the right claim while nothing printed them. CR-022 has
      // two halves: the findings never withhold the bytes, AND every
      // export emits T0.02 "so the errors travel with the document"
      // (docs/08 §1). Printing them means asking for them. So the claim is
      // now the narrow one: `evaluateDocument` is named once, in
      // `build_document.dart`, inside the T0.02 dry run, and its result
      // goes to `buildExceptionsReport` and nowhere else; every other
      // needle stays forbidden. Moving the call behind a core helper so
      // this scan stopped seeing it would have kept the old words and lost
      // their point.
      //
      // A source scan for the same reason `status_marker_source_test.dart`
      // is one, and it is not vacuous: it walks a package that really
      // does contain Dart.
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files.length, greaterThan(4), reason: 'the scan found nothing');

      final offenders = <String>[];
      for (final f in files) {
        final src = f.readAsStringSync();
        // THE ONE PERMITTED READ: the findings, straight into T0.02's
        // report. Counted, so a second call anywhere is an offender.
        const permitted = 'buildExceptionsReport(doc, evaluateDocument(doc))';
        if (src.contains('evaluateDocument')) {
          final calls = 'evaluateDocument'.allMatches(src).length;
          final asPermitted = permitted.allMatches(src).length;
          if (!f.path
                  .replaceAll(r'\', '/')
                  .endsWith(
                    'src/document/build_document.dart',
                  ) ||
              calls != 1 ||
              asPermitted != 1) {
            offenders.add('${f.path}: evaluateDocument outside T0.02');
          }
        }
        for (final needle in const [
          'kDrcRules',
          // BOTH BANDS AND THE JOINT REGISTRY (DR-154). A scan naming one
          // catalogue would let the exporter learn about the other.
          'kPlanDrcRules',
          'kPlanRules',
          'kRulesById',
          'AckedFinding',
          'blockExportOnErrors',
        ]) {
          if (src.contains(needle)) {
            offenders.add('${f.path}: $needle');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'CR-022: the exporter reads the findings only to print them on '
            'T0.02, and reads nothing else of the rules',
      );
    });
  });

  group('#646 — and four open plan advisories cannot either', () {
    const changed = <Uuid>{underlayId};

    test('the fixture really does carry all four, by name', () {
      // THE CONTROL, on `#308`'s reasoning one band over: a sheet set
      // exported from a document with no plan findings proves nothing
      // about a document with four.
      final found = evaluateDocument(troubledPlan(), changedUnderlays: changed);
      expect(
        {for (final f in found) f.ruleId: f.severity.name},
        {
          'PLN-001': 'advisory',
          'PLN-002': 'advisory',
          'PLN-003': 'advisory',
          'PLN-004': 'warning',
        },
      );
    });

    test('and a COMPLETE sheet set comes out: the plan is on the paper, '
        'not merely counted', () async {
      final result =
          await exportOf(
                troubledPlan(),
                members: <String, Uint8List>{_member: png()},
              )
              as Ok<ExportedDocument>;

      // ONE PLAN + TWO ELEVATIONS + ONE EQUIPMENT LIST. Derived rather
      // than written as `4`, because `SheetSet.forRacks` is where that
      // arithmetic lives and a literal here would be a second copy of it.
      final doc = troubledPlan();
      final expected = SheetSet.forRacks(
        doc.racks.values,
        planUnderlays: planUnderlaysWithPins(doc),
      );
      expect(result.value.sheetCount, expected.sheets.length);

      // THE SHEET ITSELF, READ OFF THE PAGE. A `sheetCount` of five is
      // satisfied by five blank pages, and `T1.01` is the sheet these
      // four rules are about: a plan whose advisories held it back would
      // still have exported the elevations and the schedule.
      final cmap = parseToUnicodeCMap(result.value.bytes);
      final texts = <String>[
        for (final body in operatorStreams(result.value.bytes))
          ...interpretContentStream(body, toUnicode: cmap).texts.map(
            (t) => t.text,
          ),
      ];
      // THE RUNS AS THEY ACTUALLY READ. The title block draws
      // `SHEET NO.  T1.01` and the footer `SHEET 1 OF 4 · DEVICE LOCATION
      // PLAN` as single runs, so a bare `contains('T1.01')` fails against
      // a page that plainly has it. Asserted on the substring rather than
      // rewritten to the exact string, which would pin the label's
      // spacing and break on a title-block edit that changes nothing
      // about this claim.
      expect(texts, anyElement(contains('T1.01')));
      expect(texts, anyElement(contains(SheetRole.devicePlan.title)));
      expect(
        texts,
        contains('WP-1'),
        reason: 'the pinned drop earns a callout, so the plan drew content',
      );
    });

    test('the warning alone does not hold it either, which is the one that '
        'is not an advisory', () async {
      // DR-154 §11.153.5 made `PLN-004` a warning, and `#646`'s own brief
      // says "all four are advisory". A loop that turned the advisories
      // off and left the warning is the case that sentence would have
      // skipped.
      final doc = troubledPlan();
      for (final id in const ['PLN-001', 'PLN-002', 'PLN-003']) {
        doc.settings.ruleOverrides[id] = RuleOverride(
          severity: Severity.off,
          reason: 'scoped for this test',
          by: 'test',
          at: at,
        );
      }
      final open = evaluateDocument(doc, changedUnderlays: changed);
      expect(
        open.map((f) => f.ruleId),
        ['PLN-004'],
        reason: 'the scoping left the wrong rule open',
      );
      expect(
        await exportOf(doc, members: <String, Uint8List>{_member: png()}),
        isA<Ok<ExportedDocument>>(),
      );
    });

    test('nor does acknowledging change whether it exports, because '
        'nothing was gating on it', () async {
      // CR-022 from the other side. An acknowledgement is for the reader
      // of `T0.02`, not a key that unlocks the exporter, and a product
      // where muting a rule made an export succeed would have taught
      // people to mute rules.
      final doc = troubledPlan();
      final finding = evaluateDocument(
        doc,
        changedUnderlays: changed,
      ).firstWhere((f) => f.ruleId == 'PLN-004');
      doc.ackedFindings[id(50)] = AckedFinding(
        id: id(50),
        ruleId: 'PLN-004',
        targetFingerprint: finding.targetFingerprint,
        reason: 'Re-imported from the same survey; the pins were re-checked.',
        by: 'test',
        at: at,
        demotedTo: Severity.advisory,
        meta: meta(),
      );

      final result = await exportOf(
        doc,
        members: <String, Uint8List>{_member: png()},
      );
      expect(result, isA<Ok<ExportedDocument>>());
      expect(
        (result as Ok<ExportedDocument>).value.sheetCount,
        // The cover, the legend, T0.02, the plan, two elevations and the
        // list (M6-A, M6-B, M6-C).
        7,
        reason: 'the same set as the unacknowledged run',
      );

      // AND THE REASON PRINTS ON T0.02, which is the assertion a test
      // here waited for until M6-C ("T0.02 IS NOT ASSERTED HERE, AND M6 IS
      // WHY", retired by this). The exporter evaluates without the
      // session's `changedUnderlays`, so `PLN-004` does not fire at export
      // and this acknowledgement prints under NO LONGER OCCURS: the
      // signed reason reaches the sheet either way (DR-214 §11.213.4).
      final bytes = result.value.bytes;
      final cmap = parseToUnicodeCMap(bytes);
      final t002 = [
        for (final body in operatorStreams(bytes))
          interpretContentStream(body, toUnicode: cmap).allText,
      ].singleWhere((t) => RegExp(r'SHEET NO\.\s+T0\.02').hasMatch(t));
      expect(
        t002,
        contains('Re-imported from the same survey; the pins were'),
        reason: 'the acknowledgement reason does not reach T0.02',
      );
    });
  });
}
