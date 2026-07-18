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
