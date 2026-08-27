// `Ctrl+G` `Group as set…` and `Ctrl+Shift+G` `Ungroup`, docs/06 §4.6.
// Board `#181` / `#224` (M4-J2), DR-086 §11.85.
//
// ═══════════════════════════════════════════════════════════════════════
// A SET IS MADE FROM ROWS, AND THE SEED CATALOG IS WHY
// ═══════════════════════════════════════════════════════════════════════
// DR-086 §11.85.2 declines both of the arrangements that would let a
// `PortSetDef` exist before it has members. The argument is measured
// rather than aesthetic: `port_set_integrity_test.dart` records the
// SHIPPED catalog failing its own gate at 90 `setKey` references with 72
// dangling, 16 sets declared and 7 referenced by nothing, and 7
// `atomicConnect` sets with fewer than two members — all because
// declaring a set and filling it were two separate acts.
//
// Below two members the AC-053 gesture is undefined: `planAtomicConnect`
// resolves the set, finds one member, and degrades to a one-conductor
// link WITH NO ERROR. So [buildGroupAsSet] refuses under two rows, and a
// one-member set becomes something only a `Delete` or a hand-edited file
// can produce rather than something this product mints.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ROLE LIST IS CLOSED, AND THAT IS A CORRECTNESS FIX
// ═══════════════════════════════════════════════════════════════════════
// `planAtomicConnect` pairs members by declared position and reports a
// `RoleMismatch` by STRING EQUALITY, and `atomic_connect.dart`'s own
// header says the exposure "opens the moment M4 lets a user author a
// template". With a free-text role, `+`, `plus`, `POS` and `Pos` are four
// distinct roles and whoever types `Pos` gets a mismatch warning against
// every seeded amplifier they connect to. AC-030 exists so a polarity
// inversion is INEXPRESSIBLE; a column that can spell `+` four ways is
// the opposite of that.
//
// [setRolesFor] therefore spells the roles EXACTLY as the 35 seeded
// member ports spell them: `L`, `R`, `+`, `-`, ASCII hyphen. One prettier
// glyph here and every authored-to-seeded connect reports a mismatch.
//
// ═══════════════════════════════════════════════════════════════════════
// ROLES RUN OUT INTO BLANK. THEY DO NOT CYCLE.
// ═══════════════════════════════════════════════════════════════════════
// Grouping four rows as a stereo pair gives `L`, `R`, blank, blank, and
// the impact list names the two it left. Cycling would write `L`, `R`,
// `L`, `R` and produce two members claiming one role, which is the
// mis-wiring `port_set_resolution.dart`'s header refuses to let a
// filtered list cause, arriving by another door. A blank role is legal:
// `PortSetMember.role` is nullable and its doc says "the position carries
// the meaning".
import 'package:rackpal_core/src/builder/port_commands.dart';
import 'package:rackpal_core/src/builder/port_impact.dart' show PortImpactRow;
import 'package:rackpal_core/src/builder/quick_add.dart' show uniqueSlugKey;
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Appends one port set. The mirror of [AddBankCommand], one type over.
///
/// HOLDS THE SET IT ADDED rather than a copy, so redo restores the
/// identical object and nothing can reach it in between to mutate it.
final class AddPortSetCommand extends Command<TemplateBody> {
  const AddPortSetCommand(this.set);

  final PortSetDef set;

  @override
  LabelKey get label => LabelKey.groupAsSet;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  void apply(TemplateBody aggregate) => aggregate.portSets.add(set);

  @override
  void revert(TemplateBody aggregate) {
    final at = aggregate.portSets.indexWhere((s) => s.key == set.key);
    if (at < 0) throw StateError('no port set ${set.key} to remove');
    aggregate.portSets.removeAt(at);
  }
}

/// Removes a port set that has no members left.
///
/// **ONLY `Ungroup` RUNS THIS, AND `RemovePortCommand` DELIBERATELY DOES
/// NOT.** DR-086 §11.85.6: deleting the last member of a set does not
/// delete the set, because an empty set is not a dangling reference, it is
/// an empty one, and it is what a person is about to put two ports back
/// into. `Ungroup` is different in kind: it is somebody saying in so many
/// words that these ports are not a set, so the heading goes with them.
final class RemovePortSetCommand extends Command<TemplateBody> {
  RemovePortSetCommand(this.setKey);

  final String setKey;

  /// Captured so [revert] restores it at its own index: `portSets` is read
  /// in list order by the codec, and a byte round trip that reorders it is
  /// a diff nobody asked for (CR-117).
  int? _at;
  PortSetDef? _removed;

  @override
  LabelKey get label => LabelKey.ungroupSet;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  void apply(TemplateBody aggregate) {
    final at = aggregate.portSets.indexWhere((s) => s.key == setKey);
    if (at < 0) throw StateError('no port set $setKey to remove');
    _at = at;
    _removed = aggregate.portSets.removeAt(at);
  }

  @override
  void revert(TemplateBody aggregate) {
    final at = _at;
    final removed = _removed;
    if (at == null || removed == null) throw StateError('revert before apply');
    aggregate.portSets.insert(at, removed);
  }
}

/// The `SetKind`s a person may choose for a NEW set (DR-086 §11.85.4).
///
/// **`balancedPair` IS ABSENT AND ITS ENUM VALUE STAYS.** Its one use in
/// the seeded catalog is A04's `bal`, "Balanced input pair", whose two
/// ports carry roles `L` and `R`: as authored it means *a stereo pair that
/// happens to be balanced*, which `PortDef.balanced` already records on
/// each port. The thing the NAME suggests, the two legs of one balanced
/// line, is `balanced` plus `Polarity` on the terminal, and AC-030 exists
/// so that a polarity inversion is inexpressible rather than merely
/// discouraged. Removing the value would move seeded bytes and break
/// CR-117's round trip on the one template carrying it.
const List<SetKind> kAuthorableSetKinds = [
  SetKind.stereoPair,
  SetKind.speakerPair,
  SetKind.componentVideo,
];

/// The roles [kind] offers, in the order members take them.
///
/// **SPELLED AS THE SEED SPELLS THEM.** See the file header: these strings
/// are compared for equality against seeded templates by
/// `planAtomicConnect`, so `-` is an ASCII hyphen and stays one.
///
/// `balancedPair` answers `L`/`R` because that is what its one seeded
/// instance carries. It is not offered for new sets (see
/// [kAuthorableSetKinds]), and this answers for it anyway so that a
/// template already holding one can still edit its members' roles.
List<String> setRolesFor(SetKind kind) => switch (kind) {
  SetKind.stereoPair || SetKind.balancedPair => const ['L', 'R'],
  SetKind.speakerPair => const ['+', '-'],
  SetKind.componentVideo => const ['Y', 'Pb', 'Pr'],
};

/// The kinds a picker should offer while editing [current].
///
/// **A VALUE NO MENU OFFERS MUST NOT BE SILENTLY RETYPED BY OPENING A
/// DIALOG.** M3-L's `SERVICE` finding, stated as a rule and applied here:
/// a set that already carries `balancedPair` keeps it, and the picker
/// includes it while that set is the one being edited.
List<SetKind> setKindOptions(SetKind? current) =>
    current == null || kAuthorableSetKinds.contains(current)
    ? kAuthorableSetKinds
    : [...kAuthorableSetKinds, current];

/// Why a group produced nothing.
enum GroupAsSetRefusal {
  /// Fewer than two rows. A set of one is the state DR-086 §11.85.2 makes
  /// inexpressible: `planAtomicConnect` resolves it, finds one member and
  /// degrades to a single-conductor link with no error.
  needsTwoRows,

  /// A sort badge is showing. The gesture writes no `order` but it READS
  /// one: roles go on in DECLARED order, so under a sort `L` would land on
  /// the row the person sees second.
  theViewIsSorted,

  /// Another set already carries this label. Refused rather than suffixed,
  /// on `bankLabelIsTaken`'s argument: a person who typed the name chose
  /// it, and two sets sharing a label is a picker that answers by list
  /// position.
  labelIsTaken,
}

/// One line of prose per refusal.
String groupAsSetRefusalMessage(GroupAsSetRefusal refusal) => switch (refusal) {
  GroupAsSetRefusal.needsTwoRows =>
    'A port set needs at least two ports. Select the ports that make up '
        'the pair or the triple, then group them.',
  GroupAsSetRefusal.theViewIsSorted =>
    'The grid is sorted. Roles are assigned in the declared order, not '
        'the order on screen, so clear the sort or commit it first.',
  GroupAsSetRefusal.labelIsTaken => 'A port set with that name already exists.',
};

/// What a group will do, computed before it does it.
final class GroupAsSetResult {
  const GroupAsSetResult.planned({
    required this.set,
    required this.commands,
    required this.impact,
  }) : refusal = null;

  const GroupAsSetResult.refused(GroupAsSetRefusal this.refusal)
    : set = null,
      commands = const [],
      impact = const [];

  /// The set that will be created, or the existing one being refilled.
  final PortSetDef? set;

  final List<Command<TemplateBody>> commands;

  /// DR-078 §11.77.3's per-row preview. One row per member, in the order
  /// the roles go on.
  final List<PortImpactRow> impact;

  final GroupAsSetRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// Whether [label] already names a port set of [body], ignoring [exceptKey].
bool portSetLabelIsTaken(
  TemplateBody body,
  String label, {
  String? exceptKey,
}) {
  final wanted = label.trim().toLowerCase();
  return body.portSets.any(
    (set) => set.key != exceptKey && set.label.toLowerCase() == wanted,
  );
}

/// A port-set key no set in [body] already holds.
///
/// `uniqueBankKey`'s derivation, one type over and through the same
/// helper, so `hdmi.inputs`, `front.pair` and `port.3` are one convention
/// rather than three.
String uniquePortSetKey(TemplateBody body, String label) => uniqueSlugKey(
  label,
  taken: {for (final set in body.portSets) set.key},
  fallback: 'set.${body.portSets.length + 1}',
);

/// `Ctrl+G`: make [selectedKeys] into a set called [label].
///
/// **THE DECLARED ORDER IS DERIVED HERE RATHER THAN TRUSTED FROM THE
/// CALLER.** `resolvePortSet` states that declared order is the set's
/// contract and DR-008 §11.8.3 pairs conductors on it, so the one thing
/// this function must not do is take a display order on faith. The two
/// coincide today, because the gesture refuses under a sort; deriving
/// makes that a fact rather than a coincidence.
///
/// **AN EXISTING SET WITH THIS LABEL IS REFILLED, NOT DUPLICATED**, which
/// is `buildQuickAdd`'s rule for banks. It is what stops `Ungroup` and
/// `Group` from accumulating empty headings: pass [reuseSetKey] to refill
/// a named set rather than mint a second one.
GroupAsSetResult buildGroupAsSet({
  required TemplateBody body,
  required Set<String> selectedKeys,
  required String label,
  required SetKind kind,
  bool atomicConnect = true,
  bool viewIsSorted = false,
  String? reuseSetKey,
}) {
  if (viewIsSorted) {
    return const GroupAsSetResult.refused(GroupAsSetRefusal.theViewIsSorted);
  }
  final members = [
    for (final port in portsInDeclaredOrder(body.ports))
      if (selectedKeys.contains(port.key.v)) port,
  ];
  if (members.length < 2) {
    return const GroupAsSetResult.refused(GroupAsSetRefusal.needsTwoRows);
  }
  if (portSetLabelIsTaken(body, label, exceptKey: reuseSetKey)) {
    return const GroupAsSetResult.refused(GroupAsSetRefusal.labelIsTaken);
  }

  final existing = reuseSetKey == null
      ? null
      : body.portSets.where((s) => s.key == reuseSetKey).firstOrNull;
  final set =
      existing ??
      PortSetDef(
        key: uniquePortSetKey(body, label),
        label: label,
        kind: kind,
        atomicConnect: atomicConnect,
      );

  final roles = setRolesFor(kind);
  final byLabel = {for (final s in body.portSets) s.key: s.label};
  final commands = <Command<TemplateBody>>[
    // THE SET LEADS, on `buildQuickAdd`'s argument for the bank: a port
    // naming a set that does not exist yet is a dangling reference for
    // however long the list takes to apply, and `revert` runs it
    // backwards.
    if (existing == null) AddPortSetCommand(set),
  ];
  final impact = <PortImpactRow>[];

  for (var i = 0; i < members.length; i++) {
    final port = members[i];
    final role = i < roles.length ? roles[i] : null;
    final leaving = port.setKey != null && port.setKey != set.key
        ? (byLabel[port.setKey] ?? port.setKey)
        : null;

    final ranOut =
        '${portSetKindLabel(kind)} has ${roles.length} roles and this is '
        'member ${i + 1}, so it gets none.';
    final notes = <String>[
      if (leaving != null) 'Leaves "$leaving".',
      if (role == null) ranOut,
    ];

    impact.add((
      key: port.key.v,
      before: port.setRole ?? '',
      after: role ?? '',
      note: notes.isEmpty ? null : notes.join(' '),
    ));

    if (port.setKey != set.key) {
      commands.add(
        SetPortFieldCommand<String?>(
          port: port.key,
          field: PortDefField.setKey,
          from: port.setKey,
          to: set.key,
        ),
      );
    }
    if (port.setRole != role) {
      commands.add(
        SetPortFieldCommand<String?>(
          port: port.key,
          field: PortDefField.setRole,
          from: port.setRole,
          to: role,
        ),
      );
    }
  }

  return GroupAsSetResult.planned(
    set: set,
    commands: commands,
    impact: impact,
  );
}

/// `Ctrl+Shift+G`: take [selectedKeys] out of whatever sets they are in,
/// and remove any set that is left with no members.
///
/// **THIS IS THE ONE PLACE A `PortSetDef` IS REMOVED, and DR-086 §11.85.6
/// is why `RemovePortCommand` is not.** Deleting a port is a person
/// editing the hardware; ungrouping is a person saying these ports are not
/// a set. Only the second is an instruction about the heading.
///
/// Returns an empty list when nothing in the selection is in a set, which
/// the caller reads as "nothing to do" rather than as a refusal.
List<Command<TemplateBody>> buildUngroupPortSets({
  required TemplateBody body,
  required Set<String> selectedKeys,
}) {
  final commands = <Command<TemplateBody>>[];
  final touched = <String>{};
  for (final port in portsInDeclaredOrder(body.ports)) {
    if (!selectedKeys.contains(port.key.v)) continue;
    final setKey = port.setKey;
    if (setKey == null) continue;
    touched.add(setKey);
    commands.add(
      SetPortFieldCommand<String?>(
        port: port.key,
        field: PortDefField.setKey,
        from: setKey,
        to: null,
      ),
    );
    if (port.setRole != null) {
      commands.add(
        SetPortFieldCommand<String?>(
          port: port.key,
          field: PortDefField.setRole,
          from: port.setRole,
          to: null,
        ),
      );
    }
  }
  if (commands.isEmpty) return commands;

  // THE HEADINGS GO LAST, so that no command in the list ever leaves a
  // port naming a set that has already been removed. `revert` runs
  // backwards and re-adds them first, for the same reason.
  for (final setKey in touched) {
    final remaining = body.ports.where(
      (p) => p.setKey == setKey && !selectedKeys.contains(p.key.v),
    );
    if (remaining.isEmpty && body.portSets.any((s) => s.key == setKey)) {
      commands.add(RemovePortSetCommand(setKey));
    }
  }
  return commands;
}

/// What a `SetKind` is called on screen.
///
/// HERE AND NOT IN THE WIDGET, on the rule `port_grid.dart`'s header
/// states: the moment a view writes `kind.name` it owns a second speller,
/// and the first time one changes they disagree on a printed schedule.
String portSetKindLabel(SetKind kind) => switch (kind) {
  SetKind.stereoPair => 'Stereo pair',
  SetKind.speakerPair => 'Speaker pair',
  SetKind.componentVideo => 'Component video',
  SetKind.balancedPair => 'Balanced pair',
};
