// Starter 4 — "Apartment": the small, sparse one.
//
// WHY A SPARSE PROJECT IS WORTH ONE OF THE FOUR SLOTS. Three of the four
// starters are dense, and a corpus of only dense documents tests one
// shape of everything: a rack with free rails at both ends, a project
// with a handful of entities, and a file that is dominated by its
// embedded template catalog rather than by its content. This one is the
// counterweight, and it is the fastest of the four to open — which makes
// it the honest fixture for "how long does opening a starter take when
// the answer is not about the document".
//
// It is also the screenshot source for a rack that is NOT full: docs/04
// §9's empty-rack story ("renders rails, holes and ruler at full
// fidelity — it should look like a rack immediately") needs a real
// document with real empty rails in it, not an empty one.
//
// A 9 U wall-mounted swing frame, which is the enclosure a flat actually
// gets: `isSwingFrame: true` and `hingeSide: left` come from the "Swing
// gate 12U / 18 in" archetype, at the 9 U the New-rack dialog's third
// field asked for.
import 'package:rackpal_core/rackpal_core.dart';

import 'authoring.dart';

/// Builds the Apartment starter.
RackDocument buildApartmentStarter() {
  final author = StarterAuthor(
    createdAt: DateTime.utc(2026, 5, 11, 15, 45),
    modifiedAt: DateTime.utc(2026, 5, 12, 9, 20),
    appVersion: '0.1.0',
  );

  final doc = author.newDocument(
    info: ProjectInfo(
      projectName: 'Apartment',
      projectNumber: 'RM-2026-042',
      drawingNumber: 'AV-400',
      clientName: 'Sample Client',
      siteAddress: Address(
        line1: '8 Example Court, Apartment 4B',
        city: 'Sampleton',
        region: 'CA',
        postalCode: '90000',
        country: 'US',
      ),
      integratorName: 'Example Integration Co.',
      drawnBy: 'RackPal',
    ),
    sequence: 37,
  );

  // --- Locations ---------------------------------------------------------

  final flat = author.addLocation(
    doc,
    kind: LocationKind.building,
    name: 'Apartment 4B',
    code: '4B',
    order: 0,
  );
  final cupboard = author.addLocation(
    doc,
    kind: LocationKind.room,
    name: 'Hall Cupboard',
    code: 'HC',
    order: 1,
    parentId: flat,
    floorNumber: 4,
    estimatedRunLengthFromRack: feet(4),
  );
  final living = author.addLocation(
    doc,
    kind: LocationKind.room,
    name: 'Living Room',
    code: 'LR',
    order: 2,
    parentId: flat,
    floorNumber: 4,
    estimatedRunLengthFromRack: feet(28),
  );
  final bedroom = author.addLocation(
    doc,
    kind: LocationKind.room,
    name: 'Bedroom',
    code: 'BR',
    order: 3,
    parentId: flat,
    floorNumber: 4,
    estimatedRunLengthFromRack: feet(34),
  );

  // --- The rack ----------------------------------------------------------

  final rackId = author.addRack(
    doc,
    preset: buildRackPresets()['swingGate12U']!,
    designator: 'RK-1',
    name: 'Hall Cupboard Rack',
    heightU: 9,
    order: 0,
    locationId: cupboard,
    hasFrontDoor: true,
  );

  void rail(String catalogId, String designator, String name, int ru) {
    author.addRailDevice(
      doc,
      catalogId: catalogId,
      designator: designator,
      name: name,
      rackId: rackId,
      ruIndex: ru,
      locationId: cupboard,
    );
  }

  rail('P02', 'SEQ-1', 'Sequenced power', 1);
  rail('N01', 'SW-1', 'PoE switch', 3);
  rail('N02', 'FW-1', 'Router / firewall', 4);
  rail('V02', 'MTX-1', 'HDMI matrix', 5);
  rail('N03', 'PP-1', 'Patch panel', 6);
  rail('X02', 'VNT-1', 'Vent panel', 7);
  // U8 and U9 are deliberately empty. See the file header.

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

  field('F01', 'DISP-1', 'Living room display', living);
  field('F01', 'DISP-2', 'Bedroom display', bedroom);
  field('F04', 'SPK-1', 'Living room ceiling pair', living);
  field('F11', 'AP-1', 'Hall access point', cupboard);
  field('F16', 'ONT-1', 'Building fibre handoff', cupboard);

  // --- Power -------------------------------------------------------------

  author
    ..addCircuit(
      doc,
      designator: 'A-9',
      breakerAmps: 15,
      volts: 120,
      rackId: rackId,
      locationId: cupboard,
    )
    // --- Drawing furniture -----------------------------------------------
    ..addNote(
      doc,
      text:
          'Swing frame: leave 600 mm clear in front of the cupboard door '
          'so the frame can open for rear access.',
      targetId: rackId,
    )
    ..addSchematicSheet(
      doc,
      number: 'E-401',
      title: 'Apartment 4B — Schematic',
      includedRackIds: [rackId],
    )
    ..addRevision(
      doc,
      revision: 'A',
      description: 'Issued for install',
      by: 'RackPal',
      date: DateTime.utc(2026, 5, 12),
    );

  return doc;
}
