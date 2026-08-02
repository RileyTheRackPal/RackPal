// rackmate_core/src/draw/scene/net_label_layer.dart — pure Dart.
//
// THE DEFAULT RENDER OF A LINK (DR-001, canon §11.1). Every `Link` draws
// as a PAIR OF NET LABELS — a short stub off each of its two pins carrying
// the generated net name — and NOT as a drawn wire.
//
// ═════════════════════════════════════════════════════════════════════
// THIS IS NOT A DEGRADATION AND MUST NOT BE DESCRIBED AS ONE
// ═════════════════════════════════════════════════════════════════════
// DR-001 reverses §10.1's own recommendation and canon §11.1 says the
// ruling is "not to be re-argued in any document":
//
//   > Any prose that presents draw-every-wire as the default, or net
//   > labels as a *degradation*, *fallback*, *density mitigation* or
//   > *mode the product falls back into*, is inverted: labels are the
//   > base state and wires are the opt-in overlay.
//
// There is NO density term and NO threshold. Render mode is a function of
// the active filter alone (§11.1.1): one selected domain, `Alt`-hover, or
// a focused subgraph switches THAT scope to `drawn`; everything else is
// labelled. So this file has no link-count branch, and adding one would
// reintroduce the silent degradation §10.1 named as draw-every-wire's
// worst property.
//
// EDGE ROUTING IS NOT HERE AND IS NOT COMING HERE. Interval-graph channel
// routing, track ordering, the Bentley–Ottmann sweep, hop arcs and
// junction staggering all leave v1 scope entirely (§11.1.3, items 1–5).
// The `drawn` mode that does ship is a deterministic per-link orthogonal
// staircase, and it belongs to M2-E beside the domain filter that triggers
// it — not to this file.
//
// ═════════════════════════════════════════════════════════════════════
// PER-DOMAIN SUB-PICTURES ARE THE POINT OF THE OP ORDER
// ═════════════════════════════════════════════════════════════════════
// The ops are emitted GROUPED BY SIGNAL DOMAIN, one contiguous run per
// domain, and each run is registered as a `DiagramScene` fragment. That is
// load-bearing for performance, not tidiness: it "is what lets a domain
// filter switch to drawn mode without rebuilding seven other pictures"
// (roadmap M2 risks). M2-E replays seven domains' label runs unchanged and
// rebuilds only the eighth.
//
// A fragment is a CONTIGUOUS `IntRange`, so the grouping IS the ordering:
// scatter one domain's stubs through the list and the sub-picture stops
// existing. Domains are emitted in ascending `SignalDomainId`, and stubs
// within a domain in the scene's own link order. Ascending id rather than
// docs/05 §11.2's filter-bar order (VID, RF, AUD, DIG, NET, CTL, PWR, STR)
// because NO MODEL FIELD CARRIES THAT ORDER — `SignalDomainDef` has no
// index — and inventing one to match a figure would be fabricating a fact
// (G4). The order is arbitrary but total, which is all determinism needs.
//
// UNLIKE A SYMBOL FRAGMENT, A DOMAIN FRAGMENT IS ABSOLUTE. `symbol_layer`
// builds in LOCAL space and `schematic_scene` brackets each symbol with a
// translate; a domain's stubs belong to many symbols at once and there is
// no local frame they could share, so these ops carry sheet coordinates
// and replay with no bracket. A caller that positions a fragment itself
// must not apply a transform to these.
//
// ═════════════════════════════════════════════════════════════════════
// THE FOUR CHANNELS, AND WHERE THEY LAND ON A STUB
// ═════════════════════════════════════════════════════════════════════
// DR-001 §11.1.3 keeps the whole palette: "hue by domain, dash + weight +
// glyph + tag by family. It applies to drawn wires, to the tag pill, to
// the net-label stub's leader, to the legend `T0.01`, and to the `TYPE`
// chip in the schedule." Resolution lives in ONE place —
// `signal_style.dart` — and this file only places what it returns:
//
//   hue    → the leader stroke, the pennant outline, the pennant fill
//            (at [NetLabelStyle.fillAlpha]) and the family token's ink
//   dash   → the leader stroke's dash
//   weight → the leader stroke's width
//   glyph
//    + tag → the family token drawn inside the pennant
//
// THE TOKEN IS WHY THE DEFAULT RENDER CARRIES ALL FOUR CHANNELS AND NOT
// THREE. §11.5's figure shows the net name alone, which would leave the
// DEFAULT sheet unable to tell HDMI 1.4 from 2.0 except by a hairline
// weight difference — and AC-054's whole resolution of requirement 4 is
// "hue = domain; dash + weight + glyph + tag = type". A channel that only
// appears once you have filtered to one domain is not a channel.
//
// ═════════════════════════════════════════════════════════════════════
// THE PENNANT SHAPE, AND THE FIGURE IT IS READ FROM
// ═════════════════════════════════════════════════════════════════════
// docs/05 §11.5 draws:
//
//   source end:  J09 ├──⟩ HDMI_MTX1_OUT3
//   sink end:    HDMI_MTX1_OUT3 ⟨──┤ J03
//
// and says "a right-pointing chevron is a signal leaving, left-pointing is
// arriving". BOTH CHEVRONS IN THAT FIGURE POINT AWAY FROM THEIR PIN, and
// the sentence still holds, because docs/05 §3's edge rule puts sinks on
// the left edge and sources on the right: away-from-the-body IS rightward
// at a source and leftward at a sink. One geometric rule reproduces both
// the figure and the sentence, so that is the rule taken here — the
// pennant is a pentagon whose apex points AWAY from the body, a signpost
// saying "the rest of this net is out that way", which is true by
// construction for every stub.
//
// THE REJECTED READING, recorded so it is not re-litigated: "the chevron
// points along the direction of signal flow" would put a RIGHT-pointing
// chevron at a sink on a left edge (signal flows rightward into the pin),
// contradicting the figure at exactly the end the figure draws. And the
// figure cannot be reproduced literally either way — it places the chevron
// BETWEEN the leader and the name, which no pentagon does. Direction
// itself is not re-encoded here: `symbol_layer.dart` already draws the
// arrowhead "into body = sink, away = source" at every pin, and a second
// derivation of the same fact is how a painter and a hit-tester drift
// apart (that file's own header).
//
// ═════════════════════════════════════════════════════════════════════
// GEOMETRY CONSTRAINTS THAT ARE DERIVED, NOT CHOSEN
// ═════════════════════════════════════════════════════════════════════
//  * THE PENNANT MUST BE NO TALLER THAN THE PIN PITCH. Left/right pins sit
//    at `kPinPitch` = 2 gu and each grows a horizontal pennant at the same
//    x; a pennant taller than 2 gu overlaps its neighbour's. 2 gu is
//    14.173 diagram units, so [NetLabelStyle.heightFactor] is capped
//    accordingly and `net_label_layer_test.dart` asserts the product
//    against `kPinPitch × kSchematicUnitsPerGrid` rather than against a
//    transcribed number.
//  * TOP/BOTTOM PINS GET A COMB, IN A BOUNDED NUMBER OF LANES. Their
//    pennants are horizontal but their pins are 2 gu apart HORIZONTALLY,
//    and a pennant is far wider than 2 gu, so neighbouring flags must be
//    pushed to different depths or they overprint.
//
//    THE STEP USED TO BE `i`, UNBOUNDED, and it is `i % lanes` now. The
//    field reported the difference as a picture: the i-th pin got a leader
//    i pennant-heights long, so A01's twelve top pins drew a twelve-step
//    diagonal staircase climbing off the sheet, a 48-port switch would have
//    drawn a 48-step one, and the fans crossed whatever devices lay under
//    them. The sheet was mostly whitespace holding up a comb.
//
//    `lanes` IS COMPUTED, NOT PICKED, because the unbounded version was
//    buying something real and a magic number would have quietly stopped
//    buying it. What makes two flags collide is a pennant wider than the
//    pin pitch, so the lane count that separates them is exactly
//    `ceil(widestPennantOnThisEdge / pitch)` — after which same-lane
//    neighbours are `lanes * pitch` apart, which is at least one pennant
//    width by construction. On the shipped catalog that is three to five
//    lanes rather than forty-eight, and the no-overlap guarantee is the
//    same one, held for the same reason.
//
//    MEASURED PER EDGE AND PER SYMBOL, from the stubs that actually land
//    there. A device whose only wired top pin carries a short net name gets
//    one lane; the matrix next to it gets five. Sizing every edge by the
//    widest label in the DOCUMENT would put the matrix's comb on the
//    two-port switch.
//
//    The

//    alternative — rotating the pennant to run along its stub — is not
//    taken: `TextStyleSpec.rotationRad` exists but how an anchor composes
//    with a rotation is unspecified in the corpus and unpinned by any
//    screen/print parity test, so it would be a divergence risk taken for
//    a layout nicety.
//
// ═════════════════════════════════════════════════════════════════════
// SCOPE, STATED HONESTLY (cf. `symbol_layer.dart`'s own list)
// ═════════════════════════════════════════════════════════════════════
// NOT DONE, and flagged rather than silently omitted:
//  * LABEL/LABEL COLLISION AVOIDANCE beyond the two rules above. Two links
//    on ONE top pin can still push a pennant into the next pin's comb
//    slot. There is no label placement pass in v1 — §11.1.3 neither keeps
//    one nor defers one — and a pass that moved labels to avoid overlap
//    would have to be deterministic to survive the byte-identical exit
//    criterion, which is a real design, not a tweak.
//  * HIT REGIONS. §11.5's "both flags of a net highlight together on
//    hover" is interaction and belongs with the filter and `Alt`-hover in
//    M2-E. `DiagramScene.hits` therefore still means "a device" exactly as
//    M2-C left it, and mixing link ids into it would silently change what
//    every existing consumer of that list is looking at. The geometry M2-E
//    needs is published as [RenderedNetLabel] instead — measured here,
//    once, so a hover test cannot drift from what was drawn.
//  * GHOST ALPHA for filtered-out domains (docs/05 §6.6 marks the value
//    **VERIFY**, unmeasured). Nothing filters yet.
//  * The TAG PILL's `{tag} · {type} · {length}` content and the drawn
//    wire's midpoint glyph. Both are `drawn` mode.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/derived/equipment_list.dart'
    show kUnknownCell;
import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/path.dart';
// #124 — channel 4a as geometry, and the ONE width both this file's sizer
// and its emitter read for it.
import 'package:rackmate_core/src/draw/scene/family_glyph.dart';
import 'package:rackmate_core/src/draw/scene/rack_style.dart';
import 'package:rackmate_core/src/draw/scene/signal_style.dart';
import 'package:rackmate_core/src/draw/scene/symbol_layer.dart';
import 'package:rackmate_core/src/draw/spec.dart';
import 'package:rackmate_core/src/draw/text.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/template.dart' show SymbolSide;
import 'package:rackmate_core/src/units/ids.dart';

/// The stub and pennant figures, in the units each one is naturally
/// stated in: LAYOUT distances in grid units (so they track `kGridUnit`
/// like every other schematic dimension), TYPE sizes in diagram units
/// (which is what `RackTextSizes` already is).
///
/// EVERY FIELD IS A STATED CHOICE. docs/05 §11.5 specifies the pennant's
/// CONTENT and its 12% fill and gives no figure for its size, so unlike
/// `SchematicMetrics` — where every field but one is a citation — nothing
/// here is transcribed from the corpus. They are gathered in one type so a
/// reader can see that, and so a caller can retune the sheet without
/// touching the layer.
@immutable
final class NetLabelStyle {
  const NetLabelStyle({
    this.theme = SignalTheme.light,
    this.leaderGu = 3,
    this.padGu = 0.5,
    this.gapGu = 0.5,
    this.tipGu = 0.5,
    this.heightFactor = 1.5,
    this.fillAlpha = 31,
    this.maxCombLanes = 6,
    this.padEm = 0.55,
    this.nameSizePt = RackTextSizes.name,
    this.tokenSizePt = RackTextSizes.type,
    this.outlineWidthPt = kMinSignalStrokePt,
  });

  /// Which of `SignalDomainDef`'s two stored hues to draw in. A UI
  /// preference, never persisted in the document (docs/05 §6.2/§6.5).
  final SignalTheme theme;

  /// Length of the leader between a pin's edge and its pennant.
  final double leaderGu;

  /// Inset of the pennant's text from its own outline, as a FLOOR in grid
  /// units. See [padEm], which is usually the one that wins.
  final double padGu;

  /// The same inset expressed as a multiple of the NET NAME'S OWN SIZE, and
  /// the larger of the two figures is what the pennant uses.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// PADDING THAT DOES NOT KNOW THE TYPE SIZE IS PADDING THAT RUNS OUT
  /// ═══════════════════════════════════════════════════════════════════
  /// [padGu] is 0.5 gu — a fixed distance on the sheet, chosen against the
  /// type size the pennant happened to carry when it was written. The
  /// pennant's CONTENT scales with the text (it is a measured token plus a
  /// measured name), so as soon as the type moves, a constant inset stops
  /// being an inset and starts being a rounding error: the glyphs reach
  /// closer and closer to the outline until the two read as one mark and
  /// the names of two neighbouring flags appear to run together. That is
  /// what the field reported.
  ///
  /// Expressing it in EM makes the inset a property of the text rather
  /// than of the sheet, which is the ordinary typographic rule and the one
  /// a reader's eye is calibrated for. [padGu] survives as a FLOOR so a
  /// very small type size cannot collapse the inset to nothing — the two
  /// are a max, not an override.
  ///
  /// AGAINST THE NAME, NOT THE TOKEN. They are different sizes
  /// ([nameSizePt] vs [tokenSizePt]) and the name is both the larger and
  /// the run the reader is actually reading (`SchematicPalette
  /// .netLabelText`). Sizing the inset off the smaller one would leave the
  /// bigger run tighter than the smaller, which is the wrong way round.
  final double padEm;

  /// Gap between the family token and the net name inside a pennant, and
  /// between one pennant and the next when a pin carries several.
  final double gapGu;

  /// Depth of the pentagon's point.
  final double tipGu;

  /// Pennant height as a multiple of [nameSizePt]. CAPPED BY THE PIN
  /// PITCH — see the file header; 1.5 × 9 = 13.5 units against the 14.173
  /// that 2 gu comes to.
  final double heightFactor;

  /// Alpha of the pennant fill, 0–255. docs/05 §11.5: "Fill is the domain
  /// colour at 12% with a full-strength outline" — 12% of 255 is 30.6, and
  /// 31 is the nearest integer. Baked into the fill colour, NEVER an
  /// opacity layer: the `saveLayer` ban applies hardest on a per-frame
  /// path (§11.2), and this is one.
  final int fillAlpha;

  /// The hard ceiling on comb depth — how many lanes a top/bottom edge may
  /// spread its flags across, however wide they are.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A CEILING OVER A DERIVED NUMBER, AND IT CAN COST AN OVERLAP
  /// ═══════════════════════════════════════════════════════════════════
  /// [_laneCount] derives what it NEEDS — `ceil((widest + gap) / pitch)` —
  /// and that number is bounded but not small: a long net name against a
  /// 2 gu pin pitch asks for a dozen lanes or more, which is a staircase
  /// tall enough that the field reported it twice.
  ///
  /// So the derived figure is capped. **Six is a judgement, not a
  /// measurement**, and unlike everything else in this file it buys its
  /// tidiness with a real cost: on an edge that needed more, two same-lane
  /// flags now sit closer than one flag is wide and OVERPRINT. That is
  /// accepted rather than hidden — the flags are opaque, so the nearer one
  /// wins cleanly instead of the two blending into an unreadable smear,
  /// and a reader who needs the covered name can hover or solo the domain
  /// to draw the wire instead.
  ///
  /// The honest alternative, deferred rather than dismissed: shorten the
  /// pennant on a crowded edge (abbreviate the net name, or drop the
  /// family token) so the lane count it needs comes down on its own. That
  /// is a legibility trade of its own and wants its own decision.
  final int maxCombLanes;

  /// The net name's size. `RackTextSizes.name` — the net name is the
  /// primary visual identity of a connection under DR-001 (§11.1.5), so
  /// it takes the secondary-label size rather than the smallest one.
  final double nameSizePt;

  /// The family token's size. `RackTextSizes.type`, the same size
  /// `symbol_layer` gives a pin label — which also keeps
  /// `DiagramScene.minTextSizePt` where M2-C left it, so adding this layer
  /// cannot move the legibility trigger (docs/08 §6.2).
  final double tokenSizePt;

  /// The pennant outline's width. Full-strength COLOUR at a hairline
  /// width: the weight CHANNEL is carried by the leader, and outlining the
  /// pennant at the family's weight too would say the same thing twice
  /// while making a 2.00× power label read as a heavy box.
  final double outlineWidthPt;

  @override
  bool operator ==(Object other) =>
      other is NetLabelStyle &&
      other.theme == theme &&
      other.leaderGu == leaderGu &&
      other.padGu == padGu &&
      other.gapGu == gapGu &&
      other.tipGu == tipGu &&
      other.heightFactor == heightFactor &&
      other.fillAlpha == fillAlpha &&
      other.maxCombLanes == maxCombLanes &&
      other.padEm == padEm &&
      other.nameSizePt == nameSizePt &&
      other.tokenSizePt == tokenSizePt &&
      other.outlineWidthPt == outlineWidthPt;

  @override
  int get hashCode => Object.hashAll([
    theme,
    leaderGu,
    padGu,
    gapGu,
    tipGu,
    heightFactor,
    fillAlpha,
    maxCombLanes,
    padEm,
    nameSizePt,
    tokenSizePt,
    outlineWidthPt,
  ]);
}

/// One drawn net label: which link and pin it belongs to, what it says,
/// how it is encoded and where it landed.
///
/// Published so M2-E's hover, focus and domain filter read the geometry
/// that was DRAWN rather than re-deriving it. `symbol_layer.dart`'s header
/// records what re-derivation cost last time: the painter and the
/// hit-tester each computed a pin centre and disagreed by half a pin for
/// as long as nobody compared them.
@immutable
final class RenderedNetLabel {
  const RenderedNetLabel({
    required this.linkId,
    required this.deviceId,
    required this.portKey,
    required this.side,
    required this.style,
    required this.netName,
    required this.pinCentre,
    required this.pennant,
  });

  /// The `Link` this stub stands for. BOTH of a link's labels carry the
  /// same id and the same [netName] — §11.5: "both flags of a net show the
  /// identical string and highlight together on hover".
  final Uuid linkId;

  /// The owning device, as `DeviceInstance.id.v` — the same key
  /// `DiagramScene.fragments` and `HitRegion.entityId` use for a symbol.
  final String deviceId;

  /// `SymbolPort.key`, the stable author-assigned join (CR-051), never a
  /// UUID.
  final String portKey;

  final SymbolSide side;

  /// The four channels this label was drawn with.
  final SignalStyle style;

  /// What the pennant says. [kUnknownCell] when no `Net` resolved — see
  /// [NetLabelLayerBuild.unnamedLinkIds].
  final String netName;

  /// The pin's centre, ABSOLUTE. `symbolPortCentre`'s answer, not a second
  /// derivation of it.
  final DPt pinCentre;

  /// The pennant's outer box, ABSOLUTE, apex included.
  final DBox pennant;

  @override
  String toString() =>
      'RenderedNetLabel($netName @ $deviceId#$portKey, ${side.name})';
}

/// [buildNetLabelLayer]'s output.
///
/// A class rather than a record (unlike `LayerBuild`) because it carries
/// four separate counts, and a nine-field record's call site reads as a
/// list of unnamed positions the moment anyone destructures it.
@immutable
final class NetLabelLayerBuild {
  const NetLabelLayerBuild({
    required this.ops,
    required this.domainRanges,
    required this.unresolvedRange,
    required this.labels,
    required this.inkBounds,
    required this.minTextPt,
    required this.unnamedLinkIds,
    required this.unlabelledLinkIds,
    required this.underGlyphedFamilyIds,
  });

  /// ABSOLUTE-coordinate ops, grouped by domain — see the file header.
  final List<DiagramOp> ops;

  /// Each domain's contiguous run, indexed into [ops]. The sub-picture
  /// M2-E's domain filter replays.
  final Map<SignalDomainId, IntRange> domainRanges;

  /// The run holding every stub whose domain did NOT resolve, or `null`
  /// when there are none. Kept out of [domainRanges] rather than filed
  /// under a made-up `SignalDomainId`: a filter offering an "unknown"
  /// chip is a product decision, and a fake id would make it by default.
  final IntRange? unresolvedRange;

  final List<RenderedNetLabel> labels;

  /// Measured from the pennant boxes and leader ends, NOT by replaying the
  /// ops through `BoundsCanvas`. Every pennant is SIZED FROM its own text
  /// measurement, so its box already bounds its ink by construction, and
  /// re-deriving would re-measure two text runs per stub — 1,200 of them
  /// on the 300-link fixture — on the commit path for an answer already
  /// held. `net_label_layer_test.dart` checks the two agree on a sample so
  /// the shortcut stays honest.
  final DBox? inkBounds;

  /// The smallest text size emitted, or `double.infinity` for an empty
  /// layer — `LayerBuild.minTextPt`'s convention.
  final double minTextPt;

  /// Links drawn with [kUnknownCell] because no `Net` resolved through
  /// `services.first.netId`.
  ///
  /// NOT AN ERROR AND NOT RARE. `Service` is what carries a net (CR-011),
  /// and a `Link` whose services list is empty has no net to name — the
  /// 300-link layout fixture is exactly that document. The name is not
  /// invented from the link's `W###` designator, which is a different fact
  /// about a different thing (G4), and the stub is still drawn, because a
  /// connection that exists must be visible whether or not it is named.
  final List<Uuid> unnamedLinkIds;

  /// Links that got NO stub at either end — an end that is not a
  /// `PortEndpoint` (AC-018's home runs to the field), a port this
  /// document does not contain, or a device with no symbol
  /// (`SchematicScene.unsymbolisedDeviceIds`). Counted for the same reason
  /// that list is: a schematic that silently omits a connection is
  /// indistinguishable from one that lost it.
  final List<Uuid> unlabelledLinkIds;

  /// Families drawn with a glyph this renderer cannot verify, sorted and
  /// distinct. See `signal_style.dart`'s header — there is no `tier` field
  /// to select `glyph` from `glyphAlt`, and `audio.analog`/`pwr` carry a
  /// THIRD shape with nowhere to live at all (DR-010 §11.10.4 keeps a
  /// per-family glyph out of scope). Reported so the gap is visible (G4).
  final List<SignalFamilyId> underGlyphedFamilyIds;
}

/// Builds the net-label layer for [doc] over the already-positioned
/// [symbols].
///
/// [unitsPerGrid] is diagram units per grid unit, passed in rather than
/// recomputed: `schematic_scene.dart` settles the sheet's ONE scale anchor
/// (`kSchematicUnitsPerGrid`, derived through `units/print_units.dart`)
/// and a second derivation here would be a second scale (G4). Taking it as
/// a parameter also keeps this file out of an import cycle with the scene
/// builder that composes it.
///
/// DETERMINISM. No hash container is iterated: links are walked in
/// `(order, id)` — `schematic_scene.dart`'s own link order — domains are
/// emitted in ascending id, and every map here is a lookup table or a
/// memo, never a source of order. Same document ⇒ byte-identical ops, which
/// `schematic_perf_test.dart` asserts through `op_digest.dart`.
NetLabelLayerBuild buildNetLabelLayer({
  required RackDocument doc,
  required Iterable<RenderedSymbol> symbols,
  required TextMeasurer measurer,
  required SchematicPalette palette,
  required double unitsPerGrid,
  NetLabelStyle style = const NetLabelStyle(),
}) {
  // ── indexes ──────────────────────────────────────────────────────────
  final symbolById = <String, RenderedSymbol>{};
  final pinsOf = <String, Map<String, SymbolPort>>{};
  for (final symbol in symbols) {
    symbolById[symbol.id] = symbol;
    pinsOf[symbol.id] = <String, SymbolPort>{
      for (final port in symbol.allPorts) port.key: port,
    };
  }

  final links = doc.links.values.toList()
    ..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
    });

  // ── one pass to resolve, bucketed by domain ──────────────────────────
  final styleOf = <String, SignalStyle>{};
  final buckets = <String, List<_Stub>>{};
  final unnamed = <Uuid>[];
  final unlabelled = <Uuid>[];
  final underGlyphed = <String, SignalFamilyId>{};

  for (final link in links) {
    final ends = _endsOf(link, doc, symbolById, pinsOf);
    if (ends.isEmpty) {
      unlabelled.add(link.id);
      continue;
    }

    // ONE FAMILY PER LINK, NOT PER END, and that is load-bearing: the
    // domain decides which sub-picture a stub lands in, and a link whose
    // two ends resolved to different domains would have one flag inside a
    // filter's scope and the other outside it. A balun with an HDMI jack
    // at one end and an RJ45 at the other is exactly that case.
    final family = _familyOf(link, ends);
    final signal = styleOf.putIfAbsent(
      family.v,
      () => resolveSignalStyle(
        family: family,
        registries: doc.registries,
        colorOverrides: doc.settings.familyColorOverrides,
        theme: style.theme,
      ),
    );
    if (signal.glyphIsUnderdetermined) {
      underGlyphed[family.v] = family;
    }

    final name = _netNameOf(link, doc);
    if (name == null) unnamed.add(link.id);

    final key = signal.domainId?.v ?? _kUnresolvedBucket;
    final bucket = buckets.putIfAbsent(key, () => <_Stub>[]);
    for (final end in ends) {
      bucket.add(
        _Stub(
          link: link,
          symbol: end.symbol,
          port: end.port,
          style: signal,
          netName: name ?? kUnknownCell,
        ),
      );
    }
  }

  // ── emit, one contiguous run per domain ──────────────────────────────
  //
  // Ascending domain id, then the unresolved bucket LAST — it is not a
  // domain and sorting it among them would put it in a different place
  // depending on which domains a document happens to use.
  final keys = buckets.keys.where((k) => k != _kUnresolvedBucket).toList()
    ..sort();
  if (buckets.containsKey(_kUnresolvedBucket)) keys.add(_kUnresolvedBucket);

  // ── the comb, in a bounded number of lanes ───────────────────────────
  //
  // AFTER the buckets and not before, which is the whole reason this moved:
  // the lane count depends on the WIDEST PENNANT THAT ACTUALLY LANDS on an
  // edge, and that is not knowable until the stubs are resolved and a
  // `_Sizer` exists to measure them. The old index needed nothing but the
  // port list, which is exactly why it could only count.
  final sizer = _Sizer(
    measurer: measurer,
    style: style,
    unitsPerGrid: unitsPerGrid,
  );

  final widestOnEdge = <String, double>{};
  for (final bucket in buckets.values) {
    for (final stub in bucket) {
      final side = stub.port.side;
      if (side != SymbolSide.top && side != SymbolSide.bottom) continue;
      final key = _edgeKey(stub.symbol.id, side);
      // `horizontal: false` — a vertical stub lays its pennant ACROSS
      // itself, so the extent that can collide with the next pin's flag is
      // the pennant's WIDTH. `emit` reads the same measurement for the same
      // reason; taking a different one here is how a comb comes to be sized
      // for a pennant nobody draws.
      final width = sizer.pennantWidth(
        stub.style,
        stub.netName,
        horizontal: false,
      );
      final prev = widestOnEdge[key];
      if (prev == null || width > prev) widestOnEdge[key] = width;
    }
  }

  final combIndex = <String, int>{};
  for (final symbol in symbols) {
    for (final side in const [SymbolSide.top, SymbolSide.bottom]) {
      final ports = symbol.ports[side] ?? const <SymbolPort>[];
      if (ports.isEmpty) continue;
      final lanes = _laneCount(
        ports: ports,
        widest: widestOnEdge[_edgeKey(symbol.id, side)] ?? 0,
        gap: sizer.gap,
        maxLanes: style.maxCombLanes,
      );
      for (var i = 0; i < ports.length; i++) {
        combIndex[_pinKey(symbol.id, ports[i].key)] = i % lanes;
      }
    }
  }

  final emitter = _Emitter(
    sizer: sizer,
    palette: palette,
    style: style,
    combIndex: combIndex,
  );
  final ranges = <SignalDomainId, IntRange>{};
  IntRange? unresolvedRange;
  for (final key in keys) {
    final start = emitter.ops.length;
    for (final stub in buckets[key]!) {
      emitter.emit(stub);
    }
    // INSIDE THE LOOP, so this run is contiguous. `emit` holds its ops back
    // by kind — leaders, pennants, text — and this appends all three at
    // once, which is what stops one stub's leader painting over the flag
    // its neighbour just drew. Flushing after the loop over `keys` instead
    // would interleave every domain into one run and destroy the
    // fragment ranges the filter replays.
    emitter.flushDomain();
    final range = IntRange(start, emitter.ops.length);
    if (key == _kUnresolvedBucket) {
      unresolvedRange = range;
    } else {
      ranges[SignalDomainId(key)] = range;
    }
  }

  final families = underGlyphed.keys.toList()..sort();
  return NetLabelLayerBuild(
    ops: emitter.ops,
    domainRanges: Map<SignalDomainId, IntRange>.unmodifiable(ranges),
    unresolvedRange: unresolvedRange,
    labels: List<RenderedNetLabel>.unmodifiable(emitter.labels),
    inkBounds: emitter.bounds,
    minTextPt: emitter.labels.isEmpty
        ? double.infinity
        : math.min(style.nameSizePt, style.tokenSizePt),
    unnamedLinkIds: List<Uuid>.unmodifiable(unnamed),
    unlabelledLinkIds: List<Uuid>.unmodifiable(unlabelled),
    underGlyphedFamilyIds: List<SignalFamilyId>.unmodifiable(<SignalFamilyId>[
      for (final f in families) underGlyphed[f]!,
    ]),
  );
}

/// The bucket key for stubs whose domain did not resolve. A `SignalDomainId`
/// can never be the empty string in a seeded registry, and the value never
/// reaches a fragment key — see [NetLabelLayerBuild.unresolvedRange].
const String _kUnresolvedBucket = '';

/// One pin's worth of label, resolved and waiting to be drawn.
@immutable
final class _Stub {
  const _Stub({
    required this.link,
    required this.symbol,
    required this.port,
    required this.style,
    required this.netName,
  });

  final Link link;
  final RenderedSymbol symbol;
  final SymbolPort port;
  final SignalStyle style;
  final String netName;
}

typedef _End = ({RenderedSymbol symbol, SymbolPort port});

/// [link]'s ends that landed on a drawn pin, in conductor order (from,
/// then to).
///
/// `Link.conductors.first` speaks for the whole link: CR-014 fixes each
/// conductor at exactly two ends and every conductor of one cable shares
/// the same physical pair, which is the reading `derived/link_class.dart`
/// and `schematic_scene.dart` both take.
///
/// An end drops out — WITHOUT dropping the other — when it is not a
/// `PortEndpoint` (a home run to the field, AC-018), when the port is not
/// in this document, or when its device has no symbol. A one-ended link
/// still labels the end it has: that flag is the only place the reader
/// learns the run exists at all.
List<_End> _endsOf(
  Link link,
  RackDocument doc,
  Map<String, RenderedSymbol> symbolById,
  Map<String, Map<String, SymbolPort>> pinsOf,
) {
  if (link.conductors.isEmpty) return const <_End>[];
  final conductor = link.conductors.first;
  final out = <_End>[];
  for (final endpoint in <Endpoint>[conductor.from, conductor.to]) {
    if (endpoint is! PortEndpoint) continue;
    final port = doc.ports[endpoint.portId];
    if (port == null) continue;
    final key = port.templatePortKey;
    if (key == null) continue;
    final symbol = symbolById[port.deviceId.v];
    final pin = pinsOf[port.deviceId.v]?[key.v];
    if (symbol == null || pin == null) continue;
    out.add((symbol: symbol, port: pin));
  }
  return out;
}

/// The family whose four channels [link] renders in.
///
/// 1. `services.first.signalFamily` — docs/05 §5: colour "resolves from
///    `Service.signalFamily`, never from the `Link`", and `services.first`
///    is the same "dominant service" reading `derived/schedule.dart`
///    already takes for the schedule's `TYPE` cell. (`Link
///    .dominantSignalFamily` is named in §5 as a derived member and does
///    not exist on the class; this is the one reading that does.)
/// 2. Otherwise the SOURCE pin's own declared family, then the sink's.
///    `PortDef.signalFamily` is a real model fact, not an estimate: a
///    cable between two HDMI jacks IS digital video whether or not anyone
///    has written a `Service` row. CR-011 auto-creates an implicit net —
///    and therefore a service — the moment the app makes a link, so this
///    path is for documents built some other way, which includes every
///    fixture written before nets mattered to the drawing.
///
/// The source end is preferred over the sink for the same reason §5 says
/// "dominant": one of the two has to win deterministically, and the source
/// is the end the net is named after (CR-049's
/// `{DOMAIN}_{SRC_REFDES}_{SRC_PORT}`).
SignalFamilyId _familyOf(Link link, List<_End> ends) {
  if (link.services.isNotEmpty) return link.services.first.signalFamily;
  return ends.first.port.family;
}

/// [link]'s net name, or `null` when none resolves.
///
/// `Service.netId` is the membership foreign key (CR-011) and the `Net`'s
/// `name` is generated, editable and NEVER load-bearing (CR-049) — which
/// is why this reads the name for DISPLAY only and nothing downstream
/// keys on it. A blank stored name is treated as absent rather than drawn
/// as an empty pennant.
String? _netNameOf(Link link, RackDocument doc) {
  if (link.services.isEmpty) return null;
  final net = doc.nets[link.services.first.netId];
  if (net == null) return null;
  final name = net.name.trim();
  return name.isEmpty ? null : name;
}

/// The clear space, in GRID UNITS, that two facing net labels need
/// between one Sugiyama layer and the next.
///
/// WHY THE LAYOUT HAS TO ASK, AND WHY THE ANSWER CANNOT BE A CONSTANT.
/// `SugiyamaParams.layerGutterGu` is 12 gu — "the empty vertical channel
/// docs/05 §10.1 says the layering buys" — and it was sized when the only
/// thing in that channel was air. Under DR-001 THE GUTTER IS WHERE THE
/// DRAWING IS: a source's right-edge pennant and the next layer's
/// left-edge pennant both grow into it, and on the shipped figures one
/// stub runs to roughly 100 diagram units — about 14 gu — so at 12 gu the
/// two flags of EVERY forward link overprint each other. That is not an
/// edge case, it is every sheet, and it is what canon §11.1.5 means by the
/// label layer becoming the PRIMARY commit-path term rather than a
/// secondary one.
///
/// The figure cannot be a constant because a pennant is as wide as its
/// text: `▲ VID·HD20` beside `HDMI_MTX1_OUT3` is a different width from
/// `⬢ PWR·IEC` beside `N001`, and CR-049's alternate
/// `{ROOM}_{DEVICE}_{N}` template widens it again. So it is MEASURED,
/// through the injected `TextMeasurer`, by the same [_Sizer] the emitter
/// draws with — one formula, so the reservation and the drawing cannot
/// disagree.
///
/// [symbols] may be the PRE-LAYOUT geometries built at the origin: this
/// reads sides, pin keys and text, never a position.
///
/// THE VERTICAL HALF NOW EXISTS, AND ITS REASON FOR NOT EXISTING IS GONE.
/// This doc used to end here, deferring the top/bottom comb's room between
/// two symbols stacked in ONE layer, on a stated ground: *"a comb grows
/// with the pin count on an edge, so reserving for the worst case would
/// push a 4 gu node gap into the tens on a device with eight control
/// ports"*. That was correct when written and is obsolete now — #96-H
/// bounds the comb at `ceil(widest / pitch)` lanes, so the reservation is
/// bounded by the same number and a 48-port switch asks for no more room
/// than a 5-port one. See [netLabelNodeGapGu], which is the other half.
int netLabelGutterGu({
  required RackDocument doc,
  required Iterable<RenderedSymbol> symbols,
  required TextMeasurer measurer,
  required double unitsPerGrid,
  NetLabelStyle style = const NetLabelStyle(),
}) {
  final sizer = _Sizer(
    measurer: measurer,
    style: style,
    unitsPerGrid: unitsPerGrid,
  );
  final symbolById = <String, RenderedSymbol>{
    for (final symbol in symbols) symbol.id: symbol,
  };
  final pinsOf = <String, Map<String, SymbolPort>>{
    for (final symbol in symbols)
      symbol.id: <String, SymbolPort>{
        for (final port in symbol.allPorts) port.key: port,
      },
  };

  // Accumulated PER PIN, exactly as the emitter accumulates: several links
  // on one multidrop tap march outward, and the gutter has to clear the
  // whole run rather than its widest member.
  final consumed = <String, double>{};
  final styleOf = <String, SignalStyle>{};
  var worst = 0.0;
  for (final link in doc.links.values) {
    final ends = _endsOf(link, doc, symbolById, pinsOf);
    if (ends.isEmpty) continue;
    final family = _familyOf(link, ends);
    final signal = styleOf.putIfAbsent(
      family.v,
      () => resolveSignalStyle(
        family: family,
        registries: doc.registries,
        colorOverrides: doc.settings.familyColorOverrides,
        theme: style.theme,
      ),
    );
    final name = _netNameOf(link, doc) ?? kUnknownCell;
    for (final end in ends) {
      final side = end.port.side;
      // Only the horizontal stubs grow into a LAYER gutter; a top/bottom
      // comb grows along the other axis entirely.
      if (side != SymbolSide.left && side != SymbolSide.right) continue;
      final key = _pinKey(end.symbol.id, end.port.key);
      final at =
          (consumed[key] ?? 0) +
          sizer.stubExtent(signal, name, horizontal: true);
      consumed[key] = at;
      if (at > worst) worst = at;
    }
  }
  // TWO stubs face each other across a gutter: one leaving the layer on
  // the left, one arriving at the layer on the right.
  //
  // `doc.links.values` is iterated in map order and that is SAFE here in a
  // way it would not be inside the emitter: this reduces to a MAXIMUM,
  // which is order-independent, and `consumed` accumulates per pin by
  // addition, which is too. Nothing about the result depends on which link
  // came first.
  return (2 * worst / unitsPerGrid).ceil();
}

/// The clear space, in GRID UNITS, that two stacked symbols' top/bottom
/// combs need between them.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE VERTICAL TWIN OF [netLabelGutterGu], AND IT ONLY BECAME POSSIBLE AT
/// #96-H
/// ═══════════════════════════════════════════════════════════════════════
/// `SugiyamaParams.nodeGapGu` is 4 gu of clear space between two symbols in
/// one layer, and it was sized when that space held air. It holds combs. A
/// symbol stacked below another was being placed into the room the one
/// above was labelling — which is what the field reported as *"netlabels
/// draw directly over devices"*.
///
/// The reservation could not be made while the comb was UNBOUNDED: a
/// 48-port switch would have asked for 48 lanes of clearance and pushed
/// every node gap on the sheet into the hundreds. [netLabelGutterGu]'s doc
/// carried exactly that objection. #96-H caps the comb at
/// `ceil(widest / pitch)` lanes — three to five on the shipped catalog —
/// so the worst case is now a small number and the objection is spent.
///
/// TWO FLAGS FACE EACH OTHER ACROSS THIS GAP, hence the doubling: the upper
/// symbol's BOTTOM comb grows down into it and the lower symbol's TOP comb
/// grows up. Same reasoning, same factor, as the layer gutter.
///
/// ONE LANE COUNT, from [_laneCount], and one stub size, from [_Sizer] —
/// the same two the emitter draws with. A reservation computed from a
/// second copy of either is a reservation that is one lane short exactly
/// when it matters.
///
/// [symbols] may be the PRE-LAYOUT geometries built at the origin: this
/// reads sides, pin keys and text, never a position.
int netLabelNodeGapGu({
  required RackDocument doc,
  required Iterable<RenderedSymbol> symbols,
  required TextMeasurer measurer,
  required double unitsPerGrid,
  NetLabelStyle style = const NetLabelStyle(),
}) {
  final sizer = _Sizer(
    measurer: measurer,
    style: style,
    unitsPerGrid: unitsPerGrid,
  );
  final symbolById = <String, RenderedSymbol>{
    for (final symbol in symbols) symbol.id: symbol,
  };
  final pinsOf = <String, Map<String, SymbolPort>>{
    for (final symbol in symbols)
      symbol.id: <String, SymbolPort>{
        for (final port in symbol.allPorts) port.key: port,
      },
  };

  // PASS 1 — collect the vertical stubs and, with them, the widest pennant
  // landing on each edge. That width is what sets the lane count, and it
  // cannot be known before the stubs are resolved.
  final styleOf = <String, SignalStyle>{};
  final widest = <String, double>{};
  final stubs = <({_End end, SignalStyle signal, String name})>[];
  for (final link in doc.links.values) {
    final ends = _endsOf(link, doc, symbolById, pinsOf);
    if (ends.isEmpty) continue;
    final family = _familyOf(link, ends);
    final signal = styleOf.putIfAbsent(
      family.v,
      () => resolveSignalStyle(
        family: family,
        registries: doc.registries,
        colorOverrides: doc.settings.familyColorOverrides,
        theme: style.theme,
      ),
    );
    final name = _netNameOf(link, doc) ?? kUnknownCell;
    for (final end in ends) {
      final side = end.port.side;
      // Only the vertical stubs grow into a NODE gap; a left/right pennant
      // grows along the other axis entirely and is the layer gutter's.
      if (side != SymbolSide.top && side != SymbolSide.bottom) continue;
      stubs.add((end: end, signal: signal, name: name));
      final key = _edgeKey(end.symbol.id, side);
      final w = sizer.pennantWidth(signal, name, horizontal: false);
      final prev = widest[key];
      if (prev == null || w > prev) widest[key] = w;
    }
  }
  // NO VERTICAL STUBS, NO CLAIM. Returning zero rather than a floor leaves
  // the caller's own `nodeGapGu` untouched — see its `math.max`.
  if (stubs.isEmpty) return 0;

  // PASS 2 — which lane each pin sits in, by the emitter's own rule.
  final lane = <String, int>{};
  for (final symbol in symbols) {
    for (final side in const [SymbolSide.top, SymbolSide.bottom]) {
      final ports = symbol.ports[side] ?? const <SymbolPort>[];
      if (ports.isEmpty) continue;
      final lanes = _laneCount(
        ports: ports,
        widest: widest[_edgeKey(symbol.id, side)] ?? 0,
        gap: sizer.gap,
        maxLanes: style.maxCombLanes,
      );
      for (var i = 0; i < ports.length; i++) {
        lane[_pinKey(symbol.id, ports[i].key)] = i % lanes;
      }
    }
  }

  // PASS 3 — the reach, accumulated PER PIN exactly as the emitter
  // accumulates: several links on one multidrop tap march outward and the
  // gap has to clear the whole run, not its widest member. The comb is
  // added once, on the first stub, which is the emitter's rule too.
  final consumed = <String, double>{};
  var worst = 0.0;
  for (final stub in stubs) {
    final key = _pinKey(stub.end.symbol.id, stub.end.port.key);
    final first = !consumed.containsKey(key);
    final comb = first ? (lane[key] ?? 0) * sizer.combStep : 0.0;
    final at =
        (consumed[key] ?? 0) +
        comb +
        sizer.stubExtent(stub.signal, stub.name, horizontal: false);
    consumed[key] = at;
    if (at > worst) worst = at;
  }

  // Iterated in map order, which is SAFE for the same reason it is in
  // [netLabelGutterGu]: this reduces to a maximum over per-pin sums, and
  // both operations are order-independent.
  return (2 * worst / unitsPerGrid).ceil();
}

/// A pin's identity across the two maps that key on one. A `PortKey` is
/// author-assigned (CR-051) and may contain a space, so the separator is
/// a character no author can type into one.
String _pinKey(String deviceId, String portKey) => '$deviceId\u0000$portKey';

/// One symbol's one edge — the scope a comb's lane count is measured over.
String _edgeKey(String deviceId, SymbolSide side) =>
    '$deviceId ${side.index}';

/// How many depths [ports]' pennants must be spread across so that no two
/// on this edge overprint.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE NUMBER IS DERIVED, WHICH IS WHY THIS IS A FUNCTION AND NOT A FIELD
/// ═══════════════════════════════════════════════════════════════════════
/// Two flags on one edge collide when the pennant is wider than the gap
/// between the pins carrying them. Put the i-th pin in lane `i % lanes` and
/// the nearest same-lane neighbour moves from one pitch away to `lanes`
/// pitches away — so the smallest lane count that separates them is
/// `ceil(widest / pitch)`, and any larger number only pushes flags further
/// out for nothing.
///
/// [widest] is the widest pennant that ACTUALLY LANDS on this edge, not the
/// widest the document holds: sizing every edge by the document's worst
/// case would give a two-port switch the matrix's comb.
///
/// THE PITCH IS READ OFF THE PORTS, not off `SchematicMetrics`. This layer
/// receives laid-out symbols and never sees the metrics that produced them,
/// and a second copy of the pitch is precisely the painter/hit-tester
/// desync `symbol_layer.dart`'s header records. Consecutive ports on one
/// edge are one pitch apart by construction ([buildSymbolGeometry]).
///
/// RETURNS 1 — a flat comb — when there is nothing to separate: fewer than
/// two pins on the edge, an edge whose stubs measured to nothing, or a
/// degenerate pitch. One lane is the no-op, and it is the honest answer
/// rather than a guard that would have to invent a spread.
int _laneCount({
  required List<SymbolPort> ports,
  required double widest,
  required double gap,
  required int maxLanes,
}) {
  if (ports.length < 2 || widest <= 0) return 1;
  final pitch = (ports[1].offset - ports[0].offset).abs();
  if (pitch <= 0 || !pitch.isFinite) return 1;
  // `widest + gap`, NOT `widest`. Bare `widest` makes same-lane neighbours
  // EXACTLY TOUCH in the worst case — `lanes * pitch >= widest` is
  // satisfied by equality — so two full-width flags met edge to edge and
  // read as one smear. The field called it "overlap a bit", which is
  // precisely what a zero-clearance fit looks like once antialiasing has
  // had its say. One gap between flags is the same clearance the emitter
  // already leaves between two stubs on one pin.
  return math.min(maxLanes, math.max(1, ((widest + gap) / pitch).ceil()));
}

/// Channel 4's width for [signal] — the figure a pennant reserves for it,
/// and the offset the emitter places the net name at.
///
/// ═══════════════════════════════════════════════════════════════════════
/// TWO ROUTES, AND THE SPLIT IS #124's WHOLE FIX
/// ═══════════════════════════════════════════════════════════════════════
/// When the domain glyph has a SHAPE (`family_glyph.dart`) the glyph is
/// GEOMETRY and only the tag is measured. The glyph's contribution is
/// [familyGlyphAdvance] — a pure function of the type size, which the
/// emitter reads too — so the width reserved and the width drawn cannot
/// disagree however the running font behaves.
///
/// When it does not, the whole `'glyph tag'` run is measured exactly as it
/// always was: the defined fallback, correct whenever the font DOES carry
/// the character, and never silently nothing.
///
/// PUBLIC BECAUSE THE DEFECT WAS THE ABSENCE OF A GATE. Nothing compared
/// what channel 4 measured with what it painted, so a glyph that measured
/// near-zero and painted full width shipped. `family_glyph_test.dart`
/// drives this function under a measurer that returns zero for every
/// string — the pathological case Jost actually produced — and the
/// geometry route is the only one that still reserves a width there.
double netLabelTokenWidth(
  SignalStyle signal, {
  required TextMeasurer measurer,
  required NetLabelStyle style,
}) {
  double measure(String text) => measurer
      .measureText(text, rackText(style.tokenSizePt, 0, TextAnchor.midLeft))
      .advanceWidth;
  return familyGlyphFor(signal.glyph) == null
      ? measure(signal.familyToken)
      : familyGlyphAdvance(style.tokenSizePt) + measure(signal.tag);
}

/// THE ONE PLACE A STUB'S SIZE IS DECIDED, shared by the emitter and by
/// [netLabelGutterGu].
///
/// It exists because those two must never disagree: the gutter reserves
/// room for exactly the stub the emitter then draws, and a second
/// transcription of the width formula would let one drift from the other
/// until the labels overprint again. Same argument
/// `schematic_scene_test.dart` makes about docs/05 §3's sizing formula
/// having two transcriptions — with the difference that there the drift
/// would be caught by an overlap test, and here it would be caught only
/// by looking at a sheet.
final class _Sizer {
  _Sizer({
    required this.measurer,
    required this.style,
    required double unitsPerGrid,
  }) : leader = style.leaderGu * unitsPerGrid,
       // A MAX, NOT AN OVERRIDE — see [NetLabelStyle.padEm]. The grid
       // figure is the floor that stops a small type size collapsing the
       // inset; the em figure is what makes the inset grow with the text
       // it is insetting, which a constant cannot do.
       pad = math.max(
         style.padGu * unitsPerGrid,
         style.nameSizePt * style.padEm,
       ),
       gap = style.gapGu * unitsPerGrid,
       tip = style.tipGu * unitsPerGrid,
       height = style.nameSizePt * style.heightFactor;

  final TextMeasurer measurer;
  final NetLabelStyle style;

  final double leader;
  final double pad;
  final double gap;
  final double tip;
  final double height;

  /// Measured widths, memoised. THE FAMILY TOKEN IS ONE OF 55 STRINGS AND
  /// THE NET NAME IS SHARED BY A LINK'S TWO FLAGS, so measuring naively
  /// would do ~1,800 measurements on the 300-link fixture where ~355
  /// distinct strings exist. This is AC-009's `(text, styleId)` label
  /// cache applied at build time.
  ///
  /// COLOUR IS NOT PART OF THE KEY, and must not be: it cannot change an
  /// advance width, and keying on it would turn one entry per token into
  /// one per (token, domain) — which is why the specs below are built at
  /// argb 0 and the drawn specs are built separately.
  final Map<String, double> _tokenWidth = <String, double>{};
  final Map<String, double> _nameWidth = <String, double>{};

  /// [netLabelTokenWidth], memoised.
  ///
  /// THE MEMO KEY IS `familyToken` ON BOTH ROUTES. It is one of ~55
  /// strings and is unique per family, so it keys the geometry route and
  /// the fallback route without a second map; the glyph half of the
  /// geometry route contributes a constant.
  double tokenWidth(SignalStyle signal) => _tokenWidth.putIfAbsent(
    signal.familyToken,
    () => netLabelTokenWidth(signal, measurer: measurer, style: style),
  );

  double nameWidth(String name) => _nameWidth.putIfAbsent(
    name,
    () => measurer
        .measureText(name, rackText(style.nameSizePt, 0, TextAnchor.midLeft))
        .advanceWidth,
  );

  /// The pennant's width. The point costs WIDTH only on a horizontal stub;
  /// on a top/bottom stub the pennant lies across its leader and the point
  /// is vertical.
  double pennantWidth(
    SignalStyle signal,
    String name, {
    required bool horizontal,
  }) {
    final content = tokenWidth(signal) + gap + nameWidth(name);
    return horizontal ? tip + pad + content + pad : pad + content + pad;
  }

  /// How far one stub reaches out from its pin's edge, INCLUDING the gap
  /// that separates it from the next stub on the same pin. The emitter's
  /// `_consumed` step and the gutter's reservation are this one figure.
  double stubExtent(
    SignalStyle signal,
    String name, {
    required bool horizontal,
  }) =>
      leader +
      (horizontal
          ? pennantWidth(signal, name, horizontal: true)
          : height + tip) +
      gap;

  /// One lane of the top/bottom comb — how much further out a flag sits per
  /// lane index.
  ///
  /// HERE RATHER THAN IN THE EMITTER, because two things now read it: the
  /// emitter that draws the comb and [netLabelNodeGapGu] that reserves room
  /// for it. Two copies of this expression is how a reservation comes to be
  /// one lane short of the drawing.
  double get combStep => height + tip + gap;
}

/// Places and draws stubs, carrying the running state a stub needs from
/// the ones before it: how far out a pin has already been built, and the
/// ink bounds so far.
final class _Emitter {
  _Emitter({
    required this.sizer,
    required this.palette,
    required this.style,
    required this.combIndex,
  });

  final _Sizer sizer;
  final SchematicPalette palette;
  final NetLabelStyle style;

  final List<DiagramOp> ops = <DiagramOp>[];

  // ── the three kinds, held back until the domain is done ──────────────
  //
  // ═══════════════════════════════════════════════════════════════════
  // A LEADER LOOKS LIKE A WIRE, AND USED TO CROSS ITS NEIGHBOURS' FLAGS
  // ═══════════════════════════════════════════════════════════════════
  // [emit] used to append leader, pennant and text straight to [ops], one
  // stub after another — so stub N's LEADER landed after stub N-1's
  // PENNANT and drew over it. On a combed edge that is exactly where the
  // crossings are: the outermost flag sits up to `maxCombLanes` out and
  // its leader is a long line passing every inner flag on the way. Inner
  // flags got crossed, outer ones did not, which is what the field
  // reported as labels drawing under the wires — the leader IS drawn in
  // the family hue with the family dash and weight, so it reads as one.
  //
  // ONLY THE OUTPUT ORDER MOVES. The geometry pass is untouched: `emit`
  // still runs once per stub, in bucket order, and `_consumed` still
  // accumulates per pin as it did — where a flag LANDS is identical. What
  // changed is which list each op goes into, and [flushDomain] then
  // appends all three in the order they must paint.
  //
  // FLUSHED PER DOMAIN, NEVER ACROSS DOMAINS, and that is a hard
  // constraint rather than a preference: a domain's fragment is ONE
  // CONTIGUOUS `IntRange`, which is what lets the filter replay seven runs
  // and rebuild the eighth. Holding ops past a domain boundary would
  // interleave two runs and silently destroy that.
  //
  // FOUR SINCE #124, and the fourth sits where it does for the same
  // reason the other three do. A family glyph drawn as geometry is ink
  // INSIDE a pennant, so it has to land after every fill in its run —
  // appending it to [_pennants] would put one flag's glyph under the next
  // flag's fill on a combed edge, which is this defect again with a
  // different shape. It goes before the texts because it is the same
  // channel as the tag beside it and nothing decides between them.
  final List<DiagramOp> _leaders = <DiagramOp>[];
  final List<DiagramOp> _pennants = <DiagramOp>[];
  final List<DiagramOp> _glyphs = <DiagramOp>[];
  final List<DiagramOp> _texts = <DiagramOp>[];

  /// Appends this domain's held ops, leaders first and text last.
  ///
  /// CALLED ONCE PER DOMAIN RUN by the caller, immediately after its last
  /// stub — see the note above on why it may not be deferred further.
  void flushDomain() {
    ops
      ..addAll(_leaders)
      ..addAll(_pennants)
      ..addAll(_glyphs)
      ..addAll(_texts);
    _leaders.clear();
    _pennants.clear();
    _glyphs.clear();
    _texts.clear();
  }
  final List<RenderedNetLabel> labels = <RenderedNetLabel>[];
  DBox? bounds;

  double get _leader => sizer.leader;
  double get _pad => sizer.pad;
  double get _gap => sizer.gap;
  double get _tip => sizer.tip;
  double get _height => sizer.height;

  /// Distance from a pin's EDGE to the outer end of the last pennant built
  /// on it. A pin normally carries one link; a multidrop tap carries
  /// several and they march outward.
  final Map<String, double> _consumed = <String, double>{};

  /// The comb offsets of the file header, one per top/bottom pin. Built by
  /// the caller in one pass over the symbols rather than searched per stub.
  final Map<String, int> combIndex;

  void emit(_Stub stub) {
    final centre = symbolPortCentre(stub.symbol, stub.port);
    final side = stub.port.side;
    final outward = _outward(side);
    final horizontal = side == SymbolSide.left || side == SymbolSide.right;

    final token = stub.style.familyToken;
    final tokenW = sizer.tokenWidth(stub.style);
    final width = sizer.pennantWidth(
      stub.style,
      stub.netName,
      horizontal: horizontal,
    );
    // The pennant's extent ALONG THE STUB: its width when the stub runs
    // horizontally, its height plus the point when the stub runs vertically
    // and the pennant lies across it.
    final extent = horizontal ? width : _height + _tip;

    final pinKey = _pinKey(stub.symbol.id, stub.port.key);
    final first = !_consumed.containsKey(pinKey);
    final comb = first && !horizontal
        ? (combIndex[pinKey] ?? 0) * sizer.combStep
        : 0.0;
    final base = _consumed[pinKey] ?? 0.0;
    final edge = stub.port.size / 2;

    final start = _along(centre, outward, edge + base);
    final anchor = _along(centre, outward, edge + base + _leader + comb);
    _consumed[pinKey] = base + _leader + comb + extent + _gap;

    // ── channel 1/2/3: the leader ────────────────────────────────────
    _leaders.add(
      OpLine(
        start,
        anchor,
        Stroke(
          argb: stub.style.argb,
          widthPt: stub.style.widthPt,
          dash: stub.style.dash,
        ),
      ),
    );

    final box = _pennantBox(anchor, side, width);

    // ── the backing, under the tint ──────────────────────────────────
    //
    // ═══════════════════════════════════════════════════════════════
    // THIS DOES NOT CHANGE THE 12% FIGURE, AND THAT IS THE POINT
    // ═══════════════════════════════════════════════════════════════
    // docs/05 §11.5 states the pennant exactly: *"Fill is the domain
    // colour at 12% with a full-strength outline."* [NetLabelStyle
    // .fillAlpha] is that 12%, and it is a CITATION rather than a knob —
    // so the field's report that flags are hard to read over a wire
    // could not be answered by raising it without contradicting the
    // corpus, and raising it would have been wrong anyway: the family
    // token inside the pennant is inked in the SAME domain hue, so a
    // strongly-tinted fill takes the token down with it.
    //
    // What §11.5 specifies is the FILL. It says nothing about the
    // pennant being TRANSPARENT TO WHAT IS BEHIND IT, and until DR-001
    // there was nothing behind it — a pennant sat on bare paper, where
    // 12% over paper is all 12% can mean. DR-001 made labels the default
    // render and M2-E put drawn wires on the same sheet, so a flag now
    // has a staircase running under it and 12% of a hue over a wire is a
    // wire you can still see.
    //
    // So the tint stays at 12% and an OPAQUE BACKING goes under it.
    // Over bare sheet the composite is 12% domain over an opaque surface
    // — which is what §11.5 describes and what the sheet has always
    // looked like. Over a wire, the wire is masked. The specified
    // appearance is preserved exactly where it was ever specified, and
    // the case it did not anticipate is the only one that changes.
    //
    // `bodyFill` RATHER THAN A NEW PALETTE ENTRY: it is already "the
    // opaque surface a mark sits on", it is derived from the theme's
    // `ColorScheme.surface` at the one place the two colour regimes meet
    // (`_schematicPalette`), so it inverts correctly in a dark theme
    // without a second entry to keep in parity. The flag reads as a
    // small card, which is what a net-label flag is.
    // ONE OPAQUE FILL, COMPOSITED — not a translucent tint over a backing.
    //
    // ═══════════════════════════════════════════════════════════════
    // THE COLOUR IS THE SAME; THE ALPHA IS NOT
    // ═══════════════════════════════════════════════════════════════
    // The previous commit drew an opaque backing and laid the 12% tint on
    // top, which made the flag opaque in TWO ops. `_over` does the same
    // composite arithmetically and emits ONE: the hue at
    // `style.fillAlpha` over `palette.bodyFill`, resolved to a single
    // fully-opaque colour.
    //
    // Same pixels over bare sheet, same pixels over a wire, and the op
    // count returns to four per flag — so the 25% rise in the label term
    // the backing cost is given back. docs/05 §11.5's "domain colour at
    // 12%" is still exactly what the flag looks like; what changed is
    // that it no longer depends on what happens to be underneath it,
    // which is the whole of the field's complaint.
    _pennants.add(
      OpPath(
        _pennantPath(anchor, side, width),
        fill: Fill(_over(stub.style.argb, style.fillAlpha, palette.bodyFill)),
        stroke: Stroke(
          argb: stub.style.argb,
          widthPt: style.outlineWidthPt,
        ),
      ),
    );

    // ── channel 4, then the identity ─────────────────────────────────
    //
    // Both anchored midLeft on the pennant's own centre line, so the two
    // runs share a baseline regardless of their sizes.
    final textLeft = horizontal
        ? (side == SymbolSide.left ? box.left + _tip + _pad : box.left + _pad)
        : box.left + _pad;
    final midY = horizontal
        ? anchor.y
        : side == SymbolSide.top
        ? box.bottom - _height / 2
        : box.top + _height / 2;
    // ═══════════════════════════════════════════════════════════════
    // CHANNEL 4a IS GEOMETRY WHEN THE GLYPH HAS A SHAPE — #124
    // ═══════════════════════════════════════════════════════════════
    // See `family_glyph.dart`. The glyph is a path whose width is
    // COMPUTED, so no font can measure it short and draw it wide; the tag
    // beside it is ASCII plus `·` and stays a measured run. Where the
    // glyph has no shape — a registry a user authored in M4, or a domain
    // that did not resolve — the whole token is one text run exactly as
    // before, which is right whenever the font does carry it.
    //
    // THE GLYPH GOES IN ITS OWN TIER, between the pennants and the texts.
    // It is ink INSIDE the flag, so it must land after the fill that would
    // otherwise cover it and before nothing in particular — but the tier
    // has to exist, because `_pennants` is flushed as a block and appending
    // a glyph there would put one flag's glyph under the next flag's fill
    // on a combed edge, which is 96-I's defect arriving through a new door.
    final shape = familyGlyphFor(stub.style.glyph);
    if (shape == null) {
      _texts.add(
        OpText(token, DPt(textLeft, midY), _tokenStyle(stub.style.argb)),
      );
    } else {
      _glyphs.add(
        familyGlyphOp(
          shape,
          DPt(textLeft, midY),
          style.tokenSizePt,
          stub.style.argb,
          // The pennant outline's width, for the same reason it is a
          // hairline there: the WEIGHT channel is the leader's, and a
          // hollow glyph stroked at the family's weight would say it twice.
          hollowWidthPt: style.outlineWidthPt,
        ),
      );
      _texts.add(
        OpText(
          stub.style.tag,
          DPt(textLeft + familyGlyphAdvance(style.tokenSizePt), midY),
          _tokenStyle(stub.style.argb),
        ),
      );
    }
    _texts.add(
      OpText(stub.netName, DPt(textLeft + tokenW + _gap, midY), _nameStyle),
    );

    labels.add(
      RenderedNetLabel(
        linkId: stub.link.id,
        deviceId: stub.symbol.id,
        portKey: stub.port.key,
        side: side,
        style: stub.style,
        netName: stub.netName,
        pinCentre: centre,
        pennant: box,
      ),
    );
    // INK, NOT GEOMETRY. A stroke straddles its path, so the pennant's
    // outline reaches `outlineWidthPt / 2` outside [box] and the leader
    // reaches `widthPt / 2` outside its segment — 0.25 and up to 0.7 units
    // on the shipped figures. `RenderedNetLabel.pennant` stays the
    // geometric box (that is what a hit test wants); only the BOUNDS grow,
    // because a page box computed from the geometry alone scales to fit
    // and then shaves the outline off the outermost flag.
    //
    // The two halves are applied to their own shapes rather than taking
    // the larger of the two over both, so this agrees with `BoundsCanvas`
    // op for op — `net_label_layer_test.dart` compares them, on all four
    // edges, and that comparison is what found this.
    final ink = box
        .inflate(style.outlineWidthPt / 2)
        .union(
          DBox.fromCorners(start, anchor).inflate(stub.style.widthPt / 2),
        );
    bounds = bounds == null ? ink : bounds!.union(ink);
  }

  TextStyleSpec _tokenStyle(int argb) =>
      rackText(style.tokenSizePt, argb, TextAnchor.midLeft);

  TextStyleSpec get _nameStyle =>
      rackText(style.nameSizePt, palette.netLabelText, TextAnchor.midLeft);

  /// The pennant's outer box, apex included.
  DBox _pennantBox(DPt anchor, SymbolSide side, double width) => switch (side) {
    SymbolSide.left => DBox.fromLtwh(
      anchor.x - width,
      anchor.y - _height / 2,
      width,
      _height,
    ),
    SymbolSide.right => DBox.fromLtwh(
      anchor.x,
      anchor.y - _height / 2,
      width,
      _height,
    ),
    SymbolSide.top => DBox.fromLtwh(
      anchor.x - width / 2,
      anchor.y - _height - _tip,
      width,
      _height + _tip,
    ),
    SymbolSide.bottom => DBox.fromLtwh(
      anchor.x - width / 2,
      anchor.y,
      width,
      _height + _tip,
    ),
  };

  /// The pentagon: a rectangle with its point on the OUTWARD side — see
  /// the file header on why outward and not inward.
  DiagramPath _pennantPath(DPt anchor, SymbolSide side, double width) {
    final box = _pennantBox(anchor, side, width);
    return switch (side) {
      SymbolSide.left => DiagramPath([
        MoveTo(box.right, box.top),
        LineTo(box.right, box.bottom),
        LineTo(box.left + _tip, box.bottom),
        LineTo(box.left, anchor.y),
        LineTo(box.left + _tip, box.top),
        const ClosePath(),
      ]),
      SymbolSide.right => DiagramPath([
        MoveTo(box.left, box.top),
        LineTo(box.left, box.bottom),
        LineTo(box.right - _tip, box.bottom),
        LineTo(box.right, anchor.y),
        LineTo(box.right - _tip, box.top),
        const ClosePath(),
      ]),
      SymbolSide.top => DiagramPath([
        MoveTo(box.left, box.bottom),
        LineTo(box.right, box.bottom),
        LineTo(box.right, box.top + _tip),
        LineTo(anchor.x, box.top),
        LineTo(box.left, box.top + _tip),
        const ClosePath(),
      ]),
      SymbolSide.bottom => DiagramPath([
        MoveTo(box.left, box.top),
        LineTo(box.right, box.top),
        LineTo(box.right, box.bottom - _tip),
        LineTo(anchor.x, box.bottom),
        LineTo(box.left, box.bottom - _tip),
        const ClosePath(),
      ]),
    };
  }
}

/// The unit vector pointing out of the body from [side].
DPt _outward(SymbolSide side) => switch (side) {
  SymbolSide.left => const DPt(-1, 0),
  SymbolSide.right => const DPt(1, 0),
  SymbolSide.top => const DPt(0, -1),
  SymbolSide.bottom => const DPt(0, 1),
};

DPt _along(DPt from, DPt unit, double distance) =>
    DPt(from.x + unit.x * distance, from.y + unit.y * distance);

/// [src] at [alpha]/255 composited over an opaque [dst], as one OPAQUE
/// colour.
///
/// REPLACES `_withAlpha`, which set the pennant's alpha and let the painter
/// composite. docs/05 §11.5's 12% is still BAKED INTO THE COLOUR — never an
/// opacity layer, per §11.2's `saveLayer` ban — but it is baked all the way
/// now, against a known surface instead of against whatever the painter
/// finds underneath.
///
/// ═══════════════════════════════════════════════════════════════════════
/// SOURCE-OVER, RESOLVED AT BUILD TIME RATHER THAN AT PAINT TIME
/// ═══════════════════════════════════════════════════════════════════════
/// The pennant is specified as "the domain colour at 12%" (docs/05 §11.5),
/// and for the whole of M2 that was emitted literally — a translucent fill,
/// which composites against WHATEVER IS BEHIND IT. On bare sheet that is
/// the sheet, which is what §11.5 means. Once M2-E put drawn wires under
/// the flags it was also the wire, and 12% of a hue over a wire is a wire
/// you can still read straight through the label.
///
/// Doing the blend here makes the result independent of what is behind.
/// The arithmetic is ordinary source-over per channel; [dst] is assumed
/// opaque, which every `SchematicPalette` surface is, so the result is too.
///
/// NOT A COLOUR POLICY. This composites two colours the caller already
/// chose; it picks neither. `signal_style.dart` remains the one place a hue
/// is resolved.
int _over(int src, int alpha, int dst) {
  final a = alpha / 255.0;
  int mix(int shift) {
    final s = (src >> shift) & 0xFF;
    final d = (dst >> shift) & 0xFF;
    return (s * a + d * (1 - a)).round().clamp(0, 255);
  }

  return 0xFF000000 | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}
