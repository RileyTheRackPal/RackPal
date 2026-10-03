// rackpal_export/lib/src/document/build_document.dart -- the ONE entry
// point that turns a project into PDF bytes.
//
// =====================================================================
// WHAT THIS FILE IS ALLOWED TO DO, AND WHAT IT IS NOT
// =====================================================================
// It resolves the sheet list, asks `rackpal_core` for one `DiagramScene`
// per page, wraps each in a `pw.Page`, sets the document metadata and
// calls `save()`. It contributes NO GEOMETRY. Every coordinate on every
// sheet comes from `rackpal_core/draw/sheet/`, which is what makes the
// on-screen sheet preview faithful by construction rather than by promise:
// `rackpal_ui` can replay the identical scene objects through
// `FlutterDiagramCanvas` without importing this package (docs/03 section
// 7.1 forbids that import, which is why the layout could not live here --
// see the M1 log's pass-1 note).
//
// dart_pdf is used as a byte writer and a TrueType embedder. Not one mark
// on any sheet comes from a `pw.Text`, a `pw.Table` or a `pw.MultiPage`.
//
// =====================================================================
// THE ORDER IS FORCED, AND EACH STEP IS FORCED BY THE ONE BEFORE IT
// =====================================================================
//   1. decode the document
//   2. build the equipment list and PAGINATE it        -- pure core
//   3. resolve the sheet set from (racks, schedule pages)
//   4. render each sheet
//
// Step 2 must precede step 3 because "SHEET i OF n" needs `n`, and `n`
// depends on how many pages the schedule actually takes. A running counter
// incremented during step 4 would be right for the exit criterion's
// one-rack, one-page project and wrong for a two-rack one -- which is
// exactly the bug that ships, because the exit criterion only exercises
// the case where it works.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_export/src/document/export_request.dart';
import 'package:rackpal_export/src/draw/plan_image.dart';
import 'package:rackpal_export/src/sheets/sheet_page.dart';
import 'package:rackpal_text/rackpal_text.dart';

/// What the PDF's `/Producer` and `/Creator` say.
const String kPdfProducer = 'RackPal';

/// Builds the three-sheet set (`2N + schedule pages`) for [request].
///
/// Returns an [Outcome] rather than throwing: "this project has no racks"
/// is a fact the caller reports to the user, not a programmer error
/// (CR-093).
///
/// Called SYNCHRONOUSLY on the main isolate in M1. Its argument carries
/// only bytes, so moving it behind `Isolate.spawn` later is a one-line
/// change with no refactor -- see `export_request.dart`.
Future<Outcome<ExportedDocument>> buildExportDocument(
  ExportRequest request,
) async {
  final decoded = const JsonDocumentCodec().read(request.documentJson);
  if (decoded case Err(:final error)) {
    return Err(ExportDocumentUnreadable(error));
  }
  final doc = (decoded as Ok<RackDocument>).value;
  if (doc.racks.isEmpty) return const Err(ExportNoRacks());

  final pdf = pw.Document(
    title: doc.info.projectName,
    author: doc.info.integratorName,
    creator: kPdfProducer,
    subject: doc.info.clientName,
    // NO `producer`/`keywords` beyond this: section 8.4 asks for findable
    // metadata, and every field here resolves from `ProjectInfo` rather
    // than being typed at export time, exactly like the title block.
  );

  final missing = _missingFont(request.fontBytes);
  if (missing != null) return Err(ExportFontMissing(missing));

  final fonts = <FontRef, PdfFont>{
    for (final entry in request.fontBytes.entries)
      entry.key: PdfTtfFont(pdf.document, ByteData.sublistView(entry.value)),
  };
  final measurer = PdfFontMeasurer(fonts);

  // ---- steps 2 and 3: paginate, THEN resolve the sheet list ------------
  // THE STAMP IS DECIDED FIRST (DR-216 §11.215.2), because it changes every
  // sheet's drawing area and so the dry runs below must see it. The
  // findings are evaluated ONCE, here, and this same report is what T0.02
  // lays out and draws (DR-214 §11.213.5).
  final report = buildExceptionsReport(doc, evaluateDocument(doc));
  final openErrors = report.openErrorCount;
  // CR-022: an open error withholds the stamp, NEVER the bytes.
  final stamped = request.issuedForConstruction && openErrors == 0;

  final list = buildEquipmentList(doc);
  // ONE SCHEDULE FOR THE ROLLUPS THAT READ IT: the footage excludes the
  // jumpers the jumper rollup counts, and the two are one set of rows.
  final schedule = buildSchedule(doc);
  final schedulePages = paginateEquipmentList(
    list: list,
    drawingArea: SheetLayout.resolve(
      geometry: const SheetGeometry(SheetSize.ansiALandscape),
      revisionRowCount: revisionBodyRowCount(doc.revisionBlock),
      stamped: stamped,
    ).drawingArea,
    measurer: measurer,
    units: doc.settings.displayUnits,
    // THE ROLLUPS RIDE IN THE DRY RUN (docs/08 §2.2, DR-219), because
    // they add pages and `SHEET i OF n` must count them.
    sections: <RollupSection>[
      footageSection(
        cableFootageOf(schedule, doc: doc),
        doc.settings.displayUnits,
      ),
      // From `report`, the one evaluation T0.02 draws (DR-214 §11.213.5).
      hardwareSection(doc, report),
      jumperSection(jumperRollupOf(schedule), doc.settings.displayUnits),
      outletMapSection(doc, buildOutletMap(doc)),
    ],
  );
  // WHICH PLANS EARN A SHEET IS A DERIVATION, NOT A DRAWING DECISION
  // (docs/15 section 8: one per underlay THAT CARRIES AT LEAST ONE PIN).
  // Resolved here and handed in, exactly as `equipmentListSheets` is: the
  // dry run has to know the total before any sheet is drawn, or
  // "SHEET i OF n" is wrong.
  final plans = planUnderlaysWithPins(doc);
  // T0.02's PAGES ARE A DRY RUN TOO (DR-214 §11.213.5): `report` above is
  // the one evaluation, laid out here and drawn below, so the sheet and
  // `SHEET i OF n` cannot come from two evaluations.
  final exceptionPages = paginateExceptions(
    report: report,
    doc: doc,
    drawingArea: SheetLayout.resolve(
      geometry: const SheetGeometry(SheetSize.ansiBLandscape),
      revisionRowCount: revisionBodyRowCount(doc.revisionBlock),
      stamped: stamped,
    ).drawingArea,
    measurer: measurer,
    issuedAt: request.issuedAt,
  );
  // T6.20 IS AUTO, AND THE PAGE COUNT SAYS SO (DR-220): no unused home run
  // paginates to no page, and zero pages is the sheet absent from the file
  // and the index alike (M6-E3). From `schedule`, the one built above.
  final unusedPages = paginateUnusedRuns(
    rooms: unusedHomeRunsOf(schedule, doc),
    drawingArea: SheetLayout.resolve(
      geometry: const SheetGeometry(SheetSize.ansiALandscape),
      revisionRowCount: revisionBodyRowCount(doc.revisionBlock),
      stamped: stamped,
    ).drawingArea,
    measurer: measurer,
    units: doc.settings.displayUnits,
  );
  // T5.01 IS AUTO TOO (DR-221): nothing non-standard paginates to no page.
  final pinoutPages = paginatePinoutDetails(
    details: pinoutDetailsOf(doc, schedule),
    settings: doc.settings,
    drawingArea: SheetLayout.resolve(
      geometry: const SheetGeometry(SheetSize.ansiALandscape),
      revisionRowCount: revisionBodyRowCount(doc.revisionBlock),
      stamped: stamped,
    ).drawingArea,
    measurer: measurer,
  );
  // T6.10 AND T6.15 ARE `ON` (docs/08 §2.2, DR-222): paginated from the
  // export's one schedule, through M3's own projection, so the page and
  // the Schedule screen are one view. Each is at least one page.
  final pullView = buildScheduleView(
    schedule,
    preset: SchedulePreset.pullSheet,
  );
  final terminationView = buildScheduleView(
    schedule,
    preset: SchedulePreset.terminationSchedule,
  );
  DBox drawingAreaOf(SheetSize size) => SheetLayout.resolve(
    geometry: SheetGeometry(size),
    revisionRowCount: revisionBodyRowCount(doc.revisionBlock),
    stamped: stamped,
  ).drawingArea;
  final pullPages = paginateSchedule(
    view: pullView,
    title: SheetRole.pullSheet.title,
    registries: doc.registries,
    drawingArea: drawingAreaOf(SheetRole.pullSheet.size),
    measurer: measurer,
    units: doc.settings.displayUnits,
  );
  final terminationPages = paginateSchedule(
    view: terminationView,
    title: SheetRole.terminationSchedule.title,
    registries: doc.registries,
    drawingArea: drawingAreaOf(SheetRole.terminationSchedule.size),
    measurer: measurer,
    units: doc.settings.displayUnits,
  );
  // T6.01… ARE A DRY RUN TOO (DR-225): which domains get a sheet is read
  // off the WHOLE schematic, every bank expanded so no cable on a collapsed
  // bank is lost before its sheet is chosen (§11.224.7), and each sheet is
  // laid out and fitted here, once, so the set, the legend and the sheet
  // are all told the same thing about it.
  final partitioning = interconnectPartitionsOf(
    buildSchematicScene(
      doc: doc,
      measurer: measurer,
      expandedBanks: allBanksExpanded(doc),
    ),
  );
  final interconnectArea = interconnectDrawingArea(
    revisionRowCount: revisionBodyRowCount(doc.revisionBlock),
    stamped: stamped,
  );
  final interconnects = <InterconnectDrawing>[
    for (final partition in partitioning.partitions)
      layoutInterconnect(
        doc: doc,
        partition: partition,
        measurer: measurer,
        area: interconnectArea,
      ),
  ];
  final set = SheetSet.forRacks(
    doc.racks.values,
    interconnectDomains: <SignalDomainDef>[
      for (final partition in partitioning.partitions)
        doc.registries.signalDomains[partition.domain]!,
    ],
    pullSheets: pullPages.length,
    terminationSheets: terminationPages.length,
    pinoutSheets: pinoutPages.length,
    exceptionSheets: exceptionPages.length,
    unusedHomeRunSheets: unusedPages.length,
    equipmentListSheets: schedulePages.length,
    planUnderlays: plans,
    stamped: stamped,
    numbering: doc.settings.sheetNumbering,
  );

  // ONE RESOLVER FOR THE WHOLE DOCUMENT, so a member decoded for sheet 1
  // is not decoded again for sheet 2 and the document holds one XObject
  // per underlay rather than one per sheet. Built even when `plans` is
  // empty, which costs an empty map: the alternative is a nullable that
  // every call site has to reason about.
  final images = planImageResolver(pdf.document, request.members);

  // ---- step 4: render -------------------------------------------------
  // NOT A NOTICE. It answers the question the user asked (DR-216
  // §11.215.1): they chose Export for construction and did not get the
  // stamp. A notice is counted on the status line and never read out, so
  // this rides in its own field and the status line prints it whole.
  final String? stampWithheld;
  if (request.issuedForConstruction && !stamped) {
    final exceptionsId = set.sheets
        .firstWhere((s) => s.role == SheetRole.exceptions)
        .ncsId;
    final noun = openErrors == 1 ? 'error' : 'errors';
    stampWithheld = 'not stamped: $openErrors open $noun, see $exceptionsId';
  } else {
    stampWithheld = null;
  }
  final notices = <String>[...set.notices];
  // A PATHWAY PRINTED WITHOUT A DESIGNATOR IS NAMED (DR-223 §11.222.2):
  // the column is sized for one, and the notice says where to type it.
  final pullId = set.sheets
      .firstWhere((s) => s.role == SheetRole.pullSheet)
      .ncsId;
  if (undesignatedPathwayNotice(pullView, pullId) case final notice?) {
    notices.add(notice);
  }
  // A CABLE WHOSE TYPE RESOLVES TO NO DOMAIN IS ON NO INTERCONNECT SHEET,
  // and saying so is the whole of what G4 asks: a drawing set that quietly
  // omits a run is indistinguishable from one that lost it.
  if (partitioning.unresolvedLinkIds case final ids when ids.isNotEmpty) {
    final names = [for (final id in ids) doc.links[id]!.designator]..sort();
    notices.add(
      '${ids.length} cable${ids.length == 1 ? '' : 's'} with a type that '
      'resolves to no signal domain ${ids.length == 1 ? 'is' : 'are'} on no '
      'interconnect sheet: ${names.join(', ')}.',
    );
  }
  var interconnectSheet = 0;
  var schedulePage = 0;
  var exceptionPage = 0;
  var unusedPage = 0;
  var pullPage = 0;
  var terminationPage = 0;
  var pinoutPage = 0;
  for (final sheet in set.sheets) {
    final DiagramScene scene;
    final LegibilityReport legibility;

    switch (sheet.role) {
      case SheetRole.cover:
        final built = buildCoverSheet(
          sheet: sheet,
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
          racks: doc.racks.values,
          devices: doc.devices.values,
          templates: doc.templates,
          landings: PortLandings.of(doc),
          sheets: set.sheets,
        );
        scene = built.scene;
        legibility = built.legibility;
        // A SHEET THE INDEX COULD NOT LIST IS NAMED (§11.211.4): an index
        // that drops a sheet quietly is the one defect an index exists to
        // prevent.
        if (built.indexOmitted.isNotEmpty) {
          notices.add(
            '${sheet.ncsId}: the drawing index lists '
            '${set.sheets.length - built.indexOmitted.length} of '
            '${set.sheets.length} sheets in ${built.indexColumns} columns; '
            '${coverIndexOmittedText(built.indexOmitted)}.',
          );
        }
        // A RACK LEFT OFF THE STRIP IS NAMED, NEVER SILENT (§11.210.4).
        if (built.racksHidden > 0) {
          notices.add(
            '${sheet.ncsId}: ${built.racksHidden} of '
            '${built.racksShown + built.racksHidden} racks did not fit the '
            "cover's rack summary; the closing row names their elevations.",
          );
        }
        // A SCOPE CUT SHORT IS NAMED, NEVER SILENT: the paragraph is the
        // job's description, and half of it reads as the whole.
        if (built.scopeTruncated) {
          notices.add(
            '${sheet.ncsId}: the scope paragraph is longer than '
            '$kCoverScopeMaxLines lines and was cut; shorten it in '
            'File ▸ Sheet set….',
          );
        }
      case SheetRole.exceptions:
        final built = buildExceptionsSheet(
          sheet: sheet,
          page: exceptionPages[exceptionPage++],
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
        );
        scene = built.scene;
        legibility = built.legibility;
      case SheetRole.symbolLegend:
        final built = buildLegendSheet(
          sheet: sheet,
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
          // THE PROJECT'S OWN REGISTRIES, not the seed's, for the plan's
          // reason below (`#901`): a document carries the subset written
          // at its creation.
          registries: doc.registries,
          familiesInUse: {
            for (final link in doc.links.values)
              for (final service in link.services) service.signalFamily,
          },
          // THE MARKS AND BORDERS THIS SET DRAWS (DR-208 §11.207.1): the
          // devices and templates the elevations are drawn from, and the
          // marker kinds the plans in THIS set carry.
          devices: doc.devices.values,
          templates: doc.templates,
          planCarriers: {
            for (final plan in plans)
              for (final pin in planPinsFor(doc, plan.id)) pin.carrier,
          },
        );
        scene = built.scene;
        legibility = built.legibility;
        if (built.omittedBlocks.isNotEmpty) {
          notices.add(
            '${sheet.ncsId}: did not fit the legend: '
            '${built.omittedBlocks.join(', ')}.',
          );
        }
        // A ROW THAT DID NOT FIT IS NAMED, NEVER DROPPED SILENTLY: a key
        // missing a line is a legend that lies by omission.
        if (built.omittedRows > 0) {
          notices.add(
            '${sheet.ncsId}: ${built.omittedRows} cable-type '
            'line${built.omittedRows == 1 ? '' : 's'} did not fit the '
            'legend.',
          );
        }
      case SheetRole.rackElevationFront:
      case SheetRole.rackElevationRear:
        final built = buildElevationSheet(
          sheet: sheet,
          rack: doc.racks[sheet.rackId]!,
          devices: doc.devices.values,
          templates: doc.templates,
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
        );
        scene = built.scene;
        legibility = built.legibility;
        // A SHEET NOBODY MAY SCALE OFF HAS TO SAY SO.
        //
        // `DrawingScale.isToScale` had no production reader anywhere in the
        // repository, so an elevation that left the standard-ratio path
        // reached the user as an ordinary "Exported 3 sheets" -- and the
        // integrator who scales off it finds out on site. Same for an
        // elevation whose content runs past its drawing area, and for one
        // whose device blocks are too short to carry a designator -- the
        // blackout `ElevationLabels` exists to report, which the legibility
        // line structurally CANNOT see (a fragment that emits no text
        // contributes `double.infinity` to the minimum). All three are
        // NOTICES and none gates the bytes (CR-023, G3), exactly like
        // the legibility line below.
        for (final notice in <String?>[
          built.scale.notice,
          built.fit.notice,
          built.labels.notice,
        ]) {
          if (notice != null) notices.add('${sheet.ncsId}: $notice');
        }
      case SheetRole.devicePlan:
        final pins = planPinsFor(doc, sheet.underlayId!);
        final built = buildPlanSheet(
          sheet: sheet,
          underlay: doc.underlays[sheet.underlayId]!,
          pins: pins,
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
          labels: planPinLabelsFor(doc, pins),
          // THE PROJECT'S OWN DOMAINS, not the seed's (`#901`). A document
          // carries the registry subset written at creation (DR-010), so
          // reading the seed here would colour a printed mark from a
          // catalogue the project never saw.
          domains: doc.registries.signalDomains,
          // THE EQUIPMENT LIST THIS EXPORT ALREADY BUILT, handed in rather
          // than rebuilt per plan: CR-107's divergence is two derivations
          // of one fact, and a second build would also pay for the whole
          // device walk once per underlay.
          scheduleRows: planScheduleFor(
            doc,
            sheet.underlayId!,
            equipment: list,
          ),
        );
        scene = built.scene;
        legibility = built.legibility;
        // A TABLE SHORTER THAN THE DRAWING ABOVE IT IS THE DEAD END THIS
        // SCHEDULE EXISTS TO CLOSE, so an omission is named rather than
        // silent. Four blocks at the band's cap hold eighty rows, a third
        // more than the exit criterion's sixty, so this is the last resort
        // DR-152 §11.151.4 describes and not an ordinary path.
        if (built.band.omitted > 0) {
          notices.add(
            '${sheet.ncsId}: the device schedule shows '
            '${built.band.shown} of ${built.band.shown + built.band.omitted} '
            'rows; the rest did not fit.',
          );
        }
        // A CROWDED CALLOUT IS A NOTICE, NEVER A GATE (CR-023, G3), on the
        // elevation's own precedent three cases up. DR-150 §11.149.5 rules
        // that a callout is never DROPPED, so a plan whose drops sit closer
        // together than a pill is wide prints every designator and overlaps
        // some of them. A reader deserves to be told which sheet that is;
        // silently overlapping two designators looks exactly like a sheet
        // with one drop on that wall.
        if (built.callouts.crowdedCount > 0) {
          final n = built.callouts.crowdedCount;
          notices.add(
            '${sheet.ncsId}: $n callout${n == 1 ? '' : 's'} could not be '
            'placed clear of another and overlap.',
          );
        }
      case SheetRole.interconnect:
        final drawing = interconnects[interconnectSheet++];
        // THE FALLBACK IS SAID TWICE (DR-225 §11.224.5): on the sheet, for
        // whoever holds it, and here, for whoever exported it.
        if (drawing.fellBack) {
          notices.add(
            '${sheet.ncsId}: cables shown as net labels; drawn, the '
            'smallest text would print at '
            '${drawing.drawnPaperPt.toStringAsFixed(2)} pt, under the '
            '${kMinPrintPt.toStringAsFixed(0)} pt floor.',
          );
        }
        final built = buildInterconnectSheet(
          sheet: sheet,
          drawing: drawing,
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
        );
        scene = built.scene;
        legibility = built.legibility;
      case SheetRole.pullSheet:
      case SheetRole.terminationSchedule:
        final pull = sheet.role == SheetRole.pullSheet;
        final built = buildScheduleSheet(
          sheet: sheet,
          page: pull
              ? pullPages[pullPage++]
              : terminationPages[terminationPage++],
          columns: (pull ? pullView : terminationView).columns,
          registries: doc.registries,
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
        );
        scene = built.scene;
        legibility = built.legibility;
      case SheetRole.unusedHomeRuns:
        final built = buildUnusedRunsSheet(
          sheet: sheet,
          page: unusedPages[unusedPage++],
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
        );
        scene = built.scene;
        legibility = built.legibility;
      case SheetRole.pinoutDetails:
        final built = buildPinoutSheet(
          sheet: sheet,
          page: pinoutPages[pinoutPage++],
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
        );
        scene = built.scene;
        legibility = built.legibility;
      case SheetRole.equipmentList:
        final built = buildEquipmentSheet(
          sheet: sheet,
          page: schedulePages[schedulePage++],
          list: list,
          info: doc.info,
          settings: doc.settings,
          revisions: doc.revisionBlock,
          fileName: request.fileName,
          issuedAt: request.issuedAt,
          measurer: measurer,
        );
        scene = built.scene;
        legibility = built.legibility;
    }

    final notice = legibility.notice;
    // A NOTICE, NEVER A GATE. Section 6.2's legibility check reports into
    // the export summary; the bytes are written either way (CR-023, G3).
    if (notice != null) notices.add('${sheet.ncsId}: $notice');

    pdf.addPage(
      buildSheetPage(
        size: sheet.size,
        scene: scene,
        fonts: fonts,
        measurer: measurer,
        images: images,
      ),
    );
  }

  return Ok(
    ExportedDocument(
      bytes: await pdf.save(),
      sheetCount: set.sheets.length,
      notices: List.unmodifiable(notices),
      stamped: stamped,
      stampWithheld: stampWithheld,
    ),
  );
}

/// The one font every sheet draws with, checked BEFORE any page is built.
///
/// `PdfDiagramCanvas.drawText` does `_fonts[s.font]!`, so a missing face
/// would surface as a null-check crash halfway through rendering -- inside
/// what the user experiences as "Export PDF", with a partly-built document
/// and no message. Checked here so it is a reported refusal instead.
FontRef? _missingFont(Map<FontRef, Uint8List> fontBytes) =>
    fontBytes.containsKey(kSheetFont) ? null : kSheetFont;
