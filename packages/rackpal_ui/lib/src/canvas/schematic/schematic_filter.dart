// rackpal_ui/src/canvas/schematic/schematic_filter.dart
//
// THE RENDER-MODE RULE, IN ONE PLACE (DR-001, canon §11.1.1). Everything
// that decides whether a Link is drawn as a wire or as a pair of net labels
// lives here, and nothing else in this package may decide it.
//
// ═════════════════════════════════════════════════════════════════════
// THE RULE, TRANSCRIBED, BECAUSE IT IS A TABLE AND NOT A SENTENCE
// ═════════════════════════════════════════════════════════════════════
//   | Unfiltered sheet (all domains)        | netLabels        |
//   | Filtered to exactly one SignalDomainId| drawn            |
//   | Alt-hover on a symbol, pin or Link    | drawn, transient |
//   | Focus / isolate on a selection        | drawn, scoped    |
//
// Read literally, and the two words that carry the most weight are EXACTLY
// ONE. Ctrl+clicking three domains visible is NOT `drawn` — the reader has
// not narrowed the question far enough for a wire to be worth its ink, and
// a rule that fired at "some domains" would put wires back on a sheet
// nobody filtered.
//
// [SheetRenderMode] is DERIVED HERE ON EVERY FRAME and is never persisted,
// never a `ProjectSettings` field and never a `Sheet` field (§11.1.1's own
// words, for CR-115's reason). Its persisted counterpart is
// `Sheet.domainFilter` (CR-067), which is a different thing about a
// different object and is not read or written by this file.
//
// THERE IS NO DENSITY TERM AND NO LINK-COUNT BRANCH. §11.1.1: render mode
// is "a function of the active filter, not a user setting and not a
// threshold". Adding one would reintroduce the silent degradation §10.1
// named as draw-every-wire's worst property, which DR-001 deletes rather
// than defers (§11.1.3 item 8: "deleted, not deferred").
//
// ═════════════════════════════════════════════════════════════════════
// FILTERED-OUT DOMAINS ARE HIDDEN, NOT GHOSTED, AND THAT IS A FLAGGED
// CORPUS CONFLICT RATHER THAN A CHOICE THIS FILE MADE QUIETLY
// ═════════════════════════════════════════════════════════════════════
// §11.2 offers a preference: "**Ghost** (default) versus **Hide**. Ghost
// preserves spatial context …; Hide is for reading a single domain
// cleanly." Ghost needs one number, and that number does not exist:
// §6.6 records it as **VERIFY** — "the design document's 8% is a
// placeholder below a legible floor; AC-058/D11 requires a *tested* value
// against both themes, which is genuine measurement and not a thing that
// can be settled on paper", and §15 item 1 keeps it open.
//
// So M2-E ships the OTHER HALF OF THE SAME SHIPPED PREFERENCE. Picking an
// alpha here would be inventing a rendering constant the corpus explicitly
// refuses to let anyone set on paper (G4), and it would be set in the one
// place §6.6 says it must not be. Ghost lands when the measurement does,
// and it is one branch in `schematic_paint_plan.dart` when it comes.

import 'package:meta/meta.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// canon §11.1.1's derived value. Never persisted — see the file header.
enum SheetRenderMode { netLabels, drawn }

/// Which of §11.1.1's three triggers put a scope into `drawn`.
///
/// Carried so the HUD can name it. A user who sees wires appear is owed
/// the reason they appeared — §11.4's own `Focus: AVR-1 · 1 hop` chip is
/// that principle already stated for one of the three.
enum DrawnTrigger {
  /// A single domain is soloed in the filter bar (§11.2).
  domainSolo,

  /// `Alt` is held over a symbol (§11.4). Transient: no click, no mode,
  /// no state that outlives the pointer.
  altHover,

  /// `F` with a selection (§11.4). N = 1 hop, §11.4's own default.
  focus,
}

/// The eight domain chips' order, and therefore `1`–`8`'s meaning.
///
/// ASCENDING `SignalDomainId`, which is M2-D's rule for the label runs
/// applied to the bar that switches them. Its reasoning transfers exactly:
/// docs/05 §11.2's figure prints VID · RF · AUD · DIG · NET · CTL · PWR ·
/// STR, but NO MODEL FIELD CARRIES THAT ORDER — `SignalDomainDef` has no
/// index — and inventing one to match a figure would be fabricating a fact
/// (G4). `buildSeedSignalDomains()` happens to CONSTRUCT them in the
/// figure's order, but that is insertion order in a hash map, which
/// `sugiyama.dart`'s determinism rule 2 forbids reading as data and which a
/// document loaded from JSON carries no promise about.
///
/// The order is arbitrary but total, which is all determinism needs — and
/// using M2-D's order means chip position and sub-picture order agree by
/// construction, so the n-th chip switches the n-th run.
///
/// THE DISAGREEMENT IS REAL AND IS NOT RESOLVED HERE: a user reading §11.2
/// expects `1` to solo Digital Video and gets Analog Audio. Fixing it needs
/// an ORDER on `SignalDomainDef`, which is a model change and therefore a
/// ruling, not an implementation detail.
List<SignalDomainId> schematicDomainOrder(Registries registries) =>
    registries.signalDomains.keys.toList()..sort((a, b) => a.v.compareTo(b.v));

/// The transient, per-view filter state (§11.2: "The view filter is
/// **transient and per-view**, never persisted in the document").
///
/// [visibleDomains] EMPTY MEANS ALL, and that is not a null-object trick —
/// it is the difference between "the user has not filtered" and "the user
/// filtered to nothing". The second is reachable (`[None]`) and is
/// [hidesEverything]; conflating them would make `[None]` silently mean
/// `[All]`.
@immutable
final class SchematicViewFilter {
  const SchematicViewFilter({
    this.visibleDomains = const <SignalDomainId>{},
    this.explicit = false,
  });

  /// The domains the user selected, or empty for the unfiltered sheet.
  final Set<SignalDomainId> visibleDomains;

  /// Whether [visibleDomains] is a deliberate selection. False is the
  /// unfiltered sheet; true with an empty set is `[None]`.
  final bool explicit;

  bool get hidesEverything => explicit && visibleDomains.isEmpty;

  /// Whether [domain]'s net labels are drawn at all.
  bool shows(SignalDomainId domain) =>
      !explicit || visibleDomains.contains(domain);

  /// Whether the unresolved-domain run (`kUnresolvedDomainFragmentKey`) is
  /// drawn.
  ///
  /// IT FOLLOWS THE FILTER RATHER THAN GETTING A CHIP. M2-D deliberately
  /// kept the unresolved bucket out of `domainFragments` because "minting a
  /// fake id would put a ninth chip in the domain filter bar … for
  /// something no `Service` can resolve to". A ninth chip here would
  /// undo that; so an explicit filter hides it, and the unfiltered sheet
  /// shows it, which is where a reader can actually see that some cable's
  /// family did not resolve.
  bool get showsUnresolved => !explicit;

  /// §11.1.1's "exactly one", and the only place the phrase is evaluated.
  SignalDomainId? get soloedDomain =>
      explicit && visibleDomains.length == 1 ? visibleDomains.first : null;

  /// Solos [domain] — §11.2's plain click.
  SchematicViewFilter solo(SignalDomainId domain) => SchematicViewFilter(
    visibleDomains: <SignalDomainId>{domain},
    explicit: true,
  );

  /// Adds or removes [domain] — §11.2's `Ctrl+click`.
  ///
  /// TOGGLING OFF THE LAST DOMAIN LEAVES `[None]`, not `[All]`. A user who
  /// Ctrl+clicks a soloed chip meant to remove it; springing back to the
  /// whole sheet would be the surface deciding they meant the opposite.
  SchematicViewFilter toggle(SignalDomainId domain) {
    final next = <SignalDomainId>{...visibleDomains};
    if (!next.remove(domain)) next.add(domain);
    return SchematicViewFilter(visibleDomains: next, explicit: true);
  }

  /// §11.2's `[All]`, and `` ` `` — back to the unfiltered sheet.
  SchematicViewFilter showAll() => const SchematicViewFilter();

  /// §11.2's `[None]`.
  SchematicViewFilter showNone() => const SchematicViewFilter(explicit: true);

  @override
  bool operator ==(Object other) =>
      other is SchematicViewFilter &&
      other.explicit == explicit &&
      other.visibleDomains.length == visibleDomains.length &&
      other.visibleDomains.containsAll(visibleDomains);

  @override
  int get hashCode => Object.hash(
    explicit,
    Object.hashAllUnordered(visibleDomains),
  );
}

/// One resolved `drawn` scope: which links, why, and what to say about it.
@immutable
final class DrawnScope {
  const DrawnScope({
    required this.trigger,
    required this.linkIds,
    required this.headline,
  });

  final DrawnTrigger trigger;

  /// The links that render as wires. Everything else on the sheet stays in
  /// `netLabels`, which is the base state and not a fallback (DR-001).
  final Set<Uuid> linkIds;

  /// §11.4's HUD chip, generalised to all three triggers.
  final String headline;

  /// Whether the scope's own domain run should be SUPPRESSED rather than
  /// replayed under the wires.
  ///
  /// TRUE FOR A SOLOED DOMAIN ONLY, and the asymmetry is the whole of M2-D's
  /// performance contract. A soloed domain's every link is in scope, so its
  /// label run is replaced wholesale — "M2-E replays seven domains' label
  /// runs unchanged and rebuilds only the eighth". `Alt`-hover and focus
  /// scope a HANDFUL of links out of the middle of several runs; a run is a
  /// contiguous `IntRange` and there is no such thing as replaying part of
  /// one, so those two draw their wires as an OVERLAY over the untouched
  /// label layer. That is also what §11.4 describes — "whatever is under
  /// the cursor lights its subgraph and everything else recedes" — rather
  /// than a compromise forced by the data structure.
  bool get replacesDomainRun => trigger == DrawnTrigger.domainSolo;
}

/// Every link that has at least one drawn stub, bucketed by domain.
///
/// Read off `SchematicScene.netLabels` — the geometry M2-D published — so
/// the chip counts, the filter and the wires all answer from one source.
/// Counting `doc.links` instead would count links the sheet does not draw
/// (a home run to the field with no drawn pin at either end) and the bar
/// would then promise wires that cannot appear.
Map<SignalDomainId, Set<Uuid>> linksByDomain(SchematicScene scene) {
  final out = <SignalDomainId, Set<Uuid>>{};
  for (final label in scene.netLabels) {
    final domain = label.style.domainId;
    if (domain == null) continue;
    out.putIfAbsent(domain, () => <Uuid>{}).add(label.linkId);
  }
  return out;
}

/// Every link with a stub on one of [deviceIds] — §11.4's one hop.
///
/// N = 1 IS §11.4's OWN DEFAULT ("N defaults to 1"), and the adjustment
/// binding is not built: §15 item 2 marks `[` / `]` **VERIFY** against the
/// arbitrated keymap, so binding it would be advertising a key the corpus
/// has not cleared.
Set<Uuid> linksTouching(SchematicScene scene, Set<String> deviceIds) {
  if (deviceIds.isEmpty) return const <Uuid>{};
  return <Uuid>{
    for (final label in scene.netLabels)
      if (deviceIds.contains(label.deviceId)) label.linkId,
  };
}

/// Resolves §11.1.1's table into at most one [DrawnScope].
///
/// ── PRECEDENCE, STATED ONCE ─────────────────────────────────────────────
/// `Alt`-hover beats focus beats the domain solo. The order is not
/// arbitrary: hover is the most transient and the most deliberate — the
/// user is holding a modifier down right now — and a hover that could not
/// be seen because a filter was already drawn would make the modifier feel
/// broken. Focus beats the solo for the same reason one step weaker.
///
/// AT MOST ONE, deliberately. Two live scopes would need a union, and a
/// union would leave the user unable to tell which trigger drew which wire
/// — the HUD headline is a single sentence because the scope is a single
/// thing.
DrawnScope? resolveDrawnScope({
  required SchematicScene scene,
  required SchematicViewFilter filter,
  required String? altHoveredDeviceId,
  required Set<String> focusedDeviceIds,
  required String Function(String deviceId) designatorOf,
}) {
  if (altHoveredDeviceId != null) {
    final ids = linksTouching(scene, <String>{altHoveredDeviceId});
    return DrawnScope(
      trigger: DrawnTrigger.altHover,
      linkIds: ids,
      headline:
          'Alt-hover: ${designatorOf(altHoveredDeviceId)} · 1 hop · '
          '${ids.length} ${ids.length == 1 ? 'cable' : 'cables'}',
    );
  }
  if (focusedDeviceIds.isNotEmpty) {
    final ids = linksTouching(scene, focusedDeviceIds);
    final names = (focusedDeviceIds.toList()..sort()).map(designatorOf);
    return DrawnScope(
      trigger: DrawnTrigger.focus,
      linkIds: ids,
      headline:
          'Focus: ${names.join(', ')} · 1 hop · '
          '${ids.length} ${ids.length == 1 ? 'cable' : 'cables'}',
    );
  }
  final solo = filter.soloedDomain;
  if (solo != null) {
    final ids = linksByDomain(scene)[solo] ?? const <Uuid>{};
    return DrawnScope(
      trigger: DrawnTrigger.domainSolo,
      linkIds: ids,
      headline:
          '${solo.v} · drawn · '
          '${ids.length} ${ids.length == 1 ? 'cable' : 'cables'}',
    );
  }
  return null;
}
