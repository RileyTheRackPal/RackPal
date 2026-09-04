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
    expect(kRuleCatalogue, hasLength(28));
  });
}
