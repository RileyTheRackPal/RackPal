// Which `JacketListing` may stand in for which. DR-079 §11.78.2, board
// `#743`.
//
// ═══════════════════════════════════════════════════════════════════════
// A TABLE, BECAUSE THE ALTERNATIVE FAILS CORRECT WORK
// ═══════════════════════════════════════════════════════════════════════
// NEC permits a higher listing wherever a lower one is required: CMP is
// acceptable in a riser, CL3P where CL2P is required, OFNP where OFNR is.
// A rule checking only for an EXACT match would fail a correctly-specified
// plenum cable in a riser, which is the same false positive DR-079 exists
// to stop, arriving from the other direction.
//
// It is data rather than a chain of `if`s on CR-024's own distinction: a
// genuine lookup table stays data while a rule stays a Dart function. The
// fixture pairs M5 owes (AC-051, a known-bad and a known-good near-miss
// per rule) are written against this table rather than against a rule's
// internals.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ARTICLE BOUNDARY IS THE CLAUSE THAT WILL BE GOT WRONG
// ═══════════════════════════════════════════════════════════════════════
// A fibre listing does not substitute for a communications one. They are
// different articles, tested differently, for different failure modes, and
// a rule that treated `OFNP` as satisfying a `CMP` requirement would be
// confidently wrong about somebody's plenum.
//
// So [substitutesFor] answers **three** ways, not two: yes, no, and
// **UNKNOWN when the two listings are from different articles** (G4). A
// rule must be able to say *"this cable's listing is from another article
// and I cannot judge it"*, because that is the true answer, and because
// the alternative is the false failure this file exists to prevent.
//
// ═══════════════════════════════════════════════════════════════════════
// `OFN` AND `OFC` ARE TWO FAMILIES INSIDE ONE ARTICLE
// ═══════════════════════════════════════════════════════════════════════
// Nonconductive and conductive optical fibre are both Art. 770 and do NOT
// substitute for each other in the conductive direction: a conductive
// cable carries a metallic member and cannot stand in where a
// nonconductive one is required. The rank alone cannot express that, so
// the family is part of the key.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS IS NOT
// ═══════════════════════════════════════════════════════════════════════
// It is not a statement that a substitution is a good idea, only that the
// code permits it. It is not the whole of 800.154: the article's own table
// also permits substitutions ACROSS articles in specific directions, and
// those are deliberately not encoded, because each needs its own citation
// and this file would rather answer UNKNOWN than guess one. And it decides
// no severity: DR-079 §11.78.3 makes both code rules warnings that name
// what to verify, and this table is what they consult before they do.
import 'package:rackpal_core/src/model/link.dart';

/// The NEC article a listing is tested and listed under.
///
/// PART OF THE FACT rather than a comment on it: `cmp` and `cl3p` are both
/// plenum and are not interchangeable.
enum JacketArticle {
  /// Art. 800 / 805, communications.
  communications,

  /// Art. 725, Class 2 and Class 3 power-limited circuits.
  classTwoThree,

  /// Art. 760, power-limited fire alarm.
  fireAlarm,

  /// Art. 770, optical fibre.
  opticalFibre,

  /// Art. 820, community antenna television and radio distribution.
  coax,
}

/// Where a listing may be installed, ascending. The substitution rank.
///
/// **ASCENDING IS THE WHOLE MECHANISM**: a listing may stand in for any
/// requirement at or below its own rank, within its own family.
enum JacketUse {
  /// Limited use / dwelling (`X` suffix). The most restricted.
  limited,

  /// General purpose, no suffix.
  general,

  /// General purpose with the `G` suffix, which Art. 770 uses where the
  /// other articles use no suffix at all.
  generalSuffixed,

  /// Riser (`R`).
  riser,

  /// Plenum (`P`). The least restricted.
  plenum,
}

/// One listing's classification.
typedef JacketClassification = ({
  JacketArticle article,

  /// The family within the article. `OFN` and `OFC` are two families of
  /// Art. 770 and do not substitute across; every other article has one.
  String family,
  JacketUse use,
});

/// What [listing] is, for substitution purposes.
///
/// EXHAUSTIVE ON PURPOSE. A `switch` over the enum means adding a value
/// without classifying it does not compile, which is the one way this
/// table can be kept honest as the vocabulary grows.
JacketClassification classifyJacketListing(JacketListing listing) =>
    switch (listing) {
      JacketListing.cmx => (
        article: JacketArticle.communications,
        family: 'CM',
        use: JacketUse.limited,
      ),
      JacketListing.cm => (
        article: JacketArticle.communications,
        family: 'CM',
        use: JacketUse.general,
      ),
      JacketListing.cmg => (
        article: JacketArticle.communications,
        family: 'CM',
        use: JacketUse.generalSuffixed,
      ),
      JacketListing.cmr => (
        article: JacketArticle.communications,
        family: 'CM',
        use: JacketUse.riser,
      ),
      JacketListing.cmp => (
        article: JacketArticle.communications,
        family: 'CM',
        use: JacketUse.plenum,
      ),

      JacketListing.cl2x => (
        article: JacketArticle.classTwoThree,
        family: 'CL2',
        use: JacketUse.limited,
      ),
      JacketListing.cl2 => (
        article: JacketArticle.classTwoThree,
        family: 'CL2',
        use: JacketUse.general,
      ),
      JacketListing.cl2r => (
        article: JacketArticle.classTwoThree,
        family: 'CL2',
        use: JacketUse.riser,
      ),
      JacketListing.cl2p => (
        article: JacketArticle.classTwoThree,
        family: 'CL2',
        use: JacketUse.plenum,
      ),
      JacketListing.cl3x => (
        article: JacketArticle.classTwoThree,
        family: 'CL3',
        use: JacketUse.limited,
      ),
      JacketListing.cl3 => (
        article: JacketArticle.classTwoThree,
        family: 'CL3',
        use: JacketUse.general,
      ),
      JacketListing.cl3r => (
        article: JacketArticle.classTwoThree,
        family: 'CL3',
        use: JacketUse.riser,
      ),
      JacketListing.cl3p => (
        article: JacketArticle.classTwoThree,
        family: 'CL3',
        use: JacketUse.plenum,
      ),

      JacketListing.fpl => (
        article: JacketArticle.fireAlarm,
        family: 'FPL',
        use: JacketUse.general,
      ),
      JacketListing.fplr => (
        article: JacketArticle.fireAlarm,
        family: 'FPL',
        use: JacketUse.riser,
      ),
      JacketListing.fplp => (
        article: JacketArticle.fireAlarm,
        family: 'FPL',
        use: JacketUse.plenum,
      ),

      JacketListing.ofn => (
        article: JacketArticle.opticalFibre,
        family: 'OFN',
        use: JacketUse.general,
      ),
      JacketListing.ofng => (
        article: JacketArticle.opticalFibre,
        family: 'OFN',
        use: JacketUse.generalSuffixed,
      ),
      JacketListing.ofnr => (
        article: JacketArticle.opticalFibre,
        family: 'OFN',
        use: JacketUse.riser,
      ),
      JacketListing.ofnp => (
        article: JacketArticle.opticalFibre,
        family: 'OFN',
        use: JacketUse.plenum,
      ),
      JacketListing.ofc => (
        article: JacketArticle.opticalFibre,
        family: 'OFC',
        use: JacketUse.general,
      ),
      JacketListing.ofcg => (
        article: JacketArticle.opticalFibre,
        family: 'OFC',
        use: JacketUse.generalSuffixed,
      ),
      JacketListing.ofcr => (
        article: JacketArticle.opticalFibre,
        family: 'OFC',
        use: JacketUse.riser,
      ),
      JacketListing.ofcp => (
        article: JacketArticle.opticalFibre,
        family: 'OFC',
        use: JacketUse.plenum,
      ),

      JacketListing.catvx => (
        article: JacketArticle.coax,
        family: 'CATV',
        use: JacketUse.limited,
      ),
      JacketListing.catv => (
        article: JacketArticle.coax,
        family: 'CATV',
        use: JacketUse.general,
      ),
      JacketListing.catvr => (
        article: JacketArticle.coax,
        family: 'CATV',
        use: JacketUse.riser,
      ),
      JacketListing.catvp => (
        article: JacketArticle.coax,
        family: 'CATV',
        use: JacketUse.plenum,
      ),
    };

/// Whether [candidate] may be installed where [required_] is required.
///
/// **THREE ANSWERS, AND THE THIRD IS THE POINT.** `null` means the two are
/// from different articles and this table declines to judge (G4). A caller
/// that treats a null as a `false` reintroduces the false failure this
/// file exists to prevent, and one that treats it as `true` reintroduces
/// the false pass DR-079 was raised over.
bool? substitutesFor(
  JacketListing candidate, {
  required JacketListing required_,
}) {
  final a = classifyJacketListing(candidate);
  final b = classifyJacketListing(required_);
  if (a.article != b.article) return null;
  // WITHIN ONE ARTICLE, ACROSS FAMILIES, THE ANSWER IS STILL SOMETIMES
  // NULL. `CL3` may stand in for `CL2` (Class 3 is the more demanding
  // listing and 725 permits the substitution), but `OFC` may not stand in
  // for `OFN`: a conductive cable carries a metallic member. So a
  // cross-family answer is only given where this file can cite a
  // direction, and is null otherwise.
  if (a.family != b.family) {
    final permitted = _crossFamily[(b.family, a.family)];
    if (permitted != true) return null;
  }
  return a.use.index >= b.use.index;
}

/// Cross-family substitutions this file is prepared to assert, keyed
/// `(required family, candidate family)`.
///
/// DELIBERATELY SHORT. Every entry is a direction somebody can cite; the
/// absence of an entry is `unknown` rather than `no`, so growing this map
/// never turns a previously correct answer into a wrong one.
const Map<(String, String), bool> _crossFamily = {
  // NEC 725: a Class 3 listing is the more demanding of the two and is
  // permitted where a Class 2 listing is required. Not the reverse.
  ('CL2', 'CL3'): true,
};

/// The plenum listing an article requires, for a rule that has a pathway
/// and needs to ask a question about it.
///
/// Null for an article this file has no plenum listing for, which cannot
/// happen today and is left as a real answer rather than an assertion.
JacketListing? plenumListingFor(JacketArticle article) => switch (article) {
  JacketArticle.communications => JacketListing.cmp,
  JacketArticle.classTwoThree => JacketListing.cl2p,
  JacketArticle.fireAlarm => JacketListing.fplp,
  JacketArticle.opticalFibre => JacketListing.ofnp,
  JacketArticle.coax => JacketListing.catvp,
};

/// Whether [listing] is rated for a plenum, judged inside its own article.
///
/// THE QUESTION `CODE-002` ACTUALLY ASKS. It never needs to compare two
/// articles, because the cable's own listing names the article it was
/// tested under; what it needs is whether that listing reaches plenum. So
/// this one has no unknown: every listing knows its own use.
bool isPlenumRated(JacketListing listing) =>
    classifyJacketListing(listing).use == JacketUse.plenum;

/// Whether [listing] is rated for a riser, judged inside its own article.
///
/// Plenum reaches riser, which is the substitution rule stated for the one
/// pair a pathway rule is likely to ask about.
bool isRiserRated(JacketListing listing) {
  final use = classifyJacketListing(listing).use;
  return use == JacketUse.riser || use == JacketUse.plenum;
}
