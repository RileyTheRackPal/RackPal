#!/usr/bin/env python3
"""Convert the Dart test JSON event stream into JUnit XML for Azure DevOps.

WHY THIS FILE EXISTS. Azure DevOps' "Tests" tab consumes JUnit (or NUnit,
VSTest, xUnit) XML and nothing else. Neither `dart test` nor `flutter test`
can emit any of them: their machine-readable output is the Dart test
*event protocol* -- one JSON object per line, documented at
https://github.com/dart-lang/test/blob/master/pkgs/test/doc/json_reporter.md
-- which the ADO publisher cannot read. Without a conversion step the
pipeline still passes or fails correctly (the runner's exit code is
authoritative and `run_suite.ps1` propagates it), but a red build shows
"2072 tests" nowhere and a reviewer has to read raw log text to find which
assertion broke. This is that conversion step and nothing more.

    dart test --reporter=json    > events.jsonl
    flutter test --machine       > events.jsonl        # same protocol
    python tools/ci/junit_from_dart_test.py \
        --input events.jsonl --output results.xml --suite rackpal_core

EXIT CODE IS NOT THE VERDICT. This script exits 0 whenever it produced a
readable report, INCLUDING when that report is full of failures -- the
verdict belongs to the test runner. It exits 2 only when it could not
produce a report at all (unreadable input), because a conversion that
silently emits an empty XML would be a green-looking Tests tab over a red
run.

THREE WAYS A RUN GOES RED WITHOUT ANY VISIBLE TEST FAILING, all of which
this file is built to surface rather than swallow:

  * A SUITE THAT DOES NOT COMPILE. The runner reports it as a *hidden*
    test named "loading <path>" with a non-success result. Hidden tests are
    bookkeeping and are dropped -- unless they failed, in which case they
    are the only record that the file exists at all.
  * A RUNNER THAT DIED MID-STREAM. No `done` event ever arrives. A
    synthetic failing case is emitted so the report cannot read green.
  * `done` WITH success:false AND NO FAILING CASE. Same treatment. This is
    the shape that makes a report lie, so it is asserted against directly:
    the JSON stream, not the XML, decides whether the XML may look clean.

`flutter test --machine` prefixes its stream with human-readable pub
output ("Resolving dependencies...", the outdated-package list), so any
line that is not a JSON object is skipped rather than treated as an error.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from xml.sax.saxutils import escape, quoteattr

# XML 1.0 forbids most C0 control characters outright -- they cannot even be
# escaped as character references. A Dart failure message can contain them
# (an ANSI-coloured expected/actual diff carries ESC = 0x1B), and one such
# byte makes the whole document unparseable, which ADO reports as "no
# results" rather than as a broken file. Strip them; keep tab/LF/CR.
_ALLOWED_CONTROL = {0x09, 0x0A, 0x0D}


def _strip_control(text: str) -> str:
    """`text` with the characters XML 1.0 cannot represent removed."""
    return ''.join(
        ch for ch in text
        if ord(ch) >= 0x20 or ord(ch) in _ALLOWED_CONTROL
    )


def _xml_safe(text: str) -> str:
    """`text` as escaped element content."""
    return escape(_strip_control(text))


def _xml_attr(text: str) -> str:
    """`text` as a quoted attribute value.

    ATTRIBUTES NEED THE SAME STRIPPING AS ELEMENT TEXT, and it is easy to
    apply it to one and not the other: `quoteattr` escapes quotes and
    ampersands but passes control characters straight through, so a single
    ESC byte from an ANSI-coloured expected/actual diff lands in
    `<failure message="...">` and the whole document stops parsing. The
    self-test drives exactly that case.
    """
    return quoteattr(_strip_control(text))


class _Test:
    __slots__ = ('name', 'suite_path', 'start_ms', 'end_ms',
                 'result', 'hidden', 'skipped', 'skip_reason', 'errors',
                 'prints')

    def __init__(self, name: str, suite_path: str,
                 start_ms: int, skipped: bool, skip_reason: str | None):
        # NOTE: `name` from a `testStart` event ALREADY carries the names of
        # every containing group, per the JSON reporter protocol ("the name
        # of the test, including prefixes from any containing groups").
        # Prepending the group names again doubles them -- which the first
        # run of this converter did, producing "CR-117 - byte round trip ...
        # CR-117 - byte round trip ... (a) empty new project".
        self.name = name
        self.suite_path = suite_path
        self.start_ms = start_ms
        self.end_ms = start_ms
        self.result = 'incomplete'
        self.hidden = False
        self.skipped = skipped
        self.skip_reason = skip_reason
        self.errors: list[tuple[str, str]] = []
        self.prints: list[str] = []


def parse_events(lines) -> dict:
    """Fold the event stream into the state the XML needs.

    Returns a dict with `tests` (ordered list of `_Test`), `saw_done`,
    `run_succeeded`.
    """
    suites: dict[int, str] = {}
    tests: dict[int, _Test] = {}
    order: list[int] = []
    saw_done = False
    run_succeeded = False

    for raw in lines:
        line = raw.strip()
        if not line.startswith('{'):
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get('type')

        if kind == 'suite':
            suite = event['suite']
            suites[suite['id']] = suite.get('path') or ''
        elif kind == 'testStart':
            test = event['test']
            metadata = test.get('metadata') or {}
            entry = _Test(
                name=test.get('name') or '(unnamed)',
                suite_path=suites.get(test.get('suiteID', -1), ''),
                start_ms=event.get('time', 0),
                skipped=bool(metadata.get('skip')),
                skip_reason=metadata.get('skipReason'),
            )
            tests[test['id']] = entry
            order.append(test['id'])
        elif kind == 'testDone':
            entry = tests.get(event.get('testID', -1))
            if entry is None:
                continue
            entry.end_ms = event.get('time', entry.start_ms)
            entry.result = event.get('result', 'error')
            entry.hidden = bool(event.get('hidden'))
            # `skipped` on testDone covers markTestSkipped() at runtime,
            # which the metadata on testStart cannot know about.
            entry.skipped = entry.skipped or bool(event.get('skipped'))
        elif kind == 'error':
            entry = tests.get(event.get('testID', -1))
            if entry is None:
                continue
            entry.errors.append(
                (event.get('error') or '', event.get('stackTrace') or ''))
        elif kind == 'print':
            entry = tests.get(event.get('testID', -1))
            if entry is not None:
                entry.prints.append(event.get('message') or '')
        elif kind == 'done':
            saw_done = True
            run_succeeded = bool(event.get('success'))

    return {
        'tests': [tests[i] for i in order],
        'saw_done': saw_done,
        'run_succeeded': run_succeeded,
    }


def _classname(suite_prefix: str, suite_path: str) -> str:
    """A dotted container name ADO groups the Tests tab by."""
    path = (suite_path or 'unknown').replace('\\', '/')
    # `flutter test --machine` reports absolute paths, `dart test` relative
    # ones. Keep the tail from `test/` on so both read the same.
    marker = '/test/'
    index = path.rfind(marker)
    if index != -1:
        path = path[index + 1:]
    if path.endswith('.dart'):
        path = path[:-len('.dart')]
    dotted = path.strip('/').replace('/', '.')
    return f'{suite_prefix}.{dotted}' if suite_prefix else dotted


def build_xml(state: dict, suite_prefix: str) -> tuple[str, dict]:
    """The JUnit document, plus the counts it reports."""
    cases: list[str] = []
    totals = {'tests': 0, 'failures': 0, 'errors': 0, 'skipped': 0}
    total_ms = 0
    visible_failures = 0

    for test in state['tests']:
        succeeded = test.result == 'success'
        # Hidden tests are the runner's own bookkeeping ("loading <path>").
        # A hidden test that FAILED is a suite that would not compile or
        # would not load -- the single most important thing to report,
        # because no visible test exists to carry the failure.
        if test.hidden and succeeded:
            continue

        name = test.name
        duration_ms = max(0, test.end_ms - test.start_ms)
        total_ms += duration_ms
        totals['tests'] += 1

        body = ''
        folded_prints_into_failure = False
        if test.skipped:
            totals['skipped'] += 1
            reason = test.skip_reason or 'skipped'
            body = f'    <skipped message={_xml_attr(reason)} />\n'
        elif not succeeded:
            visible_failures += 1
            totals['failures'] += 1
            message = test.errors[0][0] if test.errors \
                else f'result: {test.result}'
            detail = '\n\n'.join(
                f'{m}\n{s}'.rstrip() for m, s in test.errors
            ) or message
            # THE PRINTS BELONG IN THE FAILURE, not in <system-out>, when the
            # test failed. `flutter test` reports the `error` event as the
            # near-useless "Test failed. See exception logs above." and puts
            # the actual expected/actual diff and stack in `print` events --
            # so a converter that files prints under <system-out> gives a
            # reviewer a failure with no diff in it and sends them back to
            # the raw log, which is the thing this conversion exists to
            # avoid. Verified against a real flutter_test failure, not
            # assumed from the protocol document.
            if test.prints:
                detail = f'{detail}\n\n{chr(10).join(test.prints)}'
                folded_prints_into_failure = True
            first_line = message.strip().splitlines()[0] if message.strip() \
                else test.result
            body = (
                f'    <failure message={_xml_attr(first_line[:400])} '
                f'type="TestFailure">{_xml_safe(detail)}</failure>\n'
            )
        if test.prints and not folded_prints_into_failure:
            # A runtime `markTestSkipped('...')` reports its reason ONLY as a
            # print event -- `skipReason` is null for it -- so dropping
            # system-out here would erase why a test was skipped.
            body += ('    <system-out>'
                     f'{_xml_safe(chr(10).join(test.prints))}'
                     '</system-out>\n')

        cases.append(
            f'  <testcase classname='
            f'{_xml_attr(_classname(suite_prefix, test.suite_path))} '
            f'name={_xml_attr(name)} time="{duration_ms / 1000.0:.3f}">\n'
            f'{body}'
            '  </testcase>\n'
        )

    # THE ANTI-GREEN-LIE CLAUSE. See the module docstring: a run that ended
    # badly must never produce a report that reads clean.
    if not state['saw_done']:
        totals['tests'] += 1
        totals['errors'] += 1
        cases.append(
            f'  <testcase classname={_xml_attr(suite_prefix or "suite")} '
            'name="RUNNER DID NOT FINISH" time="0.000">\n'
            '    <error message="the test runner produced no `done` event" '
            'type="RunnerCrash">The JSON event stream ended without a '
            '`done` event, so the run crashed, was killed, or timed out. '
            'The cases listed here are whatever completed before that; '
            'they are not the whole suite.</error>\n'
            '  </testcase>\n'
        )
    elif not state['run_succeeded'] and visible_failures == 0:
        totals['tests'] += 1
        totals['errors'] += 1
        cases.append(
            f'  <testcase classname={_xml_attr(suite_prefix or "suite")} '
            'name="RUN REPORTED FAILURE WITH NO FAILING TEST" time="0.000">\n'
            '    <error message="`done` reported success:false but no test '
            'failed" type="UnattributedFailure">The runner says the run '
            'failed and no individual case carries it -- typically a '
            'load-time or teardown error. Read the raw log for this '
            'suite.</error>\n'
            '  </testcase>\n'
        )

    header = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<testsuites>\n'
        f'<testsuite name={_xml_attr(suite_prefix or "dart test")} '
        f'tests="{totals["tests"]}" failures="{totals["failures"]}" '
        f'errors="{totals["errors"]}" skipped="{totals["skipped"]}" '
        f'time="{total_ms / 1000.0:.3f}">\n'
    )
    return header + ''.join(cases) + '</testsuite>\n</testsuites>\n', totals


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True,
                        help='file holding the JSON event stream')
    parser.add_argument('--output', required=True,
                        help='JUnit XML file to write')
    parser.add_argument('--suite', default='',
                        help='name prefix for the suite, e.g. rackpal_core')
    args = parser.parse_args(argv)

    try:
        with open(args.input, encoding='utf-8', errors='replace') as handle:
            state = parse_events(handle)
    except OSError as error:
        print(f'junit_from_dart_test: cannot read {args.input}: {error}',
              file=sys.stderr)
        return 2

    document, totals = build_xml(state, args.suite)

    directory = os.path.dirname(os.path.abspath(args.output))
    if directory:
        os.makedirs(directory, exist_ok=True)
    try:
        with open(args.output, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(document)
    except OSError as error:
        print(f'junit_from_dart_test: cannot write {args.output}: {error}',
              file=sys.stderr)
        return 2

    print(
        f'{args.suite or "suite"}: {totals["tests"]} cases, '
        f'{totals["failures"]} failed, {totals["errors"]} errored, '
        f'{totals["skipped"]} skipped -> {args.output}'
    )
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
