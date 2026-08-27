#!/usr/bin/env python3
"""Self-test for junit_from_dart_test.py. Runs in CI, before the suites.

WHY A TEST FOR A REPORTING SCRIPT. This repository has shipped a
frozen-clock timing test, a self-referential rendering assertion, a catalog
test asserting non-null over a 1000x unit error, and a production field
whose only writer was test code. A JUnit converter is in exactly that
family: its failure mode is a report that reads GREEN over a run that was
RED, and nothing downstream would notice, because the Tests tab is the
thing people look at instead of the log.

So the three clauses that exist to prevent that -- a failing hidden
"loading <path>" test being kept, a missing `done` event becoming a
synthetic failure, and `success:false` with no failing case becoming a
synthetic failure -- are asserted here, each with an accompanying assertion
that the CLEAN stream does NOT produce them. A one-sided assertion would
pass against a converter that emitted the synthetic failure unconditionally.

    python tools/ci/junit_converter_selftest.py       # exit 0 = clean

Every case parses the produced document with ElementTree, so "the XML is
well-formed" is measured rather than eyeballed -- an unparseable document
is reported by Azure DevOps as "no results", which looks like success.
"""
from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET

from junit_from_dart_test import build_xml, parse_events

FAILURES: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        FAILURES.append(message)


def convert(events: list[dict], prefix: str = 'suite') -> tuple[ET.Element, dict]:
    lines = [json.dumps(e) for e in events]
    document, totals = build_xml(parse_events(lines), prefix)
    try:
        root = ET.fromstring(document)
    except ET.ParseError as error:
        FAILURES.append(f'produced XML is not well-formed: {error}\n{document}')
        raise
    return root, totals


def suite_of(root: ET.Element) -> ET.Element:
    return root.find('testsuite')


def _start(**kwargs):
    test = {
        'id': kwargs['id'], 'name': kwargs['name'], 'suiteID': 0,
        'groupIDs': kwargs.get('groups', []),
        'metadata': {'skip': kwargs.get('skip', False),
                     'skipReason': kwargs.get('skip_reason')},
    }
    return {'type': 'testStart', 'test': test, 'time': kwargs.get('t', 0)}


def _done_test(test_id, result='success', hidden=False, skipped=False, t=10):
    return {'type': 'testDone', 'testID': test_id, 'result': result,
            'hidden': hidden, 'skipped': skipped, 'time': t}


SUITE = {'type': 'suite',
         'suite': {'id': 0, 'platform': 'vm',
                   'path': 'C:/repo/packages/rackpal_core/test/x_test.dart'}}
GROUP = {'type': 'group',
         'group': {'id': 2, 'suiteID': 0, 'parentID': None,
                   'name': 'CR-117 round trip', 'testCount': 1}}


def clean_stream() -> list[dict]:
    """A completely ordinary green run: one hidden load, one real test."""
    return [
        {'type': 'start', 'time': 0},
        SUITE,
        _start(id=1, name='loading x_test.dart'),
        _done_test(1, hidden=True),
        GROUP,
        _start(id=3, name='CR-117 round trip (a) empty project', groups=[2], t=5),
        _done_test(3, t=25),
        {'type': 'done', 'success': True, 'time': 30},
    ]


# ----------------------------------------------------------------------
# 1. A green run reports green, and reports NOTHING extra.
# ----------------------------------------------------------------------
root, totals = convert(clean_stream(), 'rackpal_core')
suite = suite_of(root)
cases = suite.findall('testcase')
check(len(cases) == 1, f'green run should yield 1 case, got {len(cases)}')
check(totals == {'tests': 1, 'failures': 0, 'errors': 0, 'skipped': 0},
      f'green run totals wrong: {totals}')
check(suite.get('failures') == '0' and suite.get('errors') == '0',
      'green run must not report failures or errors')
check(not cases[0].findall('failure') and not cases[0].findall('error'),
      'green case must carry no failure/error child')
check(cases[0].get('classname') == 'rackpal_core.test.x_test',
      f'classname wrong: {cases[0].get("classname")}')
# The doubling bug: the group name is already inside the test name.
check(cases[0].get('name') == 'CR-117 round trip (a) empty project',
      f'test name should not repeat the group prefix: {cases[0].get("name")}')
check(cases[0].get('time') == '0.020',
      f'duration should be end-start in seconds: {cases[0].get("time")}')

# ----------------------------------------------------------------------
# 2. A failing test is a <failure>, carrying the message and the stack.
# ----------------------------------------------------------------------
stream = clean_stream()
stream[6] = _done_test(3, result='failure', t=25)
stream.insert(7, {'type': 'error', 'testID': 3,
                  'error': 'Expected: <42>\n  Actual: <41>',
                  'stackTrace': 'x_test.dart 12:5'})
stream[-1] = {'type': 'done', 'success': False, 'time': 30}
root, totals = convert(stream)
cases = suite_of(root).findall('testcase')
check(len(cases) == 1 and len(cases[0].findall('failure')) == 1,
      'a failing test must produce exactly one <failure>')
check(totals['failures'] == 1, f'failure not counted: {totals}')
check('Actual: <41>' in (cases[0].find('failure').text or ''),
      'failure body must carry the assertion detail')
check('x_test.dart 12:5' in (cases[0].find('failure').text or ''),
      'failure body must carry the stack trace')
check('RUN REPORTED FAILURE' not in ET.tostring(root, encoding='unicode'),
      'an attributed failure must not also raise the unattributed synthetic')

# ----------------------------------------------------------------------
# 3. A SUITE THAT WOULD NOT COMPILE. The runner reports it as a hidden
#    "loading <path>" test with result error, and no visible test exists.
# ----------------------------------------------------------------------
stream = [
    {'type': 'start', 'time': 0},
    SUITE,
    _start(id=1, name='loading x_test.dart'),
    {'type': 'error', 'testID': 1,
     'error': "Error: The getter 'nope' isn't defined", 'stackTrace': ''},
    _done_test(1, result='error', hidden=True),
    {'type': 'done', 'success': False, 'time': 5},
]
root, totals = convert(stream)
cases = suite_of(root).findall('testcase')
check(len(cases) == 1, f'a load failure must be reported, got {len(cases)} cases')
check(totals['failures'] == 1, f'load failure not counted as a failure: {totals}')
check("isn't defined" in ET.tostring(root, encoding='unicode'),
      'the compile error text must survive into the report')

# ----------------------------------------------------------------------
# 4. THE RUNNER DIED. No `done` event at all.
# ----------------------------------------------------------------------
stream = clean_stream()[:-1]
root, totals = convert(stream)
text = ET.tostring(root, encoding='unicode')
check('RUNNER DID NOT FINISH' in text,
      'a truncated stream must produce a synthetic failure')
check(totals['errors'] == 1, f'truncated stream must count an error: {totals}')

# ----------------------------------------------------------------------
# 5. `done` SAYS FAILED AND NOTHING FAILED. Teardown/load-time error.
# ----------------------------------------------------------------------
stream = clean_stream()
stream[-1] = {'type': 'done', 'success': False, 'time': 30}
root, totals = convert(stream)
text = ET.tostring(root, encoding='unicode')
check('RUN REPORTED FAILURE WITH NO FAILING TEST' in text,
      'success:false with no failing case must produce a synthetic failure')
check(totals['errors'] == 1, f'unattributed failure must count: {totals}')

# ----------------------------------------------------------------------
# 5b. THE FLUTTER SHAPE. `flutter test` files a near-contentless `error`
#     ("Test failed. See exception logs above.") and puts the actual
#     expected/actual diff in `print` events. The diff must end up INSIDE
#     the <failure>, or a reviewer opens the failure and finds nothing.
#     Measured against a real flutter_test failure, not inferred.
# ----------------------------------------------------------------------
stream = clean_stream()
stream[6] = _done_test(3, result='failure', t=25)
stream.insert(7, {'type': 'error', 'testID': 3,
                  'error': 'Test failed. See exception logs above.',
                  'stackTrace': ''})
stream.insert(7, {'type': 'print', 'testID': 3, 'messageType': 'print',
                  'message': 'Expected: <41>\n  Actual: <42>'})
stream[-1] = {'type': 'done', 'success': False, 'time': 30}
root, totals = convert(stream)
case = suite_of(root).find('testcase')
check(case.find('failure') is not None, 'flutter-shaped failure must be a <failure>')
check('Actual: <42>' in (case.find('failure').text or ''),
      'the diff flutter puts in print events must land inside the <failure>')
check(case.find('system-out') is None,
      'prints folded into the failure must not be duplicated in system-out')

# ----------------------------------------------------------------------
# 6. A skipped test is <skipped>, not a failure and not silence.
# ----------------------------------------------------------------------
stream = clean_stream()
stream[6] = _done_test(3, skipped=True, t=25)
root, totals = convert(stream)
cases = suite_of(root).findall('testcase')
check(len(cases[0].findall('skipped')) == 1, 'skipped test must be marked')
check(totals['skipped'] == 1 and totals['failures'] == 0,
      f'skip counted wrong: {totals}')

# ...and a RUNTIME markTestSkipped reports its reason only as a print event,
# so system-out must survive for a test that did not fail.
stream = clean_stream()
stream[6] = _done_test(3, skipped=True, t=25)
stream.insert(6, {'type': 'print', 'testID': 3, 'messageType': 'skip',
                  'message': 'git could not be run'})
root, totals = convert(stream)
case = suite_of(root).find('testcase')
check(case.find('system-out') is not None and
      'git could not be run' in (case.find('system-out').text or ''),
      'the reason for a runtime skip must survive into system-out')

# ----------------------------------------------------------------------
# 7. CONTROL CHARACTERS. An ANSI-coloured diff carries ESC (0x1B), which
#    XML 1.0 cannot represent at all -- not even escaped. One of them makes
#    the whole document unparseable, and Azure DevOps renders an
#    unparseable results file as "no results", which reads like success.
# ----------------------------------------------------------------------
stream = clean_stream()
stream[6] = _done_test(3, result='failure', t=25)
stream.insert(7, {'type': 'error', 'testID': 3,
                  'error': 'Expected: \x1b[32m<42>\x1b[0m \x00 & <tag>',
                  'stackTrace': ''})
stream[-1] = {'type': 'done', 'success': False, 'time': 30}
root, totals = convert(stream)          # parses, or `convert` records it
body = suite_of(root).find('testcase').find('failure').text or ''
check('\x1b' not in body and '\x00' not in body,
      'control characters must be stripped, not escaped')
check('<tag>' in body and '&' in body,
      'ordinary markup characters must survive as escaped text')

# ----------------------------------------------------------------------
# 8. `flutter test --machine` prefixes its stream with pub chatter.
# ----------------------------------------------------------------------
lines = ['Resolving dependencies in `C:\\repo`...',
         '  analyzer 12.1.0 (14.1.0 available)',
         'Got dependencies!',
         # Valid JSON that is not an event object. `json.loads` HAPPILY
         # returns these, so the try/except around the parse does not catch
         # them -- only the "is it an object?" guard does, and without it the
         # converter dies with an AttributeError partway through a suite and
         # produces no report at all.
         '42',
         '"a bare string"',
         '[1, 2, 3]',
         ''] + [json.dumps(e) for e in clean_stream()]
document, totals = build_xml(parse_events(lines), 'rackpal')
ET.fromstring(document)
check(totals['tests'] == 1,
      f'non-JSON preamble must be skipped, not counted: {totals}')

# ----------------------------------------------------------------------
if FAILURES:
    print('junit_converter_selftest: FAILED')
    for failure in FAILURES:
        print(f'  - {failure}')
    sys.exit(1)
print('junit_converter_selftest: all checks passed')
