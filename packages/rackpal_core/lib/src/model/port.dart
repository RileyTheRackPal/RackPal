// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:uuid/uuid.dart' as pkg_uuid;

// docs/02-data-model.md §4.5. Port deliberately carries NO `EntityMeta`
// (CR-095) and NO Uuid identity of its own beyond what's derived below —
// it is a conflict unit of one, joined to its device.

/// Fixed namespace UUID for deterministically deriving template-bound
/// port IDs via UUIDv5(deviceId, portKey) (CR-116, AC-006): two peers
/// that independently materialise the same (device, port) pair produce
/// the identical ID, which is what makes materialisation idempotent
/// across peers. Generated once and frozen forever — changing it would
/// silently re-key every already-saved project's ports.
const String kPortIdNamespace = '3f9d9b0e-2b8a-4b7a-9b8b-6d6a6e9f2c3d';

/// Deterministically derives a template-derived port's id:
/// `uuidv5(deviceId, portKey)` (CR-116, AC-006, §4.5).
Uuid derivePortId(Uuid deviceId, PortKey portKey) {
  const generator = pkg_uuid.Uuid();
  final id = generator.v5(kPortIdNamespace, '${deviceId.v}:${portKey.v}');
  return Uuid(id);
}

/// Per-instance overrides of a `PortDef`'s facts — typed, nullable fields.
/// Lives on the `Port` itself, never in a device-keyed map (CR-053).
///
/// ─────────────────────────────────────────────────────────────────────
/// `label` IS DELETED, AND IT WAS A DUPLICATE (`#233`)
/// ─────────────────────────────────────────────────────────────────────
/// It meant "what this jack is called on this instance", which is exactly
/// what [Port.userLabel] means, and `userLabel` is the one with a reader:
/// `derived/schedule.dart` has printed it in the port-label column since
/// DR-054. This one was read by nothing at all.
///
/// That is DR-098 §11.97.4's finding on a different class and it gets the
/// same answer: two spellings of one fact is how a document comes to say
/// it two different ways, and the field with a consumer survives. Every
/// override block in the shipped corpus is empty, so this was a deletion
/// rather than a migration.
///
/// TWO STATES, NOT DR-098's THREE, and the third is deferred with a named
/// trigger rather than forgotten. `DeviceOverrides` is tri-state because
/// `null` was fabricating a rollup TOTAL; nothing here feeds a total.
/// These two feed predicates, and the predicates are M5's `CON-001` and
/// `SIG-002`, neither of which exists. The addition is purely additive
/// when M5 wants it (an absent `cleared` key means nothing cleared), so
/// building it now would add a state with no reader.
final class PortOverrides {
  PortOverrides({this.connector, this.signalFamily});

  ConnectorTypeId? connector;
  SignalFamilyId? signalFamily;
}

/// Live network configuration on a `Port` — hostname/IP/VLANs/etc.
///
/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.5.
/// Fields transcribed from docs/research/design-data-model.md line 527
/// (`{hostname, ip, subnet, gw, mac, vlans[], portRole}`); no worked JSON
/// example exists for this type.
final class NetworkConfig {
  NetworkConfig({
    this.hostname,
    this.ip,
    this.subnet,
    this.gw,
    this.mac,
    List<int>? vlans,
    this.portRole,
  }) : vlans = vlans ?? [];

  String? hostname;
  String? ip;
  String? subnet;
  String? gw;
  String? mac;
  List<int> vlans;

  /// e.g. "access" | "trunk" — value set not yet specified.
  String? portRole;
}

/// The negotiated PoE outcome on a live port — distinct from the
/// template's declarative `PoeSpec` (capability vs. actual).
///
/// M0 MINIMAL SHAPE: full spec pending, see docs/02-data-model.md §4.5.
/// docs/research/design-data-model.md line 533 describes this only as
/// "negotiated class <= port capability"; no field list is given.
final class PoeAssignment {
  PoeAssignment({this.poeClass, this.negotiatedWatts});

  /// Negotiated PoE class number (0-8).
  int? poeClass;
  int? negotiatedWatts;
}

/// One connector on a device instance — lazily materialised: only
/// serialized if it carries project state (a conductor endpoint, an
/// override, a pinned designator, network config, a bus address, a tap
/// wattage, or a reserve/orphan flag); the rest are reconstructed at load
/// by key-joining `TemplateBody.ports` against the device (AC-006). That
/// join logic is a persistence-layer concern for a later milestone — this
/// type only models the entity itself.
final class Port {
  Port({
    required this.id,
    required this.deviceId,
    required String designator,
    this.templatePortKey,
    PortOverrides? overrides,
    String? userLabel,
    this.orphaned = false,
    this.reserved = false,
    this.network,
    this.busAddress,
    this.busUniverse,
    this.isBusTerminator,
    this.tapWatts,
    this.lowZBypass = false,
    this.circuitId,
    this.poeActual,
    String? notes,
    Map<String, Object?>? unknown,
  }) : overrides = overrides ?? PortOverrides(),
       _userLabel = userLabel,
       _designator = designator,
       _notes = notes,
       unknown = unknown ?? {};

  /// `uuidv5(deviceId, portKey)` when template-derived (see
  /// [derivePortId]); a random UUIDv7 for instance-added ports.
  final Uuid id;
  final Uuid deviceId;

  /// Null for instance-added ports.
  final PortKey? templatePortKey;

  String? _userLabel;
  String? get userLabel => _userLabel;
  @internal
  set userLabel(String? v) => _userLabel = v;

  /// "J01" — unique within the device (CR-042).
  String _designator;
  String get designator => _designator;
  @internal
  set designator(String v) => _designator = v;

  String? _notes;
  String? get notes => _notes;
  @internal
  set notes(String? v) => _notes = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// Typed; lives here, not in a device-keyed map (CR-053).
  PortOverrides overrides;
  bool orphaned;
  bool reserved;
  NetworkConfig? network;
  int? busAddress;
  int? busUniverse;
  bool? isBusTerminator;

  /// 70/100 V transformer tap, in watts: per INSTALLATION, not per
  /// template.
  ///
  /// **NOTHING WROTE OR READ THIS UNTIL DR-131 §11.130** (`#838`). It was
  /// modelled with the right home and the right doc comment, round-tripped
  /// by the codec, and reachable by no gesture: the NINTH producer gap of
  /// M5, and `catalog_field.dart`'s header had said so in as many words,
  /// that no rule *"reads `impedanceOhms`/`tapWatts` from at all"*.
  ///
  /// NULL IS UNKNOWN, and `0` would be a measured zero (G4/CR-114). A 70 V
  /// bus rollup counts an unknown rather than treating it as no load: a
  /// speaker whose tap nobody recorded still draws from the amplifier.
  ///
  /// TYPED RATHER THAN PICKED FROM A LADDER (DR-131 §11.130.8). There is
  /// no single ladder: Episode ships 7.5/15/30/60, Beale Street ranges
  /// from 1/1.9/3.8/7.5/15 to that same scheme, and `F08`'s own
  /// description hard-codes a third set. Any fixed list is wrong on
  /// somebody's speaker.
  ///
  /// Meaningless while [lowZBypass] is true. Read the pair through
  /// [isConstantVoltage] rather than separately.
  int? tapWatts;

  /// Whether the transformer is bypassed, making this a low-impedance
  /// connection.
  ///
  /// **THIS IS THE CV-to-LOW-Z SWITCHING DR-125 FOUND MISSING**, and it
  /// is on the SPEAKER because that is where the switch physically is.
  /// The question went to the user as an AMPLIFIER mode and the premise
  /// was wrong: amplifiers are rarely switchable, and one that does both
  /// has separate outputs rather than a switch. `A05` already models
  /// exactly that, with two `audio.speaker_cv` bus nodes and no low-Z
  /// output at all.
  ///
  /// `ELE-006` reads it. A bypassed speaker landed on a low-Z output is
  /// CORRECT, and the rule fired on it before this existed.
  bool lowZBypass;

  /// Whether this port is presently a constant-voltage load.
  ///
  /// The pair's precedence in one place, so a reader cannot get it
  /// backwards: **bypass wins over any tap value**, because the
  /// transformer the tap would have been read from is out of circuit.
  bool get isConstantVoltage => !lowZBypass;

  /// Only set where the rack meets the building.
  Uuid? circuitId;
  PoeAssignment? poeActual;

  /// Forward-compat / passthrough for fields this reader does not model.
  final Map<String, Object?> unknown;

  // NO EntityMeta (CR-095).
}
