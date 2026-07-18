// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/rgb.dart';

/// p2p|star|daisyChain|passiveSplit|bus. Distinct from `PortTopology`
/// (template.dart), which describes a single port rather than a net.
enum NetTopologyKind { p2p, star, daisyChain, passiveSplit, bus }

/// The STORED logical equivalence class a `Service` belongs to
/// (`Service.netId`, CR-011). A pure derived structure (union-find at
/// read time) cannot carry the user's net name, colour override, notes,
/// universe number or terminator assignment, and cannot be a sync
/// conflict unit — so unlike its name suggests, `Net` is not derivable.
final class Net {
  Net({
    required this.id,
    required String name,
    required this.signalFamily,
    required this.meta,
    String? designator,
    this.topology = NetTopologyKind.p2p,
    this.colorOverride,
    this.isImplicit = true,
    this.busTerminatorPortIdA,
    this.busTerminatorPortIdB,
    this.busUniverse,
    this.nominalVoltage,
    String? notes,
  }) : _name = name,
       _designator = designator,
       _notes = notes;

  final Uuid id;

  /// Generated, editable, NEVER load-bearing (CR-049).
  String _name;
  String get name => _name;
  @internal
  set name(String v) => _name = v;

  /// "N012".
  String? _designator;
  String? get designator => _designator;
  @internal
  set designator(String? v) => _designator = v;

  String? _notes;
  String? get notes => _notes;
  @internal
  set notes(String? v) => _notes = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  SignalFamilyId signalFamily;
  NetTopologyKind topology;
  Rgb? colorOverride;

  /// Auto singleton for a lone P2P service; becomes explicit the moment
  /// a second service joins or the user names it.
  bool isImplicit;
  Uuid? busTerminatorPortIdA;
  Uuid? busTerminatorPortIdB;
  int? busUniverse;
  int? nominalVoltage;
  EntityMeta meta;
}
