// The AC-051 coverage gate (`#302`, M5-G4).
//
// THE SUBJECT IS THE CATALOGUE, NOT AN ENUM. See `drc_corpus.dart`.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'fixtures/drc_corpus.dart';
import 'fixtures/drc_fixture.dart';

void main() {
  test('EVERY catalogue rule has both halves of its AC-051 pair', () {
    final gaps = corpusGaps();
    expect(
      gaps,
      isEmpty,
      reason:
          'rules missing a half:\n'
          '${gaps.entries.map((e) => '  ${e.key}: needs '
              '${e.value.map((k) => k.name).join(" and ")}').join('\n')}',
    );
  });

  test('every fixture holds its own contract', () {
    final broken = [
      for (final f in drcCorpus())
        if (violationOf(f) case final String why) why,
    ];
    expect(broken, isEmpty, reason: broken.join('\n'));
  });

  test('the corpus is not vacuous', () {
    // A corpus that walked nothing would report no gaps and pass.
    expect(drcCorpus().length, greaterThan(20));
    expect(kRuleCatalogue, hasLength(30));
  });

  /// DR-154 §11.153.4. The gate reports per band, so a failure names the
  /// catalogue it is about, and the plan band's count moves on its own.
  test('the plan band is gated too, and separately', () {
    expect(corpusGapsIn(kPlanRules), isEmpty);
    expect(
      kPlanRules,
      hasLength(4),
      reason: 'docs/15 §9 gives four advisories',
    );
    expect(
      corpusCoverage().keys.where((id) => id.startsWith('PLN-')),
      hasLength(4),
      reason: 'a band gated by a loop over an EMPTY band passes silently',
    );
  });
}
