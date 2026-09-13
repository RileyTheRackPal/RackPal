// Starter 2 — "Whole house", the M1 exit-criterion shape and the one
// that exercises the Structure device end to end (AC-052, docs/07 §10).
//
// ==================================================================
// WHY THIS IS THE STRUCTURE STARTER
// ==================================================================
// docs/07-structure-device.md §10: *"One of the four starter projects
// authored as real `.rmpj` files exercises Structure end to end,
// doing triple duty as a golden, a perf fixture and a screenshot source
// (AC-052)."* A whole-house rough-in IS that document's own worked
// scenario, so it lands here rather than being sprinkled across four
// files. Everything docs/07 §3 names is present and joined up:
//
//   * a `StructureBody` on a `DeviceInstance` with `kind: structure`,
//   * `Outlet`s — ONE wall plate or ceiling location each, holding no
//     member list (CR-016),
//   * `Link`s that name their outlet through `structureOrigin.outletId`
//     (AC-019). There is no drop entity; `StructureDrop` is deleted
//     (CR-107) and the word appears nowhere,
//   * `fieldLabel` on every home run, project-unique (CR-113);
//     `rackLabel` only where the run is actually terminated, because an
//     unterminated run has no panel position yet,
//   * `Pathway`s that N links share, affecting grouping and never
//     connectivity,
//   * an arbitrary-depth `Location` tree with `code` (never `abbr`,
//     CR-046) and `estimatedRunLengthFromRack`,
//   * bound and UNBOUND rack ends: 15 of the 27 runs are terminated on a
//     real port, 12 are `OpenEndpoint`s — which is what feeds the
//     Unused Home Runs sheet (T6.20) and is the ordinary state of a job
//     between rough-in and trim (docs/07 §1: "the pull happens at
//     framing stage, weeks or months before the equipment list exists").
//
// ==================================================================
// LENGTHS ARE MEASURED OR ABSENT, NEVER ESTIMATED INTO A LINK
// ==================================================================
// `Location.estimatedRunLengthFromRack` seeds the SCHEDULE's estimate,
// which AC-024 requires be rendered in italic and tagged so nobody bills
// off it. Copying that estimate into `Link.routedLength` would launder an
// estimate into a measurement. So only the fifteen TERMINATED runs carry
// a length — the installer has walked them — and the twelve that are
// merely planned or pulled carry null. Null means unknown (G4, CR-114).
//
// ==================================================================
// JACKET COLOUR IS ASSIGNED FROM THE RUN'S PURPOSE, AND ONLY ON
// CATEGORY CABLE
// ==================================================================
// The requesting integrator's convention is a convention about CATEGORY
// CABLE: "we don't have this same issue with other cabling, as generally
// speaking they aren't as universal in their functionality". So the
// fifteen Cat6 runs carry a `jacketColorId` chosen from what each one
// actually feeds — the touchpanel back box is blue because it is
// control, the soffit camera is white because it is a camera, the
// HDBaseT feed is green because it is A/V distribution — and the twelve
// RG6, speaker and fibre runs carry NULL, because their colour is not a
// convention and inventing one would be a fabrication (G4).
//
// Two of the seven seeded colours — red and black — are therefore
// present in `settings.jacketColorConventions` and referenced by no
// link. That is the third state the format is built to express: a colour
// the shop stocks but has not pulled on this job.
import 'package:rackpal_core/rackpal_core.dart';

import 'authoring.dart';

/// Builds the Whole house starter.
RackDocument buildWholeHouseStarter() {
  final author = StarterAuthor(
    createdAt: DateTime.utc(2026, 1, 12, 8, 5),
    modifiedAt: DateTime.utc(2026, 4, 21, 11, 22),
    appVersion: '0.1.0',
  );

  final doc = author.newDocument(
    info: ProjectInfo(
      projectName: 'Whole House',
      projectNumber: 'RM-2026-014',
      drawingNumber: 'AV-200',
      clientName: 'Sample Client',
      siteAddress: Address(
        line1: '48 Example Ridge Road',
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
    settings: ProjectSettings(defaultRackHeightU: 42),
    sequence: 1_412,
  );

  // The four media types these home runs are pulled in — CANON §6.5's OWN
  // IDS, and no local `MediaTypeDef` at all, because `newDocument` has
  // already seeded all 38 of them (M3-C/6).
  //
  // THREE OF THESE IDS USED TO BE THIS FILE'S INVENTION, and the cost was
  // not aesthetic. `media.cat6_utp`, `media.speaker_16_4` and
  // `media.fiber_os2_2f` name cables canon spells `media.cat6`,
  // `media.16_4` and `media.os2`; docs/07 §5.1's synonym table resolves
  // to canon's spellings and to nothing else, so a starter written in the
  // local dialect shipped 27 links whose media no CSV import, no drop DSL
  // and no wide-mode header match could ever reach. `media.rg6_quad` was
  // already right and is unchanged.
  //
  // The four `jacketOptions` sets that used to live here are gone with
  // them. They were authored for this fixture rather than sourced — canon
  // §6.5 names `availableJackets[]` in its field list and gives it no
  // column — and nothing in the codebase reads the field.
  const cat6 = MediaTypeId('media.cat6');
  const rg6 = MediaTypeId('media.rg6_quad');
  const spk164 = MediaTypeId('media.16_4');
  const os2 = MediaTypeId('media.os2');

  // --- Locations ---------------------------------------------------------

  final site = author.addLocation(
    doc,
    kind: LocationKind.site,
    name: 'Willow Creek',
    code: 'WC',
    order: 0,
  );
  final house = author.addLocation(
    doc,
    kind: LocationKind.building,
    name: 'Main House',
    code: 'MH',
    order: 1,
    parentId: site,
  );
  final l1 = author.addLocation(
    doc,
    kind: LocationKind.floor,
    name: 'Ground Floor',
    code: 'L1',
    order: 2,
    parentId: house,
    floorNumber: 1,
  );
  final l2 = author.addLocation(
    doc,
    kind: LocationKind.floor,
    name: 'First Floor',
    code: 'L2',
    order: 3,
    parentId: house,
    floorNumber: 2,
  );

  Uuid room(String name, String code, int order, Uuid floor, int feetFromRack) {
    return author.addLocation(
      doc,
      kind: LocationKind.room,
      name: name,
      code: code,
      order: order,
      parentId: floor,
      floorNumber: floor == l1 ? 1 : 2,
      estimatedRunLengthFromRack: feet(feetFromRack),
    );
  }

  final equip = room('Equipment Room', 'EQ', 4, l1, 5);
  final great = room('Great Room', 'GR', 5, l1, 60);
  final kitchen = room('Kitchen', 'KIT', 6, l1, 55);
  final study = room('Study', 'STU', 7, l1, 40);
  final garage = room('Garage', 'GAR', 8, l1, 25);
  final primary = room('Primary Bedroom', 'PBR', 9, l2, 85);
  final bed2 = room('Bedroom 2', 'BR2', 10, l2, 95);
  final media = room('Media Room', 'MED', 11, l2, 75);
  final patio = author.addLocation(
    doc,
    kind: LocationKind.outdoor,
    name: 'Patio',
    code: 'PAT',
    order: 12,
    parentId: site,
    estimatedRunLengthFromRack: feet(110),
  );

  // --- Pathways ----------------------------------------------------------

  final riser = author.addPathway(
    doc,
    name: 'Equipment room to attic riser',
    kind: PathwayKind.conduit,
    order: 0,
    fromLocationId: equip,
    toLocationId: l2,
    nominalLength: feet(22),
    notes: '2 in EMT, sleeved through the top plate.',
  );
  final groundRun = author.addPathway(
    doc,
    name: 'Ground floor J-hook run',
    kind: PathwayKind.jhook,
    order: 1,
    fromLocationId: equip,
    toLocationId: l1,
    nominalLength: feet(45),
  );
  final atticTray = author.addPathway(
    doc,
    name: 'First floor attic tray',
    kind: PathwayKind.tray,
    order: 2,
    fromLocationId: l2,
    toLocationId: l2,
    nominalLength: feet(38),
  );
  final buried = author.addPathway(
    doc,
    name: 'Patio direct bury',
    kind: PathwayKind.directBury,
    order: 3,
    fromLocationId: equip,
    toLocationId: patio,
    nominalLength: feet(70),
  );

  // --- The rack ----------------------------------------------------------

  final rackId = author.addRack(
    doc,
    preset: buildRackPresets()['data42U36in']!,
    designator: 'RK-1',
    name: 'MDF — Equipment Room',
    heightU: 42,
    order: 0,
    locationId: equip,
    hasFrontDoor: true,
    hasRearDoor: true,
    groundBarPresent: true,
    zeroUChannels: [
      ZeroUChannel(
        id: 'ch-rear-left',
        side: ZeroUChannelSide.rearLeft,
        startU: 1,
        endU: 42,
        name: 'Rear left',
      ),
      ZeroUChannel(
        id: 'ch-rear-right',
        side: ZeroUChannelSide.rearRight,
        startU: 1,
        endU: 42,
        name: 'Rear right',
      ),
    ],
  );

  // --- Front elevation ---------------------------------------------------

  Uuid rail(String catalogId, String designator, String name, int ru) =>
      author.addRailDevice(
        doc,
        catalogId: catalogId,
        designator: designator,
        name: name,
        rackId: rackId,
        ruIndex: ru,
        locationId: equip,
      );

  rail('P03', 'UPS-1', 'Head-end UPS', 1);
  rail('P02', 'SEQ-1', 'Sequenced power', 4);
  rail('X02', 'VNT-1', 'Vent panel', 6);
  rail('V01', 'MTX-1', 'House video matrix', 7);
  rail('V04', 'DA-1', 'Distribution amplifier', 10);
  rail('V05', 'SCL-1', 'Study presentation switcher', 11);
  rail('A01', 'AMP-1', 'Multi-zone amplifier', 12);
  rail('A04', 'AMP-2', 'Great room L/R amplifier', 15);
  rail('A03', 'DSP-1', 'House audio DSP', 17);
  rail('A06', 'STRM-1', 'Streaming source', 18);
  rail('X02', 'VNT-2', 'Vent panel', 19);
  final shelf = rail('X03', 'SHF-1', 'Source shelf', 20);
  rail('S02', 'NAS-1', 'Media server', 22);
  rail('N01', 'SW-1', 'Core switch', 24);
  rail('N01', 'SW-2', 'Edge switch', 25);
  rail('N02', 'FW-1', 'Router / firewall', 26);
  rail('C03', 'SER-1', 'Serial gateway', 27);
  rail('C01', 'CTL-1', 'Control processor', 28);
  rail('C02', 'IRB-1', 'IR distribution', 29);
  final splitter = rail('R01', 'SPL-1', 'CATV splitter panel', 30);
  rail('R02', 'SWM-1', 'Satellite multiswitch', 31);
  final liu = rail('N04', 'LIU-1', 'Fibre enclosure', 32);
  rail('X02', 'VNT-3', 'Vent panel', 33);
  final pp1 = rail('N03', 'PP-1', 'Home-run patch panel A', 34);
  rail('N03', 'PP-2', 'Home-run patch panel B', 35);
  rail('N03', 'PP-3', 'Equipment patch panel', 36);
  rail('X01', 'BLK-1', 'Blank panel', 37);

  author
    ..addShelfDevice(
      doc,
      catalogId: 'S01',
      designator: 'STB-1',
      name: 'Satellite receiver',
      hostDeviceId: shelf,
      order: 0,
      locationId: equip,
    )
    ..addShelfDevice(
      doc,
      catalogId: 'V06',
      designator: 'TX-1',
      name: 'Media room HDBaseT transmitter',
      hostDeviceId: shelf,
      order: 1,
      locationId: equip,
    )
    ..addZeroUDevice(
      doc,
      catalogId: 'P01',
      designator: 'PDU-1',
      name: 'Rear PDU, left',
      rackId: rackId,
      channelId: 'ch-rear-left',
      spanAlongChannel: kRackUnit * 42,
      locationId: equip,
    )
    ..addZeroUDevice(
      doc,
      catalogId: 'P01',
      designator: 'PDU-2',
      name: 'Rear PDU, right',
      rackId: rackId,
      channelId: 'ch-rear-right',
      spanAlongChannel: kRackUnit * 42,
      locationId: equip,
    );

  // --- The field ---------------------------------------------------------

  void field(String catalogId, String designator, String name, Uuid where) {
    author.addFieldDevice(
      doc,
      catalogId: catalogId,
      designator: designator,
      name: name,
      locationId: where,
    );
  }

  field('F01', 'DISP-1', 'Great room display', great);
  field('F01', 'DISP-2', 'Kitchen display', kitchen);
  field('F01', 'DISP-3', 'Primary bedroom display', primary);
  field('F02', 'PROJ-1', 'Media room projector', media);
  field('F04', 'SPK-1', 'Great room ceiling pair', great);
  field('F04', 'SPK-2', 'Kitchen ceiling pair', kitchen);
  field('F04', 'SPK-3', 'Media room ceiling pair', media);
  field('F04', 'SPK-4', 'Primary bedroom ceiling pair', primary);
  field('F07', 'SPK-5', 'Patio landscape pair', patio);
  field('F11', 'AP-1', 'Ground floor access point', great);
  field('F11', 'AP-2', 'First floor access point', primary);
  field('F09', 'CAM-1', 'Front door camera', great);
  field('F09', 'CAM-2', 'Driveway camera', garage);
  field('F12', 'TP-1', 'Great room touchpanel', great);
  field('F13', 'KP-1', 'Kitchen keypad', kitchen);
  field('F16', 'ONT-1', 'Fibre ONT', equip);

  // --- Structure ---------------------------------------------------------

  final structure = author.addStructure(
    doc,
    designator: 'STR-1',
    title: 'Rough-In — Main House',
    distributionDeviceLocationId: equip,
    enclosureModel: 'Generic 42 in structured media enclosure',
  );

  // The fifteen rack-end ports that are actually punched down. AC-006:
  // a port is materialised because it CARRIES STATE — here, a home run
  // landing on it — and not because a template lists it.
  final panelPort = <int, Uuid>{
    for (var n = 1; n <= 12; n++)
      n: author.addPort(
        doc,
        deviceId: pp1,
        portKey: 'rear.$n',
        designator: 'PP1-${n.toString().padLeft(2, '0')}',
      ),
  };
  final catvPort = <int, Uuid>{
    for (var n = 1; n <= 2; n++)
      n: author.addPort(
        doc,
        deviceId: splitter,
        portKey: 'out.$n',
        designator: 'SPL1-0$n',
      ),
  };
  final fibrePort = author.addPort(
    doc,
    deviceId: liu,
    portKey: 'lc.1',
    designator: 'LIU1-01',
  );

  var outletOrder = 0;
  var linkOrder = 0;
  var wireNumber = 0;

  Uuid outlet({
    required String designation,
    required Uuid where,
    required String template,
    required Uuid pathway,
    required int estimatedFeet,
    Wall? wall,
    MountSurface mountSurface = MountSurface.wall,
    Len? heightAff,
    String? grade,
    int? floorNumber,
  }) => author.addOutlet(
    doc,
    structureBodyId: structure.bodyId,
    designation: designation,
    order: outletOrder++,
    locationId: where,
    wall: wall,
    mountSurface: mountSurface,
    mountHeightAff: heightAff,
    floorNumber: floorNumber,
    outletTemplateId: template,
    tia570Grade: grade,
    pathwayId: pathway,
    nominalRunLength: feet(estimatedFeet),
  );

  /// One home run. [rackPort] null means the rack end is still an
  /// `OpenEndpoint` — a pulled or planned run, which is the ordinary
  /// mid-job state and what the Unused Home Runs sheet is for.
  void drop({
    required Uuid outletId,
    required String fieldLabel,
    required String fieldDescription,
    required Uuid where,
    required MediaTypeId media,
    required SignalFamilyId family,
    required TerminationType termination,
    required Uuid pathway,
    required RoughInStatus status,
    JacketListing? jacket,
    bool? directBurialRated,
    JacketColorId? jacketColorId,
    int? gaugeAwg,
    Uuid? rackPort,
    String? rackLabel,
    Len? routedLength,
    Wall? wall,
    MountSurface mountSurface = MountSurface.wall,
    Len? heightAff,
    List<({String role, int? pairNumber, String colorCode})>? conductorRoles,
  }) {
    wireNumber++;
    author.addHomeRun(
      doc,
      designator: 'W${wireNumber.toString().padLeft(3, '0')}',
      media: media,
      signalFamily: family,
      order: linkOrder++,
      fieldEnd: PlaceEndpoint(
        description: fieldDescription,
        locationId: where,
        intendedTermination: termination,
      ),
      rackEnd: rackPort == null
          ? const OpenEndpoint('Rack end not yet terminated')
          : PortEndpoint(rackPort),
      origin: StructureOrigin(
        structureBodyId: structure.bodyId,
        outletId: outletId,
        fieldLabel: fieldLabel,
        rackLabel: rackLabel,
        terminationField: termination,
        wall: wall,
        mountSurface: mountSurface,
        mountHeightAff: heightAff,
      ),
      conductorRoles: conductorRoles,
      pathwayId: pathway,
      jacket: jacket,
      directBurialRated: directBurialRated,
      jacketColorId: jacketColorId,
      gaugeAwg: gaugeAwg,
      routedLength: routedLength,
      roughInStatus: status,
    );
  }

  const speakerRoles = [
    (role: 'L+', pairNumber: 1, colorCode: 'red'),
    (role: 'L-', pairNumber: 1, colorCode: 'black'),
    (role: 'R+', pairNumber: 2, colorCode: 'white'),
    (role: 'R-', pairNumber: 2, colorCode: 'green'),
  ];

  final tvHeight = inches(16);
  const ceiling = MountSurface.ceiling;

  // 1 — Great Room TV wall: the canonical Grade 2 outlet (2 × Cat6 +
  // 2 × RG6), fully terminated.
  final grTv = outlet(
    designation: 'GR-TV-1',
    where: great,
    template: 'outlet.tv_location',
    pathway: groundRun,
    estimatedFeet: 60,
    wall: Wall.n,
    heightAff: tvHeight,
    grade: 'TIA-570-D Grade 2',
    floorNumber: 1,
  );
  drop(
    outletId: grTv,
    fieldLabel: 'GR-DATA-1',
    fieldDescription: 'Great Room TV wall, keystone 1',
    where: great,
    media: cat6,
    jacketColorId: const JacketColorId('jc.yellow'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[1],
    rackLabel: 'PP1-01',
    routedLength: feet(64),
    wall: Wall.n,
    heightAff: tvHeight,
  );
  drop(
    outletId: grTv,
    fieldLabel: 'GR-DATA-2',
    fieldDescription: 'Great Room TV wall, keystone 2',
    where: great,
    media: cat6,
    jacketColorId: const JacketColorId('jc.yellow'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[2],
    rackLabel: 'PP1-02',
    routedLength: feet(64),
    wall: Wall.n,
    heightAff: tvHeight,
  );
  drop(
    outletId: grTv,
    fieldLabel: 'GR-VID-1',
    fieldDescription: 'Great Room TV wall, F-barrel 1',
    where: great,
    media: rg6,
    family: const SignalFamilyId('rf.catv'),
    termination: TerminationType.fBarrel,
    jacket: JacketListing.cl2,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 18,
    rackPort: catvPort[1],
    rackLabel: 'SPL1-01',
    routedLength: feet(66),
    wall: Wall.n,
    heightAff: tvHeight,
  );
  drop(
    outletId: grTv,
    fieldLabel: 'GR-VID-2',
    fieldDescription: 'Great Room TV wall, F-barrel 2',
    where: great,
    media: rg6,
    family: const SignalFamilyId('rf.catv'),
    termination: TerminationType.fBarrel,
    jacket: JacketListing.cl2,
    pathway: groundRun,
    status: RoughInStatus.pulled,
    gaugeAwg: 18,
    wall: Wall.n,
    heightAff: tvHeight,
  );

  // 2 — Great Room ceiling speakers: one 16/4, four conductors (RJ-016).
  final grSpk = outlet(
    designation: 'GR-SPK-1',
    where: great,
    template: 'outlet.ceiling_speaker_pair',
    pathway: groundRun,
    estimatedFeet: 60,
    mountSurface: ceiling,
    floorNumber: 1,
  );
  drop(
    outletId: grSpk,
    fieldLabel: 'GR-AUD-1',
    fieldDescription: 'Great Room ceiling speaker pair',
    where: great,
    media: spk164,
    family: const SignalFamilyId('audio.speaker_lowz'),
    termination: TerminationType.unterminated,
    jacket: JacketListing.cl3,
    pathway: groundRun,
    status: RoughInStatus.pulled,
    gaugeAwg: 16,
    mountSurface: ceiling,
    conductorRoles: speakerRoles,
  );

  // 3 — Great Room touchpanel and keypad feed.
  final grCtl = outlet(
    designation: 'GR-CTL-1',
    where: great,
    template: 'outlet.data_only',
    pathway: groundRun,
    estimatedFeet: 58,
    wall: Wall.e,
    heightAff: inches(48),
    floorNumber: 1,
  );
  drop(
    outletId: grCtl,
    fieldLabel: 'GR-DATA-3',
    fieldDescription: 'Great Room touchpanel back box',
    where: great,
    media: cat6,
    jacketColorId: const JacketColorId('jc.blue'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[3],
    rackLabel: 'PP1-03',
    routedLength: feet(59),
    wall: Wall.e,
    heightAff: inches(48),
  );

  // 4 — Ground floor access point.
  final apL1 = outlet(
    designation: 'GR-AP-1',
    where: great,
    template: 'outlet.ap',
    pathway: groundRun,
    estimatedFeet: 50,
    mountSurface: ceiling,
    floorNumber: 1,
  );
  drop(
    outletId: apL1,
    fieldLabel: 'GR-DATA-4',
    fieldDescription: 'Ground floor ceiling access point',
    where: great,
    media: cat6,
    jacketColorId: const JacketColorId('jc.grey'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[4],
    rackLabel: 'PP1-04',
    routedLength: feet(52),
    mountSurface: ceiling,
  );

  // 5 — Kitchen display.
  final kitTv = outlet(
    designation: 'KIT-TV-1',
    where: kitchen,
    template: 'outlet.tv_location',
    pathway: groundRun,
    estimatedFeet: 55,
    wall: Wall.w,
    heightAff: inches(54),
    grade: 'TIA-570-D Grade 1',
    floorNumber: 1,
  );
  drop(
    outletId: kitTv,
    fieldLabel: 'KIT-DATA-1',
    fieldDescription: 'Kitchen display back box',
    where: kitchen,
    media: cat6,
    jacketColorId: const JacketColorId('jc.yellow'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[5],
    rackLabel: 'PP1-05',
    routedLength: feet(58),
    wall: Wall.w,
    heightAff: inches(54),
  );
  drop(
    outletId: kitTv,
    fieldLabel: 'KIT-VID-1',
    fieldDescription: 'Kitchen display, F-barrel',
    where: kitchen,
    media: rg6,
    family: const SignalFamilyId('rf.catv'),
    termination: TerminationType.fBarrel,
    jacket: JacketListing.cl2,
    pathway: groundRun,
    status: RoughInStatus.pulled,
    gaugeAwg: 18,
    wall: Wall.w,
    heightAff: inches(54),
  );

  // 6 — Kitchen ceiling speakers.
  final kitSpk = outlet(
    designation: 'KIT-SPK-1',
    where: kitchen,
    template: 'outlet.ceiling_speaker_pair',
    pathway: groundRun,
    estimatedFeet: 52,
    mountSurface: ceiling,
    floorNumber: 1,
  );
  drop(
    outletId: kitSpk,
    fieldLabel: 'KIT-AUD-1',
    fieldDescription: 'Kitchen ceiling speaker pair',
    where: kitchen,
    media: spk164,
    family: const SignalFamilyId('audio.speaker_lowz'),
    termination: TerminationType.unterminated,
    jacket: JacketListing.cl3,
    pathway: groundRun,
    status: RoughInStatus.pulled,
    gaugeAwg: 16,
    mountSurface: ceiling,
    conductorRoles: speakerRoles,
  );

  // 7 — Study desk, two data.
  final stuData = outlet(
    designation: 'STU-DATA-1',
    where: study,
    template: 'outlet.data_only',
    pathway: groundRun,
    estimatedFeet: 40,
    wall: Wall.s,
    heightAff: inches(16),
    floorNumber: 1,
  );
  drop(
    outletId: stuData,
    fieldLabel: 'STU-DATA-1',
    fieldDescription: 'Study desk, keystone 1',
    where: study,
    media: cat6,
    jacketColorId: const JacketColorId('jc.yellow'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[6],
    rackLabel: 'PP1-06',
    routedLength: feet(43),
    wall: Wall.s,
    heightAff: inches(16),
  );
  drop(
    outletId: stuData,
    fieldLabel: 'STU-DATA-2',
    fieldDescription: 'Study desk, keystone 2',
    where: study,
    media: cat6,
    jacketColorId: const JacketColorId('jc.yellow'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[7],
    rackLabel: 'PP1-07',
    routedLength: feet(43),
    wall: Wall.s,
    heightAff: inches(16),
  );

  // 8 — Garage camera.
  final garCam = outlet(
    designation: 'GAR-CAM-1',
    where: garage,
    template: 'outlet.camera',
    pathway: groundRun,
    estimatedFeet: 25,
    mountSurface: MountSurface.soffit,
    heightAff: inches(108),
    floorNumber: 1,
  );
  drop(
    outletId: garCam,
    fieldLabel: 'GAR-DATA-1',
    fieldDescription: 'Driveway camera, soffit',
    where: garage,
    media: cat6,
    jacketColorId: const JacketColorId('jc.white'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[8],
    rackLabel: 'PP1-08',
    routedLength: feet(29),
    mountSurface: MountSurface.soffit,
    heightAff: inches(108),
  );

  // 9 — Front door camera.
  final frontCam = outlet(
    designation: 'GR-CAM-1',
    where: great,
    template: 'outlet.camera',
    pathway: groundRun,
    estimatedFeet: 35,
    mountSurface: MountSurface.exterior,
    heightAff: inches(96),
    floorNumber: 1,
  );
  drop(
    outletId: frontCam,
    fieldLabel: 'GR-DATA-5',
    fieldDescription: 'Front door camera, exterior wall',
    where: great,
    media: cat6,
    jacketColorId: const JacketColorId('jc.white'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[9],
    rackLabel: 'PP1-09',
    routedLength: feet(38),
    mountSurface: MountSurface.exterior,
    heightAff: inches(96),
  );

  // 10 — Media room projector, up the riser.
  final medTv = outlet(
    designation: 'MED-PROJ-1',
    where: media,
    template: 'outlet.tv_location',
    pathway: riser,
    estimatedFeet: 75,
    mountSurface: ceiling,
    grade: 'TIA-570-D Grade 2',
    floorNumber: 2,
  );
  drop(
    outletId: medTv,
    fieldLabel: 'MED-DATA-1',
    fieldDescription: 'Media room projector, HDBaseT receiver feed',
    where: media,
    media: cat6,
    jacketColorId: const JacketColorId('jc.green'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: riser,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[10],
    rackLabel: 'PP1-10',
    routedLength: feet(81),
    mountSurface: ceiling,
  );
  drop(
    outletId: medTv,
    fieldLabel: 'MED-DATA-2',
    fieldDescription: 'Media room projector, control spare',
    where: media,
    media: cat6,
    jacketColorId: const JacketColorId('jc.blue'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: riser,
    status: RoughInStatus.pulled,
    gaugeAwg: 23,
    mountSurface: ceiling,
  );
  drop(
    outletId: medTv,
    fieldLabel: 'MED-VID-1',
    fieldDescription: 'Media room, F-barrel spare',
    where: media,
    media: rg6,
    family: const SignalFamilyId('rf.catv'),
    termination: TerminationType.fBarrel,
    jacket: JacketListing.cl2,
    pathway: riser,
    status: RoughInStatus.planned,
    gaugeAwg: 18,
    mountSurface: ceiling,
  );

  // 11 — Media room ceiling speakers.
  final medSpk = outlet(
    designation: 'MED-SPK-1',
    where: media,
    template: 'outlet.ceiling_speaker_pair',
    pathway: atticTray,
    estimatedFeet: 78,
    mountSurface: ceiling,
    floorNumber: 2,
  );
  drop(
    outletId: medSpk,
    fieldLabel: 'MED-AUD-1',
    fieldDescription: 'Media room ceiling speaker pair',
    where: media,
    media: spk164,
    family: const SignalFamilyId('audio.speaker_lowz'),
    termination: TerminationType.unterminated,
    jacket: JacketListing.cl3,
    pathway: atticTray,
    status: RoughInStatus.pulled,
    gaugeAwg: 16,
    mountSurface: ceiling,
    conductorRoles: speakerRoles,
  );

  // 12 — Primary bedroom TV, Grade 2.
  final pbrTv = outlet(
    designation: 'PBR-TV-1',
    where: primary,
    template: 'outlet.tv_location',
    pathway: riser,
    estimatedFeet: 85,
    wall: Wall.se,
    heightAff: tvHeight,
    grade: 'TIA-570-D Grade 2',
    floorNumber: 2,
  );
  drop(
    outletId: pbrTv,
    fieldLabel: 'PBR-DATA-1',
    fieldDescription: 'Primary bedroom TV wall, keystone 1',
    where: primary,
    media: cat6,
    jacketColorId: const JacketColorId('jc.yellow'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: riser,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[11],
    rackLabel: 'PP1-11',
    routedLength: feet(92),
    wall: Wall.se,
    heightAff: tvHeight,
  );
  drop(
    outletId: pbrTv,
    fieldLabel: 'PBR-DATA-2',
    fieldDescription: 'Primary bedroom TV wall, keystone 2',
    where: primary,
    media: cat6,
    jacketColorId: const JacketColorId('jc.yellow'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: riser,
    status: RoughInStatus.pulled,
    gaugeAwg: 23,
    wall: Wall.se,
    heightAff: tvHeight,
  );
  drop(
    outletId: pbrTv,
    fieldLabel: 'PBR-VID-1',
    fieldDescription: 'Primary bedroom TV wall, F-barrel 1',
    where: primary,
    media: rg6,
    family: const SignalFamilyId('rf.catv'),
    termination: TerminationType.fBarrel,
    jacket: JacketListing.cl2,
    pathway: riser,
    status: RoughInStatus.terminated,
    gaugeAwg: 18,
    rackPort: catvPort[2],
    rackLabel: 'SPL1-02',
    routedLength: feet(94),
    wall: Wall.se,
    heightAff: tvHeight,
  );
  drop(
    outletId: pbrTv,
    fieldLabel: 'PBR-VID-2',
    fieldDescription: 'Primary bedroom TV wall, F-barrel 2',
    where: primary,
    media: rg6,
    family: const SignalFamilyId('rf.catv'),
    termination: TerminationType.fBarrel,
    jacket: JacketListing.cl2,
    pathway: riser,
    status: RoughInStatus.planned,
    gaugeAwg: 18,
    wall: Wall.se,
    heightAff: tvHeight,
  );

  // 13 — Primary bedroom ceiling speakers.
  final pbrSpk = outlet(
    designation: 'PBR-SPK-1',
    where: primary,
    template: 'outlet.ceiling_speaker_pair',
    pathway: atticTray,
    estimatedFeet: 88,
    mountSurface: ceiling,
    floorNumber: 2,
  );
  drop(
    outletId: pbrSpk,
    fieldLabel: 'PBR-AUD-1',
    fieldDescription: 'Primary bedroom ceiling speaker pair',
    where: primary,
    media: spk164,
    family: const SignalFamilyId('audio.speaker_lowz'),
    termination: TerminationType.unterminated,
    jacket: JacketListing.cl3,
    pathway: atticTray,
    status: RoughInStatus.pulled,
    gaugeAwg: 16,
    mountSurface: ceiling,
    conductorRoles: speakerRoles,
  );

  // 14 — First floor access point.
  final apL2 = outlet(
    designation: 'PBR-AP-1',
    where: primary,
    template: 'outlet.ap',
    pathway: atticTray,
    estimatedFeet: 80,
    mountSurface: ceiling,
    floorNumber: 2,
  );
  drop(
    outletId: apL2,
    fieldLabel: 'PBR-DATA-3',
    fieldDescription: 'First floor ceiling access point',
    where: primary,
    media: cat6,
    jacketColorId: const JacketColorId('jc.grey'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: atticTray,
    status: RoughInStatus.terminated,
    gaugeAwg: 23,
    rackPort: panelPort[12],
    rackLabel: 'PP1-12',
    routedLength: feet(86),
    mountSurface: ceiling,
  );

  // 15 — Bedroom 2 data.
  final br2 = outlet(
    designation: 'BR2-DATA-1',
    where: bed2,
    template: 'outlet.data_only',
    pathway: riser,
    estimatedFeet: 95,
    wall: Wall.w,
    heightAff: inches(16),
    floorNumber: 2,
  );
  drop(
    outletId: br2,
    fieldLabel: 'BR2-DATA-1',
    fieldDescription: 'Bedroom 2 desk wall',
    where: bed2,
    media: cat6,
    jacketColorId: const JacketColorId('jc.yellow'),
    family: const SignalFamilyId('net.ethernet'),
    termination: TerminationType.keystone,
    jacket: JacketListing.cmr,
    pathway: riser,
    status: RoughInStatus.pulled,
    gaugeAwg: 23,
    wall: Wall.w,
    heightAff: inches(16),
  );

  // 16 — Patio speakers, direct buried.
  final patSpk = outlet(
    designation: 'PAT-SPK-1',
    where: patio,
    template: 'outlet.ceiling_speaker_pair',
    pathway: buried,
    estimatedFeet: 110,
    mountSurface: MountSurface.inGround,
    floorNumber: 1,
  );
  drop(
    outletId: patSpk,
    fieldLabel: 'PAT-AUD-1',
    fieldDescription: 'Patio landscape speaker pair',
    where: patio,
    media: spk164,
    family: const SignalFamilyId('audio.speaker_lowz'),
    termination: TerminationType.unterminated,
    // DIRECT BURIAL IS AN APPLICATION, NOT A LISTING (DR-079 §11.78.1),
    // so it left the enum with LSZH. The listing this run actually
    // carries was never recorded, and inventing one to fill the column
    // would be exactly the fabrication G4 forbids: it stays unknown and
    // the fact that IS known is stated on its own field.
    directBurialRated: true,
    pathway: buried,
    status: RoughInStatus.planned,
    gaugeAwg: 16,
    mountSurface: MountSurface.inGround,
    conductorRoles: speakerRoles,
  );

  // 17 — The service entrance: the one fibre, and the one outlet whose
  // role is not a home run from a room.
  final onts = outlet(
    designation: 'EQ-ONT-1',
    where: equip,
    template: 'outlet.data_only',
    pathway: groundRun,
    estimatedFeet: 8,
    wall: Wall.n,
    heightAff: inches(60),
    floorNumber: 1,
  );
  drop(
    outletId: onts,
    fieldLabel: 'EQ-FIB-1',
    fieldDescription: 'ISP demarcation, fibre ONT',
    where: equip,
    media: os2,
    family: const SignalFamilyId('net.fiber_sm'),
    termination: TerminationType.fieldConnector,
    jacket: JacketListing.cmr,
    pathway: groundRun,
    status: RoughInStatus.terminated,
    rackPort: fibrePort,
    rackLabel: 'LIU1-01',
    routedLength: feet(11),
    wall: Wall.n,
    heightAff: inches(60),
  );

  // --- Power -------------------------------------------------------------
  //
  // THREE dedicated 20 A branches, and the reason is arithmetic rather
  // than decoration. `computeRackRollups` sums every contributor's
  // `apparentVA`, and P03 declares 3000 VA — which for a UPS is its
  // OUTPUT RATING, not its draw. The rack's honest connected load is
  // about 2.4 kVA; the rollup will read 5.44 kVA. Three branches give a
  // continuous limit of 5.76 kVA, so this project reads clean under
  // BOTH interpretations rather than depending on which one a future DRC
  // takes. (That the two interpretations differ at all is a real gap in
  // `PowerProfile`, recorded here rather than papered over.)

  author
    ..addCircuit(
      doc,
      designator: 'C-21',
      breakerAmps: 20,
      volts: 120,
      rackId: rackId,
      locationId: equip,
      dedicated: true,
    )
    ..addCircuit(
      doc,
      designator: 'C-23',
      breakerAmps: 20,
      volts: 120,
      rackId: rackId,
      locationId: equip,
      dedicated: true,
    )
    ..addCircuit(
      doc,
      designator: 'C-25',
      breakerAmps: 20,
      volts: 120,
      rackId: rackId,
      locationId: equip,
      dedicated: true,
    )
    // --- Drawing furniture -----------------------------------------------
    ..addNote(
      doc,
      text:
          'Twelve of the twenty-seven home runs are pulled or planned '
          'but not terminated; their rack ends are open and they appear '
          'on the Unused Home Runs schedule until they are punched down.',
      targetId: structure.deviceId,
    )
    ..addNote(
      doc,
      text:
          'Lengths are recorded only where a run has been walked and '
          'measured. Everything else is left blank rather than estimated.',
    )
    ..addSchematicSheet(
      doc,
      number: 'E-201',
      title: 'Main House — Schematic',
      includedRackIds: [rackId],
    )
    ..addRevision(
      doc,
      revision: 'A',
      description: 'Issued for rough-in',
      by: 'RackPal',
      date: DateTime.utc(2026, 1, 30),
    )
    ..addRevision(
      doc,
      revision: 'B',
      description: 'Head-end updated after trim walkthrough',
      by: 'RackPal',
      date: DateTime.utc(2026, 4, 21),
    );

  return doc;
}
