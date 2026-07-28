// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show LifecycleStatus;
import 'package:rackmate_core/src/model/service.dart';
import 'package:rackmate_core/src/model/structure_body.dart'
    show StructureOrigin;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/permille.dart';

/// fieldCable|jumper|powerCord|internal — auto-classified,
/// user-overridable (AC-026). The schedule excludes jumpers by default.
enum LinkClass { fieldCable, jumper, powerCord, internal }

/// cl2|cl3|cmr|cmp|lszh|directBurial. Not decorative: `CODE-002` is an
/// error when a pathway is a plenum space and the jacket is not `cmp`/
/// `lszh` (NEC 800.154) — given directly in docs/canonical-decisions.md
/// line 4425.
enum JacketRating { cl2, cl3, cmr, cmp, lszh, directBurial }

/// straight|nullModem|fiberPolarityAB.
enum CrossoverKind { straight, nullModem, fiberPolarityAB }

/// planned|pulled|dressed|terminated|tested.
enum RoughInStatus { planned, pulled, dressed, terminated, tested }

/// The outcome of certifying a `Link` (RJ-004).
///
/// M0 MINIMAL SHAPE: docs/02-data-model.md names this type only as
/// "pass/fail + headroom + certificate id"; the unit/meaning of
/// `headroom` (e.g. a worst-case dB margin at a given frequency) is not
/// specified anywhere in the corpus, so it is kept as a bare nullable
/// int rather than inventing a unit.
final class TestResult {
  TestResult({required this.pass, this.headroom, this.certificateId});

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  bool pass;
  int? headroom;
  String? certificateId;
}

/// ONE PHYSICAL CABLE. One `W###`. One schedule row (G1: the schedule is
/// the deliverable). No `netId`, no waypoints, no `autoRoute` — route
/// geometry is never persisted (CR-012).
final class Link {
  Link({
    required this.id,
    required String designator,
    required this.media,
    required this.order,
    required this.meta,
    this.designatorLocked = false,
    this.linkClass = LinkClass.fieldCable,
    List<Service>? services,
    List<Conductor>? conductors,
    List<Breakout>? breakouts,
    List<InlineAdapter>? inlineAdapters,
    this.cableSpecId,
    this.gaugeAwg,
    this.jacket,
    JacketColorId? jacketColorId,
    JacketColorId? jacketColorPulledId,
    this.shielded = false,
    this.plenum = false,
    this.routedLength,
    this.cutLength,
    this.terminatedLength,
    this.slack,
    this.pathwayId,
    this.crossover,
    this.lifecycleStatus = LifecycleStatus.new_,
    this.roughInStatus = RoughInStatus.planned,
    this.test,
    this.installedBy,
    this.terminatedAt,
    this.structureOrigin,
    String? notes,
  }) : services = services ?? [],
       conductors = conductors ?? [],
       breakouts = breakouts ?? [],
       inlineAdapters = inlineAdapters ?? [],
       _designator = designator,
       _jacketColorId = jacketColorId,
       _jacketColorPulledId = jacketColorPulledId,
       _notes = notes;

  final Uuid id;

  /// "W042".
  String _designator;
  String get designator => _designator;
  @internal
  set designator(String v) => _designator = v;

  String? _notes;
  String? get notes => _notes;
  @internal
  set notes(String? v) => _notes = v;

  // ─────────────────────────────────────────────────────────────────
  // JACKET COLOUR — TWO FACTS, RECORDED BY TWO PEOPLE AT TWO TIMES.
  // ─────────────────────────────────────────────────────────────────
  // These two sit HERE, in the AC-013-converted region, rather than
  // beside `jacket`/`media` where they read more naturally, because
  // `SetLinkJacketColorCommand` and `SetLinkPulledJacketColorCommand`
  // drive them: the retrofit comment further down promises conversion
  // "as each is wired to a Command", and this is that.
  //
  // Neither is ever resolved against the convention map here. The
  // resolution — what was pulled, whether this run is an exception,
  // what colour the keystone is — is DERIVED, in
  // `derived/jacket_color_resolution.dart`. Storing an answer that is
  // computable from two stored facts is what CR-107 deleted
  // `StructureDrop` for.

  /// WHAT THE RUN IS — a reference into
  /// `ProjectSettings.jacketColorConventions` naming the convention
  /// entry this run follows ("this is a control drop"). This is the
  /// SEMANTIC fact, and it is what a keystone follows: the keystone is
  /// chosen weeks after the pull, out of the same box as every other
  /// control drop's, so it is routinely correct even when the cable is
  /// not (see [jacketColorPulledId]).
  ///
  /// Three colour-ish facts live near each other on this class and must
  /// not be confused: [jacket] is the NEC FIRE RATING (CODE-002, NEC
  /// 800.154), `Conductor.colorCode` is the PAIR COLOUR INSIDE the
  /// sheath, and this names the convention the run belongs to. NEVER
  /// feeds a drawn wire's hue — see CR-078/PAL-1 and
  /// `jacket_colour_is_not_hue_test.dart`.
  ///
  /// An id resolving to no entry is UNKNOWN, never guessed (G4): it
  /// decodes intact so a round trip cannot destroy it, and a consumer
  /// counts it rather than substituting a default colour.
  JacketColorId? _jacketColorId;
  JacketColorId? get jacketColorId => _jacketColorId;
  @internal
  set jacketColorId(JacketColorId? v) => _jacketColorId = v;

  /// WHAT WAS ACTUALLY PULLED, set ONLY when the cable in the wall is
  /// not the convention colour — they ran out of blue, or a prewire
  /// mistake happened.
  ///
  /// NULL IS THE NORMAL CASE and means "matches the convention". This
  /// exists because DOCUMENTATION OF IMPERFECTIONS BEATS NO
  /// DOCUMENTATION AT ALL: a control run pulled in yellow must read on
  /// a schedule as `BLU · CONTROL — PULLED YEL`, never silently as
  /// yellow and never silently as blue.
  ///
  /// NEVER DRIVES THE KEYSTONE. [jacketColorId] does, alone — that is
  /// the requesting integrator's own stated rule and it is a real
  /// trim-out fact. `keystone_follows_convention` in
  /// `jacket_color_resolution_test.dart` is the gate on it.
  ///
  /// A value EQUAL to [jacketColorId] is not an exception and the
  /// Command normalises it to null on the write path, so "no exception"
  /// has exactly one on-disk spelling (CR-117). A hand-edited file or a
  /// CSV import can still carry one, so the resolver checks the
  /// inequality too rather than trusting the write path.
  JacketColorId? _jacketColorPulledId;
  JacketColorId? get jacketColorPulledId => _jacketColorPulledId;
  @internal
  set jacketColorPulledId(JacketColorId? v) => _jacketColorPulledId = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// Auto-set at `roughInStatus >= pulled` (AC-034/m22).
  bool designatorLocked;
  LinkClass linkClass;

  /// 1..N (CR-010, AC-021).
  List<Service> services;

  /// 1..N. One 16/4 cable = one Link, four Conductors (RJ-016).
  List<Conductor> conductors;

  /// Fan-outs; a Link may reach N devices (CR-014).
  List<Breakout> breakouts;

  /// PASSIVE only; two-cable adapters are `DeviceInstance`s (CR-015).
  List<InlineAdapter> inlineAdapters;

  MediaTypeId media;
  String? cableSpecId;
  int? gaugeAwg;
  JacketRating? jacket;

  // The two jacket-COLOUR fields are declared above, in the
  // AC-013-converted region — see the block header there for why.

  bool shielded;
  bool plenum;

  /// Three fields, three columns: pull sheet wants cut length, as-built
  /// wants terminated length, takeoff wants routed length (AC-024/M9).
  Len? routedLength;
  Len? cutLength;
  Len? terminatedLength;
  Permille? slack;
  Uuid? pathwayId;
  CrossoverKind? crossover;

  /// Same five-value enum as `DeviceInstance.lifecycleStatus` (CR-064,
  /// CR-065, AC-018).
  LifecycleStatus lifecycleStatus;
  RoughInStatus roughInStatus;
  TestResult? test;
  String? installedBy;
  DateTime? terminatedAt;

  /// Home runs only (AC-019).
  StructureOrigin? structureOrigin;
  FracIndex order;
  EntityMeta meta;
}
