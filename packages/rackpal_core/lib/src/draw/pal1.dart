// rackpal_core/src/draw/pal1.dart: pure Dart.
//
// PAL-1, THE GREYSCALE RULE, AS ARITHMETIC THE APP CAN RUN (canon §14,
// DR-122 §11.121.4, SFE-A1).
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS MOVED INTO CORE
// ═════════════════════════════════════════════════════════════════════
// PAL-1 was a CI gate over the SHIPPED families, written in Python
// (`tools/pal1_check.py`) so it could run before any Dart existed. DR-122
// lets a person clone a family and choose its dash and weight, and a
// family that person creates does not exist when CI runs. So the rule has
// to be enforceable at authoring time, which means in the app, which
// means here.
//
// The gate and the editor read THIS file. Two implementations of a
// legibility rule is how the printed sheet and the CI check come to
// disagree, which is CR-021's argument about the rule catalogue and
// M5-A's about the connector mating matrix, applied a third time.
//
// ═════════════════════════════════════════════════════════════════════
// THE PORT IS DIFFERENTIAL, NOT RE-DERIVED
// ═════════════════════════════════════════════════════════════════════
// `test/draw/pal1_test.dart` holds this file to every verdict the Python
// reached, limb by limb and pair by pair, over three palettes: the
// shipped one, the one canon §14.3 corrected, and the control dash §14.4's
// floor corrected. The last two are what make it a test: the shipped
// palette passes, so a comparison over it alone could not tell a port
// that agrees from one that never fails.
//
// ═════════════════════════════════════════════════════════════════════
// TWO PLACES THIS IS EXACT WHERE THE PYTHON WAS NOT
// ═════════════════════════════════════════════════════════════════════
// Dashes and weights are PERMILLE INTEGERS (CR-001, CR-079), so the mark
// thresholds and the weight ratio are integer comparisons rather than
// float ones. `max / min >= 1.4` in floating point and
// `max * 1000 >= 1400 * min` in integers agree on every shipped pair (the
// differential test is the evidence), and only the second can be trusted
// on a pair that lands exactly on the boundary. Luminance stays a double:
// it is WCAG's formula, and `contrast.dart` already owns it.
//
// ═════════════════════════════════════════════════════════════════════
// THE WITHIN-DOMAIN LIMB IGNORES THE GLYPH, AND THAT IS NOW A CHOICE
// ═════════════════════════════════════════════════════════════════════
// §14.1 lets two families in one domain differ in "dash pattern, weight,
// or glyph". The Python dropped the glyph with the note "glyph is
// per-domain, so it cannot help", which DR-181 made untrue by adding
// `SignalFamilyDef.glyphOverride`. This limb keeps the Python's STRICTER
// reading, (domain, dash, weight), for two reasons: the port must agree
// with the gate it replaces, and a clone cannot choose its glyph (DR-122
// §11.121.2 gives it a name, a tag, a dash and a weight), so the strict
// reading is exactly the one an editor can act on.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/contrast.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/rgb.dart';

/// Two families whose luminances differ by LESS than this are confusable
/// in greyscale, and must be told apart by dash class or weight (§14.1).
const double kPal1LuminanceBand = 0.10;

/// Limb (b): weights that differ by at least this factor, in permille
/// (`1400` = 1.4×), rescue a shared dash class.
const int kPal1WeightRatioPermille = 1400;

/// §14.4: a dash period below 4.5 pt blurs to solid at 300 dpi. In
/// permille-points, like every dash in the registry.
const int kPal1PeriodFloorPermille = 4500;

/// §14.2's mark thresholds in permille-points: a dot is under 2.5 pt and
/// a long is 9 pt or more. Everything between is a short.
const int kPal1DotBelowPermille = 2500;

/// See [kPal1DotBelowPermille].
const int kPal1LongFromPermille = 9000;

/// One mark of a dash pattern, classified by length (§14.2).
enum Pal1Mark { dot, short, long }

/// The class of a single mark of [lengthPermille] permille-points.
Pal1Mark pal1MarkOf(int lengthPermille) {
  if (lengthPermille < kPal1DotBelowPermille) return Pal1Mark.dot;
  if (lengthPermille < kPal1LongFromPermille) return Pal1Mark.short;
  return Pal1Mark.long;
}

const _markEquality = ListEquality<Pal1Mark>();

/// The class of a dash pattern: its sequence of mark classes, compared up
/// to rotation (§14.2). `1.5,3,4,3` and `4,3,1.5,3` draw the same rhythm,
/// so they are one class.
@immutable
final class Pal1DashClass {
  const Pal1DashClass._(this.marks);

  /// Classifies a dash in permille-points. The EMPTY list is solid, as it
  /// is in `SignalFamilyDef.effectiveDashPattern`.
  ///
  /// Marks are the even indices; the odd ones are gaps and carry no class.
  /// Of the rotations, the one kept is the least when each mark is read as
  /// its NAME, which is the canonical form the Python printed. Any fixed
  /// choice would compare correctly; this one also prints identically.
  factory Pal1DashClass.of(List<int> dashPermille) {
    if (dashPermille.isEmpty) return solid;
    final marks = [
      for (var i = 0; i < dashPermille.length; i += 2)
        pal1MarkOf(dashPermille[i]),
    ];
    List<Pal1Mark>? best;
    for (var r = 0; r < marks.length; r++) {
      final rotated = [...marks.skip(r), ...marks.take(r)];
      if (best == null || _compareByName(rotated, best) < 0) best = rotated;
    }
    return Pal1DashClass._(List.unmodifiable(best!));
  }

  /// The solid line, which is a class of its own.
  static const solid = Pal1DashClass._([]);

  /// The canonical rotation's marks. Empty for [solid].
  final List<Pal1Mark> marks;

  bool get isSolid => marks.isEmpty;

  static int _compareByName(List<Pal1Mark> a, List<Pal1Mark> b) {
    for (var i = 0; i < a.length; i++) {
      final c = a[i].name.compareTo(b[i].name);
      if (c != 0) return c;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is Pal1DashClass && _markEquality.equals(marks, other.marks);

  @override
  int get hashCode => _markEquality.hash(marks);

  /// `solid`, or the marks joined by `/`: `short/dot`.
  @override
  String toString() => isSolid ? 'solid' : marks.map((m) => m.name).join('/');
}

/// One period of [dashPermille], or `null` for solid, which has none.
int? pal1PeriodPermille(List<int> dashPermille) =>
    dashPermille.isEmpty ? null : dashPermille.sum;

/// A family as PAL-1 sees it: the rendered triple's inputs.
///
/// Every value is EFFECTIVE, "after any per-family override, not the
/// domain base value" (§14.1). [Pal1Entry.of] resolves them through the
/// same accessors the renderer uses, so the rule is checked against what
/// is drawn rather than what is stored.
@immutable
final class Pal1Entry {
  Pal1Entry({
    required this.familyId,
    required this.domainId,
    required this.hue,
    required List<int> dashPermille,
    required this.weightPermille,
    double? luminance,
  }) : dashPermille = List.unmodifiable(dashPermille),
       luminance = luminance ?? relativeLuminance(hue.argb);

  /// [family] resolved against its [domain], at the light theme's hue,
  /// which is the print theme and the one §14 tabulates.
  factory Pal1Entry.of(SignalFamilyDef family, SignalDomainDef domain) =>
      Pal1Entry(
        familyId: family.id,
        domainId: domain.id,
        hue: domain.color,
        dashPermille: family.effectiveDashPattern(domain),
        weightPermille: family.effectiveLineWeightPermille(domain),
      );

  final SignalFamilyId familyId;
  final SignalDomainId domainId;
  final Rgb hue;

  /// Permille-points. Empty is solid.
  final List<int> dashPermille;

  /// Permille of the base signal weight: `1000` is 1×.
  final int weightPermille;

  /// The lightness this family is SEEN at: WCAG relative luminance of
  /// [hue], through `contrast.dart`, which is the product's one
  /// definition of it (DR-080 §11.79.4).
  ///
  /// A caller may supply it instead. `tools/legend_cvd_check.py` asks
  /// PAL-1's question of the lightness a colour-vision deficiency leaves
  /// (AC-054, M6-J1), and passing that number in is how it asks without
  /// keeping a second copy of the rule. Nothing in the product does.
  final double luminance;

  Pal1DashClass get dashClass => Pal1DashClass.of(dashPermille);

  int? get periodPermille => pal1PeriodPermille(dashPermille);
}

/// Every family in [registries] whose domain resolves, sorted by id.
///
/// A family whose domain is missing has no hue to be legible in and is
/// left out rather than guessed at (G4). The sort is what makes the order
/// of [pal1Violations] a property of the registries rather than of a
/// map's insertion history.
List<Pal1Entry> pal1EntriesOf(Registries registries) {
  final out = <Pal1Entry>[];
  for (final family in registries.signalFamilies.values) {
    final domain = registries.signalDomains[family.domain];
    if (domain != null) out.add(Pal1Entry.of(family, domain));
  }
  return out..sort((a, b) => a.familyId.v.compareTo(b.familyId.v));
}

/// The cross-domain limbs of §14.1 for one pair, each answered on its own.
///
/// Separate fields rather than one boolean because an editor has to say
/// WHY a choice is refused, and because the differential test compares
/// the limbs: a pair can be in band and still clear.
@immutable
final class Pal1PairVerdict {
  const Pal1PairVerdict({
    required this.inBand,
    required this.sameDashClass,
    required this.weightRescues,
  });

  /// `|L₁ − L₂| < 0.10`.
  final bool inBand;

  /// Limb (a) FAILS: the two dash classes are equal.
  final bool sameDashClass;

  /// Limb (b) HOLDS: the weights differ by a factor of at least 1.4.
  final bool weightRescues;

  /// In band, sharing a dash class, and not rescued by weight.
  bool get collides => inBand && sameDashClass && !weightRescues;
}

/// §14.1's cross-domain test for [a] and [b].
///
/// It does not look at the domains. The rule applies it only to families
/// in DIFFERENT domains, and [pal1Violations] is where that is decided,
/// as a domain-equality check rather than an allowlist (§14.5).
Pal1PairVerdict pal1Pair(Pal1Entry a, Pal1Entry b) {
  final hi = a.weightPermille > b.weightPermille
      ? a.weightPermille
      : b.weightPermille;
  final lo = a.weightPermille > b.weightPermille
      ? b.weightPermille
      : a.weightPermille;
  return Pal1PairVerdict(
    inBand: (a.luminance - b.luminance).abs() < kPal1LuminanceBand,
    sameDashClass: a.dashClass == b.dashClass,
    weightRescues: hi * 1000 >= kPal1WeightRatioPermille * lo,
  );
}

/// One way a palette fails PAL-1. Each names the family or families
/// involved, because "that combination is taken" without saying by what
/// leaves a person guessing (SFE-B2).
sealed class Pal1Violation {
  const Pal1Violation();

  /// The families involved, in the order the check met them.
  List<SignalFamilyId> get familyIds;
}

/// Two families in different domains, in band, sharing a dash class at
/// a weight ratio under 1.4: in greyscale they are the same line.
final class Pal1CrossDomainCollision extends Pal1Violation {
  const Pal1CrossDomainCollision(this.a, this.b);

  final Pal1Entry a;
  final Pal1Entry b;

  @override
  List<SignalFamilyId> get familyIds => [a.familyId, b.familyId];
}

/// Two families in one domain with the same dash AND the same weight.
/// They share a hue by construction, so nothing tells them apart.
final class Pal1WithinDomainDuplicate extends Pal1Violation {
  const Pal1WithinDomainDuplicate(this.a, this.b);

  final Pal1Entry a;
  final Pal1Entry b;

  @override
  List<SignalFamilyId> get familyIds => [a.familyId, b.familyId];
}

/// A dash whose period is under the 4.5 pt floor (§14.4).
final class Pal1PeriodBelowFloor extends Pal1Violation {
  const Pal1PeriodBelowFloor(this.entry);

  final Pal1Entry entry;

  @override
  List<SignalFamilyId> get familyIds => [entry.familyId];
}

const _dashEquality = ListEquality<int>();

/// Every PAL-1 violation among [entries], in the order the gate has
/// always reported them: cross-domain pairs, then within-domain
/// duplicates, then period floors. Empty means the palette is legible.
List<Pal1Violation> pal1Violations(List<Pal1Entry> entries) {
  final out = <Pal1Violation>[];
  for (var i = 0; i < entries.length; i++) {
    for (var j = i + 1; j < entries.length; j++) {
      final a = entries[i];
      final b = entries[j];
      if (a.domainId == b.domainId) continue;
      if (pal1Pair(a, b).collides) out.add(Pal1CrossDomainCollision(a, b));
    }
  }
  // Each entry is compared with the LATEST earlier entry carrying its
  // key, so three identical families report as two adjacent pairs rather
  // than three, which is how the gate has always counted them.
  final seen = <Pal1Entry>[];
  for (final e in entries) {
    final twin = seen.lastWhereOrNull(
      (s) =>
          s.domainId == e.domainId &&
          s.weightPermille == e.weightPermille &&
          _dashEquality.equals(s.dashPermille, e.dashPermille),
    );
    if (twin != null) out.add(Pal1WithinDomainDuplicate(twin, e));
    seen.add(e);
  }
  for (final e in entries) {
    final p = e.periodPermille;
    if (p != null && p < kPal1PeriodFloorPermille) {
      out.add(Pal1PeriodBelowFloor(e));
    }
  }
  return out;
}

// ═════════════════════════════════════════════════════════════════════
// HEADROOM: WHAT AN EDITOR NEEDS AND THE GATE NEVER DID (SFE-A3)
// ═════════════════════════════════════════════════════════════════════
// The gate answers yes or no about a palette that already exists. A
// person cloning a family has to be told what is still available BEFORE
// they choose, and why each refused option is refused. So the question
// turns around: given everything already drawn, which dash and weight
// would a NEW family in this domain be allowed to take?

/// The violations [candidate] would ADD to [palette], and no others.
///
/// A violation already present among [palette] is not the candidate's
/// fault and is not reported. An entry carrying the candidate's own id
/// is skipped, so a family can be re-checked against the palette it is
/// already part of. Each violation names the family it collides with,
/// which is what SFE-B2's refusal prints.
List<Pal1Violation> pal1ViolationsOf(
  Pal1Entry candidate,
  Iterable<Pal1Entry> palette,
) {
  final out = <Pal1Violation>[];
  final others = [
    for (final e in palette)
      if (e.familyId != candidate.familyId) e,
  ];
  for (final e in others) {
    if (e.domainId == candidate.domainId) continue;
    if (pal1Pair(e, candidate).collides) {
      out.add(Pal1CrossDomainCollision(e, candidate));
    }
  }
  for (final e in others) {
    if (e.domainId == candidate.domainId &&
        e.weightPermille == candidate.weightPermille &&
        _dashEquality.equals(e.dashPermille, candidate.dashPermille)) {
      out.add(Pal1WithinDomainDuplicate(e, candidate));
    }
  }
  final p = candidate.periodPermille;
  if (p != null && p < kPal1PeriodFloorPermille) {
    out.add(Pal1PeriodBelowFloor(candidate));
  }
  return out;
}

/// The dashes and weights a clone may choose from (DR-243 §11.242.1).
@immutable
final class Pal1Vocabulary {
  Pal1Vocabulary({
    required List<List<int>> dashes,
    required List<int> weights,
  }) : dashes = List.unmodifiable([
         for (final d in dashes) List<int>.unmodifiable(d),
       ]),
       weights = List.unmodifiable(weights);

  /// One pattern per dash class, in permille-points; the empty list is
  /// solid.
  final List<List<int>> dashes;

  /// Permille of the base signal weight, ascending.
  final List<int> weights;
}

/// DR-243's menu, derived from [palette]: one dash per class the palette
/// draws, crossed with every weight it uses.
///
/// DERIVED, NOT LISTED, so it cannot drift from the palette
/// `registry_parity.py` holds to `pal1_check.py`. Pass the SHIPPED
/// palette (`pal1EntriesOf(buildSeedRegistries())`) so a document's own
/// clones cannot reshape the menu.
///
/// A class stands for itself through the pattern the most families use,
/// ties to the smallest permille list: the one an installer is likeliest
/// to have already seen in this product. Classes come solid first, then
/// by mark count, then by name, so the menu reads simplest first.
Pal1Vocabulary pal1ClassVocabulary(Iterable<Pal1Entry> palette) {
  final uses = <String, (List<int>, int)>{};
  for (final e in palette) {
    final key = e.dashPermille.join(',');
    final prior = uses[key];
    uses[key] = (e.dashPermille, (prior?.$2 ?? 0) + 1);
  }
  final best = <Pal1DashClass, (List<int>, int)>{};
  for (final (dash, n) in uses.values) {
    final c = Pal1DashClass.of(dash);
    final held = best[c];
    if (held == null ||
        n > held.$2 ||
        (n == held.$2 && _compareInts(dash, held.$1) < 0)) {
      best[c] = (dash, n);
    }
  }
  final classes = best.keys.toList()
    ..sort((a, b) {
      final byLength = a.marks.length.compareTo(b.marks.length);
      return byLength != 0 ? byLength : '$a'.compareTo('$b');
    });
  return Pal1Vocabulary(
    dashes: [for (final c in classes) best[c]!.$1],
    weights: {for (final e in palette) e.weightPermille}.toList()..sort(),
  );
}

int _compareInts(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final c = a[i].compareTo(b[i]);
    if (c != 0) return c;
  }
  return a.length.compareTo(b.length);
}

/// One dash and weight a clone could take, and what refuses it.
@immutable
final class Pal1Option {
  Pal1Option({
    required List<int> dashPermille,
    required this.weightPermille,
    required List<Pal1Violation> blockers,
  }) : dashPermille = List.unmodifiable(dashPermille),
       blockers = List.unmodifiable(blockers);

  final List<int> dashPermille;
  final int weightPermille;

  /// Every violation this option would add. Empty means free.
  final List<Pal1Violation> blockers;

  bool get isFree => blockers.isEmpty;

  Pal1DashClass get dashClass => Pal1DashClass.of(dashPermille);
}

/// What remains for a new family in one domain.
@immutable
final class Pal1Headroom {
  Pal1Headroom({required this.domainId, required List<Pal1Option> options})
    : options = List.unmodifiable(options);

  final SignalDomainId domainId;

  /// Every option in the vocabulary, free or not, in vocabulary order:
  /// dash-major, then weight. An editor draws the refused ones too, with
  /// their reason, rather than hiding them.
  final List<Pal1Option> options;

  Iterable<Pal1Option> get free => options.where((o) => o.isFree);

  /// NONE LEFT, as a state of its own. An empty [free] reached by
  /// iterating would read as a bug in the caller; this reads as an answer.
  bool get isExhausted => !options.any((o) => o.isFree);
}

/// The headroom a new family in [domain] has against [palette], over
/// [vocabulary] (SFE-A3).
///
/// [palette] is everything already drawn: the shipped families AND any
/// clones the document holds, since a clone collides with a clone as
/// surely as with a shipped family.
Pal1Headroom pal1Headroom({
  required Iterable<Pal1Entry> palette,
  required SignalDomainDef domain,
  required Pal1Vocabulary vocabulary,
}) {
  final drawn = palette.toList();
  // An id no registry key can take: `SignalFamilyId`s are dotted
  // lower-case, so this cannot shadow a real family and be skipped.
  const probe = SignalFamilyId(' headroom candidate ');
  return Pal1Headroom(
    domainId: domain.id,
    options: [
      for (final dash in vocabulary.dashes)
        for (final weight in vocabulary.weights)
          Pal1Option(
            dashPermille: dash,
            weightPermille: weight,
            blockers: pal1ViolationsOf(
              Pal1Entry(
                familyId: probe,
                domainId: domain.id,
                hue: domain.color,
                dashPermille: dash,
                weightPermille: weight,
              ),
              drawn,
            ),
          ),
    ],
  );
}
