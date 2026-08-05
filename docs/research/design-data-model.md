# RackMate: Domain & Persistence Data Model

**Status:** design spec, v1 schema. Opinionated throughout. Every rejected alternative is named.

Three vocabulary changes from the brief, made deliberately and argued in §3.5:

| You said | I model it as | Why |
|---|---|---|
| `Connection` | **`Link`** (physical, exactly 2 ends) + **`Net`** (logical N-way) + **`SignalRoute`** (transport-independent flow) | "Connection" is three different things in this domain and conflating them is the single most expensive mistake available here |
| `CableType` / `SignalType` | **`SignalFamily`** + **`ConnectorType`** + **`MediaType`**, three orthogonal registries | RJ45 is a connector, not a signal; Cat6a is a medium, not a signal |
| `RackSlot` | **`Placement`** (sealed union) | Slots don't exist for 0U gear, shelf-hosted gear, or off-rack gear, and "slot" implies an array index, the thing we must never use as identity |

---

## 0. The shape, in one paragraph

The document is a **flat set of UUID-keyed entity maps** (never a tree), mutated **only** through undoable `Command`s. Physical facts live on **immutable, versioned `DeviceTemplate` snapshots embedded in the file**; project facts live on `DeviceInstance`. Ports are **first-class entities with stable string keys** so template revisions are a key-join, not a re-index. Wiring is **two layers**: `Link` = one cable = one schedule row = one `W###` designator; `Net` = one electrical/logical equivalence class = one bus trunk on the drawing. Validation **never blocks the pen**: it emits `Finding`s the user can acknowledge with a rationale. Everything is **integers**: RU counts, nanometres, schematic grid units. There is not a single float in the persisted model.

---

## 1. Entity-relationship overview

```
Project ────────────────────────────────────────────────────────────────────┐
 │ id, schemaVersion, revision, settings                                     │
 │                                                                           │
 ├─1:N─▶ Location            (tree: Site▶Building▶Floor▶Room▶Zone)          │
 │        └─self-ref parentId                                                │
 │                                                                           │
 ├─1:N─▶ Rack                                                                │
 │        │ heightU, railType, widthClass, depths, capacities, locationId ───┤
 │        └─1:N─▶ (referenced by Placement, not owned)                       │
 │                                                                           │
 ├─1:N─▶ TemplateSnapshot        ◀── IMMUTABLE. content-addressed.          │
 │        │ templateId + version + contentHash                               │
 │        ├─1:N─▶ PortDef        (key: stable string, NOT index)             │
 │        ├─1:N─▶ PortGroupDef                                               │
 │        └─0:N─▶ PassthroughPairDef  (patch panels: front↔rear same net)    │
 │                                                                           │
 ├─1:N─▶ DeviceInstance                                                      │
 │        │ templateRef ─────────────────▶ TemplateSnapshot (id+version)     │
 │        │ refDes, name, status, placement, overrides, locationId           │
 │        ├─1:N─▶ Port           (OWNED; templatePortKey joins to PortDef)   │
 │        ├─1:N─▶ PortGroup      (OWNED)                                     │
 │        ├─0:1──▶ StructureBody (iff kind == structure)                     │
 │        │         └─1:N─▶ StructureBundle                                  │
 │        │                    └─1:N─▶ StructureDrop ──1:1──▶ Port           │
 │        └─0:1──▶ hostDeviceId  ───▶ DeviceInstance   (shelf containment)   │
 │                                                                           │
 ├─1:N─▶ Net                                                                 │
 │        │ name, signalFamilyId, colorOverride, notes                       │
 │        └─◀1:N── Link.netId                                                │
 │                                                                           │
 ├─1:N─▶ Link                    ◀── one physical cable, one schedule row    │
 │        │ designator W###, netId, mediaId, lengthNm, status, test          │
 │        ├─1:N─▶ Conductor  { fromPortId, toPortId, role }                  │
 │        ├─0:N─▶ InlineAdapter                                              │
 │        └─0:N─▶ RouteWaypoint (schematic geometry, per Sheet)              │
 │                                                                           │
 ├─0:N─▶ SignalRoute             ◀── Dante / AVoIP / matrix crosspoint       │
 │        └─N:M─▶ Link, Net      (transportPath)                             │
 │                                                                           │
 ├─0:N─▶ Circuit                 (branch circuit / breaker)                  │
 │        └─◀N:1── Port.power.circuitId                                      │
 │                                                                           │
 ├─1:N─▶ Sheet                   (T0.01, T2.01, T6.02 …)                     │
 │        ├─ viewKind: elevation | schematic | schedule | cover | legend     │
 │        └─1:N─▶ SheetItem  (placement of entities on this sheet)           │
 │                                                                           │
 ├─0:N─▶ Note                    (annotation; anchored to any entity or free)│
 ├─0:N─▶ RevisionEntry           (drawing rev block: rev#, date, desc, by)   │
 ├─0:N─▶ Finding                 (DRC output; persisted only when acked)     │
 ├─1:1──▶ Registries  { signalFamilies, connectors, media, cableSpecs }      │
 └─1:1──▶ Tombstones  Map<Uuid, {deletedAt, entityType, by}>                 │
```

**Cardinality notes that matter:**

- `Port` is owned by `DeviceInstance` **and never shared**. A patch panel's front and rear jacks are two `Port`s bound by a `PassthroughPair`, not one port.
- `Link.Conductor` is 1:N, a 16/4 speaker cable is **one Link with four Conductors**, not four Links. One cable = one row on the pull sheet = one physical thing a human pulls.
- `Net` is **stored, not derived** (§3.5).
- `TemplateSnapshot` is referenced by `(templateId, version)` and is immutable; it can never be a sync conflict and never a dangling edit.

---

## 2. Dart class definitions

Package: `rackmate_core`, pure Dart, **no `package:flutter` import** (not even for `Offset`/`Color`).

### 2.0 Primitives & value types

```dart
/// Zero-cost typed IDs. Dart 3.3+ extension types — no wrapper allocation.
extension type const Uuid(String v)              { }
extension type const SignalFamilyId(String v)    { }  // "video.hdmi.2_1"
extension type const ConnectorTypeId(String v)   { }  // "conn.hdmi_a"
extension type const MediaTypeId(String v)       { }  // "media.cat6a_futp"
extension type const PortKey(String v)           { }  // "hdmi_out_3"  (template-stable)
extension type const TemplateId(String v)        { }
extension type const FracIndex(String v)         { }  // LexoRank "a0", "a0V", "a1"

/// Length. int64 NANOMETRES. See §3.7 — this is the load-bearing unit choice.
extension type const Len(int nm) {
  static Len mm(num v) => Len((v * 1e6).round());
  static Len inch(num v) => Len((v * 25400000).round());
  double get asMm => nm / 1e6;
  double get asInch => nm / 25400000;
  Len operator +(Len o) => Len(nm + o.nm);
}

/// Mass, integer micrograms → grams exact, lb exact (1 lb = 453592370 µg).
extension type const Mass(int ug) {
  static Mass kg(num v) => Mass((v * 1e9).round());
  static Mass lb(num v) => Mass((v * 453592370).round());
}

/// Schematic canvas coordinate. INTEGER grid units. 1 gu ≡ 2.54 mm nominal pitch.
/// Sub-grid precision via `Sub` (1/64 gu) for annotation nudging only.
final class Pt {
  final int gx, gy;                 // grid units
  final int sx, sy;                 // 1/64 gu sub-offsets, usually 0
  const Pt(this.gx, this.gy, {this.sx = 0, this.sy = 0});
}

final class Rgb { final int r, g, b, a; const Rgb(this.r, this.g, this.b, [this.a = 255]); }

/// Every entity carries this. It is the LWW tuple and the audit trail.
final class EntityMeta {
  DateTime createdAt;        // UTC, microsecond
  DateTime updatedAt;        // UTC, microsecond — bumped by every Command
  String   updatedBy;        // local install UUID now; user id later
  int      localRevision;    // per-entity monotonic counter
  Map<String, Object?> unknown = {};   // §4.4 forward-compat: preserve & re-emit
}

sealed class Extent { }                       // for "unknown/varies" fields
final class Known extends Extent { final Len v; Known(this.v); }
final class Unknown extends Extent { const Unknown(); }
```

### 2.1 Project, Settings, Revision

```dart
final class Project {
  final Uuid id;
  int schemaVersion;              // 1
  int minReaderVersion;           // 1  — see §4.3
  String appVersion;              // diagnostics only
  DateTime createdAt, modifiedAt;

  /// Monotonic; ++ on every committed Command. Dirty flag + sync cursor.
  int revision;

  // Job metadata (title block source of truth — AVIXA D401.01)
  String projectName, projectNumber;
  String clientName;
  Address siteAddress;
  String integratorName, integratorContact, integratorLicense;
  String drawnBy, checkedBy, approvedBy;

  ProjectSettings settings;

  // Flat entity maps. NEVER nested. See §5.1.
  Map<Uuid, Location>        locations   = {};
  Map<Uuid, Rack>            racks       = {};
  Map<Uuid, DeviceInstance>  devices     = {};
  Map<Uuid, Port>            ports       = {};   // deviceId on the port, not nesting
  Map<Uuid, PortGroup>       portGroups  = {};
  Map<Uuid, Net>             nets        = {};
  Map<Uuid, Link>            links       = {};
  Map<Uuid, SignalRoute>     routes      = {};
  Map<Uuid, Circuit>         circuits    = {};
  Map<Uuid, Sheet>           sheets      = {};
  Map<Uuid, Note>            notes       = {};
  Map<Uuid, StructureBundle> bundles     = {};
  Map<Uuid, StructureDrop>   drops       = {};
  Map<Uuid, AckedFinding>    ackedFindings = {};

  // Embedded, immutable, content-addressed. Key = "$templateId@$version".
  Map<String, TemplateSnapshot> templates = {};

  // Embedded subset of the registries this document actually uses. §3.4.
  Registries registries;

  List<RevisionEntry> revisionBlock = [];   // ordered, drawing-set rev block
  Map<Uuid, Tombstone> tombstones = {};     // §5.4
  EntityMeta meta;
}

final class ProjectSettings {
  // Display
  UnitSystem displayUnits;              // imperial | metric | mixed
  RuNumbering ruNumbering;              // bottomUpFromOne (default) | topDown
  bool defaultElevationFace;            // rear-first for wiring work
  bool greyscaleSafeExport;             // §3.4 colour degradation

  // Identifier format engine — TIA-606 declines to mandate a format. §3.9.
  IdFormat deviceDesignatorFormat;      // "{typePrefix}-{seq:2}"      → "MTX-01"
  IdFormat linkDesignatorFormat;        // "W{seq:3}"                  → "W042"
  IdFormat portDesignatorFormat;        // "J{devSeq:2}{portSeq:2}"    → "J2301"
  IdFormat dropFieldLabelFormat;        // "{type}-{room}-{dir}-{seq}" → "ET-LIV-W-1"
  IdFormat dropRackLabelFormat;         // "{floor}{space}-{panel}{port}" → "1A-A12"
  int      designatorBlockSize;         // 100 → matrix ports 2301..2316 reserve gaps

  // Colour: two INDEPENDENT dimensions (§3.4)
  Uuid signalColorSchemeId;             // Okabe-Ito default
  Uuid? terminationColorSchemeId;       // TIA-606-C class colours, optional

  // DRC
  Map<String, Severity> ruleSeverityOverrides;   // ruleId → error|warning|advisory|off
  bool blockExportOnErrors;             // default true

  // Defaults for new entities
  MediaTypeId defaultNetworkMedia;      // "media.cat6a_futp"
  int defaultRackHeightU;               // 12
  StructureGrade defaultBundleGrade;    // grade2  (TIA-570-D: 2×Cat6A + 2×RG6)
}

/// The DRAWING revision block (Rev # | Date | Description | By).
/// Distinct from Project.revision (the monotonic sync counter). Do not conflate.
final class RevisionEntry {
  final Uuid id;
  String label;                 // "A", "1", "2"
  DateTime date;
  String description;
  String by;
  bool issued;                  // issued-for-construction vs internal
  Uuid? frozenSnapshotId;       // optional immutable doc snapshot for as-built diff
  EntityMeta meta;
}
```

### 2.2 Location

```dart
final class Location {
  final Uuid id;
  Uuid? parentId;               // self-referential tree
  LocationKind kind;            // site | building | floor | room | zone | outdoor
  String name;                  // "Master Bedroom"
  String code;                  // "MBR"  — feeds the ID format engine
  int? floorNumber;             // 2
  String? spaceCode;            // "A"    — TIA-606 `fs` composition
  FracIndex order;              // sibling ordering, never an array index
  EntityMeta meta;
}
```

### 2.3 Rack

```dart
final class Rack {
  final Uuid id;
  String name;                  // "AV Rack — Basement"
  String designator;            // "RK-1"  — must match schedule Location column
  Uuid? locationId;

  int heightU;                  // INTEGER. The whole point. Never a float.
  RackWidthClass widthClass;    // eia19 | eia23 | tenInch | etsi | customWidth
  Len? customPanelWidth;

  RailType railType;            // tapped10_32 | tapped12_24 | squareCageNut
                                // | roundClearance | m6
  bool fullHoleRail;            // "universal" rail vs omitted holes

  RackFormFactor formFactor;    // floorEnclosure | openFrame4Post | openFrame2Post
                                // | wallSwingGate | wallPivotCabinet | wallFixed
                                // | credenzaFurniture | portableCase

  // Depth: usable vs overall are reported inconsistently by vendors. Store BOTH.
  Len usableDepth;
  Len? overallDepth;
  Len? overallWidth, overallHeight;   // for the "space required" note under the elevation

  Mass? weightCapacity;         // wall racks: 100 lb is the real binding constraint
  Mass? ownWeight;

  bool isSwingFrame;
  HingeSide? hingeSide;         // left | right — affects rear-access rendering

  bool hasFrontDoor, hasRearDoor;
  Len? frontDoorClearance, rearDoorClearance;

  // Vertical 0U channels available for PDUs / lace strips
  List<ZeroUChannel> zeroUChannels;   // {id, side, startU, endU, capacityMm}

  FracIndex order;              // rack ordering within the project
  EntityMeta meta;
}

final class ZeroUChannel {
  final String id;              // stable string key within the rack
  ZeroUSide side;               // rearLeft | rearRight | sideLeft | sideRight
  int startU, endU;
  Len? usableLength;
}
```

### 2.4 Placement: the `RackSlot` replacement

```dart
/// Sealed union. `switch` over it is exhaustive at compile time.
/// NOTE: elevation X/Y coordinates are NEVER stored — they are DERIVED from
/// this + rail geometry. See §3.7.
sealed class Placement { }

final class RailPlacement extends Placement {
  final Uuid rackId;
  final int  ruIndex;           // 1-based, BOTTOM origin, always — regardless of
                                // ProjectSettings.ruNumbering (that is display only)
  final Face face;              // front | rear   (which rails it's screwed to)
  /// Lateral span across the panel in TWELFTHS. Exact for half (6), third (4),
  /// quarter (3). Two half-rack devices sharing 1U = {0,6} and {6,6}.
  final int  startTwelfth;      // 0..11
  final int  spanTwelfths;      // 1..12
  final Len? depthOffsetFromFront;   // recessed mounting
}

final class ShelfPlacement extends Placement {
  final Uuid hostDeviceId;      // the shelf/drawer DeviceInstance
  final int  startTwelfth, spanTwelfths;   // lateral position on the shelf
  final Len? depthOffset;
}

final class ZeroUPlacement extends Placement {
  final Uuid rackId;
  final String channelId;       // Rack.zeroUChannels[].id
  final Len offsetFromChannelStart;
  final Orientation orientation;   // vertical | horizontal
}

final class OffRackPlacement extends Placement {
  final Uuid? locationId;       // "attic", "structured media can"
  final String? mountNote;      // "J-hook above ceiling tile, grid E7"
}

/// Structure devices, and anything staged but not yet placed.
final class UnplacedPlacement extends Placement {
  final Pt? schematicHint;      // where the user parked it on the schematic sheet
}
```

### 2.5 DeviceTemplate & TemplateSnapshot

```dart
/// The mutable library object. Lives in the user library / seeded catalog.
/// NEVER referenced directly by a DeviceInstance.
final class DeviceTemplate {
  final TemplateId templateId;
  int version;                  // monotonic; every edit forks a new version
  String contentHash;           // sha256 of canonical JSON of the snapshot body
  TemplateBody body;
  TemplateProvenance provenance;   // seeded | userAuthored | imported | derivedFrom
  TemplateId? derivedFrom; int? derivedFromVersion;
  EntityMeta meta;
}

/// Immutable, embedded in the .rackmate file. Cannot be edited in place.
final class TemplateSnapshot {
  final TemplateId templateId;
  final int version;
  final String contentHash;
  final TemplateBody body;      // deeply immutable
  final DateTime capturedAt;
}

/// Everything PHYSICALLY TRUE OF THE MODEL. Nothing project-specific.
final class TemplateBody {
  // Identity
  String manufacturer;          // "Generic" for seeded archetypes
  String model;                 // "8x8 HDMI Matrix"
  String displayName;
  String description;
  String category;              // "matrix.hdmi", "network.switch", "power.pdu"
  String? typePrefix;           // "MTX" — seeds the designator format engine
  List<String> tags;

  // ── Occupancy. A STRUCT, never a scalar heightU. Front and rear differ. ──
  int frontU;                   // 0 for 0U and rear-only items
  int rearU;                    // rear rail holes consumed (patch panel = same as front)
  OccupancySide side;           // front | rear | both | zeroUVertical | none
  MountMethod mountMethod;      // rackEars | shelf | zeroU | sideMount | rearRail
                                // | furniture | hosted | notInRack
  List<MountMethod> alternateMountMethods;   // half-rack unit + optional ear kit
  WidthClass widthClass;        // full | half | third | quarter | customWidth
  int nominalSpanTwelfths;      // 12 | 6 | 4 | 3
  Len? customPanelWidth;

  Len bodyDepth;                // chassis depth, connectors excluded
  Len? connectorProjection;     // add for HDMI/stiff coax bend radius
  Mass weight;

  // Clearance — the differentiating validation few tools implement
  int requiresClearanceAboveU;
  int requiresClearanceBelowU;
  ThermalClass thermalClass;    // passive | lowHeat | highHeat | activeCooled

  // ── Container semantics (shelves, drawers) ──
  bool isContainer;
  Mass? containerWeightCapacity;
  Len?  containerUsableDepth;
  Len?  containerUsableWidth;
  bool  containerVented;

  // ── Pass-through semantics (patch panels, feed-through/keystone) ──
  bool isPassthrough;
  List<PassthroughPairDef> passthroughPairs;   // frontKey ↔ rearKey, same net

  // ── Power ──
  PowerProfile power;

  // ── I/O ──
  List<PortDef>      ports;
  List<PortGroupDef> portGroups;

  // ── Presentation ──
  String? faceplateAssetRef;    // asset id in the zip container (v2)
  Rgb? accentColor;
  List<PanelGraphic> panelGraphics;   // vector rects/text for the elevation

  // Escape hatch for template-defined defaults an instance may override
  Map<String, Object?> defaults;
}

final class PowerProfile {
  int? nameplateWatts;          // breaker math uses this
  int? typicalWatts;            // heat math uses this (gear draws 30–70% of rated)
  int? standbyWatts;
  int? nominalVolts;
  bool isContinuousLoad;        // ≥3h ⇒ NEC 210.19(A)(1) 125% / 80% rule
  int outletsProvided;          // PDUs, conditioners, UPS
  int outletsConsumed;          // usually 1; amps with dual inlets = 2
  PlugType? inletPlug;          // C14 | C20 | NEMA_5_15P | hardwired | wallWart
  int? btuPerHourOverride;      // else derived: typicalWatts × 3.41214
}
```

### 2.6 PortDef & Port

```dart
/// The template-side port definition. `key` is the migration anchor. §3.3.
final class PortDef {
  /// STABLE, author-assigned, unique within template, NEVER reused for a
  /// different port, NEVER derived from index or label. This is the ONLY thing
  /// that makes connections survive a template revision.
  final PortKey key;
  /// Old keys this port absorbed, so an author can rename without breaking joins.
  final List<PortKey> renamedFrom;

  String label;                 // silkscreen: "HDMI OUT 3"
  String? designatorHint;       // "J14" seed; final designator computed per project

  // ── THREE ORTHOGONAL IDENTITY AXES. Never one enum. §3.4 ──
  ConnectorTypeId connector;              // "conn.rj45"
  SignalFamilyId  signalFamily;           // "net.ethernet"
  List<SignalFamilyId> carriedProtocols;  // ["net.ethernet","audio.dante"]
  List<SignalFamilyId> acceptedFamilies;  // what this port will legitimately take

  // Direction & topology
  PortDirection direction;      // source | sink | bidirectional | busNode | passive
  ReturnChannel? returnChannel; // ARC/eARC: opposite-direction signal, same port
  PortTopology topology;        // p2p | multidrop | star
  int maxConnections;           // 1 for p2p; N for splitters/bus nodes

  // Physical
  Gender gender;                // male | female | genderless | jack | plug
  Face face;                    // front | rear   — MANDATORY, not optional
  PanelPosition position;       // {ruOffset:int, xTwelfth:int, xFineNm:Len, yFineNm:Len}
  String? pinoutVariant;        // "xantech-stereo" | "mono-tip-sleeve"  (IR hazard)
  int? conductorCount;

  // Electrical
  int? impedanceOhms;           // 75 | 110 | 120 | 100 | 50
  AudioLevel? level;            // mic | lineUnbal | lineBal | phono | speaker
  bool? balanced;
  bool? phantomPowerCapable;
  Polarity? polarity;           // positive | negative | none   (speaker +/−)
  int? nominalVoltage;          // 25 | 70 | 100 for constant-voltage audio
  int? maxCurrentMa;            // 12 V trigger: 100 mA is the real limit

  // Grouping — component video, RGBHV, balanced pairs, speaker pairs
  String? groupKey;             // joins to PortGroupDef.key
  String? groupRole;            // "Y"|"Pb"|"Pr"|"L"|"R"|"+"|"−"|"H"|"V"
  int? channelIndex;

  // Network
  PoeSpec? poe;                 // {role: pse|pd|none, standard, type, class, watts}
  int? linkSpeedMbps;
  SfpFormFactor? sfp;
  FiberMode? fiberMode;
  int? wavelengthNm;

  // Bus membership capability
  BusCapability? bus;           // {protocol, supportsTermination, unitLoads,
                                //  addressable, maxTapWatts}

  // Serial
  SerialSpec? serial;           // {role: DTE|DCE, baud, dataBits, parity, stop, flow}

  // Power
  PortPowerSpec? power;         // {role: inlet|outlet, receptacle, volts, phase,
                                //  maxAmps, outletMode, sequenceStep, sequenceDelayMs,
                                //  backing: ups|surge|none, drawWatts}

  FracIndex order;              // display order on the panel; NOT identity
  String? notes;
}

/// The instance-side port. Owned by exactly one DeviceInstance.
/// Exists whether or not it is connected (reserve-ID / block-numbering support).
final class Port {
  final Uuid id;                // graph identity; Links reference THIS
  final Uuid deviceId;
  final PortKey? templatePortKey;   // null for instance-added and Structure ports

  /// Sparse. Only keys the user actually changed. Everything else reads through
  /// to the template PortDef. §3.2.
  Map<String, Object?> overrides;

  // Project-level state that has no template equivalent
  String? userLabel;            // overrides PortDef.label in this project
  String designator;            // "J2301" — computed, then frozen, then editable
  bool orphaned;                // template revision removed the matching PortDef
  bool reserved;                // populated later; keeps its ID out of allocation

  // Live configuration
  NetworkConfig? network;       // {hostname, ip, subnet, gw, mac, vlans[], portRole}
  int? busAddress;              // DMX start addr, DALI short addr, Cresnet ID
  int? busUniverse;
  bool? isBusTerminator;
  int? tapWatts;                // 70V/100V transformer tap — per INSTALLATION
  Uuid? circuitId;              // for power inlets
  PoeAssignment? poeActual;     // negotiated class ≤ port capability

  String? notes;
  EntityMeta meta;
}

final class PortGroupDef {
  final String key;             // stable within template
  String label;                 // "Component Video In 1"
  PortGroupKind kind;           // componentVideo | rgbhv | balancedPair
                                // | speakerPair | speakerQuad | stereoPair | custom
  List<PortKey> memberKeys;     // ordered by role
  bool atomicConnect;           // true ⇒ UI connects the whole group in one gesture
}

final class PortGroup {
  final Uuid id;
  final Uuid deviceId;
  final String? templateGroupKey;
  String label;
  PortGroupKind kind;
  List<Uuid> memberPortIds;
  bool atomicConnect;
  EntityMeta meta;
}

final class PassthroughPairDef {
  final PortKey frontKey, rearKey;
  final bool sameNet;           // true ⇒ netlist collapses; no spurious two-hop
}
```

### 2.7 DeviceInstance

```dart
final class DeviceInstance {
  final Uuid id;
  DeviceKind kind;              // rackDevice | shelf | structure | offRackPassive
                                // | virtual | blankPanel | ventPanel | pdu | ups

  /// Pinned to an exact immutable snapshot. Never a floating reference. §3.1.
  TemplateRef templateRef;      // {templateId, version, contentHash}
  bool templateUpdateAvailable; // cached; recomputed against the library on open

  // Project identity
  String designator;            // "MTX-01" — must be unique project-wide
  String name;                  // "Main HDMI Matrix"  (user-facing)
  DeviceStatus status;          // existing | new | future | removed
                                // `future` reserves RU without a BOM line

  Placement placement;
  Uuid? hostDeviceId;           // shelf containment; must be a container template
  Uuid? locationId;             // for offRack / structure devices

  // Instance-only real-world data
  String? serialNumber, assetTag, macAddressPrimary;
  String? firmwareVersion;
  DateTime? installedAt;
  Money? cost;                  // BOM
  String? supplier, purchaseOrder;

  /// Sparse instance overrides of TemplateBody fields. Keys are dotted paths:
  /// "weight", "power.nameplateWatts", "bodyDepth". Anything not present reads
  /// through to the snapshot. Overrides SURVIVE template migration. §3.2.
  Map<String, Object?> overrides;

  /// A per-instance forked template ("Edit this device only"). When non-null it
  /// wholly replaces templateRef's body. Marked derivedFrom for lineage.
  TemplateSnapshot? localTemplate;

  List<Uuid> portIds;           // ordered by FracIndex; convenience index
  Uuid? structureBodyId;        // iff kind == structure

  String? notes;
  Rgb? colorOverride;
  FracIndex zOrder;             // schematic stacking; never an array index
  EntityMeta meta;
}

final class TemplateRef {
  final TemplateId templateId;
  final int version;
  final String contentHash;     // integrity: detects a tampered/edited snapshot
}
```

### 2.8 Structure device

```dart
/// The body attached to a DeviceInstance with kind == structure.
/// Zero RU, zero weight, no rack position. Renders as an off-page connector bank.
/// Multiple instances are expected: "Rough-in — 1st floor", "Exterior/cameras".
final class StructureBody {
  final Uuid id;
  final Uuid deviceId;
  String title;                 // "Rough-In — First Floor"
  StructureRole role;           // homeRunField | serviceEntrance | interRackTie
                                // | temporaryFeed
  Uuid? distributionDeviceLocationId;   // the SMC / can / MDF location
  String? enclosureModel;       // "Leviton 42in SMC"
  List<Uuid> bundleIds;
  EntityMeta meta;
}

/// One OUTLET LOCATION. The atomic unit of creation, specification and pricing.
/// "Add outlet: Grade 2" creates one bundle containing 2×Cat6A + 2×RG6.
final class StructureBundle {
  final Uuid id;
  final Uuid structureBodyId;

  String outletDesignation;     // "LR-TV-1"   — the FIELD label
  Uuid? locationId;             // Room
  Wall? wall;                   // n | s | e | w | c | ne | nw | se | sw | ceiling | floor
  Len? mountHeightAff;          // above finished floor
  int? floorNumber;

  StructureGrade grade;         // grade1 | grade2 | grade3 | custom  (TIA-570-D)
  String? conduitId, pathwayId;
  Len? nominalRunLength;        // shared estimate; per-drop can override

  List<Uuid> dropIds;
  RoughInStatus bundleStatus;   // derived-max of member drop statuses
  String? notes;
  FracIndex order;
  EntityMeta meta;
}

/// One PHYSICAL HOME RUN. The unit of pulling, testing and scheduling.
/// 1:1 with a generated Port on the structure device.
final class StructureDrop {
  final Uuid id;
  final Uuid bundleId;
  final Uuid portId;            // the auto-generated Port on the structure device

  // TWO IDs. This is where jobs go wrong — print both. §3.9.
  String fieldLabel;            // "LR-TV-1A"   — what's on the wall plate
  String? rackLabel;            // "1A-A12"     — TIA-606 fs-an at the panel

  MediaTypeId media;            // "media.cat6a_futp" | "media.rg6_quad" | "media.14_2"
  int conductorCount;
  int? gaugeAwg;
  JacketRating? jacket;         // cl3 | cmr | cmp | lszh | direct_burial

  /// MAY BE UNDETERMINED AT ROUGH-IN. This is the interesting case: a Cat6 run
  /// may end up Ethernet, HDBaseT, or nothing. The Link assigns it; the DRC
  /// then validates retroactively.
  SignalFamilyId signalFamily;  // may be "signal.undetermined"

  TerminationType terminationRack;   // keystone | punchdown | fBarrel | euroblock
                                     // | unterminated | fieldConnector
  TerminationType terminationField;
  Uuid? terminatesAtPortId;     // patch panel / splitter port inside the rack
                                // (also expressible as a normal Link — see §3.6)

  Len? actualLength;
  Extent? calculatedLength;
  String? reelId;

  RoughInStatus status;         // planned | pulled | dressed | terminated
                                // | tested | issued
  TestResult? test;             // {pass, headroomDb, lossDb, certId, testedBy, at}

  Polarity? polarity;           // speaker runs
  String? notes;
  FracIndex order;
  EntityMeta meta;
}
```

### 2.9 Net, Link, SignalRoute: the wiring model

```dart
/// The LOGICAL equivalence class. One net = one bus trunk on the schematic,
/// one colour, one name. STORED, not derived. §3.5.
final class Net {
  final Uuid id;
  String name;                  // "LR-TV HDBaseT", "IR Bus — Head End"
  String? designator;           // "N012"
  SignalFamilyId signalFamily;
  NetTopologyKind topology;     // pointToPoint | starSwitched | multidropBus
                                // | passiveSplit | daisyChain
  Rgb? colorOverride;
  bool isImplicit;              // auto-created singleton for a lone P2P link
  Uuid? busTerminatorPortIdA, busTerminatorPortIdB;   // RS-485/DMX 120Ω ends
  int? busUniverse;             // DMX
  int? nominalVoltage;          // 70/100 V speaker line
  String? notes;
  EntityMeta meta;
}

/// ONE PHYSICAL CABLE. One row on the pull sheet. One `W###` designator.
/// EXACTLY two device ends. A 16/4 speaker cable is ONE Link with FOUR conductors.
final class Link {
  final Uuid id;
  String designator;            // "W042"
  Uuid netId;                   // never null; implicit singleton net if unassigned

  /// 1..N. Usually 1. Component video = 3, RGBHV = 5, 16/4 speaker = 4.
  List<Conductor> conductors;

  // Cable spec
  MediaTypeId media;
  String? cableSpecId;          // registry: manufacturer + part number
  int? gaugeAwg;
  JacketRating? jacket;
  bool shielded;
  bool plenum;

  // Physical
  Len? calculatedLength;        // from geometry / user estimate
  Len? cutLength;               // as-pulled, incl. service loop. Distinct field.
  int? slackPercent;            // industrial convention adds ~10%
  String? pathwayId, conduitId, route;

  // Semantics that only exist at the cable level
  CrossoverKind? crossover;     // straight | nullModem | fiberPolarityAB
  List<InlineAdapter> inlineAdapters;   // baluns, RCA→XLR, IR over Cat5 kits

  // Field lifecycle — this is what turns the design PDF into the as-built PDF
  RoughInStatus status;
  TestResult? test;
  String? installedBy;
  DateTime? terminatedAt;

  // Drawing
  Map<Uuid, List<Pt>> waypointsBySheet;   // manual orthogonal routing per sheet
  bool autoRoute;

  String? notes;
  FracIndex order;
  EntityMeta meta;
}

final class Conductor {
  final String role;            // "" | "Y" | "Pb" | "Pr" | "L+" | "L−" | "R+" | "R−"
  final Uuid fromPortId;
  final Uuid toPortId;
  final int? pairNumber;
  final String? colorCode;      // "blue/white"
}

final class InlineAdapter {
  final Uuid id;
  final String label;           // "HDMI→Cat6 balun pair"
  ConnectorTypeId fromConnector, toConnector;
  SignalFamilyId? convertsTo;
  String? model;
  bool poweredExternally;
  /// Declaring an adapter SATISFIES the connector-mismatch rule rather than
  /// requiring the user to acknowledge a finding. §3.4.
  List<String> satisfiesRuleIds;
}

/// Transport-independent logical flow. Dante channels, AVoIP streams, matrix
/// crosspoints, eARC return. Rides Links/Nets; may have NO dedicated cable.
final class SignalRoute {
  final Uuid id;
  String label;                 // "Dante — Zone 3 L/R"
  SignalFamilyId signalFamily;
  Uuid sourcePortId, sinkPortId;
  int channelCount;
  List<Uuid> transportLinkIds;  // the physical hops it actually rides
  List<Uuid> transportNetIds;
  int? vlan;
  String? multicastGroup;
  int? latencyUs;
  int? bandwidthMbps;
  bool isDerived;               // computed from a matrix crosspoint config
  EntityMeta meta;
}

final class Circuit {
  final Uuid id;
  String designator;            // "Panel A / Breaker 14"
  int breakerAmps;              // 15 | 20 | 30
  int volts;                    // 120 | 208 | 240
  int? phase;
  bool dedicated;
  Uuid? locationId;
  /// Continuous-load derate: 15A→12A, 20A→16A (NEC 210.19(A)(1), 80% rule).
  int get continuousLimitAmps => (breakerAmps * 4) ~/ 5;
  EntityMeta meta;
}
```

### 2.10 Registries: `CableType` / `SignalType` replacement

```dart
/// Embedded in the document: the SUBSET actually referenced, at the version used.
/// Same reasoning as TemplateSnapshot — the file must be self-describing in 2031.
final class Registries {
  String builtinCatalogVersion;
  Map<SignalFamilyId, SignalFamilyDef> signalFamilies;
  Map<ConnectorTypeId, ConnectorTypeDef> connectors;
  Map<MediaTypeId, MediaTypeDef> media;
  Map<String, CableSpecDef> cableSpecs;
  Map<String, ColorScheme> colorSchemes;
  List<CompatibilityRuleDef> rules;   // DATA, not code. §3.4.
}

final class SignalFamilyDef {
  final SignalFamilyId id;      // "video.hdmi.2_1"
  String displayName;           // "HDMI 2.1 (48 Gbps)"
  String shortTag;              // "HD" — printed on the run pill
  SignalDomain domain;          // digitalVideo | analogVideoRf | analogAudio
                                // | digitalAudio | network | control | power
                                // | structureUndetermined
  SignalFamilyId? basedOn;      // custom entries inherit the parent's rules
  bool custom;

  PortDirection defaultDirection;
  PortTopology defaultTopology;
  List<ConnectorTypeId> typicalConnectors;
  List<MediaTypeId> typicalMedia;
  List<SignalFamilyId> compatibleWith;      // silent
  List<SignalFamilyId> adaptableTo;         // advisory + adapter suggestion

  int? maxRunLengthPassive;     // in Len.nm; HDMI 2.1 ≈ 4.5 m
  int? maxRunLengthActive;
  int? nominalImpedanceOhms;
  int? maxUnitLoads;            // RS-485/DMX: 32
  int? maxDevicesPerSegment;    // DALI: 64
  bool requiresTermination;
  bool carriesPower;

  Rgb color;                    // domain colour (Okabe-Ito)
  List<int> dashPattern;        // [6,3] — survives greyscale AND CVD
  int lineWeightPermille;       // 1000 = 1×; power 2000; control 750
  String? glyph;                // "▲" | "●" | "■" — fourth encoding channel
}

final class ConnectorTypeDef {
  final ConnectorTypeId id;     // "conn.rj45"
  String displayName;
  ConnectorFamily family;
  List<Gender> validGenders;
  int? contactCount;
  int? nominalImpedanceOhms;
  List<ConnectorTypeId> matesWith;    // gender-aware mating table
  bool keyed;
  String? symbolRef;            // J-STD-710 symbol
}

final class MediaTypeDef {
  final MediaTypeId id;         // "media.cat6a_futp"
  String displayName, shortTag;
  int? conductorCount, pairCount, gaugeAwg;
  int? impedanceOhms;
  bool shielded;
  List<JacketRating> availableJackets;
  int? maxChannelLength;        // Len.nm — Ethernet: 100 m
  Len? minBendRadius;
  Len? outerDiameter;           // conduit fill later
  List<SignalFamilyId> supports;
}

/// Compatibility rules live as DATA so a new adapter case does not need a release.
final class CompatibilityRuleDef {
  final String ruleId;          // "DIR-001", "SIG-014"
  RuleScope scope;              // link | net | device | rack | circuit | project
  Severity defaultSeverity;     // error | warning | advisory
  bool blocksCreation;          // TRUE for only 5 rules. §3.4.
  String message, rationale;
  String? remedyHint;
  RulePredicate predicate;      // declarative AST, JSON-serializable
  bool userAcknowledgeable;
}
```

### 2.11 Sheet, Note, Finding, Tombstone

```dart
final class Sheet {
  final Uuid id;
  String number;                // "T2.01"  — NCS [Discipline][Type][Seq]
  String title;                 // "Rack Elevations — Front"
  SheetKind kind;               // cover | legend | elevationFront | elevationRear
                                // | schematic | wiringSchedule | dropSchedule
                                // | bom | networkSchedule | powerSchedule | pullSheet
  PaperSize paper;              // ansiA..ansiE | a4..a1
  Orientation orientation;
  int scaleNumerator, scaleDenominator;   // integers; 0/0 ⇒ NTS
  bool carriesLegend;
  String? legendLocationNote;   // J-STD-710: sheets without a legend MUST say where
  List<Uuid> includedRackIds;
  List<Uuid> includedDeviceIds; // empty ⇒ all
  Set<SignalDomain> domainFilter;   // "control signal flow only" export
  DetailLevel detailLevel;      // systemLevel | detailed
  Map<Uuid, SheetItem> items;   // per-sheet placement of devices/notes/nets
  FracIndex order;
  EntityMeta meta;
}

final class SheetItem {
  final Uuid id;
  final Uuid targetId;          // device | note | net | structureBody
  Pt position;                  // INTEGER schematic grid units
  int rotationQuarterTurns;     // 0..3 — no float angles
  bool collapsed;               // block-level vs port-stub detail
  FracIndex zOrder;
}

final class Note {
  final Uuid id;
  NoteKind kind;                // freeText | callout | dimension | revisionCloud
                                // | generalNote | warning
  String text;
  Uuid? anchorEntityId;         // any entity, or null for free-floating
  Uuid? sheetId;                // null ⇒ appears on every sheet showing the anchor
  Pt? position;
  Pt? leaderTarget;
  CalloutShape? shape;          // circle ⇒ home-run, square ⇒ local (J-STD-710)
  String? revisionLabel;
  Rgb? color;
  EntityMeta meta;
}

/// Findings are COMPUTED, not stored. Only ACKNOWLEDGEMENTS persist.
final class AckedFinding {
  final Uuid id;
  final String ruleId;
  final String targetFingerprint;   // stable hash of the rule's subject
  final Uuid? targetEntityId;
  String reason;                // "Balun pair, Extron DTP. Verified on site."
  String by;
  DateTime at;
  Severity demotedTo;           // advisory | off
  EntityMeta meta;
}

final class Tombstone {
  final Uuid id;
  final String entityType;
  final DateTime deletedAt;
  final String deletedBy;
  final String? summary;        // "MTX-01 (8x8 HDMI Matrix)" for the history panel
}
```

---

## 3. Critical modelling decisions, argued

### 3.1 Template vs instance: embedded immutable snapshots, opt-in migration

**What lives where.**

| Template (`TemplateBody`) | Instance (`DeviceInstance`) |
|---|---|
| RU occupancy (front/rear/side), width class, mount methods | Placement (rack, RU, face, twelfths) |
| Depth, weight, clearance requirements, thermal class | Serial, asset tag, MAC, firmware, install date, cost |
| Power profile (nameplate/typical/standby, outlets provided/consumed) | Circuit assignment, actual PoE negotiation, outlet assignment |
| Complete `PortDef` list: connector, signal, direction, side, panel position, gender, capability metadata | `Port` overrides, designators, IP/hostname/VLAN, bus address, DMX universe, 70 V tap, terminator flag |
| Manufacturer, model, category, type prefix, faceplate art | Designator, name, status (existing/new/future), notes, colour |
| Container capacity (shelves), passthrough pairs | Container membership (`hostDeviceId`) |

The dividing line: **if two identical units in two different projects would disagree about it, it belongs on the instance.** A 70 V transformer tap is per-installation → instance. Panel width is per-model → template.

**Propagation.** `DeviceInstance.templateRef` pins `(templateId, version, contentHash)` to an **immutable `TemplateSnapshot` embedded in the project file**. Template edits do **not** propagate. Instead, on open, RackMate compares each snapshot version to the library and sets `templateUpdateAvailable`. The user sees *"3 devices use an outdated version of 8×8 HDMI Matrix, Review update."* Applying it is a single undoable `MigrateTemplateCommand` producing a diff report.

**Rejected: live reference to a mutable library template.** This is what most tools do and it is wrong for a deliverable-producing app. Consequences: (a) the project file is not self-contained, opening it on the installer's laptop, whose library differs, silently changes the drawing; (b) a template edit can delete a port that has three connections, mid-project, with no undo scope; (c) an issued-for-construction PDF stops being reproducible from its own file. Deliverable integrity beats convenience.

**Rejected: copy-on-place with no linkage.** You lose the ability to fix a wrong port count across 12 instances, and you lose the "update available" affordance that makes a library worth having.

**When the user edits a template a placed device uses,** the UI presents exactly two doors:

1. **Edit template** → forks `version+1` in the library. Placed instances are untouched until the user opts in. Then the migration command runs (§3.3).
2. **Edit this device only** → materializes `DeviceInstance.localTemplate`, a per-instance fork tagged `derivedFrom: (templateId, version)`. The device leaves the update stream and is badged as customized. Offer "Promote to library template" as a follow-up.

There is no third door. Silent in-place mutation of an embedded snapshot is forbidden by the `contentHash` invariant (I-14).

### 3.2 Overrides are sparse dotted-path maps, not a parallel object

`DeviceInstance.overrides` is `Map<String, Object?>` keyed by dotted path into `TemplateBody` (`"weight"`, `"power.nameplateWatts"`, `"bodyDepth"`). Resolution is `overrides[path] ?? snapshot.body.get(path)`.

**Why sparse.** An override map that survives template migration must be able to say "the user changed *only* the weight." A parallel `DeviceOverrides` class with 40 nullable fields expresses the same thing but must be edited in lockstep with `TemplateBody` forever, and it silently breaks when a template gains a field. Sparse maps are also exactly what round-trips through the unknown-field preservation mechanism (§4.4).

**Cost, stated honestly:** you lose compile-time type safety on override paths. Mitigate with a generated-at-hand `TemplateBody.pathType(String)` table used by both the property inspector and the JSON codec, plus a validation pass (I-16) that rejects unknown paths on load with a warning rather than a crash.

### 3.3 Port identity across template revisions

Three-level identity, and it matters that they are three:

| Level | Field | Scope | Purpose |
|---|---|---|---|
| Graph identity | `Port.id` (UUID v7) | project | what `Link.Conductor` references |
| Template identity | `PortDef.key` / `Port.templatePortKey` | template | the migration join key |
| Human identity | `Port.designator` (`J2301`), `Port.userLabel` | drawing | what is printed and labelled |

**Connections reference `Port.id`, never `(deviceId, portKey)`.** Structure ports and instance-added ports have no template key at all; a uniform reference type is required.

**Migration algorithm** (`MigrateTemplateCommand`, fully undoable):

```
1. old = snapshot[v_from].ports keyed by PortKey
   new = snapshot[v_to].ports keyed by PortKey
2. Expand new: for each PortDef p, index p.key AND every k in p.renamedFrom.
3. MATCHED  (old.key resolves in new):
     update the instance Port's read-through attributes;
     if templatePortKey was an alias, rewrite it to the canonical new key;
     re-run DRC on every Link touching this port.
4. ADDED    (new.key ∉ old): create a Port, reserved = false, allocate designator
     from the reserve block if one exists.
5. REMOVED  (old.key ∉ new):
     if the Port has no Conductors → delete (tombstone).
     else → set orphaned = true. DO NOT DELETE. DO NOT DELETE THE LINK.
     Emit finding MIG-001 (warning): "Port 'HDMI OUT 8' no longer exists on
     template v3 but carries link W042."
6. Present the diff BEFORE committing. One transaction, one undo entry.
```

**Rejected: index identity (`ports[3]`).** The canonical failure. Inserting a port at position 2 reassigns every downstream connection.

**Rejected: label identity (`"HDMI OUT 3"`).** Labels are user-facing, get corrected for typos, and get localized. A rename must not be a rewire.

**Rejected: deleting orphaned ports and their links.** Data loss on a routine operation. Orphaning is recoverable; deletion is not. The orphan badge is also *useful information*, it tells the user exactly what the template change cost them.

### 3.4 The port type system: data-driven registry, embedded, user-extensible

**Decision:** `SignalFamily`, `ConnectorType` and `MediaType` are **three independent string-keyed registries**, seeded with a built-in catalog, extensible by the user, and **embedded (the used subset) in every project file**. Compatibility rules are **registry data**, not Dart code.

**Why not an enum.** Dart enums give exhaustive `switch` and compile-time safety, which is genuinely valuable, and it is the wrong trade here for three reasons:

1. **Growth rate.** The taxonomy has 43+ families today and gains entries with every new transport (SDVoE, HDMI 2.2, DP80, PoE Type 5). Each addition would be an app release.
2. **Forward compatibility is impossible.** A v1.0 app reading a v1.4 file that references `video.hdmi.2_2` must either crash, silently coerce, or drop the value. An enum cannot round-trip an unknown member. A registry can (I-24).
3. **Rules would live in code.** The most valuable feature in the whole app, "HDBaseT patched into a switch", is a *rule*, and rules that live in code can't be shipped as a catalog update, can't be authored by a user for a proprietary Cresnet variant, and can't be inspected by the user to understand why the app is complaining.

**Why not free-text user-extensible.** No colour mapping, no rules, no legend, no DRC. Garbage in.

**The registry design specifically:**

- IDs are reverse-hierarchical strings: `"video.hdmi.2_1"`, `"net.ethernet"`, `"ctl.rs232"`. Hierarchical prefixes give cheap domain grouping and cheap prefix-matching in rules.
- `extension type SignalFamilyId(String)` gives type safety at the call site with zero allocation; you cannot pass a `ConnectorTypeId` where a `SignalFamilyId` is expected, and there is no wrapper object at runtime.
- Custom entries carry `custom: true` + `basedOn`. A user's `"ctl.cresnet.hp"` inherits every rule from `"ctl.cresnet"` unless it overrides one.
- **Embedding the used subset in the file** is the same argument as template snapshots: the file must render identically in 2031 on an app whose built-in catalog has moved on. On open, the app reconciles: identical id + identical hash → use built-in; id present but hash differs → use the *embedded* one and badge it "this project pins an older definition of Cat6a".

**The three axes are orthogonal and must never collapse into one field.** This is the highest-value structural decision in the port model:

```
connector:        conn.rj45          ← what physically mates
signalFamily:     video.hdbaset      ← what electrically flows
carriedProtocols: [video.hdbaset, ctl.rs232, ctl.ir, net.ethernet_100]
media (on Link):  media.cat6a_futp   ← what you actually pull
```

An RJ45 jack is an RJ45 jack whether it carries Ethernet, HDBaseT, Dante, DMX-over-Cat, or Cresnet. Collapsing these makes the single most damaging real-world error (patching HDBaseT into a switch, which delivers PoH into a switch port) *undetectable*.

**Colour is on the `SignalDomain` (7 values), not the family (43+).** No palette is CVD-safe past ~9 categories. Colour carries domain; **dash pattern, line weight, glyph and text tag** carry the specific type. Okabe-Ito hues mapped near trade convention (blue video / warm audio / green network / purple control / black power). Two collision pairs exist in greyscale luminance (sky blue 0.401 vs orange 0.416), which is *why* dash + tag are mandatory, not decorative. Ship `greyscaleSafeExport` that drops hue entirely; it will be the setting most installers actually use. And keep TIA-606 termination-class colour as a **second, independently assignable dimension**: it conflicts with signal colour and both belong in the legend.

### 3.5 Connection validity: never block the pen

**Three tiers, but not the obvious three.** The naive design is `hard-illegal / warn / allow-with-note` as three static rule outcomes. I reject that shape.

The problem: which tier a rule belongs to is **not a property of the rule**, it's a property of the situation. "HDBaseT into a switch port" is a catastrophic error in a new design and *a correct depiction of an existing system you were called in to fix*. A model that cannot draw a mistake cannot document reality, cannot plan a remediation, and cannot import an as-found survey.

**The shape I use instead:**

```
Rule  →  emits Finding{ruleId, severity, subject, message}
User  →  may Acknowledge a Finding with a written reason
      →  the finding demotes to `advisory` or `off`, and the reason PRINTS in the schedule
Link  →  may declare an InlineAdapter, which SATISFIES a rule outright (no ack needed)
```

So the three tiers are: **error** (red, listed in DRC, **blocks export sign-off** if `blockExportOnErrors`), **warning** (yellow, listed), **advisory** (informational). And a fourth state, **acknowledged**, that only a human can produce, and that produces a printed audit line: *"W042, HDBaseT on Cat6 patched via SW-1 port 12. Reason: existing condition, to be corrected in Phase 2., R. Riley, 2026-07-18."*

**Only five rules block creation** (`blocksCreation: true`). These are rules whose violation makes the *model itself* incoherent, not rules about the physical world:

| ruleId | Rule |
|---|---|
| `TOP-001` | A conductor may not connect a port to itself |
| `TOP-002` | Two conductors may not duplicate the same ordered port pair on the same link |
| `TOP-003` | A port's live conductor count may not exceed `maxConnections` |
| `TOP-004` | A link's endpoints must resolve to existing, non-tombstoned ports |
| `TOP-005` | A shelf-hosted device's `hostDeviceId` must be a container and must not create a cycle |

Everything else is drawable.

**The rule catalogue.** Grouped, with default severities.

*Direction & topology*
- `DIR-001` **error**: source→source or sink→sink. Exception: both ports declare `returnChannel` (eARC), or the net is `passiveSplit`.
- `DIR-002` **warning**: bidirectional port connected to a `busNode` outside a declared bus net.
- `DIR-003` **error**: IR emitter output plugged into an IR *receiver* jack. Damages hardware; the `pinoutVariant` field exists solely to make this detectable.
- `DIR-004` **warning**: contact-closure *sense* input wired to another sense input (no drive).

*Connector*
- `CON-001` **error**: connector types do not mate, no `InlineAdapter` declared. Satisfied by declaring one.
- `CON-002` **warning**: genders both male or both female on a gendered family (XLR, DE-9, IEC).
- `CON-003` **advisory**: connector mates but is atypical for the signal family (BNC carrying analog audio).

*Signal*
- `SIG-001` **error**: **HDBaseT port connected to an `net.ethernet` switch port.** The flagship rule. PoH into a switch port.
- `SIG-002` **error**: sink's `acceptedFamilies` excludes the link's `signalFamily`, no adapter declared.
- `SIG-003` **warning**: non-Ethernet-over-Cat (DMX-over-Cat, Cresnet-over-Cat, analog balun, RS-485-on-RJ45) terminating on a switch.
- `SIG-004` **advisory**: Structure drop still `signal.undetermined` after a link assigns it a family → auto-offer to promote the drop's family. Retroactive validation then runs.
- `SIG-005` **warning**: TOSLINK carrying a family flagged `requiresHighBandwidth` (no lossless multichannel over optical S/PDIF).

*Electrical*
- `ELE-001` **warning**: impedance mismatch (S/PDIF into 50 Ω BNC; AES3 on 110 Ω vs mic cable; 75 Ω video on a 50 Ω path).
- `ELE-002` **warning**: unbalanced source → balanced sink or vice versa without a declared adapter/DI.
- `ELE-003` **error**: speaker polarity inverted between the two ends of a conductor pair (`+`→`−`).
- `ELE-004` **error**: parallel low-Z speakers drop the amplifier's load below its rated minimum impedance.
- `ELE-005` **warning**: Σ of 70 V/100 V `tapWatts` on a net > 80% of the amp channel rating.
- `ELE-006` **error**: constant-voltage speaker on a low-Z amp output, or vice versa.
- `ELE-007` **error**: satellite splitter net with no DC-passing port toward the LNB.
- `ELE-008` **warning**: RF cascade insertion loss exceeds the budget from source to the worst drop.

*Length*
- `LEN-001` **error**: Ethernet channel > 100 m (90 m horizontal + 10 m patch).
- `LEN-002` **warning**: passive HDMI 2.1 run > 4.5 m at 48 Gbps.
- `LEN-003` **warning**: 12G-SDI coax > 45 m; 6G > 80 m; 3G > 100 m.
- `LEN-004` **warning**: unbalanced line-level run > 6 m.
- `LEN-005` **warning**: RS-232 > 15 m at the declared baud.
- `LEN-006` **warning**: media's `maxChannelLength` exceeded for the assigned family.

*Bus*
- `BUS-001` **warning**: RS-485/DMX segment > 32 unit loads.
- `BUS-002` **warning**: bus net missing a 120 Ω terminator at one or both ends.
- `BUS-003` **error**: DMX universe > 512 channels allocated.
- `BUS-004` **error**: DALI line > 64 devices, or > 300 m.
- `BUS-005` **warning**: Cresnet run exceeds *either* the 3000 ft data limit *or* the 24 V power-drop limit (18 AWG @ 20 W ⇒ 333 ft). Two independent limits, two findings.
- `BUS-006` **warning**: RS-485 wired as a star rather than a daisy chain. Suppressed for `ctl.lutron_qs` and `ctl.dali`, which are topology-free.
- `BUS-007` **error**: duplicate bus address within a segment.

*Serial*
- `SER-001` **warning**: DTE↔DTE or DCE↔DCE without `crossover: nullModem`.
- `SER-002` **advisory**: baud/parity/stop mismatch between the two ports.

*Network*
- `NET-001` **error**: Σ PD class draw on a switch > the switch's PoE budget.
- `NET-002` **warning**: Type-4 PD on a Type-2 PSE.
- `NET-003` **error**: Dante/AES67 endpoints with no network path between them.
- `NET-004` **error**: AVB endpoints traversing a non-AVB/TSN switch.
- `NET-005` **warning**: Dante and AVoIP sharing a VLAN with no QoS declared.
- `NET-006` **advisory**: duplicate IP address in the project.
- `NET-007` **warning**: fiber pair without declared A/B polarity.

*Power*
- `PWR-001` **error**: Σ continuous nameplate amps on a circuit > 80% of breaker (12 A / 15 A; 16 A / 20 A).
- `PWR-002` **warning**: Σ outlet draw > PDU rating.
- `PWR-003` **error**: outlets consumed > outlets provided in the rack.
- `PWR-004` **warning**: 12 V trigger fan-out > 100 mA.
- `PWR-005` **warning**: UPS-backed load exceeds UPS capacity.

*Rack (not link rules, but same engine)*
- `RCK-001` **error**: RU overlap on the same face.
- `RCK-002` **error**: device extends past `heightU`.
- `RCK-003` **error**: Σ device weight > `Rack.weightCapacity`. Wall racks at 100 lb hit this constantly.
- `RCK-004` **warning**: centre of gravity above 50% of rack height ("top-heavy").
- `RCK-005` **warning**: `bodyDepth + connectorProjection` > `usableDepth − 50 mm`.
- `RCK-006` **warning**: `requiresClearanceAboveU`/`BelowU` violated by an adjacent device.
- `RCK-007` **advisory**: two high-heat devices adjacent with no vent/blank between.
- `RCK-008` **advisory**: < 15% spare front RU.
- `RCK-009` **error**: Σ hosted-device weight > shelf capacity.
- `RCK-010` **error**: hosted device depth > shelf usable depth.
- `RCK-011` **error**: lateral twelfths overlap within one RU.

**The real-world "wrong is right" cases, and how each resolves without an escape hatch:**

| Case | Resolution |
|---|---|
| HDBaseT over Cat6 | Not an error at all. `Link.signalFamily = video.hdbaset`, `media = media.cat6a_futp`. `SIG-001` only fires when the *other end is a switch port*. |
| RCA source → XLR input | Declare `InlineAdapter{fromConnector: conn.rca, toConnector: conn.xlr3, model: "RDL STD-TA1"}`. `CON-001` and `ELE-002` are both satisfied by data, not by acknowledgement. |
| IR over Cat5 | A `MediaTypeDef` for `media.cat5e` lists `ctl.ir` in `supports`. No finding. |
| Unbalanced → balanced, short run, no DI | `ELE-002` warning → user acknowledges: *"3 ft, same rack, same circuit."* Reason prints. |
| Analog audio on a spare Cat6 pair | `SIG-003` warning, acknowledged with the balun model, or an adapter declared. |
| Existing miswired system being documented | Every finding acknowledged with reason *"existing condition"*. The DRC list becomes the remediation scope, a deliverable in itself. |

### 3.6 One-to-many: `Link` is a point-to-point edge; `Net` is the hypergraph above it

**Decision: two layers, both stored.**

- **`Link`**: exactly two device ends. One physical cable. One `W###`. One row on the pull sheet. One length, one jacket rating, one test result. **1..N `Conductor`s inside it.**
- **`Net`**: a stored, named, N-endpoint equivalence class over links. One colour, one bus trunk, one name on the schematic.

**Rejected: pure edge list.** Cannot express "these six drops are one RF cascade" or "these four speakers share one 70 V line". You get six disconnected edges with no shared identity, no shared loss budget, and no way to draw a bus trunk. Every one of the bus rules (`BUS-*`, `ELE-005`, `ELE-008`) is unimplementable.

**Rejected: pure hypergraph (a `Connection` with N endpoints).** Destroys the pull sheet. A net with six endpoints does not tell an installer what to pull: how many cables, of what length, terminated how. The cable schedule is the primary deliverable; it needs a two-ended row.

**Rejected: derived-only nets (union-find over links at read time).** Tempting and wrong. A derived structure cannot carry the user's net name, colour override, notes, universe number, or terminator assignment, and cannot be a sync conflict unit. It also makes labels flicker: connect a link, and every net downstream renumbers. Nets are stored; the union-find is used only to *propose* merges, which the commands then apply explicitly and undoably.

**How each hard case lands:**

| Reality | Model |
|---|---|
| 16/4 speaker cable, one run, stereo pair to one location | **1 Link, 4 Conductors** (`L+`,`L−`,`R+`,`R−`). One row, one length, one pull. |
| Component video (3× RCA sold as one cable) | **1 Link, 3 Conductors** (`Y`,`Pb`,`Pr`). Endpoints resolve through `PortGroup`s, so the UI connects all three in one gesture. |
| RG6 splitter feeding 4 drops | Splitter is a real `DeviceInstance` (`kind: offRackPassive`, `frontU: 0`, `mountMethod: notInRack`) with 1 input + 4 output ports. **5 Links, 1 Net.** Loss budget walks the net through the splitter's declared insertion loss. |
| IR bus, connecting block, 6 emitters | Block is a device with 1 input + 6 outputs. **7 Links.** Net optional, usually 1 net so the schematic draws a trunk. |
| Network switch port = shared segment | It is *not* a shared segment at the physical layer. Each device→switch run is **1 Link, 1 Net (implicit)**. The shared-ness is `SignalRoute`, a Dante flow from A to B lists `transportLinkIds: [A→SW, SW→B]`. This is why `SignalRoute` exists as a third entity. |
| 70 V speaker line, 6 speakers daisy-chained | **6 Links, 1 Net** (`topology: daisyChain`, `nominalVoltage: 70`). Each speaker's input `Port.tapWatts` is per-installation. `ELE-005` sums the net. |
| Patch panel front↔rear | `PassthroughPairDef` with `sameNet: true`. The netlist collapses the two-hop into one logical connection while both physical links remain schedulable. |
| eARC | One Link. The display's HDMI port declares `returnChannel`. `DIR-001` is suppressed; a `SignalRoute` in the opposite direction carries the audio. |
| Matrix crosspoint (which input reaches which output) | `SignalRoute` with `isDerived: true`, computed from the matrix's configuration. Zero physical cables involved. |

`Net` is auto-created as an implicit singleton for every new link (`isImplicit: true`, no name). It becomes explicit, and gains a name and a `N###` designator, the moment a second link joins it or the user names it. This keeps the common case free of ceremony.

### 3.7 Units and precision: no floats, anywhere, ever

**Rack geometry.** Height and position are **integer RU**. Never a float, never a millimetre. Panel height (`44.45n − 0.79 mm`) is a **render-time derivation** for the PDF only, never stored, real panels measure below spec and inferring U from a measurement is a bug factory.

**Physical dimensions.** `Len` = **int64 nanometres.**

Why nanometres specifically: 1 in = 25 400 000 nm exactly, so *every* imperial fraction down to 1/1000 in is an exact integer, including the EIA 1/32-in inter-panel clearance (793 750 nm) and 1/16-in hardware dimensions (1 587 500 nm). Metric catalog values in mm are exact by construction. int64 covers 9.2 × 10⁹ m.

**Rejected: micrometres.** Reads better in JSON (`508000` vs `508000000`) but 1/32 in = 793.75 µm and 1/16 in = 1587.5 µm are *not* integral. You would round, and the rounding shows up as a half-micron seam in a dimensioned PDF and as an unstable JSON round-trip. Losing readability of a number no human reads is a cheap price.

**Rejected: floating-point millimetres.** The obvious choice and the wrong one. Three concrete failures: (a) `0.1 + 0.2` in snap accumulation produces positions that fail equality tests, breaking the *"apply then revert must produce a byte-identical document"* undo property test; (b) `toJson`→`fromJson`→`toJson` is not bit-stable, so the file diffs spuriously in git and the dirty flag lies; (c) accumulated drift across a 40-device stack is visible at print scale.

**Canvas positions: a different space entirely, and integer.**

There are **two coordinate spaces**, and conflating them is a category error:

1. **Rack elevation space is not stored.** A device's X/Y in the elevation is a pure function of `(Placement, Rack.railType, Rack.widthClass, face)`. There is nothing to persist. Storing elevation coordinates would let them diverge from the RU index, the classic "the drawing says RU 7 but it's drawn at RU 8" bug. Elevation is a **projection**, computed fresh, always correct by construction.

2. **Schematic space is stored, as integer grid units.** `Pt{int gx, gy, int sx, sy}` where 1 gu ≡ 2.54 mm (0.1 in) nominal schematic pitch, and `sx`/`sy` are 1/64-gu sub-offsets for annotation nudging. Rationale: a schematic is not a scale drawing; it is a diagram on a pitch, exactly like a board schematic. Integer grid units make snapping, orthogonal routing, jog insertion, and crossing/hop detection **exact integer arithmetic**: deterministic, diff-stable, unit-testable without tolerance epsilons, and immune to zoom-dependent drift. Zoom is a *view transform* applied at paint time and never written back.

**Rotation is `int rotationQuarterTurns` (0–3).** No arbitrary angles in v1. Schematics are orthogonal; free rotation buys nothing and costs float geometry throughout the router.

**Mass** is `int` micrograms (1 lb = 453 592 370 µg exactly). **Money** is `int` minor units + ISO currency code. **Scale** is `int numerator / int denominator`. **Percentages** are permille integers.

The invariant: **`grep` the persisted model for `double` and find zero hits.** (§6, I-1.)

### 3.8 The Structure device in detail

Modelled as a first-class `DeviceInstance` with `kind: structure`, `frontU: 0`, `rearU: 0`, `mountMethod: notInRack`, `Placement: UnplacedPlacement`. It maps to a real standard: the TIA-570-D **Distribution Device**. It renders as a bordered field-infrastructure block outside the rack boundary, with each drop as an off-page-connector flag (J-STD-710 "Demarcation for All Services"; circular callout shape = home run).

**Three-level hierarchy, and each level is the atomic unit of a different activity:**

| Level | Atomic unit of | Key fields |
|---|---|---|
| `StructureBody` | *the building side of the project* | role, enclosure model, distribution location |
| `StructureBundle` | **creation, specification, pricing** | outlet designation, room, wall, height AFF, TIA-570-D grade, conduit/pathway |
| `StructureDrop` | **pulling, terminating, testing, scheduling** | field label + rack label, media, jacket, signal family, terminations, length, status, test result |
| `Port` (1:1 with drop) | **connecting** | the schematic stub a `Link` attaches to |

**Bundles exist because that is how the work is specified.** "Add outlet: Grade 2" is one gesture creating one bundle with **four** drops (2 × Cat6A + 2 × RG6) sharing one outlet designation, one room, one wall, one conduit, one length estimate. Presets: Grade 1 (1×Cat6A + 1×RG6), Grade 2 (2+2), Grade 3 (2×Cat6 + 1×RG6 + 2-fiber), plus user-defined ("AV outlet: 2×Cat6A + 1×16/4 + 1×RG6").

**`signalFamily: "signal.undetermined"` is a first-class, expected state.** At rough-in a Cat6 run is just a Cat6 run. When a `Link` assigns it `video.hdbaset`, rule `SIG-004` offers to promote the drop's family, and every length/termination rule then re-validates retroactively. This "assign later, validate backwards" flow is the whole reason the Structure device is not just a device with a port list.

**Two labels per drop, always.** `fieldLabel` (what's printed on the wall plate: `LR-TV-1A`) and `rackLabel` (the TIA-606 `fs-an` port identifier at the panel: `1A-A12`). **Both print in the schedule.** The single most common on-site failure is a schedule that carries one and the technician needs the other.

**Termination into the rack is a normal `Link`.** `StructureDrop.terminatesAtPortId` is a denormalized convenience cache; the source of truth is a Link from the drop's Port to the patch panel's rear Port. No special case, no second connection mechanism, and the drop-to-panel run appears in the cable schedule like everything else.

**Multiple Structure instances are expected and encouraged.** "Rough-In (First Floor", "Rough-In) Exterior/Cameras", "Utility Service Entrance", "Tie to Rack 2". One giant node is unreadable; four labelled edge banks match how the installer thinks.

**`RoughInStatus` is not decorative.** `planned → pulled → dressed → terminated → tested → issued`, plus `TestResult` with headroom dB and certifier report ID. This is exactly what converts the design PDF into the as-built PDF that AVIXA D401.01 calls essential, and it's what makes the "unused home runs" view, a genuinely valuable deliverable, fall out for free.

### 3.9 Identifier format engine (not a hardcoded scheme)

TIA-606 explicitly declines to mandate a format but *requires* consistency and uniqueness. So `IdFormat` is a token template evaluated by the app, shipped with presets: TIA-606 commercial (`{floor}{space}-{panel}{port}`), residential Scheme A (`{type}-{room}-{dir}-{seq}`), Scheme C (`{area}-{type}-{run}`), and the AV block convention (`{devBlock}{portSeq:2}` → matrix inputs `2301–2316`, outputs `2401–2416`).

`designatorBlockSize` supports **reserve-ID allocation**: ports exist as entities whether or not they are connected (`Port.reserved`), so adding a 17th matrix output later does not renumber the first sixteen. This is why `Port` is a first-class entity rather than a lazily-created connection endpoint.

---

## 4. On-disk format

### 4.1 Container

v1 is **plain, pretty-printed, key-sorted UTF-8 JSON** with extension `.rackmate`. Deterministic key ordering and 2-space indentation make it `git diff`-able, which matters more than the ~3× size for files in the 100–500 KB range.

Behind a `DocumentCodec` interface from commit one:

```dart
abstract interface class DocumentCodec {
  Future<Project> read(Uint8List bytes);
  Future<Uint8List> write(Project doc);
}
// v1: PlainJsonCodec
// v2: ZipCodec — document.json + assets/<uuid>.png + manifest.json
// Read dispatches on the PK\x03\x04 magic. The extension NEVER changes;
// v1 files keep opening forever.
```

Saves are **atomic**: write `foo.rackmate.tmp` in the same directory → `flush()` → `rename()`. Optionally retain `foo.rackmate.bak`.

### 4.2 Envelope

```json
{
  "generator": "RackMate",
  "schemaVersion": 1,
  "minReaderVersion": 1,
  "appVersion": "0.1.0+build.42",
  "id": "0190e3c1-7a2f-7c9d-8b11-a0f2c4e51d33",
  "createdAt": "2026-07-18T09:14:02.113847Z",
  "modifiedAt": "2026-07-18T16:42:55.902310Z",
  "revision": 412,
  "document": { … }
}
```

`generator` is a magic key: foreign JSON is rejected with a real error rather than a null-cast crash. `schemaVersion` and `appVersion` are strictly separate.

### 4.3 Migration strategy

```dart
const kCurrentSchemaVersion = 1;
typedef JsonMap = Map<String, Object?>;
typedef Migration = JsonMap Function(JsonMap);

/// APPEND-ONLY. Frozen the moment a version ships. A migration is a historical
/// record — editing one corrupts users' files.
const migrations = <int, Migration>{
  // 1: _v1ToV2,   // added when v2 ships. Never deleted. Never edited.
};

JsonMap migrateToCurrent(JsonMap raw) {
  if (raw['generator'] != 'RackMate') {
    throw const FormatException('Not a RackMate document');
  }
  final minReader = raw['minReaderVersion'] as int? ?? 1;
  if (minReader > kCurrentSchemaVersion) {
    throw NewerSchemaException(minReader);   // refuse; cannot safely round-trip
  }
  var v = raw['schemaVersion'] as int;
  if (v > kCurrentSchemaVersion) {
    // Readable but not fully understood → open READ-ONLY with a banner.
    return raw..['_openReadOnly'] = true;
  }
  while (v < kCurrentSchemaVersion) {
    raw = migrations[v]!(raw);
    v = raw['schemaVersion'] as int;   // each migration bumps its own version
  }
  return raw;
}
```

Five rules committed to on day one:

1. **Migrations are pure functions on raw `Map<String, Object?>`, never on typed objects.** Migrate the map fully, *then* deserialize. Typed migration requires keeping every historical class shape alive in the codebase.
2. **`schemaVersion` + `minReaderVersion` together** give both directions: an old app opens a newer file read-only (preserving unknown fields on a subsequent save-as), and refuses outright only when a genuinely breaking change bumped `minReaderVersion`.
3. **Golden fixture corpus.** `test/fixtures/v1_sample.rackmate`, `v2_sample.rackmate`, … Every release, one test opens *every* historical fixture and asserts it migrates to a valid current document. Add a fixture the day each version ships. Highest value-per-line test in the project.
4. **Enums are strings, never ordinals.** `"hdmi"`, not `3`. Unknown enum values fall back to an `unknown(raw)` variant that round-trips rather than throwing.
5. **Additive-only within a major.** Deprecate, never remove or rename.

### 4.4 Forward compatibility: unknown-field preservation

Every entity carries `EntityMeta.unknown: Map<String, Object?>`. The codec routes every unrecognized key there on read and re-emits it verbatim on write. A v1.0 app opening a v1.4 file round-trips without destroying newer data. Combined with `minReaderVersion`, this is what stops old builds silently corrupting new files.

### 4.5 Abbreviated `.rackmate` example

One 12U rack, an 8×8 HDMI matrix, a 24-port PoE switch, one Structure device with a Grade-2 bundle, and two links. `…` marks elision.

```json
{
  "generator": "RackMate",
  "schemaVersion": 1,
  "minReaderVersion": 1,
  "appVersion": "0.1.0",
  "id": "0190e3c1-7a2f-7c9d-8b11-a0f2c4e51d33",
  "createdAt": "2026-07-18T09:14:02.113847Z",
  "modifiedAt": "2026-07-18T16:42:55.902310Z",
  "revision": 412,

  "document": {
    "projectName": "Ashford Residence",
    "projectNumber": "2026-0114",
    "clientName": "M. Ashford",
    "integratorName": "Northbeam Systems",

    "settings": {
      "displayUnits": "imperial",
      "ruNumbering": "bottomUpFromOne",
      "defaultElevationFace": "rear",
      "greyscaleSafeExport": false,
      "linkDesignatorFormat": "W{seq:3}",
      "dropFieldLabelFormat": "{type}-{room}-{dir}-{seq}",
      "dropRackLabelFormat": "{floor}{space}-{panel}{port}",
      "designatorBlockSize": 100,
      "signalColorSchemeId": "scheme.okabe_ito_av",
      "blockExportOnErrors": true,
      "ruleSeverityOverrides": { "RCK-008": "off" }
    },

    "locations": {
      "loc-basement": { "id": "loc-basement", "kind": "room", "name": "Basement AV Closet",
                        "code": "BAS", "floorNumber": 0, "spaceCode": "A", "order": "a0" },
      "loc-living":   { "id": "loc-living", "kind": "room", "name": "Living Room",
                        "code": "LIV", "floorNumber": 1, "order": "a1" }
    },

    "racks": {
      "rk-1": {
        "id": "rk-1", "name": "AV Rack", "designator": "RK-1",
        "locationId": "loc-basement",
        "heightU": 12,
        "widthClass": "eia19",
        "railType": "tapped10_32", "fullHoleRail": true,
        "formFactor": "wallSwingGate",
        "usableDepthNm": 457200000,
        "overallDepthNm": 482600000,
        "weightCapacityUg": 45359237000,
        "isSwingFrame": true, "hingeSide": "left",
        "zeroUChannels": [
          { "id": "ch-rear-l", "side": "rearLeft", "startU": 1, "endU": 12 }
        ],
        "order": "a0",
        "meta": { "createdAt": "…", "updatedAt": "…", "updatedBy": "inst-7f2c",
                  "localRevision": 3 }
      }
    },

    "templates": {
      "tpl.generic.hdmi_matrix_8x8@2": {
        "templateId": "tpl.generic.hdmi_matrix_8x8", "version": 2,
        "contentHash": "sha256:1f4c…9ab0",
        "capturedAt": "2026-07-18T09:20:11Z",
        "body": {
          "manufacturer": "Generic", "model": "8x8 HDMI Matrix",
          "category": "matrix.hdmi", "typePrefix": "MTX",
          "frontU": 2, "rearU": 2, "side": "both",
          "mountMethod": "rackEars", "widthClass": "full", "nominalSpanTwelfths": 12,
          "bodyDepthNm": 355600000, "connectorProjectionNm": 63500000,
          "weightUg": 4535923700,
          "requiresClearanceAboveU": 0, "requiresClearanceBelowU": 0,
          "thermalClass": "lowHeat",
          "isContainer": false, "isPassthrough": false,
          "power": { "nameplateWatts": 60, "typicalWatts": 34, "nominalVolts": 120,
                     "isContinuousLoad": true, "outletsProvided": 0,
                     "outletsConsumed": 1, "inletPlug": "C14" },
          "ports": [
            { "key": "hdmi_in_1", "label": "HDMI IN 1", "connector": "conn.hdmi_a",
              "signalFamily": "video.hdmi.2_0", "carriedProtocols": ["video.hdmi.2_0"],
              "acceptedFamilies": ["video.hdmi.2_0","video.hdmi.1_4"],
              "direction": "sink", "topology": "p2p", "maxConnections": 1,
              "gender": "female", "face": "rear",
              "position": { "ruOffset": 1, "xTwelfth": 0, "xFineNm": 12700000,
                            "yFineNm": 15875000 },
              "order": "a0" },
            "… hdmi_in_2 … hdmi_in_8 …",
            { "key": "hdmi_out_1", "label": "HDMI OUT 1", "connector": "conn.hdmi_a",
              "signalFamily": "video.hdmi.2_0",
              "carriedProtocols": ["video.hdmi.2_0","audio.earc"],
              "direction": "source", "returnChannel": { "signalFamily": "audio.earc",
                            "direction": "sink", "enabled": false },
              "topology": "p2p", "maxConnections": 1,
              "gender": "female", "face": "rear",
              "position": { "ruOffset": 0, "xTwelfth": 0, "xFineNm": 12700000,
                            "yFineNm": 15875000 },
              "order": "b0" },
            "… hdmi_out_2 … hdmi_out_8 …",
            { "key": "rs232", "label": "RS-232", "connector": "conn.de9",
              "signalFamily": "ctl.rs232", "direction": "bidirectional",
              "topology": "p2p", "maxConnections": 1, "gender": "female",
              "face": "rear",
              "serial": { "role": "DCE", "baud": 9600, "dataBits": 8,
                          "parity": "none", "stopBits": 1, "flowControl": "none" },
              "order": "c0" },
            { "key": "ac_in", "label": "AC IN", "connector": "conn.iec_c14",
              "signalFamily": "power.ac_120", "direction": "sink",
              "gender": "male", "face": "rear", "maxConnections": 1,
              "power": { "role": "inlet", "volts": 120, "maxAmps": 5,
                         "drawWatts": 60 },
              "order": "d0" }
          ],
          "portGroups": []
        }
      },

      "tpl.generic.poe_switch_24@1": {
        "templateId": "tpl.generic.poe_switch_24", "version": 1,
        "contentHash": "sha256:88de…41c7",
        "body": {
          "manufacturer": "Generic", "model": "24-Port PoE+ Switch",
          "category": "network.switch", "typePrefix": "SW",
          "frontU": 1, "rearU": 0, "side": "front",
          "mountMethod": "rackEars", "widthClass": "full", "nominalSpanTwelfths": 12,
          "bodyDepthNm": 254000000, "weightUg": 3628738900,
          "thermalClass": "highHeat", "requiresClearanceAboveU": 1,
          "power": { "nameplateWatts": 440, "typicalWatts": 180,
                     "isContinuousLoad": true, "outletsConsumed": 1,
                     "inletPlug": "C14" },
          "poeBudgetWatts": 370,
          "ports": [
            { "key": "eth_01", "label": "1", "connector": "conn.rj45",
              "signalFamily": "net.ethernet",
              "carriedProtocols": ["net.ethernet","audio.dante","audio.aes67"],
              "acceptedFamilies": ["net.ethernet"],
              "direction": "bidirectional", "topology": "star",
              "maxConnections": 1, "gender": "female", "face": "front",
              "linkSpeedMbps": 1000,
              "poe": { "role": "pse", "standard": "at", "type": 2, "class": 4,
                       "watts": 30 },
              "position": { "ruOffset": 0, "xTwelfth": 0, "xFineNm": 25400000,
                            "yFineNm": 12700000 },
              "order": "a0" },
            "… eth_02 … eth_24 …",
            { "key": "sfp_1", "label": "SFP+ 1", "connector": "conn.sfp_plus",
              "signalFamily": "net.ethernet", "direction": "bidirectional",
              "face": "front", "sfp": "SFP+", "linkSpeedMbps": 10000, "order": "b0" },
            { "key": "ac_in", "label": "AC IN", "connector": "conn.iec_c14",
              "signalFamily": "power.ac_120", "direction": "sink", "face": "rear",
              "power": { "role": "inlet", "volts": 120, "maxAmps": 6,
                         "drawWatts": 440 },
              "order": "c0" }
          ]
        }
      },

      "tpl.system.structure@1": {
        "templateId": "tpl.system.structure", "version": 1,
        "contentHash": "sha256:0000…0001",
        "body": {
          "manufacturer": "—", "model": "Structured Wiring Field",
          "category": "system.structure",
          "frontU": 0, "rearU": 0, "side": "none",
          "mountMethod": "notInRack", "widthClass": "customWidth",
          "weightUg": 0,
          "power": { "outletsProvided": 0, "outletsConsumed": 0 },
          "ports": []
        }
      }
    },

    "devices": {
      "dev-mtx1": {
        "id": "dev-mtx1", "kind": "rackDevice",
        "templateRef": { "templateId": "tpl.generic.hdmi_matrix_8x8",
                         "version": 2, "contentHash": "sha256:1f4c…9ab0" },
        "templateUpdateAvailable": false,
        "designator": "MTX-01", "name": "Main HDMI Matrix",
        "status": "new",
        "placement": { "type": "rail", "rackId": "rk-1", "ruIndex": 7,
                       "face": "front", "startTwelfth": 0, "spanTwelfths": 12 },
        "overrides": {},
        "portIds": ["p-mtx1-in1", "…", "p-mtx1-out1", "…", "p-mtx1-ac"],
        "zOrder": "a0",
        "meta": { "createdAt": "2026-07-18T09:22:00Z",
                  "updatedAt": "2026-07-18T15:02:11Z",
                  "updatedBy": "inst-7f2c", "localRevision": 7 }
      },

      "dev-sw1": {
        "id": "dev-sw1", "kind": "rackDevice",
        "templateRef": { "templateId": "tpl.generic.poe_switch_24",
                         "version": 1, "contentHash": "sha256:88de…41c7" },
        "designator": "SW-01", "name": "AV Network Switch",
        "status": "new",
        "placement": { "type": "rail", "rackId": "rk-1", "ruIndex": 10,
                       "face": "front", "startTwelfth": 0, "spanTwelfths": 12 },
        "overrides": { "power.typicalWatts": 210 },
        "portIds": ["p-sw1-e01", "…", "p-sw1-ac"],
        "zOrder": "a1",
        "meta": { "…": "…" }
      },

      "dev-str1": {
        "id": "dev-str1", "kind": "structure",
        "templateRef": { "templateId": "tpl.system.structure", "version": 1,
                         "contentHash": "sha256:0000…0001" },
        "designator": "STR-01", "name": "Rough-In — First Floor",
        "status": "existing",
        "placement": { "type": "unplaced", "schematicHint": { "gx": -40, "gy": 12 } },
        "locationId": "loc-basement",
        "structureBodyId": "sb-1",
        "portIds": ["p-str1-d1", "p-str1-d2", "p-str1-d3", "p-str1-d4"],
        "zOrder": "a2",
        "meta": { "…": "…" }
      }
    },

    "structureBodies": {
      "sb-1": {
        "id": "sb-1", "deviceId": "dev-str1",
        "title": "Rough-In — First Floor", "role": "homeRunField",
        "enclosureModel": "Leviton 42in SMC",
        "distributionDeviceLocationId": "loc-basement",
        "bundleIds": ["bun-liv-tv1"]
      }
    },

    "bundles": {
      "bun-liv-tv1": {
        "id": "bun-liv-tv1", "structureBodyId": "sb-1",
        "outletDesignation": "LR-TV-1",
        "locationId": "loc-living", "wall": "n",
        "mountHeightAffNm": 1524000000,
        "floorNumber": 1,
        "grade": "grade2",
        "conduitId": "C-14",
        "nominalRunLengthNm": 21336000000,
        "dropIds": ["drop-1", "drop-2", "drop-3", "drop-4"],
        "bundleStatus": "pulled",
        "order": "a0"
      }
    },

    "drops": {
      "drop-1": {
        "id": "drop-1", "bundleId": "bun-liv-tv1", "portId": "p-str1-d1",
        "fieldLabel": "LR-TV-1A", "rackLabel": "1A-A12",
        "media": "media.cat6a_futp", "conductorCount": 8, "gaugeAwg": 23,
        "jacket": "cmr",
        "signalFamily": "video.hdbaset",
        "terminationRack": "keystone", "terminationField": "keystone",
        "actualLengthNm": 22860000000,
        "status": "terminated",
        "test": { "pass": true, "headroomDb": 4, "certId": "FLK-2026-0114-012",
                  "testedBy": "R. Okonkwo", "at": "2026-07-15T14:22:00Z" },
        "order": "a0",
        "meta": { "…": "…" }
      },
      "drop-2": {
        "id": "drop-2", "bundleId": "bun-liv-tv1", "portId": "p-str1-d2",
        "fieldLabel": "LR-TV-1B", "rackLabel": "1A-A13",
        "media": "media.cat6a_futp", "conductorCount": 8,
        "signalFamily": "net.ethernet",
        "terminationRack": "keystone", "terminationField": "keystone",
        "actualLengthNm": 22860000000,
        "status": "terminated",
        "order": "a1", "meta": { "…": "…" }
      },
      "drop-3": {
        "id": "drop-3", "bundleId": "bun-liv-tv1", "portId": "p-str1-d3",
        "fieldLabel": "LR-TV-1C", "rackLabel": "COAX-04",
        "media": "media.rg6_quad", "conductorCount": 1,
        "signalFamily": "signal.undetermined",
        "terminationRack": "fBarrel", "terminationField": "fBarrel",
        "status": "pulled",
        "order": "a2", "meta": { "…": "…" }
      },
      "drop-4": { "…": "… second RG6, LR-TV-1D …" }
    },

    "ports": {
      "p-mtx1-out1": {
        "id": "p-mtx1-out1", "deviceId": "dev-mtx1",
        "templatePortKey": "hdmi_out_1",
        "designator": "J2401", "overrides": {},
        "orphaned": false, "reserved": false,
        "meta": { "…": "…" }
      },
      "p-sw1-e01": {
        "id": "p-sw1-e01", "deviceId": "dev-sw1", "templatePortKey": "eth_01",
        "designator": "J1101", "overrides": {},
        "network": { "portRole": "access", "vlans": [20] },
        "poeActual": { "class": 0, "watts": 0 },
        "meta": { "…": "…" }
      },
      "p-str1-d1": {
        "id": "p-str1-d1", "deviceId": "dev-str1", "templatePortKey": null,
        "userLabel": "LR-TV-1A", "designator": "STR-01A",
        "overrides": {}, "meta": { "…": "…" }
      },
      "p-str1-d2": {
        "id": "p-str1-d2", "deviceId": "dev-str1", "templatePortKey": null,
        "userLabel": "LR-TV-1B", "designator": "STR-01B",
        "overrides": {}, "meta": { "…": "…" }
      },
      "…": "… remaining ports elided …"
    },

    "nets": {
      "net-lrtv-hdbt": {
        "id": "net-lrtv-hdbt", "name": "LR-TV HDBaseT", "designator": "N001",
        "signalFamily": "video.hdbaset", "topology": "pointToPoint",
        "isImplicit": false, "meta": { "…": "…" }
      },
      "net-lrtv-data": {
        "id": "net-lrtv-data", "name": null, "designator": "N002",
        "signalFamily": "net.ethernet", "topology": "starSwitched",
        "isImplicit": true, "meta": { "…": "…" }
      }
    },

    "links": {
      "lnk-w001": {
        "id": "lnk-w001", "designator": "W001", "netId": "net-lrtv-hdbt",
        "conductors": [
          { "role": "", "fromPortId": "p-mtx1-out1", "toPortId": "p-str1-d1" }
        ],
        "media": "media.cat6a_futp", "gaugeAwg": 23, "jacket": "cmr",
        "shielded": true, "plenum": false,
        "calculatedLengthNm": 22860000000,
        "cutLengthNm": 25400000000,
        "slackPercent": 10,
        "pathwayId": "C-14",
        "inlineAdapters": [
          { "id": "ad-1", "label": "HDBaseT TX/RX pair",
            "fromConnector": "conn.hdmi_a", "toConnector": "conn.rj45",
            "convertsTo": "video.hdbaset", "model": "Generic HDBaseT extender set",
            "poweredExternally": false,
            "satisfiesRuleIds": ["CON-001", "SIG-002"] }
        ],
        "status": "terminated",
        "autoRoute": true,
        "waypointsBySheet": {},
        "order": "a0",
        "meta": { "createdAt": "2026-07-18T10:03:00Z",
                  "updatedAt": "2026-07-18T16:41:02Z",
                  "updatedBy": "inst-7f2c", "localRevision": 4 }
      },

      "lnk-w002": {
        "id": "lnk-w002", "designator": "W002", "netId": "net-lrtv-data",
        "conductors": [
          { "role": "", "fromPortId": "p-str1-d2", "toPortId": "p-sw1-e01" }
        ],
        "media": "media.cat6a_futp", "jacket": "cmr", "shielded": true,
        "calculatedLengthNm": 22860000000,
        "status": "tested",
        "test": { "pass": true, "headroomDb": 6, "certId": "FLK-2026-0114-013" },
        "autoRoute": true,
        "order": "a1",
        "meta": { "…": "…" }
      }
    },

    "circuits": {
      "ckt-a14": { "id": "ckt-a14", "designator": "Panel A / Brkr 14",
                   "breakerAmps": 20, "volts": 120, "dedicated": true,
                   "locationId": "loc-basement" }
    },

    "sheets": {
      "sh-t001": { "id": "sh-t001", "number": "T0.01", "title": "Legend & Notes",
                   "kind": "legend", "paper": "ansiB", "orientation": "landscape",
                   "carriesLegend": true, "order": "a0", "items": {} },
      "sh-t201": { "id": "sh-t201", "number": "T2.01",
                   "title": "Rack Elevations — Front", "kind": "elevationFront",
                   "paper": "ansiB", "scaleNumerator": 1, "scaleDenominator": 8,
                   "carriesLegend": false, "legendLocationNote": "See sheet T0.01",
                   "includedRackIds": ["rk-1"], "order": "a1", "items": {} },
      "sh-t601": { "id": "sh-t601", "number": "T6.01",
                   "title": "Wiring Plan / Interconnect", "kind": "schematic",
                   "detailLevel": "detailed", "carriesLegend": false,
                   "legendLocationNote": "See sheet T0.01",
                   "order": "a2",
                   "items": {
                     "si-1": { "id": "si-1", "targetId": "dev-mtx1",
                               "position": { "gx": 20, "gy": 8 },
                               "rotationQuarterTurns": 0, "collapsed": false,
                               "zOrder": "a0" },
                     "si-2": { "id": "si-2", "targetId": "dev-sw1",
                               "position": { "gx": 20, "gy": 40 },
                               "rotationQuarterTurns": 0, "zOrder": "a1" },
                     "si-3": { "id": "si-3", "targetId": "dev-str1",
                               "position": { "gx": -40, "gy": 12 },
                               "rotationQuarterTurns": 0, "zOrder": "a2" }
                   } },
      "sh-t602": { "id": "sh-t602", "number": "T6.02", "title": "Wiring Schedule",
                   "kind": "wiringSchedule", "order": "a3", "items": {} },
      "sh-t603": { "id": "sh-t603", "number": "T6.03",
                   "title": "Structure / Home-Run Drop Schedule",
                   "kind": "dropSchedule", "order": "a4", "items": {} }
    },

    "notes": {
      "nt-1": { "id": "nt-1", "kind": "callout", "text": "Home run — see T6.03",
                "anchorEntityId": "dev-str1", "sheetId": "sh-t601",
                "shape": "circle", "position": { "gx": -46, "gy": 6 } }
    },

    "ackedFindings": {
      "ack-1": {
        "id": "ack-1", "ruleId": "RCK-005",
        "targetFingerprint": "dev-mtx1|rk-1",
        "targetEntityId": "dev-mtx1",
        "reason": "Swing-gate rack; rear access confirmed, 14in clear behind. OK.",
        "by": "R. Riley", "at": "2026-07-18T16:20:00Z",
        "demotedTo": "advisory"
      }
    },

    "revisionBlock": [
      { "id": "rev-a", "label": "A", "date": "2026-07-18",
        "description": "Issued for rough-in", "by": "JS", "issued": true }
    ],

    "registries": {
      "builtinCatalogVersion": "2026.07.1",
      "signalFamilies": {
        "video.hdbaset": {
          "id": "video.hdbaset", "displayName": "HDBaseT (5Play)",
          "shortTag": "HBT", "domain": "digitalVideo",
          "defaultDirection": "source", "defaultTopology": "p2p",
          "typicalConnectors": ["conn.rj45"],
          "typicalMedia": ["media.cat6a_futp", "media.cat6_utp"],
          "compatibleWith": [], "adaptableTo": ["video.hdmi.2_0"],
          "maxRunLengthPassive": 100000000000,
          "carriesPower": true,
          "color": [0, 114, 178, 255], "dashPattern": [],
          "lineWeightPermille": 1000, "glyph": "▲"
        },
        "net.ethernet": {
          "id": "net.ethernet", "displayName": "Ethernet", "shortTag": "NET",
          "domain": "network", "defaultDirection": "bidirectional",
          "defaultTopology": "star", "typicalConnectors": ["conn.rj45"],
          "maxRunLengthPassive": 100000000000,
          "color": [0, 158, 115, 255], "dashPattern": [],
          "lineWeightPermille": 1500, "glyph": "■"
        },
        "signal.undetermined": {
          "id": "signal.undetermined", "displayName": "Undetermined (rough-in)",
          "shortTag": "STR", "domain": "structureUndetermined",
          "color": [153, 153, 153, 255], "dashPattern": [6, 3],
          "lineWeightPermille": 750
        },
        "…": "… only families referenced by this document are embedded …"
      },
      "connectors": { "conn.rj45": { "…": "…" }, "conn.hdmi_a": { "…": "…" },
                      "conn.iec_c14": { "…": "…" }, "conn.de9": { "…": "…" } },
      "media": {
        "media.cat6a_futp": {
          "id": "media.cat6a_futp", "displayName": "Cat6A F/UTP", "shortTag": "C6A",
          "conductorCount": 8, "pairCount": 4, "gaugeAwg": 23, "impedanceOhms": 100,
          "shielded": true, "availableJackets": ["cmr", "cmp", "lszh"],
          "maxChannelLength": 100000000000,
          "minBendRadiusNm": 25400000,
          "supports": ["net.ethernet", "video.hdbaset", "audio.dante", "ctl.rs485"]
        },
        "media.rg6_quad": { "…": "…" }
      },
      "cableSpecs": {},
      "colorSchemes": { "scheme.okabe_ito_av": { "…": "…" } },
      "rules": [
        { "ruleId": "SIG-001", "scope": "link", "defaultSeverity": "error",
          "blocksCreation": false,
          "message": "HDBaseT connected to an Ethernet switch port.",
          "rationale": "HDBaseT uses Ethernet cabling and connectors but is not "
                       "Ethernet. PoH may damage the switch port.",
          "remedyHint": "Terminate on an HDBaseT receiver, not a switch.",
          "userAcknowledgeable": true,
          "predicate": { "and": [
            { "endpointSignalFamily": "video.hdbaset" },
            { "otherEndpointSignalFamily": "net.ethernet" },
            { "otherEndpointPortRoleIn": ["access","trunk","uplink"] } ] } },
        "… remaining rules elided …"
      ]
    },

    "tombstones": {
      "dev-old-avr": { "id": "dev-old-avr", "entityType": "DeviceInstance",
                       "deletedAt": "2026-07-18T11:40:12Z", "deletedBy": "inst-7f2c",
                       "summary": "AVR-01 (7.2ch AV Receiver)" }
    }
  }
}
```

---

## 5. Cloud-readiness

No CRDT now. Rack design is overwhelmingly single-user-at-a-time and no Dart CRDT library is production-grade. But **six decisions made now** keep both last-write-wins sync *and* a later CRDT viable, and each is nearly free today.

### 5.1 Flat entity maps, never a nested tree

`Map<Uuid, DeviceInstance>` and `Map<Uuid, Port>` side by side, `Port` carries `deviceId`, it is not nested inside the device. This single decision simultaneously enables:

- **per-entity sync** (an entity is a addressable sync unit);
- **cheap commands** (a command touches one map entry);
- **fine-grained repaint invalidation** (the canvas subscribes to entity-class revisions);
- **O(1) lookup during wire routing** (the hot path).

Nested trees make all four hard, and retrofitting flatness later is a rewrite of every command.

### 5.2 No positional index is ever identity

Ordering (device stacking on the schematic, port display order, sheet order, sibling locations, link z-order) uses a **fractional index string** (LexoRank / Figma style: `"a0"`, `"a0V"`, `"a1"`). Inserting between two items is a purely local edit that cannot collide. An integer `sortOrder` requires renumbering neighbours, and neighbour-renumbering is precisely the operation that makes sync impossible to retrofit.

The `portIds` list on `DeviceInstance` is a **derived convenience index**, sorted by `Port.order`, and is explicitly *not* authoritative, rebuildable from the ports map at any time (I-11).

### 5.3 Per-entity LWW metadata from day one

Every entity carries `EntityMeta { createdAt, updatedAt, updatedBy, localRevision }`. This *is* the last-write-wins tuple. Adding it later means a migration that cannot backfill honest values, every existing entity gets a lie for `updatedAt`, and the first sync resolves conflicts wrongly.

`Project.revision` is a document-level monotonic counter, already required for dirty-tracking, and doubles as the sync cursor.

**UUID v7** for every entity ID. Over v4 this buys: time-ordered IDs (log reading and debugging become sane), a free stable creation-order sort without a separate field, and index locality if these ever land in a database.

### 5.4 Tombstones: the one thing that genuinely cannot be retrofitted

Deletions are the retrofit-killer. With hard deletes, a later sync cannot distinguish *"the peer deleted this"* from *"the peer never had it"*, and the second interpretation resurrects deleted devices on every sync. `Map<Uuid, Tombstone>` costs a few dozen bytes per delete, makes delete commands trivially invertible for undo, and powers the history panel ("Deleted AVR-01"). Do it now or accept that sync is a rewrite.

Prune policy: tombstones older than the last-synced watermark (or 1 year for local-only files) are compacted on save.

### 5.5 Conflict units: and which entities can never conflict

| Entity | Conflict unit? | Reasoning |
|---|---|---|
| `Project` (settings, metadata) | **yes**: field-level LWW | Small, rarely edited concurrently |
| `Rack` | **yes**: whole entity | Coarse is fine; racks change rarely |
| `DeviceInstance` **including its `Port`s** | **yes**: as one unit | A port has no meaning without its device; template migration rewrites all ports atomically; splitting them would let a sync produce a device whose port set matches neither side |
| `Link` **including its `Conductor`s** | **yes**: whole entity | A conductor list is meaningless split |
| `Net` | **yes** | Merging two nets is a command, not a field write; concurrent merges conflict honestly |
| `StructureBundle` **including its `StructureDrop`s** | **yes**: as one unit | Same argument as device+ports; a bundle is the specification atom |
| `Sheet` + its `SheetItem`s | **yes**: as one unit | Layout is holistic |
| `Note`, `Circuit`, `AckedFinding`, `RevisionEntry`, `Location` | **yes**: whole entity | Small and independent |
| `TemplateSnapshot` | **never conflicts** | Immutable + content-addressed. Two peers adding the same `(templateId, version)` produce byte-identical objects; a hash mismatch is a hard error, not a merge |
| Registry entries | **never conflicts** | Same reasoning. Custom entries get UUID-suffixed ids to avoid namespace collision |
| `Tombstone` | **never conflicts** | Append-only, idempotent |
| `Finding` (unacknowledged) | **not synced** | Purely derived; recomputed on both sides |
| Elevation coordinates | **do not exist** | Derived from `Placement`; nothing to conflict over (§3.7) |

**The design win worth stating explicitly:** by making templates and registries immutable and content-addressed, and by making elevation geometry derived rather than stored, a large fraction of the document is *structurally incapable* of conflicting. What remains conflictable is small and semantically meaningful.

### 5.6 Sync-hostile things deliberately avoided

- No auto-incrementing integer keys anywhere.
- No "first element of the list is special" semantics.
- No entity whose identity is a composite of mutable fields.
- No derived data persisted as authoritative (`portIds`, `bundleStatus`, `templateUpdateAvailable` are all rebuildable caches, flagged as such).
- Designators (`MTX-01`, `W042`) are **unique but not identity**. Two peers can independently allocate `W042`; renumbering on merge is a cosmetic fix-up command, not a data loss.

---

## 6. Invariants and validation rules the model must enforce

Split into **structural invariants** (I-*, the model is corrupt if violated, assert on load, refuse or repair) and **DRC rules** (§3.5, the *design* is questionable, surface, never corrupt).

### Structural invariants

1. **No `double` appears anywhere in the persisted model.** All dimensions are `int` nanometres, all masses `int` micrograms, all canvas positions `int` grid units, all scales `int`/`int`, all percentages `int` permille. Enforced by a codec-level assertion and a lint.
2. Every entity ID is a valid UUID v7 and is **unique across the entire document**, not merely within its map.
3. Every map key equals its value's `id` field.
4. **No entity ID appears in both an entity map and `tombstones`.**
5. Every foreign key resolves to a live (non-tombstoned) entity, or is explicitly nullable. Dangling references are a load error; the loader quarantines the referencing entity rather than crashing.
6. `Project.revision` is strictly monotonic across the life of the document and never decreases on save.
7. `schemaVersion ≥ minReaderVersion ≥ 1`.
8. Every `TemplateSnapshot` in `templates` is keyed `"$templateId@$version"`, and `sha256(canonicalJson(body)) == contentHash`. A mismatch is a hard load error (detects hand-edited or corrupted snapshots).
9. Every `DeviceInstance.templateRef` resolves to an embedded `TemplateSnapshot` with matching `contentHash`, **or** `localTemplate` is non-null. Never neither.
10. `PortDef.key` is unique within a `TemplateBody`, and no key appears in another `PortDef.renamedFrom` within the same body.
11. Every `Port.deviceId` resolves; every `Port.templatePortKey`, when non-null, resolves in the device's effective template **or** `orphaned == true`. `DeviceInstance.portIds` is a derived cache: rebuildable, and rebuilt on load rather than trusted.
12. `Port.designator` is unique project-wide when non-empty. Duplicates are a load *warning* with auto-renumber offered, not an error (imports collide legitimately).
13. **Fractional index strings are unique among siblings** and strictly ordered. Ties are repaired on load by re-spacing.
14. A `TemplateSnapshot` is never mutated after insertion. Editing produces a new `(templateId, version)`.
15. `DeviceInstance.overrides` keys are valid dotted paths into `TemplateBody`. Unknown paths are preserved (forward compat) but reported.
16. `EntityMeta.unknown` round-trips byte-identically: `read(write(read(x))) == read(x)` for every entity.

### Placement invariants

17. `RailPlacement.ruIndex` ∈ `[1, rack.heightU]`, and `ruIndex + effectiveU − 1 ≤ rack.heightU`.
18. `RailPlacement.ruIndex` is always **bottom-origin**. `ProjectSettings.ruNumbering` affects display only and never the stored value.
19. `startTwelfth ∈ [0,11]`, `spanTwelfths ∈ [1,12]`, `startTwelfth + spanTwelfths ≤ 12`.
20. **No two devices overlap** in `(rackId, face, ruIndex range, twelfth range)`. Front and rear occupancy are computed independently from `frontU`/`rearU`. → `RCK-001`.
21. `ShelfPlacement.hostDeviceId` resolves to a device whose effective template has `isContainer == true`, and the containment graph is **acyclic** and at most one level deep in v1.
22. A shelf-hosted device consumes **zero** rack RU of its own.
23. `ZeroUPlacement.channelId` resolves in `rack.zeroUChannels`, and `offsetFromChannelStart` lies within the channel.
24. A `structure`-kind device always has `UnplacedPlacement` and a non-null `structureBodyId`; a non-structure device always has a null `structureBodyId`.

### Connection invariants

25. Every `Link` has ≥ 1 `Conductor`, and every conductor's `fromPortId` / `toPortId` resolve to live ports on **exactly two distinct devices** across the whole link. A link spanning three devices is corrupt.
26. `fromPortId != toPortId` within a conductor. → `TOP-001`.
27. No two conductors on the same link duplicate the same ordered port pair. → `TOP-002`.
28. A port's live conductor count ≤ its effective `maxConnections`. → `TOP-003`.
29. `Link.netId` is never null and resolves. Removing the last link from a non-implicit net leaves the net orphaned but alive (user data preserved); implicit empty nets are garbage-collected.
30. `Link.designator` is unique project-wide.
31. `PortGroup.memberPortIds` all belong to the same `deviceId` as the group.
32. A `PassthroughPairDef`'s two keys resolve to ports on the same device with **opposite `face`** values.
33. Every `SignalRoute.transportLinkIds` entry resolves, and the listed links form a connected path from `sourcePortId` to `sinkPortId` through devices and nets.

### Structure invariants

34. Every `StructureDrop` has **exactly one** `Port`, and that port's `deviceId` equals its bundle's structure device. The relationship is 1:1 in both directions.
35. `StructureBundle.dropIds` and `StructureBody.bundleIds` are ordered by `FracIndex` and contain no duplicates.
36. `StructureDrop.fieldLabel` is unique within the project. `rackLabel` is unique within the project when non-null.
37. A drop's `signalFamily` may be `signal.undetermined`; any *other* value must appear in its `media`'s `supports` list, or `SIG-002` fires.
38. `StructureDrop.terminatesAtPortId`, when non-null, is a cache consistent with the existence of a `Link` between the drop's port and that port. Inconsistency is repaired from the links (links win).
39. `StructureBundle.bundleStatus` is derived as the minimum status across its drops; never authored directly.

### Sheet, note & finding invariants

40. `Sheet.number` is unique project-wide and matches `^[A-Z]{1,2}\d\.\d{2}$` (NCS `[Discipline][Type][Seq]`).
41. **Every sheet with `carriesLegend == false` has a non-empty `legendLocationNote`.** (J-STD-710 §3.6.1, a sheet lacking the legend must state where it is.) Blocks PDF export.
42. `SheetItem.targetId` resolves and is of a kind the sheet's `viewKind` can display.
43. `SheetItem.rotationQuarterTurns ∈ {0,1,2,3}`.
44. `Note.sheetId`, when non-null, resolves; when null, the note appears on every sheet showing its anchor.
45. `AckedFinding.ruleId` resolves in `registries.rules`, and its `targetFingerprint` is recomputable, a stale acknowledgement (fingerprint no longer produced by any current finding) is garbage-collected on load with a log entry, so acknowledgements cannot silently suppress a *different* problem than the one the user reviewed.

### Registry invariants

46. Every `SignalFamilyId` / `ConnectorTypeId` / `MediaTypeId` referenced anywhere resolves in the embedded registries. Unresolvable ids degrade to an `unknown(rawId)` placeholder that **round-trips**, renders in grey with the raw id as its tag, and never throws.
47. A custom registry entry's `basedOn`, when non-null, resolves and is not itself the entry (no cycles).
48. `Circuit.continuousLimitAmps == breakerAmps * 4 ~/ 5`, derived, never stored, so the NEC 80% rule cannot drift out of sync with the breaker rating.

---

## Summary of the load-bearing choices

| # | Decision | Rejected alternative | Cost of getting it wrong |
|---|---|---|---|
| 1 | Embedded immutable versioned template snapshots + opt-in migration | Live library reference | Non-reproducible deliverables; silent drawing changes across machines |
| 2 | `PortDef.key` string identity + `renamedFrom` aliases | Index or label identity | Every template revision rewires the project |
| 3 | Three orthogonal registries (connector / signal / media), rules as data | One `SignalType` enum | The HDBaseT-into-a-switch class of error becomes undetectable; no forward compat |
| 4 | `Link` (2-ended, N conductors) **+** stored `Net` **+** `SignalRoute` | Pure edge list, or pure hypergraph | Either no bus/net semantics, or no cable schedule |
| 5 | Findings + acknowledgement-with-reason; only 5 rules block creation | Static hard-illegal tier | Cannot document existing systems; users route around the tool |
| 6 | Structure = device → bundle → drop → port, `undetermined` is legal | Ad-hoc drop list on the project | Loses the rough-in→assign→revalidate workflow that is the actual value |
| 7 | Integers everywhere; `Len` in nm; elevation derived, schematic in grid units | float mm; stored elevation coords | Unstable round-trips, failing undo property tests, drawing/RU divergence |
| 8 | Flat UUID-v7 maps, fractional indices, per-entity LWW meta, tombstones | Nested tree, integer sort order, hard deletes | Sync is a rewrite instead of a weekend |
| 9 | Hand-written JSON codecs, `schemaVersion` + `minReaderVersion`, frozen append-only migrations, golden corpus, unknown-field preservation | Generated codecs coupled to class shape | The file format, the product's most durable asset, breaks on every refactor |