// DR-011.2 — the pin-to-pin connect gesture. One user action, one `Link`,
// one `Conductor`, two `PortEndpoint`s, one undo entry.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS EXISTS AND `AtomicConnectCommand` DOES NOT COVER IT
// ═════════════════════════════════════════════════════════════════════
// `AtomicConnectCommand` connects a `PortSetDef` to a `PortSetDef`. 223 of
// the catalog's 257 ports carry NO `setKey` at all, so not one HDMI, RJ45,
// IR or outlet port is reachable set-to-set. DR-011.2 rules the gesture
// pin-to-pin and reserves `AtomicConnectCommand` for the case where the
// grabbed pin belongs to a set flagged `atomicConnect: true`.
//
// ═════════════════════════════════════════════════════════════════════
// PORTS ARE MATERIALISED INSIDE `apply()`. THAT IS DR-011.1, AND IT IS
// A DELIBERATE EXCEPTION TO THE "NEVER ALLOCATE IN apply()" RULE.
// ═════════════════════════════════════════════════════════════════════
// Nothing in the app ever writes `doc.ports`: the only
// `doc.ports[id] = Port(...)` in the repository is in
// `apps/rackmate/tool/starters/authoring.dart`, a TOOL. So on any document
// built by dropping devices out of the palette, every pin is
// unmaterialised and a plan that required materialised ports would be
// empty on every real document.
//
// The exception is safe because it allocates NOTHING. The port id is
// `derivePortId(deviceId, portKey)` — a pure UUIDv5 (CR-116, AC-006), the
// same answer on every peer and every replay — and the DESIGNATOR is
// allocated CALLER-SIDE and carried on [PortMaterialisation], exactly as
// `AddLinkCommand.netName` is. What `apply()` decides from the document is
// only WHETHER the port is already there, and that decision is recorded so
// `revert()` can undo precisely it:
//
//   * materialisation is IDEMPOTENT — an existing port is left untouched,
//     including its designator, overrides, notes and network config;
//   * `revert()` removes EXACTLY what this apply added and nothing else,
//     so a port that already existed survives an undo with its state.
//
// The alternative — materialising in a separate command, or before
// evaluating the rules — writes ports into the document for a connect that
// then REFUSES, leaving an undo entry for a gesture that visibly did
// nothing. DR-011.5 refuses outright, so there must be nothing to undo.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/commands/atomic_connect.dart'
    show RoleMismatch;
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/link_commands.dart'
    show allocateLinkDesignatorFor, allocateNetNameFor;
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/derived/connect_rules.dart';
import 'package:rackmate_core/src/derived/connect_target.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/net.dart';
import 'package:rackmate_core/src/model/port.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/service.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/util/id_gen.dart';

/// The `MediaTypeId` a connect gesture writes when the document cannot say
/// what cable this run is — which today is EVERY connect made in the app.
///
/// ═════════════════════════════════════════════════════════════════════
/// EMPTY IS THE HONEST ANSWER, AND IT IS G4, NOT LAZINESS
/// ═════════════════════════════════════════════════════════════════════
/// `Link.media` is required and non-nullable, so a connect must write
/// SOMETHING. Nothing in the tree knows what:
///
///   * `Registries.mediaTypes` IS EMPTY in every seeded document —
///     `seed_registries.dart`'s header says so outright ("`cableSpecs`,
///     `.mediaTypes` and `.outletTemplates` STAY EMPTY"), because docs/02
///     §5.3's `MediaTypeDef` table was kept out of DR-010's scope. There
///     is no id to pick that would resolve;
///   * `SignalFamilyDef` carries no `typicalMedia` — DR-010 §11.10.4
///     keeps the twenty-odd corpus fields absent until something needs
///     them, and this is not that;
///   * `PortDef` names a CONNECTOR, and a connector is not a cable. RJ45
///     carries `net.ethernet` and `video.hdbaset` over different cable
///     grades, which docs/05:145 calls the two most dangerous ports in
///     the taxonomy.
///
/// So the alternatives are all fabrications. `ProjectSettings
/// .defaultNetworkMedia` is `media.cat6a_futp` and writing it on an HDMI
/// run puts a wrong cable spec on a termination schedule an installer
/// buys from — which is precisely what G4 forbids, and the failure is
/// silent because a plausible cable type looks like data rather than like
/// a guess.
///
/// AN UNRESOLVED MEDIA IS ALREADY A MODELLED STATE, which is why this
/// costs nothing downstream: `ScheduleRow.media` is a nullable
/// `MediaTypeDef?` documented as "the registry entry for `mediaId`, or
/// null when the document's `Registries` does not carry one. Counted,
/// never invented." An empty id lands in that arm exactly as any
/// unresolvable id would, and it round-trips (`Link.media` is encoded as
/// a bare string).
///
/// WHEN THIS STOPS BEING RIGHT: the moment `mediaTypes` is seeded and a
/// family can name its typical cable, the connect path should offer that
/// and this constant should be deleted rather than defaulted around.
const MediaTypeId kUnstatedMedia = MediaTypeId('');

/// Everything [ConnectPortsCommand.apply] needs to materialise one pin —
/// and nothing else.
///
/// Deliberately NOT a [ConnectTarget]. A `ConnectTarget` is a document
/// JOIN: it holds a live `Port` reference and a `PortDef` off a template
/// snapshot, both of which are answers about the document as it was at
/// resolve time. A command must survive being replayed against a document
/// that has moved, so it carries the four flat facts that are true
/// regardless — and the designator among them, because that one was
/// ALLOCATED and an allocation replayed is an allocation that can come out
/// different.
@immutable
final class PortMaterialisation {
  const PortMaterialisation({
    required this.portId,
    required this.deviceId,
    required this.portKey,
    required this.designator,
  });

  /// Built from [target], with [designator] the caller's allocation for
  /// the case where the port turns out not to exist yet.
  factory PortMaterialisation.of(
    ConnectTarget target, {
    required String designator,
  }) => PortMaterialisation(
    portId: target.portId,
    deviceId: target.deviceId,
    portKey: target.portKey,
    designator: designator,
  );

  /// `derivePortId(deviceId, portKey)`. Recomputable, carried explicitly
  /// so `apply()` performs no derivation of its own.
  final Uuid portId;
  final Uuid deviceId;
  final PortKey portKey;

  /// The designator to give the port IF this command materialises it.
  /// Ignored entirely when the document already holds the port — an
  /// existing `Port.designator` is project state and is never rewritten
  /// by a connect (CR-048: a designator is evaluated once at creation and
  /// stored).
  final String designator;
}

/// Creates ONE [Link] carrying ONE [Conductor] between two pins, plus its
/// implicit [Net] — and materialises either pin the document does not hold
/// yet (DR-011.1).
///
/// Ids are minted in the constructor, never in `apply()`, so redo
/// recreates identical entities — the `AddLinkCommand` rule. See the file
/// header for why port materialisation is not a violation of it.
final class ConnectPortsCommand extends Command {
  ConnectPortsCommand({
    required this.from,
    required this.to,
    required this.designator,
    required this.netName,
    required this.signalFamily,
    required this.media,
    required this.order,
    required this.now,
    required this.actor,
    this.role = '',
    Uuid? id,
    Uuid? netId,
  }) : id = id ?? newEntityId(),
       netId = netId ?? newEntityId() {
    // ─────────────────────────────────────────────────────────────────
    // THE ZERO-CONDUCTOR GUARD. AN EMPTY CONNECTION IS NOT A SUCCESS.
    // ─────────────────────────────────────────────────────────────────
    // A `Link` needs at least one `Conductor` to mean anything (CR-010,
    // CR-014). This command builds exactly one, from [from] to [to] — so
    // the only way to reach a link that asserts nothing is for those two
    // to be the SAME pin, which is a conductor from a jack to itself:
    // zero electrical paths wearing one conductor's clothes, and
    // `TOP-001` besides.
    //
    // A THROW, NOT AN `assert`. Asserts are stripped in release, and a
    // release build that silently wrote this link would put a cable on
    // the termination schedule that goes nowhere. `evaluateConnect`
    // refuses this case first, so reaching here means a caller skipped
    // the rules — which is exactly when a guard has to hold.
    if (from.portId == to.portId) {
      throw ArgumentError.value(
        from.portId.v,
        'from.portId',
        'ConnectPortsCommand would build a conductor from a port to '
            'itself, which is no conductor at all (TOP-001, CR-014). Call '
            'evaluateConnect before constructing this command.',
      );
    }
  }

  final PortMaterialisation from;
  final PortMaterialisation to;
  final Uuid id;
  final Uuid netId;

  /// "W042" — `allocateLinkDesignator`'s answer, computed by the CALLER
  /// before construction for the same reason the ids are.
  final String designator;

  /// The implicit `Net`'s generated name — see `AddLinkCommand.netName`.
  final String netName;

  /// The pins' OWN signal family (DR-011.3), not
  /// `structure.undetermined`. It lands on both the `Net` and the
  /// `Service`, which is what puts the run in the right signal DOMAIN and
  /// therefore gives it the right colour, dash, weight and tag glyph
  /// (CR-078). Hardcoding a placeholder here — as this file's predecessor
  /// did — drew every cable in the project as structure.
  final SignalFamilyId signalFamily;

  final MediaTypeId media;
  final FracIndex order;

  /// The conductor's role — `"+"`, `"L"`, `"Y"` — or `''`.
  ///
  /// ═════════════════════════════════════════════════════════════════
  /// ONLY WHEN BOTH PINS DECLARE THE SAME ONE. A ROLE IS A CLAIM ABOUT
  /// THE WHOLE CONDUCTOR, NOT ABOUT THE END THE USER GRABBED.
  /// ═════════════════════════════════════════════════════════════════
  /// This link has exactly one conductor spanning exactly two pins, so
  /// its role is a statement that BOTH of them are the `+` leg. Taking it
  /// from the grabbed end alone writes `+` on a conductor whose far end
  /// is a `-` post, and `buildSchedule` then prints `[+]` beside it — the
  /// installer lands the plus leg on the minus terminal with every sheet
  /// agreeing. `AtomicConnectCommand` refuses to let that land unremarked
  /// (`RoleMismatch`, atomic_connect.dart), which is exactly the
  /// exposure AC-030 exists to close, and the pin-to-pin path is where it
  /// is one drag away rather than latent.
  ///
  /// So `buildConnectPortsCommand` writes the grabbed end's role UNLESS
  /// the other end CONTRADICTS it, reports that contradiction on
  /// [ConnectPortsReady.roleMismatch] where a caller can surface it, and
  /// writes `''` in its place. A far end that declares NO role
  /// contradicts nothing — the template simply does not model roles on
  /// that pin — so the run keeps the one real fact it has. `''` is itself
  /// a real value, not a missing one: `ScheduleConductor.role` documents
  /// it as *"the cable has one electrical path whose role is the cable"*,
  /// which is precisely this link's shape.
  ///
  /// NOT A REFUSAL. Polarity is not one of `TOP-001..005`, and docs/02 §5
  /// opens with *"a rule not listed here does not exist"* — inventing a
  /// sixth tier-1 rule here would make a system the user was called in to
  /// document undrawable (G2, CR-017).
  final String role;

  final DateTime now;
  final String actor;

  /// The ports THIS apply() created, in creation order. Empty until
  /// `apply()` runs, and empty again after `revert()`.
  ///
  /// Recorded rather than recomputed because "did this command materialise
  /// that port" is not answerable from the document afterwards — the port
  /// looks identical either way — and getting it wrong deletes a port the
  /// user's document already owned, with its designator, notes, network
  /// config and every conductor that lands on it left dangling.
  final List<Uuid> _materialised = [];

  @override
  LabelKey get label => LabelKey.connectPorts;

  /// `wires` for the `Link`/`Conductor`/`Service`/`Net`, and `meta`
  /// because materialisation MINTS A DESIGNATOR.
  ///
  /// `meta`'s own doc comment names "designators, names, notes" and
  /// `Port.designator` is one — it is what the termination schedule prints
  /// in its terminal column and what CR-042 cites as `MTX-1:J09`. A
  /// surface subscribed only to `wires` would draw the new run against a
  /// pin whose identifier it has never read.
  ///
  /// NOT `structure`. That epoch is placement — "placement
  /// add/remove/move/rotate/face" — and a materialised `Port` moves
  /// nothing: the pin was always on the device's template, always drawn by
  /// the symbol layer (which builds `SymbolPort` from `PortDef`, not from
  /// `doc.ports`), and always occupied the same RU. What changes is that
  /// the document now holds project state for it.
  @override
  EpochMask get touches => EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [id, netId, from.portId, to.portId];

  @override
  void apply(RackDocument doc) {
    // Cleared, not appended to: `apply` runs again on every redo and this
    // must describe THIS run, not the union of all of them.
    _materialised.clear();
    for (final spec in [from, to]) {
      // IDEMPOTENT. An existing port keeps everything it carries.
      if (doc.ports.containsKey(spec.portId)) continue;
      doc.ports[spec.portId] = Port(
        id: spec.portId,
        deviceId: spec.deviceId,
        designator: spec.designator,
        templatePortKey: spec.portKey,
      );
      _materialised.add(spec.portId);
    }

    doc.nets[netId] = Net(
      id: netId,
      name: netName,
      signalFamily: signalFamily,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
    );
    doc.links[id] = Link(
      id: id,
      designator: designator,
      media: media,
      order: order,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      services: [
        Service(id: 'svc-1', signalFamily: signalFamily, netId: netId),
      ],
      conductors: [
        Conductor(
          from: PortEndpoint(from.portId),
          to: PortEndpoint(to.portId),
          role: role,
        ),
      ],
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.links.remove(id);
    doc.nets.remove(netId);
    // ONLY what this apply added. A port that was already in the document
    // when this command ran is not this command's to remove.
    for (final portId in _materialised) {
      doc.ports.remove(portId);
    }
    _materialised.clear();
  }
}

/// The outcome of [buildConnectPortsCommand] — a ready command, or the
/// tier-1 refusal that stopped it — in the shape `AddRackResult` and
/// `CatalogPlacementResult` already establish, so a caller can honour
/// docs/04 §3.4's "never silently do nothing".
@immutable
sealed class ConnectPortsResult {
  const ConnectPortsResult();
}

final class ConnectPortsReady extends ConnectPortsResult {
  const ConnectPortsReady(this.command, {this.roleMismatch});

  final ConnectPortsCommand command;

  /// Non-null when the two pins declare DIFFERENT non-empty `setRole`s —
  /// a `+` landing on a `-`.
  ///
  /// READY, NOT REFUSED, AND THE DISTINCTION IS THE RULING. Polarity is
  /// not a tier-1 rule and docs/02 §5 forbids inventing one, so the
  /// gesture proceeds; what it may not do is proceed SILENTLY. This is
  /// the arm a caller reads to put a warning in front of the user, and
  /// [ConnectPortsCommand.role] is `''` in this case so nothing on the
  /// termination schedule claims the conductor is the `+` leg.
  ///
  /// `position` is always 0 — a pin-to-pin gesture has one conductor.
  /// The type is shared with `AtomicConnectCommand`'s report because it
  /// is the same fact about the same kind of pair, and two spellings of
  /// it is how a surface ends up handling one and not the other.
  final RoleMismatch? roleMismatch;
}

/// The gesture is refused. DR-011.5: there is no `[ Connect anyway ]` for
/// a tier-1 rule — docs/02 §5 gives T1's escape as *"None. There is
/// nothing to escape to."* — and because nothing was written, there is no
/// history entry to undo.
final class ConnectPortsRefused extends ConnectPortsResult {
  const ConnectPortsRefused(this.verdict);
  final ConnectRefused verdict;

  String get ruleId => verdict.ruleId;
  String get message => verdict.message;
}

/// Everything one GESTURE has already allocated against an unmutated
/// document, so the next command it builds does not mint the same names.
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT IS MUTATED BY [buildConnectPortsCommand], AND THAT IS THE POINT
/// ═══════════════════════════════════════════════════════════════════════
/// Every allocator reads the DOCUMENT to decide what is taken. Correct for
/// one command; silently wrong for N built together and applied together,
/// which is exactly what multi-draw is (DR-012.2 — N `Link`s, one undo
/// entry). Without a reservation all N allocate `W006`, all N allocate
/// `N006`, and two pairs landing on one device are handed the same
/// `J`-number.
///
/// Handing the caller three separate sets to thread would make forgetting
/// one a live defect that nothing catches — link designators are
/// PROJECT-WIDE unique and a duplicate is two schedule rows an installer
/// cannot tell apart. So the builder records what it took, and a caller
/// that passes the same accumulator to every call in the gesture cannot get
/// it wrong.
///
/// A caller building ONE command passes nothing and pays nothing.
final class ConnectAllocations {
  /// `W###` values this gesture has minted.
  final Set<String> linkDesignators = <String>{};

  /// `N###` values this gesture has minted.
  final Set<String> netNames = <String>{};

  /// Port designators minted, PER DEVICE — a port designator is unique
  /// within its device (CR-042), not project-wide.
  final Map<Uuid, Set<String>> portDesignators = <Uuid, Set<String>>{};

  /// Sort indices minted, so N links do not all land on one order.
  final List<FracIndex> orders = <FracIndex>[];

  Set<String> _portsOn(Uuid deviceId) =>
      portDesignators.putIfAbsent(deviceId, () => <String>{});
}

/// Builds the [ConnectPortsCommand] for a pin-to-pin gesture from [from]
/// to [to], or the refusal that stops it.
///
/// EVERY ALLOCATION HAPPENS HERE, CALLER-SIDE — the link designator, the
/// net name, the sort order and both port designators — for
/// `AddLinkCommand.netName`'s reason: an allocation performed inside
/// `apply()` would see a different set of used values on a redo and mint a
/// different answer than the original run.
///
/// The rules run BEFORE any of it. A refusal returns no command, so a
/// refused gesture leaves neither a document change nor an undo entry
/// (DR-011.1).
///
/// [freeing] is DR-014's pending split, forwarded to `evaluateConnect` so
/// `TOP-003` counts the pins as this gesture will leave them. A caller that
/// passes it MUST also run the split — see `buildSplitConnectCommands`,
/// which is the one place that does both and the only thing that should
/// pass this.
ConnectPortsResult buildConnectPortsCommand({
  required RackDocument doc,
  required ConnectTarget from,
  required ConnectTarget to,
  required MediaTypeId media,
  required DateTime now,
  required String actor,
  ConnectAllocations? reserve,
  Set<ConductorRef> freeing = const <ConductorRef>{},
}) {
  final verdict = evaluateConnect(doc, from, to, freeing: freeing);
  if (verdict is ConnectRefused) return ConnectPortsRefused(verdict);

  // Both ends may be pins on the SAME device (a loopback between two of
  // its own jacks is legal — only connecting a pin to ITSELF is not), so
  // the second allocation must see the first one's answer — and, when a
  // gesture is building several commands at once, every EARLIER command's
  // answers too. See [ConnectAllocations].
  final fromReserved = reserve?._portsOn(from.deviceId) ?? <String>{};
  final fromDesignator = allocatePortDesignatorFor(
    doc,
    from,
    alsoUsed: fromReserved,
  );
  fromReserved.add(fromDesignator);
  final toReserved = reserve?._portsOn(to.deviceId) ?? <String>{};
  final toDesignator = allocatePortDesignatorFor(
    doc,
    to,
    alsoUsed: from.deviceId == to.deviceId
        ? {fromDesignator, ...toReserved}
        : toReserved,
  );
  toReserved.add(toDesignator);

  final linkDesignator = allocateLinkDesignatorFor(
    doc,
    alsoUsed: reserve?.linkDesignators ?? const {},
  );
  final netName = allocateNetNameFor(
    doc,
    alsoUsed: reserve?.netNames ?? const {},
  );
  final order = nextOrder([
    ...doc.links.values.map((l) => l.order),
    ...?reserve?.orders,
  ]);
  reserve
    ?..linkDesignators.add(linkDesignator)
    ..netNames.add(netName)
    ..orders.add(order);

  // The two ends' declared roles. A null and an empty string both mean
  // "this pin declares no role" — `Conductor.role`'s own doc gives `""`
  // as a value, so a template may spell it either way and comparing them
  // raw would report a conflict on every unroled pair.
  final fromRole = from.def.setRole ?? '';
  final toRole = to.def.setRole ?? '';
  final disagree =
      fromRole.isNotEmpty && toRole.isNotEmpty && fromRole != toRole;

  return ConnectPortsReady(
    ConnectPortsCommand(
      from: PortMaterialisation.of(from, designator: fromDesignator),
      to: PortMaterialisation.of(to, designator: toDesignator),
      designator: linkDesignator,
      netName: netName,
      // DR-011.3: the pin's REAL family. The `from` end supplies it —
      // it is the end the user grabbed, and where the two disagree that
      // disagreement is `SIG-002`'s to report (tier 2, deferred to M5),
      // not this builder's to arbitrate by picking the other one.
      signalFamily: from.signalFamily,
      media: media,
      order: order,
      now: now,
      actor: actor,
      // See `ConnectPortsCommand.role`: a role is a claim about the whole
      // conductor, so it is written only where both ends make it.
      role: disagree ? '' : fromRole,
    ),
    roleMismatch: disagree
        ? RoleMismatch(position: 0, fromRole: fromRole, toRole: toRole)
        : null,
  );
}
