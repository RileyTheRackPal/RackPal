// RJ-001's fourth gesture, and the last one M2 owed: multi-draw.
//
// docs/05:484 — "With N ports selected in one bank, dragging to a target
// bank creates N `Link`s in rank order under **one undo entry** — the
// 'wire the 8x8 matrix to eight zone amps' gesture. Live preview shows all
// N bands. This is the demo moment."
//
// ═══════════════════════════════════════════════════════════════════════
// N `Link`s. NOT ONE `Link` WITH N `Conductor`s — DR-012.2
// ═══════════════════════════════════════════════════════════════════════
// The two sit one line apart in docs/05 and swapping them changes the pull
// sheet's row count: eight cables an installer pulls separately is a
// different bill of materials from one cable with eight conductors
// (AC-053). `atomic_connect.dart` is the other one. The distinction is
// deliberate and preserved, and `multi_draw_test.dart` counts links for
// exactly this reason.
//
// ═══════════════════════════════════════════════════════════════════════
// RANK IS `PortDef.order` THEN `key` — DR-012.2, AND NOT `channelIndex`
// ═══════════════════════════════════════════════════════════════════════
// The same sort `_seqIn` uses for `PORT_SEQ` and `chainOutputFor` uses for
// DR-012.1, for the reason `connect_target.dart` records: two orderings of
// one port list is how a pin ends up with one number on the schedule and a
// different one in the gesture that wires it. `channelIndex` is the field
// that looks purpose-built and is nullable, undocumented and **set on no
// seed port** — a rule reading it would fall through to this answer on
// every real document with an extra branch nothing could test.
//
// ═══════════════════════════════════════════════════════════════════════
// THE BANK IS REACHABLE, AND THAT IS MEASURED RATHER THAN ASSUMED
// ═══════════════════════════════════════════════════════════════════════
// The trap this file was written expecting is the one DR-012 found three
// times: a `PortDef` field that looks purpose-built and is populated on no
// shipped template, so the gesture reading it is unreachable from the
// catalog. `bankKey` is the opposite. **All 727 seed ports carry one**,
// across 154 banks in 45 of the 48 templates, 57 of those banks holding
// four or more ports — and `A01` declares `srcIn=16` and `zoneOut=16`,
// which is docs/05's "8x8 matrix to eight zone amps" demo moment sitting in
// the shipped catalog. `multi_draw_test.dart` asserts that against
// `buildSeedCatalog()` so it cannot quietly stop being true.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THE CORPUS DOES NOT SAY, AND WHAT IS DONE ABOUT IT
// ═══════════════════════════════════════════════════════════════════════
// docs/05 says "N ports selected ... creates N Links" and says nothing
// about a target bank with fewer free jacks than N. This file **connects
// what fits and reports the rest**, which is §11.8.3's ruling for
// `atomicConnect` applied to the case beside it — with one deliberate
// difference:
//
//   AN UNPAIRED SOURCE MINTS NOTHING. §11.8.3 lets an atomic set's surplus
//   conductor end open, and that is right there: the conductor is inside
//   ONE cable that physically exists, so an open end is a real termination
//   a real installer will find. A multi-draw surplus would be an entire
//   `Link` — a whole cable, its own schedule row, its own `W` number —
//   pulled to nowhere. DR-013 has just ruled on the same shape from the
//   other direction: "a cable to a device that has been deleted is not a
//   design intent; it is debris."
//
// So `unpaired` is returned rather than written, the caller says how many
// were left, and the user decides. This is a consequence of two existing
// rulings rather than a new one — if it ever needs to be argued with, it
// wants a DR of its own.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/connect_commands.dart';
import 'package:rackpal_core/src/derived/connect_rules.dart';
import 'package:rackpal_core/src/derived/connect_target.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One planned cable: a source pin paired with the sink pin rank order
/// gave it.
@immutable
final class MultiDrawPair {
  const MultiDrawPair({required this.from, required this.to});

  final ConnectTarget from;
  final ConnectTarget to;
}

/// A selected source pin that will get no cable, and why.
@immutable
final class MultiDrawUnpaired {
  const MultiDrawUnpaired({required this.from, required this.reason});

  final ConnectTarget from;

  /// A complete sentence about THIS document — `connect_rules.dart`'s rule
  /// for refusals, applied to an omission. "AMP-1 J09 has no free jack
  /// left in Zone Outputs." never "no target".
  final String reason;
}

/// What a multi-draw gesture would do.
@immutable
final class MultiDrawPlan {
  const MultiDrawPlan({required this.pairs, required this.unpaired});

  /// In rank order. Empty means the gesture writes nothing.
  final List<MultiDrawPair> pairs;

  /// Selected sources that found no sink. See the file header for why
  /// these mint nothing rather than ending open.
  final List<MultiDrawUnpaired> unpaired;

  bool get isEmpty => pairs.isEmpty;

  /// How many cables this gesture makes — the pull sheet's row count, and
  /// the number DR-012.2 makes worth being careful about.
  int get linkCount => pairs.length;
}

/// The ports of [deviceId]'s [bankKey] bank, in DR-012.2's rank order.
///
/// `PortDef.order` then `key`. Exposed because the UI needs the same
/// order to draw the N bands in, and two orderings of one bank is the
/// defect this whole file is careful about.
List<ConnectTarget> portsInBank(
  RackDocument doc, {
  required Uuid deviceId,
  required String bankKey,
}) {
  final device = doc.devices[deviceId];
  if (device == null) return const [];
  final body = bodyFor(device, doc.templates);
  if (body == null) return const [];

  final defs = portsInDeclaredOrder(
    body.ports.where((p) => p.bankKey == bankKey),
  );

  return <ConnectTarget>[
    for (final def in defs)
      ?resolveConnectTarget(doc, deviceId: deviceId, portKey: def.key.v),
  ];
}

/// Pairs [sources] against the free jacks of [toDeviceId]'s [toBankKey]
/// bank, in rank order.
///
/// [sources] are port keys the user selected; they are filtered to
/// [fromBankKey] and re-sorted here rather than trusted, because "N ports
/// selected in ONE bank" is the gesture's precondition and a caller that
/// got it wrong should produce a smaller plan, not a wrong one.
///
/// GREEDY, AND ONE CABLE PER JACK. Each candidate sink is consumed at most
/// once even where `effectiveMaxConnections` would allow a second: a bulk
/// gesture that quietly stacked two cables on one jack because the model
/// permits it is not what "wire the matrix to the amps" means, and the
/// pin-to-pin gesture is still there for the deliberate case.
MultiDrawPlan planMultiDraw(
  RackDocument doc, {
  required Uuid fromDeviceId,
  required String fromBankKey,
  required Iterable<String> sources,
  required Uuid toDeviceId,
  required String toBankKey,
}) {
  final selected = sources.toSet();
  final from = <ConnectTarget>[
    for (final t in portsInBank(
      doc,
      deviceId: fromDeviceId,
      bankKey: fromBankKey,
    ))
      if (selected.contains(t.def.key.v)) t,
  ];
  final candidates = portsInBank(
    doc,
    deviceId: toDeviceId,
    bankKey: toBankKey,
  );

  final bankLabel = bankLabelFor(doc, deviceId: toDeviceId, bankKey: toBankKey);
  final pairs = <MultiDrawPair>[];
  final unpaired = <MultiDrawUnpaired>[];
  final consumed = <Uuid>{};

  for (final source in from) {
    ConnectTarget? landed;
    ConnectRefused? lastRefusal;
    for (final candidate in candidates) {
      if (consumed.contains(candidate.portId)) continue;
      final verdict = evaluateConnect(doc, source, candidate);
      if (verdict is ConnectRefused) {
        lastRefusal = verdict;
        continue;
      }
      landed = candidate;
      break;
    }
    if (landed == null) {
      unpaired.add(
        MultiDrawUnpaired(
          from: source,
          // THE RULE'S OWN SENTENCE WHERE THERE IS ONE. A user told "no
          // free jack" for a bank that is not full but whose every jack a
          // tier-1 rule refuses would go looking for space they already
          // have.
          // BOTH HALVES WHERE THERE IS A RULE, which is the format the
          // schematic already speaks: `connect_rules.dart`'s header says
          // "'TOP-003' alone is a log line, not an explanation", and the
          // sentence alone is a finding the user cannot look up.
          reason: lastRefusal == null
              ? '${source.citation} found no free jack in $bankLabel.'
              : '${source.citation}: ${lastRefusal.ruleId} — '
                    '${lastRefusal.message}',
        ),
      );
      continue;
    }
    consumed.add(landed.portId);
    pairs.add(MultiDrawPair(from: source, to: landed));
  }

  return MultiDrawPlan(
    pairs: List<MultiDrawPair>.unmodifiable(pairs),
    unpaired: List<MultiDrawUnpaired>.unmodifiable(unpaired),
  );
}

/// A bank's human label, falling back to its key.
///
/// PUBLIC BECAUSE THE SCREEN SAYS THIS WORD TOO. The status line has to
/// name the bank a run was selected in and the bank a drop would land on,
/// and a second lookup in `rackpal_ui` would be a second answer to
/// "what is this bank called" — the shape of drift this file's header
/// already refuses for ORDER. One function, one name, both surfaces.
String bankLabelFor(
  RackDocument doc, {
  required Uuid deviceId,
  required String bankKey,
}) {
  final device = doc.devices[deviceId];
  final body = device == null ? null : bodyFor(device, doc.templates);
  for (final bank in body?.banks ?? const <BankDef>[]) {
    if (bank.key == bankKey) {
      return bank.label.trim().isEmpty ? bankKey : bank.label;
    }
  }
  return bankKey;
}

/// The N `ConnectPortsCommand`s [plan] calls for, in rank order.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A LIST, NOT A `Transaction` — AND THAT IS HOW "ONE UNDO ENTRY" HAPPENS
/// ═══════════════════════════════════════════════════════════════════════
/// docs/05:484 wants "N `Link`s in rank order under **one undo entry**".
/// The obvious move is to wrap these in a `Transaction` here, and it is
/// wrong: a `Transaction` also carries the selection before and after, and
/// core has no idea what is selected. `DocumentController.transact` is the
/// thing that knows — it snapshots the selection, flattens nested scopes so
/// one gesture is one entry however many calls it nests, and pushes the
/// undo record. So the caller runs:
///
/// ```dart
/// controller.transact(LabelKey.multiDraw, (tx) {
///   for (final c in commands) tx.add(c);
/// });
/// ```
///
/// which is the same path every other multi-command gesture in the app
/// already takes.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ONE `ConnectAllocations` ACROSS ALL N — THE DEFECT THIS AVOIDS
/// ═══════════════════════════════════════════════════════════════════════
/// Every allocator reads the DOCUMENT, and none of these commands has been
/// applied yet. Built naively, all N links would be called `W006`, all N
/// nets `N006`, and two pairs landing on one device would be handed the
/// same `J`-number — on a gesture whose entire purpose is to make eight
/// cables at once, and whose output is eight schedule rows an installer is
/// meant to tell apart. Link designators are PROJECT-WIDE unique
/// (`link_commands.dart`), so that is not a cosmetic collision.
///
/// Returns an EMPTY list when [plan] pairs nothing — a gesture that writes
/// no command leaves no undo entry, the same rule a refused pin-to-pin
/// connect follows (DR-011.1), and `transact` already declines to push a
/// transaction with no children.
List<Command<RackDocument>> buildMultiDrawCommands({
  required RackDocument doc,
  required MultiDrawPlan plan,
  required MediaTypeId media,
  required DateTime now,
  required String actor,
}) {
  if (plan.isEmpty) return const [];

  final reserve = ConnectAllocations();
  final commands = <Command<RackDocument>>[];
  for (final pair in plan.pairs) {
    final built = buildConnectPortsCommand(
      doc: doc,
      from: pair.from,
      to: pair.to,
      media: media,
      now: now,
      actor: actor,
      reserve: reserve,
    );
    // A REFUSAL HERE IS NOT REACHABLE THROUGH `planMultiDraw`, which has
    // already run the same rules over the same document — but this builder
    // is public and a caller may hand it a plan built against a document
    // that has since moved. Skipping is the answer that cannot write a
    // half-formed transaction; the plan is what the user was shown.
    if (built is ConnectPortsReady) commands.add(built.command);
  }
  return List<Command<RackDocument>>.unmodifiable(commands);
}
