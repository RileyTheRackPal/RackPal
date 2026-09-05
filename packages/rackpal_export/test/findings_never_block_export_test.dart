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
import 'dart:io';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/rackpal_export.dart';
import 'package:test/test.dart';

const FontRef _font = FontRef('Jost');

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

  late Uint8List fontBytes;
  setUpAll(() {
    fontBytes = File(
      '../../apps/rackpal/assets/fonts/Jost-Regular.ttf',
    ).readAsBytesSync();
  });

  Future<Outcome<ExportedDocument>> exportOf(RackDocument doc) =>
      buildExportDocument(
        ExportRequest(
          documentJson: const JsonDocumentCodec().write(doc),
          fontBytes: <FontRef, Uint8List>{_font: fontBytes},
          fileName: 'every-severity.rmpj',
          issuedAt: at,
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
        for (final rule in kRuleCatalogue) {
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

    test('the exporter never consults the rules at all', () {
      // A second cue, and the reason the switch above is honest: the
      // package cannot gate on a finding it never asks for. This is a
      // source scan for the same reason `status_marker_source_test.dart`
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
        for (final needle in const [
          'evaluateDocument',
          'kDrcRules',
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
        reason: 'CR-022: the exporter must not read the rules',
      );
    });
  });
}
