#!/usr/bin/env python3
"""The milestone-completeness gate: roadmap section 8.9 as a CI check.

THE FOURTH GATE THAT READS THE CORPUS, beside pal1_check.py, palette_parity.py
and registry_parity.py. Board #780, under #92. The rule is DR-095 (canon
section 11.94):

    A milestone may not open while the milestone before it holds an exit
    clause that is neither DISCHARGED (DEMONSTRATED or CONFIRMED, docs/12
    section 0) nor PARKED (reassigned by ruling ID to a named later
    milestone). A milestone may not close while it holds one either.

Section 11.94.9 states the mechanical form this file implements: fail on an
undischarged, unparked clause in any milestone before the current one.

    python tools/milestone_gate.py            # exits 0 clean, 1 on any owed clause
    python tools/milestone_gate.py --selftest # only the planted cases

WHAT IT READS, all of it from docs/12-milestone-board.md:

  * Section 1's table, in its own row order, for each milestone's status. A
    status reading CRITERION MET or CLOSED is a closed milestone. THE CURRENT
    MILESTONE is the first row that is not closed, and every row above it is
    checked.
  * Each checked milestone's own section (`## 2. M0, ...`, `### 5.3 M4, ...`,
    `### 5.9 The Plan view ...`), and in it the first table whose header has
    a cell starting `Clause` and a cell that is exactly `Mark`. A DR-007 clause
    table is not an exit-clause table and its header says so.
  * A row whose Clause cell says `not an exit clause` is counted and skipped.
    Clause tables carry goal lines and checklist items beside the criterion
    (M1's "and it ships to real users", M8's licence), and section 1 already
    excludes them from its counts; the marker makes the table say so where
    this gate can read it, instead of the gate guessing from the wording.
  * Each row's Mark cell. Its LEADING word must be one of section 0's seven
    marks; anything after it is a note. A row whose mark is not DEMONSTRATED
    or CONFIRMED must carry `parked on <milestone> by DR-nnn`, the destination
    must come later in section 1's order, and the ruling must have a heading
    in docs/canonical-decisions.md.

WHY IT RUNS A SELF-TEST EVERY TIME. It passed the day it was written, over a
tree whose tables had just been normalised to pass it, which is the one
reading of "green" that proves nothing. The planted cases below are the
evidence that it can fail: each is a small docs/12 and canon built in memory
with exactly one defect, and the gate must return the expected verdict for
every one before it is allowed to read the real files.

WHAT IT DOES NOT DO. It does not judge whether a mark is TRUE; that is a
person reading evidence, and DR-095 section 11.94.6 is explicit that the
normalisation is the judgement. It does not read section 1's weakest-mark
column or the headline counts, which are prose. It reads what a clause table
claims and whether that claim is allowed to stand where it is.

Output is ASCII: the CI console decodes with cp1252.
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOARD_REL = 'docs/12-milestone-board.md'
CANON_REL = 'docs/canonical-decisions.md'

MARKS = ('NOT BUILT', 'DEMONSTRATED', 'CONFIRMED', 'BELIEVED', 'VACUOUS',
         'REFUTED', 'UNPERFORMED')
DISCHARGED = ('DEMONSTRATED', 'CONFIRMED')
PARK = re.compile(r'parked on (M\d+|the Plan view) by (DR-\d{3})\b')


def ascii_(s):
    return s.encode('ascii', 'replace').decode('ascii')


def plain(cell):
    return re.sub(r'[*`]', '', cell).strip()


def cells(row):
    return [c.strip() for c in row.strip().strip('|').split('|')]


def milestone_key(first_cell):
    """`**M3**` -> 'M3'; `**Plan view**` -> 'the Plan view'; else None."""
    p = plain(first_cell)
    if re.fullmatch(r'M\d+', p):
        return p
    if p.lower() == 'plan view':
        return 'the Plan view'
    return None


def read_overview(board):
    """Section 1's rows as [(key, status)], in table order."""
    lines = board.split('\n')
    start = next((i for i, l in enumerate(lines) if l.startswith('## 1. ')), None)
    if start is None:
        raise ValueError('docs/12 has no "## 1." section')
    rows = []
    status_at = None
    for l in lines[start + 1:]:
        if l.startswith('## '):
            break
        if not l.startswith('|'):
            if rows:
                break
            continue
        c = cells(l)
        if status_at is None:
            status_at = next((k for k, h in enumerate(c) if h.startswith('Status')), None)
            continue
        key = milestone_key(c[0]) if c else None
        if key and status_at is not None and len(c) > status_at:
            rows.append((key, plain(c[status_at]).upper()))
    if not rows:
        raise ValueError('section 1 has no milestone rows')
    return rows


def section_of(board, key):
    """The lines of `key`'s own section, from its heading to the next heading at its depth or above."""
    lines = board.split('\n')
    if key == 'the Plan view':
        pat = re.compile(r'^(#{2,3}) [\d.]+ The Plan view\b')
    else:
        pat = re.compile(r'^(#{2,3}) [\d.]+ ' + re.escape(key) + r',')
    for i, l in enumerate(lines):
        m = pat.match(l)
        if m:
            depth = len(m.group(1))
            out = []
            for l2 in lines[i + 1:]:
                h = re.match(r'^(#+) ', l2)
                if h and len(h.group(1)) <= depth:
                    break
                out.append(l2)
            return out
    return None


def clause_table(section):
    """[(row_id, clause, mark_cell)] from the first exit-clause table, or None."""
    for i, l in enumerate(section):
        if not l.startswith('|'):
            continue
        head = cells(l)
        clause_at = next((k for k, h in enumerate(head) if h.startswith('Clause')), None)
        mark_at = next((k for k, h in enumerate(head) if h == 'Mark'), None)
        if clause_at is None or mark_at is None:
            continue
        rows = []
        for r in section[i + 2:]:
            if not r.startswith('|'):
                break
            c = cells(r)
            if len(c) <= max(clause_at, mark_at):
                continue
            rid = c[0] if clause_at > 0 else str(len(rows) + 1)
            rows.append((plain(rid), plain(c[clause_at]), c[mark_at]))
        return rows
    return None


def leading_mark(cell):
    p = plain(cell).upper()
    for m in MARKS:
        if re.match(r'\s*' + m + r'\b', p):
            return m
    return None


def check(board, canon):
    """Returns (problems, report_lines)."""
    problems, report = [], []
    overview = read_overview(board)
    order = [k for k, _ in overview]
    closed = [('CRITERION MET' in s) or ('CLOSED' in s) for _, s in overview]
    current = next((i for i, c in enumerate(closed) if not c), len(overview))
    report.append('current milestone: %s (the first in section 1 that is not closed)'
                  % (order[current] if current < len(order) else 'none, every one is closed'))
    for idx in range(current):
        key = order[idx]
        section = section_of(board, key)
        if section is None:
            problems.append('%s: no section heading found in %s' % (key, BOARD_REL))
            continue
        table = clause_table(section)
        if not table:
            problems.append('%s: no clause table with a Mark column in its section' % key)
            continue
        discharged = parked = owed = skipped = 0
        for rid, clause, mark_cell in table:
            if 'not an exit clause' in clause.lower():
                skipped += 1
                continue
            rid = rid if re.fullmatch(r'\w+', rid) else '-'
            label = '%s clause %s (%s)' % (key, rid, clause[:50])
            mark = leading_mark(mark_cell)
            if mark is None:
                problems.append('%s: "%s" is not one of section 0\'s seven marks'
                                % (label, plain(mark_cell)[:40]))
                owed += 1
                continue
            if mark in DISCHARGED:
                discharged += 1
                continue
            park = PARK.search(plain(mark_cell))
            if not park:
                problems.append('%s: %s, neither discharged nor parked' % (label, mark))
                owed += 1
                continue
            dest, ruling = park.group(1), park.group(2)
            if dest not in order or order.index(dest) <= idx:
                problems.append('%s: parked on %s, which is not a later milestone' % (label, dest))
                owed += 1
                continue
            if not re.search(r'^#{2,3} .*\b' + ruling + r'\b', canon, re.M):
                problems.append('%s: parked by %s, which has no heading in %s'
                                % (label, ruling, CANON_REL))
                owed += 1
                continue
            parked += 1
        report.append('  %-13s %2d clauses: %d discharged, %d parked, %d owed%s'
                      % (key, len(table) - skipped, discharged, parked, owed,
                         (', and %d row(s) marked not an exit clause' % skipped) if skipped else ''))
    return problems, report


# ----------------------------------------------------------------------
# THE PLANTED CASES
# ----------------------------------------------------------------------

_CANON = '### 11.26 DR-027 · a ruling\n'


def _board(m0_rows, m0_status='**CRITERION MET**', m1_rows=None, m1_status='NOT STARTED'):
    head = '| # | Clause | Mark | Evidence |\n|---|---|---|---|\n'
    out = ['## 1. The board', '',
           '| # | Milestone | Size | Exit clauses | Status: weakest mark | Why |',
           '|---|---|---|---|---|---|',
           '| **M0** | F | S | x | %s | x |' % m0_status,
           '| **M1** | E | L | x | %s | x |' % m1_status,
           '', '## 2. M0, Foundations', '']
    if m0_rows is not None:
        out.append(head + '\n'.join(m0_rows))
    out += ['', '## 3. M1, Elevation', '']
    if m1_rows is not None:
        out.append(head + '\n'.join(m1_rows))
    return '\n'.join(out) + '\n'


def selftest():
    ok_row = '| 1 | a | **DEMONSTRATED** | t |'
    cases = [
        ('every clause discharged', _board([ok_row, '| 2 | b | **CONFIRMED**: by the user, 2026-01-01 | t |']), True),
        ('a note after the mark is allowed', _board(['| 1 | a | **DEMONSTRATED: exceeded** | t |']), True),
        ('BELIEVED and not parked', _board([ok_row, '| 2 | b | **BELIEVED** | t |']), False),
        ('parked on a later milestone by a real ruling',
         _board([ok_row, '| 2 | b | **NOT BUILT**, parked on M1 by DR-027 | t |']), True),
        ('parked on itself', _board(['| 1 | a | **NOT BUILT**, parked on M0 by DR-027 | t |']), False),
        ('parked by a ruling canon does not hold',
         _board(['| 1 | a | **NOT BUILT**, parked on M1 by DR-999 | t |']), False),
        ('a word that is not a mark', _board(['| 1 | a | **BUILT** | t |']), False),
        ('a goal line marked not an exit clause is not counted',
         _board([ok_row, '| - | *Goal clause, not an exit clause:* ships | **NOT BUILT** | t |']), True),
        ('a goal line NOT marked is counted, and owed',
         _board([ok_row, '| - | *Goal clause:* ships | **NOT BUILT** | t |']), False),
        ('a closed milestone with no clause table', _board(None), False),
        ('the current milestone owes clauses, which is allowed',
         _board([ok_row], m1_rows=['| 1 | a | **NOT BUILT** | t |']), True),
        ('CLOSED counts as closed',
         _board(['| 1 | a | **UNPERFORMED** | t |'], m0_status='**CLOSED 2026-01-01**'), False),
    ]
    failures = 0
    for name, board, want_pass in cases:
        try:
            problems, _ = check(board, _CANON)
            got_pass = not problems
        except ValueError:
            got_pass = False
        if got_pass != want_pass:
            failures += 1
            print('  SELFTEST FAIL  %s: expected %s, got %s'
                  % (name, 'pass' if want_pass else 'fail', 'pass' if got_pass else 'fail'))
    print('self-test: %d planted cases, %d wrong' % (len(cases), failures))
    return failures == 0


def main(argv):
    if not selftest():
        print('FAIL - the gate cannot tell a planted defect from a clean table, '
              'so its verdict on the real board means nothing.')
        return 1
    if '--selftest' in argv:
        return 0
    try:
        board = io.open(os.path.join(ROOT, BOARD_REL), encoding='utf-8').read()
        canon = io.open(os.path.join(ROOT, CANON_REL), encoding='utf-8').read()
        problems, report = check(board, canon)
    except (OSError, ValueError) as exc:
        # A PARSE FAILURE IS A GATE FAILURE, never a silent pass.
        print('FAIL - could not read the milestone tables: %s: %s'
              % (type(exc).__name__, ascii_(str(exc))))
        return 1
    for line in report:
        print(ascii_(line))
    if not problems:
        print('PASS - every milestone before the current one has each exit clause '
              'discharged or parked on a named later milestone (DR-095).')
        return 0
    print('FAIL - %d clause(s) owed where section 8.9 allows none:' % len(problems))
    for p in problems:
        print('  OWED  ' + ascii_(p))
    print()
    print('Fix the TABLE only if it is wrong. A clause that is really owed is')
    print('discharged by evidence, or parked by a ruling that names a later milestone;')
    print('a milestone that owes one is not closed.')
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
