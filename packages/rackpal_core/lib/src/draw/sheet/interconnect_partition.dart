// rackpal_core/src/draw/sheet/interconnect_partition.dart — pure Dart.
//
// The exporter's domain partition (CR-073, DR-225 §11.224.2): which links
// and which devices each `T6.01…` interconnect sheet draws, and in what
// order the sheets come.
//
// ═══════════════════════════════════════════════════════════════════════
// PARTITION AT EXPORT, NOT MULTI-SHEET AUTHORING (DR-004 §11.4.3)
// ═══════════════════════════════════════════════════════════════════════
// The document holds ONE schematic `Sheet`, and nothing here creates,
// names or populates another. This file reads that one sheet's drawing and
// splits it by `SignalDomainId`; a cable belongs to exactly one domain, so
// the split has no cross-sheet connection to resolve. If this file ever
// grows a reason to write a `Sheet`, it has become the thing DR-004 says is
// never built.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DOMAIN OF A LINK IS READ OFF THE DRAWING, NEVER RE-DERIVED
// ═══════════════════════════════════════════════════════════════════════
// `net_label_layer.dart` decides a link's domain ONCE, from one family per
// link rather than per end, so a balun's two flags cannot land in two
// domains' runs. A second rule here would be a second answer to the same
// question, and the day the two disagreed a cable would print on one
// sheet and be filtered under another on screen. So the partition is the
// full schematic's own `RenderedNetLabel`s, grouped by the domain their
// style already resolved to.
//
// That also settles WHICH links reach a sheet without a rule of its own: a
// label exists exactly when a link has an end on a drawn pin. A home run
// with no device at either end has no label and no sheet, and it is not
// lost: it is `T6.20`'s (DR-220).
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY BANK EXPANDED, OR A CABLE IS LOST BEFORE ITS SHEET IS CHOSEN
// ═══════════════════════════════════════════════════════════════════════
// A collapsed bank (CR-103) draws one vector pin carrying its FIRST
// port's key, so a cable on any other member finds no pin and gets no
// label. Partitioning the canvas's own drawing would therefore drop
// eleven of Whole House's twelve patch-panel runs before any sheet was
// chosen. So the partition is read off a schematic with every bank
// expanded ([allBanksExpanded]), and each sheet then expands the banks
// its own cables land in ([banksWiredBy]), DR-225 §11.224.7.
//
// A label whose domain did NOT resolve belongs to no partition and is
// counted in [InterconnectPartitioning.unresolvedLinkIds], never dropped:
// the exporter names it, for the reason `kUnresolvedDomainFragmentKey`
// exists on screen.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show templateKeyFor;
import 'package:rackpal_core/src/draw/scene/schematic_scene.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The interconnect sheets' order (DR-225 §11.224.2): docs/05 §11.2's
/// figure, `VID · RF · AUD · DIG · NET · CTL · PWR · STR`.
///
/// AN EXPORTER CONSTANT, NOT A FIELD ON `SignalDomainDef`, and the
/// difference is deliberate. `schematic_filter.dart` records that no model
/// field carries this order and that adding one is a model change; the
/// ruling put the order on the sheets and left the filter bar's ascending
/// order alone. A domain not in this list, which no seeded document has,
/// follows in ascending id order, so the order stays total.
const List<SignalDomainId> kInterconnectDomainOrder = <SignalDomainId>[
  SignalDomainId('video.digital'),
  SignalDomainId('video.analog'),
  SignalDomainId('audio.analog'),
  SignalDomainId('audio.digital'),
  SignalDomainId('net'),
  SignalDomainId('ctl'),
  SignalDomainId('pwr'),
  SignalDomainId('str'),
];

/// One interconnect sheet's share of the schematic.
@immutable
final class InterconnectPartition {
  const InterconnectPartition({
    required this.domain,
    required this.linkIds,
    required this.deviceIds,
  });

  final SignalDomainId domain;

  /// The links this sheet draws, in the schematic's own link order (the
  /// order their labels were emitted in), each once.
  final List<Uuid> linkIds;

  /// The devices this sheet draws: every device one of [linkIds] lands
  /// on, ascending by id (DR-225 §11.224.3). Never a device with no link
  /// here, which on paper is CR-074's all-devices sheet.
  final List<Uuid> deviceIds;
}

/// [interconnectPartitionsOf]'s result.
@immutable
final class InterconnectPartitioning {
  const InterconnectPartitioning({
    required this.partitions,
    required this.unresolvedLinkIds,
  });

  /// One per domain with at least one link on a drawn pin, in
  /// [kInterconnectDomainOrder].
  final List<InterconnectPartition> partitions;

  /// Links drawn on screen whose family resolved to no domain, so no sheet
  /// prints them. Counted so the exporter can say so (G4).
  final List<Uuid> unresolvedLinkIds;
}

/// Splits [full], the WHOLE document's schematic drawn with
/// [allBanksExpanded], into interconnect sheets.
///
/// See the file header for why the input is the drawing and not the
/// document, and why its banks must be expanded.
InterconnectPartitioning interconnectPartitionsOf(SchematicScene full) {
  final links = <SignalDomainId, List<Uuid>>{};
  final seenLinks = <SignalDomainId, Set<Uuid>>{};
  final devices = <SignalDomainId, Set<String>>{};
  final unresolved = <Uuid>[];
  final seenUnresolved = <Uuid>{};

  for (final label in full.netLabels) {
    final domain = label.style.domainId;
    if (domain == null) {
      if (seenUnresolved.add(label.linkId)) unresolved.add(label.linkId);
      continue;
    }
    if ((seenLinks[domain] ??= <Uuid>{}).add(label.linkId)) {
      (links[domain] ??= <Uuid>[]).add(label.linkId);
    }
    (devices[domain] ??= <String>{}).add(label.deviceId);
  }

  final present = links.keys.toSet();
  final order = <SignalDomainId>[
    for (final d in kInterconnectDomainOrder)
      if (present.contains(d)) d,
    ...(present.where((d) => !kInterconnectDomainOrder.contains(d)).toList()
      ..sort((a, b) => a.v.compareTo(b.v))),
  ];

  return InterconnectPartitioning(
    partitions: List<InterconnectPartition>.unmodifiable(
      <InterconnectPartition>[
        for (final domain in order)
          InterconnectPartition(
            domain: domain,
            linkIds: List<Uuid>.unmodifiable(links[domain]!),
            deviceIds: List<Uuid>.unmodifiable(
              (devices[domain]!.toList()..sort()).map(Uuid.new),
            ),
          ),
      ],
    ),
    unresolvedLinkIds: List<Uuid>.unmodifiable(unresolved),
  );
}

/// [doc] narrowed to [partition]: its devices and its links, and every
/// other field of [doc] itself.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A VIEW FOR ONE BUILD, NEVER A DOCUMENT ANYBODY KEEPS
/// ═══════════════════════════════════════════════════════════════════════
/// The maps that are not narrowed are [doc]'s OWN instances, shared, not
/// copied: the schematic builders only read, and copying the port and
/// template maps once per sheet would cost a walk of the whole project for
/// nothing. So this must never reach a command, a codec or an undo stack,
/// and nothing here could tell if it did.
///
/// EVERY CONSTRUCTOR PARAMETER IS NAMED, so a field added to
/// `RackDocument` is a compile-time question here rather than a silent
/// default: `interconnect_partition_test.dart` encodes this view and its
/// source and requires them to differ in `devices` and `links` alone.
RackDocument partitionDocument(
  RackDocument doc,
  InterconnectPartition partition,
) {
  final deviceIds = partition.deviceIds.toSet();
  final linkIds = partition.linkIds.toSet();
  return RackDocument(
    id: doc.id,
    appVersion: doc.appVersion,
    createdAt: doc.createdAt,
    modifiedAt: doc.modifiedAt,
    meta: doc.meta,
    schemaVersion: doc.schemaVersion,
    minReaderVersion: doc.minReaderVersion,
    sequence: doc.sequence,
    stateId: doc.stateId,
    info: doc.info,
    settings: doc.settings,
    locations: doc.locations,
    racks: doc.racks,
    devices: <Uuid, DeviceInstance>{
      for (final e in doc.devices.entries)
        if (deviceIds.contains(e.key)) e.key: e.value,
    },
    ports: doc.ports,
    nets: doc.nets,
    links: <Uuid, Link>{
      for (final e in doc.links.entries)
        if (linkIds.contains(e.key)) e.key: e.value,
    },
    pathways: doc.pathways,
    outlets: doc.outlets,
    structures: doc.structures,
    circuits: doc.circuits,
    underlays: doc.underlays,
    sheets: doc.sheets,
    notes: doc.notes,
    ackedFindings: doc.ackedFindings,
    templates: doc.templates,
    registries: doc.registries,
    revisionBlock: doc.revisionBlock,
    tombstones: doc.tombstones,
    unknown: doc.unknown,
  );
}

/// Every bank of every device, as `buildSchematicScene`'s `expandedBanks`:
/// the schematic the partition reads (see the file header).
Map<Uuid, Set<String>> allBanksExpanded(RackDocument doc) =>
    <Uuid, Set<String>>{
      for (final device in doc.devices.values)
        if (doc.templates[templateKeyFor(device.templateRef)]?.body
            case final body? when body.banks.isNotEmpty)
          device.id: <String>{for (final bank in body.banks) bank.key},
    };

/// The banks [linkIds] land in, per device, as `buildSchematicScene`'s
/// `expandedBanks` (DR-225 §11.224.7): a bank one of this sheet's cables
/// lands in prints expanded, and every other bank keeps its collapse.
///
/// EVERY CONDUCTOR, not the first alone. A pair whose second conductor is
/// the only one on a bank still lands in it, and expanding a bank for a
/// conductor the drawing does not label costs some pins and loses nothing.
Map<Uuid, Set<String>> banksWiredBy(RackDocument doc, Iterable<Uuid> linkIds) {
  final out = <Uuid, Set<String>>{};
  for (final id in linkIds) {
    final link = doc.links[id];
    if (link == null) continue;
    for (final conductor in link.conductors) {
      for (final end in <Endpoint>[conductor.from, conductor.to]) {
        if (end is! PortEndpoint) continue;
        final port = doc.ports[end.portId];
        final key = port?.templatePortKey;
        if (port == null || key == null) continue;
        final device = doc.devices[port.deviceId];
        if (device == null) continue;
        final body = doc.templates[templateKeyFor(device.templateRef)]?.body;
        if (body == null) continue;
        for (final def in body.ports) {
          if (def.key != key) continue;
          if (def.bankKey case final bank?) {
            (out[device.id] ??= <String>{}).add(bank);
          }
          break;
        }
      }
    }
  }
  return out;
}
