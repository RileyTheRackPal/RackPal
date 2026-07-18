#!/usr/bin/env python3
"""Documentation-vs-registry parity check for the RackMate signal palette.

tools/pal1_check.py proves the palette itself is legible in greyscale. This proves the
DOCUMENTS agree with it. Those are different failures, and the second one shipped four times:
a table of dash and weight values drifts out of step with the registry, a reader implements
from the stale table, and the resulting palette re-collides.

Every markdown table row in docs/ whose first cell is a known signal-family id is checked
against the FAMILIES list in tools/pal1_check.py, which is the single authority.

    python tools/palette_parity.py           # report drift, exit 1 if any
    python tools/palette_parity.py --fix     # rewrite the drifted cells in place

Run both this and tools/pal1_check.py in CI. The first says the palette is correct; the
second says the docs tell the truth about it.
"""
import importlib.util
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, 'docs')
SKIP_DIRS = {'research'}  # raw working papers: frozen artifacts, deliberately not maintained


def load_registry():
    spec = importlib.util.spec_from_file_location(
        'pal1_check', os.path.join(ROOT, 'tools', 'pal1_check.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return {f[0]: (f[2], f[3]) for f in mod.FAMILIES}


def norm_dash(cell):
    """`12,4` / solid / `solid` -> canonical bare string."""
    s = cell.strip().strip('*').strip().strip('`').strip()
    return s


def norm_weight(cell):
    """1.00x / 1.00* / **0.75x** -> float, or None if the cell is not a weight."""
    s = cell.strip().strip('*').strip()
    m = re.match(r'^([0-9]+(?:\.[0-9]+)?)\s*[x×]$', s)
    return float(m.group(1)) if m else None


def fmt_weight(w):
    return '%.2f×' % w


def split_row(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]


def scan(path, registry, fix=False):
    """Return (drifts, newlines). A drift is (lineno, fid, field, found, expected)."""
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    drifts = []
    dash_col = wt_col = None
    for i, line in enumerate(lines):
        if not line.lstrip().startswith('|'):
            dash_col = wt_col = None          # a table ended
            continue
        cells = split_row(line)
        if all(set(c) <= set('-: ') for c in cells if c):
            continue                          # delimiter row
        low = [c.lower() for c in cells]
        if 'id' in low:                       # header row: locate the columns
            dash_col = next((k for k, c in enumerate(low) if 'dash' in c), None)
            wt_col = next((k for k, c in enumerate(low) if c in ('wt', 'weight')), None)
            continue
        if dash_col is None and wt_col is None:
            continue
        fid = cells[0].strip('`* ')
        if fid not in registry:
            continue
        exp_dash, exp_wt = registry[fid]
        changed = False
        if dash_col is not None and dash_col < len(cells):
            got = norm_dash(cells[dash_col])
            # an em-dash means "inherits the domain base"; not a published value
            if got and got not in ('—', '-') and got != exp_dash:
                drifts.append((i + 1, fid, 'dash', got, exp_dash))
                cells[dash_col] = 'solid' if exp_dash == 'solid' else '`%s`' % exp_dash
                changed = True
        if wt_col is not None and wt_col < len(cells):
            got = norm_weight(cells[wt_col])
            if got is not None and abs(got - exp_wt) > 1e-9:
                drifts.append((i + 1, fid, 'weight', fmt_weight(got), fmt_weight(exp_wt)))
                cells[wt_col] = fmt_weight(exp_wt)
                changed = True
        if changed and fix:
            lines[i] = '| ' + ' | '.join(cells) + ' |'
    if fix and drifts:
        with open(path, 'w', encoding='utf-8', newline='') as fh:
            fh.write('\n'.join(lines))
    return drifts


def main():
    fix = '--fix' in sys.argv
    registry = load_registry()
    total = 0
    for base, dirs, files in os.walk(DOCS):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(files):
            if not name.endswith('.md'):
                continue
            path = os.path.join(base, name)
            drifts = scan(path, registry, fix)
            if not drifts:
                continue
            total += len(drifts)
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            print('%s: %d drifted cell(s)' % (rel, len(drifts)))
            for lineno, fid, field, got, exp in drifts:
                verb = 'fixed  ' if fix else 'DRIFT  '
                print('  %s%s:%d  %-24s %-7s %-16s -> %s'
                      % (verb, rel, lineno, fid, field, got, exp))
    print()
    if not total:
        print('PASS - every documented dash and weight matches tools/pal1_check.py.')
        return 0
    if fix:
        print('Rewrote %d cell(s). Re-run without --fix to confirm, '
              'then run tools/pal1_check.py.' % total)
        return 0
    print('FAIL - %d documented value(s) disagree with the registry.' % total)
    print('Run with --fix to correct them.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
