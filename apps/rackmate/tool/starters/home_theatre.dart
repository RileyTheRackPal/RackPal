// Starter 1 — "Home theatre", the one docs/04-rack-editor.md §9 names.
//
// §9's sentence is the specification: *"A user who picks 'Home theater'
// is editing a populated, finding-clean 24U rack in two seconds, which is
// a far lower-effort mode than creating one."* So this is ONE 24 U rack,
// densely populated, with nothing in it that a validation engine could
// reasonably object to:
//
//   * no two devices overlap on either face,
//   * nothing hangs past the top of the rack,
//   * every device resolves its template,
//   * every designator is unique,
//   * 80 kg on a 500 kg enclosure,
//   * 12 outlets consumed against 40 provided,
//   * 1.67 kVA on a dedicated 20 A / 120 V circuit, whose 80 % continuous
//     limit is 1.92 kVA — so the one power figure a v1 DRC will certainly
//     check passes with real headroom rather than by rounding.
//
// It also carries the two placement variants a rack editor screenshot
// needs and the rail alone does not show: a 2 U shelf HOSTING two
// components (`ShelfPlacement`) and a 0 U vertical PDU in the rear-left
// channel (`ZeroUPlacement`, AC-044).
import 'package:rackmate_core/rackmate_core.dart';

import 'authoring.dart';

/// Builds the Home theatre starter.
RackDocument buildHomeTheatreStarter() {
  final author = StarterAuthor(
    createdAt: DateTime.utc(2026, 3, 2, 9, 15),
    modifiedAt: DateTime.utc(2026, 3, 9, 16, 40),
    appVersion: '0.1.0',
  );

  final doc = author.newDocument(
    info: ProjectInfo(
      projectName: 'Home Theatre',
      projectNumber: 'RM-2026-001',
      drawingNumber: 'AV-100',
      clientName: 'Sample Client',
      siteAddress: Address(
        line1: '12 Example Street',
        city: 'Sampleton',
        region: 'CA',
        postalCode: '90000',
        country: 'US',
      ),
      integratorName: 'Example Integration Co.',
      drawnBy: 'RackMate',
    ),
    // A starter is a document a user is about to edit, so its sequence
    // starts where a real short authoring session would leave it rather
    // than at a suspiciously round zero.
    sequence: 96,
  );

  // --- Locations ---------------------------------------------------------

  final house = author.addLocation(
    doc,
    kind: LocationKind.building,
    name: 'Main House',
    code: 'MH',
    order: 0,
  );
  final ground = author.addLocation(
    doc,
    kind: LocationKind.floor,
    name: 'Ground Floor',
    code: 'L1',
    order: 1,
    parentId: house,
    floorNumber: 1,
  );
  final closet = author.addLocation(
    doc,
    kind: LocationKind.room,
    name: 'Equipment Closet',
    code: 'EQ',
    order: 2,
    parentId: ground,
    floorNumber: 1,
    estimatedRunLengthFromRack: feet(5),
  );
  final theatre = author.addLocation(
    doc,
    kind: LocationKind.room,
    name: 'Media Room',
    code: 'MED',
    order: 3,
    parentId: ground,
    floorNumber: 1,
    estimatedRunLengthFromRack: feet(45),
  );
  final hall = author.addLocation(
    doc,
    kind: LocationKind.zone,
    name: 'Hallway',
    code: 'HALL',
    order: 4,
    parentId: ground,
    floorNumber: 1,
    estimatedRunLengthFromRack: feet(25),
  );

  // --- The rack ----------------------------------------------------------

  // The "Floor enclosure 27U" archetype at 24 U — Preset + Height, which
  // is exactly what §9's three-field New-rack dialog produces. Its depth
  // (609.6 mm), rail type (square cage-nut) and 500 kg static rating come
  // from `rack_presets.dart`, not from this file.
  final rackId = author.addRack(
    doc,
    preset: buildRackPresets()['floorEnclosure27U']!,
    designator: 'RK-1',
    name: 'Cinema Rack',
    heightU: 24,
    order: 0,
    locationId: closet,
    hasFrontDoor: true,
    hasRearDoor: true,
    groundBarPresent: true,
    zeroUChannels: [
      ZeroUChannel(
        id: 'ch-rear-left',
        side: ZeroUChannelSide.rearLeft,
        startU: 1,
        endU: 24,
        name: 'Rear left',
      ),
      ZeroUChannel(
        id: 'ch-rear-right',
        side: ZeroUChannelSide.rearRight,
        startU: 1,
        endU: 24,
        name: 'Rear right',
      ),
    ],
  );

  // --- Front elevation, bottom-up ---------------------------------------
  //
  // Heavy and hot at the bottom, signal in the middle, patching at the
  // top — the order an integrator actually builds a rack in, which is
  // what makes this usable as a screenshot rather than a list.

  Uuid rail(String catalogId, String designator, String name, int ru) =>
      author.addRailDevice(
        doc,
        catalogId: catalogId,
        designator: designator,
        name: name,
        rackId: rackId,
        ruIndex: ru,
        locationId: closet,
      );

  rail('P02', 'SEQ-1', 'Sequenced power', 1);
  rail('A04', 'AMP-1', 'L/R power amplifier', 3);
  final shelf = rail('X03', 'SHF-1', 'Source shelf', 5);
  rail('V03', 'MTX-1', 'House video matrix', 7);
  rail('V04', 'DA-1', 'Projector feed DA', 11);
  rail('N01', 'SW-1', 'AV network switch', 12);
  rail('N02', 'FW-1', 'Router / firewall', 13);
  rail('C01', 'CTL-1', 'Control processor', 14);
  rail('C02', 'IRB-1', 'IR distribution', 15);
  rail('X02', 'VNT-1', 'Vent panel', 16);
  rail('N03', 'PP-1', 'Room patch panel', 17);
  rail('X01', 'BLK-1', 'Blank panel', 18);
  // U19-U24 are deliberately clear: six rack units of growth, and the
  // empty rails a screenshot of a REAL project always has.

  // 11.8 kg + 1.4 kg on a shelf rated 22.7 kg (X03's own
  // `containerWeightCapacity`) — inside the one shelf limit a DRC would
  // check.
  author
    ..addShelfDevice(
      doc,
      catalogId: 'A02',
      designator: 'AVR-1',
      name: 'Cinema AV receiver',
      hostDeviceId: shelf,
      order: 0,
      locationId: closet,
    )
    ..addShelfDevice(
      doc,
      catalogId: 'S01',
      designator: 'STB-1',
      name: 'Cable box',
      hostDeviceId: shelf,
      order: 1,
      locationId: closet,
    )
    ..addZeroUDevice(
      doc,
      catalogId: 'P01',
      designator: 'PDU-1',
      name: 'Rear PDU',
      rackId: rackId,
      channelId: 'ch-rear-left',
      locationId: closet,
    );

  // --- The field ---------------------------------------------------------

  void field(
    String catalogId,
    String designator,
    String name,
    Uuid where, {
    String? mountNote,
  }) {
    author.addFieldDevice(
      doc,
      catalogId: catalogId,
      designator: designator,
      name: name,
      locationId: where,
      mountNote: mountNote,
    );
  }

  field(
    'F02',
    'PROJ-1',
    'Cinema projector',
    theatre,
    mountNote: 'Ceiling mount, rear of room',
  );
  field(
    'F03',
    'SCRN-1',
    'Motorised screen',
    theatre,
    mountNote: 'Recessed, front wall',
  );
  field(
    'F01',
    'DISP-1',
    'Secondary display',
    theatre,
    mountNote: 'Side wall, casual viewing',
  );
  field(
    'F05',
    'SPK-1',
    'Front left',
    theatre,
    mountNote: 'In-wall, behind screen',
  );
  field('F05', 'SPK-2', 'Centre', theatre, mountNote: 'In-wall, behind screen');
  field(
    'F05',
    'SPK-3',
    'Front right',
    theatre,
    mountNote: 'In-wall, behind screen',
  );
  field(
    'F04',
    'SPK-4',
    'Surround pair',
    theatre,
    mountNote: 'In-ceiling, side walls',
  );
  field('F04', 'SPK-5', 'Height pair', theatre, mountNote: 'In-ceiling, front');
  field('F06', 'SUB-1', 'Subwoofer', theatre, mountNote: 'Front left corner');
  field(
    'F12',
    'TP-1',
    'Room touchpanel',
    theatre,
    mountNote: 'In-wall, entry door',
  );
  field('F15', 'IRR-1', 'IR receiver', theatre, mountNote: 'Under screen trim');
  field(
    'F13',
    'KP-1',
    'Hall keypad',
    hall,
    mountNote: 'Beside media room door',
  );
  field(
    'F11',
    'AP-1',
    'Hall access point',
    hall,
    mountNote: 'Ceiling, centre of hall',
  );
  field('F16', 'ONT-1', 'Fibre ONT', closet, mountNote: 'Wall beside rack');

  // --- Power -------------------------------------------------------------

  author
    ..addCircuit(
      doc,
      designator: 'C-12',
      breakerAmps: 20,
      volts: 120,
      rackId: rackId,
      locationId: closet,
      dedicated: true,
    )
    // --- Drawing furniture -----------------------------------------------
    ..addNote(
      doc,
      text:
          'Amplifier and receiver share the lower half of the rack; the '
          'vent panel at U16 is the exhaust path for both.',
      targetId: rackId,
    )
    ..addSchematicSheet(
      doc,
      number: 'E-101',
      title: 'Media Room — Schematic',
      includedRackIds: [rackId],
    )
    ..addRevision(
      doc,
      revision: 'A',
      description: 'Issued for review',
      by: 'RackMate',
      date: DateTime.utc(2026, 3, 9),
    );

  return doc;
}
