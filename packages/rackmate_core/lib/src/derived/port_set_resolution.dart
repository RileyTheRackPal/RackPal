// A device's PortSetDef, resolved against the document to the materialised
// ports it names — in the set's DECLARED ORDER.
//
// This exists because `PortDef.setKey` is a join, not a pointer. A template
// declares its sets in `TemplateBody.portSets` and its ports name a set by
// string key, so "the members of this set" is a query nobody had written.
// `test/catalog/port_set_integrity_test.dart` records what the missing
// query cost once already: 72 of 90 port-set references were dangling and
// nothing noticed, because no code had ever tried to walk one.
//
// DECLARED ORDER IS THE SET'S CONTRACT. DR-008 §11.8.3 pairs members "in
// the set's declared order", so the sort here is not cosmetic — it decides
// which conductor lands on which pin. `PortDef.order` is the fractional
// index the template author controls; the `key` tiebreak keeps the result
// total and stable when two ports share an order, which a hand-edited or
// generated template can produce.

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackmate_core/src/model/port.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// One member of a resolved set, at its position in declared order.
@immutable
final class PortSetMember {
  const PortSetMember({
    required this.portKey,
    required this.role,
    required this.portId,
    required this.derivedPortId,
  });

  /// The template's key for this port.
  final PortKey portKey;

  /// `setRole` — "L", "R", "+", "-", "Y", "Pb", "Pr". Null when the
  /// template declares the port in a set but gives it no role, which is
  /// legal and means the position carries the meaning.
  final String? role;

  /// The materialised `Port`, or NULL when the template declares this
  /// member but the document holds no port for it.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THIS IS "DOES THE DOCUMENT HOLD ONE TODAY", NOT "WHICH ID IS IT"
  /// ═══════════════════════════════════════════════════════════════════
  /// The two questions look like one and are not — `connect_target.dart`'s
  /// header argues the same split at length for the pin-to-pin path, where
  /// conflating them "either refuses every legal connect or writes a
  /// `PortEndpoint` at an id nothing resolves".
  ///
  /// A caller PLANNING a connection wants [derivedPortId], which is always
  /// known because `derivePortId` is a pure UUIDv5 over `(deviceId,
  /// portKey)` (CR-116, AC-006). A caller asking whether the port already
  /// carries project state wants THIS.
  ///
  /// Reading this one as the planning id is what left `planAtomicConnect`
  /// returning a zero-conductor plan on every palette-built document —
  /// DR-011's finding #1, fixed for `ConnectPortsCommand` in M2-F Phase 0
  /// and for this path in Phase 4C.
  final Uuid? portId;

  /// The id this member HAS or WILL have — `derivePortId(deviceId,
  /// portKey)`, never null.
  ///
  /// Set by [resolvePortSet] for every declared member regardless of
  /// materialisation. See [portId] for why both exist.
  final Uuid derivedPortId;

  /// Whether this member can carry a conductor end.
  bool get isMaterialised => portId != null;
}

/// [deviceId]'s port set [PortSetDef], with its members in declared order.
@immutable
final class ResolvedPortSet {
  const ResolvedPortSet({
    required this.deviceId,
    required this.def,
    required this.members,
  });

  final Uuid deviceId;
  final PortSetDef def;

  /// In DECLARED ORDER. See the file header — this ordering is what
  /// §11.8.3 pairs on.
  final List<PortSetMember> members;

  /// The members that can actually carry a conductor end.
  Iterable<PortSetMember> get materialised =>
      members.where((m) => m.isMaterialised);
}

/// Resolves [setKey] on [deviceId], or `null` when the device, its
/// template snapshot, or the set itself does not resolve.
///
/// Returns a set with ZERO members rather than null when the set is
/// declared but no port references it — that is the dangling-key state
/// `port_set_integrity_test` guards, and a caller should be able to tell
/// "no such set" from "a set nothing joined to".
ResolvedPortSet? resolvePortSet(
  RackDocument doc,
  Uuid deviceId,
  String setKey,
) {
  final device = doc.devices[deviceId];
  if (device == null) return null;

  // CR-054 says a TemplateRef always resolves; a hand-edited file says
  // otherwise, and `bodyFor` already treats that as an unknown rather than
  // an impossibility.
  final body = bodyFor(device, doc.templates);
  if (body == null) return null;

  PortSetDef? def;
  for (final s in body.portSets) {
    if (s.key == setKey) {
      def = s;
      break;
    }
  }
  if (def == null) return null;

  final defs = portsInDeclaredOrder(
    body.ports.where((p) => p.setKey == setKey),
  );

  return ResolvedPortSet(
    deviceId: deviceId,
    def: def,
    members: [
      for (final p in defs)
        PortSetMember(
          portKey: p.key,
          role: p.setRole,
          derivedPortId: derivePortId(deviceId, p.key),
          portId: doc.ports.containsKey(derivePortId(deviceId, p.key))
              ? derivePortId(deviceId, p.key)
              : null,
        ),
    ],
  );
}
