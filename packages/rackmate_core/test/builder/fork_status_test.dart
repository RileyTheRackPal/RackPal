// CR-062: a fork whose source has since been corrected shows a passive
// badge, and no action is forced. Board #198, M4-C/3.
//
// These assert the ARTIFACT the badge is drawn from: the status, the two
// version numbers, and the counted unknown. There is no widget test,
// because there is no widget: nothing forks yet (M4-D owns Duplicate) and
// no library holds one (M4-N owns the directory service). The rule is
// what M4-C owes.
//
// THE CASE WORTH READING TWICE is the last group. "We could not find a
// newer version" and "there is no newer version" are different answers,
// and a resolver that collapses them is the same defect as a rollup that
// prints a total by skipping its unknowns (G4, CR-114).
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

const _source = TemplateId('cat.video.v04');

TemplateBody _body({TemplateOrigin? derivedFrom}) => TemplateBody(
  manufacturer: 'Generic',
  model: 'MTX-8',
  displayName: 'HDMI Matrix 8x8',
  frontU: 4,
  derivedFrom: derivedFrom,
);

TemplateOrigin _from(int version) =>
    TemplateOrigin(templateId: _source, version: version);

TemplateSnapshot _snapshot(TemplateId id, int version) => TemplateSnapshot(
  templateId: id,
  version: version,
  contentHash: 'sha256:${id.v}@$version',
  body: _body(),
  capturedAt: DateTime.utc(2026, 8, 14),
);

void main() {
  group('a template that is not a fork', () {
    test('is original, whatever the shelf holds', () {
      final r = resolveForkStatus(
        _body(),
        sourceVersions: {_source: 9},
      );

      expect(r.status, ForkStatus.original);
      expect(r.origin, isNull);
      expect(r.showsStaleBadge, isFalse);
    });
  });

  group('a fork whose source is visible', () {
    test('is current while the source sits at the version it was taken '
        'from, and carries no badge', () {
      final r = resolveForkStatus(
        _body(derivedFrom: _from(1)),
        sourceVersions: {_source: 1},
      );

      expect(r.status, ForkStatus.current);
      expect(r.currentSourceVersion, 1);
      expect(r.showsStaleBadge, isFalse);
    });

    test('is superseded once the source is corrected, and reports BOTH '
        "numbers, because CR-062's badge prints both", () {
      final r = resolveForkStatus(
        _body(derivedFrom: _from(1)),
        sourceVersions: {_source: 3},
      );

      expect(r.status, ForkStatus.superseded);
      expect(r.origin, _from(1));
      expect(r.currentSourceVersion, 3);
      expect(r.showsStaleBadge, isTrue);
    });

    test('compares against the NEWEST version on the shelf, not against '
        'whichever one is encountered first', () {
      final doc = {
        'cat.video.v04@1': _snapshot(_source, 1),
        'cat.video.v04@3': _snapshot(_source, 3),
        'cat.video.v04@2': _snapshot(_source, 2),
      };

      expect(latestTemplateVersions(doc), {_source: 3});
    });
  });

  group('a fork whose source cannot be compared against', () {
    test('reads as UNKNOWN rather than as current when no shelf holds the '
        'id at all — the case of a project opened on a second machine', () {
      final r = resolveForkStatus(
        _body(derivedFrom: _from(1)),
        sourceVersions: const <TemplateId, int>{},
      );

      expect(r.status, ForkStatus.sourceUnknown);
      expect(r.origin, _from(1), reason: 'the fork still remembers');
      expect(r.showsStaleBadge, isFalse, reason: 'no action is forced');
    });

    test('reads as unknown when the shelf is OLDER than the fork claims, '
        'because a partial shelf is not evidence that nothing was '
        'corrected', () {
      final r = resolveForkStatus(
        _body(derivedFrom: _from(3)),
        sourceVersions: {_source: 1},
      );

      expect(r.status, ForkStatus.sourceUnknown);
    });

    test('withholds the version number it did find, so a badge cannot '
        'print "the catalog is at v1" beside "you forked v3"', () {
      final r = resolveForkStatus(
        _body(derivedFrom: _from(3)),
        sourceVersions: {_source: 1},
      );

      expect(r.currentSourceVersion, isNull);
    });

    test('is NOT the same value as current, which is the whole point', () {
      final unknown = resolveForkStatus(
        _body(derivedFrom: _from(1)),
        sourceVersions: const <TemplateId, int>{},
      );
      final current = resolveForkStatus(
        _body(derivedFrom: _from(1)),
        sourceVersions: {_source: 1},
      );

      expect(unknown.status, isNot(current.status));
    });
  });

  group('the rollup', () {
    final templates = {
      'original': _body(),
      'fresh': _body(derivedFrom: _from(2)),
      'stale-a': _body(derivedFrom: _from(1)),
      'stale-b': _body(derivedFrom: _from(1)),
      'lost': _body(
        derivedFrom: const TemplateOrigin(
          templateId: TemplateId('cat.gone'),
          version: 1,
        ),
      ),
    };

    test('badges only the superseded forks', () {
      final audit = auditForks(templates, sourceVersions: {_source: 2});

      expect(audit.superseded.map((e) => e.key), ['stale-a', 'stale-b']);
      expect(audit.supersededCount, 2);
    });

    test('COUNTS the fork it could not check rather than folding it into '
        'either answer (G4)', () {
      final audit = auditForks(templates, sourceVersions: {_source: 2});

      expect(audit.uncheckable.map((e) => e.key), ['lost']);
      expect(audit.uncheckableCount, 1);
    });

    test('counts every fork, checkable or not, so the two numbers above '
        'can be read against a whole', () {
      final audit = auditForks(templates, sourceVersions: {_source: 2});

      expect(audit.forkCount, 4);
      expect(audit.resolutions.length, 5);
    });

    test('keys its answers exactly as it was given them, so a surface can '
        'map a status back to the row it belongs on', () {
      final audit = auditForks(templates, sourceVersions: {_source: 2});

      expect(audit.resolutions.keys, templates.keys);
    });

    test('an empty shelf makes every fork uncheckable and none stale, '
        'which is the shape a report must be able to say', () {
      final audit = auditForks(templates, sourceVersions: const {});

      expect(audit.supersededCount, 0);
      expect(audit.uncheckableCount, 4);
    });
  });
}
