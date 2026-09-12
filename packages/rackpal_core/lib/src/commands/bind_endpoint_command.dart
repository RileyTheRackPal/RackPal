// rackpal_core/src/commands/bind_endpoint_command.dart — pure Dart.
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
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/connect_commands.dart'
    show PortMaterialisation;
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/derived/connect_rules.dart'
    show portConductorCount;
import 'package:rackpal_core/src/derived/connect_target.dart'
    show resolveConnectTarget;
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart' show PortDef;
import 'package:rackpal_core/src/units/ids.dart';

/// Lands one home run's far end on one panel pin, and records the rack
/// label that landing makes renderable.
/// Which end of a home run a gesture is landing (`#714`).
///
/// ═════════════════════════════════════════════════════════════════════
/// TWO ENDS, ONE COMMAND, AND ONE OF THEM WAS UNREACHABLE FOR A YEAR
/// ═════════════════════════════════════════════════════════════════════
/// This command bound the RACK end and nothing else, so a run could land
/// on a patch panel and never on the thing at the other end of it. In
/// structured cabling that is right: a Cat6 drop ends at a wall plate and
/// whatever plugs in there is a separate patch cord. In AV it is wrong
/// often enough to matter, because a speaker run is ONE continuous
/// conductor from the amplifier to the driver, and a product that could
/// not say so made the user draw a second cable that does not exist.
///
/// Settled by the user on 2026-08-18 (DR-068): either end may bind.
enum LinkEnd {
  /// `Conductor.from` — the wall plate, the speaker, the camera.
  field,

  /// `Conductor.to` — the panel, the switch, the amplifier in the rack.
  rack,
}

final class BindEndpointCommand extends Command<RackDocument> {
  BindEndpointCommand({
    required this.linkId,
    required this.port,
    required this.rackLabel,
    required this.now,
    required this.actor,
    this.end = LinkEnd.rack,
  }) : assert(
         end == LinkEnd.rack || rackLabel == null,
         'A field bind may not write a rack label: the two ends carry two '
         'labels and landing a speaker does not rename the panel position.',
       );

  final Uuid linkId;

  /// Which end is landing. DEFAULTS TO `rack`, so every call site written
  /// before DR-068 keeps its meaning without being touched.
  ///
  /// THE LABEL IS NOT SYMMETRIC EVEN THOUGH THE ENDPOINT IS, and that is
  /// a fact about the two labels rather than an omission. A rack label is
  /// DERIVED FROM WHERE THE RUN LANDED — `{FLOOR}`, `{PORT}` — so it is
  /// unknowable until the bind happens and is written by it. A field
  /// label names the wall plate, was typed when the drop was created, and
  /// is unique project-wide under CR-113: landing a speaker on the run
  /// records where the copper ends and says nothing about what the plate
  /// is called. Rewriting it here would be the fusion G4 forbids, and
  /// would collide the moment two speakers landed in one room.
  final LinkEnd end;

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
  /// DEFAULT ONE. `AddHomeRunCommand` writes `kUnlandedEndDescription`,
  /// but a document round-tripped from a file or built by a starter may
  /// carry a person's own words — the shipped starters say "Rack end not
  /// yet terminated", and files written before DR-074 say "not yet
  /// landed" — and an undo that replaced them with the constant would
  /// quietly edit a note somebody wrote.
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
  bool apply(RackDocument doc) {
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
    if (link == null) return false;
    final conductor = link.conductors.first;
    final landed = PortEndpoint(port.portId);
    // THE OTHER END IS UNTOUCHED, WHICHEVER ONE THIS IS. Rebuilding both
    // would let a caller that passed the wrong pin move the drop out of
    // its own room, which is the failure the one-sided version of this
    // comment was guarding against when only the rack end could land.
    _previousEnd = switch (end) {
      LinkEnd.field => conductor.from,
      LinkEnd.rack => conductor.to,
    };
    _previousMeta = link.meta;
    link.conductors[0] = Conductor(
      from: end == LinkEnd.field ? landed : conductor.from,
      to: end == LinkEnd.rack ? landed : conductor.to,
      role: conductor.role,
      pairNumber: conductor.pairNumber,
      colorCode: conductor.colorCode,
    );

    // RACK ONLY. See [end] for why the two labels are not symmetric.
    final origin = link.structureOrigin;
    if (origin != null && end == LinkEnd.rack) {
      _previousRackLabel = origin.rackLabel;
      origin.rackLabel = rackLabel;
    }
    link.meta = EntityMeta(
      createdAt: link.meta.createdAt,
      updatedAt: now,
      updatedBy: actor,
    );
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link != null) {
      if (_previousEnd case final was?) {
        final conductor = link.conductors.first;
        link.conductors[0] = Conductor(
          from: end == LinkEnd.field ? was : conductor.from,
          to: end == LinkEnd.rack ? was : conductor.to,
          role: conductor.role,
          pairNumber: conductor.pairNumber,
          colorCode: conductor.colorCode,
        );
      }
      // Restored on a rack bind only, because only a rack bind wrote it:
      // a field bind left `_previousRackLabel` null and clearing the
      // label from that null would erase a panel position nobody touched.
      if (end == LinkEnd.rack) {
        if (link.structureOrigin case final origin?) {
          origin.rackLabel = _previousRackLabel;
        }
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
/// REAR ONLY ON A RACK PANEL, WHICH IS DR-040 §11.39.2 CLAUSE 4 AS A
/// FILTER. `Face.rear` is `PortBuilder.p`'s default and is what the N03
/// archetype's twenty-four punchdowns carry; its front twenty-four are
/// `Face.front` and are where a patch cord goes, not a pulled cable. A
/// walk that offered both would hand the first drop `front.1` and put the
/// whole rough-in on the wrong side of the panel.
///
/// AND NOT ON A FIELD DEVICE (`#714`). Clause 4 is a rule about the two
/// SIDES OF A PANEL IN A RACK: one side takes pulled cable, the other
/// takes patch cords, and the drop belongs on the first. An in-wall
/// speaker has no such geometry — its binding posts are simply its
/// terminals — and inheriting a rack panel's front/rear split would
/// offer a speaker zero positions and refuse every direct run. [end]
/// selects which rule applies, and it is the caller's statement about
/// what it is landing on rather than a guess made from the template.
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
  LinkEnd end = LinkEnd.rack,
}) {
  final device = doc.devices[panelDeviceId];
  if (device == null) return const [];
  final body = bodyFor(device, doc.templates);
  if (body == null) return const [];

  final free = <PanelLanding>[];
  for (final def in body.ports) {
    if (end == LinkEnd.rack && def.face != Face.rear) continue;
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
  LinkEnd end = LinkEnd.rack,
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
    return BindEndpointRefused(
      'That cable is not a home run, so it has no ${_endWord(end)} end to '
      'land. Use the schematic to connect two devices.',
    );
  }
  if (link.conductors.isEmpty) {
    return const BindEndpointRefused(
      'That cable has no conductors, so there is nothing to land.',
    );
  }

  final conductor = link.conductors.first;
  final existing = switch (end) {
    LinkEnd.field => conductor.from,
    LinkEnd.rack => conductor.to,
  };
  if (existing is PortEndpoint) {
    // STILL NOT AN UNBIND, AND NOW THERE IS SOMEWHERE TO SEND THEM.
    // DR-040 §11.39.6 left the gesture unruled and this sentence used to
    // say so ("not something this can do yet"); DR-074 §11.73.1 rules it
    // and `MoveEndpointCommand` performs it. Re-landing here would still
    // be wrong: it would rewrite a termination somebody recorded and take
    // the rack label with it, silently, under the wrong undo label.
    //
    // THE WORDS NAME AN ACT, NOT A CONTROL. This is `rackpal_core`; the
    // menu item that performs the act lives in a surface, and a refusal
    // that named it would be wrong the first time a second surface grew
    // one.
    return BindEndpointRefused(
      "That drop's ${_endWord(end)} end is already landed. To put it in a "
      'different port, move it rather than landing it again.',
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

  // ═══════════════════════════════════════════════════════════════════
  // THE REST OF TIER 1 (`#811`, DR-116 §11.115.3)
  // ═══════════════════════════════════════════════════════════════════
  // `TOP-003` was the only catalogue rule this builder asked, which was
  // an artefact of the bind path predating both tiers rather than a
  // decision anybody made. DR-116 rules that **a rule is a statement
  // about the resulting state, not about the gesture that produced it**:
  // a meaningless document is not made meaningful by which gesture wrote
  // it.
  //
  // ASKED HERE AND NOT THROUGH `evaluateConnect`, and the reason is that
  // this gesture has no second `ConnectTarget` to hand it. A bind writes
  // ONE endpoint onto a conductor whose other end is already fixed, so
  // the pair `evaluateConnect` reads is (the anchor, this port) — and the
  // anchor is an endpoint rather than a pin the caller resolved. The two
  // rules that can fire on that pair are spelled out below with their
  // ids, which is what `PLC-001..003`'s ratification demanded of exactly
  // this shape (canon §12.6(b): an unnumbered blocking rule can carry
  // neither a `Finding.ruleId` nor an AC-051 fixture pair).
  final anchor = switch (end) {
    LinkEnd.field => conductor.to,
    LinkEnd.rack => conductor.from,
  };
  if (anchor is PortEndpoint) {
    if (anchor.portId == port.portId) {
      // `TOP-001`: a conductor may not connect a port to itself. Reachable
      // by pointer: the anchor pin and the loose end's pennant sit beside
      // each other, and the surface's candidate set is what usually keeps
      // them apart — usually is not a guarantee a command may rely on.
      return BindEndpointRefused(
        'TOP-001 — ${port.designator} is the end this drop is already on, '
        'so landing it there would connect the cable to itself.',
      );
    }
    // `TOP-002`: two conductors may not duplicate the same ordered port
    // pair on the same link. A multi-conductor home run can land its
    // second pair on the jack its first already uses, which is one
    // physical punchdown recorded twice.
    for (final other in link.conductors) {
      if (identical(other, conductor)) continue;
      final ends = {other.from, other.to}.whereType<PortEndpoint>().map(
        (e) => e.portId,
      );
      if (ends.contains(anchor.portId) && ends.contains(port.portId)) {
        return const BindEndpointRefused(
          'TOP-002 — another conductor on this cable already runs between '
          'those two ports.',
        );
      }
    }
  }

  // THE LABEL GATE IS RACK-ONLY, like the write it guards. A field bind
  // passes no label (the constructor asserts it), so there is nothing to
  // normalise and nothing that could collide.
  final trimmed = end == LinkEnd.rack ? rackLabel?.trim() : null;
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
      end: end,
    ),
  );
}

/// The word a refusal uses for [end].
///
/// SPELLED ONCE. Three refusals name the end, and three copies of
/// "field"/"rack" is how one of them comes to say "rear" after somebody
/// reworded the others.
String _endWord(LinkEnd end) => switch (end) {
  LinkEnd.field => 'field',
  LinkEnd.rack => 'rack',
};
