# Data Model and File Format

This is the authoritative specification of RackPal's domain model, its on-disk `.rppj` format, and the rules that decide whether a document is coherent. It is derived from [the canonical decision record](canonical-decisions.md) §4 (canonical naming), §5 (canonical data model summary) and §6 (registry), and from the §1.2 and §1.3 rulings on the wiring entity model and validation philosophy. Where any raw working paper in [docs/research/](research/) disagrees with this document, this document wins; where this document disagrees with the canonical decision record, the record wins and this document is defective. Every non-obvious statement below cites the ruling that adjudicated it, so any reader can trace a field back to the argument that put it there.

**Companion documents:** [Overview](00-overview.md) · [Domain](01-domain.md) · [Architecture](03-architecture.md) · [Rack editor](04-rack-editor.md) · [Schematic editor](05-schematic-editor.md) · [Device builder](06-device-builder.md) · [Structure device](07-structure-device.md) · [PDF export](08-pdf-export.md) · [Roadmap](09-roadmap.md) · [Decisions](10-decisions.md) · [Testing and quality](11-testing-and-quality.md) · [Seed catalog](catalog/seed-devices.md)

---

## 1. The shape, in five sentences

1. The document is a **flat set of UUID-keyed entity maps**, never a tree, mutated **only** through undoable `Command`s (CR-083, §5.0).
2. Physical facts live on immutable, versioned `TemplateSnapshot`s embedded in the file; project facts live on `DeviceInstance` (CR-054).
3. Wiring is three layers, `Link` (one physical cable) → `Service` (one signal carried on it) → `Conductor` (one electrical path), with `Net` as the **stored** logical equivalence class hanging off `Service.netId` (CR-008, CR-010, CR-011).
4. **Every persisted number is an integer.** `grep` the persisted model for `double` and find zero hits (CR-001, CR-063, I-1).
5. Validation never blocks the pen: *the gesture may hesitate, the document may not lie* (CR-017).

Five governing principles from the decision record shape almost every field below. They are quoted here because they resolve arguments this document does not re-run:

| # | Principle | Model consequence |
|---|---|---|
| G1 | The schedule is the deliverable; the drawing is the receipt. | `Link` is the entity that must be complete, expressive and printable. Diagram state is secondary. |
| G2 | The document must be able to represent a wrong, incomplete, or found-in-the-field world. | Only model-incoherence is illegal. Unbound endpoints, undetermined signal families and miswired systems are all representable. |
| G3 | A heuristic may never hold a user's deliverable hostage. | No computed number and no drafting convention blocks an export. `blockExportOnErrors` does not exist. |
| G4 | Never fabricate data. Show `unknown`. | `null` means unknown everywhere; rollups report their unknown count. `Extent` is deleted (CR-114). |
| G5 | Cut features, never foundations. | Units, UUIDs, tombstones, `EntityMeta`, fractional indices and the command stack ship in v1 even where their UI does not. |

---

## 2. Entity–relationship overview

```text
RackDocument ─────────────────────────────────────────────────────────────────┐
 │ id, schemaVersion, minReaderVersion, sequence, info, settings              │
 │                                                                            │
 ├─1:N─▶ Location             (tree, arbitrary depth; parentId self-ref)      │
 ├─1:N─▶ Rack                 (└─ ZeroUChannel[] inline)                      │
 ├─0:N─▶ Circuit              (flat; optional rackId)                         │
 │                                                                            │
 ├─1:N─▶ TemplateSnapshot     ◀── IMMUTABLE, content-addressed, refcounted    │
 │        │ key = "$templateId@$version"                                      │
 │        └─ TemplateBody ─┬─1:N─▶ PortDef      (key: PortKey, + renamedFrom) │
 │                         ├─0:N─▶ BankDef      (presentation grouping)       │
 │                         ├─0:N─▶ PortSetDef   (electrical grouping)         │
 │                         └─0:N─▶ PassthroughPairDef                         │
 │                                                                            │
 ├─1:N─▶ DeviceInstance                                                       │
 │        │ templateRef ────────────────▶ TemplateSnapshot                    │
 │        │ designator, name, lifecycleStatus, placement, overrides           │
 │        ├─0:N─▶ Port        (OWNED; lazily materialised; templatePortKey)   │
 │        └─0:1──▶ StructureBody  (iff kind == structure)                     │
 │                  └─1:N─▶ Outlet ──1:N─▶ (Link, via Link.structureOrigin)   │
 │                                                                            │
 ├─1:N─▶ Link                 ◀── ONE PHYSICAL CABLE. one W###. one row.      │
 │        │ designator, linkClass, media, jacket, gauge, lengths, statuses    │
 │        ├─1:N─▶ Service     { signalFamily, netId, conductorRoles[], label }│
 │        ├─1:N─▶ Conductor   { role, from: Endpoint, to: Endpoint, pair, … } │
 │        ├─0:N─▶ Breakout                                                    │
 │        ├─0:N─▶ InlineAdapter                                               │
 │        ├─0:1──▶ StructureOrigin  (home runs only)                          │
 │        └─0:1──▶ pathwayId ─────▶ Pathway                                   │
 │                                                                            │
 ├─1:N─▶ Net                  ◀── STORED. membership = Service.netId (FK)     │
 ├─0:N─▶ Pathway              (conduit / j-hook / tray; containsLineVoltage)  │
 │                                                                            │
 ├─1:N─▶ Sheet                └─1:N─▶ SheetItem  (position, pinned, zOrder)   │
 ├─0:N─▶ Note                                                                 │
 ├─0:N─▶ RevisionEntry                                                        │
 ├─0:N─▶ AckedFinding         ◀── Findings are computed; only acks persist    │
 ├─1:1──▶ Registries  { signalDomains, signalFamilies, connectors, media,     │
 │                      cableSpecs, outletTemplates }                         │
 └─1:1──▶ Tombstones  Map<Uuid, {deletedAt, entityType, by}>                  │
```

### 2.1 Cardinality notes that carry weight

| Relationship | Cardinality | Why it matters |
|---|---|---|
| `DeviceInstance → Port` | 1:N, **never shared** | A patch panel's front and rear jacks are two `Port`s bound by a `PassthroughPairDef`, not one port with two faces (CR-057). |
| `Link → Conductor` | 1:N | A 16/4 speaker cable is **one Link with four Conductors**: one pull-sheet row, one thing a human pulls (RJ-016). |
| `Link → Service` | 1:N | One Cat5e carrying an IR run, a 12 V trigger and RS-232 on separate pairs is one Link with three Services (CR-010, AC-021). |
| `Conductor → Endpoint` | exactly 2 | Each conductor spans two ends; a **Link** may reach N devices via `Breakout`s (CR-014, AC-029). |
| `Service → Net` | N:1, non-null | Membership is the foreign key `Service.netId`, never a name (CR-011). |
| `Outlet → Link` | 1:N, reverse-keyed | Members are Links via `Link.structureOrigin.outletId`. `Outlet` holds no member list (AC-019). |
| `DeviceInstance → TemplateSnapshot` | N:1, immutable | A snapshot is content-addressed, so it can never be a sync conflict and never a dangling edit. Insertion and removal are explicit refcounted child commands (AC-015). |

---

## 3. Primitives, units and precision

### 3.1 The unit regime

Four documents proposed four base length units and one of them contained an arithmetic error. The adjudication (CR-001, CR-002) is binding and the reasoning is worth restating because it is the single most retrofit-hostile decision in the product.

```dart
extension type const Uuid(String v)           { }   // UUIDv7 for entities
extension type const SignalDomainId(String v) { }   // "video.digital"
extension type const SignalFamilyId(String v) { }   // "video.hdmi.2_1"
extension type const ConnectorTypeId(String v){ }   // "conn.hdmi_a"
extension type const MediaTypeId(String v)    { }   // "media.cat6a_futp"
extension type const PortKey(String v)        { }   // "hdmi_out_3" — template-stable
extension type const TemplateId(String v)     { }
extension type const FracIndex(String v)      { }   // LexoRank "a0", "a0V", "a1"

/// int64 NANOMETRES. The load-bearing unit choice. CR-001.
/// 1 in = 25 400 000 nm · 1 U = 44 450 000 nm · 1/32 in = 793 750 nm — all exact.
extension type const Len(int nm) { }

/// int64 MICROGRAMS. 1 lb = 453 592 370 µg exactly. CR-003.
extension type const Mass(int ug) { }

/// Parts per thousand. Power factor, line weight, slack, diversity, waste factor.
extension type const Permille(int v) { }

/// Schematic canvas coordinate. INTEGER grid units, 1 gu = Len(2_500_000). CR-004.
/// No sub-grid. No sx/sy. No free positioning.
final class Pt { final int gx, gy; const Pt(this.gx, this.gy); }

final class Rgb { final int r, g, b, a; }
```

| Quantity | Type | Storage | Ruling | Rejected alternative |
|---|---|---|---|---|
| Length | `Len` | `int64` nanometres | CR-001 | Hundredths-mm: 1/32 in is 79.375 hundredths, not integral. Tenths-mm, 1 U is 444.5 tenths, which loses 2.25 mm across a 45U rack (CR-002). Float mm, unstable JSON round-trip and a lying dirty flag. |
| Mass | `Mass` | `int64` micrograms | CR-003 | `weightKg` / `weightGrams` / `weightLb`. Kilograms and pounds are `UnitFormatter` display formats; neither is stored. |
| Schematic position | `Pt{gx, gy}` | `int` grid units, 1 gu = 2.5 mm | CR-004 | 2.54 mm pitch with 1/64-gu sub-offsets, and `Alt`-free 0.1 mm nudging. Free positioning defeats the exact-integer routing the layout pipeline is built on and lets a user author an unroutable drawing. |
| Rack elevation position | **not stored** | derived from `(Placement, rail geometry, face)` | CR-006 | Persisted `xOffsetTenthMm`. A stored coordinate can diverge from `ruIndex`, the classic "drawing says U7, label says U8" defect. |
| Canvas / PDF boundary | `double` | 1 diagram unit = 1 PDF point = 1/72 in | CR-007 | Hundredths-mm doubles. This is not a breach of the no-floats rule: `DiagramScene` is a transient rendering artifact, never persisted, and the `Len(nm)` → points conversion happens in exactly one function. |
| Percentage / factor | `Permille` | `int` parts per thousand | CR-001 | Floating-point fractions. |
| Scale | `int` / `int` | numerator and denominator | CR-118 | A `double` ratio. Fit-to-page snapped to a standard ratio within 2%, otherwise `NTS`. |
| Rotation | `int` | quarter turns, 0..3 | §3.7 | Arbitrary float angles. Schematics are orthogonal; free rotation costs float geometry throughout the router. |
| Unknown value | `null` | — | CR-114, G4 | `sealed class Extent { Known \| Unknown }`. One mechanism; the obligation moves to the UI, which must **report** its unknown count rather than silently treating null as zero. |

Constants live once, in `rackpal_core/units/`:

```dart
const kRackUnit          = Len(44_450_000);   // 44.45 mm exactly
const kGridUnit          = Len(2_500_000);    // 2.5 mm schematic pitch
const kPinPitch          = 2;                 // gu
const kBtuPerWattHour    = 3.412142;          // CR-005 — derived heat, never stored
const kBankCollapseThreshold = 8;
const kMaxRackHeightU    = 60;                // CR-038
const kSchemaVersion     = 2;
```

Two unit tests are written **before any other code** (AC-001): exact 1/32-in inter-panel clearance, and zero accumulated error across a 45U stack.

### 3.2 Naming rules that bind the field names below

Four rules from CR-045 and §4.0 govern every identifier in this document. They are enforceable, not stylistic.

| # | Rule |
|---|---|
| N1 | One concept, one name: Dart identifier, JSON key, UI label, prose and PDF column header all derive from one glossary entry. |
| N2 | A banned word is banned in prose too. `Connection` is not a synonym for `Link` in a comment (CR-008). |
| N3 | Types `UpperCamelCase`; fields and JSON keys `lowerCamelCase`; registry IDs `lower.dotted.snake`; format tokens `UPPER_SNAKE`; rule IDs `AAA-000`. |
| N4 | Units are in the name or in the type, never in a comment: `weightUg`, `depthNm`, `heightU`, or typed `Len` / `Mass` / `Permille`. A bare `weight` or `length` on a serialized field is a defect. |

---

## 4. Entities

### 4.1 `RackDocument`, `ProjectInfo`, `ProjectSettings`

```dart
final class RackDocument {
  final Uuid id;
  int schemaVersion, minReaderVersion;      // 2, 2
  String appVersion;                        // diagnostics only
  DateTime createdAt, modifiedAt;

  int sequence;                             // strictly monotonic; ++ on EVERY committed
                                            // transaction AND on every undo/redo.
                                            // Persisted. The sync cursor. CR-094.
  int stateId;                              // in-memory only; isDirty == stateId != savedStateId

  ProjectInfo info;
  ProjectSettings settings;

  Map<Uuid, Location>       locations     = {};
  Map<Uuid, Rack>           racks         = {};
  Map<Uuid, DeviceInstance> devices       = {};
  Map<Uuid, Port>           ports         = {};   // MATERIALISED ports only. AC-006.
  Map<Uuid, Net>            nets          = {};
  Map<Uuid, Link>           links         = {};
  Map<Uuid, Pathway>        pathways      = {};
  Map<Uuid, Outlet>         outlets       = {};
  Map<Uuid, StructureBody>  structures    = {};
  Map<Uuid, Circuit>        circuits      = {};
  Map<Uuid, Sheet>          sheets        = {};   // exactly one schematic sheet, always.
                                                  // CR-073, DR-004, AC-037.
  Map<Uuid, Note>           notes         = {};
  Map<Uuid, AckedFinding>   ackedFindings = {};

  Map<String, TemplateSnapshot> templates = {};   // key "$templateId@$version"
  Registries registries;

  List<RevisionEntry>  revisionBlock = [];
  Map<Uuid, Tombstone> tombstones    = {};
  EntityMeta meta;
}
```

| Field | Type | Notes |
|---|---|---|
| `sequence` | `int` | Strictly monotonic, persisted, incremented on every committed transaction **and on every undo/redo**. This is the sync cursor. Never called `revision` (CR-094). |
| `stateId` | `int` | In-memory only, non-monotonic. Drives `isDirty`. Conflating it with `sequence` is what CR-094 resolved. |
| `templates` | `Map<String, TemplateSnapshot>` | The **one** snapshot store. `DeviceInstance.localTemplate` and `PlacedDevice.snapshot` are deleted (CR-054). |
| `ports` | `Map<Uuid, Port>` | Only ports carrying project state are serialized; the rest are key-joined at load (AC-006, §5.4). |
| `tombstones` | `Map<Uuid, Tombstone>` | Ships in v1 even though the history UI does not (G5, CR-095). |

`ProjectInfo` carries the AVIXA D401.01 title-block fields, `projectName`, `projectNumber`, `drawingNumber`, `clientName`, `siteAddress`, `integratorName`, `integratorContact`, `integratorLicense`, `drawnBy`, `checkedBy`, `approvedBy`, plus the front matter the set prints: `scopeNarrative` for the cover (DR-210 §11.209.5) and `legendAbbreviations` / `legendNotes` for `T0.01` (DR-209 §11.208.4), each absent until somebody writes it. All of them are edited in `File ▸ Sheet set…`, as is `logo` (DR-030, DR-217): a `ProjectLogo` with `PlanUnderlay`'s image shape (`imageMember` under `logos/`, `format`, `pixelWidth`, `pixelHeight`, `contentHash`), always a raster, absent for none.

```dart
final class ProjectSettings {
  UnitSystem displayUnits;                 // AUTHORITATIVE over the app preference. CR-097.
  RuNumbering defaultRuNumbering;          // seeds Rack.ruNumbering. CR-026.
  bool defaultMirrorRearElevation;         // seeds Rack.mirrorRearElevation. CR-035.
  SheetNumbering sheetNumbering;           // ncs | simple — DEFAULT simple. CR-066.

  // Format engine. One grammar, one parser, five call sites. CR-045, CR-048.
  IdFormat deviceDesignatorFormat;         // "{TYPE_PREFIX}{SEP}{SEQ}"        → "MTX-1"
  IdFormat portDesignatorFormat;           // "J{PORT_SEQ:2}"                  → "J01"
  IdFormat linkDesignatorFormat;           // "W{SEQ:3}"                       → "W042"
  IdFormat netNameFormat;                  // "N{SEQ:3}"                       → "N012"
  IdFormat outletFieldLabelFormat;         // "{ROOM_ABBR}-{SERVICE}-{SEQ}"    → "LR-TV-1"
  IdFormat outletRackLabelFormat;          // "{FLOOR}{SPACE}-{PANEL}{PORT:2}" → "1A-A12"
  String designatorSeparator;              // "-"; may be empty ⇒ "MTX1"
  int designatorPad;                       // 0; 2 ⇒ "MTX-01"
  CollisionPolicy collisionPolicy;         // suffixLetter | suffixNumber | error
  int designatorBlockSize;                 // reserve blocks for commercial port numbering

  Map<String, RuleOverride> ruleOverrides;           // {severity, reason, by, at}. CR-019.
  Map<SignalFamilyId, Rgb> familyColorOverrides;     // ships in v1. AC-054.
  Map<String, Permille> diversityFactorsByCategory;  // amplifiers 350‰ default. AC-020.
  Permille cableWasteFactor;                         // 100‰ default, footage rollup. AC-024.

  MediaTypeId defaultNetworkMedia;
  int defaultRackHeightU;                  // 12
  int defaultLineVolts;                    // 120 — seeds new Circuits. CR-039.
  WiringStandard? wiringStandard;          // t568a|t568b — THE JOB'S. Null is
                                           // unknown, never an assumed t568b,
                                           // and the key is absent when unset
                                           // (G4, CR-114). DR-180 §11.179.2.
}
```

`blockExportOnErrors` and `greyscaleSafeExport` **do not exist** (CR-022, CR-077). Export options live on a transient `ExportSpec{palette: colour|greyscale|cmyk, issuedForConstruction, paper, preset, maxPages}`, and the screen theme never affects the export.

### 4.2 `Location`, `Rack`, `ZeroUChannel`, `Circuit`

```dart
final class Location {
  final Uuid id;
  Uuid? parentId;                 // arbitrary-depth tree. CR-047.
  LocationKind kind;              // site|building|floor|room|zone|outdoor
  String name;                    // "Master Bedroom"
  String code;                    // "MBR" — feeds {ROOM_ABBR}. CR-046.
  int? floorNumber; String? spaceCode;
  Len? estimatedRunLengthFromRack;   // ONE number per room ⇒ 62 usable estimates. AC-024.
  RunLengthOrigin? estimatedRunLengthOrigin;  // typed | computedFromPlan. Absent
                                  // is UNKNOWN, never "typed" (G4). DR-050 §11.49.3.
  Len? riseAllowance;             // the vertical drop a plan cannot see. DR-020 §11.19.2(1).
  RoomOutline? planOutline;       // this room's shape, drawn on one plan. DR-050 §11.49.
  FracIndex order;
  EntityMeta meta;
}

/// The room's shape as drawn on a plan (DR-050 §11.49, `LEN-A/1`).
///
/// It hangs off `Location` and not off `PlanUnderlay` because it is a fact
/// about the ROOM; the plan is where it was captured, not what it is
/// about. It carries `underlayId` for `PlanPin`'s reason: a document may
/// hold several plans and a bare list of `PxPt` means nothing without the
/// raster it indexes.
///
/// **IMPLICITLY CLOSED.** The first vertex is not repeated at the end: a
/// stored closing point is a second copy of the first, and two copies of a
/// number are two numbers that can disagree.
///
/// **FEWER THAN THREE VERTICES IS HELD AND REPORTED, NOT REFUSED**, on
/// `PlanScale`'s answer to the same question about a calibration whose two
/// points coincide. The decoder must read whatever is on disk (CR-093);
/// `isUsable` says so and `SetRoomOutlineCommand` declines to author one.
final class RoomOutline {
  final Uuid underlayId;
  final List<PxPt> vertices;      // ORDER IS THE SHAPE, compared as a sequence.
  bool get isUsable => vertices.length >= 3;
}

/// Where `Location.estimatedRunLengthFromRack` came from (DR-050 §11.49.3).
///
/// An enum rather than a `bool?`, though both are one nullable field: a
/// `false` would carry either "a person typed it" or "nobody recorded it"
/// while looking identical either way, and those are different answers to
/// the question the field exists to ask.
enum RunLengthOrigin { typed, computedFromPlan }

final class Rack {
  final Uuid id;
  String name, designator;        // "RK-1" — the ONLY rack identifier. CR-040.
  Uuid? locationId;

  int heightU;                    // 1..60, asserted. Advisory above 50. CR-038.
  RuNumbering ruNumbering;        // per-rack; DISPLAY ONLY, never affects ruIndex. CR-026.
  bool mirrorRearElevation;       // per-rack, default true; NOT MIRRORED chip when off. CR-035.

  RackWidthClass widthClass;      // eia19|eia23|tenInch|etsi|customWidth
  Len? customPanelWidth;
  RailType railType;              // tapped10_32|tapped12_24|squareCageNut|roundClearance|m6
  bool fullHoleRail;
  RackFormFactor formFactor;      // floorEnclosure|openFrame4Post|openFrame2Post
                                  // |wallSwingGate|wallPivotCabinet|wallFixed
                                  // |credenzaFurniture|portableCase
  Len? usableDepth;               // NULLABLE — a 2-post frame has none. AC-050/A1.3.
  Len? overallDepth, overallWidth, overallHeight;
  Mass? weightCapacity, ownWeight;

  bool isSwingFrame; HingeSide? hingeSide;
  bool hasFrontDoor, hasRearDoor;
  Len? frontDoorClearance, rearDoorClearance;
  bool groundBarPresent;          // feeds a note on the elevation. AC-034/m21.

  List<ZeroUChannel> zeroUChannels;   // sub-objects, string-keyed, no EntityMeta
  FracIndex order;
  EntityMeta meta;
}

final class Circuit {
  final Uuid id;
  String designator;              // "Panel A / Breaker 14"
  Uuid? rackId;                   // FLAT on the document; the inspector filters. CR-028.
  int breakerAmps, volts;         // volts is AUTHORITATIVE downstream. CR-039.
  int? phase; bool dedicated;
  Uuid? locationId;
  int get continuousLimitAmps => (breakerAmps * 4) ~/ 5;   // PLANNING ESTIMATE, DERIVED
  EntityMeta meta;
}
```

| Decision | Ruling | Rejected alternative |
|---|---|---|
| `Location` is an arbitrary-depth tree with `parentId` | CR-047 | A fixed 4-level site/building/floor/room struct, and a flat list. A tree covers both without a migration. |
| The room abbreviation field is `code` | CR-046 | `abbr`. |
| `Rack.formFactor` gates `RCK-004`, `RCK-007` and `RCK-008` | AC-034/m19, m20 | An ungated heuristic. A 12U wall box in a closet has no spare U by design; a sealed enclosure wants blanks, not vents. |
| `usableDepth` is nullable | AC-050/A1.3 | A required depth. Depth rules **skip** rather than fabricate for 2-post frames (G4). |
| `Circuit` is flat on the document, with an optional `rackId` | CR-028 | `List<Circuit>` on `Rack`. A branch circuit routinely feeds more than one rack. |
| `Rack.lineVoltage` is deleted | CR-039 | Three sources of truth for voltage. `Circuit.volts` is authoritative. |
| `continuousLimitAmps` is derived, never stored, and is a **planning estimate rather than an NEC load calculation** (DR-079 §11.78.4) | CR-048/I-48, DR-079 | A stored 80% figure that drifts out of sync with the breaker rating; and a citation that reads as though the arithmetic were the code rule. 80% is the continuous-load allowance: there are no demand factors, nothing classifies a load as continuous, and `PWR-001` sums a third quantity again (typical × diversity, in VA). |

Circuit membership itself is **derived** by walking power Links (device inlet → PDU outlet → PDU inlet → circuit). `Port.circuitId` survives only where the rack meets the building, PDU and UPS inlets and hardwired devices (CR-028).

### 4.3 `Placement`: a sealed union of five variants

```dart
sealed class Placement { }   // elevation X/Y is NEVER stored — it is derived. CR-006.

final class RailPlacement extends Placement {
  final Uuid rackId;
  final int  ruIndex;             // 1-BASED, BOTTOM ORIGIN, ALWAYS. CR-025.
  final Face face;                // front | rear
  final int  startTwelfth;        // 0..11 — v1 UI exposes Full(0,12)/Left(0,6)/Right(6,6)
  final int  spanTwelfths;        // 1..12 — free lateral drag is v1.2. CR-030.
  final Len? depthOffsetFromFront;
  final ChassisRotation chassisRotation;   // normal | reversed. AC-023.
  final bool locked;
}
final class ShelfPlacement extends Placement {
  final Uuid hostDeviceId;        // CHILD → PARENT only. The parent never owns a list. CR-029.
  final FracIndex order;          // auto-pack left→right in v1. AC-043.
  final Len? lateralOffset;       // stays in the format; the UI defers.
  final bool locked;
}
final class ZeroUPlacement extends Placement {
  final Uuid rackId; final String channelId;
  final Len offsetFromChannelStart; final Orientation orientation;
  final bool locked;              // inspector-edited in v1; no drag gesture. AC-044.
}
final class OffRackPlacement extends Placement {
  final Uuid? locationId; final String? mountNote;
}
final class StagedPlacement extends Placement {          // IS the Staging Bin. CR-032.
  final Uuid? lastRackId; final int? lastRuIndex; final Face? lastFace;
  final Pt? schematicHint;        // consumed ONCE when the first SheetItem is created. CR-069.
}
```

| Decision | Ruling | Rejected alternative |
|---|---|---|
| `ruIndex` is 1-based, bottom origin, always | CR-025 | `bottomU`, 0-based. The off-by-one is the defect most likely to reach a printed drawing: a device at `ruIndex: 7` and one at `bottomU: 7` are in different rack positions. |
| `ruNumbering` is display-only and per-rack | CR-026 | A project-wide setting that alters stored values. Top-down racks exist next to bottom-up racks in the same job. |
| Lateral position is `startTwelfth`/`spanTwelfths` | CR-030 | `xOffset` in length units. Twelfths express half-rack, third-rack and quarter-rack shelves exactly; the v1 UI exposes only Full/Left/Right. |
| Containment points child → parent | CR-029 | A `hostedDeviceIds` list on the shelf. One direction means one place to be wrong, and it makes a shelf move O(1). |
| The Staging Bin is `StagedPlacement`, not an entity | CR-032 | A separate unplaced-devices collection. The bin is a **query**. |
| `chassisRotation` exists | AC-023/M8 | No rotation. Mounting a device backwards in a credenza rack is standard practice; port face resolves as `templateFace XOR reversed`. |
| `locked` on every variant | CR-034 | An unmodelled lock. Never called `pinned`, that word belongs to `SheetItem` (CR-068). |

### 4.4 The template layer

```dart
final class TemplateSnapshot {
  final TemplateId templateId; final int version;   // monotonic int, NOT semver. CR-050.
  final String contentHash;     // sha256; mismatch = warning + badge, never a load
                                // failure. AC-042.
  final TemplateBody body; final DateTime capturedAt;
}

final class TemplateRef {
  final TemplateId templateId; final int version; final String contentHash;
}

final class TemplateBody {
  String manufacturer, model, displayName, description, category;
  String? typePrefix;                     // "MTX" — seeds the designator format
  List<String> tags;

  // Occupancy — a struct, never a scalar. CR-036.
  int frontU, rearU;
  OccupancySide side;                     // front|rear|both|zeroUVertical|none
  MountMethod mountMethod;                // rackEars|shelf|zeroU|sideMount|rearRail
                                          // |furniture|hosted|notInRack
  List<MountMethod> alternateMountMethods;
  WidthClass widthClass; int nominalSpanTwelfths; Len? customPanelWidth;

  Len? bodyDepth;                         // null means unknown, never estimated. G4, CR-114.
  Len? connectorProjection;               // DERIVED from the deepest rear connector,
                                          // not bodyDepth + 75 mm. AC-022/M7.
  Len chassisWidth;                       // default 432 mm for full width — NOT 482.6. AC-032.
  Mass? weight;                           // null means unknown, never estimated. G4, CR-114.
  Mass? maxUnsupportedMass;               // default ~7 kg for rackEars. Feeds RCK-013. AC-028.

  int requiresClearanceAboveU, requiresClearanceBelowU;
  ThermalClass thermalClass;

  bool isContainer; Mass? containerWeightCapacity;
  Len? containerUsableDepth, containerUsableWidth; bool containerVented;

  bool isPassthrough;
  List<PassthroughPairDef> passthroughPairs;   // now in .rpdx. CR-057.

  PowerProfile power;
  List<PortDef>    ports;
  List<BankDef>    banks;                 // PRESENTATION grouping. CR-055.
  List<PortSetDef> portSets;              // ELECTRICAL grouping. CR-055.

  Rgb? accentColor;
  List<PanelGraphic> panelGraphics;
}                                          // no frontImage / rearImage in v1. AC-057.

final class PowerProfile {
  int? nameplateWatts;                    // UL thermal rating; ADVISORY second line only
  int? typicalWatts;                      // the number circuit loading uses.
                                          // NEVER auto-derived from nameplate. AC-039.
  int? standbyWatts, nominalVolts;
  int? apparentVA;                        // circuit loading is computed in VA. CR-056, AC-020.
  int? powerFactor;                       // permille. 650 for a linear-supply amp.
  bool isContinuousLoad;
  // outletsProvided, outletsConsumed: NOT STORED. Derived from ports and cords. DR-171.
  PlugType? inletPlug;
  int? poeBudgetWatts;                    // now declared. NET-001 depends on it. CR-056.
  int? btuPerHourOverride;                // else typicalWatts × kBtuPerWattHour. CR-005.
}

final class PortDef {
  final PortKey key;                      // STABLE, author-assigned. THE migration join. CR-051.
  final List<PortKey> renamedFrom;        // what a UUID cannot express
  String label; String? designatorHint;

  ConnectorTypeId connector;              // ORTHOGONAL AXES. Never one enum.
  SignalFamilyId  signalFamily;           // `carriedProtocols` was a third
  List<SignalFamilyId> acceptedFamilies;  // until DR-134 deleted it.

  PortDirection direction;                // source|sink|bidirectional|busNode|passive. CR-060.
  ReturnChannel? returnChannel;           // ARC / eARC
  PortTopology topology; int maxConnections;

  Gender gender;                          // male|female|genderless ONLY. CR-059.
  Face face; PanelPosition position;
  String? pinoutVariant;                  // the IR emitter/receiver hazard. Must be cited. AC-052.
  List<String>? terminalRoles;            // terminal-block order, pin 1 first ('TX RX G'). Absent = unknown. DR-221.
  int? conductorCount;

  int? impedanceOhms; AudioLevel? level; bool? balanced, phantomPowerCapable;
  Polarity? polarity;                     // on the TERMINAL, so a typo is inexpressible. AC-030.
  int? nominalVoltage, maxCurrentMa;

  String? bankKey;                        // → BankDef       (presentation)
  String? setKey, setRole; int? channelIndex;   // → PortSetDef (electrical)

  PoeSpec? poe; int? linkSpeedMbps; SfpFormFactor? sfp;
  FiberMode? fiberMode; int? wavelengthNm;
  BusCapability? bus; SerialSpec? serial; PortPowerSpec? power;

  FracIndex order; String? notes;
}

final class BankDef {                     // PRESENTATION. Drives symbol edges, brackets,
  final String key;                       // collapse, and auto rear-panel layout. CR-055.
  String label, abbr;
  SymbolSide symbolSide;                  // left|right|top|bottom
  bool collapseInSymbol;                  // collapses above kBankCollapseThreshold (8)
  FracIndex order;
}

final class PortSetDef {                  // ELECTRICAL. Y/Pb/Pr, L/R, +/−. CR-055.
  final String key;
  String label;
  SetKind kind;                           // componentVideo|stereoPair|speakerPair|balancedPair
  bool atomicConnect;                     // one gesture connects the whole set
}

final class PassthroughPairDef {          // patch panels. CR-057.
  final PortKey frontKey, rearKey;
  final bool sameNet;
}
```

| Decision | Ruling | Rejected alternative |
|---|---|---|
| Template version is a monotonic `int` | CR-050 | Semver. A monotonic integer plus `contentHash` answers every question v1 asks; semver implies a compatibility classifier that AC-041 cut. |
| `PortDef.key` + `renamedFrom` is the migration join | CR-051 | A `portId` UUID. A UUID cannot express "this port was renamed"; a key can, and a rename must not rewire the project. |
| Occupancy is a struct on `TemplateBody`; depth and weight stay siblings | CR-036 | Folding depth and weight into an `Occupancy` object, which implies they vary with mounting. They do not. |
| Banks and port sets are two entities | CR-055 | One `PortGroupDef`. A symbol-edge grouping and an electrical grouping are different concepts that collided on one name. |
| `chassisWidth` defaults to 432 mm | AC-032/m15 | Flowing rear-panel connectors across 482.6 mm; that is the panel width including ears, and connectors live on the chassis. |
| `connectorProjection` derives from the deepest rear connector | AC-022/M7 | `bodyDepth + 75 mm`. A molded HDMI plug with a bend is 100–125 mm; a Cat6a boot is ~50 mm. |
| `typicalWatts` never defaults to a fraction of nameplate | AC-039, RJ-007, G4 | A silent 50%-of-nameplate estimate. Fabricated data the user cannot see is worse than missing data they can. |
| `apparentVA` and `powerFactor` exist | CR-056, AC-020 | `amps = watts / 120`. A linear-supply amplifier at PF 0.65 under-reports current by 35% on exactly the gear where it matters. |
| `bodyDepth` and `weight` are **nullable** | CR-114, AC-039, G4 | Non-nullable `Len bodyDepth` / `Mass weight`, which force a fabricated zero or a silent estimate on every template whose figure is uncited, and the AC-052 provenance gate guarantees many will be. `null` means unknown, everywhere; rollups report their unknown count. Canon §5.6's non-nullable declaration is superseded by the stronger and more recent CR-114/G4/AC-039 rulings. |
| No `frontImage` / `rearImage` | AC-057 | Bitmap panel art in v1. `panelGraphics` (vector) covers the legible cases. |

**What nullable depth and mass oblige downstream.** The rack rollup is `rackWeight = Σ device.weight where weight != null` with `unknownCount = count(device.weight == null)`, and the chip strip reads *"Total weight 148 lb · 3 devices have no weight"*. Depth is the same shape. The depth-interval check `RCK-012` **skips** when either `bodyDepth` or `Rack.usableDepth` is null, exactly as it already skips for a 2-post frame (AC-050/A1.3), a skipped check is honest; a check run against a fabricated zero is not. On the wire, `weightUg` and `bodyDepthNm` are **omitted from JSON when null**, an absent key reads as null, and the codec never writes an explicit `null` for either; §6.2's matrix template carries `weightUg` while the generic patch panel omits it entirely. `Len chassisWidth`, `int frontU` and `int rearU` stay **non-nullable**: a device with no width or no RU height cannot be placed, so unknown is not a representable state there.

### 4.5 `DeviceInstance`, `Port`, overrides

```dart
final class DeviceInstance {
  final Uuid id;
  DeviceKind kind;                        // rackDevice|shelf|structure|offRackPassive
                                          // |virtual|blankPanel|ventPanel|pdu|ups
  TemplateRef templateRef;                // ALWAYS resolves to an embedded snapshot. CR-054.
  String designator, name;                // "MTX-1" — unique project-wide
  bool designatorLocked;                  // CR-034
  LifecycleStatus lifecycleStatus;        // existing|new|future|removed|designIntent.
                                          // CR-064, CR-065, AC-018.
  Placement placement;
  Uuid? locationId;
  String? serialNumber, assetTag, macAddressPrimary, firmwareVersion;
                                          // macAddressPrimary is THE device MAC (DR-226)
  DateTime? installedAt;
  NetworkConfig? network;                 // the MANAGEMENT address, absent when null.
                                          // Its mac is unused here. DR-048, DR-226.
  DeviceOverrides overrides;              // TYPED, nullable fields. CR-053, AC-012.
  int designatorWatermark;                // reserve allocation. AC-006.
  Uuid? structureBodyId;
  String? notes; Rgb? colorOverride;
  EntityMeta meta;
}                                          // no localTemplate, no zOrder, no cost/supplier.

final class Port {
  final Uuid id;                          // uuidv5(deviceId, portKey) when template-derived
  final Uuid deviceId;
  final PortKey? templatePortKey;         // null for instance-added ports
  PortOverrides overrides;                // typed. Lives HERE, not in a device map. CR-053.
  String? userLabel; String designator;   // "J01" — unique within the device. CR-042.
  bool orphaned, reserved;
  NetworkConfig? network;
  int? busAddress, busUniverse; bool? isBusTerminator;
  int? tapWatts;                          // 70/100 V transformer tap — per INSTALLATION
  Uuid? circuitId;                        // only where the rack meets the building
  PoeAssignment? poeActual;
  String? notes;
  Map<String, Object?> unknown;
}                                          // NO EntityMeta. CR-095.
```

**`LifecycleStatus` is one enum of five values (`existing`, `new`, `future`, `removed`, `designIntent`) and it is the same enum on `DeviceInstance` and on `Link`** (CR-064, canon §4.2). `designIntent` arises almost always on a `Link`, a run scheduled to a device that does not exist yet (AC-018), but a `DeviceInstance` placed to reserve RU for gear not yet selected is a legitimate `designIntent` device. One enum, five values, both entities; it is not split in two.

**Lazy port materialisation (AC-006).** A `Port` is serialized **only if it carries project state**: a conductor endpoint, an override, a pinned designator, network config, a bus address, a tap wattage, or a reserve/orphan flag. Everything else is reconstructed at load by key-joining `TemplateBody.ports` against the device. Typical files drop ~70%. This is what keeps plain pretty-printed JSON defensible at the design's own 2,000-port target.

For that to survive the cloud-ready decision, template-derived port IDs must be **deterministic**: `Port.id == uuidv5(deviceId, portKey)`. Two machines that independently connect the same port produce the same ID, so materialisation is idempotent across peers (AC-006). Instance-added ports get a random UUIDv7 and a null `templatePortKey`.

Reserve allocation is `DeviceInstance.designatorWatermark`, not thousands of placeholder entities.

**Overrides are typed classes with nullable fields** (CR-053, AC-012); `null` *is* the sparse "not overridden" semantics. The rejected alternative, dotted-path string maps into `TemplateBody`, was self-defeating: it rejected a typed class for requiring lockstep maintenance with `TemplateBody`, then proposed a hand-maintained `pathType(String)` table with the identical lockstep requirement, minus the compiler check, plus a runtime validation pass. Port overrides live **on the `Port`**, never in a device-keyed map, which would re-introduce the composite-key identity the model bans.

**Template binding is copy-on-place in v1** (AC-041). `templateRef{templateId, version, contentHash}` is recorded and the snapshot is embedded, so nothing about the format changes when the Update Manager lands in v1.2. Migration joins on `PortKey` (plus `renamedFrom`); a removed port that still carries conductors is **orphaned, never deleted** (CR-052). The manager offers `[ Remap ▾ ]` and `[ Keep as orphan ]`. **There is no `[ Del ]`.**

The three doors (CR-054), replacing four verbs and three snapshot stores:

| Door | Effect |
|---|---|
| Edit this device only | writes `DeviceOverrides`; the template is untouched |
| Edit the template | forks `version + 1` in the library; placed instances untouched until opted in |
| Fork to a new template | new `templateId` seeded from snapshot + overrides; this instance rebinds, overrides clear, `derivedFrom` recorded |

The rejected fourth verb ("Detach instance", `templateRef → null`) produced a device with no lineage; door 3 covers the case with better provenance.

### 4.6 Wiring: `Link`, `Service`, `Conductor`, `Endpoint`, `Net`, `Pathway`

This is the part of the model the product is for. G1: the schedule is the deliverable.

```dart
final class Link {                        // ONE PHYSICAL CABLE. One W###. One schedule row.
  final Uuid id;
  String designator;                      // "W042"
  bool designatorLocked;                  // auto-set at roughInStatus >= pulled. AC-034/m22.
  LinkClass linkClass;                    // fieldCable|jumper|powerCord|internal — auto-
                                          // classified, user-overridable. AC-026.

  List<Service>   services;               // 1..N. CR-010, AC-021.
  List<Conductor> conductors;             // 1..N. One 16/4 = one Link, four Conductors. RJ-016.
  List<Breakout>  breakouts;              // fan-outs; a Link may reach N devices. CR-014.
  List<InlineAdapter> inlineAdapters;     // PASSIVE only; two-cable devices are DeviceInstances

  MediaTypeId media; String? cableSpecId;
  int? gaugeAwg; JacketRating? jacket; bool shielded, plenum;

  // JACKET COLOUR — TWO FACTS, NEVER COLLAPSED. Both key into
  // ProjectSettings.jacketColorConventions; neither is ever a bare Rgb.
  JacketColorId? jacketColorId;        // WHAT THE RUN IS — the convention
                                       // entry it follows. Drives the KEYSTONE.
  JacketColorId? jacketColorPulledId;  // WHAT WAS ACTUALLY PULLED, set only
                                       // when it differs. NULL IS NORMAL.
                                       // NEVER drives the keystone.
  // Derived, never stored: derived/jacket_color_resolution.dart answers
  // "as-built colour", "is this an exception" and "keystone colour" (CR-107).
  // Neither ever reaches a drawn wire's hue (CR-078/PAL-1).

  Len? routedLength, cutLength, terminatedLength;   // three fields, three columns. AC-024.
  Permille? slack;
  Uuid? pathwayId;                        // → Pathway
  CrossoverKind? crossover;               // straight|nullModem|fiberPolarityAB|polarityReversed (DR-231)
  WiringStandard? wiringStandard;         // t568a|t568b — THIS CABLE'S, when it
                                          // differs from the job's. Null means
                                          // "whatever the project says", the
                                          // ordinary case: one entry per job
                                          // replaces one per drop. Shown only
                                          // on a four-pair or RJ45 cable, and a
                                          // value differing from the project's
                                          // is what turns T5.01 on. DR-180.

  LifecycleStatus lifecycleStatus;        // existing|new|future|removed|designIntent — the
                                          // same five values. CR-064, CR-065, AC-018.
  RoughInStatus roughInStatus;            // planned|pulled|dressed|terminated|tested
  TestResult? test;                       // pass/fail + headroom + certificate id. RJ-004.
  String? installedBy; DateTime? terminatedAt;

  StructureOrigin? structureOrigin;       // home runs. AC-019.
  String? notes; FracIndex order;
  EntityMeta meta;
}                                          // no netId, no waypoints, no autoRoute. CR-012.

final class Service {                     // ONE SIGNAL carried on the cable
  final String id;
  SignalFamilyId signalFamily;
  Uuid netId;                             // NON-NULL. Implicit singleton net if unassigned.
  List<String> conductorRoles;            // which conductors carry it — "pr 3", "pr 1–2"
  String? label;
}

final class Conductor {
  final String role;                      // "" | "Y" | "Pb" | "Pr" | "L+" | "L−" | "+" | "−"
  final Endpoint from, to;                // EXACTLY two ends. CR-014.
  final int? pairNumber;
  final String? colorCode;                // "blue/white" — PRINTS on the termination schedule.
                                          // THE PAIR COLOUR INSIDE THE SHEATH, and nothing
                                          // else. This document's own worked example stored
                                          // "T568B" here until DR-180 §11.179, which is one
                                          // field asked to hold two facts; the wiring standard
                                          // is now Link.wiringStandard and the example says
                                          // "blue/white". The exporter never re-reads a stored
                                          // colour to decide it means a standard (G4).
}

sealed class Endpoint { }                                        // AC-018
final class PortEndpoint  extends Endpoint { final Uuid portId; }
final class PlaceEndpoint extends Endpoint {
  final Uuid? locationId; final String description;
  final TerminationType? intendedTermination; final Len? serviceLoop;
}
final class OpenEndpoint  extends Endpoint { final String description; }

final class Breakout      { String label; Permille atLengthFraction; }
final class InlineAdapter { ConnectorTypeId fromConnector, toConnector;
                            String? model; List<String> satisfiesRuleIds; }

final class Net {                         // STORED. Membership is Service.netId. CR-011.
  final Uuid id;
  String name;                            // generated, editable, NEVER load-bearing. CR-049.
  String? designator;                     // "N012"
  SignalFamilyId signalFamily;
  NetTopologyKind topology;               // p2p|star|daisyChain|passiveSplit|bus
  Rgb? colorOverride;
  bool isImplicit;                        // auto singleton for a lone P2P service
  Uuid? busTerminatorPortIdA, busTerminatorPortIdB;
  int? busUniverse, nominalVoltage;
  String? notes;
  EntityMeta meta;
}

final class Pathway {                     // conduit / j-hook / tray / trunk. CR-016, AC-027.
  final Uuid id;
  String name;                            // "B03"
  PathwayKind kind;                       // conduit|jhook|tray|plenumSpace|riser
                                          // |directBury|exterior
  bool containsLineVoltage;               // CODE-001 depends on it
  Uuid? fromLocationId, toLocationId;
  Len? nominalLength; MediaTypeId? pathwayMedia;   // isPathwayOnly media. CR-109.
  String? notes; FracIndex order;
  EntityMeta meta;
}
```

| Decision | Ruling | Rejected alternative |
|---|---|---|
| The entity is `Link`; the word `Connection` is **banned** | CR-008 | `Connection`, `PhysicalLink`, `LogicalSignal`, `CableType`. Four documents used four names for three different concepts; conflating them is the most expensive mistake available in this domain. |
| A `Link` carries `List<Service>` | CR-010, AC-021 | One signal family per cable. One Cat5e routinely carries an IR run, a 12 V trigger and RS-232 on separate pairs, three Links on one physical cable means three pull rows, three lengths to keep in sync, and a `TOP-002` fight over the designator. |
| `signalFamily` lives on `Service`, not `Link` | CR-009 | `Link.signalFamily`. `Link.dominantSignalFamily` is **derived** and used only for line colour; it is never serialized (CR-115). |
| `Net` is stored | CR-011 | Derived-only nets (union-find at read time), and name-carried membership. A derived structure cannot carry the user's net name, colour override, notes, universe number or terminator assignment, and cannot be a sync conflict unit. Name-carried membership is the KiCad typo failure. Union-find is used only to **propose** merges, which a command then applies. |
| Two layers, 2-ended `Link` above N-endpoint `Net` | CR-008, §3.6 | A pure edge list (no bus semantics, no cascade budget, no trunk to draw) and a pure hypergraph (destroys the pull sheet, a 6-endpoint net does not tell an installer what to pull). |
| An `Endpoint` is a sealed union | AC-018/B1 | Both ends must resolve to live ports. That made it impossible to schedule a run to a device that does not exist yet, which is the state of every job in February when drywall goes up in three weeks. An unbound endpoint **schedules, prints, gets a `W` number and gets a label**; `BindEndpoint` later preserves the ID, the length, the jacket and the test result. |
| Each **Conductor** spans exactly two ends; a **Link** may reach N devices | CR-014, AC-029 | "A link spanning three devices is corrupt." A dual-head IR emitter is one cable, one part number, one pull, three devices. |
| Passive adapters are values; two-cable adapters are devices | CR-015 | Either extreme. The test is mechanical: *does an installer pull two separate cables to it?* If yes it is a `DeviceInstance` with `mountMethod: notInRack`. |
| `linkClass` exists and the schedule excludes jumpers by default | AC-026/B5 | Every patch cord as a schedule row. A 180-row schedule where 110 rows are factory cords out of a bag is a schedule nobody reads past row 20. |
| Three length fields | AC-024/M9 | One `calculatedLength`. The pull sheet wants cut length; the as-built wants terminated length; the takeoff wants routed length. |
| `Pathway` is a first-class entity | CR-016, AC-027/M13 | An opaque `conduitId` string. `CODE-001` (Class 2/3 conductor sharing a pathway with line voltage) and `CODE-002` (non-plenum jacket in a plenum space) are two of the few checks that protect the user from an actual code citation, and both need `containsLineVoltage` and `kind`. |
| **No route geometry is persisted** | CR-012 | `waypointsBySheet`, `routeOverrides`, `RouteWaypoint`. Symbol placement is user intent and is stored (`SheetItem`); wire geometry is a pure deterministic function of the model. Manual rerouting returns in **v1.1** as **constraints** (ordered grid points the router must pass through, in `routeConstraintsBySheet`) never as a polyline (canon §7.3, ADR-008). |

`Net` is auto-created as an implicit singleton for every new link (`isImplicit: true`, unnamed). It becomes explicit, gaining a name and an `N###` designator, the moment a second service joins it or the user names it. The common case stays free of ceremony.

How the hard cases land:

| Reality | Model |
|---|---|
| 16/4 speaker cable, stereo pair to one location | 1 Link, 4 Conductors (`L+`,`L−`,`R+`,`R−`). One row, one length, one pull. |
| Cat5e to a TV carrying IR + 12 V trigger + RS-232 | 1 Link, 3 Services, conductors assigned by `Service.conductorRoles`. |
| Component video (3× RCA sold as one cable) | 1 Link, 3 Conductors (`Y`,`Pb`,`Pr`). A `PortSetDef` with `atomicConnect` connects all three in one gesture. |
| RG6 splitter feeding 4 drops | The splitter is a real `DeviceInstance` (`offRackPassive`, `notInRack`). 5 Links, 1 Net. |
| 70 V speaker line, 6 speakers daisy-chained | 6 Links, 1 Net (`topology: daisyChain`, `nominalVoltage: 70`). Each speaker's `Port.tapWatts` is per-installation. |
| Dual-head IR emitter | 1 Link, 2 Conductors, 1 `Breakout`, 3 devices. |
| Patch panel front ↔ rear | `PassthroughPairDef{sameNet: true}`. The netlist collapses the two-hop; both physical links remain schedulable. |
| Cat6 pulled to "the projector shelf, beam 3" in February | 1 Link, `PortEndpoint` at the rack end, `PlaceEndpoint` at the field end, `lifecycleStatus: designIntent`. Prints, schedules, gets a W number. |
| Coil left in a J-hook forever | 1 Link with an `OpenEndpoint`. `LNK-020` counts them as an advisory checklist. |
| Existing miswired system being documented | Every finding acknowledged with a reason. The DRC list becomes the remediation scope, a deliverable in itself (G2). |

### 4.7 The Structure device: `StructureBody`, `Outlet`, `StructureOrigin`

The Structure device represents the structured wiring entering the rack, requirement 6 of the brief. It is a `DeviceInstance` with `kind == structure`, `frontU: 0`, `rearU: 0`, `mountMethod: notInRack`, `placement: OffRackPlacement`. It maps to the TIA-570-D **Distribution Device** and renders in the schematic as an edge bank of off-page-connector flags (J-STD-710); it renders in the rack elevation not at all. See [Structure device](07-structure-device.md) for the editor.

```dart
final class StructureBody {
  final Uuid id;
  final Uuid deviceId;                    // the DeviceInstance with kind == structure
  String title;                           // "Rough-In — First Floor"
  StructureRole role;                     // homeRunField|serviceEntrance|interRackTie
                                          // |temporaryFeed
  Uuid? distributionDeviceLocationId;     // the SMC / can / MDF location
  String? enclosureModel;                 // "Generic 42 in structured media enclosure"
  SheetEdge sheetEdge;                    // left | right, default left. CR-072.
  EntityMeta meta;
}                                          // NO bundleIds list — Outlets key back. CR-016.

final class Outlet {                      // ONE WALL PLATE / ONE CEILING LOCATION. CR-016.
  final Uuid id; final Uuid structureBodyId;
  String designation;                     // the outlet's own field designation
  Uuid? locationId;
  Wall? wall; MountSurface? mountSurface;  // wall|ceiling|floor|soffit|exterior|inGround. m24.
  Len? mountHeightAff; int? floorNumber;
  String? outletTemplateId;               // what created it. CR-108.
  String? tia570Grade;                    // a standards TAG, not an axis. CR-108.
  Uuid? pathwayId; Len? nominalRunLength;
  String? notes; FracIndex order;
  EntityMeta meta;
}                                          // members are Links, via Link.structureOrigin.outletId

final class StructureOrigin {             // ON THE LINK. AC-019. Not an entity.
  final Uuid structureBodyId, outletId;
  String fieldLabel;                      // "LR-TV-1A" — on the wall plate. REQUIRED, unique
                                          // project-wide across ALL Structure bodies. CR-113.
  String? rackLabel;                      // "1A-A12" — at the panel. Unique when set.
  Wall? wall; MountSurface? mountSurface;
  Len? mountHeightAff;
  TerminationType terminationField;       // keystone|punchdown|fBarrel|euroblock
                                          // |unterminated|fieldConnector
}

final class OutletTemplate {              // first-class recipe. CR-108.
  final String id; String name;
  List<OutletDrop> drops;                 // {media, service, count}
}
```

| Decision | Ruling | Rejected alternative |
|---|---|---|
| `StructureDrop` is **deleted**; a home run *is* a `Link` with a `StructureOrigin` | CR-107, AC-019/B2 | Drop and Link as two entities each carrying media, jacket, gauge, length, status and test result. That divergence is guaranteed within one week of real use: the drop schedule says 78 ft and the wiring schedule says 90 ft, and nobody knows which to bill against. One cable, one row, one length, one certificate, one status. |
| `Outlet` (renamed from `StructureBundle`) is the creation/specification/pricing atom | CR-016, RJ-011 | Making it a bare grouping over Links. The three-level Body → Outlet → run hierarchy maps exactly onto how the work is specified, priced, pulled and tested. |
| `Outlet` holds no member list | AC-019 | `dropIds: List<Uuid>`. Members key back via `Link.structureOrigin.outletId`, so there is one source of truth for membership. |
| Outlet templates are first-class; TIA-570-D grades are a standards **tag**, not an axis | CR-108, m23; confirmed by DR-002 | `StructureGrade{grade1, grade2, grade3, custom}` as the primary axis. Essentially no CI integrator speaks in grades; they say "two Cat6 and two RG6 to every TV". |
| Both labels, both printed | CR-044, AC-047 | One label. The most common on-site failure is a schedule carrying one label when the technician needs the other. `fieldLabel` is required and project-unique; `rackLabel` is unique when set. |
| Conduit is `isPathwayOnly` media creating a `Pathway`, not a Link | CR-109 | A conduit "drop" with a connectable port. An empty conduit is not a cable and cannot be connected to anything, but you still pull the smurf tube and it still costs money, so it appears in the drop table and on the pull sheet. |
| `Outlet.roughInStatus` is derived as the **minimum** across member Links | CR-111, CR-115 | Derived-max, and persisting it. A max would report an outlet "tested" when three of its four cables are still coiled. Not serialized. |
| Multiple Structure bodies are supported | CR-113 | One per project. Media panel, exterior/cameras and service entrance are different bodies; `sheetEdge` routes each to layer 0 or layer N. |
| Removed from the rack palette | CR-110 | A palette entry that cannot be placed. A body is created from `Project ▸ Structured wiring…`, or implicitly on first use of the Structure editor. |
| The location tree is a **top-level surface**, today the `Site` view | CR-112; renamed by DR-168 | The location tree owned by the Structure editor. A project with racks and no Structure device must still be able to say which room a rack is in. |

A drop's signal family may legitimately be `structure.undetermined` at rough-in, at rough-in a Cat6 is just a Cat6. The Link assigns a family later and the DRC re-validates retroactively. That state being first-class is a genuine differentiator; no competitor models it.

### 4.8 `Sheet`, `SheetItem`, `Note`, `AckedFinding`, `Tombstone`, `EntityMeta`

```dart
final class Sheet {
  final Uuid id;
  String number;                          // "T2.01" (ncs) or "2" (simple). CR-066.
  String title;
  SheetKind kind;                         // cover|legend|exceptions|elevationFront
                                          // |elevationRear|schematic|wiringSchedule
                                          // |dropSchedule|equipmentList|networkSchedule
                                          // |powerSchedule|pullSheet
  PaperSize paper; Orientation orientation;
  int scaleNumerator, scaleDenominator;   // 0/0 ⇒ NTS. Fit-to-page, snapped within 2%. CR-118.
  bool carriesLegend;                     // legendLocationNote is AUTO-FILLED at export. CR-023.
  List<Uuid> includedRackIds, includedDeviceIds;
  Set<SignalDomainId> domainFilter;
  Set<LifecycleStatus> lifecycleFilter;   // the useful half of layers. CR-067.
  Map<Uuid, SheetItem> items;
  FracIndex order;
  EntityMeta meta;
}

final class SheetItem {
  final Uuid id, targetId;
  Pt position;                            // THE only symbol position. CR-069.
  int rotationQuarterTurns;               // 0..3 — no float angles
  bool collapsed;
  bool pinned;                            // any manual move sets it; auto-layout never moves
                                          // a pinned symbol. CR-068.
  FracIndex zOrder;                       // THE only stacking order
  Map<String, Object?> unknown;
}

final class AckedFinding {
  final Uuid id; final String ruleId;
  final String targetFingerprint;         // "*" ⇒ project-wide mute (reason REQUIRED)
  final Uuid? targetEntityId;
  String reason;                          // optional for a single instance. RJ-006.
  String by; DateTime at; Severity demotedTo;
  EntityMeta meta;
}

final class RuleOverride { Severity severity; String reason; String by; DateTime at; }
final class Tombstone    { DateTime deletedAt; String entityType; String by; }

final class EntityMeta {                  // CONFLICT UNITS ONLY. CR-095.
  DateTime createdAt, updatedAt;          // UTC, microsecond
  String   updatedBy;
  int      localRevision;
  Map<String, Object?> unknown = {};      // forward-compat: preserve and re-emit
}
```

| Decision | Ruling | Rejected alternative |
|---|---|---|
| Exactly one schematic `Sheet`; the **exporter** partitions by domain | CR-073, AC-010, DR-004 | A full multi-sheet subsystem on the critical path to the first PDF. A domain partition has zero cross-sheet connections by construction, so no off-sheet connector pairs and no min-cut are needed. |
| `Sheet.kind`, not `viewKind` | CR-075 | Two spellings of the same field. |
| `SheetItem` is the only symbol position and the only z-order | CR-069 | Three candidate homes for a symbol position. `StagedPlacement.schematicHint` is consumed **once**, when the first `SheetItem` is created. |
| `pinned` on `SheetItem` | CR-068 | Unmodelled pinning. Any manual move sets it; auto-layout never moves a pinned symbol. |
| Layers are `LifecycleStatus` + `Sheet.lifecycleFilter` | CR-064, CR-067, AC-038 | A `Layer` entity and `layerId`. The useful half of layers is "show me only the new work"; the rest is CAD ceremony. |
| Sheet numbering is a project setting, default `simple` | CR-066, m17 | Hard-validating `^[A-Z]{1,2}\d\.\d{2}$`. A residential set is four pages; the first user who types "Page 2" should not get a validation failure from a 200-sheet commercial convention. |
| `EntityMeta` on conflict units only | CR-095 | `EntityMeta` on every object. On `Port`, `Conductor`, `Service`, `SheetItem` and `ZeroUChannel` it is dead weight by the design's own conflict model; those carry a bare `unknown` map instead. |
| Tombstones ship in v1 | CR-095, G5 | Hard deletes. With hard deletes a later sync cannot distinguish "the peer deleted this" from "the peer never had it", and the second reading resurrects deleted devices on every sync. Tombstones also make delete commands trivially invertible for undo. |
| `Finding` is computed, never stored | §5.8 | Persisted findings. Only acknowledgements persist. |

**Exactly one schematic `Sheet` is created per project, and multi-sheet authoring is never built (DR-004).** The entity ships anyway so the format never migrates if that is ever reversed (AC-037). It is not vestigial and must not be described as removable. There is therefore no field, note or TODO for sheet-boundary link handling, match lines or off-sheet connectors: a `Link` can never have its two ends on different sheets, because there is only one. Distinguish this from the **exporter's** domain partition, which is untouched (CR-073): one `Sheet` in the document, N interconnect sheets `T6.01…` emitted from it by filtering, alongside `T0.00` cover and drawing index, `T0.01` legend, `T0.02` exceptions, `T2.01`/`T2.02` elevations, `T6.10` pull sheet, `T6.15` termination schedule, `T6.20` unused home runs, `T6.30` equipment list and materials, and `T5.01` plate/panel/pinout details. **N sheets coming out of the PDF is not evidence that multi-sheet authoring exists.**

**Wire idiom is not a stored property.** Every `Link` renders as a pair of net labels by default; on a domain filter, `Alt`-hover or focus, the Links in scope render as orthogonal polylines with a tag pill at each end (DR-001). `Link` carries no render field and `Sheet` carries no render setting, render mode is **derived** from the active filter, never persisted (CR-115). The only sheet state that persists is `domainFilter`, `lifecycleFilter` and the `SheetItem` placements.

### 4.9 `Registries`: the three orthogonal axes

The single most expensive mistake available in this domain is one `CableType` enum. RJ45 is a **connector**; Cat6a is a **medium**; Ethernet, HDBaseT, Dante and Cresnet are **signal families** that share both. HDBaseT reuses Ethernet conductors, cable and connectors *and is not interchangeable with them*, patching an HDBaseT output into a switch does not work and its PoH can damage the switch. That check (`SIG-001`) is the highest-value validation in the product, and it is only expressible because the axes are separate (CR-008, §6.1).

| Registry | Answers | User-extensible in v1? |
|---|---|---|
| `SignalDomainDef` | What colour, dash, weight and glyph does this class of signal draw in? | No: 8 fixed entries (CR-078) |
| `SignalFamilyDef` | What *is* this signal, what does it require, what may it mate with? | **By clone only** (DR-122; was catalog-updated, RJ-012) |
| `ConnectorTypeDef` | What plugs into what, and does gender apply? | Aliases only (CR-058) |
| `MediaTypeDef` | What cable is pulled, how long may it be, what jacket? | **Yes**: CSV import creates them (RJ-009) |
| `CableSpecDef` | Which manufacturer part number is this? | Yes; optional throughout |
| `OutletTemplate` | What does a "TV location" consist of? | Yes (CR-108) |

`SignalDomainDef` is new in CR-078 and owns the **visual language** (`{id, displayName, tagPrefix, color, colorDark, dashPattern, lineWeightPermille, glyph, glyphAlt}`) which deleted the 43-entry per-family palette that the source design simultaneously carried and argued against. Colour encodes **domain** (8 entries, Okabe–Ito), not type, because no categorical palette is colour-vision-deficiency-safe past 8–9 categories. Dash pattern, line weight and glyph carry type-within-domain, and the tag pill (`W042 · HDMI · 25 ft`, drawn at both ends of every run) is the encoding that never fails. Requirement 4 of the brief, "colour-coded by cable type", is met by the **legend**, which prints one row per named cable type in colour and greyscale side by side (AC-054). Dash patterns are stored as `List<int>` of permille-points so the file stays integral: `6,3` is `[6000, 3000]` (CR-079).

`SignalFamilyDef` carries the type-within-domain half as four optional overrides: `shortTag`, `dashOverride` and a weight override (DR-010 §11.10.3), and `glyphOverride` (DR-181 §11.180.2). Each is null to inherit the domain's value, and the effective value is what every renderer and `tools/registry_parity.py` read: `effectiveDashPattern`, `effectiveLineWeightPermille`, `effectiveGlyph`. The glyph's fallback is the domain's NATIVE shape and never `glyphAlt`, because which alternate a family takes is exactly what the override exists to state.

Registry IDs are `lower.dotted.snake` and reverse-hierarchical (`video.hdmi.2_1`, `conn.rj45`, `media.cat6a_futp`) with bare trade names carried as `aliases: List<String>` (CR-058). Full contents are specified in canonical §6 and shipped as `assets/catalog/registries.json`; the subset a document references is **embedded in the file**, which is what makes a `.rppj` self-describing.

Unresolvable registry IDs degrade to an `unknown(rawId)` placeholder that round-trips, renders in grey with the raw id as its tag, and never throws (I-46).

---

## 5. The v1 validation rule catalogue: three tiers

**This section is the rule catalogue. A rule not listed here does not exist (CR-021).** It is the single home the corpus refers to as `docs/rules.md`; that file is not created.

**8 tier-1 + 6 tier-2 + 16 tier-3.** The sixteenth is `RCK-014`, CR-030's ear-kit advisory, added by DR-219 §11.218.4 as a §8.3 amendment; the fifteenth is `ELE-005`, restored by DR-132 §11.131 after AC-040 cut it; this sentence said *"28 rules ... 14 tier-3"* until DR-154 §11.153.1, while the table below it already had fifteen rows. AC-040's "22" is an arithmetic error against its own enumeration of 24; `PLC-001..003` are ratified as distinct tier-1 rules because CR-017 already rules their conditions model-illegal and an unnumbered blocking rule can carry neither a `Finding.ruleId` nor an AC-051 fixture pair (canon §12.6(b)). **`LEN-002`** was added by DR-020 (canon §11.19, §12.13) and **`ELE-005`** restored by DR-132 (canon §11.131); §12.6(b)'s "27" is superseded on the number only and stands in every other respect.

The naive design is `hard-illegal / warn / allow` as three static rule outcomes. That shape is rejected, because **which tier a rule belongs to is not a property of the rule: it is a property of the situation.** "HDBaseT into a switch port" is a catastrophic error in a new design and *a correct depiction of an existing system you were called in to fix*. A model that cannot draw a mistake cannot document reality, cannot plan a remediation, and cannot import an as-found survey (G2).

The binding frame (CR-017):

> **The gesture may hesitate. The document may not lie.**

| Tier | What it is | Effect | Escape |
|---|---|---|---|
| **T1: model-level illegal** | States in which the document *means nothing*. | The command is rejected. These are the only rules that can prevent an edit. | None. There is nothing to escape to. |
| **T2: gesture-level spring-back** | Physically or electrically wrong, and known at drag time. | The wire springs back with a reason chip carrying remedy actions **and `[ Connect anyway ]`**. | `[ Connect anyway ]` creates the Link and files a T3 finding. |
| **T3: post-hoc finding** | Everything else, including anything unevaluatable at drag time. | A `Finding` in the issues list, at `error \| warning \| advisory \| off`. | `AckedFinding` with a reason that **prints** on sheet `T0.02`. |

The former "Class A, hard-invalid, refused at drag time, cannot exist in the document" list is **deleted** as a concept (CR-017); its members became T2 spring-backs with their remedy chips kept exactly as designed, only the finality went. Two of them ("Dante endpoints with no network path", "AVB traversing a non-AVB switch") are **logically unevaluatable** at drag time, because the link being drawn may be the one that completes the path; they are demoted to T3 unconditionally.

### 5.1 Tier 1: model-level illegality (blocking, no override)

| Rule ID | Rule | Governing |
|---|---|---|
| `TOP-001` | A conductor may not connect a port to itself. | CR-017 |
| `TOP-002` | Two conductors may not duplicate the same ordered port pair on the same link. | CR-017 |
| `TOP-003` | A port's live conductor count may not exceed its effective `maxConnections`. | CR-017 |
| `TOP-004` | Every endpoint must resolve: a `PortEndpoint` to an existing, non-tombstoned port. (`PlaceEndpoint` and `OpenEndpoint` are exempt by construction, AC-018.) | CR-017, AC-018 |
| `TOP-005` | A shelf-hosted device's `hostDeviceId` must resolve to a container and must not create a containment cycle. | CR-017 |
| `PLC-001` | `RailPlacement.ruIndex ∈ [1, rack.heightU]` and the device fits within the rack extent on that face. | CR-017 |
| `PLC-002` | `startTwelfth ∈ [0,11]`, `spanTwelfths ∈ [1,12]`, `startTwelfth + spanTwelfths ≤ 12`. | CR-030 |
| `PLC-003` | `ZeroUPlacement.channelId` resolves in `rack.zeroUChannels` and the offset lies within the channel. | CR-031 |

CR-017 names the three placement-coherence conditions without assigning rule IDs; they are **ratified here** as `PLC-001..003`, distinct tier-1 rules of the eight (canon §12.6(b)).

The rack editor's other blocking drop checks are demoted to warnings, **except** RU-range-free on the same face and fits-within-rack-extent, which are physical impossibilities rather than trade opinions (CR-017).

### 5.2 Tier 2: gesture-level spring-back

Every chip below carries its remedy actions and `[ Connect anyway ]`. All of these also exist as T3 findings once the user overrides.

| Rule ID | Condition | Default severity when filed | Governing |
|---|---|---|---|
| `SIG-001` | HDBaseT port connected to a `net.ethernet` switch port. **The flagship rule**: PoH into a switch port. Remedy: `[ Insert HDBaseT receiver ]`, which inserts a **device** (CR-015). | error | CR-017, §6.1 |
| `SIG-002` | The sink's `acceptedFamilies` excludes the service's `signalFamily`, and no `InlineAdapter` is declared. | error | CR-017 |
| `DIR-001` | source→source or sink→sink. Exceptions: both ports declare `returnChannel` (eARC), or the net is `passiveSplit`. | error | AC-040 |
| `DIR-003` | IR emitter output plugged into an IR *receiver* jack. Damages hardware; `PortDef.pinoutVariant` exists solely to make this detectable. | error | AC-040 |
| `CON-001` | Connector types do not mate and no `InlineAdapter` is declared. **Satisfied by data**: declaring the adapter clears it, no acknowledgement needed. | error | CR-015 |
| `ELE-006` | Constant-voltage speaker on a low-Z amplifier output, or the reverse. | error | AC-040 |

### 5.3 Tier 3: post-hoc findings (the v1 catalogue)

Severity vocabulary is `error | warning | advisory | off`, "info" is renamed `advisory` everywhere (CR-018). Severity is a property of the rule *in this project* and is settable per rule via `ProjectSettings.ruleOverrides`.

| Rule ID | Condition | Severity | Governing |
|---|---|---|---|
| `ELE-003` | Speaker polarity inverted between the two ends of a conductor pair. | **warning** (demoted from error) | AC-030/M12 |
| `ELE-005` | Σ of 70 V/100 V `Port.tapWatts` on a net > 80% of the amplifier channel's `bus.maxTapWatts`. **Known taps only**: an unrecorded tap is counted and named, never estimated, so the total is a FLOOR (CR-114). **Restored by DR-132 §11.131**, having been cut by AC-040, on that cut's own "protects the user from real money" test: an overloaded line clips the amplifier and clipped square waves destroy tweeters. | **warning** | AC-040, DR-132, CR-114 |
| `NET-001` | Σ PD class draw on a switch exceeds `PowerProfile.poeBudgetWatts`. | error | CR-056 |
| `PWR-001` | Σ continuous amps on a circuit > 80% of the breaker, computed on **typical × diversity factor, in VA**. **A planning estimate and not a compliance check** (DR-079 §11.78.4): it names the circuit to look at first and asserts nothing about NEC. | **warning** (demoted from error) | CR-020, AC-020, DR-079 |
| `PWR-003` | Outlets consumed exceed outlets provided in the rack. | error | AC-040 |
| `LEN-001` | Ethernet channel > 100 m (90 m horizontal + 10 m patch). When length is null it emits *"length unknown, cannot verify"* rather than passing silently, silence reads as approval. **Fed by a `planLowerBound` when that alone already exceeds the limit** (DR-147 §11.146.5): a bound can prove a violation and can never prove compliance, so a floor UNDER the limit still emits the unknown finding. This clause was on the `LEN-002` row below and not on this one until `PLAN-G`, against a shared predicate that serves both. | error | AC-024/M9 |
| `LEN-002` | A run's known length exceeds the declared maximum for its media type, which is `MediaTypeDef.maxRunLengthPassive` and **not** the empty `maxRunLengthActive` beside it (canon §11.19.7). **Generic by construction**: one rule reading the registry, not one rule per medium, so a new limit is a registry row rather than a new ruling. Seven of the 38 shipped types declare one, so the rule is silent on the other thirty-one and counts them rather than treating null as zero. Fed by `cutLength`/`terminatedLength` when known, and by a `planLowerBound` when that alone already exceeds the limit, a bound can prove a violation and can never prove compliance. Null length emits *"length unknown, cannot verify"* like `LEN-001`. | warning | DR-020 |
| `RCK-001` | RU overlap on the same face. | error | AC-040 |
| `RCK-002` | Device extends past `heightU`. | error | AC-040 |
| `RCK-003` | Σ device weight > `Rack.weightCapacity`. | **advisory at 60%, warning at 85%, error over capacity** (DR-125) | CR-020 |
| `RCK-012` | Front device depth + rear device depth + 50 mm cable allowance > usable depth, for overlapping RU ranges. | error | AC-022/M7 |
| `RCK-013` | Device mass exceeds `maxUnsupportedMass` on front ears only; requires rear support or a shelf. | warning | AC-028/M14 |
| `RCK-014` | Half-rack device alone in its U; needs an ear kit or a shelf. | advisory | CR-030, DR-219 |
| `CODE-001` | Class 2/3 conductor in a `Pathway` with `containsLineVoltage == true`. **Cites NEC 725.136 and says the article has permitted arrangements this product does not model**, so it asks the user to verify rather than asserting a violation (DR-079 §11.78.3). | **warning** (demoted from error) | AC-027/M13, DR-079 |
| `CODE-002` | `Pathway.kind == plenumSpace` and the jacket's **listing** is not plenum-rated for its own NEC article, resolved through `jacket_substitution.dart`. **`lszh` is gone from the predicate**: LSZH is a jacket compound and not a listing, and accepting it was a false pass (DR-079 §11.78.1). Cites NEC 800.154 and names 300.22(C)'s metal-raceway exception, which this product cannot see because it models no raceway. A listing from another article, or none at all, is **unknown and skips** (G4). | **warning** (demoted from error) | AC-027/M13, DR-079 |
| `LNK-020` | N links have unbound endpoints. A checklist, not a failure. | advisory | AC-018/B1 |

**v1 ships this set and no more** (AC-040, as amended by DR-020), fourteen tier-3 rules, completing the 28. Everything else in the full catalogue (the remaining `DIR`, `CON`, `ELE`, `LEN`, `BUS`, `SER`, `NET`, `PWR` and `RCK` rules, plus `PWR-006`, `RCK-003b`, `RCK-007`, `RCK-014`, `TOP-010`, `TOP-011` and `SEQ-001` adopted by CR-021 and AC-033) moves to v1.2 behind a fixture corpus. **No rule ships without a known-bad and a known-good fixture** (AC-040, AC-051).

### 5.4 Acknowledgement: one mechanism, two scopes

Three documents proposed three dismissal mechanisms. One survives (CR-019): `AckedFinding{ruleId, targetFingerprint, reason, by, at, demotedTo}`, where `targetFingerprint == "*"` means a project-wide mute of that rule and the reason is **required**. For a single instance the reason is optional (RJ-006).

**Errors are acknowledgeable.** Refusing to let a professional override the tool's opinion about their own system is how the tool gets abandoned. The rejected alternative, `ruleSeverityOverrides: Map<String, Severity>`, had no field for the justification that two documents promised would print; it is replaced by `Map<String, RuleOverride{severity, reason, by, at}>`.

**Nothing blocks export** (CR-022, G3). `blockExportOnErrors` is deleted; open errors block only the `ISSUED FOR CONSTRUCTION` stamp and the revision-block `issued` flag, via `ExportSpec.issuedForConstruction`. Every export emits sheet **`T0.02 — Exceptions & Acknowledgements`** listing every open finding and every acknowledgement with its reason, author and date, which is where the promised "the reason prints in the appendix" actually happens. Likewise the legend-note invariant is **not** an invariant: the exporter knows which sheet carries the legend and auto-fills `SYMBOL LEGEND: SEE SHEET T0.01` into every other title block, so there is nothing for the user to get wrong and nothing to validate (CR-023).

Rules are **Dart functions** in a registry keyed by `ruleId`; the **catalogue** is data (CR-024, AC-011). Reachability (`NET-003`), path enumeration with a per-hop predicate (`NET-004`), parallel impedance (`ELE-004`) and sums-with-a-derate (`PWR-001`) do not fit a boolean predicate tree, and building an AST *plus* a native escape hatch yields two rule systems, two debuggers and two test suites. `RulePredicate` is deleted and the user-authored-rules claim is withdrawn. What stays data is substantial: rule metadata, per-project severity overrides, acknowledgements, forward-compat on unknown `ruleId`s, and the connector × signal-family **compatibility matrix**, which genuinely is a lookup table. This also closes an import-security hole: no evaluated program arrives in any file.

---

## 6. The `.rppj` file format

This section **is** the file-format specification; `docs/file-format.md` is not created and every citation of it points here.

### 6.1 Container and persistence contract

| Property | Binding value | Ruling |
|---|---|---|
| Container | Plain, **pretty-printed, key-sorted UTF-8 JSON**. 2-space indent. | CR-091 |
| Codec | `DocumentCodec` from commit one, sniffing `PK\x03\x04` on read, so a v2 zip container is a non-event. The extension never changes; v1 files keep opening forever. | CR-091 |
| Envelope | Format metadata at the root; all entity maps under `"document"`. | CR-092 |
| Round trip | **Byte** round trip: `write(read(bytes)) == bytes`, asserted over files RackPal wrote, an explicit `null` in a hand-edited file reads as absent and re-emits as absent. | CR-117 |
| Unknown values | Written as an **absent key**, never an explicit `null`. `weightUg` and `bodyDepthNm` are the two that most often go missing. | CR-114, G4 |
| Saves | Atomic: write `foo.rppj.tmp` in the same directory → `flush()` → `rename()`. One sibling `.bak`. **No `.history/` folder** in the user's directory. | CR-098 |
| Snapshots | `getApplicationSupportDirectory()/snapshots/<docUuid>/<sequence>.rppj`, last 10. | CR-098 |
| Floats | **None**, in any persisted model, including `.rpdx`. | CR-001, CR-063, I-1 |
| Enums | Strings, never ordinals. Unknown values fall back to an `unknown(raw)` variant that round-trips rather than throwing. | §4.3 |
| Derived values | **Never serialized**: `portIds`, `Outlet.roughInStatus`, `templateUpdateAvailable`, `Link.dominantSignalFamily`, elevation X/Y, circuit membership, `continuousLimitAmps`. | CR-115, CR-006 |
| IDs | UUIDv7 for entities; `uuidv5(deviceId, portKey)` for template-derived ports. Normative examples use real UUIDs. | CR-116, AC-006 |
| Import security | Zip-slip protection, entry-count and uncompressed-size caps, JSON depth and size limits on every import path. | AC-058/D8 |

Two container decisions and their rejected alternatives. **Plain JSON over zip (CR-091):** deterministic key ordering and 2-space indentation make the file `git diff`-able, which matters more than the ~3× size at the corrected ~600 KB budget; the `DocumentCodec` seam means choosing otherwise later costs nothing. **Byte round trip over semantic round trip (CR-117):** the stated justification for plain JSON is git-diffability and honest dirty-tracking, and both require `write(read(bytes)) == bytes`. That constrains key ordering, *including inside nested `unknown` maps*, timestamp precision and integer formatting, which are exactly the things that produce spurious diffs and a lying dirty flag. The weaker `read(write(read(x))) == read(x)` tested the wrong property.

### 6.2 Annotated example

A 12U wall rack, a 4×4 HDMI matrix, a 24-port PoE switch, a 24-port patch panel, one Structure body with one outlet, and four Links, one home run still `structure.undetermined` at rough-in, one patch jumper, one multi-service Cat5e, and one design-intent HDMI run to a device that does not exist yet.

**Presentation note.** The codec key-sorts every object, which would place the enormous `document` value between `createdAt` and `generator`. It is shown last here so the envelope reads as a unit. Port arrays inside templates are elided with an explicit sentinel string. This listing is therefore *derived from* `test/fixtures/v1_sample.rmpj` and is not itself byte-identical to it.

```json
{
  "appVersion": "0.1.0+build.42",
  "createdAt": "2026-07-18T09:14:02.113847Z",
  "generator": "RackPal",
  "id": "0190e3c1-7a2f-7c9d-8b11-a0f2c4e51d33",
  "minReaderVersion": 2,
  "modifiedAt": "2026-07-18T16:42:55.902310Z",
  "schemaVersion": 2,
  "sequence": 412,

  "document": {
    "info": {
      "checkedBy": "R. Okonkwo",
      "clientName": "M. Ashford",
      "drawingNumber": "AV-100",
      "drawnBy": "R. Riley",
      "integratorLicense": "EC-13004221",
      "integratorName": "Northbeam Systems",
      "projectName": "Ashford Residence",
      "projectNumber": "2026-0114",
      "siteAddress": { "city": "Asheville", "line1": "114 Ridgeline Ct",
                       "postalCode": "28803", "region": "NC" }
    },

    "settings": {
      "cableWasteFactor": 100,
      "collisionPolicy": "suffixLetter",
      "defaultLineVolts": 120,
      "defaultMirrorRearElevation": true,
      "defaultNetworkMedia": "media.cat6a_futp",
      "defaultRackHeightU": 12,
      "defaultRuNumbering": "bottomUpFromOne",
      "designatorBlockSize": 100,
      "designatorPad": 0,
      "designatorSeparator": "-",
      "deviceDesignatorFormat": "{TYPE_PREFIX}{SEP}{SEQ}",
      "displayUnits": "imperial",
      "diversityFactorsByCategory": { "amplifier": 350, "switch": 1000, "ups": 1000 },
      "familyColorOverrides": {},
      "linkDesignatorFormat": "W{SEQ:3}",
      "netNameFormat": "N{SEQ:3}",
      "outletFieldLabelFormat": "{ROOM_ABBR}-{SERVICE}-{SEQ}",
      "outletRackLabelFormat": "{FLOOR}{SPACE}-{PANEL}{PORT:2}",
      "portDesignatorFormat": "J{PORT_SEQ:2}",
      "ruleOverrides": {
        "RCK-013": { "at": "2026-07-18T11:02:19.000000Z", "by": "rriley",
                     "reason": "Every amp in this job sits on a shelf.",
                     "severity": "advisory" }
      },
      "sheetNumbering": "simple",
      "wiringStandard": "t568b"
    },

    "locations": {
      "0190e3c1-8b40-7a11-9c02-3f7d1e88a201": {
        "code": "BAS", "floorNumber": 0, "id": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
        "kind": "room", "name": "Basement AV Closet", "order": "a0", "spaceCode": "A",
        "meta": { "createdAt": "2026-07-18T09:14:40.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T09:14:40.000000Z", "updatedBy": "rriley" }
      },
      "0190e3c1-8b41-7b22-8d13-4a2e5c90b312": {
        "code": "LR", "estimatedRunLengthFromRackNm": 18288000000,
        "floorNumber": 1, "id": "0190e3c1-8b41-7b22-8d13-4a2e5c90b312",
        "kind": "room", "name": "Living Room", "order": "a1",
        "meta": { "createdAt": "2026-07-18T09:15:02.000000Z", "localRevision": 2,
                  "updatedAt": "2026-07-18T10:41:11.000000Z", "updatedBy": "rriley" }
      }
    },

    "racks": {
      "0190e3c1-9c50-7d33-9e24-5b3f6da1c423": {
        "designator": "RK-1",
        "formFactor": "wallSwingGate",
        "fullHoleRail": true,
        "groundBarPresent": true,
        "hasFrontDoor": true, "hasRearDoor": false,
        "heightU": 12,
        "hingeSide": "left",
        "id": "0190e3c1-9c50-7d33-9e24-5b3f6da1c423",
        "isSwingFrame": true,
        "locationId": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
        "mirrorRearElevation": true,
        "name": "AV Rack",
        "order": "a0",
        "overallDepthNm": 482600000,
        "ownWeightUg": 27215542000,
        "railType": "tapped10_32",
        "ruNumbering": "bottomUpFromOne",
        "usableDepthNm": 457200000,
        "weightCapacityUg": 45359237000,
        "widthClass": "eia19",
        "zeroUChannels": [
          { "endU": 12, "id": "ch-rear-l", "side": "rearLeft", "startU": 1 }
        ],
        "meta": { "createdAt": "2026-07-18T09:16:00.000000Z", "localRevision": 3,
                  "updatedAt": "2026-07-18T09:31:44.000000Z", "updatedBy": "rriley" }
      }
    },

    "circuits": {
      "0190e3c1-9c51-7e44-8f35-6c407eb2d534": {
        "breakerAmps": 20, "dedicated": true,
        "designator": "Panel A / Breaker 14",
        "id": "0190e3c1-9c51-7e44-8f35-6c407eb2d534",
        "locationId": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
        "rackId": "0190e3c1-9c50-7d33-9e24-5b3f6da1c423",
        "volts": 120,
        "meta": { "createdAt": "2026-07-18T09:17:10.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T09:17:10.000000Z", "updatedBy": "rriley" }
      }
    },

    "templates": {
      "tpl.generic.hdmi_matrix_4x4@2": {
        "capturedAt": "2026-07-18T09:20:11.000000Z",
        "contentHash": "sha256:1f4c8b2e9a0d4471bc35e6f708a19d2c5b4e37f10a9c8d6e2b1f0a3c7d5e9b04",
        "templateId": "tpl.generic.hdmi_matrix_4x4",
        "version": 2,
        "body": {
          "banks": [
            { "abbr": "IN", "collapseInSymbol": false, "key": "in", "label": "HDMI Inputs",
              "order": "a0", "symbolSide": "left" },
            { "abbr": "OUT", "collapseInSymbol": false, "key": "out", "label": "HDMI Outputs",
              "order": "a1", "symbolSide": "right" }
          ],
          "bodyDepthNm": 355600000,
          "category": "matrix.hdmi",
          "chassisWidthNm": 432000000,
          "connectorProjectionNm": 101600000,
          "displayName": "4x4 HDMI Matrix",
          "frontU": 2,
          "isContainer": false,
          "isPassthrough": false,
          "manufacturer": "Generic",
          "maxUnsupportedMassUg": 7000000000,
          "model": "4x4 HDMI Matrix",
          "mountMethod": "rackEars",
          "nominalSpanTwelfths": 12,
          "ports": [
            { "acceptedFamilies": ["video.hdmi.2_0", "video.hdmi.1_4"],
              "bankKey": "in",
              "connector": "conn.hdmi_a", "direction": "sink", "face": "rear",
              "gender": "female", "key": "hdmi_in_1", "label": "HDMI IN 1",
              "maxConnections": 1, "order": "a0", "renamedFrom": [],
              "signalFamily": "video.hdmi.2_0", "topology": "p2p" },
            "…hdmi_in_2 … hdmi_in_4 elided…",
            { "acceptedFamilies": [],
              "bankKey": "out",
              "connector": "conn.hdmi_a", "direction": "source", "face": "rear",
              "gender": "female", "key": "hdmi_out_1", "label": "HDMI OUT 1",
              "maxConnections": 1, "order": "b0", "renamedFrom": [],
              "returnChannel": { "direction": "sink", "enabled": false,
                                 "signalFamily": "audio.earc" },
              "signalFamily": "video.hdmi.2_0", "topology": "p2p" },
            "…hdmi_out_2 … hdmi_out_4 elided…",
            { "connector": "conn.de9", "direction": "bidirectional", "face": "rear",
              "gender": "female", "key": "rs232", "label": "RS-232", "maxConnections": 1,
              "order": "c0", "renamedFrom": [],
              "serial": { "baud": 9600, "dataBits": 8, "flowControl": "none",
                          "parity": "none", "role": "DCE", "stopBits": 1 },
              "signalFamily": "ctl.rs232", "topology": "p2p" },
            { "connector": "conn.iec_c14", "direction": "sink", "face": "rear",
              "gender": "male", "key": "ac_in", "label": "AC IN", "maxConnections": 1,
              "order": "d0", "renamedFrom": [],
              "power": { "drawWatts": 60, "maxAmps": 5, "role": "inlet", "volts": 120 },
              "signalFamily": "power.ac_iec", "topology": "p2p" }
          ],
          "portSets": [],
          "power": { "apparentVA": 52, "inletPlug": "C14", "isContinuousLoad": true,
                     "nameplateWatts": 60, "nominalVolts": 120,
                     "powerFactor": 950, "typicalWatts": 34 },
          "rearU": 2,
          "requiresClearanceAboveU": 0, "requiresClearanceBelowU": 0,
          "side": "both",
          "tags": ["video", "distribution"],
          "thermalClass": "lowHeat",
          "typePrefix": "MTX",
          "weightUg": 4535923700,
          "widthClass": "full"
        }
      },

      "tpl.generic.poe_switch_24@1": {
        "capturedAt": "2026-07-18T09:21:03.000000Z",
        "contentHash": "sha256:88de41c70b9a2f6538e14d07cb9a35f2618d4e0a7c93b5d1f8026ae4bc7d5301",
        "templateId": "tpl.generic.poe_switch_24",
        "version": 1,
        "body": {
          "banks": [ { "abbr": "ETH", "collapseInSymbol": true, "key": "eth",
                       "label": "Ethernet", "order": "a0", "symbolSide": "left" } ],
          "bodyDepthNm": 254000000,
          "category": "network.switch",
          "chassisWidthNm": 432000000,
          "displayName": "24-Port PoE+ Switch",
          "frontU": 1,
          "isContainer": false, "isPassthrough": false,
          "manufacturer": "Generic", "model": "24-Port PoE+ Switch",
          "mountMethod": "rackEars", "nominalSpanTwelfths": 12,
          "ports": [
            { "acceptedFamilies": ["net.ethernet"], "bankKey": "eth",
              "connector": "conn.rj45", "direction": "bidirectional", "face": "front",
              "gender": "female", "key": "eth_01", "label": "1", "linkSpeedMbps": 1000,
              "maxConnections": 1, "order": "a0",
              "poe": { "class": 4, "role": "pse", "standard": "at", "type": 2,
                       "watts": 30 },
              "renamedFrom": [], "signalFamily": "net.ethernet", "topology": "star" },
            "…eth_02 … eth_24 elided…"
          ],
          "portSets": [],
          "power": { "apparentVA": 190, "inletPlug": "C14", "isContinuousLoad": true,
                     "nameplateWatts": 440,
                     "poeBudgetWatts": 370, "powerFactor": 950, "typicalWatts": 180 },
          "rearU": 0,
          "requiresClearanceAboveU": 1, "requiresClearanceBelowU": 0,
          "side": "front", "tags": ["network"], "thermalClass": "highHeat",
          "typePrefix": "SW", "weightUg": 3628738900, "widthClass": "full"
        }
      },

      "tpl.generic.patch_panel_24@1": {
        "capturedAt": "2026-07-18T09:21:40.000000Z",
        "contentHash": "sha256:c4a70d19b8e2f350a6d7c1948b0e5fa27361dc84e09f5b2a7c6d3e18f40b9a25",
        "templateId": "tpl.generic.patch_panel_24",
        "version": 1,
        "body": {
          "category": "infrastructure.patch_panel",
          "chassisWidthNm": 432000000,
          "displayName": "24-Port Cat6A Patch Panel",
          "frontU": 1,
          "isContainer": false,
          "isPassthrough": true,
          "manufacturer": "Generic", "model": "24-Port Cat6A Patch Panel",
          "mountMethod": "rackEars", "nominalSpanTwelfths": 12,
          "passthroughPairs": [
            { "frontKey": "pp_f_12", "rearKey": "pp_r_12", "sameNet": true },
            "…pairs 1–11 and 13–24 elided…"
          ],
          "ports": [ "…pp_f_01 … pp_f_24, pp_r_01 … pp_r_24 elided…" ],
          "portSets": [],
          "power": { "isContinuousLoad": false },
          "rearU": 1,
          "requiresClearanceAboveU": 0, "requiresClearanceBelowU": 0,
          "side": "both", "tags": ["infrastructure"], "thermalClass": "passive",
          "typePrefix": "PP", "widthClass": "full"
        }
      },

      "tpl.system.structure@1": {
        "capturedAt": "2026-07-18T09:22:05.000000Z",
        "contentHash": "sha256:0d5e91af73c2b846e10f7d3a95c6b280e4f1a7d93b05c8e26af14d7302b9c651",
        "templateId": "tpl.system.structure",
        "version": 1,
        "body": {
          "bodyDepthNm": 0, "category": "system.structure",
          "chassisWidthNm": 0, "displayName": "Structured Wiring",
          "frontU": 0, "isContainer": false, "isPassthrough": false,
          "manufacturer": "RackPal", "model": "Structure",
          "mountMethod": "notInRack", "nominalSpanTwelfths": 0,
          "ports": [], "portSets": [],
          "power": { "isContinuousLoad": false },
          "rearU": 0, "requiresClearanceAboveU": 0, "requiresClearanceBelowU": 0,
          "side": "none", "tags": ["system"], "thermalClass": "passive",
          "typePrefix": "STR", "weightUg": 0, "widthClass": "none"
        }
      }
    },

    "devices": {
      "0190e3c1-ad60-7e44-8f35-6c407eb2d534": {
        "designator": "MTX-1", "designatorLocked": false, "designatorWatermark": 0,
        "id": "0190e3c1-ad60-7e44-8f35-6c407eb2d534",
        "kind": "rackDevice",
        "lifecycleStatus": "new",
        "locationId": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
        "name": "HDMI Matrix",
        "overrides": {},
        "placement": { "chassisRotation": "normal", "face": "front", "locked": false,
                       "rackId": "0190e3c1-9c50-7d33-9e24-5b3f6da1c423",
                       "ruIndex": 9, "spanTwelfths": 12, "startTwelfth": 0,
                       "type": "rail" },
        "templateRef": { "contentHash": "sha256:1f4c8b2e9a0d4471bc35e6f708a19d2c5b4e37f10a9c8d6e2b1f0a3c7d5e9b04",
                         "templateId": "tpl.generic.hdmi_matrix_4x4", "version": 2 },
        "meta": { "createdAt": "2026-07-18T09:25:00.000000Z", "localRevision": 4,
                  "updatedAt": "2026-07-18T15:03:12.000000Z", "updatedBy": "rriley" }
      },
      "0190e3c1-ad61-7f55-9046-7d518fc3e645": {
        "designator": "SW-1", "designatorLocked": false, "designatorWatermark": 0,
        "id": "0190e3c1-ad61-7f55-9046-7d518fc3e645",
        "kind": "rackDevice", "lifecycleStatus": "new",
        "locationId": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
        "name": "Core Switch", "overrides": {},
        "placement": { "chassisRotation": "normal", "face": "front", "locked": false,
                       "rackId": "0190e3c1-9c50-7d33-9e24-5b3f6da1c423",
                       "ruIndex": 6, "spanTwelfths": 12, "startTwelfth": 0,
                       "type": "rail" },
        "templateRef": { "contentHash": "sha256:88de41c70b9a2f6538e14d07cb9a35f2618d4e0a7c93b5d1f8026ae4bc7d5301",
                         "templateId": "tpl.generic.poe_switch_24", "version": 1 },
        "meta": { "createdAt": "2026-07-18T09:26:11.000000Z", "localRevision": 2,
                  "updatedAt": "2026-07-18T09:44:02.000000Z", "updatedBy": "rriley" }
      },
      "0190e3c1-ad62-7066-8157-8e629ad4f756": {
        "designator": "PP-1", "designatorLocked": false, "designatorWatermark": 0,
        "id": "0190e3c1-ad62-7066-8157-8e629ad4f756",
        "kind": "rackDevice", "lifecycleStatus": "new",
        "locationId": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
        "name": "Patch Panel A", "overrides": {},
        "placement": { "chassisRotation": "normal", "face": "front", "locked": false,
                       "rackId": "0190e3c1-9c50-7d33-9e24-5b3f6da1c423",
                       "ruIndex": 12, "spanTwelfths": 12, "startTwelfth": 0,
                       "type": "rail" },
        "templateRef": { "contentHash": "sha256:c4a70d19b8e2f350a6d7c1948b0e5fa27361dc84e09f5b2a7c6d3e18f40b9a25",
                         "templateId": "tpl.generic.patch_panel_24", "version": 1 },
        "meta": { "createdAt": "2026-07-18T09:27:31.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T09:27:31.000000Z", "updatedBy": "rriley" }
      },
      "0190e3c1-ad63-7177-9268-9f73abe50867": {
        "designator": "STR-1", "designatorLocked": false, "designatorWatermark": 0,
        "id": "0190e3c1-ad63-7177-9268-9f73abe50867",
        "kind": "structure", "lifecycleStatus": "new",
        "name": "Rough-In — First Floor", "overrides": {},
        "placement": { "locationId": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
                       "mountNote": "Structured media enclosure, hallway",
                       "type": "offRack" },
        "structureBodyId": "0190e3c1-be70-7288-8379-a084bcf61978",
        "templateRef": { "contentHash": "sha256:0d5e91af73c2b846e10f7d3a95c6b280e4f1a7d93b05c8e26af14d7302b9c651",
                         "templateId": "tpl.system.structure", "version": 1 },
        "meta": { "createdAt": "2026-07-18T09:30:00.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T09:30:00.000000Z", "updatedBy": "rriley" }
      }
    },

    "ports": {
      "5c1a9e34-77b2-5c68-9f31-0a4b6d2e8c15": {
        "circuitId": null, "designator": "J12",
        "deviceId": "0190e3c1-ad62-7066-8157-8e629ad4f756",
        "id": "5c1a9e34-77b2-5c68-9f31-0a4b6d2e8c15",
        "orphaned": false, "overrides": {}, "reserved": false,
        "templatePortKey": "pp_r_12", "unknown": {}
      },
      "6d2bef45-88c3-5d79-8042-1b5c7e3f9d26": {
        "designator": "J36",
        "deviceId": "0190e3c1-ad62-7066-8157-8e629ad4f756",
        "id": "6d2bef45-88c3-5d79-8042-1b5c7e3f9d26",
        "orphaned": false, "overrides": {}, "reserved": false,
        "templatePortKey": "pp_f_12", "unknown": {}
      },
      "7e3cb056-99d4-5e8a-9153-2c6d8f40ae37": {
        "designator": "J12",
        "deviceId": "0190e3c1-ad61-7f55-9046-7d518fc3e645",
        "id": "7e3cb056-99d4-5e8a-9153-2c6d8f40ae37",
        "network": { "ipv4": "10.20.0.12", "vlan": 20 },
        "orphaned": false, "overrides": {},
        "poeActual": { "class": 4, "watts": 25 },
        "reserved": false, "templatePortKey": "eth_12", "unknown": {}
      },
      "8f4dc167-aae5-5f9b-8264-3d7e9051bf48": {
        "designator": "J05",
        "deviceId": "0190e3c1-ad60-7e44-8f35-6c407eb2d534",
        "id": "8f4dc167-aae5-5f9b-8264-3d7e9051bf48",
        "orphaned": false, "overrides": {}, "reserved": false,
        "templatePortKey": "hdmi_out_1", "unknown": {}
      },
      "905ed278-bbf6-50ac-9375-4e8fa162c059": {
        "designator": "J09",
        "deviceId": "0190e3c1-ad60-7e44-8f35-6c407eb2d534",
        "id": "905ed278-bbf6-50ac-9375-4e8fa162c059",
        "orphaned": false, "overrides": {}, "reserved": false,
        "templatePortKey": "rs232", "unknown": {}
      }
    },

    "structures": {
      "0190e3c1-be70-7288-8379-a084bcf61978": {
        "deviceId": "0190e3c1-ad63-7177-9268-9f73abe50867",
        "distributionDeviceLocationId": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
        "enclosureModel": "Generic 42 in structured media enclosure",
        "id": "0190e3c1-be70-7288-8379-a084bcf61978",
        "role": "homeRunField", "sheetEdge": "left",
        "title": "Rough-In — First Floor",
        "meta": { "createdAt": "2026-07-18T09:30:01.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T09:30:01.000000Z", "updatedBy": "rriley" }
      }
    },

    "outlets": {
      "0190e3c1-be71-7399-948a-b195cd072a89": {
        "designation": "LR-TV-1",
        "floorNumber": 1,
        "id": "0190e3c1-be71-7399-948a-b195cd072a89",
        "locationId": "0190e3c1-8b41-7b22-8d13-4a2e5c90b312",
        "mountHeightAffNm": 1524000000,
        "mountSurface": "wall",
        "nominalRunLengthNm": 18288000000,
        "order": "a0",
        "outletTemplateId": "outlet.tv_location",
        "pathwayId": "0190e3c1-be72-74aa-859b-c2a6de183b9a",
        "structureBodyId": "0190e3c1-be70-7288-8379-a084bcf61978",
        "tia570Grade": "TIA-570-D Grade 2",
        "wall": "n",
        "meta": { "createdAt": "2026-07-18T10:02:00.000000Z", "localRevision": 3,
                  "updatedAt": "2026-07-18T14:19:40.000000Z", "updatedBy": "rriley" }
      }
    },

    "pathways": {
      "0190e3c1-be72-74aa-859b-c2a6de183b9a": {
        "containsLineVoltage": false,
        "fromLocationId": "0190e3c1-8b40-7a11-9c02-3f7d1e88a201",
        "id": "0190e3c1-be72-74aa-859b-c2a6de183b9a",
        "kind": "jhook", "name": "B03", "nominalLengthNm": 16764000000,
        "order": "a0",
        "toLocationId": "0190e3c1-8b41-7b22-8d13-4a2e5c90b312",
        "meta": { "createdAt": "2026-07-18T10:01:00.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T10:01:00.000000Z", "updatedBy": "rriley" }
      }
    },

    "links": {
      "0190e3c1-cf80-75bb-96ac-d3b7ef294cab": {
        "breakouts": [],
        "conductors": [
          { "colorCode": "blue/white", "pairNumber": 1, "role": "",
            "from": { "portId": "5c1a9e34-77b2-5c68-9f31-0a4b6d2e8c15", "type": "port" },
            "to":   { "description": "LR TV wall plate, north wall, 60 in AFF",
                      "intendedTermination": "keystone",
                      "locationId": "0190e3c1-8b41-7b22-8d13-4a2e5c90b312",
                      "serviceLoopNm": 914400000, "type": "place" } }
        ],
        "cutLengthNm": 19812000000,
        "designator": "W001", "designatorLocked": true,
        "gaugeAwg": 23,
        "id": "0190e3c1-cf80-75bb-96ac-d3b7ef294cab",
        "inlineAdapters": [],
        "jacket": "cmr",
        "lifecycleStatus": "new",
        "linkClass": "fieldCable",
        "media": "media.cat6a_futp",
        "order": "a0",
        "pathwayId": "0190e3c1-be72-74aa-859b-c2a6de183b9a",
        "plenum": false,
        "roughInStatus": "pulled",
        "routedLengthNm": 18288000000,
        "services": [
          { "conductorRoles": [""], "id": "svc-1", "label": null,
            "netId": "0190e3c1-d090-79ff-9af0-17fb3c6d80ef",
            "signalFamily": "structure.undetermined" }
        ],
        "shielded": true,
        "structureOrigin": {
          "fieldLabel": "LR-TV-1A",
          "mountHeightAffNm": 1524000000,
          "mountSurface": "wall",
          "outletId": "0190e3c1-be71-7399-948a-b195cd072a89",
          "rackLabel": "1A-A12",
          "structureBodyId": "0190e3c1-be70-7288-8379-a084bcf61978",
          "terminationField": "keystone",
          "wall": "n"
        },
        "meta": { "createdAt": "2026-07-18T10:03:12.000000Z", "localRevision": 5,
                  "updatedAt": "2026-07-18T16:02:00.000000Z", "updatedBy": "rriley" }
      },

      "0190e3c1-cf81-76cc-87bd-e4c80f3a5dbc": {
        "breakouts": [],
        "conductors": [
          { "colorCode": "blue", "pairNumber": null, "role": "",
            "from": { "portId": "6d2bef45-88c3-5d79-8042-1b5c7e3f9d26", "type": "port" },
            "to":   { "portId": "7e3cb056-99d4-5e8a-9153-2c6d8f40ae37", "type": "port" } }
        ],
        "cutLengthNm": 304800000,
        "designator": "W002", "designatorLocked": false,
        "id": "0190e3c1-cf81-76cc-87bd-e4c80f3a5dbc",
        "inlineAdapters": [],
        "jacket": "cl2",
        "lifecycleStatus": "new",
        "linkClass": "jumper",
        "media": "media.cat6",
        "order": "a1",
        "plenum": false,
        "roughInStatus": "terminated",
        "services": [
          { "conductorRoles": [""], "id": "svc-1", "label": null,
            "netId": "0190e3c1-d091-7a10-8b01-28fc4d7e91f0",
            "signalFamily": "net.ethernet" }
        ],
        "shielded": false,
        "meta": { "createdAt": "2026-07-18T10:05:44.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T10:05:44.000000Z", "updatedBy": "rriley" }
      },

      "0190e3c1-cf82-77dd-98ce-f5d91a4b6ecd": {
        "breakouts": [],
        "conductors": [
          { "colorCode": "white/brown", "pairNumber": 3, "role": "IR",
            "from": { "description": "IR emitter output, block port 3", "type": "open" },
            "to":   { "description": "LR TV, IR eye on display bezel",
                      "intendedTermination": "fieldConnector",
                      "locationId": "0190e3c1-8b41-7b22-8d13-4a2e5c90b312",
                      "serviceLoopNm": 609600000, "type": "place" } },
          { "colorCode": "brown", "pairNumber": 4, "role": "+12V",
            "from": { "description": "Screen trigger, spare", "type": "open" },
            "to":   { "description": "LR TV wall plate, spare pair",
                      "intendedTermination": "unterminated",
                      "locationId": "0190e3c1-8b41-7b22-8d13-4a2e5c90b312",
                      "serviceLoopNm": 609600000, "type": "place" } },
          { "colorCode": "blue/white-blue", "pairNumber": 1, "role": "",
            "from": { "portId": "905ed278-bbf6-50ac-9375-4e8fa162c059", "type": "port" },
            "to":   { "description": "LR TV, display RS-232 port",
                      "intendedTermination": "fieldConnector",
                      "locationId": "0190e3c1-8b41-7b22-8d13-4a2e5c90b312",
                      "serviceLoopNm": 609600000, "type": "place" } }
        ],
        "designator": "W003", "designatorLocked": true,
        "gaugeAwg": 24,
        "id": "0190e3c1-cf82-77dd-98ce-f5d91a4b6ecd",
        "inlineAdapters": [],
        "jacket": "cmr",
        "lifecycleStatus": "new",
        "linkClass": "fieldCable",
        "media": "media.cat5e",
        "order": "a2",
        "pathwayId": "0190e3c1-be72-74aa-859b-c2a6de183b9a",
        "plenum": false,
        "roughInStatus": "pulled",
        "routedLengthNm": 18897600000,
        "services": [
          { "conductorRoles": ["IR"], "id": "svc-1", "label": "IR emitter",
            "netId": "0190e3c1-d092-7b21-9c12-390d5e8fa201",
            "signalFamily": "ctl.ir_emitter" },
          { "conductorRoles": ["+12V"], "id": "svc-2", "label": "Screen trigger",
            "netId": "0190e3c1-d093-7c32-8d23-4a1e6f90b312",
            "signalFamily": "ctl.trigger12v" },
          { "conductorRoles": [""], "id": "svc-3", "label": "Display control",
            "netId": "0190e3c1-d094-7d43-9e34-5b2f70a1c423",
            "signalFamily": "ctl.rs232" }
        ],
        "shielded": false,
        "structureOrigin": {
          "fieldLabel": "LR-TV-1C",
          "mountHeightAffNm": 1524000000,
          "mountSurface": "wall",
          "outletId": "0190e3c1-be71-7399-948a-b195cd072a89",
          "rackLabel": null,
          "structureBodyId": "0190e3c1-be70-7288-8379-a084bcf61978",
          "terminationField": "fieldConnector",
          "wall": "n"
        },
        "meta": { "createdAt": "2026-07-18T10:09:02.000000Z", "localRevision": 4,
                  "updatedAt": "2026-07-18T16:41:55.000000Z", "updatedBy": "rriley" }
      },

      "0190e3c1-cf83-78ee-89df-06ea2b5c7fde": {
        "breakouts": [],
        "conductors": [
          { "colorCode": null, "pairNumber": null, "role": "",
            "from": { "portId": "8f4dc167-aae5-5f9b-8264-3d7e9051bf48", "type": "port" },
            "to":   { "description": "Projector shelf, beam 3 — model TBD",
                      "intendedTermination": "fieldConnector",
                      "locationId": "0190e3c1-8b41-7b22-8d13-4a2e5c90b312",
                      "serviceLoopNm": 4572000000, "type": "place" } }
        ],
        "designator": "W004", "designatorLocked": false,
        "id": "0190e3c1-cf83-78ee-89df-06ea2b5c7fde",
        "inlineAdapters": [],
        "jacket": "cl3",
        "lifecycleStatus": "designIntent",
        "linkClass": "fieldCable",
        "media": "media.hdmi_passive",
        "order": "a3",
        "plenum": false,
        "roughInStatus": "planned",
        "services": [
          { "conductorRoles": [""], "id": "svc-1", "label": null,
            "netId": "0190e3c1-d095-7e54-8f45-6c3081b2d534",
            "signalFamily": "video.hdmi.2_0" }
        ],
        "shielded": true,
        "meta": { "createdAt": "2026-07-18T15:58:20.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T15:58:20.000000Z", "updatedBy": "rriley" }
      }
    },

    "nets": {
      "0190e3c1-d090-79ff-9af0-17fb3c6d80ef": {
        "id": "0190e3c1-d090-79ff-9af0-17fb3c6d80ef", "isImplicit": true,
        "name": "", "signalFamily": "structure.undetermined", "topology": "p2p",
        "meta": { "createdAt": "2026-07-18T10:03:12.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T10:03:12.000000Z", "updatedBy": "rriley" }
      },
      "0190e3c1-d092-7b21-9c12-390d5e8fa201": {
        "designator": "N012", "id": "0190e3c1-d092-7b21-9c12-390d5e8fa201",
        "isImplicit": false, "name": "LR TV IR", "signalFamily": "ctl.ir_emitter",
        "topology": "star",
        "meta": { "createdAt": "2026-07-18T10:09:02.000000Z", "localRevision": 2,
                  "updatedAt": "2026-07-18T11:20:00.000000Z", "updatedBy": "rriley" }
      },
      "…implicit nets for W002 and W004 elided…": {}
    },

    "sheets": {
      "0190e3c1-e1a0-7d43-9e34-5b2f70a1c423": {
        "carriesLegend": false,
        "domainFilter": [],
        "id": "0190e3c1-e1a0-7d43-9e34-5b2f70a1c423",
        "includedDeviceIds": [], "includedRackIds": [],
        "kind": "schematic",
        "lifecycleFilter": ["existing", "new", "designIntent"],
        "number": "2", "order": "a1", "orientation": "landscape",
        "paper": "ansiB",
        "scaleDenominator": 0, "scaleNumerator": 0,
        "title": "SYSTEM SCHEMATIC",
        "items": {
          "0190e3c1-e1a1-7e54-8f45-6c3081b2d534": {
            "collapsed": false, "id": "0190e3c1-e1a1-7e54-8f45-6c3081b2d534",
            "pinned": true, "position": { "gx": 48, "gy": 20 },
            "rotationQuarterTurns": 0,
            "targetId": "0190e3c1-ad60-7e44-8f35-6c407eb2d534",
            "unknown": {}, "zOrder": "a1"
          },
          "…SheetItems for SW-1, PP-1, STR-1 elided…": {}
        },
        "meta": { "createdAt": "2026-07-18T09:14:02.113847Z", "localRevision": 9,
                  "updatedAt": "2026-07-18T16:42:55.902310Z", "updatedBy": "rriley" }
      }
    },

    "ackedFindings": {
      "0190e3c1-f2b0-7f65-9056-7d4192c3e645": {
        "at": "2026-07-18T15:11:03.000000Z", "by": "rriley",
        "demotedTo": "advisory",
        "id": "0190e3c1-f2b0-7f65-9056-7d4192c3e645",
        "reason": "Existing condition; corrected in Phase 2 under change order CO-3.",
        "ruleId": "SIG-001",
        "targetEntityId": "0190e3c1-cf81-76cc-87bd-e4c80f3a5dbc",
        "targetFingerprint": "SIG-001:W002:6d2bef45/7e3cb056",
        "meta": { "createdAt": "2026-07-18T15:11:03.000000Z", "localRevision": 1,
                  "updatedAt": "2026-07-18T15:11:03.000000Z", "updatedBy": "rriley" }
      }
    },

    "notes": {},

    "revisionBlock": [
      { "by": "R. Riley", "date": "2026-07-18", "description": "Issued for pricing",
        "issued": false, "rev": "A" }
    ],

    "registries": {
      "connectors": {
        "conn.hdmi_a": { "contacts": 19, "displayName": "HDMI Type A",
                         "genderApplies": false, "id": "conn.hdmi_a",
                         "matesWith": ["conn.hdmi_a"] },
        "conn.rj45":   { "aliases": ["rj45", "8p8c"], "contacts": 8,
                         "displayName": "RJ45", "genderApplies": true,
                         "id": "conn.rj45", "matesWith": ["conn.rj45"] },
        "…conn.de9, conn.iec_c14, conn.f_type elided…": {}
      },
      "media": {
        "media.cat5e":      { "conductorCount": 8, "id": "media.cat5e",
                              "isPathwayOnly": false, "maxChannelLengthNm": 100000000000,
                              "pairCount": 4 },
        "media.cat6a_futp": { "conductorCount": 8, "id": "media.cat6a_futp",
                              "impedanceOhms": 100, "isPathwayOnly": false,
                              "maxChannelLengthNm": 100000000000, "pairCount": 4 },
        "…media.cat6, media.hdmi_passive elided…": {}
      },
      "outletTemplates": {
        "outlet.tv_location": {
          "drops": [ { "count": 2, "media": "media.cat6a_futp", "service": "net.ethernet" },
                     { "count": 2, "media": "media.rg6_quad",  "service": "rf.catv" },
                     { "count": 1, "media": "media.cat5e",     "service": "ctl.ir_emitter" } ],
          "id": "outlet.tv_location", "name": "TV location"
        }
      },
      "signalDomains": {
        "ctl": { "color": "#CC79A7", "colorDark": "#E29CC3",
                 "dashPattern": [1500, 3000], "displayName": "Control", "glyph": "✚",
                 "glyphAlt": "✳", "id": "ctl", "lineWeightPermille": 750,
                 "tagPrefix": "C" },
        "net": { "color": "#009E73", "colorDark": "#2FC79A", "dashPattern": [],
                 "displayName": "Network", "glyph": "■", "glyphAlt": "□", "id": "net",
                 "lineWeightPermille": 1500, "tagPrefix": "N" },
        "…video.digital, video.analog, audio.analog, audio.digital, pwr, str elided…": {}
      },
      "signalFamilies": {
        "ctl.ir_emitter": { "domain": "ctl", "id": "ctl.ir_emitter", "shortTag": "IR",
                            "topologyFree": false },
        "net.ethernet":   { "domain": "net", "id": "net.ethernet",
                            "maxChannelLengthNm": 100000000000, "shortTag": "NET",
                            "topologyFree": false },
        "structure.undetermined": { "domain": "str", "id": "structure.undetermined",
                                    "shortTag": "STR", "topologyFree": false },
        "…video.hdmi.2_0, video.hdbaset, ctl.rs232, ctl.trigger12v elided…": {}
      }
    },

    "tombstones": {
      "0190e3c1-a0c0-7076-8167-8e52a3d4f756": {
        "by": "rriley", "deletedAt": "2026-07-18T13:40:19.000000Z",
        "entityType": "DeviceInstance"
      }
    },

    "meta": { "createdAt": "2026-07-18T09:14:02.113847Z", "localRevision": 412,
              "updatedAt": "2026-07-18T16:42:55.902310Z", "updatedBy": "rriley" }
  }
}
```

### 6.3 What the example is demonstrating

| Line of interest | The ruling it exercises |
|---|---|
| `generator: "RackPal"` | A magic key, so foreign JSON is rejected with a real error rather than a null-cast crash (CR-092). |
| `sequence: 412` at the root, no `revision` key | CR-094. `stateId` is in-memory and absent from the file. |
| `usableDepthNm`, `weightCapacityUg`, `mountHeightAffNm` | N4: the unit is in the name. All integers (CR-001, CR-003). |
| The matrix template carries `weightUg` and `bodyDepthNm`; the patch panel carries **neither** | `null` means unknown and is written as an **absent key**, never an explicit `null` (G4, CR-114). The rack rollup reports the panel in its unknown count rather than adding a fabricated zero; `RCK-012` skips it. |
| `ruIndex: 9` on a 2U device in a 12U rack | 1-based, bottom origin (CR-025). The matrix occupies U9–U10. |
| `placement.type: "rail" \| "offRack"` | The sealed-union tag. No elevation X/Y anywhere in the file (CR-006). |
| Four templates, all content-addressed and embedded | The file is self-describing; a snapshot can never be a sync conflict (CR-054, AC-015). |
| Only **five** ports serialized across four devices | Lazy materialisation. The switch's other 23 ports, the panel's other 46 and the matrix's other 8 are key-joined at load (AC-006). |
| Port IDs are UUID**v5** while entity IDs are v7 | `uuidv5(deviceId, portKey)` makes materialisation idempotent across peers (AC-006). |
| `W001` has `structureOrigin` and one `PlaceEndpoint` | A home run **is** a Link. There is no `StructureDrop`, one length, one status (CR-107, AC-019). |
| `W001.services[0].signalFamily == "structure.undetermined"` | At rough-in a Cat6 is just a Cat6; the family is assigned later and the DRC re-validates. |
| `W002.linkClass == "jumper"` | Excluded from the pull sheet by default so 110 factory patch cords do not bury 70 real pulls (AC-026). |
| `W003` has three `Service`s over three conductors | One Cat5e carrying IR, a 12 V trigger and RS-232 (CR-010, AC-021). |
| `W003` mixes `PortEndpoint`, `PlaceEndpoint` and `OpenEndpoint` | The sealed endpoint union (AC-018). |
| `W004.lifecycleStatus == "designIntent"` | A cable scheduled to a device that does not exist yet (AC-018). |
| `nets` contains implicit unnamed singletons and one named net | `isImplicit` keeps the common case free of ceremony (§3.6). |
| `ackedFindings` present, `findings` absent | Findings are computed; only acknowledgements persist (§5.8). |
| `ruleOverrides["RCK-013"]` carries a reason, author and timestamp | The bare `Map<String, Severity>` had nowhere to put the justification that prints (CR-019). |
| `scaleNumerator: 0, scaleDenominator: 0` | `NTS`. A ratio is printed only when fit-to-page snaps within 2% (CR-118). |
| `tombstones` non-empty | Ships in v1 (CR-095, G5). |
| `registries` embedded, elided to the referenced subset | Requirement-4 colour lives on `signalDomains`, not on 43 families (CR-078). |

### 6.4 `.rpdx`: the single-template file

A `.rpdx` is one `TemplateBody` plus its identity, in plain JSON, under the **same unit regime** as `.rppj`, `depthNm`, `weightUg`, integers throughout (CR-063). ~~Its `identity.` / `physical.` / `power.` sections are a **file layout only**; the codec flattens them onto `TemplateBody` (CR-053).~~ **Superseded by DR-100 §11.99: there are no sections.** The file is five envelope keys (`schemaVersion`, `kind`, `templateId`, `version`, `contentHash`) over a `body` that is `templateBodyToJson`'s own map, verbatim, so the format acquires **no second description of a `TemplateBody`** and inherits CR-117's gate instead of drifting from it. The sectioned layout was drawn in docs/06 §7.3 and placed 18 of the encoder's 39 keys; `model` was one of the 21 it dropped. It has its own migration chain (AC-050/A8.2), starting at `schemaVersion` 1 independent of `.rppj`'s 2, and a newer one is **refused rather than opened read-only**, because AC-012 makes `TemplateBody` closed with no `unknown` passthrough, so there is nothing to open read-only with. The `signature` field and the provenance chain are **cut from v1** (AC-042); single `.rpdx` export and import stay, because that is the unit people email each other.

**`.rpda`: the device archive.** Many `TemplateBody` in one file: a manifest plus an array, in the `.rpdx` unit regime, reusing the `.rpdx` migration chain rather than inventing a second one. **A single JSON file, not a zip**: DR-015 §11.15.4 has the argument, and it is CR-091's argument applied a second time: the zip in the original `.rmlib` spec existed to carry per-face device images, images are cut (AC-057), and a zip of pure JSON buys compression at the cost of the whole zip-slip / entry-count / decompression-bomb surface D8 lists as needed-and-absent. It carries **neither `signature` nor `provenance`**: AC-042 kept `contentHash` and cut the cryptographic apparatus, and an archive needs only the half that was kept. **This renames `.rmlib` and re-opens the part of AC-042 that cut it**: a scope edit under roadmap §8.3, ruled in DR-015 and not yet built.

---

## 7. Schema versioning and the migration chain

Two integers, and they do different jobs (CR-092, CR-093):

| Field | Meaning | Reader behaviour |
|---|---|---|
| `schemaVersion` | The version this file was written at. | `> kSchemaVersion` and `minReaderVersion <= kSchemaVersion` ⇒ open **read-only** with a banner, preserving unknown fields for Save As. |
| `minReaderVersion` | The oldest reader that can safely round-trip this file. | `> kSchemaVersion` ⇒ **refuse**. A genuinely breaking change happened. |

> **`kMinReaderVersion` IS 2, AND THAT SENTENCE IS ABOUT WHAT WE WRITE RATHER THAN HOW WE READ.** The two rows above describe how a reader treats a file it is handed. The constant decides what goes INTO every file this build saves, and it moved to 2 with `migrateV1ToV2`: so **a v1 reader refuses a file written today** rather than opening it read-only, which is the row above running in the other direction. That is correct and deliberate, because v1 had no `sequence` and a v1 reader silently round-tripping a v2 document would drop it. It is written down here because raising the constant is a one-line change with a product consequence, and the consequence lived in nobody's head (docs/12 §4.7).

Migration returns an `Outcome<T>`, never an exception (CR-093), the source snippet's `throw NewerSchemaException` is a control-flow defect in a path that must degrade gracefully.

```dart
const kSchemaVersion = 2;
typedef JsonMap  = Map<String, Object?>;
typedef Migration = JsonMap Function(JsonMap);

/// APPEND-ONLY. Frozen the moment a version ships. A migration is a historical
/// record — editing one corrupts users' files.
const migrations = <int, Migration>{
  0: _v0ToV1,      // synthetic, and it exists to prove the chain runs
  1: _v1ToV2,      // the first REAL one. Never deleted. Never edited.
};

sealed class LoadOutcome { }
final class LoadOk       extends LoadOutcome { final JsonMap raw; final bool openReadOnly; }
final class LoadErr      extends LoadOutcome { final LoadError error; }

enum LoadError { notARackPalDocument, newerSchemaRefused, corruptEnvelope }

LoadOutcome migrateToCurrent(JsonMap raw) {
  if (raw['generator'] != 'RackPal') {
    return LoadErr(LoadError.notARackPalDocument);
  }
  final minReader = raw['minReaderVersion'] as int? ?? 1;
  if (minReader > kSchemaVersion) {
    return LoadErr(LoadError.newerSchemaRefused);      // cannot safely round-trip
  }
  var v = raw['schemaVersion'] as int;
  if (v > kSchemaVersion) {
    // Readable but not fully understood. Unknown fields are preserved so a
    // later Save As does not destroy them.
    return LoadOk(raw, openReadOnly: true);
  }
  while (v < kSchemaVersion) {
    raw = migrations[v]!(raw);
    v = raw['schemaVersion'] as int;                   // each migration bumps its own version
  }
  return LoadOk(raw, openReadOnly: false);
}
```

Five commitments made on day one:

1. **Migrations are pure functions on raw `Map<String, Object?>`, never on typed objects.** Migrate the map fully, *then* deserialize. Typed migration requires keeping every historical class shape alive in the codebase forever.
2. **`schemaVersion` + `minReaderVersion` together** give both directions, forward-readable and explicitly-refused, rather than one blunt gate.
3. **Golden fixture corpus.** `test/fixtures/v1_sample.rmpj`, `v2_sample.rmpj`, … Every release, one test opens *every* historical fixture and asserts it migrates to a valid current document. A fixture is added the day each version ships. Highest value-per-line test in the project; see [Testing and quality](11-testing-and-quality.md).
4. **Enums are strings, never ordinals.** `"rackEars"`, not `3`. Unknown enum values fall back to an `unknown(raw)` variant that round-trips rather than throwing.
5. **Additive-only within a major.** Deprecate, never remove or rename. Unknown keys are routed to `unknown` on read and re-emitted verbatim on write, so a v1.0 app opening a v1.4 file round-trips without destroying newer data.

Rejected alternative: **generated codecs** coupled to class shape. Hand-written codecs are more typing and they are the reason the format survives a refactor; the file format is the product's most durable asset.

---

## 8. Cloud-readiness properties

There is no CRDT and no sync in v1. Rack design is overwhelmingly single-user-at-a-time and no Dart CRDT library is production-grade. But six properties hold from commit one, each nearly free today and each a rewrite to retrofit (G5, CR-095).

| # | Property | What it buys | What its absence would cost |
|---|---|---|---|
| 1 | **Flat entity maps, never a nested tree.** `Map<Uuid, Port>` sits beside `Map<Uuid, DeviceInstance>`; a `Port` carries `deviceId` and is not nested inside its device. | Per-entity sync units; O(1) command application; O(1) lookup on the routing hot path; fine-grained repaint invalidation. | Rewriting every command. |
| 2 | **No positional index is ever identity.** Ordering uses `FracIndex` (LexoRank: `"a0"`, `"a0V"`, `"a1"`), CR-027. | Inserting between two items is a purely local edit that cannot collide. | Integer `sortOrder` requires renumbering neighbours, and neighbour-renumbering is precisely what makes sync unretrofittable. |
| 3 | **Per-entity LWW metadata on conflict units, from day one.** `EntityMeta{createdAt, updatedAt, updatedBy, localRevision}`, CR-095. | The last-write-wins tuple already exists when sync arrives. | A migration that cannot backfill honest values; every existing entity gets a lie for `updatedAt` and the first sync resolves conflicts wrongly. |
| 4 | **UUIDv7 entity IDs; deterministic UUIDv5 for template-derived ports.** | Time-ordered IDs, a free stable creation-order sort, index locality, and cross-peer idempotent port materialisation (AC-006). | Random IDs make lazy materialisation produce divergent ports on two machines. |
| 5 | **Tombstones.** `Map<Uuid, Tombstone>`: CR-095. | Sync can distinguish "the peer deleted this" from "the peer never had it". Delete commands become trivially invertible for undo, and the history panel is free. | Deleted devices resurrect on every sync. This is the one thing that genuinely cannot be retrofitted. |
| 6 | **`sequence` as the document-level monotonic cursor**: CR-094. | Already needed for dirty-tracking; doubles as the sync cursor. | A second counter, and the `revision`/`stateId` conflation the record had to resolve. |

Which entities can conflict, and which structurally cannot:

| Entity | Conflict unit? | Reasoning |
|---|---|---|
| `RackDocument` (info, settings) | yes: field-level LWW | Small, rarely edited concurrently. |
| `Location`, `Rack`, `Circuit`, `Note`, `RevisionEntry`, `AckedFinding`, `Pathway` | yes: whole entity | Small and independent. |
| `DeviceInstance` **including its `Port`s** | yes: as one unit | A port has no meaning without its device; template migration rewrites all ports atomically. Splitting them would let a sync produce a device whose port set matches neither side. |
| `Link` **including its `Service`s and `Conductor`s** | yes: whole entity | A conductor list is meaningless split. |
| `Net` | yes | Merging two nets is a command, not a field write; concurrent merges conflict honestly. |
| `StructureBody`, `Outlet` | yes: as one unit | Same argument as device + ports; the outlet is the specification atom. |
| `Sheet` + its `SheetItem`s | yes: as one unit | Layout is holistic. |
| `TemplateSnapshot` | **never conflicts** | Immutable and content-addressed. Two peers adding the same `(templateId, version)` produce byte-identical objects; a hash mismatch is an error, not a merge. |
| Registry entries | **never conflicts** | Same reasoning. Custom entries take UUID-suffixed IDs to avoid namespace collision. |
| `Tombstone` | **never conflicts** | Append-only, idempotent. |
| `Finding` | **not synced** | Purely derived; recomputed on both sides. |
| Elevation coordinates | **do not exist** | Derived from `Placement` (CR-006). Nothing to conflict over. |

The design win worth stating plainly: by making templates and registries immutable and content-addressed, and by making elevation geometry and findings derived rather than stored, a large fraction of the document is **structurally incapable** of conflicting. What remains conflictable is small and semantically meaningful.

Sync-hostile constructs deliberately avoided: auto-incrementing integer keys anywhere; "the first element of the list is special" semantics; any entity whose identity is a composite of mutable fields; derived data persisted as authoritative (CR-115). Designators (`MTX-1`, `W042`) are **unique but not identity**: two peers can independently allocate `W042`, and renumbering on merge is a cosmetic fix-up command, not data loss.

**How much further to invest was [question 10.8](canonical-decisions.md), and it is ANSWERED (2026-08-03): (a), spend nothing further. RackPal is a local application.** No sync cursor plumbing, no conflict-resolution implementation, nothing beyond the six properties above, until a user asks twice for two people in one project.

**This section is the page that answer ratifies.** §10.8's recommendation asked for one page stating the intended conflict unit and merge story, so that AC-006's device-plus-ports assumption was recorded rather than folkloric. This is it, and the ruling adopts it as the canonical statement rather than commissioning a new one. Two consequences follow. First, **the six properties are retained in full**: option (c), drop the cloud-ready constraint and simplify, was never available and was not taken, so nothing above is dead weight to be pruned on the grounds that the product is local. Second, the tables above are now load-bearing, and a change to any conflict-unit row is a change to a ruled position, not an edit to derived prose.

---

## 9. Model invariants

Structural invariants (**I-n**) mean the model is *corrupt* if violated: assert on load, then quarantine or repair. They are categorically different from DRC rules (§5), which mean the *design* is questionable and must never corrupt anything. The loader quarantines a referencing entity rather than crashing.

**Primitives and identity**

1. **No `double` appears anywhere in the persisted model.** All lengths are `int` nanometres, masses `int` micrograms, canvas positions `int` grid units, scales `int`/`int`, percentages `int` permille. Enforced by a codec-level assertion and a lint (CR-001, CR-063).
2. Every entity ID is a valid UUIDv7, or a UUIDv5 for a template-derived `Port`, and is **unique across the entire document**, not merely within its map (CR-116, AC-006).
3. Every map key equals its value's `id` field.
4. No entity ID appears in both an entity map and `tombstones`.
5. Every foreign key resolves to a live, non-tombstoned entity, or is explicitly nullable.
6. `sequence` is strictly monotonic across the life of the document and never decreases on save (CR-094).
7. `schemaVersion ≥ minReaderVersion ≥ 1`.
8. **Byte round trip:** `write(read(bytes)) == bytes`, including key ordering inside nested `unknown` maps (CR-117).
9. Fractional index strings are unique among siblings and strictly ordered; ties are repaired on load by re-spacing (CR-027).

**Templates and ports**

10. Every `TemplateSnapshot` is keyed `"$templateId@$version"` and `sha256(canonicalJson(body)) == contentHash`. A mismatch is a **warning plus a badge** on the affected devices, never a load failure, refusing to open a project because a snapshot was hand-edited is a data-loss event dressed as a safety feature (AC-042).
11. Every `DeviceInstance.templateRef` resolves to an embedded `TemplateSnapshot`. There is no `localTemplate` alternative (CR-054).
12. A `TemplateSnapshot` is never mutated after insertion. Editing produces a new `(templateId, version)`. Insertion and removal are refcounted (AC-015).
13. `PortDef.key` is unique within a `TemplateBody`, and no key appears in another `PortDef.renamedFrom` within the same body (CR-051).
14. Every `Port.deviceId` resolves. Every non-null `Port.templatePortKey` resolves in the device's snapshot **or** `orphaned == true`. A removed port carrying conductors is orphaned, never deleted (CR-052).
15. `Port.designator` is unique **within its device** (CR-042). A project-wide duplicate is not an error.
16. A `PassthroughPairDef`'s two keys resolve to ports on the same device with **opposite `face`** values (CR-057).
17. `DeviceInstance.portIds` is a derived index, rebuilt on load, and is **never serialized** (CR-115).

**Placement**

18. `RailPlacement.ruIndex ∈ [1, rack.heightU]` and `ruIndex + effectiveU − 1 ≤ rack.heightU`. Always bottom-origin; `ruNumbering` affects display only (CR-025, CR-026).
19. `startTwelfth ∈ [0,11]`, `spanTwelfths ∈ [1,12]`, `startTwelfth + spanTwelfths ≤ 12` (CR-030).
20. No two devices overlap in `(rackId, face, ruIndex range, twelfth range)`. Front and rear occupancy are computed independently from `frontU`/`rearU`, the physical arbitration between them is `RCK-012`, a rule, not an invariant (I-20, AC-022).
21. `ShelfPlacement.hostDeviceId` resolves to a device whose snapshot has `isContainer == true`; the containment graph is acyclic and at most one level deep in v1.
22. A shelf-hosted device consumes zero rack RU of its own.
23. `ZeroUPlacement.channelId` resolves in `rack.zeroUChannels` and `offsetFromChannelStart` lies within the channel.
24. A `structure`-kind device has `OffRackPlacement` and a non-null `structureBodyId`; a non-structure device has a null `structureBodyId` (CR-110).
25. Elevation X/Y is **never** present in the file (CR-006).

**Wiring**

26. Every `Link` has ≥ 1 `Conductor` and ≥ 1 `Service`.
27. Every `Conductor` spans **exactly two** `Endpoint`s. A `Link` may reference N devices via `Breakout`s (CR-014, AC-029).
28. Every `PortEndpoint.portId` resolves to a live port. `PlaceEndpoint` and `OpenEndpoint` resolve to nothing by design and are legal (AC-018).
29. `Service.netId` is non-null and resolves. Removing the last service from a non-implicit net leaves the net orphaned but alive, user data is preserved; implicit empty nets are garbage-collected (CR-010, CR-011).
30. `Link.designator` is unique project-wide.
31. `Link.dominantSignalFamily` is derived and never serialized (CR-009, CR-115).
32. No `Link` carries route geometry. `waypointsBySheet`, `routeOverrides` and `RouteWaypoint` do not exist in v1 (CR-012).
33. `Service.conductorRoles` entries resolve to `Conductor.role` values on the same Link.

**Structure**

34. `Link.structureOrigin.outletId` resolves, and its `structureBodyId` matches that outlet's `structureBodyId`.
35. `StructureOrigin.fieldLabel` is **unique project-wide across all Structure bodies**: labels get printed on physical cable and must not collide across panels (CR-113). `rackLabel` is unique project-wide when non-null.
36. `Outlet.roughInStatus` is derived as the **minimum** across its member Links and is not serialized (CR-111, CR-115).
37. An `Outlet` holds no member list; membership is the reverse key `Link.structureOrigin.outletId` (AC-019).
38. A `Pathway` referenced by `Link.pathwayId` or `Outlet.pathwayId` resolves. `MediaTypeDef.isPathwayOnly` entries create `Pathway`s, never Links and never Ports (CR-109).

**Sheets, findings, registries**

39. `Sheet.number` is unique project-wide. It is **not** pattern-validated against the NCS regex; the scheme is `ProjectSettings.sheetNumbering` and defaults to `simple` (CR-066, m17).
40. `SheetItem.targetId` resolves and is of a kind the sheet's `kind` can display; `rotationQuarterTurns ∈ {0,1,2,3}`.
41. There is **no** legend-note invariant. The exporter auto-fills `SYMBOL LEGEND: SEE SHEET T0.01` (CR-023).
42. `AckedFinding.ruleId` is preserved even when unknown to this build (forward compat, AC-011). A stale acknowledgement (one whose `targetFingerprint` is no longer produced by any current finding) is garbage-collected on load with a log entry, so an acknowledgement can never silently suppress a *different* problem than the one the user reviewed.
43. Every `SignalFamilyId` / `ConnectorTypeId` / `MediaTypeId` referenced anywhere resolves in the embedded registries, **or** degrades to an `unknown(rawId)` placeholder that round-trips, renders grey with the raw id as its tag, and never throws.
44. `Circuit.continuousLimitAmps` is derived, never stored, so the 80% figure cannot drift out of sync with the breaker rating. **It is a planning estimate, not an NEC load calculation** (DR-079 §11.78.4).
45. Nothing in this list blocks an export (G3, CR-022).

---

## 10. Load-bearing choices, in one table

| # | Decision | Rejected alternative | Cost of getting it wrong | Ruling |
|---|---|---|---|---|
| 1 | `Len` = int64 nanometres | tenths-mm, hundredths-mm, float mm | Rounding in every dimensioned print; a format migration touching every entity | CR-001, CR-002 |
| 2 | `Link` → `Service` → `Conductor`, plus a stored `Net` | A pure edge list, or a pure hypergraph, or one `Connection` | No multi-service cables, or no cable schedule, or no bus semantics | CR-008, CR-010, CR-011 |
| 3 | Endpoints are a sealed union | Both ends must be live ports | No pull sheet before the equipment list: the tool is used at the end of the job, if at all | AC-018 |
| 4 | A home run **is** a Link | `StructureDrop` + `Link` | Two lengths, two statuses, two test results, guaranteed to diverge in a week | CR-107, AC-019 |
| 5 | Embedded immutable versioned snapshots; copy-on-place | A live library reference | Non-reproducible deliverables; drawings that change silently across machines | CR-054, AC-041 |
| 6 | `PortDef.key` + `renamedFrom` as the migration join | A port UUID | Every template revision rewires the project | CR-051 |
| 7 | Three orthogonal registries | One `CableType` enum | The HDBaseT-into-a-switch class of error becomes inexpressible | CR-008, §6.1 |
| 8 | Findings + acknowledgement; only the eight tier-1 rules block | A static hard-illegal tier | Cannot document an existing miswired system, the remediation market | CR-017, CR-019 |
| 9 | Nothing blocks export | `blockExportOnErrors` | A heuristic holds the deliverable hostage; users export a PNG into Word | CR-022, G3 |
| 10 | `ruIndex` 1-based, bottom origin | 0-based `bottomU` | The elevation says U7 and the label says U8 | CR-025 |
| 11 | Elevation derived; schematic stored in integer gu; no route geometry | Stored elevation coords; persisted polylines | Drawing/RU divergence; unstable round-trips; an unroutable authored drawing | CR-006, CR-004, CR-012 |
| 12 | Flat UUIDv7 maps, fractional indices, LWW meta, tombstones | Nested tree, integer sort order, hard deletes | Sync is a rewrite instead of a weekend | CR-095, CR-027 |
| 13 | Hand-written codecs, two version integers, frozen append-only migrations, golden corpus, unknown-field preservation | Generated codecs coupled to class shape | The format, the most durable asset in the product, breaks on every refactor | CR-092, CR-093 |
| 14 | Lazy port materialisation with deterministic port IDs | Every port serialized | A ~1 MB port map at the design's own target, invalidating the plain-JSON argument | AC-006 |
| 15 | `null` means unknown; rollups report their unknown count | `Extent{Known, Unknown}`; silent estimates | Fabricated numbers the user cannot see, on a document someone bills against | CR-114, AC-039, G4 |


