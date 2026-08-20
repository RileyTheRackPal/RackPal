// M8-F1: MEASURE, then document the limits (board `#424`).
//
//     dart run tool/scale_probe.dart          # from apps/rackmate
//     dart run tool/scale_probe.dart 1 1.5 3  # explicit multipliers
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS EXISTS TO SETTLE, AND WHAT IT DELIBERATELY DOES NOT
// ═══════════════════════════════════════════════════════════════════════
// M8-F asks for a documented scale limit, a soft warning at 1.5x and an
// open-read-only gate at 3x, and none of those numbers has ever been
// taken. The only figures in the tree are `kMaxDocumentBytes` (64 MB) and
// `kMaxJsonDepth` (64), which are import-hardening caps chosen to stop a
// decompression bomb: they say nothing about what the application can
// comfortably hold.
//
// So this builds a synthetic project at a stated size and times the four
// stages of the round trip separately, because they do NOT cost the same
// and only two of them block the user:
//
//   encodeToJsonTree     MAIN ISOLATE, synchronous. Blocks the UI on save.
//   encodeJsonTreeBytes  Isolate.run in production. Does not block.
//   parseDocumentJsonTree  Isolate.run in production. Does not block.
//   readFromJsonTree     MAIN ISOLATE. Blocks the UI on open.
//
// `serialization.dart` is where that split is enforced and why. A probe
// that timed `codec.write` and `codec.read` end to end would report two
// numbers the user never experiences.
//
// IT ALSO TIMES THE DERIVED LAYER, which is the part nobody has looked
// at. `derived/` has twenty-one modules and a grep for `cache` or `memo`
// across all of them returns nothing, so every rebuild recomputes from
// scratch. On a large document that cost is paid on the UI thread far
// more often than a file is opened.
//
// NOT MEASURED HERE: paint, layout, and the schematic op counts. Those
// have their own harness (`schematic_perf_test.dart`) with op-count
// baselines that are stable across runners in a way wall time is not.
// This file reports wall time BECAUSE the question is wall time, and it
// prints the machine it ran on for exactly that reason.
//
// THE ONE `dart:io` RULE. `lib/src/storage/io_file_store.dart` is the
// app's only filesystem seam and a grep test enforces it; this is build
// tooling outside `lib/` and never ships, the same standing
// `generate_starters.dart` has.
import 'dart:io';

import 'package:rackmate_core/rackmate_core.dart';

import 'starters/authoring.dart';

/// One synthetic project's shape at 1x.
///
/// ═══════════════════════════════════════════════════════════════════════
/// CALIBRATED TO THE CORPUS, NOT TO IMAGINATION
/// ═══════════════════════════════════════════════════════════════════════
/// AC-006 argues the file-size budget at a design target of **2,000
/// ports**; AC-009 sizes the label cache against **200 devices x 20
/// ports**. Those two are the only stated shapes in the corpus, and they
/// agree on the order of magnitude, so 1x takes them as a large job
/// rather than an impossible one:
///
///   * 200 rack devices across 6 racks, which is AC-009's figure exactly.
///   * 1,200 home runs, each of which is a `Link` AND a `Net`. A 400-drop
///     house at three cables a drop is a real number for a large
///     residential job, and AC-018's drill is 60.
///   * 600 MATERIALISED ports. Ports are lazy (AC-006): one exists only
///     because a home run lands on it, so this is the punched-down half
///     of the rack end and not 200 devices' worth of template ports.
///
/// The multipliers scale everything except the racks and the seeded
/// catalog, because a bigger job is more drops and more devices rather
/// than a bigger template library.
const int kRacks = 6;
const int kDevices = 200;
const int kOutlets = 400;
const int kHomeRuns = 1200;
const int kPanelPorts = 600;
const int kLocations = 40;
const int kPathways = 60;

/// The three devices every starter already places, so the probe cannot
/// invent a template the palette does not hold.
const List<String> kCatalog = ['P01', 'V06', 'V07'];

const List<MediaTypeId> kMedia = [
  MediaTypeId('media.cat6'),
  MediaTypeId('media.rg6_quad'),
  MediaTypeId('media.16_4'),
];

const List<SignalFamilyId> kFamilies = [
  SignalFamilyId('net.ethernet'),
  SignalFamilyId('rf.catv'),
  SignalFamilyId('audio.speaker_lowz'),
];

/// The same proportional stand-in `schematic_perf_test.dart` uses.
///
/// A REAL FONT IS NOT THE POINT HERE. Text metrics belong to
/// `rackmate_text` and have their own parity test (AC-007); what this
/// probe is asking is how the SCENE BUILD scales with entity count, and a
/// measurer that allocates no glyph cache keeps the answer about that.
/// The absolute milliseconds are therefore optimistic on the text-bound
/// path by construction, which is stated here rather than discovered.
final class _ProbeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

/// One frame at 60 Hz, which is `schematic_perf_test.dart`'s own unit and
/// M2's exit criterion rather than a threshold invented here.
const double kOneFrameMs = 1000 / 60;

void main(List<String> args) {
  final multipliers = args.isEmpty
      ? const [1.0, 1.5, 3.0]
      : args.map(double.parse).toList();

  stdout
    ..writeln('RackMate scale probe (M8-F1)')
    ..writeln('dart      ${Platform.version.split(' ').first}')
    ..writeln('os        ${Platform.operatingSystemVersion}')
    ..writeln('cores     ${Platform.numberOfProcessors}')
    ..writeln();

  // WARM-UP, AND THE FIRST DRAFT OF THIS FILE DID NOT HAVE ONE. Without
  // it the first multiplier pays for JIT compiling the whole codec and
  // reads 2 to 3 times slower than the same work later in the process,
  // so 1x looked WORSE than 1.5x and the table read as nonsense. The
  // discarded pass is a real document at 0.25x, big enough to compile
  // every path the measured passes take.
  _round(_build(0.25));

  _baseline();
  for (final multiplier in multipliers) {
    _probe(multiplier);
  }
}

/// What an EMPTY project costs, which is the fixed floor under every
/// number below.
///
/// A new document is not empty on disk: `newDocument` embeds all 48 seed
/// templates and the full registries, because `buildPlaceFromCatalogCommand`
/// resolves `doc.templates['<id>@1']` and refuses when it is missing. So
/// this line is the price of admission, and the project's own share of a
/// file is the measured size MINUS this.
void _baseline() {
  final author = StarterAuthor(
    createdAt: DateTime.utc(2026, 8, 15),
    modifiedAt: DateTime.utc(2026, 8, 15),
    appVersion: 'scale-probe',
  );
  final doc = author.newDocument(info: ProjectInfo()..projectName = 'Empty');
  const codec = JsonDocumentCodec();
  final r = _round(doc);
  stdout
    ..writeln('── empty document (48 seed templates + registries) ────────')
    ..writeln('   file      ${_mb(codec.write(doc).length)}')
    ..writeln('   open      ${_msValue(r.decodeUs)}   (blocks the UI)')
    ..writeln();
}

/// One encode/decode round, returned rather than printed.
({
  int encodeUs,
  int bytesUs,
  int parseUs,
  int decodeUs,
  int size,
  RackDocument loaded,
})
_round(RackDocument doc) {
  const codec = JsonDocumentCodec();

  final encodeWatch = Stopwatch()..start();
  final tree = codec.encodeToJsonTree(doc);
  encodeWatch.stop();

  final bytesWatch = Stopwatch()..start();
  final bytes = encodeJsonTreeBytes(tree);
  bytesWatch.stop();

  final parseWatch = Stopwatch()..start();
  final parsed = parseDocumentJsonTree(bytes);
  parseWatch.stop();
  final raw = switch (parsed) {
    Ok(:final value) => value,
    Err(:final error) => throw StateError('probe could not re-read: $error'),
  };

  final decodeWatch = Stopwatch()..start();
  final reread = readFromJsonTree(raw);
  decodeWatch.stop();
  final loaded = switch (reread) {
    Ok(:final value) => value,
    Err(:final error) => throw StateError('probe could not decode: $error'),
  };

  return (
    encodeUs: encodeWatch.elapsedMicroseconds,
    bytesUs: bytesWatch.elapsedMicroseconds,
    parseUs: parseWatch.elapsedMicroseconds,
    decodeUs: decodeWatch.elapsedMicroseconds,
    size: bytes.length,
    loaded: loaded,
  );
}

void _probe(double multiplier) {
  final rssBefore = ProcessInfo.currentRss;
  final doc = _build(multiplier);
  final r = _round(doc);
  final bytes = r.size;
  final loaded = r.loaded;

  // THE DERIVED LAYER, on the document that was just loaded, because
  // that is the state the UI is in when it first draws one.
  final equipmentWatch = Stopwatch()..start();
  final equipment = buildEquipmentList(loaded);
  equipmentWatch.stop();

  final scheduleWatch = Stopwatch()..start();
  final schedule = buildSchedule(loaded);
  scheduleWatch.stop();

  final footageWatch = Stopwatch()..start();
  final footage = buildCableFootage(loaded);
  footageWatch.stop();

  // The other three the UI calls from inside a `build()`.
  final structureBodyId = loaded.structures.keys.first;
  final tableWatch = Stopwatch()..start();
  final table = buildStructureTable(loaded, structureBodyId: structureBodyId);
  tableWatch.stop();

  final matrixWatch = Stopwatch()..start();
  final matrix = buildStructureMatrix(loaded, structureBodyId: structureBodyId);
  matrixWatch.stop();

  final pathwayWatch = Stopwatch()..start();
  final pathwayTable = buildPathwayTable(loaded);
  pathwayWatch.stop();

  // THE SCHEMATIC SCENE, which is the whole commit-path recompute:
  // the document projected onto the graph, Sugiyama phases 0 to 3, and
  // the display list emitted. `schematic_perf_test.dart` measures this
  // at 300 connections against a one-frame budget and passes at 5.8 ms;
  // what nobody has asked is what it does at ten times that.
  final sceneWatch = Stopwatch()..start();
  final scene = buildSchematicScene(doc: loaded, measurer: _ProbeMeasurer());
  sceneWatch.stop();
  final ops = scene.scene.ops.length;

  stdout
    ..writeln('── ${multiplier}x ${'─' * 52}')
    ..writeln(
      '   entities  ${loaded.devices.length} devices · '
      '${loaded.links.length} links · ${loaded.nets.length} nets · '
      '${loaded.ports.length} ports · ${loaded.outlets.length} outlets · '
      '${loaded.locations.length} locations',
    )
    ..writeln('   file      ${_mb(bytes)}  ($bytes bytes)')
    ..writeln()
    ..writeln('   BLOCKS THE UI')
    ..writeln('     encode tree   ${_msValue(r.encodeUs)}   (save)')
    ..writeln('     decode tree   ${_msValue(r.decodeUs)}   (open)')
    ..writeln('   OFF-THREAD (Isolate.run)')
    ..writeln('     tree→bytes    ${_msValue(r.bytesUs)}')
    ..writeln('     bytes→tree    ${_msValue(r.parseUs)}')
    ..writeln('   DERIVED, uncached, recomputed on every rebuild')
    ..writeln(
      '     equipment     ${_msValue(equipmentWatch.elapsedMicroseconds)}   '
      '(${equipment.rows.length} rows)',
    )
    ..writeln(
      '     schedule      ${_msValue(scheduleWatch.elapsedMicroseconds)}   '
      '(${schedule.rows.length} rows)',
    )
    ..writeln(
      '     footage       ${_msValue(footageWatch.elapsedMicroseconds)}   '
      '(${footage.lines.length} lines)',
    )
    ..writeln(
      '     structure     ${_msValue(tableWatch.elapsedMicroseconds)}   '
      '(${table.dropCount} drops)',
    )
    ..writeln(
      '     matrix        ${_msValue(matrixWatch.elapsedMicroseconds)}   '
      '(${matrix.rows.length} rows)',
    )
    ..writeln(
      '     pathways      ${_msValue(pathwayWatch.elapsedMicroseconds)}   '
      '(${pathwayTable.rows.length} rows)',
    )
    ..writeln('   SCHEMATIC SCENE, one frame = 16.7 ms')
    ..writeln(
      '     build         ${_msValue(sceneWatch.elapsedMicroseconds)}   '
      '($ops ops, ${_verdict(sceneWatch.elapsedMicroseconds)} budget)',
    )
    // A DELTA, NOT A TOTAL. The probe holds every document it has built,
    // so absolute RSS is the sum of all rounds and says nothing about
    // one project. Even the delta is generous: it includes the JSON tree
    // and the byte buffer, which are garbage the moment the round ends.
    ..writeln(
      '   rss +     ${_mb(ProcessInfo.currentRss - rssBefore)}   '
      '(document + its tree + its bytes)',
    )
    ..writeln();
}

/// Whether a stage fits in one frame. Named rather than inlined so the
/// comparison is stated once and reads the same in every row.
String _verdict(int micros) => micros / 1000 > kOneFrameMs ? 'OVER' : 'within';

String _msValue(int micros) =>
    '${(micros / 1000).toStringAsFixed(1).padLeft(8)} ms';

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';

/// A synthetic project [multiplier] times the 1x shape above.
RackDocument _build(double multiplier) {
  int n(int base) => (base * multiplier).round();

  final author = StarterAuthor(
    createdAt: DateTime.utc(2026, 8, 15),
    modifiedAt: DateTime.utc(2026, 8, 15),
    appVersion: 'scale-probe',
  );
  final doc = author.newDocument(
    info: ProjectInfo()..projectName = 'Scale probe ${multiplier}x',
  );

  final locations = [
    for (var i = 0; i < n(kLocations); i++)
      author.addLocation(
        doc,
        kind: LocationKind.room,
        name: 'Room ${i + 1}',
        code: 'R${(i + 1).toString().padLeft(3, '0')}',
        order: i,
      ),
  ];

  final racks = [
    for (var i = 0; i < kRacks; i++)
      author.addRack(
        doc,
        preset: buildRackPresets()['data42U36in']!,
        designator: 'RK-${i + 1}',
        name: 'Rack ${i + 1}',
        heightU: 42,
        order: i,
        locationId: locations[i % locations.length],
      ),
  ];

  final devices = <Uuid>[];
  for (var i = 0; i < n(kDevices); i++) {
    devices.add(
      author.addRailDevice(
        doc,
        catalogId: kCatalog[i % kCatalog.length],
        designator: 'DV-${i + 1}',
        name: 'Device ${i + 1}',
        rackId: racks[i % racks.length],
        // Wraps deliberately: RU overlap is an M5 finding and not a
        // parse error, so it costs nothing here and keeps the loop
        // honest about device COUNT rather than rack capacity.
        ruIndex: (i % 42) + 1,
      ),
    );
  }

  final pathways = [
    for (var i = 0; i < n(kPathways); i++)
      author.addPathway(
        doc,
        name: 'Pathway ${i + 1}',
        kind: PathwayKind.attic,
        order: i,
        fromLocationId: locations[i % locations.length],
      ),
  ];

  final structure = author.addStructure(
    doc,
    designator: 'STR-1',
    title: 'Rough-in',
    distributionDeviceLocationId: locations.first,
    enclosureModel: 'Generic 42 in structured media enclosure',
  );

  // MATERIALISED PORTS ONLY (AC-006). One exists because a home run
  // lands on it, which is what makes the port map sparse on a real
  // document and is the whole point of the lazy rule.
  final panelPorts = [
    for (var i = 0; i < n(kPanelPorts); i++)
      author.addPort(
        doc,
        deviceId: devices[i % devices.length],
        portKey: 'p${i + 1}',
        designator: 'J${(i + 1).toString().padLeft(3, '0')}',
      ),
  ];

  final outlets = [
    for (var i = 0; i < n(kOutlets); i++)
      author.addOutlet(
        doc,
        structureBodyId: structure.bodyId,
        designation: 'O${(i + 1).toString().padLeft(4, '0')}',
        order: i,
        locationId: locations[i % locations.length],
        wall: Wall.n,
        mountSurface: MountSurface.wall,
        pathwayId: pathways[i % pathways.length],
      ),
  ];

  for (var i = 0; i < n(kHomeRuns); i++) {
    author.addHomeRun(
      doc,
      designator: 'W${(i + 1).toString().padLeft(4, '0')}',
      media: kMedia[i % kMedia.length],
      signalFamily: kFamilies[i % kFamilies.length],
      order: i,
      fieldEnd: PlaceEndpoint(
        description: 'Room ${(i % locations.length) + 1} outlet',
        locationId: locations[i % locations.length],
        intendedTermination: TerminationType.keystone,
      ),
      rackEnd: PortEndpoint(panelPorts[i % panelPorts.length]),
      origin: StructureOrigin(
        structureBodyId: structure.bodyId,
        outletId: outlets[i % outlets.length],
        fieldLabel: 'F${i + 1}',
        rackLabel: 'R${i + 1}',
        terminationField: TerminationType.keystone,
        wall: Wall.n,
        mountSurface: MountSurface.wall,
      ),
      pathwayId: pathways[i % pathways.length],
      jacket: JacketListing.cmr,
      routedLength: feet(60 + (i % 90)),
    );
  }

  return doc;
}
