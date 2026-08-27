import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart' show LifecycleStatus;
import 'package:rackpal_core/src/model/sheet_item.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// cover|legend|exceptions|elevationFront|elevationRear|schematic|
/// wiringSchedule|dropSchedule|equipmentList|networkSchedule|
/// powerSchedule|pullSheet.
enum SheetKind {
  cover,
  legend,
  exceptions,
  elevationFront,
  elevationRear,
  schematic,
  wiringSchedule,
  dropSchedule,
  equipmentList,
  networkSchedule,
  powerSchedule,
  pullSheet,
}

/// The physical paper an exported sheet targets.
///
/// M0 MINIMAL SHAPE: docs/02-data-model.md declares only
/// `PaperSize paper` with no enumerated values. The set below is
/// transcribed from docs/08-pdf-export.md (the `PdfPageFormat` native
/// sizes `a3, a4, a5, a6, letter, legal, roll57, roll80`, plus the
/// custom `ansiA..ansiD` sizes the product actually uses for its sheet
/// set — line ~468-487).
enum PaperSize {
  ansiA,
  ansiB,
  ansiC,
  ansiD,
  a3,
  a4,
  a5,
  a6,
  letter,
  legal,
  roll57,
  roll80,
}

/// portrait|landscape — a page's print orientation.
///
/// Named `PageOrientation` rather than bare `Orientation` because
/// `ZeroUPlacement` needs an unrelated *spatial* orientation
/// (horizontal/vertical) — colliding two different concepts on one enum
/// name is exactly what docs/02-data-model.md §4.8 warns against. See
/// `ZeroUOrientation` in placement.dart.
enum PageOrientation { portrait, landscape }

/// The one permanent schematic sheet (DR-004, CR-073, AC-037). Exactly
/// one is created per project in practice — a document-construction rule
/// for a later stage, not something this class enforces structurally.
/// The exporter partitions it into N interconnect sheets by domain
/// filter; that partition is never itself authored or stored here.
final class Sheet {
  Sheet({
    required this.id,
    required this.number,
    required this.title,
    required this.order,
    required this.meta,
    this.kind = SheetKind.schematic,
    this.paper = PaperSize.ansiB,
    this.orientation = PageOrientation.landscape,
    this.scaleNumerator = 0,
    this.scaleDenominator = 0,
    this.carriesLegend = false,
    List<Uuid>? includedRackIds,
    List<Uuid>? includedDeviceIds,
    Set<SignalDomainId>? domainFilter,
    Set<LifecycleStatus>? lifecycleFilter,
    Map<Uuid, SheetItem>? items,
  }) : includedRackIds = includedRackIds ?? [],
       includedDeviceIds = includedDeviceIds ?? [],
       domainFilter = domainFilter ?? {},
       lifecycleFilter = lifecycleFilter ?? {},
       items = items ?? {};

  final Uuid id;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// "T2.01" (ncs) or "2" (simple) (CR-066).
  String number;
  String title;
  SheetKind kind;
  PaperSize paper;
  PageOrientation orientation;

  /// 0/0 means NTS (not to scale). Fit-to-page, snapped within 2%
  /// (CR-118).
  int scaleNumerator;
  int scaleDenominator;

  /// `legendLocationNote` is AUTO-FILLED at export (CR-023).
  bool carriesLegend;
  List<Uuid> includedRackIds;
  List<Uuid> includedDeviceIds;
  Set<SignalDomainId> domainFilter;

  /// The useful half of "layers" (CR-067).
  Set<LifecycleStatus> lifecycleFilter;
  Map<Uuid, SheetItem> items;
  FracIndex order;
  EntityMeta meta;
}
