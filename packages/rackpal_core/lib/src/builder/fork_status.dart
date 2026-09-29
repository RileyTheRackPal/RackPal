// CR-062's passive stale-fork badge, as a rule rather than as a widget.
// Board #198, M4-C/3. The fourth status and the withheld version number
// are DR-058 (canon §11.57), which this file carries because it is where
// the next implementer will be standing.
//
// THE RULING, and the consequence it exists to surface. Seeded templates
// are read-only, so editing one silently performs Duplicate-then-edit. The
// consequence no document surfaced before CR-062 is that a user who
// corrects a wrong wattage forks the template and PERMANENTLY LOSES
// catalog corrections for that device. The answer is not to forbid the
// fork; it is to remember what it came from (`TemplateBody.derivedFrom`,
// M4-C/1) and to say so quietly when the source moves on:
//
//   "Based on catalog 'HDMI Matrix 8x8' v1, the catalog version has since
//    been corrected (v3). Compare..."
//
// NO ACTION IS FORCED. That is the ruling's own sentence and it is the
// design: nothing here returns a prompt, a migration or a to-do. It
// returns a fact about two version numbers, and the surface that reads it
// is expected to be quiet about it.
//
// ─────────────────────────────────────────────────────────────────────
// NO WIDGET SHIPS WITH THIS FILE, and the reason is sequencing rather
// than shyness. What M4-C owes is the RULE, which is the part that needs
// deciding; the badge is a `Row` once the rule is right. Recorded here
// rather than left to be discovered, per
// `a modelled field is not a reachable one`.
//
// THE SEQUENCING HALF OF THAT PARAGRAPH IS NOW HALF FALSE, and it is
// corrected rather than deleted because the correction is the useful
// part. It used to read "nothing forks yet: the palette lists only
// `buildSeedCatalog()` -- 50 templates, all version 1, none of them a
// fork". Since M4-S (DR-077 §11.76) the palette lists the DOCUMENT'S
// shelf, and a second `Save` in one builder session forks `version + 1`
// rather than minting a second id, so **a document can now hold several
// versions of one template and this file has a producer for the first
// time.** What is still true is the rest: `Duplicate & edit` from a
// catalog card is M4-O's, so nothing writes a `derivedFrom` yet, and the
// library directory service that would hold a second shelf is M4-N's. So
// the badge has a producer and still no fork to badge.
// ─────────────────────────────────────────────────────────────────────
//
// WHERE THE VERSIONS COME FROM IS THE CALLER'S PROBLEM, deliberately. The
// only shelf that exists today is a document's own `templates` map, keyed
// `"$templateId@$version"`, which is why [latestTemplateVersions] is here.
// A library, the seeded catalog and a fetched community pack (DR-034) are
// three more, and they arrive over three different milestones. Taking a
// plain map means this file never learns about any of them, and a caller
// that can see two shelves passes their union.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart' show TemplateId;

/// What comparing a template against the source it was forked from
/// produced.
enum ForkStatus {
  /// Not a fork. `derivedFrom` is absent, which per CR-114 is what an
  /// original template's file says by saying nothing.
  original,

  /// A fork whose source is still at the version it was taken from.
  /// Nothing to show.
  current,

  /// A fork whose source has been revised since. **This is the only
  /// value that badges** (CR-062).
  superseded,

  /// A fork whose source this installation cannot compare against: no
  /// shelf in view holds that template id, or none holds the version the
  /// fork claims to have come from.
  ///
  /// **UNKNOWN, and never [current]** (G4, CR-114). The temptation is to
  /// treat "we did not find a newer version" as "there is no newer
  /// version", which is the same fabrication as printing a total that
  /// silently skips its unknowns. A project opened on a second machine
  /// reaches this state routinely and legitimately.
  sourceUnknown,
}

/// One template's answer, with the two numbers a badge needs to print.
@immutable
final class ForkResolution {
  const ForkResolution({
    required this.status,
    this.origin,
    this.currentSourceVersion,
  });

  final ForkStatus status;

  /// What the fork recorded, or null when [status] is
  /// [ForkStatus.original].
  final TemplateOrigin? origin;

  /// The newest version of the source any shelf in view holds. Null
  /// unless [status] is [ForkStatus.superseded] or [ForkStatus.current] —
  /// on [ForkStatus.sourceUnknown] it is deliberately absent rather than
  /// reporting whatever stale number happened to be found, because a
  /// badge printing "(v1)" beside "forked from v3" is worse than no
  /// badge.
  final int? currentSourceVersion;

  /// Whether CR-062's badge shows. One property rather than a comparison
  /// spelled at every call site, because the answer is not
  /// `status != current`: [ForkStatus.sourceUnknown] must not badge.
  bool get showsStaleBadge => status == ForkStatus.superseded;

  @override
  bool operator ==(Object other) =>
      other is ForkResolution &&
      other.status == status &&
      other.origin == origin &&
      other.currentSourceVersion == currentSourceVersion;

  @override
  int get hashCode => Object.hash(status, origin, currentSourceVersion);

  @override
  String toString() =>
      'ForkResolution(${status.name}'
      '${origin == null ? '' : ', from $origin'}'
      '${currentSourceVersion == null ? '' : ', source now '
                'v$currentSourceVersion'})';
}

/// Resolves one [body] against the newest version of each template
/// [sourceVersions] can see.
///
/// [sourceVersions] is the union of every shelf the caller can reach; see
/// [latestTemplateVersions] for building it from a document. An id absent
/// from it is not evidence of anything, and answers
/// [ForkStatus.sourceUnknown].
ForkResolution resolveForkStatus(
  TemplateBody body, {
  required Map<TemplateId, int> sourceVersions,
}) {
  final origin = body.derivedFrom;
  if (origin == null) return const ForkResolution(status: ForkStatus.original);

  final visible = sourceVersions[origin.templateId];
  if (visible == null) {
    return ForkResolution(status: ForkStatus.sourceUnknown, origin: origin);
  }
  // A shelf holding only a version OLDER than the one forked from cannot
  // answer CR-062's question either. It is a stale or partial shelf, not
  // proof that nothing was corrected, so it reads as unknown rather than
  // as current — and the number is withheld with it, because printing
  // "the catalog is at v1" beside "you forked v3" invites exactly the
  // wrong conclusion.
  if (visible < origin.version) {
    return ForkResolution(status: ForkStatus.sourceUnknown, origin: origin);
  }
  return ForkResolution(
    status: visible > origin.version
        ? ForkStatus.superseded
        : ForkStatus.current,
    origin: origin,
    currentSourceVersion: visible,
  );
}

/// Every fork in a set of templates, resolved, with its unknowns counted.
///
/// **The count is the point** (G4): the user's ruling on 2026-08-14 was
/// that a fork whose source cannot be seen shows NO badge on the device
/// and IS reported here, so the silence is visible somewhere rather than
/// nowhere. A rollup that omitted [uncheckable] would be a rollup
/// fabricating a total, which this model forbids everywhere else.
@immutable
final class ForkAudit {
  const ForkAudit(this.resolutions);

  /// Keyed exactly as the caller's input was, so a surface can map an
  /// answer back to the row it belongs on.
  final Map<String, ForkResolution> resolutions;

  /// The forks whose source has moved on. These badge.
  Iterable<MapEntry<String, ForkResolution>> get superseded =>
      resolutions.entries.where((e) => e.value.showsStaleBadge);

  /// The forks that could not be checked at all. These do NOT badge, and
  /// they are counted here instead.
  Iterable<MapEntry<String, ForkResolution>> get uncheckable => resolutions
      .entries
      .where((e) => e.value.status == ForkStatus.sourceUnknown);

  int get supersededCount => superseded.length;
  int get uncheckableCount => uncheckable.length;

  /// How many of [resolutions] are forks at all, checkable or not.
  int get forkCount =>
      resolutions.values.where((r) => r.status != ForkStatus.original).length;
}

/// Resolves every entry of [templates] (see [resolveForkStatus]).
///
/// Only tests call this (#945): it is a handle on live logic, not logic of its
/// own, so it stays and the analyzer keeps it out of lib/.
@visibleForTesting
ForkAudit auditForks(
  Map<String, TemplateBody> templates, {
  required Map<TemplateId, int> sourceVersions,
}) => ForkAudit({
  for (final e in templates.entries)
    e.key: resolveForkStatus(e.value, sourceVersions: sourceVersions),
});

/// The newest version of each template id present in [snapshots], which
/// is the shelf a `RackDocument.templates` map represents.
///
/// A document holds `"$templateId@$version"` keys and may legitimately
/// carry several versions of one template at once (CR-050: every version
/// stays resolvable). The newest is what CR-062 compares against, because
/// "the source has since been corrected" is a claim about the latest
/// correction and not about whichever one happens to iterate first.
Map<TemplateId, int> latestTemplateVersions(
  Map<String, TemplateSnapshot> snapshots,
) {
  final latest = <TemplateId, int>{};
  for (final s in snapshots.values) {
    final seen = latest[s.templateId];
    if (seen == null || s.version > seen) latest[s.templateId] = s.version;
  }
  return latest;
}
