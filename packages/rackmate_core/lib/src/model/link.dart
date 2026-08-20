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

/// The NEC/UL LISTING printed on a cable's jacket. DR-079 §11.78.1.
///
/// ═══════════════════════════════════════════════════════════════════════
/// A LISTING IS NOT A MATERIAL, AND CONFLATING THEM PRODUCED A FALSE PASS
/// ═══════════════════════════════════════════════════════════════════════
/// This was `JacketRating { cl2, cl3, cmr, cmp, lszh, directBurial }`, and
/// `CODE-002` accepted `lszh` as satisfying NEC 800.154's plenum
/// requirement. **LSZH is a jacket compound characteristic, not a
/// listing**: low smoke zero halogen is an IEC and European concern about
/// smoke density and halogen acid gas during evacuation, and it says
/// nothing about the flame spread and smoke development testing (UL 910 /
/// NFPA 262) a plenum listing rests on. An LSZH cable may carry no plenum
/// listing at all.
///
/// So the product would have told somebody their unlisted cable was FINE
/// in a plenum. **A false pass is worse than a false failure**: the false
/// failure gets argued with and the false pass gets built. LSZH is now
/// [Link.lowSmokeZeroHalogen] and direct burial, which is an APPLICATION
/// rather than a listing, is [Link.directBurialRated].
///
/// ═══════════════════════════════════════════════════════════════════════
/// FIVE ARTICLES, BECAUSE THIS PRODUCT'S MEDIA TOUCH FIVE
/// ═══════════════════════════════════════════════════════════════════════
/// Ordered by article and then by rating, ascending, which is also the
/// substitution order within each family (`port_jacket_listing.dart`
/// carries that as data). The suffix convention is the NEC's own: no
/// suffix is general purpose, `G` general purpose (fibre), `R` riser,
/// `P` plenum, `X` limited use / dwelling.
///
/// **THE ARTICLE IS PART OF THE FACT.** `cmp` and `cl3p` are both plenum
/// and are not interchangeable, because they are tested and listed under
/// different articles for different uses. Anything that reasons about
/// these values reasons per article or answers UNKNOWN (G4).
enum JacketListing {
  // ── Art. 800 / 805, communications ──────────────────────────────────
  cm,
  cmg,
  cmr,
  cmp,
  cmx,

  // ── Art. 725, Class 2 and Class 3 ───────────────────────────────────
  cl2,
  cl2r,
  cl2p,
  cl2x,
  cl3,
  cl3r,
  cl3p,
  cl3x,

  // ── Art. 760, power-limited fire alarm ──────────────────────────────
  fpl,
  fplr,
  fplp,

  // ── Art. 770, optical fibre ─────────────────────────────────────────
  // Nonconductive (`OFN`) and conductive (`OFC`) are separate families:
  // a conductive fibre cable carries a metallic member and is not a
  // substitute for a nonconductive one.
  ofn,
  ofng,
  ofnr,
  ofnp,
  ofc,
  ofcg,
  ofcr,
  ofcp,

  // ── Art. 820, coaxial ───────────────────────────────────────────────
  catv,
  catvr,
  catvp,
  catvx,
}

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
    LinkClass linkClass = LinkClass.fieldCable,
    bool linkClassLocked = false,
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
    this.lowSmokeZeroHalogen,
    this.directBurialRated,
    Len? routedLength,
    Len? cutLength,
    Len? terminatedLength,
    this.slack,
    this.pathwayId,
    this.crossover,
    LifecycleStatus lifecycleStatus = LifecycleStatus.new_,
    int? spliceCount,
    RoughInStatus roughInStatus = RoughInStatus.planned,
    TestResult? test,
    String? installedBy,
    DateTime? terminatedAt,
    this.structureOrigin,
    String? notes,
  }) : services = services ?? [],
       conductors = conductors ?? [],
       breakouts = breakouts ?? [],
       inlineAdapters = inlineAdapters ?? [],
       _designator = designator,
       _linkClass = linkClass,
       _linkClassLocked = linkClassLocked,
       _jacketColorId = jacketColorId,
       _jacketColorPulledId = jacketColorPulledId,
       _lifecycleStatus = lifecycleStatus,
       _spliceCount = spliceCount,
       _roughInStatus = roughInStatus,
       _routedLength = routedLength,
       _cutLength = cutLength,
       _terminatedLength = terminatedLength,
       _test = test,
       _installedBy = installedBy,
       _terminatedAt = terminatedAt,
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

  // ─────────────────────────────────────────────────────────────────
  // LINK CLASS — TWO PIECES OF STATE, AND THE SECOND IS WHY.
  // ─────────────────────────────────────────────────────────────────
  // DR-008 §11.8.2. The classifier (`derived/link_class.dart`) is
  // ADVISORY: it never writes here. When a person sets the class by
  // hand that assertion is stored and kept, and if the document later
  // changes so the classifier would say something else, THE USER'S
  // VALUE STANDS AND THE DISAGREEMENT IS REPORTABLE.
  //
  // One field cannot express that. With only [linkClass] there is no
  // way to tell "the classifier said jumper" from "a person said
  // jumper", so moving a device either silently overwrites a human
  // judgement or is silently ignored — with nothing able to say which
  // happened. That is the same shape, for the same reason, as
  // [jacketColorId] / [jacketColorPulledId] under CR-121, and the
  // precedent is already on this class in [designatorLocked].

  /// What this link IS, as stored. Only authoritative when
  /// [linkClassLocked]; otherwise it is an inert leftover and
  /// `effectiveLinkClassOf` ignores it in favour of the classifier.
  ///
  /// Defaults to [LinkClass.fieldCable] because a `Link` must decode to
  /// something and the field is mandatory on the wire. Do NOT read that
  /// default as a claim: an unlocked link's class is whatever
  /// `linkClassOf` derives, up to and including `null` for undetermined.
  LinkClass _linkClass;
  LinkClass get linkClass => _linkClass;
  @internal
  set linkClass(LinkClass v) => _linkClass = v;

  /// TRUE ONLY WHEN A PERSON SET THE CLASS. Never set by the classifier.
  ///
  /// ON THE WIRE THIS KEY IS ABSENT WHEN FALSE, per CR-117's
  /// absent-key-is-not-null contract — false is overwhelmingly the normal
  /// case, so every document that has never had a hand-set class encodes
  /// BYTE-FOR-BYTE as it did before this field existed and
  /// `kSchemaVersion` does not move. Note this deliberately does NOT
  /// follow [designatorLocked], which is written unconditionally: adding
  /// an always-written key here would rewrite every existing document.
  bool _linkClassLocked;
  bool get linkClassLocked => _linkClassLocked;
  @internal
  set linkClassLocked(bool v) => _linkClassLocked = v;

  /// Same five-value enum as `DeviceInstance.lifecycleStatus` (CR-064,
  /// CR-065, AC-018). Written through `LinkField.lifecycleStatus`.
  LifecycleStatus _lifecycleStatus;
  LifecycleStatus get lifecycleStatus => _lifecycleStatus;
  @internal
  set lifecycleStatus(LifecycleStatus v) => _lifecycleStatus = v;

  /// How many splices are in this run (DR-020 §11.19.2(3)). Written
  /// through `LinkField.spliceCount`.
  ///
  /// NULL IS UNKNOWN, `0` IS A CONFIRMED NONE (G4, CR-114), and a
  /// non-nullable `int` defaulting to `0` is the whole failure this
  /// nullability exists to prevent: it cannot tell "nobody has looked"
  /// from "somebody looked and there are none". A splice count is a
  /// number an installer acts on, so the two must stay apart.
  ///
  /// A REAL AS-BUILT FACT WITH REAL CONSEQUENCES, which is why DR-020
  /// put it in v1 rather than deferring it: on Cat6 a splice breaks the
  /// channel and fails certification, on coax it is loss, on fibre it is
  /// normal and engineered. [notes] carries the why; this carries the
  /// how many.
  ///
  /// NO RULE READS IT YET, and that is deliberate. Canon §5 is explicit
  /// that a rule not listed does not exist, and DR-020 adds exactly one
  /// rule to v1 (`LEN-002`, in M5). M3 is where the fact is entered.
  int? _spliceCount;
  int? get spliceCount => _spliceCount;
  @internal
  set spliceCount(int? v) => _spliceCount = v;

  /// How far along this run is: planned, pulled, dressed, terminated,
  /// tested.
  ///
  /// CONVERTED AT M3-C/2, when the Structure editor made it an editable
  /// cell. It is the column a person actually walks the job with, and
  /// docs/07 §4.1 puts it among the eight defaults for that reason.
  ///
  /// NOT NULLABLE, unlike almost everything else on this class, and that
  /// is not an oversight about G4: `planned` IS the state of a drop
  /// nobody has touched, so there is no "unknown" to distinguish it from.
  /// A cable that exists in the document has, at minimum, been planned.
  RoughInStatus _roughInStatus;
  RoughInStatus get roughInStatus => _roughInStatus;
  @internal
  set roughInStatus(RoughInStatus v) => _roughInStatus = v;

  // ─────────────────────────────────────────────────────────────────
  // THE AS-BUILT FOUR (DR-020 §11.19.2(5), M3-J/3).
  // ─────────────────────────────────────────────────────────────────
  // "The as-built story was 80 % modelled and 0 % reachable" (§11.19.3).
  // These four were modelled from M0 and had no gesture; the Structure
  // editor's optional columns are that gesture, so this is where they
  // take the AC-013 retrofit.

  /// What was actually terminated, end to end (AC-024).
  ///
  /// NULL IS UNKNOWN, never a measured zero, and it is a DIFFERENT FACT
  /// from [cutLength]: the pull sheet's number is what to order and this
  /// is what went in. A rollup that substituted one for the other would
  /// bill an estimate.
  Len? _terminatedLength;
  Len? get terminatedLength => _terminatedLength;
  @internal
  set terminatedLength(Len? v) => _terminatedLength = v;

  // ─────────────────────────────────────────────────────────────────
  // AND THE OTHER TWO OF AC-024'S THREE (M3-D/2).
  // ─────────────────────────────────────────────────────────────────
  // M3-J/3 converted the as-built length alone and said why: a field
  // takes the retrofit "as each is wired to a Command", and that task
  // wired one. These two are the Command that did not exist then. The
  // three now sit together because AC-024's rule is about the three as a
  // SET — "three fields, three columns" — and a reader who finds one of
  // them needs the other two in view to see which fact they are holding.

  /// The takeoff's estimate of how far this run travels (AC-024).
  ///
  /// FIRST OF THE THREE AND THE LEAST BINDING. It is what a person
  /// pacing a set of drawings believes before anybody pulls anything, so
  /// it is the number to plan a truck load from and the wrong number to
  /// bill from. Null is unknown, never a measured zero.
  Len? _routedLength;
  Len? get routedLength => _routedLength;
  @internal
  set routedLength(Len? v) => _routedLength = v;

  /// What to actually pull, and the one the Pull Sheet prints (AC-024).
  ///
  /// THE ONLY ONE OF THE THREE `derived/schedule.dart` READS for its
  /// `LEN` column, at the head of `_lengthOf`'s chain, so this is the
  /// field that decides whether a row prints an upright measurement or
  /// an italic estimate. Filling it in is what promotes a row from
  /// `ScheduleLengthSource.outletNominal` to `.cut`.
  Len? _cutLength;
  Len? get cutLength => _cutLength;
  @internal
  set cutLength(Len? v) => _cutLength = v;

  /// The certification result, or null for NOT TESTED.
  ///
  /// REPLACED WHOLE, never mutated in place, by every caller that writes
  /// it. `SetEntityPropertyCommand` captures the previous VALUE to undo
  /// with, so an in-place edit of the old object would leave undo
  /// restoring a reference to something already changed.
  TestResult? _test;
  TestResult? get test => _test;
  @internal
  set test(TestResult? v) => _test = v;

  /// Who pulled it. Free text: a subcontractor's crew is not a document
  /// entity and inventing one to hold a name would be a model nobody
  /// asked for.
  String? _installedBy;
  String? get installedBy => _installedBy;
  @internal
  set installedBy(String? v) => _installedBy = v;

  /// When the trim-out crew landed it.
  ///
  /// NOTHING IN THE PRODUCT WRITES A TIME-OF-DAY into this, which is why
  /// the editor's column is a date and parses one. If a surface ever
  /// records the hour, that column has to grow rather than silently
  /// truncate.
  DateTime? _terminatedAt;
  DateTime? get terminatedAt => _terminatedAt;
  @internal
  set terminatedAt(DateTime? v) => _terminatedAt = v;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// Auto-set at `roughInStatus >= pulled` (AC-034/m22).
  bool designatorLocked;

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
  JacketListing? jacket;

  // The two jacket-COLOUR fields are declared above, in the
  // AC-013-converted region — see the block header there for why.

  bool shielded;

  /// Whether the jacket compound is low smoke zero halogen.
  ///
  /// **NOT A LISTING AND NEVER A SUBSTITUTE FOR ONE** (DR-079 §11.78.1).
  /// It is an independent fact about the compound: an LSZH cable may
  /// carry any [JacketListing] or none, and nothing may read this field
  /// to answer a question about NEC 800.154.
  ///
  /// TRI-STATE, because G4 applies to it like everything else: null is
  /// "nobody recorded this", not "no".
  bool? lowSmokeZeroHalogen;

  /// Whether the cable is rated for direct burial.
  ///
  /// An APPLICATION rather than a listing, which is why it left the
  /// listing enum with LSZH. Tri-state for the same reason.
  bool? directBurialRated;

  // AC-024's three lengths ARE NOT HERE ANY MORE. All three are wired to
  // Commands and all three sit in the converted region above; M3-D/2
  // closed the asymmetry M3-J/3 left and recorded.
  Permille? slack;
  Uuid? pathwayId;
  CrossoverKind? crossover;

  /// Home runs only (AC-019).
  StructureOrigin? structureOrigin;
  FracIndex order;
  EntityMeta meta;
}
