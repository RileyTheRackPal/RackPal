// rackmate_core/src/commands/bind_endpoint_command.dart — pure Dart.
//
// LANDING A DROP AT THE RACK. Board M3-K/2 (#664), DR-040 §11.39.2,
// AC-018.
//
// ─────────────────────────────────────────────────────────────────────────
// CANON NAMED THIS COMMAND AND NOBODY EVER WROTE IT
// ─────────────────────────────────────────────────────────────────────────
// AC-018 (canon :2186): *"Binding it later is one command (`BindEndpoint`)
// that preserves the ID, the length, the jacket, and the test result."*
// `docs/01` §535 and `docs/02` §663 both cite it as though it existed. It
// existed in zero `.dart` files until this one, which is why the product
// could only ever produce AC-018's FOURTEEN unbound drops, sixty times,
// while M3's exit criterion wants forty-six of them landed.
//
// The clause quoted above is the whole specification and it is a list of
// what must NOT change. So this command touches exactly two things: the
// far end of conductor 0, and the rack label. The `Link` keeps its id, its
// designator, its `W` number, its net, its media, its lengths, its jacket
// colour, its `TestResult` and its `RoughInStatus`, because binding a
// cable that was already pulled records where it landed and nothing else.
//
// ─────────────────────────────────────────────────────────────────────────
// THE PORT MATERIALISES IN `apply()`, WHICH IS DR-011.1 AND NOT A NEW IDEA
// ─────────────────────────────────────────────────────────────────────────
// `derivePortId` is a pure UUIDv5 over `(deviceId, portKey)` (CR-116,
// AC-006), so the id a pin WILL have is knowable before the pin exists.
// `ConnectPortsCommand` already relies on that and materialises inside its
// own `apply()`; a panel dropped out of the palette has no materialised
// ports at all, so a bind that demanded one would refuse every real
// document. The `_materialised` list is recorded rather than recomputed
// for `ConnectPortsCommand`'s stated reason: afterwards the port looks
// identical either way, and guessing wrong deletes a jack the user's
// document already owned.
//
// ─────────────────────────────────────────────────────────────────────────
// THE REAR PORT IS THE CALLER'S CHOICE AND THE CATALOG SAYS WHY
// ─────────────────────────────────────────────────────────────────────────
// This command binds whatever pin it is handed. DR-040 §11.39.2 clause 4
// rules that a structured drop lands on the REAR, and the N03 archetype
// carries the reason in its own description: *"Rear ports are 110
// punchdown, not RJ45 — modelling both faces as RJ45 is the error that
// makes the Termination Schedule wrong on the one column the trim tech
// actually needs (AC-025)."* The choice is made where the pin is picked,
// so a future gesture landing a fibre run on an LIU adapter needs no new
// command.
//
// ─────────────────────────────────────────────────────────────────────────
// A BIND THAT CANNOT RENDER A LABEL STILL BINDS (DR-040 §11.39.5)
// ─────────────────────────────────────────────────────────────────────────
// [rackLabel] is nullable and a null one is written as null. The endpoint
// and the label are two facts: a panel whose location carries no floor
// number cannot render `{FLOOR}`, and letting that undo a physical fact
// somebody stated would be exactly the fusion G4 forbids. The caller says
// the sentence naming the field to fill; the punchdown still happened.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/connect_commands.dart'
    show PortMaterialisation;
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/derived/connect_rules.dart'
    show portConductorCount;
import 'package:rackmate_core/src/derived/connect_target.dart'
    show resolveConnectTarget;
import 'package:rackmate_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/placement.dart' show Face;
import 'package:rackmate_core/src/model/port.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/template.dart' show PortDef;
import 'package:rackmate_core/src/units/ids.dart';

/// Lands one home run's far end on one panel pin, and records the rack
/// label that landing makes renderable.
final class BindEndpointCommand extends Command<RackDocument> {
  BindEndpointCommand({
    required this.linkId,
    required this.port,
    required this.rackLabel,
    required this.now,
    required this.actor,
  });

  final Uuid linkId;

  /// The pin, flat, for `PortMaterialisation`'s stated reason: a command
  /// replayed against a moved document may not re-derive an allocation.
  final PortMaterialisation port;

  /// `1A-PP-101`, or NULL when the label's pattern could not render.
  /// Allocated caller-side through `allocateOutletRackLabel`, never here.
  final String? rackLabel;

  final DateTime now;
  final String actor;

  /// What was there before, so `revert` restores rather than guesses.
  ///
  /// AN `OpenEndpoint` CARRIES A DESCRIPTION AND IT IS NOT ALWAYS THE
  /// DEFAULT ONE. `AddHomeRunCommand` writes `'not yet landed'`, but a
  /// document round-tripped from a file or built by a starter may carry a
  /// person's own words, and an undo that replaced them with the constant
  /// would quietly edit a note somebody wrote.
  Endpoint? _previousEnd;
  String? _previousRackLabel;
  EntityMeta? _previousMeta;

  /// Empty unless THIS `apply()` created the port. See the file header.
  final List<Uuid> _materialised = [];

  @override
  LabelKey get label => LabelKey.bindEndpoint;

  /// `wires` for the conductor's end, `meta` for the rack label and for
  /// the designator a materialised port mints.
  ///
  /// `ConnectPortsCommand` documents the same pair for the same two
  /// reasons, and NOT `structure`: materialising a pin moves nothing, the
  /// jack was always on the template and always drawn.
  @override
  EpochMask get touches => EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [linkId, port.portId];

  @override
  void apply(RackDocument doc) {
    // Cleared, not appended to: `apply` runs again on every redo and must
    // describe THIS run.
    _materialised.clear();
    if (!doc.ports.containsKey(port.portId)) {
      doc.ports[port.portId] = Port(
        id: port.portId,
        deviceId: port.deviceId,
        designator: port.designator,
        templatePortKey: port.portKey,
      );
      _materialised.add(port.portId);
    }

    final link = doc.links[linkId];
    if (link == null) return;
    final conductor = link.conductors.first;
    _previousEnd = conductor.to;
    _previousMeta = link.meta;
    // FIELD END UNTOUCHED. `Conductor.from` is the wall plate and this
    // gesture is about the other end; rebuilding both would let a caller
    // that passed the wrong pin move the drop out of its own room.
    link.conductors[0] = Conductor(
      from: conductor.from,
      to: PortEndpoint(port.portId),
      role: conductor.role,
      pairNumber: conductor.pairNumber,
      colorCode: conductor.colorCode,
    );

    final origin = link.structureOrigin;
    if (origin != null) {
      _previousRackLabel = origin.rackLabel;
      origin.rackLabel = rackLabel;
    }
    link.meta = EntityMeta(
      createdAt: link.meta.createdAt,
      updatedAt: now,
      updatedBy: actor,
    );
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link != null) {
      if (_previousEnd case final end?) {
        final conductor = link.conductors.first;
        link.conductors[0] = Conductor(
          from: conductor.from,
          to: end,
          role: conductor.role,
          pairNumber: conductor.pairNumber,
          colorCode: conductor.colorCode,
        );
      }
      if (link.structureOrigin case final origin?) {
        origin.rackLabel = _previousRackLabel;
      }
      if (_previousMeta case final meta?) link.meta = meta;
    }
    // ONLY what this apply added, on `ConnectPortsCommand`'s rule: a port
    // the document already held is not this command's to remove.
    for (final portId in _materialised) {
      doc.ports.remove(portId);
    }
    _materialised.clear();
    _previousEnd = null;
    _previousRackLabel = null;
    _previousMeta = null;
  }
}

/// The positions on [panelDeviceId] a drop may land on, in the template's
/// declared order, lowest first.
///
/// REAR ONLY, WHICH IS DR-040 §11.39.2 CLAUSE 4 AS A FILTER. `Face.rear`
/// is `PortBuilder.p`'s default and is what the N03 archetype's twenty-four
/// punchdowns carry; its front twenty-four are `Face.front` and are where a
/// patch cord goes, not a pulled cable. A walk that offered both would hand
/// the first drop `front.1` and put the whole rough-in on the wrong side of
/// the panel.
///
/// DECLARED ORDER, NOT MAP ORDER. `TemplateBody.ports` is the declared
/// sequence (the catalog port-order gate is what keeps it so), and it is
/// what makes `01, 02, 03…` come out in the order a person punches them
/// down rather than in whatever order a hash produced.
///
/// [alsoClaimed] is the sibling reservation `buildAddHomeRunCommand`
/// explains: ten drops landed from one typed line are planned against ONE
/// unmutated document, so each must see the positions its siblings took.
List<PanelLanding> freePanelPositions(
  RackDocument doc, {
  required Uuid panelDeviceId,
  Set<Uuid> alsoClaimed = const <Uuid>{},
}) {
  final device = doc.devices[panelDeviceId];
  if (device == null) return const [];
  final body = bodyFor(device, doc.templates);
  if (body == null) return const [];

  final free = <PanelLanding>[];
  for (final def in body.ports) {
    if (def.face != Face.rear) continue;
    final target = resolveConnectTarget(
      doc,
      deviceId: panelDeviceId,
      portKey: def.key.v,
    );
    if (target == null) continue;
    if (alsoClaimed.contains(target.portId)) continue;
    // ASKED, NOT ANSWERED AGAIN. `portConductorCount` is where TOP-003
    // lives; a second occupancy test written here would be a second
    // answer to one question.
    if (portConductorCount(doc, target.portId) > 0) continue;
    final designator = target.portDesignator;
    free.add(
      PanelLanding(
        port: PortMaterialisation.of(target, designator: designator),
        positionToken: panelPositionToken(def, designator),
      ),
    );
  }
  return free;
}

/// One free position on a panel: the pin, and what `{PORT}` renders for it.
///
/// TWO STRINGS BECAUSE THERE ARE TWO FACTS, and DR-040 §11.39.8 is the
/// ruling that separates them. `port.designator` is what the `Port` entity
/// will carry, which is project state governed by `portDesignatorFormat`.
/// [positionToken] is what is PRINTED ON THE PART. On a patch panel those
/// differ, and a caller that used one for both would either put `J04` on a
/// cable label or write `01` into a port designator that the rest of the
/// product allocates.
@immutable
final class PanelLanding {
  const PanelLanding({required this.port, required this.positionToken});

  final PortMaterialisation port;

  /// What `{PORT}` renders. See [panelPositionToken].
  final String positionToken;
}

/// What `{PORT}` renders for a position on a patch panel (DR-040
/// §11.39.8).
///
/// ═════════════════════════════════════════════════════════════════════
/// THE NUMBER PRINTED ON THE PANEL, NOT THE ONE THIS PRODUCT ALLOCATED
/// ═════════════════════════════════════════════════════════════════════
/// `ConnectTarget.portDesignator` renders `J04` on a three-up/three-down
/// fixture, because `portDesignatorFormat` is `J{PORT_SEQ:2}` and
/// `PORT_SEQ` counts the FRONT jacks a drop never touches. `J04` appears
/// nowhere on the physical part, so a tech on a ladder holding a cable
/// labelled `1A-PP-1J04` has to translate it against a panel silkscreened
/// `01 … 24`. CR-044's own example is `1A-A12`, which is a position
/// number.
///
/// The archetype already carries that number: `catalog_network.dart` calls
/// `n03.p(rearKey, n, …)` where `n` is `'01'`, so it is `PortDef.label`.
/// So the label wins where the template declares one, and the designator
/// is the fallback for a pin whose template says nothing.
///
/// WHAT THIS DOES NOT FIX, STATED SO NOBODY READS IT AS FIXED. The
/// Termination Schedule's `RACK TERM` column still prints the DESIGNATOR
/// for the same hole, so two columns describe one position two ways. That
/// disagreement predates this function: it is between `portDesignator` and
/// the part, and closing it means teaching designator ALLOCATION to honour
/// an authored label, which is its own ruling and touches the connect
/// gesture's output for every device in the catalog.
String panelPositionToken(PortDef def, String designator) {
  final label = def.label.trim();
  return label.isEmpty ? designator : label;
}

/// The outcome of [buildBindEndpointCommand].
sealed class BindEndpointResult {
  const BindEndpointResult();
}

final class BindEndpointReady extends BindEndpointResult {
  const BindEndpointReady(this.command);
  final BindEndpointCommand command;
}

/// The bind cannot happen, and [reason] is a sentence for the user.
final class BindEndpointRefused extends BindEndpointResult {
  const BindEndpointRefused(this.reason);
  final String reason;
}

/// Builds a bind, or refuses with a sentence.
///
/// FIVE REFUSALS AND EACH ONE IS A DIFFERENT FACT ABOUT THE DOCUMENT.
/// docs/04 §3.4's "never silently do nothing" read from the other side: a
/// gesture that declined without saying which of these it hit would leave
/// the user re-picking pins at random.
///
/// [usedRackLabels] is `home_run_commands.dart`'s scan, passed in rather
/// than taken here, because a batch landing ten drops on one panel is
/// built against ONE unmutated document and each must see the labels its
/// siblings have already spent.
BindEndpointResult buildBindEndpointCommand({
  required RackDocument doc,
  required Uuid linkId,
  required PortMaterialisation port,
  required String? rackLabel,
  required Set<String> usedRackLabels,
  required DateTime now,
  required String actor,
}) {
  final link = doc.links[linkId];
  if (link == null) {
    return const BindEndpointRefused('That cable is not in this project.');
  }
  if (link.structureOrigin == null) {
    // A PATCH IS NOT A DROP. This writes a `rackLabel` onto a
    // `StructureOrigin`, and a link without one is an ordinary connection
    // between two devices; binding it here would be a connect wearing the
    // wrong gesture's undo label.
    return const BindEndpointRefused(
      'That cable is not a home run, so it has no rack end to land. Use '
      'the schematic to connect two devices.',
    );
  }
  if (link.conductors.isEmpty) {
    return const BindEndpointRefused(
      'That cable has no conductors, so there is nothing to land.',
    );
  }

  final existing = link.conductors.first.to;
  if (existing is PortEndpoint) {
    // NOT AN UNBIND, AND DR-040 §11.39.6 says so out loud: moving a drop
    // off a jack it is already punched into is its own gesture and is not
    // ruled. Silently re-landing it would rewrite a termination somebody
    // recorded, and the rack label with it.
    return const BindEndpointRefused(
      'That drop is already landed. Moving a drop to a different port is '
      'not something this can do yet.',
    );
  }

  // ONE CABLE PER PUNCHDOWN POSITION, asked through `portConductorCount`
  // rather than answered again here, so `TOP-003` keeps living in exactly
  // one place. A jack that already has a cable in it is a jack the trim
  // tech will find occupied.
  if (portConductorCount(doc, port.portId) > 0) {
    return BindEndpointRefused(
      '${port.designator} already has a cable landed on it. Pick a free '
      'position.',
    );
  }

  final trimmed = rackLabel?.trim();
  final normalised = (trimmed?.isEmpty ?? true) ? null : trimmed;
  if (normalised != null && usedRackLabels.contains(normalised)) {
    // CR-113, project-wide. Two cables sharing a rack label is two rows
    // of the Pull Sheet naming one hole in one panel.
    return BindEndpointRefused(
      'Rack label "$normalised" is already used by another drop. Rack '
      'labels are unique across the whole project.',
    );
  }

  return BindEndpointReady(
    BindEndpointCommand(
      linkId: linkId,
      port: port,
      rackLabel: normalised,
      now: now,
      actor: actor,
    ),
  );
}
