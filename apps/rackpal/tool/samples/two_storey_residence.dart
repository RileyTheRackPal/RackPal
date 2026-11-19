// The two-storey residence sample: a whole job, built the way an integrator
// would build it in the application, for screenshots, a published PDF set and
// a census of what the seed catalogue cannot yet express.
//
// ==================================================================
// WHY THIS IS NOT A FIFTH STARTER
// ==================================================================
// AC-052 names four starters and the starter tests count them. This file is
// a SAMPLE: bigger than any starter, wired end to end, and allowed to carry
// project templates the catalogue does not ship. It reuses the starters'
// authoring vocabulary (`starters/authoring.dart`) so its ids are
// deterministic and two regenerations write the same bytes.
//
// ==================================================================
// EVERY CABLE PASSES THE APPLICATION'S OWN CONNECT RULES
// ==================================================================
// [_Wiring.cable] resolves both ends with `resolveConnectTarget` and asks
// `evaluateConnect` before it writes a conductor, which is exactly what the
// schematic's drag gesture asks. A cable the product would spring back is a
// thrown error here rather than a quietly impossible sample.
//
// ==================================================================
// THE FLOORPLANS ARE DRAWN FOR THIS SAMPLE
// ==================================================================
// The room layout follows a reference house plan whose title block forbids
// republishing it. The two pages imported here are block plans drawn from
// room positions alone by `tools/samples/draw_residence_plans.py`, from the
// same `residence_geometry.json` this file reads for outlines and pins.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:rackpal_core/rackpal_core.dart';

import '../starters/authoring.dart';

/// Where the geometry and the two plan PNGs live, relative to `apps/rackpal`.
const String kSampleSourceDir = 'tool/samples';

/// The built document and the container members it needs beside it.
typedef SampleProject = ({
  RackDocument doc,
  Map<String, Uint8List> members,
  List<String> forkedTemplates,
});

/// Builds the sample. Reads the geometry and plan images from
/// [sourceDir].
SampleProject buildTwoStoreyResidence({String sourceDir = kSampleSourceDir}) {
  final author = StarterAuthor(
    createdAt: DateTime.utc(2026, 11, 18, 9),
    modifiedAt: DateTime.utc(2026, 11, 18, 17),
    appVersion: '0.6.60',
  );
  final doc = author.newDocument(
    info: ProjectInfo(
      projectName: 'Two-Storey Residence',
      projectNumber: 'RP-SAMPLE-002',
      drawingNumber: 'AV-300',
      clientName: 'Sample Client',
      siteAddress: Address(
        line1: '7 Example Lane',
        city: 'Sampleton',
        region: 'CA',
        postalCode: '90000',
        country: 'US',
      ),
      integratorName: 'Example Integration Co.',
      integratorContact: 'projects@example.invalid',
      drawnBy: 'RackPal',
      checkedBy: 'RackPal',
    ),
    settings: ProjectSettings(defaultRackHeightU: 27),
  );
  final w = _Wiring(author, doc);
  final forked = w.addProjectTemplates();

  // --- Locations ---------------------------------------------------------

  final geometry =
      jsonDecode(File('$sourceDir/residence_geometry.json').readAsStringSync())
          as Map<String, Object?>;
  final site = author.addLocation(
    doc,
    kind: LocationKind.site,
    name: 'Two-Storey Residence',
    code: 'RES',
    order: 0,
  );
  final house = author.addLocation(
    doc,
    kind: LocationKind.building,
    name: 'House',
    code: 'H',
    order: 1,
    parentId: site,
  );
  final floors = <String, Uuid>{
    'L1': author.addLocation(
      doc,
      kind: LocationKind.floor,
      name: 'Ground Floor',
      code: 'L1',
      order: 2,
      parentId: house,
      floorNumber: 1,
    ),
    'L2': author.addLocation(
      doc,
      kind: LocationKind.floor,
      name: 'Upper Floor',
      code: 'L2',
      order: 3,
      parentId: house,
      floorNumber: 2,
    ),
  };

  // Typed run lengths for the upper floor only. A plan-derived length needs
  // the rack on the SAME page (docs/21 Â§21.5.2), and the head end is
  // downstairs, so these are the integrator's estimate up the stair riser.
  const upperRunFeet = <String, int>{
    'PTR': 70,
    'PBR': 62,
    'PCL': 55,
    'PBA': 58,
    'BR2': 55,
    'BA2': 50,
    'HAL2': 45,
    'STR2': 40,
    'BR3': 60,
    'B3C': 58,
    'TER': 75,
  };

  final room = <String, Uuid>{};
  final pages = (geometry['pages']! as List).cast<Map<String, Object?>>();
  var order = 4;
  for (final page in pages) {
    final floorKey = page['key']! as String;
    for (final r in (page['rooms']! as List).cast<Map<String, Object?>>()) {
      if (r['void'] == true) continue;
      final code = r['code']! as String;
      final parentCode = r['parent'] as String?;
      final feetFromRack = upperRunFeet[code];
      room[code] = author.addLocation(
        doc,
        kind: r['outdoor'] == true ? LocationKind.outdoor : LocationKind.room,
        name: r['name']! as String,
        code: code,
        order: order++,
        parentId: parentCode == null ? floors[floorKey] : room[parentCode],
        floorNumber: floorKey == 'L1' ? 1 : 2,
        estimatedRunLengthFromRack: feetFromRack == null
            ? null
            : feet(feetFromRack),
      );
    }
  }

  // --- Pathways ----------------------------------------------------------

  final riser = author.addPathway(
    doc,
    name: 'Equipment room to upper floor riser',
    designator: 'T1',
    kind: PathwayKind.conduit,
    order: 0,
    fromLocationId: room['EQ'],
    toLocationId: floors['L2'],
    nominalLength: feet(18),
    notes: '1-1/2 in EMT up the stair wall, sleeved through the top plate.',
  );
  final groundRun = author.addPathway(
    doc,
    name: 'Ground floor J-hook run',
    designator: 'T2',
    kind: PathwayKind.jhook,
    order: 1,
    fromLocationId: room['EQ'],
    toLocationId: floors['L1'],
    nominalLength: feet(40),
  );
  final upperRun = author.addPathway(
    doc,
    name: 'Upper floor attic J-hooks',
    designator: 'T3',
    kind: PathwayKind.jhook,
    order: 2,
    fromLocationId: floors['L2'],
    toLocationId: floors['L2'],
    nominalLength: feet(45),
  );
  final livingRun = author.addPathway(
    doc,
    name: 'Living room front wall chase',
    designator: 'T4',
    kind: PathwayKind.conduit,
    order: 3,
    fromLocationId: room['LIV'],
    toLocationId: room['LIV'],
    nominalLength: feet(20),
  );

  // --- RK-1, the primary rack -------------------------------------------

  final eq = room['EQ']!;
  final rk1 = author.addRack(
    doc,
    preset: buildRackPresets()['floorEnclosure27U']!,
    designator: 'RK-1',
    name: 'Primary rack, Equipment Room',
    heightU: 27,
    order: 0,
    locationId: eq,
    hasFrontDoor: true,
    hasRearDoor: true,
    groundBarPresent: true,
    zeroUChannels: [
      ZeroUChannel(
        id: 'ch-rear-left',
        side: ZeroUChannelSide.rearLeft,
        startU: 1,
        endU: 27,
        name: 'Rear left',
      ),
    ],
  );
  Uuid rail1(String template, String designator, String name, int ru) =>
      w.rail(template, designator, name, rk1, ru, eq);

  final ups = rail1('P03', 'UPS-1', 'UPS', 1);
  final seq = rail1('P02', 'SEQ-1', 'Power manager', 4);
  rail1('X01', 'BLK-1', 'Blank panel', 6);
  final amp = rail1(w.ampId, 'AMP-1', 'Distribution amplifier', 7);
  rail1('X02', 'VNT-1', 'Vent panel', 10);
  final mtx = rail1(w.matrixId, 'MTX-1', 'Audio matrix', 11);
  final strm = rail1('A06', 'STRM-1', 'Audio streamers', 12);
  final shf1 = rail1('X03', 'SHF-1', 'Balun shelf', 13);
  final ctl1 = rail1('C01', 'CTL-1', 'Primary smart home controller', 15);
  final fw = rail1('N02', 'FW-1', 'Router', 16);
  final sw1 = rail1('N01', 'SW-1', 'Primary network switch', 17);
  final pp1 = rail1('N03', 'PP-1', 'Patch panel', 18);
  rail1('X01', 'BLK-2', 'Blank panel', 19);
  final pdu = author.addZeroUDevice(
    doc,
    catalogId: 'P01',
    designator: 'PDU-1',
    name: 'Rear PDU',
    rackId: rk1,
    channelId: 'ch-rear-left',
    spanAlongChannel: kRackUnit * 27,
    locationId: eq,
  );
  final balRx = [
    for (var n = 1; n <= 3; n++)
      w.shelf(w.balunRxId, 'BAL-$n', 'Audio balun receiver $n', shf1, n, eq),
  ];
  final modem = w.field(
    'F16',
    'MDM-1',
    'Modem',
    eq,
    mountNote:
        'Wall-mounted beside RK-1; the catalogue modem cannot sit on '
        'a rack shelf',
  );

  // --- RK-2, the living room rack ---------------------------------------

  final liv = room['LIV']!;
  final rk2 = author.addRack(
    doc,
    preset: buildRackPresets()['floorEnclosure18U']!,
    designator: 'RK-2',
    name: 'Living room AV rack',
    heightU: 18,
    order: 1,
    locationId: liv,
    hasFrontDoor: true,
    hasRearDoor: true,
    zeroUChannels: [
      ZeroUChannel(
        id: 'ch-rear-left',
        side: ZeroUChannelSide.rearLeft,
        startU: 1,
        endU: 18,
        name: 'Rear left',
      ),
    ],
  );
  final shf2 = w.rail('X03', 'SHF-2', 'Receiver shelf', rk2, 1, liv);
  w.rail('X02', 'VNT-2', 'Vent panel', rk2, 7, liv);
  final shf3 = w.rail('X03', 'SHF-3', 'Source shelf', rk2, 8, liv);
  w.rail('X01', 'BLK-3', 'Blank panel', rk2, 10, liv);
  final sw2 = w.rail(w.switchId, 'SW-2', 'Living room switch', rk2, 11, liv);
  final ctl2 = w.rail('C01', 'CTL-2', 'Smart home controller', rk2, 12, liv);
  w.rail('X02', 'VNT-3', 'Vent panel', rk2, 13, liv);
  final avr = w.shelf('A02', 'AVR-1', 'AV receiver', shf2, 0, liv);
  final strip = w.shelf('P04', 'PS-1', 'Power strip', shf2, 1, liv);
  final pdu2 = author.addZeroUDevice(
    doc,
    catalogId: 'P01',
    designator: 'PDU-2',
    name: 'Rear PDU',
    rackId: rk2,
    channelId: 'ch-rear-left',
    spanAlongChannel: kRackUnit * 18,
    locationId: liv,
  );
  final tx = w.shelf('V06', 'TX-1', 'HDBaseT transmitter', shf3, 0, liv);
  final smpLiv = w.shelf(
    w.streamerId,
    'SMP-1',
    'Living room streaming player',
    shf3,
    1,
    liv,
  );
  final bd = w.shelf(w.discId, 'BD-1', 'Blu-ray player', shf3, 2, liv);

  // --- Field devices -----------------------------------------------------

  final disp = w.field(
    'F01',
    'DISP-1',
    'Living room TV',
    liv,
    mountNote: 'Front wall, centred',
  );
  final rx = w.field(
    w.receiverId,
    'RX-1',
    'HDBaseT receiver',
    liv,
    mountNote: 'Behind the TV',
  );
  final spkFl = w.field(
    'F05',
    'LIV-SPK-FL',
    'Front left',
    liv,
    mountNote: 'In-wall, front wall',
  );
  final spkC = w.field(
    'F05',
    'LIV-SPK-C',
    'Centre',
    liv,
    mountNote: 'In-wall, below the TV',
  );
  final spkFr = w.field(
    'F05',
    'LIV-SPK-FR',
    'Front right',
    liv,
    mountNote: 'In-wall, front wall',
  );
  final spkSl = w.field(
    w.ceilingId,
    'LIV-SPK-SL',
    'Surround left',
    liv,
    mountNote: 'In-ceiling, behind the seating',
  );
  final spkSr = w.field(
    w.ceilingId,
    'LIV-SPK-SR',
    'Surround right',
    liv,
    mountNote: 'In-ceiling, behind the seating',
  );
  final sub = w.field(
    'F06',
    'SUB-1',
    'Subwoofer',
    liv,
    mountNote: 'Front right corner',
  );

  // A room's stereo pair is TWO speakers: two locations on the plan, two
  // runs, labelled ROOM-SPK-1 and ROOM-SPK-2. F04 models a pair as one
  // device, which can only ever be one pin, so the rooms use a single
  // in-ceiling speaker forked from F05.
  //
  // A speaker's designator IS its room label (KIT-SPK-2): it has no plate,
  // so the plan's only label on it is the designator, and the owner asked
  // for the room form. Its run carries the same text as its field label.
  (Uuid, Uuid) pair(String template, String code, String name) => (
    w.field(template, '$code-SPK-1', '$name left', room[code]!),
    w.field(template, '$code-SPK-2', '$name right', room[code]!),
  );
  final spkDin = pair(w.ceilingId, 'DIN', 'Dining room');
  final spkKit = pair(w.ceilingId, 'KIT', 'Kitchen');
  final spkLau = w.field(
    w.dvcId,
    'LAU-SPK-1',
    'Laundry DVC',
    room['LAU']!,
  );
  final spkTer = pair('F07', 'TER', 'Upper terrace');
  final spkPtr = pair('F07', 'PTR', 'Primary terrace');
  final spkPbr = pair(w.ceilingId, 'PBR', 'Primary bedroom');
  final spkBr2 = pair(w.ceilingId, 'BR2', 'Bedroom 2');
  final spkBr3 = pair(w.ceilingId, 'BR3', 'Bedroom 3');

  final tpKit = w.field('F12', 'TP-1', 'Kitchen touchscreen', room['KIT']!);
  final tpPbr = w.field(
    'F12',
    'TP-2',
    'Primary bedroom touchscreen',
    room['PBR']!,
  );
  final tpBr2 = w.field('F12', 'TP-3', 'Bedroom 2 touchscreen', room['BR2']!);
  final tpBr3 = w.field('F12', 'TP-4', 'Bedroom 3 touchscreen', room['BR3']!);

  final smpPbr = w.field(
    w.streamerId,
    'SMP-2',
    'Primary bedroom streamer',
    room['PBR']!,
    mountNote: 'Media niche',
  );
  final smpBr2 = w.field(
    w.streamerId,
    'SMP-3',
    'Bedroom 2 streamer',
    room['BR2']!,
    mountNote: 'Media niche',
  );
  final smpBr3 = w.field(
    w.streamerId,
    'SMP-4',
    'Bedroom 3 streamer',
    room['BR3']!,
    mountNote: 'Media niche',
  );
  final balTx = [
    w.field(w.balunTxId, 'BAL-4', 'Primary bedroom balun', room['PBR']!),
    w.field(w.balunTxId, 'BAL-5', 'Bedroom 2 balun', room['BR2']!),
    w.field(w.balunTxId, 'BAL-6', 'Bedroom 3 balun', room['BR3']!),
  ];

  final apPcl = w.field(
    'F11',
    'AP-1',
    'Primary closet access point',
    room['PCL']!,
    mountNote: 'Ceiling',
  );
  final apB3c = w.field(
    'F11',
    'AP-2',
    'Bedroom 3 closet access point',
    room['B3C']!,
    mountNote: 'Ceiling',
  );
  final apDin = w.field(
    'F11',
    'AP-3',
    'Dining room access point',
    room['DIN']!,
    mountNote: 'Ceiling',
  );

  // --- Structure ---------------------------------------------------------

  final structure = author.addStructure(
    doc,
    designator: 'STR-1',
    title: 'Rough-in, Two-Storey Residence',
    distributionDeviceLocationId: eq,
    enclosureModel: 'RK-1, Equipment Room',
  );
  var outletOrder = 0;
  Uuid outlet(
    String designation,
    String roomCode,
    String template,
    Uuid pathway, {
    MountSurface surface = MountSurface.wall,
    Wall? wall,
    int? heightIn,
  }) => author.addOutlet(
    doc,
    structureBodyId: structure.bodyId,
    designation: designation,
    order: outletOrder++,
    locationId: room[roomCode],
    wall: wall,
    mountSurface: surface,
    mountHeightAff: heightIn == null ? null : inches(heightIn),
    floorNumber: upperRunFeet.containsKey(roomCode) ? 2 : 1,
    outletTemplateId: template,
    pathwayId: pathway,
  );

  // --- Cables: the living room ------------------------------------------

  const cat6 = MediaTypeId('media.cat6');
  const spk162 = MediaTypeId('media.16_2');
  const spk164 = MediaTypeId('media.16_4');
  const rg6 = MediaTypeId('media.rg6');
  const hdmi = MediaTypeId('media.hdmi_passive');
  const line = MediaTypeId('media.mic_stp');
  const ctl224 = MediaTypeId('media.22_4');
  const ctl222 = MediaTypeId('media.22_2');
  const iec = MediaTypeId('media.iec_cordage');
  const so = MediaTypeId('media.so_cord');

  final livTv = outlet(
    'LIV-TV-1',
    'LIV',
    'outlet.tv_location',
    livingRun,
    wall: Wall.s,
    heightIn: 60,
  );
  w.homeRun(
    media: cat6,
    pairs: [(tx, 'hdbt.out', rx, 'hdbt.in', '')],
    structure: structure.bodyId,
    outletId: livTv,
    fieldLabel: 'LIV-HDBT-1',
    rackLabel: 'TX-1',
    fieldTerm: TerminationType.fieldConnector,
    rackTerm: TerminationType.fieldConnector,
    pathway: livingRun,
    feetLong: 22,
    jacketColor: 'jc.green',
  );
  // A speaker is wired straight to its own terminals, with no plate, so
  // every speaker run is BOXLESS: a field label and no outlet to pin.
  for (final (dev, term, len) in [
    (spkFl, 'FL', 24),
    (spkC, 'C', 22),
    (spkFr, 'FR', 24),
    (spkSl, 'SL', 16),
    (spkSr, 'SR', 18),
  ]) {
    w.homeRun(
      media: spk162,
      pairs: [
        (avr, 'spk.$term.pos', dev, 'spk.pos', '+'),
        (avr, 'spk.$term.neg', dev, 'spk.neg', '-'),
      ],
      structure: structure.bodyId,
      fieldLabel: 'LIV-SPK-$term',
      rackLabel: 'AVR-1 $term',
      rackTerm: TerminationType.unterminated,
      pathway: livingRun,
      feetLong: len,
    );
  }
  final livSub = outlet(
    'LIV-SUB-1',
    'LIV',
    'outlet.data_only',
    livingRun,
    wall: Wall.s,
    heightIn: 12,
  );
  w
    ..homeRun(
      media: rg6,
      pairs: [(avr, 'sub.pre.1', sub, 'lfe.in', '')],
      structure: structure.bodyId,
      outletId: livSub,
      fieldLabel: 'LIV-SUB-1',
      rackLabel: 'AVR-1 SUB',
      pathway: livingRun,
      feetLong: 26,
    )
    ..jumper(hdmi, [(rx, 'hdmi.out', disp, 'hdmi.1', '')], feetLong: 6)
    ..jumper(hdmi, [(avr, 'hdmi.out.main', tx, 'hdmi.in', '')])
    ..jumper(hdmi, [(smpLiv, 'hdmi.out', avr, 'hdmi.in.1', '')])
    ..jumper(hdmi, [(bd, 'hdmi.out', avr, 'hdmi.in.2', '')])
    ..jumper(cat6, [(avr, 'lan', sw2, 'access.1', '')])
    ..jumper(cat6, [(smpLiv, 'lan', sw2, 'access.2', '')])
    ..jumper(cat6, [(bd, 'lan', sw2, 'access.3', '')])
    ..jumper(cat6, [(ctl2, 'lan.1', sw2, 'access.4', '')])
    ..jumper(ctl224, [(ctl2, 'com.1', avr, 'rs232', '')])
    ..jumper(ctl222, [(ctl2, 'ir.1', bd, 'ir.in', '')])
    ..jumper(ctl222, [(ctl2, 'ir.2', smpLiv, 'ir.in', '')])
    ..power(so, [(strip, 'out.1', avr, 'ac.in', '')])
    ..power(so, [(strip, 'out.2', smpLiv, 'ac.in', '')])
    ..power(so, [(strip, 'out.3', bd, 'ac.in', '')])
    ..power(iec, [(pdu2, 'c13.1', sw2, 'psu.a', '')])
    ..power(iec, [(pdu2, 'c13.2', ctl2, 'ac.in', '')])
    // The trunk between the two racks: a field cable with no wall plate.
    ..homeRun(
      media: cat6,
      pairs: [(sw2, 'access.8', pp1, 'rear.11', '')],
      structure: structure.bodyId,
      fieldLabel: 'LIV-RK2-1',
      rackLabel: 'PP1-11',
      fieldTerm: TerminationType.fieldConnector,
      pathway: groundRun,
      feetLong: 38,
      jacketColor: 'jc.yellow',
    );

  // --- Cables: distributed audio ----------------------------------------

  // Zone N of the stereo-zone amplifier feeds one room: the left speaker
  // from the zone's L terminals and the right from its R, each on its own
  // boxless 16/2. The laundry's DVC takes both channels on one 16/4.
  final zones = <(String, Uuid, Uuid?, Uuid, int)>[
    ('DIN', spkDin.$1, spkDin.$2, groundRun, 34),
    ('KIT', spkKit.$1, spkKit.$2, groundRun, 30),
    ('LAU', spkLau, null, groundRun, 14),
    ('TER', spkTer.$1, spkTer.$2, riser, 62),
    ('PTR', spkPtr.$1, spkPtr.$2, riser, 58),
    ('PBR', spkPbr.$1, spkPbr.$2, upperRun, 56),
    ('BR2', spkBr2.$1, spkBr2.$2, upperRun, 52),
    ('BR3', spkBr3.$1, spkBr3.$2, upperRun, 58),
  ];
  for (var i = 0; i < zones.length; i++) {
    final (code, left, right, path, len) = zones[i];
    final z = i + 1;
    if (right == null) {
      w.homeRun(
        media: spk164,
        pairs: [
          (amp, 'zone.$z.l.pos', left, 'spk.L.pos', 'L+'),
          (amp, 'zone.$z.l.neg', left, 'spk.L.neg', 'L-'),
          (amp, 'zone.$z.r.pos', left, 'spk.R.pos', 'R+'),
          (amp, 'zone.$z.r.neg', left, 'spk.R.neg', 'R-'),
        ],
        structure: structure.bodyId,
        fieldLabel: '$code-SPK-1',
        rackLabel: 'AMP1-Z$z',
        pathway: path,
        feetLong: len,
      );
      continue;
    }
    // F07 is pigtailed; the in-ceiling fork keeps F05's terminal keys.
    final outdoor = code == 'TER' || code == 'PTR';
    final (pos, neg) = outdoor ? ('pos', 'neg') : ('spk.pos', 'spk.neg');
    for (final (n, side, dev) in [(1, 'l', left), (2, 'r', right)]) {
      w.homeRun(
        media: spk162,
        pairs: [
          (amp, 'zone.$z.$side.pos', dev, pos, '+'),
          (amp, 'zone.$z.$side.neg', dev, neg, '-'),
        ],
        structure: structure.bodyId,
        fieldLabel: '$code-SPK-$n',
        rackLabel: 'AMP1-Z$z${side.toUpperCase()}',
        pathway: path,
        feetLong: len + (n == 2 ? 6 : 0),
      );
    }
  }

  // Sources into the matrix, matrix into the amplifier.
  for (var s = 1; s <= 4; s++) {
    w.jumper(line, [
      (strm, 'stream.$s.l', mtx, 'in.$s.l', 'L'),
      (strm, 'stream.$s.r', mtx, 'in.$s.r', 'R'),
    ]);
  }
  for (var n = 0; n < 3; n++) {
    w.jumper(line, [
      (balRx[n], 'out.l', mtx, 'in.${5 + n}.l', 'L'),
      (balRx[n], 'out.r', mtx, 'in.${5 + n}.r', 'R'),
    ]);
  }
  for (var z = 1; z <= 8; z++) {
    w.jumper(line, [
      (mtx, 'out.$z.l', amp, 'src.$z.l', 'L'),
      (mtx, 'out.$z.r', amp, 'src.$z.r', 'R'),
    ]);
  }

  // --- Cables: bedrooms, kitchen and access points ----------------------

  var panelPort = 0;
  void dataRun(
    Uuid device,
    String port,
    String roomCode,
    String label,
    String template,
    Uuid pathway,
    int feetLong,
    String colour, {
    MountSurface surface = MountSurface.wall,
    int? heightIn,
    // An access point or a touchscreen takes its Cat6 straight into its
    // own jack: no plate, so the run is boxless and ends on a plug.
    bool boxless = false,
  }) {
    panelPort++;
    final o = boxless
        ? null
        : outlet(
            label,
            roomCode,
            template,
            pathway,
            surface: surface,
            heightIn: heightIn,
          );
    w
      ..homeRun(
        media: cat6,
        pairs: [(device, port, pp1, 'rear.$panelPort', '')],
        structure: structure.bodyId,
        outletId: o,
        fieldTerm: boxless ? TerminationType.fieldConnector : null,
        fieldLabel: label,
        rackLabel: 'PP1-${panelPort.toString().padLeft(2, '0')}',
        pathway: pathway,
        feetLong: feetLong,
        jacketColor: colour,
      )
      ..jumper(cat6, [(pp1, 'front.$panelPort', sw1, 'access.$panelPort', '')]);
  }

  const ceiling = MountSurface.ceiling;
  dataRun(
    apPcl,
    'lan',
    'PCL',
    'PCL-AP-1',
    'outlet.ap',
    upperRun,
    58,
    'jc.grey',
    surface: ceiling,
    boxless: true,
  );
  dataRun(
    apB3c,
    'lan',
    'B3C',
    'B3C-AP-1',
    'outlet.ap',
    upperRun,
    62,
    'jc.grey',
    surface: ceiling,
    boxless: true,
  );
  dataRun(
    apDin,
    'lan',
    'DIN',
    'DIN-AP-1',
    'outlet.ap',
    groundRun,
    32,
    'jc.grey',
    surface: ceiling,
    boxless: true,
  );
  dataRun(
    tpKit,
    'lan',
    'KIT',
    'KIT-TP-1',
    'outlet.data_only',
    groundRun,
    24,
    'jc.blue',
    heightIn: 48,
    boxless: true,
  );
  dataRun(
    tpPbr,
    'lan',
    'PBR',
    'PBR-TP-1',
    'outlet.data_only',
    upperRun,
    60,
    'jc.blue',
    heightIn: 48,
    boxless: true,
  );
  dataRun(
    tpBr2,
    'lan',
    'BR2',
    'BR2-TP-1',
    'outlet.data_only',
    upperRun,
    54,
    'jc.blue',
    heightIn: 48,
    boxless: true,
  );
  dataRun(
    tpBr3,
    'lan',
    'BR3',
    'BR3-TP-1',
    'outlet.data_only',
    upperRun,
    60,
    'jc.blue',
    heightIn: 48,
    boxless: true,
  );
  for (final (dev, code) in [
    (smpPbr, 'PBR'),
    (smpBr2, 'BR2'),
    (smpBr3, 'BR3'),
  ]) {
    dataRun(
      dev,
      'lan',
      code,
      '$code-SMP-1',
      'outlet.data_only',
      upperRun,
      code == 'BR2' ? 53 : 61,
      'jc.yellow',
      heightIn: 16,
    );
  }

  // Audio baluns: the room's streamer into the balun, Cat6 straight to the
  // receiver on SHF-1, which feeds a matrix input. The balun IS the wall
  // plate, so its run lands on it directly and is boxless.
  for (final (n, dev, smp, code, len) in [
    (0, balTx[0], smpPbr, 'PBR', 61),
    (1, balTx[1], smpBr2, 'BR2', 53),
    (2, balTx[2], smpBr3, 'BR3', 61),
  ]) {
    w
      ..jumper(line, [
        (smp, 'audio.l', dev, 'in.l', 'L'),
        (smp, 'audio.r', dev, 'in.r', 'R'),
      ])
      ..homeRun(
        media: cat6,
        pairs: [(dev, 'cat.out', balRx[n], 'cat.in', '')],
        structure: structure.bodyId,
        fieldLabel: '$code-BAL-1',
        fieldTerm: TerminationType.fieldConnector,
        rackLabel: 'BAL-${n + 1}',
        rackTerm: TerminationType.fieldConnector,
        pathway: upperRun,
        feetLong: len,
        jacketColor: 'jc.green',
      );
  }

  // --- Cables: the head end ---------------------------------------------

  w
    ..jumper(cat6, [(modem, 'lan.1', fw, 'wan.1', '')], feetLong: 7)
    ..jumper(cat6, [(fw, 'lan.1', sw1, 'access.48', '')])
    ..jumper(cat6, [(ctl1, 'lan.1', sw1, 'access.40', '')])
    ..jumper(cat6, [(strm, 'lan', sw1, 'access.41', '')])
    ..jumper(cat6, [(mtx, 'lan', sw1, 'access.42', '')])
    ..jumper(cat6, [(amp, 'lan', sw1, 'access.43', '')])
    ..jumper(cat6, [(seq, 'lan', sw1, 'access.44', '')])
    ..jumper(cat6, [(ups, 'network.card', sw1, 'access.45', '')])
    ..jumper(ctl224, [(ctl1, 'com.1', amp, 'rs232', '')])
    ..jumper(ctl224, [(ctl1, 'com.2', mtx, 'rs232', '')])
    // Power: UPS feeds the PDU and the power manager; the amplifier's
    // captive cord takes a sequenced outlet so it comes up last.
    ..power(so, [(ups, 'nema520r.1', pdu, 'ac.in', '')])
    ..power(so, [(ups, 'nema520r.2', seq, 'ac.in', '')])
    ..power(so, [(seq, 'step4.out.1', amp, 'ac.in', '')]);
  var outletNo = 0;
  for (final (dev, inlet) in [
    (fw, 'ac.in'),
    (sw1, 'psu.a'),
    (ctl1, 'ac.in'),
    (strm, 'ac.in'),
    (mtx, 'ac.in'),
  ]) {
    outletNo++;
    w.power(iec, [(pdu, 'c13.$outletNo', dev, inlet, '')]);
  }

  // --- Floorplans --------------------------------------------------------

  final members = <String, Uint8List>{};
  final scale = (geometry['pxPerMetre']! as num).toInt();
  final houseWidth = geometry['houseWidthMetres']! as num;
  final origin = (geometry['originMetres']! as List).cast<num>();
  final margin = (geometry['marginPx']! as num).toInt();
  final bar = (geometry['scaleBarPx']! as List)
      .cast<List<Object?>>()
      .map((p) => PxPt(p[0]! as int, p[1]! as int))
      .toList();
  // The drawing script's transform, front of the house to the right; see
  // `transform` in the geometry file.
  PxPt px(num x, num y) => PxPt(
    (margin + (y - origin[0]) * scale).round(),
    (margin + (houseWidth - x - origin[1]) * scale).round(),
  );

  final underlay = <String, Uuid>{};
  var pageOrder = 0;
  for (final page in pages) {
    final key = page['key']! as String;
    final bytes = File(
      '$sourceDir/plan_${key.toLowerCase()}.png',
    ).readAsBytesSync();
    final id = author.mint();
    final member = '$kUnderlayMemberDir${id.v}.png';
    members[member] = bytes;
    final size = (geometry['sizePx']! as List).cast<int>();
    AddPlanUnderlayCommand(
      underlay: PlanUnderlay(
        id: id,
        name: key == 'L1' ? 'Ground floor' : 'Upper floor',
        imageMember: member,
        format: PlanImageFormat.png,
        pixelWidth: size[0],
        pixelHeight: size[1],
        contentHash: '$kSha256Prefix${sha256.convert(bytes)}',
        order: fracIndex(pageOrder++),
        meta: author.meta(),
        locationId: floors[key],
      ),
    ).apply(doc);
    // Calibrated off the drawn scale bar, end to end, as a person would:
    // two clicks and "5 m".
    SetPlanScaleCommand(
      underlayId: id,
      scale: PlanScale(
        a: bar[0],
        b: bar[1],
        distance: Len.fromMillimetres(5000),
      ),
    ).apply(doc);
    underlay[key] = id;
    for (final r in (page['rooms']! as List).cast<Map<String, Object?>>()) {
      final roomId = room[r['code']];
      if (roomId == null) continue;
      final poly = (r['poly']! as List)
          .cast<List<Object?>>()
          .map((p) => px(p[0]! as num, p[1]! as num))
          .toList();
      SetRoomOutlineCommand(
        locationId: roomId,
        outline: RoomOutline(underlayId: id, vertices: poly),
      ).apply(doc);
    }
  }

  final pinnedAt = <Uuid, (String, num, num)>{};
  void pin(PinCarrier carrier, Uuid id, String page, num x, num y) {
    pinnedAt[id] = (page, x, y);
    final ok = SetPlanPinCommand(
      carrier: carrier,
      entityId: id,
      pin: PlanPin(underlayId: underlay[page]!, at: px(x, y)),
    ).apply(doc);
    if (!ok) throw StateError('Could not pin $id');
  }

  pin(PinCarrier.rack, rk1, 'L1', 9.05, 6.2);
  pin(PinCarrier.rack, rk2, 'L1', 10.75, 10.2);
  // Pairs sit a third and two thirds across the room's long side.
  for (final (id, page, x, y) in [
    (modem, 'L1', 8.85, 7.2),
    (structure.deviceId, 'L1', 8.85, 5.75),
    (disp, 'L1', 10.75, 13.2),
    (rx, 'L1', 11.25, 13.2),
    (spkFl, 'L1', 9.65, 13.45),
    (spkC, 'L1', 10.75, 13.5),
    (spkFr, 'L1', 11.9, 13.45),
    (spkSl, 'L1', 9.65, 11.3),
    (spkSr, 'L1', 11.9, 11.3),
    (sub, 'L1', 12.05, 12.8),
    (spkDin.$1, 'L1', 4.45, 8.55),
    (spkDin.$2, 'L1', 5.95, 8.55),
    (apDin, 'L1', 5.2, 9.5),
    (spkKit.$1, 'L1', 4.9, 5.3),
    (spkKit.$2, 'L1', 7.3, 5.3),
    (tpKit, 'L1', 3.9, 6.6),
    (spkLau, 'L1', 10.0, 4.2),
    (spkTer.$1, 'L2', 1.6, 13.0),
    (spkTer.$2, 'L2', 6.3, 15.3),
    (spkPtr.$1, 'L2', 2.3, 1.3),
    (spkPtr.$2, 'L2', 2.3, 6.1),
    (spkPbr.$1, 'L2', 5.0, 3.5),
    (spkPbr.$2, 'L2', 7.3, 3.5),
    (tpPbr, 'L2', 8.4, 5.1),
    (smpPbr, 'L2', 3.95, 2.6),
    (balTx[0], 'L2', 3.95, 3.2),
    (apPcl, 'L2', 9.7, 4.0),
    (spkBr2.$1, 'L2', 4.8, 7.15),
    (spkBr2.$2, 'L2', 6.6, 7.15),
    (tpBr2, 'L2', 7.45, 8.3),
    (smpBr2, 'L2', 3.95, 6.6),
    (balTx[1], 'L2', 3.95, 7.2),
    (spkBr3.$1, 'L2', 4.7, 10.6),
    (spkBr3.$2, 'L2', 6.4, 10.6),
    (tpBr3, 'L2', 4.6, 12.0),
    (smpBr3, 'L2', 3.95, 9.5),
    (balTx[2], 'L2', 3.95, 10.1),
    (apB3c, 'L2', 7.67, 11.0),
  ]) {
    pin(PinCarrier.offRackDevice, id, page, x, y);
  }
  // Each wall plate is pinned exactly under the device it serves: one
  // marker on the plan carrying both labels (the owner's choice, REL-3),
  // and nothing left for PLN-002 to report. Speakers, access points,
  // touchscreens and baluns are wired straight into the device with no
  // plate (their runs are boxless), so they have no outlet to pin.
  for (final link in doc.links.values) {
    final outletId = link.structureOrigin?.outletId;
    if (outletId == null || doc.outlets[outletId]!.planPin != null) continue;
    for (final c in link.conductors) {
      final at = [c.from, c.to]
          .whereType<PortEndpoint>()
          .map((e) => pinnedAt[doc.ports[e.portId]!.deviceId])
          .nonNulls
          .firstOrNull;
      if (at == null) continue;
      final (page, x, y) = at;
      pin(PinCarrier.outlet, outletId, page, x, y);
      break;
    }
  }

  // --- Power circuits and drawing furniture -----------------------------

  author
    ..addCircuit(
      doc,
      designator: 'C-14',
      breakerAmps: 20,
      volts: 120,
      rackId: rk1,
      locationId: eq,
      dedicated: true,
    )
    ..addCircuit(
      doc,
      designator: 'C-16',
      breakerAmps: 20,
      volts: 120,
      rackId: rk2,
      locationId: liv,
      dedicated: true,
    )
    ..addNote(
      doc,
      text:
          'Eight stereo zones of distributed audio come from AMP-1, fed by '
          'MTX-1: four streams from STRM-1 and three bedroom streamers '
          'returned over audio baluns.',
      targetId: rk1,
    )
    ..addNote(
      doc,
      text:
          'The living room is self-contained: AVR-1 drives the 5.1 system '
          'from RK-2 and reaches the TV over HDBaseT.',
      targetId: rk2,
    )
    ..addRevision(
      doc,
      revision: 'A',
      description: 'Issued for rough-in',
      by: 'RackPal',
      date: DateTime.utc(2026, 11, 18),
    );

  return (doc: doc, members: members, forkedTemplates: forked);
}

/// One end pair of a conductor: (from device, from port, to device, to port,
/// conductor role).
typedef _Pair = (Uuid, String, Uuid, String, String);

final class _Wiring {
  _Wiring(this.author, this.doc);

  final StarterAuthor author;
  final RackDocument doc;

  final String ampId = 'tpl.multi_zone_amplifier_8_zone_stereo';
  final String matrixId = 'tpl.audio_matrix_8x8_stereo';
  final String switchId = 'tpl.poe_switch_8_port';
  final String streamerId = 'tpl.streaming_media_player';
  final String discId = 'tpl.uhd_blu_ray_player';
  final String dvcId = 'tpl.in_ceiling_speaker_dual_voice_coil';
  final String ceilingId = 'tpl.in_ceiling_speaker';
  final String balunTxId = 'tpl.audio_balun_wall_plate';
  final String balunRxId = 'tpl.audio_balun_receiver';
  final String receiverId = 'V06:receiver';

  int _linkOrder = 0;

  // --- Templates ---------------------------------------------------------

  /// Adds the project templates this job needs and the catalogue lacks,
  /// each forked from the seed archetype docs/catalog/seed-devices.md Â§3.10
  /// names as its starting point. Returns their display names.
  List<String> addProjectTemplates() {
    final seed = buildSeedCatalog();
    Map<String, Object?> json(String id) => templateBodyToJson(seed[id]!);

    final added = <String>[];
    void add(String id, Map<String, Object?> body) {
      final b = templateBodyFromJson(body);
      doc.templates[templateKey(id, 1)] = TemplateSnapshot(
        templateId: TemplateId(id),
        version: 1,
        contentHash: templateContentHash(b),
        capturedAt: author.createdAt,
        body: b,
      );
      added.add(b.displayName);
    }

    // The HDBaseT receiver half, exactly as `insertHdbasetReceiver` adds it
    // except for a hash that is a real digest.
    final rx = buildSeedRoleVariants()[receiverId]!;
    doc.templates[templateKey(receiverId, 1)] = TemplateSnapshot(
      templateId: TemplateId(receiverId),
      version: 1,
      contentHash: templateContentHash(rx),
      capturedAt: author.createdAt,
      body: rx,
    );

    // Sources: the S01 set-top box without its RF front end.
    for (final (id, name, model, prefix, description) in [
      (
        streamerId,
        'Streaming Media Player',
        'SMP-4K',
        'SMP',
        'Generic 4K streaming player: HDMI and analogue audio out, IR in. '
            'Forked from S01 with the RF front end removed.',
      ),
      (
        discId,
        'UHD Blu-ray Player',
        'BD-UHD',
        'BD',
        'Generic UHD disc player. Forked from S01 with the RF front end '
            'removed.',
      ),
    ]) {
      final j = json('S01')
        ..['displayName'] = name
        ..['model'] = model
        ..['typePrefix'] = prefix
        ..['description'] = description
        ..['tags'] = <String>['source', 'sample-fork'];
      j['ports'] = [
        for (final p in (j['ports']! as List).cast<Map<String, Object?>>())
          if (!(p['key']! as String).startsWith('rf.')) p,
      ];
      j['banks'] = [
        for (final b in (j['banks']! as List).cast<Map<String, Object?>>())
          if (b['key'] != 'rf') b,
      ];
      add(id, j);
    }

    // One in-ceiling speaker: F05's two terminals in a ceiling can. F04 is
    // the only ceiling speaker shipped and it is a PAIR, one device and so
    // one pin, where a plan needs one location per speaker.
    add(
      ceilingId,
      json('F05')
        ..['displayName'] = 'In-Ceiling Speaker'
        ..['model'] = 'SPK-CEIL-1'
        ..['description'] =
            'One in-ceiling speaker, one location. Forked from F05 (in-wall) '
            'because the catalogue ships ceiling speakers only as a pair '
            '(F04), which a plan cannot show as two locations.'
        ..['tags'] = <String>['speaker', 'ceiling', 'field', 'sample-fork']
        ..['weightUg'] = 1400000000,
    );

    // The DVC speaker: F04's four terminals in one can.
    add(
      dvcId,
      json('F04')
        ..['displayName'] = 'In-Ceiling Speaker, dual voice coil'
        ..['model'] = 'SPK-CEIL-DVC'
        ..['description'] =
            'One stereo speaker with two voice coils for a small room. '
            'Forked from F04: the same four terminals, one location.'
        ..['weightUg'] = 1600000000,
    );

    // The stereo-zone amplifier: A01 with L and R terminals per zone.
    final a01 = json('A01')
      ..['displayName'] = 'Multi-Zone Amplifier, 8 stereo zones'
      ..['model'] = 'AMP-8Z-ST'
      ..['description'] =
          '16 channels as 8 stereo zones, L and R terminals per zone. Forked '
          'from A01, whose zones carry one +/- pair each.';
    final a01Ports = <Map<String, Object?>>[];
    for (final p in (a01['ports']! as List).cast<Map<String, Object?>>()) {
      final key = p['key']! as String;
      if (!key.startsWith('zone.') || key.endsWith('.ir')) {
        a01Ports.add(p);
        continue;
      }
      if (key.endsWith('.neg')) continue;
      final z = key.split('.')[1];
      for (final side in ['l', 'r']) {
        for (final pol in ['pos', 'neg']) {
          a01Ports.add({
            ...p,
            'key': 'zone.$z.$side.$pol',
            'label': 'ZONE $z ${side.toUpperCase()}${pol == 'pos' ? '+' : '-'}',
            'polarity': pol == 'pos' ? 'positive' : 'negative',
            'setKey': 'zone$z${side.toUpperCase()}',
            'setRole': pol == 'pos' ? '+' : '-',
          });
        }
      }
    }
    a01['ports'] = _reorder(a01Ports);
    a01['portSets'] = [
      for (final s in (a01['portSets']! as List).cast<Map<String, Object?>>())
        if ((s['key']! as String).startsWith('zone')) ...[
          {
            ...s,
            'key': '${s['key']}L',
            'label': 'Zone ${(s['key']! as String).substring(4)} left',
          },
          {
            ...s,
            'key': '${s['key']}R',
            'label': 'Zone ${(s['key']! as String).substring(4)} right',
          },
        ] else
          s,
    ];
    add(ampId, a01);

    // The stereo audio matrix: A03's chassis with unbalanced stereo I/O.
    final a03 = json('A03')
      ..['displayName'] = 'Audio Matrix Switcher, 8x8 stereo'
      ..['model'] = 'AMX-88-ST'
      ..['typePrefix'] = 'MTX'
      ..['description'] =
          'Residential stereo matrix, 8 stereo inputs to 8 stereo zones. '
          'Forked from A03, whose 8x8 is mono and balanced.';
    final keep = (a03['ports']! as List).cast<Map<String, Object?>>().where(
      (p) => ['lan', 'rs232', 'ac.in'].contains(p['key']),
    );
    final stereoSets = <Map<String, Object?>>[];
    final io = <Map<String, Object?>>[];
    for (final (dir, prefix, bank) in [
      ('sink', 'in', 'analogIn'),
      ('source', 'out', 'analogOut'),
    ]) {
      for (var n = 1; n <= 8; n++) {
        stereoSets.add({
          'key': '$prefix$n',
          'label': '${prefix == 'in' ? 'Input' : 'Output'} $n',
          'kind': 'stereoPair',
          'atomicConnect': true,
        });
        for (final side in ['l', 'r']) {
          io.add({
            'key': '$prefix.$n.$side',
            'renamedFrom': <String>[],
            'label': '${prefix.toUpperCase()} $n ${side.toUpperCase()}',
            'connector': 'conn.rca',
            'signalFamily': 'audio.line_unbal',
            'acceptedFamilies': <String>[],
            'direction': dir,
            'topology': 'p2p',
            'maxConnections': 1,
            'gender': 'genderless',
            'face': 'rear',
            'order': 'a0000',
            'bankKey': bank,
            'setKey': '$prefix$n',
            'setRole': side.toUpperCase(),
          });
        }
      }
    }
    a03['ports'] = _reorder([...io, ...keep]);
    a03['portSets'] = stereoSets;
    a03['banks'] = [
      for (final b in (a03['banks']! as List).cast<Map<String, Object?>>())
        if (['analogIn', 'analogOut', 'control', 'power'].contains(b['key'])) b,
    ];
    add(matrixId, a03);

    // The small switch: N01 cut to eight access ports.
    final n01 = json('N01')
      ..['displayName'] = 'PoE Switch, 8-port'
      ..['model'] = 'SW-8P'
      ..['description'] =
          "Generic 8-port PoE switch. Forked from N01, the catalogue's "
          '8/24/48 family, which ships only its 48-port configuration.'
      ..['weightUg'] = 2700000000;
    n01['ports'] = [
      for (final p in (n01['ports']! as List).cast<Map<String, Object?>>())
        if (!(p['key']! as String).startsWith('access.') ||
            int.parse((p['key']! as String).split('.')[1]) <= 8)
          if (p['key'] != 'psu.b') p,
    ];
    final n01Power = n01['power']! as Map<String, Object?>;
    n01['power'] = {
      ...n01Power,
      'nameplateWatts': 150,
      'typicalWatts': 60,
      'apparentVA': 158,
    };
    n01.remove('poeBudgetWatts');
    add(switchId, n01);

    // Audio baluns: passive, a stereo RCA pair onto one Cat6 run.
    Map<String, Object?> port(
      String key,
      String label,
      String connector,
      String family,
      String dir,
      String bank, {
      String? set,
      String? role,
      String gender = 'genderless',
    }) => {
      'key': key,
      'renamedFrom': <String>[],
      'label': label,
      'connector': connector,
      'signalFamily': family,
      'acceptedFamilies': <String>[],
      'direction': dir,
      'topology': 'p2p',
      'maxConnections': 1,
      'gender': gender,
      'face': 'rear',
      'order': 'a0000',
      'bankKey': bank,
      'setKey': ?set,
      'setRole': ?role,
    };
    Map<String, Object?> bank(String key, String label, String abbr) => {
      'key': key,
      'label': label,
      'abbr': abbr,
      'order': 'a0000',
      'symbolSide': 'left',
      'collapseInSymbol': false,
    };
    final tx = json('F11')
      ..['displayName'] = 'Audio Balun, wall plate'
      ..['model'] = 'BAL-WP'
      ..['typePrefix'] = 'BAL'
      ..['category'] = 'Field Devices'
      ..['primaryDomain'] = 'audio.analog'
      ..['tags'] = <String>['balun', 'audio', 'sample-fork']
      ..['description'] =
          'Passive stereo audio balun on a decora plate: RCA in, one Cat6 '
          'run out to a matching receiver.'
      ..['weightUg'] = 100000000
      ..['power'] = {'isContinuousLoad': false}
      ..['ports'] = _reorder([
        port(
          'in.l',
          'IN L',
          'conn.rca',
          'audio.line_unbal',
          'sink',
          'in',
          set: 'in',
          role: 'L',
        ),
        port(
          'in.r',
          'IN R',
          'conn.rca',
          'audio.line_unbal',
          'sink',
          'in',
          set: 'in',
          role: 'R',
        ),
        port(
          'cat.out',
          'CAT OUT',
          'conn.rj45',
          'audio.line_bal',
          'source',
          'link',
          gender: 'female',
        ),
      ])
      ..['banks'] = [bank('in', 'Audio In', 'IN'), bank('link', 'Link', 'LINK')]
      ..['portSets'] = [
        {
          'key': 'in',
          'label': 'Audio in',
          'kind': 'stereoPair',
          'atomicConnect': true,
        },
      ]
      ..remove('glyph');
    add(balunTxId, tx);

    final rxBody = json('V06')
      ..['displayName'] = 'Audio Balun, receiver'
      ..['model'] = 'BAL-RX'
      ..['typePrefix'] = 'BAL'
      ..['category'] = 'Audio'
      ..['primaryDomain'] = 'audio.analog'
      ..['tags'] = <String>['balun', 'audio', 'sample-fork']
      ..['description'] =
          'Passive stereo audio balun receiver for a rack shelf: Cat6 in, '
          'RCA out to the matrix.'
      ..['weightUg'] = 150000000
      ..['power'] = {'isContinuousLoad': false}
      ..['ports'] = _reorder([
        port(
          'cat.in',
          'CAT IN',
          'conn.rj45',
          'audio.line_bal',
          'sink',
          'link',
          gender: 'female',
        ),
        port(
          'out.l',
          'OUT L',
          'conn.rca',
          'audio.line_unbal',
          'source',
          'out',
          set: 'out',
          role: 'L',
        ),
        port(
          'out.r',
          'OUT R',
          'conn.rca',
          'audio.line_unbal',
          'source',
          'out',
          set: 'out',
          role: 'R',
        ),
      ])
      ..['banks'] = [
        bank('link', 'Link', 'LINK'),
        bank('out', 'Audio Out', 'OUT'),
      ]
      ..['portSets'] = [
        {
          'key': 'out',
          'label': 'Audio out',
          'kind': 'stereoPair',
          'atomicConnect': true,
        },
      ]
      ..remove('glyph');
    add(balunRxId, rxBody);

    return added;
  }

  static List<Map<String, Object?>> _reorder(List<Map<String, Object?>> ps) => [
    for (var i = 0; i < ps.length; i++)
      {...ps[i], 'order': 'a${(i + 1).toString().padLeft(4, '0')}'},
  ];

  // --- Devices -----------------------------------------------------------

  DeviceKind _kind(String templateId) {
    final body = doc.templates[templateKey(templateId, 1)]!.body;
    return starterDeviceKindFor(templateId, body);
  }

  DeviceInstance _device(
    String templateId,
    String designator,
    String name,
    Placement placement,
    Uuid locationId,
  ) {
    final snapshot = doc.templates[templateKey(templateId, 1)];
    if (snapshot == null) throw ArgumentError('no template $templateId');
    final id = author.mint();
    return doc.devices[id] = DeviceInstance(
      id: id,
      kind: _kind(templateId),
      templateRef: TemplateRef(
        templateId: snapshot.templateId,
        version: snapshot.version,
        contentHash: snapshot.contentHash,
      ),
      designator: designator,
      name: name,
      placement: placement,
      meta: author.meta(),
      locationId: locationId,
    );
  }

  Uuid rail(
    String templateId,
    String designator,
    String name,
    Uuid rackId,
    int ru,
    Uuid locationId,
  ) => _device(
    templateId,
    designator,
    name,
    RailPlacement(rackId: rackId, ruIndex: ru, face: Face.front),
    locationId,
  ).id;

  Uuid shelf(
    String templateId,
    String designator,
    String name,
    Uuid hostId,
    int order,
    Uuid locationId,
  ) => _device(
    templateId,
    designator,
    name,
    ShelfPlacement(hostDeviceId: hostId, order: fracIndex(order)),
    locationId,
  ).id;

  Uuid field(
    String templateId,
    String designator,
    String name,
    Uuid locationId, {
    String? mountNote,
  }) => _device(
    templateId,
    designator,
    name,
    OffRackPlacement(locationId: locationId, mountNote: mountNote),
    locationId,
  ).id;

  // --- Cables ------------------------------------------------------------

  /// How the wall end is finished, by what the cable is.
  static TerminationType? _fieldTermFor(MediaTypeId media) => switch (media.v) {
    'media.cat6' => TerminationType.keystone,
    'media.16_2' || 'media.16_4' => TerminationType.unterminated,
    'media.rg6' => TerminationType.fieldConnector,
    _ => null,
  };

  /// How the rack end is finished: Cat6 punched down on the panel, speaker
  /// wire into the amplifier's euroblocks.
  static TerminationType? _rackTermFor(MediaTypeId media) => switch (media.v) {
    'media.cat6' => TerminationType.punchdown,
    'media.16_2' || 'media.16_4' => TerminationType.euroblock,
    'media.rg6' => TerminationType.fieldConnector,
    _ => null,
  };

  Endpoint _end(Uuid deviceId, String portKey) {
    final target = resolveConnectTarget(
      doc,
      deviceId: deviceId,
      portKey: portKey,
    );
    if (target == null) {
      final d = doc.devices[deviceId]?.designator ?? deviceId.v;
      throw ArgumentError('$d has no port "$portKey"');
    }
    final id = derivePortId(deviceId, PortKey(portKey));
    if (!doc.ports.containsKey(id)) {
      doc.ports[id] = Port(
        id: id,
        deviceId: deviceId,
        designator: allocatePortDesignatorFor(doc, target),
        templatePortKey: PortKey(portKey),
      );
    }
    return PortEndpoint(id);
  }

  void _check(_Pair pair) {
    final (a, ak, b, bk, _) = pair;
    final from = resolveConnectTarget(doc, deviceId: a, portKey: ak)!;
    final to = resolveConnectTarget(doc, deviceId: b, portKey: bk)!;
    final verdict = evaluateConnect(doc, from, to);
    if (verdict is ConnectRefused) {
      throw StateError(
        '${from.citation} to ${to.citation} refused: '
        '${verdict.ruleId} ${verdict.message}',
      );
    }
  }

  /// Writes one cable. The lengths, rough-in state and jacket go through the
  /// `Link` constructor because their setters are core's own (`@internal`):
  /// outside core a link is born with them or a command changes them.
  Link cable(
    MediaTypeId media,
    List<_Pair> pairs,
    LinkClass linkClass, {
    Len? cut,
    Len? terminated,
    RoughInStatus roughIn = RoughInStatus.planned,
    StructureOrigin? origin,
    Uuid? pathway,
    JacketListing? jacket,
    String? jacketColor,
  }) {
    pairs.forEach(_check);
    final (a, ak, _, _, _) = pairs.first;
    final family = resolveConnectTarget(
      doc,
      deviceId: a,
      portKey: ak,
    )!.signalFamily;
    final netId = author.mint();
    final linkId = author.mint();
    doc.nets[netId] = Net(
      id: netId,
      name: allocateNetNameFor(doc),
      signalFamily: family,
      meta: author.meta(),
    );
    final conductors = [
      for (final (a, ak, b, bk, role) in pairs)
        Conductor(from: _end(a, ak), to: _end(b, bk), role: role),
    ];
    return doc.links[linkId] = Link(
      id: linkId,
      designator: allocateLinkDesignatorFor(doc),
      media: media,
      order: fracIndex(_linkOrder++),
      meta: author.meta(),
      linkClass: linkClass,
      // LOCKED, BECAUSE THE CLASSIFIER CANNOT SEE A FIELD DEVICE.
      // `linkClassOf` resolves a port on an off-rack device as UNRESOLVED,
      // so every cable to a modelled speaker, AP or TV would land in the
      // Pull Sheet's CLASS NOT DETERMINED band. A person states the class,
      // as DR-008 §11.8.2 lets them. Recorded as a defect for a ruling.
      linkClassLocked: true,
      services: [Service(id: 'svc-1', signalFamily: family, netId: netId)],
      conductors: conductors,
      structureOrigin: origin,
      pathwayId: pathway,
      // The planned route and the walked length agree for a run that has
      // been pulled and terminated; a jumper has only its cut length.
      routedLength: terminated,
      cutLength: cut,
      terminatedLength: terminated,
      roughInStatus: roughIn,
      jacket: jacket,
      jacketColorId: jacketColor == null ? null : JacketColorId(jacketColor),
    );
  }

  /// A rack or room jumper, at a stock length: patch cords and HDMI leads
  /// are bought cut, so the length is known rather than measured.
  void jumper(MediaTypeId media, List<_Pair> pairs, {int feetLong = 3}) =>
      cable(media, pairs, LinkClass.jumper, cut: feet(feetLong));

  void power(MediaTypeId media, List<_Pair> pairs, {int feetLong = 3}) =>
      cable(media, pairs, LinkClass.powerCord, cut: feet(feetLong));

  void homeRun({
    required MediaTypeId media,
    required List<_Pair> pairs,
    required Uuid structure,
    required String fieldLabel,
    required String rackLabel,
    required Uuid pathway,
    required int feetLong,
    Uuid? outletId,
    String? jacketColor,
    TerminationType? fieldTerm,
    TerminationType? rackTerm,
  }) {
    cable(
      media,
      pairs,
      LinkClass.fieldCable,
      origin: StructureOrigin(
        structureBodyId: structure,
        outletId: outletId,
        boxless: outletId == null,
        fieldLabel: fieldLabel,
        rackLabel: rackLabel,
        terminationField: fieldTerm ?? _fieldTermFor(media),
        terminationRack: rackTerm ?? _rackTermFor(media),
      ),
      pathway: pathway,
      // Terminated runs have been walked and measured (G4: a length is
      // stated only where somebody knows it), so the cut length the
      // schedule orders from and the terminated length agree.
      cut: feet(feetLong),
      terminated: feet(feetLong),
      roughIn: RoughInStatus.terminated,
      jacket: JacketListing.cmr,
      jacketColor: jacketColor,
    );
  }
}
