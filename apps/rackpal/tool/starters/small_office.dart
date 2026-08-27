// Starter 3 — "Small office": TWO racks, and the placement variants the
// other three do not show.
//
// WHAT ONLY THIS ONE EXERCISES:
//
//   * TWO racks in one document, in two different rooms and two
//     different form factors (an 18 U floor enclosure and a 6 U wall
//     box). Everything that reads `racks.values.first` — the canvas, the
//     header bar, the chip strip — is exercised against a document where
//     that is a CHOICE rather than the only option.
//   * REAR-FACE rail placements. `Face.rear` has its own occupancy map,
//     its own chip-strip RU figure and its own elevation; a corpus where
//     every device is on the front leaves all three untested against
//     real data. The two rear devices sit at U16 and U17, which are FREE
//     on the front — so the drawing is unambiguous about depth as well
//     as legal about occupancy.
//   * `mountMethod: hosted` devices on a shelf. V06 and V07 are the two
//     seed templates that are explicitly hosted rather than rack-eared,
//     and a shelf is the thing that hosts them.
//   * A commercial 70 V audio system (A05 + F08 pendants), which is the
//     one signal chain the three residential starters never touch.
import 'package:rackpal_core/rackpal_core.dart';

import 'authoring.dart';

/// Builds the Small office starter.
RackDocument buildSmallOfficeStarter() {
  final author = StarterAuthor(
    createdAt: DateTime.utc(2026, 2, 17, 13, 30),
    modifiedAt: DateTime.utc(2026, 5, 6, 10, 12),
    appVersion: '0.1.0',
  );

  final doc = author.newDocument(
    info: ProjectInfo(
      projectName: 'Small Office',
      projectNumber: 'RM-2026-031',
      drawingNumber: 'AV-300',
      clientName: 'Sample Tenant Co.',
      siteAddress: Address(
        line1: '400 Example Boulevard, Suite 210',
        city: 'Sampleton',
        region: 'CA',
        postalCode: '90000',
        country: 'US',
      ),
      integratorName: 'Example Integration Co.',
      drawnBy: 'RackPal',
    ),
    sequence: 604,
  );

  // --- Locations ---------------------------------------------------------

  final suite = author.addLocation(
    doc,
    kind: LocationKind.building,
    name: 'Suite 210',
    code: 'S210',
    order: 0,
  );
  final floor = author.addLocation(
    doc,
    kind: LocationKind.floor,
    name: 'Second Floor',
    code: 'L2',
    order: 1,
    parentId: suite,
    floorNumber: 2,
  );
  final serverRoom = author.addLocation(
    doc,
    kind: LocationKind.room,
    name: 'Server Room',
    code: 'SRV',
    order: 2,
    parentId: floor,
    floorNumber: 2,
    estimatedRunLengthFromRack: feet(6),
  );
  final reception = author.addLocation(
    doc,
    kind: LocationKind.room,
    name: 'Reception',
    code: 'REC',
    order: 3,
    parentId: floor,
    floorNumber: 2,
    estimatedRunLengthFromRack: feet(70),
  );
  final boardroom = author.addLocation(
    doc,
    kind: LocationKind.room,
    name: 'Boardroom',
    code: 'BRD',
    order: 4,
    parentId: floor,
    floorNumber: 2,
    estimatedRunLengthFromRack: feet(45),
  );
  final openPlan = author.addLocation(
    doc,
    kind: LocationKind.zone,
    name: 'Open Plan',
    code: 'OP',
    order: 5,
    parentId: floor,
    floorNumber: 2,
    estimatedRunLengthFromRack: feet(35),
  );

  // --- Rack 1: the server room floor enclosure ---------------------------

  final main = author.addRack(
    doc,
    preset: buildRackPresets()['floorEnclosure18U']!,
    designator: 'RK-1',
    name: 'Server Room Rack',
    heightU: 18,
    order: 0,
    locationId: serverRoom,
    hasFrontDoor: true,
    hasRearDoor: true,
    groundBarPresent: true,
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

  Uuid mainRail(
    String catalogId,
    String designator,
    String name,
    int ru, {
    Face face = Face.front,
  }) => author.addRailDevice(
    doc,
    catalogId: catalogId,
    designator: designator,
    name: name,
    rackId: main,
    ruIndex: ru,
    face: face,
    locationId: serverRoom,
  );

  mainRail('P02', 'SEQ-1', 'Sequenced power', 1);
  mainRail('A05', 'AMP-1', '70 V paging amplifier', 3);
  mainRail('A03', 'DSP-1', 'Paging and BGM processor', 5);
  mainRail('N01', 'SW-1', 'Core switch', 6);
  mainRail('N02', 'FW-1', 'Router / firewall', 7);
  mainRail('C01', 'CTL-1', 'Room control processor', 8);
  final shelf = mainRail('X03', 'SHF-1', 'Transmitter shelf', 9);
  mainRail('N03', 'PP-1', 'Open plan patch panel', 11);
  mainRail('N03', 'PP-2', 'Boardroom patch panel', 12);
  mainRail('X01', 'BLK-1', 'Blank panel', 13);
  mainRail('X02', 'VNT-1', 'Vent panel', 14);

  // THE REAR ELEVATION. Both devices sit above the front stack rather
  // than back-to-back with it — see the file header.
  mainRail('N01', 'SW-2', 'Edge switch, rear-mounted', 16, face: Face.rear);
  mainRail('C03', 'SER-1', 'Serial gateway, rear-mounted', 17, face: Face.rear);

  author
    ..addShelfDevice(
      doc,
      catalogId: 'V06',
      designator: 'TX-1',
      name: 'Boardroom HDBaseT transmitter',
      hostDeviceId: shelf,
      order: 0,
      locationId: serverRoom,
    )
    ..addShelfDevice(
      doc,
      catalogId: 'V07',
      designator: 'ENC-1',
      name: 'Reception AVoIP encoder',
      hostDeviceId: shelf,
      order: 1,
      locationId: serverRoom,
    )
    ..addZeroUDevice(
      doc,
      catalogId: 'P01',
      designator: 'PDU-1',
      name: 'Rear PDU',
      rackId: main,
      channelId: 'ch-rear-left',
      locationId: serverRoom,
    );

  // --- Rack 2: the reception wall box ------------------------------------

  final wall = author.addRack(
    doc,
    preset: buildRackPresets()['wallBox6U']!,
    designator: 'RK-2',
    name: 'Reception Wall Box',
    heightU: 6,
    order: 1,
    locationId: reception,
    hasFrontDoor: true,
  );

  void wallRail(String catalogId, String designator, String name, int ru) {
    author.addRailDevice(
      doc,
      catalogId: catalogId,
      designator: designator,
      name: name,
      rackId: wall,
      ruIndex: ru,
      locationId: reception,
    );
  }

  wallRail('P02', 'SEQ-2', 'Sequenced power', 1);
  wallRail('N01', 'SW-3', 'Reception switch', 3);
  wallRail('N03', 'PP-3', 'Reception patch panel', 4);
  wallRail('X02', 'VNT-2', 'Vent panel', 5);

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

  field('F01', 'DISP-1', 'Boardroom display', boardroom);
  field('F01', 'DISP-2', 'Reception display', reception);
  field('F08', 'SPK-1', 'Open plan pendant, north', openPlan);
  field('F08', 'SPK-2', 'Open plan pendant, centre', openPlan);
  field('F08', 'SPK-3', 'Open plan pendant, south', openPlan);
  field('F08', 'SPK-4', 'Reception pendant', reception);
  field('F11', 'AP-1', 'Open plan access point', openPlan);
  field('F11', 'AP-2', 'Boardroom access point', boardroom);
  field('F12', 'TP-1', 'Boardroom touchpanel', boardroom);
  field('F09', 'CAM-1', 'Reception camera', reception);
  field('F16', 'ONT-1', 'Carrier handoff', serverRoom);

  // --- Power -------------------------------------------------------------

  author
    ..addCircuit(
      doc,
      designator: 'P2-14',
      breakerAmps: 20,
      volts: 120,
      rackId: main,
      locationId: serverRoom,
      dedicated: true,
    )
    ..addCircuit(
      doc,
      designator: 'P2-16',
      breakerAmps: 20,
      volts: 120,
      rackId: wall,
      locationId: reception,
      dedicated: true,
    )
    // --- Drawing furniture -----------------------------------------------
    ..addNote(
      doc,
      text:
          'SW-2 and SER-1 are mounted on the rear rails at U16 and U17, '
          'which are clear on the front elevation.',
      targetId: main,
    )
    ..addSchematicSheet(
      doc,
      number: 'E-301',
      title: 'Suite 210 — Schematic',
      includedRackIds: [main, wall],
    )
    ..addRevision(
      doc,
      revision: 'A',
      description: 'Issued for construction',
      by: 'RackPal',
      date: DateTime.utc(2026, 5, 6),
    );

  return doc;
}
