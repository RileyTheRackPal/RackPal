// rackpal_core/src/derived/network_table.dart — pure Dart.
//
// THE ONE DERIVATION BEHIND THE DEVICES VIEW AND `T6.50` (DR-048, DR-226,
// DR-227). Which devices, in what order, and every cell string, so the table
// a tech types into and the schedule they print are the same strings from
// the same function: CR-107's rule, and `structure_table.dart`'s for the
// runs.
//
// ═══════════════════════════════════════════════════════════════════════
// WHO IS NETWORK-CAPABLE (DR-227 §11.226.2)
// ═══════════════════════════════════════════════════════════════════════
// A device is listed by default when its template has a port in the
// Network domain and is NOT A PASSTHROUGH, or its template says it has
// Wi-Fi, or it already carries a network value or a MAC. A passthrough
// (a patch panel, a fibre enclosure) carries Network ports and never an
// address of its own: on all four starters `isPassthrough` is exactly the
// set the port rule wrongly listed. *Show all devices* lists everything.
//
// THE "ALREADY CARRIES A VALUE" ARM IS NOT A CONVENIENCE. Without it a
// device given an address under Show all, or one whose template later
// lost its Wi-Fi flag, would vanish from the default list while still
// printing on `T6.50`, and a sheet that names a device the table hides is
// the disagreement this file exists to prevent.
//
// ═══════════════════════════════════════════════════════════════════════
// AN UNDATED VALUE IS UNVERIFIED, NEVER A FACT (DR-048 §11.47.3)
// ═══════════════════════════════════════════════════════════════════════
// [NetworkRow.verifiedText] says so in words. A surface that prints an
// address without its date has thrown the ruling away.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_loads.dart'
    show bodyFor, hostRackOf;
import 'package:rackpal_core/src/derived/schedule.dart' show compareDesignators;
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart' show NetworkOrder;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The Network domain's id, which the seed registry and every document
/// carry (`seed_registries.dart`).
const SignalDomainId kNetworkDomain = SignalDomainId('net');

/// What a row says when nobody has verified its values.
const String kUnverified = 'unverified';

/// One device's row.
@immutable
final class NetworkRow {
  const NetworkRow({
    required this.deviceId,
    required this.designator,
    required this.name,
    required this.where,
    required this.hostname,
    required this.ip,
    required this.subnet,
    required this.gateway,
    required this.mac,
    required this.vlans,
    required this.verifiedOn,
  });

  final Uuid deviceId;
  final String designator;
  final String name;

  /// `RK-1 · U12` for a rack device, the room's name for one in a room, or
  /// null when the model says neither.
  final String? where;

  final String? hostname;
  final String? ip;
  final String? subnet;
  final String? gateway;

  /// `DeviceInstance.macAddressPrimary`, the device MAC's one home
  /// (DR-226 §11.225.4).
  final String? mac;

  final List<int> vlans;
  final DateTime? verifiedOn;

  /// Whether any value is stated: what `T6.50` prints a row for.
  bool get hasValues =>
      hostname != null ||
      ip != null ||
      subnet != null ||
      gateway != null ||
      mac != null ||
      vlans.isNotEmpty;

  /// The VLAN cell: `10, 20`, or empty when nobody said.
  String get vlansText => formatVlans(vlans);

  /// The verified cell: the day, or [kUnverified] (DR-048 §11.47.3).
  String get verifiedText =>
      verifiedOn == null ? kUnverified : formatVerifiedOn(verifiedOn!);
}

/// Whether [device] is listed by default (DR-227 §11.226.2).
bool isNetworkCapable(DeviceInstance device, RackDocument doc) {
  if (device.network != null || device.macAddressPrimary != null) {
    return true;
  }
  final body = bodyFor(device, doc.templates);
  if (body == null) return false;
  if (body.wifi ?? false) return true;
  if (body.isPassthrough) return false;
  final families = doc.registries.signalFamilies;
  return body.ports.any(
    (p) => families[p.signalFamily]?.domain == kNetworkDomain,
  );
}

/// Every listed device's row, in [order].
List<NetworkRow> buildNetworkTable(
  RackDocument doc, {
  bool showAll = false,
  NetworkOrder order = NetworkOrder.designator,
}) {
  final listed = <DeviceInstance>[
    for (final d in doc.devices.values)
      if (showAll || isNetworkCapable(d, doc)) d,
  ];
  final keys = {for (final d in listed) d.id: _sortKey(d, doc)};
  listed.sort((a, b) {
    if (order == NetworkOrder.rackThenRoom) {
      final c = _compareKeys(keys[a.id]!, keys[b.id]!);
      if (c != 0) return c;
    }
    final byName = compareDesignators(a.designator, b.designator);
    return byName != 0 ? byName : a.id.v.compareTo(b.id.v);
  });
  return List<NetworkRow>.unmodifiable(<NetworkRow>[
    for (final d in listed)
      NetworkRow(
        deviceId: d.id,
        designator: d.designator,
        name: d.name,
        where: keys[d.id]!.where,
        hostname: d.network?.hostname,
        ip: d.network?.ip,
        subnet: d.network?.subnet,
        gateway: d.network?.gw,
        mac: d.macAddressPrimary,
        vlans: d.network?.vlans ?? const <int>[],
        verifiedOn: d.network?.verifiedOn,
      ),
  ]);
}

/// `10, 20`; the empty string for none.
String formatVlans(List<int> vlans) => vlans.join(', ');

/// Reads a VLAN cell: numbers separated by commas or spaces, each 1 to
/// 4094 (IEEE 802.1Q's usable range). Null when anything else was typed,
/// so the caller can refuse rather than store a guess; an empty cell is the
/// empty list, which is "nobody said".
List<int>? parseVlans(String text) {
  final parts = text
      .split(RegExp(r'[,\s]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  final out = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 1 || n > 4094) return null;
    out.add(n);
  }
  return out;
}

/// Reads a VERIFIED cell: `YYYY-MM-DD` is that day at UTC midnight, and an
/// empty cell or the word `unverified` clears the date. Anything else is
/// invalid, so the caller can refuse rather than store a guess; a date is
/// the whole of DR-048's stale mechanism, and a mistyped one is worse than
/// none.
({bool valid, DateTime? day}) parseVerifiedOn(String text) {
  final t = text.trim();
  if (t.isEmpty || t.toLowerCase() == kUnverified) {
    return (valid: true, day: null);
  }
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(t);
  if (m == null) return (valid: false, day: null);
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final day = DateTime.utc(y, mo, d);
  // DateTime rolls 2026-02-30 over into March; a day that does not read
  // back as itself was not a day.
  if (day.year != y || day.month != mo || day.day != d) {
    return (valid: false, day: null);
  }
  return (valid: true, day: day);
}

/// `2026-10-03`: the calendar day `verifiedOn` holds at UTC midnight.
String formatVerifiedOn(DateTime day) {
  final d = day.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// The rack-then-room key: which rack (by `Rack.order`), how high in it,
/// then which room (by `Location.order`).
typedef _Key = ({
  int group,
  String rackOrder,
  String rackId,
  int ruDescending,
  String roomOrder,
  String roomId,
  String? where,
});

_Key _sortKey(DeviceInstance d, RackDocument doc) {
  final rackId = hostRackOf(d, doc.devices);
  final rack = rackId == null ? null : doc.racks[rackId];
  if (rack != null) {
    final placement = d.placement;
    final ru = placement is RailPlacement ? placement.ruIndex : null;
    return (
      group: 0,
      rackOrder: rack.order.v,
      rackId: rack.id.v,
      // Top unit first; a device with no unit of its own (on a shelf, in a
      // 0U channel) after every unit, as the equipment list orders them.
      ruDescending: ru == null ? 1 << 30 : -ru,
      roomOrder: '',
      roomId: '',
      where: ru == null ? rack.designator : '${rack.designator} · U$ru',
    );
  }
  final room = d.locationId == null ? null : doc.locations[d.locationId];
  return (
    group: room == null ? 2 : 1,
    rackOrder: '',
    rackId: '',
    ruDescending: 0,
    roomOrder: room?.order.v ?? '',
    roomId: room?.id.v ?? '',
    where: room?.name,
  );
}

int _compareKeys(_Key a, _Key b) {
  for (final c in <int>[
    a.group.compareTo(b.group),
    a.rackOrder.compareTo(b.rackOrder),
    a.rackId.compareTo(b.rackId),
    a.ruDescending.compareTo(b.ruDescending),
    a.roomOrder.compareTo(b.roomOrder),
    a.roomId.compareTo(b.roomId),
  ]) {
    if (c != 0) return c;
  }
  return 0;
}

/// The Devices view's columns (DR-226 §11.225.3), in screen order.
///
/// The first three say which device a row is and are always shown; the
/// rest are its network values. [NetworkColumnId.subnet] and
/// [NetworkColumnId.gateway] sit behind the Columns toggle: most jobs use
/// one of each for every device, which is a lot of repeated ink.
enum NetworkColumnId {
  /// `SW-1`. FIRST, the identifier, as the equipment list leads.
  device,
  name,

  /// `RK-1 · U12`, or the room.
  where,
  hostname,
  ip,
  subnet,
  gateway,

  /// The device's MAC: `macAddressPrimary` (DR-226 §11.225.4). Shown by
  /// default at the user's word: WOL, SSDP and SDDP identify by it.
  mac,

  /// Shown by default at the user's word: video distribution runs on them.
  vlans,

  /// The day the row was checked, or `unverified` (DR-048 §11.47.3).
  verified,
}

/// What [id]'s heading says.
String networkColumnHeader(NetworkColumnId id) => switch (id) {
  NetworkColumnId.device => 'DEVICE',
  NetworkColumnId.name => 'NAME',
  NetworkColumnId.where => 'LOCATION',
  NetworkColumnId.hostname => 'HOSTNAME',
  NetworkColumnId.ip => 'IP ADDRESS',
  NetworkColumnId.subnet => 'SUBNET',
  NetworkColumnId.gateway => 'GATEWAY',
  NetworkColumnId.mac => 'MAC',
  NetworkColumnId.vlans => 'VLANS',
  NetworkColumnId.verified => 'VERIFIED',
};

/// Layout width in points, on `pathwayColumnWidth`'s scale.
double networkColumnWidth(NetworkColumnId id) => switch (id) {
  NetworkColumnId.device => 88,
  NetworkColumnId.name => 180,
  NetworkColumnId.where => 120,
  NetworkColumnId.hostname => 150,
  // `255.255.255.255` with a margin; an IPv6 address scrolls in its box.
  NetworkColumnId.ip => 128,
  NetworkColumnId.subnet => 128,
  NetworkColumnId.gateway => 128,
  // `00:11:22:33:44:55`.
  NetworkColumnId.mac => 140,
  NetworkColumnId.vlans => 100,
  // `2026-10-03` or `unverified`.
  NetworkColumnId.verified => 96,
};

/// Whether [id] is typed into. The identity columns are written elsewhere
/// (a designator by its rename command, a location by placement).
bool networkColumnIsEditable(NetworkColumnId id) => switch (id) {
  NetworkColumnId.device ||
  NetworkColumnId.name ||
  NetworkColumnId.where => false,
  _ => true,
};

/// Whether [id] shows when nobody has touched the Columns toggle
/// (DR-226 §11.225.3).
bool networkColumnShownByDefault(NetworkColumnId id) =>
    id != NetworkColumnId.subnet && id != NetworkColumnId.gateway;

/// [row]'s text in [id]: the string the view shows and `T6.50` prints. The
/// empty string where nobody has said, except [NetworkColumnId.verified],
/// which says `unverified` rather than nothing (DR-048 §11.47.3).
String networkCellText(NetworkRow row, NetworkColumnId id) => switch (id) {
  NetworkColumnId.device => row.designator,
  NetworkColumnId.name => row.name,
  NetworkColumnId.where => row.where ?? '',
  NetworkColumnId.hostname => row.hostname ?? '',
  NetworkColumnId.ip => row.ip ?? '',
  NetworkColumnId.subnet => row.subnet ?? '',
  NetworkColumnId.gateway => row.gateway ?? '',
  NetworkColumnId.mac => row.mac ?? '',
  NetworkColumnId.vlans => row.vlansText,
  NetworkColumnId.verified => row.verifiedText,
};
