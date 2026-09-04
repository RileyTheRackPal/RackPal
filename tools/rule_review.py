#!/usr/bin/env python3
"""Generate docs/20-rule-review.md, the M5-H1 domain-review pack.

    python3 tools/rule_review.py

WHY GENERATED AND NOT WRITTEN. `#304`: *"a reviewer who has to learn the
words 'net', 'service' and 'conductor' first is a reviewer who signs off
on the vocabulary rather than the rules."* The words a reviewer marks up
have to be the words the product ships, and a hand-copied pack drifts
from the catalogue the first time a rationale is corrected. Re-run this
after M5-H2's corrections land and the pack is current again.

WHY IT PARSES THE SOURCE rather than running Dart. A `dart run` needs a
file under `packages/*/tool/`, and anything left there is analyzed and
counts against the analyzer ratchet (CLAUDE.md). The parse was checked
field by field against a `dart run` dump of `kRuleCatalogue` on
2026-09-04 and agreed on all 28 rules; `rule_review_test` is not a thing,
so if this ever disagrees the symptom is a pack that reads oddly rather
than a red build. Check it against the catalogue if you doubt it.
"""

from __future__ import annotations

import io
import re
import sys
from collections import defaultdict

CATALOGUE = 'packages/rackpal_core/lib/src/validation/rule_catalogue.dart'
SEED = 'packages/rackpal_core/lib/src/catalog/seed_registries.dart'
OUT = 'docs/20-rule-review.md'

# What each tier MEANS to somebody drawing, in their words rather than the
# model's. This mapping is the whole point of H1.
BEHAVIOUR = {
    'modelIllegal':
        'The app will not let you draw this. There is no override, because '
        'the drawing would not mean anything.',
    'springBack':
        'The cable springs back with a short explanation and an '
        '`[ Connect anyway ]` button. You can always overrule it.',
    'postHoc':
        'Listed on the issues panel after the fact. Nothing is blocked, and '
        'you can acknowledge it with a reason that prints on the sheet set.',
}

SEVERITY = {
    'error': 'Error',
    'warning': 'Warning',
    'advisory': 'Advisory (a note, not a problem)',
    None: 'n/a (nothing is filed, the edit is simply refused)',
}

# Grouped by what a person would say the rule is ABOUT, not by tier. A
# reviewer thinks in subjects; the tier is a consequence and is stated per
# rule as "what happens".
GROUPS = [
    ('Signal and connector compatibility',
     ['SIG-001', 'SIG-002', 'DIR-001', 'DIR-003', 'CON-001', 'ELE-006',
      'ELE-003']),
    ('Cable lengths', ['LEN-001', 'LEN-002']),
    ('Power', ['PWR-001', 'PWR-003', 'NET-001']),
    ('Racks and mounting',
     ['RCK-001', 'RCK-002', 'RCK-003', 'RCK-012', 'RCK-013', 'PLC-001',
      'PLC-002', 'PLC-003']),
    ('Code-adjacent checks', ['CODE-001', 'CODE-002']),
    ('Drawing integrity',
     ['TOP-001', 'TOP-002', 'TOP-003', 'TOP-004', 'TOP-005', 'LNK-020']),
]

_PIECES = re.compile(r"'([^']*)'|\"([^\"]*)\"")


def _joined(block: str, field: str) -> str | None:
    """A Dart adjacent-string literal, put back together."""
    m = re.search(
        field + r":\s*((?:\s*(?:'[^']*'|\"[^\"]*\")\s*)+),", block)
    if not m:
        return None
    return ''.join(a or b for a, b in _PIECES.findall(m.group(1)))


def rules() -> list[dict]:
    src = io.open(CATALOGUE, encoding='utf-8').read()
    out = []
    for block in re.findall(r'RuleMeta\((.*?)\n  \),', src, re.S):
        rid = re.search(r"ruleId:\s*'([^']+)'", block)
        if not rid:
            continue
        sev = re.search(r'defaultSeverity:\s*Severity\.(\w+)', block)
        out.append({
            'id': rid.group(1),
            'tier': re.search(r'tier:\s*RuleTier\.(\w+)', block).group(1),
            'severity': sev.group(1) if sev else None,
            'summary': _joined(block, 'summary'),
            'rationale': _joined(block, 'rationale'),
        })
    return out


def families() -> dict[str, list[tuple[str, str]]]:
    src = io.open(SEED, encoding='utf-8').read()
    dom: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for i, name, d in re.findall(
            r"_family\(\s*\n\s*'([^']+)',\s*\n\s*'([^']*)',\s*\n\s*'([^']+)',",
            src):
        dom[d].append((i, name))
    return dom


def main() -> int:
    catalogue = rules()
    by_id = {r['id']: r for r in catalogue}
    placed = {i for _, ids in GROUPS for i in ids}
    ungrouped = set(by_id) - placed
    if ungrouped:
        # A NEW RULE MUST BE PLACED BY HAND. Dropping it into a catch-all
        # group would hide it at the bottom of the pack, which is where a
        # reviewer stops reading.
        print(f'ungrouped rules: {sorted(ungrouped)}', file=sys.stderr)
        return 1
    stale = placed - set(by_id)
    if stale:
        print(f'grouped but not in the catalogue: {sorted(stale)}',
              file=sys.stderr)
        return 1

    L: list[str] = []
    w = L.append
    w('# The 28 checks, and the signal families: a review pack')
    w('')
    w('**For a working integrator to mark up. Nothing here needs any '
      'knowledge of how RackPal is built.**')
    w('')
    w('There are two parts. Part 1 is every check the product makes, in '
      'plain terms. Part 2 is the list of signal types it knows about.')
    w('')
    w('## What I am asking')
    w('')
    w('For each check in Part 1, three questions:')
    w('')
    w('1. **Is the reasoning right?** Not the wording: the trade fact '
      'underneath it. If it is wrong, or right only sometimes, say when.')
    w('2. **Is it as serious as it says?** Nothing here blocks a drawing '
      'or an export, at any level: the difference an error makes is how '
      'loudly it is reported and how it reads to whoever opens the sheet '
      'set. A warning that should be an error, or the reverse, is worth '
      'more than a wording fix.')
    w('3. **Does it fire when it should not?** The case that matters most '
      'is a correct design the check complains about, because that is how '
      'people learn to ignore it.')
    w('')
    w('For Part 2, one question: **what would you specify on a job that is '
      'not on the list?**')
    w('')
    w('## What I am NOT asking')
    w('')
    w('Whether there should be MORE checks. The set is capped at 28 on '
      'purpose and adding to it is a separate decision. If something '
      'important is missing, say so and it becomes its own question rather '
      'than a change to this list.')
    w('')
    w('Nothing here is a code ruling. Two of the checks mention NEC '
      'articles and both ask you to verify rather than telling you the '
      'answer; if they read as though they are deciding, that is a defect '
      'and worth flagging.')
    w('')
    w('---')
    w('')
    w(f'# Part 1: the {len(catalogue)} checks')
    w('')
    for title, ids in GROUPS:
        w(f'## {title}')
        w('')
        for rid in ids:
            r = by_id[rid]
            w(f'### {rid}')
            w('')
            w(f'**Why it matters.** {r["rationale"]}')
            w('')
            w(f'**What happens.** {BEHAVIOUR[r["tier"]]}')
            w('')
            w(f'**How serious.** {SEVERITY[r["severity"]]}')
            w('')
            w('| Right? | Severity right? | False alarms? | Notes |')
            w('|---|---|---|---|')
            w('|  |  |  |  |')
            w('')
    w('---')
    w('')
    w('# Part 2: the signal types RackPal knows')
    w('')
    dom = families()
    total = sum(len(v) for v in dom.values())
    w(f'**{total} of them, in {len(dom)} groups.** These are catalogue data '
      'and cannot be added by the person drawing, so a missing one cannot '
      'be worked around on a job. That is why the list is here.')
    w('')
    w('The question is not whether the names are right. It is whether '
      'anything you would put on a drawing has nowhere to go.')
    w('')
    for d in sorted(dom):
        w(f'## {d} ({len(dom[d])})')
        w('')
        w('| Name | Id |')
        w('|---|---|')
        for i, name in sorted(dom[d], key=lambda x: x[1].lower()):
            w(f'| {name} | `{i}` |')
        w('')
    w('## Two names already raised')
    w('')
    w('**Lutron QS / HomeWorks already ships**, as `ctl.lutron_qs` in the '
      'control group. **Legrand Vantage does not.** Both were named when '
      'this question was first raised, and one of the two turned out to be '
      'there already, which is why this is a census rather than a shopping '
      'list.')
    w('')
    w('## What a new one costs, so the answer is not automatic')
    w('')
    w('Each signal type needs an id, a display name, a group, a default '
      'connector, a default direction, a default topology and a short tag. '
      'If it has to be told apart from its group-mates on a black and white '
      'print it also needs its own dash pattern and line weight, and there '
      'is a test that fails the build when two in one group are too alike. '
      'The digital video group is already crowded.')
    w('')
    w('So: a name that is genuinely specified on jobs is worth adding. A '
      'name that is a variant of something already listed is usually better '
      'served by the thing already listed.')
    w('')

    io.open(OUT, 'w', encoding='utf-8', newline='').write('\n'.join(L))
    print(f'wrote {OUT}: {len(catalogue)} rules, {total} families')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
