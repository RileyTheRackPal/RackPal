// The shared authoring vocabulary for the four starter projects.
//
// ==================================================================
// WHY THIS IS BUILD-TIME CODE AND NOT `lib/`
// ==================================================================
// docs/04-rack-editor.md §9 and AC-052 require the starters to be REAL
// `.rackmate` FILES — "goldens, perf fixtures and screenshot source". A
// document rebuilt from Dart on every launch is none of those three: a
// golden that regenerates itself cannot detect a codec regression, and a
// perf fixture that never touches a disk does not measure the thing that
// is slow. So this authoring code runs ONCE, at `tool/generate_starters
// .dart` time, and what ships is bytes.
//
// The app therefore never imports this file. `test/starters/
// starter_assets_test.dart` does, and asserts the checked-in bytes are
// exactly what these builders produce — so a hand-edit of an asset, or a
// codec change that alters the encoding, fails in CI rather than in a
// screenshot six weeks later.
//
// ==================================================================
// IDENTITY IS DETERMINISTIC, WHICH IS WHAT MAKES THEM GOLDENS
// ==================================================================
// `newEntityId()` is a random UUIDv7. Four starters minted with it would
// produce different bytes on every regeneration, and "the checked-in
// bytes are what the builder produces" would be untestable. [StarterAuthor
// .mint] therefore emits UUIDv7-SHAPED ids from the document's own
// authored `createdAt` plus a counter: same version nibble (7), same
// variant nibble (8), same 48-bit millisecond prefix a real v7 carries,
// and a sequence where a real one has entropy. Nothing in the codec or
// the model parses a UUID — they are opaque strings (units/ids.dart) —
// so this is a naming convention, not a format claim.
//
// ==================================================================
// EVERY DEVICE COMES FROM THE 48-TEMPLATE SEED CATALOG
// ==================================================================
// No starter invents a template. [railDevice] and its siblings resolve
// `doc.templates['<catalogId>@1']` and take the occupancy, weight, power
// and ports from there, exactly as `buildPlaceFromCatalogCommand` does
// when a user places from the palette — so a starter cannot contain a
// device the user could not have placed themselves.
//
// The ONE documented exception is the Structure device, which
// docs/07-structure-device.md §2 row 3 states has NO template at all
// ("Ports come from a TemplateSnapshot | No template. Its 'ports' are a
// rendering of home-run field endpoints"). See [structureDevice].
import 'package:rackmate_core/rackmate_core.dart';

/// Recorded as `EntityMeta.updatedBy` on every entity in every starter.
///
/// Not a person's name: these files ship with the application, and
/// docs/12 §4's redaction rule is about real identities reaching real
/// files. "RackMate" is the truthful author of a bundled asset.
const String kStarterActor = 'RackMate';

/// The `version` every seed-catalog `TemplateSnapshot` is embedded at,
/// matching `catalogTemplateKey`'s own `"<id>@1"` scheme.
const int kStarterTemplateVersion = 1;

/// A `FracIndex` whose lexicographic order matches [index]'s numeric
/// order.
///
/// `'a$index'` does NOT: `'a10' < 'a9'` lexicographically, which would
/// silently reorder the eleventh outlet in a project ahead of the tenth.
/// Base-36 zero-padded to three digits keeps 46 656 entries ordered
/// correctly, which is well past anything a starter holds.
FracIndex fracIndex(int index) =>
    FracIndex('a${index.toRadixString(36).padLeft(3, '0')}');

/// Builds one starter document, minting deterministic ids as it goes.
final class StarterAuthor {
  StarterAuthor({
    required this.createdAt,
    required this.modifiedAt,
    required this.appVersion,
  }) : _timeHex = createdAt.millisecondsSinceEpoch
           .toRadixString(16)
           .padLeft(12, '0');

  /// The document's authored creation instant. Also seeds every minted
  /// id's timestamp prefix, so ids from different starters cannot
  /// collide.
  final DateTime createdAt;

  /// The document's authored modification instant.
  final DateTime modifiedAt;

  /// Written to `RackDocument.appVersion` (diagnostics only).
  final String appVersion;

  final String _timeHex;
  int _minted = 0;

  /// How many ids this author has handed out. Asserted by the round-trip
  /// test as a cheap "the builder actually built something" signal.
  int get mintedCount => _minted;

  /// A deterministic, UUIDv7-shaped id. See the file header.
  Uuid mint() {
    final seq = (++_minted).toRadixString(16).padLeft(18, '0');
    return Uuid(
      '${_timeHex.substring(0, 8)}-${_timeHex.substring(8, 12)}'
      '-7${seq.substring(0, 3)}-8${seq.substring(3, 6)}'
      '-${seq.substring(6, 18)}',
    );
  }

  /// A fresh `EntityMeta` for one entity.
  ///
  /// FRESH RATHER THAN SHARED because `EntityMeta` is mutable and
  /// `touch()` bumps `localRevision` in place — one instance shared
  /// across a whole document would make the user's first edit appear to
  /// have touched every entity at once.
  EntityMeta meta({int localRevision = 1}) => EntityMeta(
    createdAt: createdAt,
    updatedAt: modifiedAt,
    updatedBy: kStarterActor,
    localRevision: localRevision,
  );

  /// A new document with the full 48-template seed catalog embedded.
  ///
  /// THE WHOLE CATALOG, NOT JUST WHAT THIS PROJECT USES.
  /// `buildPlaceFromCatalogCommand` resolves `doc.templates['<id>@1']` and
  /// REFUSES when it is missing, so a starter carrying only its own
  /// templates would open with a palette where most rows refuse to place.
  /// `buildBlankDocument` embeds all 48 for exactly this reason, and a
  /// starter must not be a second-class document.
  RackDocument newDocument({
    required ProjectInfo info,
    ProjectSettings? settings,
    int sequence = 0,
  }) {
    final doc = RackDocument(
      id: mint(),
      appVersion: appVersion,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      meta: meta(),
      info: info,
      settings: settings,
      sequence: sequence,
    );
    for (final entry in buildSeedCatalog().entries) {
      doc.templates[catalogTemplateKey(entry.key)] = TemplateSnapshot(
        templateId: TemplateId(entry.key),
        version: kStarterTemplateVersion,
        contentHash: 'sha256:seed-${entry.key}',
        capturedAt: createdAt,
        body: entry.value,
      );
    }
    // Same one line, and the same reason, as `buildBlankDocument`: the
    // convention is seeded at CREATION, never defaulted on
    // `ProjectSettings`, so an older file still decodes with none. A
    // starter must not be a second-class document.
    doc.settings.jacketColorConventions.addAll(
      buildDefaultJacketColorConvention(),
    );
    // And the same again for the registries (DR-010 §11.10.2). THE FOUR
    // STARTERS ARE REGENERATED FOR THIS, deliberately: they are shipped
    // fixtures rather than user data, so unlike a user's `.rackmate` they
    // are rebuilt from the Dart master with a reviewable golden diff.
    doc.registries = buildSeedRegistries();
    return doc;
  }

  // --- Locations ---------------------------------------------------------

  /// Adds one `Location` and returns its id.
  Uuid addLocation(
    RackDocument doc, {
    required LocationKind kind,
    required String name,
    required String code,
    required int order,
    Uuid? parentId,
    int? floorNumber,
    Len? estimatedRunLengthFromRack,
  }) {
    final id = mint();
    doc.locations[id] = Location(
      id: id,
      kind: kind,
      name: name,
      code: code,
      order: fracIndex(order),
      meta: meta(),
      parentId: parentId,
      floorNumber: floorNumber,
      estimatedRunLengthFromRack: estimatedRunLengthFromRack,
    );
    return id;
  }

  // --- Racks -------------------------------------------------------------

  /// Adds a rack built from [preset], at [heightU].
  ///
  /// PRESET PLUS HEIGHT IS THE PRODUCT'S OWN SHAPE, not a shortcut here:
  /// docs/04 §9 fixes the New-rack dialog at "three fields — Name, Preset,
  /// Height", so a 24 U rack carrying a 27 U enclosure's depth, rail type
  /// and static load rating is exactly what a user gets when they pick the
  /// nearest archetype and type a height. Presets are not persisted
  /// (`rack_presets.dart`: there is no `presetRef`), so the file records
  /// only the resulting field values — which is why every number in a
  /// starter rack traces back to a reviewed archetype rather than to this
  /// file.
  Uuid addRack(
    RackDocument doc, {
    required RackPreset preset,
    required String designator,
    required String name,
    required int heightU,
    required int order,
    Uuid? locationId,
    List<ZeroUChannel> zeroUChannels = const [],
    bool hasFrontDoor = false,
    bool hasRearDoor = false,
    bool groundBarPresent = false,
  }) {
    final id = mint();
    doc.racks[id] = Rack(
      id: id,
      name: name,
      designator: designator,
      heightU: heightU,
      order: fracIndex(order),
      meta: meta(),
      locationId: locationId,
      widthClass: preset.widthClass,
      railType: preset.railType,
      formFactor: preset.formFactor,
      usableDepth: preset.usableDepth,
      weightCapacity: preset.weightCapacity,
      isSwingFrame: preset.isSwingFrame,
      hingeSide: preset.hingeSide,
      hasFrontDoor: hasFrontDoor,
      hasRearDoor: hasRearDoor,
      groundBarPresent: groundBarPresent,
      zeroUChannels: zeroUChannels,
    );
    return id;
  }

  // --- Devices -----------------------------------------------------------

  /// The `TemplateRef` for a seed-catalog id, resolved THROUGH the
  /// document's own snapshot store rather than reconstructed — so a
  /// device can never reference a template the file does not carry.
  TemplateRef templateRef(RackDocument doc, String catalogId) {
    final snapshot = doc.templates[catalogTemplateKey(catalogId)];
    if (snapshot == null) {
      throw ArgumentError.value(
        catalogId,
        'catalogId',
        'not embedded in this document',
      );
    }
    return TemplateRef(
      templateId: snapshot.templateId,
      version: snapshot.version,
      contentHash: snapshot.contentHash,
    );
  }

  /// The body behind a seed-catalog id.
  TemplateBody body(RackDocument doc, String catalogId) =>
      doc.templates[catalogTemplateKey(catalogId)]!.body;

  /// Adds a rail-mounted device at [ruIndex] on [face].
  Uuid addRailDevice(
    RackDocument doc, {
    required String catalogId,
    required String designator,
    required String name,
    required Uuid rackId,
    required int ruIndex,
    Face face = Face.front,
    DeviceKind? kind,
    Uuid? locationId,
    String? notes,
    LifecycleStatus lifecycleStatus = LifecycleStatus.new_,
  }) {
    final id = mint();
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: kind ?? starterDeviceKindFor(catalogId, body(doc, catalogId)),
      templateRef: templateRef(doc, catalogId),
      designator: designator,
      name: name,
      placement: RailPlacement(rackId: rackId, ruIndex: ruIndex, face: face),
      meta: meta(),
      locationId: locationId,
      notes: notes,
      lifecycleStatus: lifecycleStatus,
    );
    return id;
  }

  /// Adds a device sitting ON a shelf (`X03`), hosted by [hostDeviceId].
  Uuid addShelfDevice(
    RackDocument doc, {
    required String catalogId,
    required String designator,
    required String name,
    required Uuid hostDeviceId,
    required int order,
    Uuid? locationId,
    String? notes,
  }) {
    final id = mint();
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: starterDeviceKindFor(catalogId, body(doc, catalogId)),
      templateRef: templateRef(doc, catalogId),
      designator: designator,
      name: name,
      placement: ShelfPlacement(
        hostDeviceId: hostDeviceId,
        order: fracIndex(order),
      ),
      meta: meta(),
      locationId: locationId,
      notes: notes,
    );
    return id;
  }

  /// Adds a 0U occupant in a rack's vertical channel (AC-044).
  Uuid addZeroUDevice(
    RackDocument doc, {
    required String catalogId,
    required String designator,
    required String name,
    required Uuid rackId,
    required String channelId,
    Len offsetFromChannelStart = const Len(0),
    Uuid? locationId,
    String? notes,
  }) {
    final id = mint();
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: starterDeviceKindFor(catalogId, body(doc, catalogId)),
      templateRef: templateRef(doc, catalogId),
      designator: designator,
      name: name,
      placement: ZeroUPlacement(
        rackId: rackId,
        channelId: channelId,
        offsetFromChannelStart: offsetFromChannelStart,
        orientation: ZeroUOrientation.vertical,
      ),
      meta: meta(),
      locationId: locationId,
      notes: notes,
    );
    return id;
  }

  /// Adds a field device — one of the 18 `mountMethod: notInRack`
  /// templates — at a location.
  Uuid addFieldDevice(
    RackDocument doc, {
    required String catalogId,
    required String designator,
    required String name,
    required Uuid locationId,
    String? mountNote,
    String? notes,
  }) {
    final id = mint();
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: starterDeviceKindFor(catalogId, body(doc, catalogId)),
      templateRef: templateRef(doc, catalogId),
      designator: designator,
      name: name,
      placement: OffRackPlacement(
        locationId: locationId,
        mountNote: mountNote,
      ),
      meta: meta(),
      locationId: locationId,
      notes: notes,
    );
    return id;
  }

  /// Adds the Structure device and its `StructureBody`, returning both
  /// ids.
  ///
  /// THE ONE DEVICE IN ANY STARTER WITH NO TEMPLATE SNAPSHOT BEHIND IT,
  /// and that is the spec rather than an omission. docs/07 §2's table,
  /// row 3: *"Ports come from a `TemplateSnapshot` | **No template.** Its
  /// 'ports' are a rendering of home-run field endpoints (AC-019)"*, and
  /// row 2: *"Zero RU, zero weight, `mountMethod: notInRack`. Renders in
  /// the rack elevation not at all."* `DeviceInstance.templateRef` is
  /// non-nullable, so the ref names the reserved `structure` id at
  /// version 1 and resolves to nothing — which every occupancy scan in
  /// core already tolerates, because `elevationOccupantsOnFace` only ever
  /// looks at `RailPlacement`s and this device is off-rack.
  ///
  /// `starter_integrity_test.dart` exempts `DeviceKind.structure` from
  /// its "every templateRef resolves" rule and cites this paragraph, so
  /// the exemption is one named case rather than a hole.
  ({Uuid deviceId, Uuid bodyId}) addStructure(
    RackDocument doc, {
    required String designator,
    required String title,
    required Uuid distributionDeviceLocationId,
    required String enclosureModel,
    StructureRole role = StructureRole.homeRunField,
  }) {
    final deviceId = mint();
    final bodyId = mint();
    doc.devices[deviceId] = DeviceInstance(
      id: deviceId,
      kind: DeviceKind.structure,
      templateRef: const TemplateRef(
        templateId: TemplateId('structure'),
        version: kStarterTemplateVersion,
        contentHash: 'sha256:structure-no-template',
      ),
      designator: designator,
      name: title,
      placement: OffRackPlacement(
        locationId: distributionDeviceLocationId,
      ),
      meta: meta(),
      locationId: distributionDeviceLocationId,
      structureBodyId: bodyId,
    );
    doc.structures[bodyId] = StructureBody(
      id: bodyId,
      deviceId: deviceId,
      title: title,
      meta: meta(),
      role: role,
      distributionDeviceLocationId: distributionDeviceLocationId,
      enclosureModel: enclosureModel,
    );
    return (deviceId: deviceId, bodyId: bodyId);
  }

  // --- Ports -------------------------------------------------------------

  /// Materialises one port on [deviceId] so a `Conductor` can land on it.
  ///
  /// AC-006: ports are NOT materialised unless they carry state. A home
  /// run punched down on `PP-1 / rear.07` is exactly such a state, and
  /// the id comes from `derivePortId` — the same UUIDv5 derivation the
  /// rest of the system uses — so the same physical port always has the
  /// same id however it came to exist.
  Uuid addPort(
    RackDocument doc, {
    required Uuid deviceId,
    required String portKey,
    required String designator,
  }) {
    final key = PortKey(portKey);
    final id = derivePortId(deviceId, key);
    doc.ports[id] = Port(
      id: id,
      deviceId: deviceId,
      designator: designator,
      templatePortKey: key,
    );
    return id;
  }

  // --- Structured wiring -------------------------------------------------

  /// Adds a `Pathway` — a conduit, J-hook run, tray or riser N home runs
  /// share (CR-016: "bundle" is two entities and names neither).
  Uuid addPathway(
    RackDocument doc, {
    required String name,
    required PathwayKind kind,
    required int order,
    Uuid? fromLocationId,
    Uuid? toLocationId,
    Len? nominalLength,
    bool containsLineVoltage = false,
    String? notes,
  }) {
    final id = mint();
    doc.pathways[id] = Pathway(
      id: id,
      name: name,
      order: fracIndex(order),
      meta: meta(),
      kind: kind,
      containsLineVoltage: containsLineVoltage,
      fromLocationId: fromLocationId,
      toLocationId: toLocationId,
      nominalLength: nominalLength,
      notes: notes,
    );
    return id;
  }

  /// Adds an `Outlet` — ONE wall plate or ONE ceiling location (CR-016).
  /// Its members are `Link`s that name it back through
  /// `Link.structureOrigin.outletId` (AC-019); it holds no member list.
  Uuid addOutlet(
    RackDocument doc, {
    required Uuid structureBodyId,
    required String designation,
    required int order,
    Uuid? locationId,
    Wall? wall,
    MountSurface? mountSurface,
    Len? mountHeightAff,
    int? floorNumber,
    String? outletTemplateId,
    String? tia570Grade,
    Uuid? pathwayId,
    Len? nominalRunLength,
    String? notes,
  }) {
    final id = mint();
    doc.outlets[id] = Outlet(
      id: id,
      structureBodyId: structureBodyId,
      designation: designation,
      order: fracIndex(order),
      meta: meta(),
      locationId: locationId,
      wall: wall,
      mountSurface: mountSurface,
      mountHeightAff: mountHeightAff,
      floorNumber: floorNumber,
      outletTemplateId: outletTemplateId,
      tia570Grade: tia570Grade,
      pathwayId: pathwayId,
      nominalRunLength: nominalRunLength,
      notes: notes,
    );
    return id;
  }

  /// Adds one home run: a `Link` with its implicit `Net`, one `Service`
  /// and one `Conductor`.
  ///
  /// THE SHAPE IS `AddLinkCommand`'s, DELIBERATELY — one net per link,
  /// `Service(id: 'svc-1', ...)`, exactly one conductor — so a starter's
  /// links are indistinguishable from links the running application
  /// creates, and a future command that edits one cannot be surprised by
  /// a shape only the starters have.
  Uuid addHomeRun(
    RackDocument doc, {
    required String designator,
    required MediaTypeId media,
    required SignalFamilyId signalFamily,
    required int order,
    required Endpoint fieldEnd,
    required Endpoint rackEnd,
    required StructureOrigin origin,
    // RJ-016: one 16/4 speaker cable is ONE `Link` with FOUR
    // `Conductor`s. Naming the roles here fans `fieldEnd`/`rackEnd` out
    // into one `Conductor` each — the four conductors of a 16/4 run
    // between the same two places and differ only in role, pair and
    // jacket colour. The default is the single-conductor shape
    // `AddLinkCommand` produces.
    List<({String role, int? pairNumber, String colorCode})>? conductorRoles,
    Uuid? pathwayId,
    JacketRating? jacket,
    // The colour of the SHEATH, which is not [jacket] (the NEC fire
    // rating) and not a `Conductor.colorCode` (the pair colour inside
    // it). Null means the run's colour was not recorded — the ordinary
    // state for cabling that is not category cable, where a shop's
    // colours carry no convention.
    JacketColorId? jacketColorId,
    int? gaugeAwg,
    Len? routedLength,
    RoughInStatus roughInStatus = RoughInStatus.planned,
    LinkClass linkClass = LinkClass.fieldCable,
    bool plenum = false,
    String? serviceLabel,
    String? notes,
  }) {
    final netId = mint();
    final linkId = mint();
    doc.nets[netId] = Net(
      id: netId,
      name: '',
      signalFamily: signalFamily,
      meta: meta(),
    );
    doc.links[linkId] = Link(
      id: linkId,
      designator: designator,
      media: media,
      order: fracIndex(order),
      meta: meta(),
      linkClass: linkClass,
      services: [
        Service(
          id: 'svc-1',
          signalFamily: signalFamily,
          netId: netId,
          label: serviceLabel,
        ),
      ],
      conductors: [
        if (conductorRoles == null)
          Conductor(from: fieldEnd, to: rackEnd)
        else
          for (final c in conductorRoles)
            Conductor(
              from: fieldEnd,
              to: rackEnd,
              role: c.role,
              pairNumber: c.pairNumber,
              colorCode: c.colorCode,
            ),
      ],
      gaugeAwg: gaugeAwg,
      jacket: jacket,
      jacketColorId: jacketColorId,
      plenum: plenum,
      routedLength: routedLength,
      pathwayId: pathwayId,
      roughInStatus: roughInStatus,
      structureOrigin: origin,
      notes: notes,
    );
    return linkId;
  }

  // --- Power -------------------------------------------------------------

  /// Adds a branch `Circuit`. `continuousLimitAmps` is derived (80 % of
  /// the breaker), never stored.
  Uuid addCircuit(
    RackDocument doc, {
    required String designator,
    required int breakerAmps,
    required int volts,
    Uuid? rackId,
    Uuid? locationId,
    bool dedicated = false,
  }) {
    final id = mint();
    doc.circuits[id] = Circuit(
      id: id,
      designator: designator,
      breakerAmps: breakerAmps,
      volts: volts,
      meta: meta(),
      rackId: rackId,
      locationId: locationId,
      dedicated: dedicated,
    );
    return id;
  }

  // --- Drawing furniture -------------------------------------------------

  /// Adds a free `Note`, or one attached to [targetId].
  Uuid addNote(RackDocument doc, {required String text, Uuid? targetId}) {
    final id = mint();
    doc.notes[id] = Note(id: id, text: text, meta: meta(), targetId: targetId);
    return id;
  }

  /// Adds the single schematic `Sheet` every document carries (CR-073,
  /// DR-004, AC-037). Empty of items: no schematic surface exists in this
  /// build, and a `SheetItem` placed by nothing would be a fabrication.
  Uuid addSchematicSheet(
    RackDocument doc, {
    required String number,
    required String title,
    List<Uuid> includedRackIds = const [],
  }) {
    final id = mint();
    doc.sheets[id] = Sheet(
      id: id,
      number: number,
      title: title,
      order: fracIndex(0),
      meta: meta(),
      includedRackIds: includedRackIds,
    );
    return id;
  }

  /// Appends one row to the title block's revision history.
  void addRevision(
    RackDocument doc, {
    required String revision,
    required String description,
    required String by,
    DateTime? date,
  }) {
    doc.revisionBlock.add(
      RevisionEntry(
        revision: revision,
        date: date ?? createdAt,
        description: description,
        by: by,
      ),
    );
  }
}

/// The `DeviceKind` a seed-catalog id maps to.
///
/// A TRANSCRIPTION of `buildPlaceFromCatalogCommand`'s own private
/// `_kindFor`, which is what a user placing from the palette gets.
/// Restated rather than shared because that function is private to core's
/// placement factory — and `starter_assets_test.dart` asserts the two
/// agree for all 48 catalog ids by placing every one of them through the
/// real command, so a divergence is a test failure rather than a starter
/// whose blank panels are typed as ordinary devices.
DeviceKind starterDeviceKindFor(String catalogId, TemplateBody body) =>
    switch (catalogId) {
      'X01' => DeviceKind.blankPanel,
      'X02' => DeviceKind.ventPanel,
      'X03' => DeviceKind.shelf,
      'P01' => DeviceKind.pdu,
      'P03' => DeviceKind.ups,
      _ =>
        body.mountMethod == MountMethod.notInRack
            ? DeviceKind.offRackPassive
            : DeviceKind.rackDevice,
    };

/// Feet as exact nanometres (CR-001 — no floating point in a persisted
/// length). One foot is 12 inches; `Len.nmPerInch` is 25 400 000.
Len feet(int ft) => Len(ft * 12 * Len.nmPerInch);

/// Inches as exact nanometres.
Len inches(int inch) => Len(inch * Len.nmPerInch);
