#!/usr/bin/env python3
"""Dart-seed-vs-registry parity check for the RackPal signal palette.

THE THIRD GATE IN A FAMILY OF THREE, and each proves something the other two
cannot:

    tools/pal1_check.py       the PALETTE is legible in greyscale
    tools/palette_parity.py   the DOCUMENTS agree with the palette
    tools/registry_parity.py  the CODE agrees with the palette   <- this file

DR-010 section 11.10.1 makes the shipped registries a SEEDED DART CATALOG
rather than the `assets/catalog/registries.json` that `registries.dart` claimed
for a year and that never existed. That is the right call -- `rackpal_core`
imports no Flutter and cannot load an asset at all -- but it means the 8 domain
hues and the 55 (dash, weight) pairs are now hand-authored into Dart, which
makes packages/rackpal_core/lib/src/catalog/seed_registries.dart A FOURTH COPY
of data that already lives in tools/pal1_check.py, seed-devices.md sections
4.3/4.4 and canon section 6.2.5.

Four copies is the exact failure mode palette_parity.py was written for after
it, in its own words, "shipped four times": a dash drifts, a reader implements
from the stale copy, and the palette re-collides in greyscale where nobody is
looking. pal1_check.py stays THE SINGLE AUTHORITY (DR-010 section 11.10.1) and
this file asserts the Dart seed is a faithful projection of it.

    python tools/registry_parity.py     # exits 0 clean, 1 on any drift

WHAT IS COMPARED, and why it is the effective value and not the stored one.
PAL-1 is stated over EFFECTIVE values -- "after any override, not the domain
base value" -- and the Dart seed deliberately stores OVERRIDES, so that a
domain-level correction (as `str` took at section 14.3) reaches every family
that never overrode it. This file therefore applies the same fallback the Dart
does (`SignalFamilyDef.effectiveDashPattern`: override ?? domain base) before
comparing, which means it checks the INHERITANCE RULE as well as the values. A
seed that dropped the fallback and stored `[]` for every inheriting family
would read as "solid everywhere" here and fail loudly.

WHY IT PARSES DART SOURCE RATHER THAN RUNNING DART. This gate runs in the
palette block of azure-pipelines.yml, which is explicitly the block that "needs
no Dart and no dependencies" -- it is positioned to fail fast, before any
toolchain is exercised. palette_parity.py text-scans markdown for the same
reason. The parser below is whitespace- and format-insensitive (it reads
balanced parentheses, not columns), so `dart format` cannot break it, and the
id-set equality checks below make a parser that silently matched NOTHING fail
rather than pass vacuously -- which is the only way a checker like this lies.
"""
import importlib.util
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = os.path.join(ROOT, 'packages', 'rackpal_core', 'lib', 'src', 'catalog',
                    'seed_registries.dart')
SEED_REL = 'packages/rackpal_core/lib/src/catalog/seed_registries.dart'

# --------------------------------------------------------------------- authority

def load_authority():
    """DOMAIN_HUE and FAMILIES from tools/pal1_check.py, the single authority."""
    spec = importlib.util.spec_from_file_location(
        'pal1_check', os.path.join(ROOT, 'tools', 'pal1_check.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

# ------------------------------------------------------------------- dart parse

def strip_comments(src):
    """Remove // and /* */ comments, respecting string literals.

    The seed file carries a rationale comment INSIDE several argument lists
    (that is the house style, and it is why the argument splitter cannot simply
    split on commas). Blanking them here keeps the splitter honest.
    """
    out, i, n = [], 0, len(src)
    while i < n:
        ch = src[i]
        if ch in "'\"":
            quote = ch
            out.append(ch)
            i += 1
            while i < n:
                if src[i] == '\\':
                    out.append(src[i:i + 2])
                    i += 2
                    continue
                out.append(src[i])
                if src[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        if ch == '/' and i + 1 < n and src[i + 1] == '/':
            while i < n and src[i] != '\n':
                i += 1
            continue
        if ch == '/' and i + 1 < n and src[i + 1] == '*':
            i = src.find('*/', i + 2)
            i = n if i < 0 else i + 2
            continue
        out.append(ch)
        i += 1
    return ''.join(out)


def balanced(src, open_at):
    """Body of the parenthesised region whose '(' is at [open_at]."""
    depth, i, n = 0, open_at, len(src)
    while i < n:
        ch = src[i]
        if ch in "'\"":
            quote = ch
            i += 1
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == quote:
                    break
                i += 1
        elif ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return src[open_at + 1:i]
        i += 1
    raise ValueError('unbalanced parentheses at offset %d' % open_at)


def split_args(body):
    """Top-level comma split, respecting (), [], {} and string literals."""
    args, cur, depth, i, n = [], [], 0, 0, len(body)
    while i < n:
        ch = body[i]
        if ch in "'\"":
            quote = ch
            cur.append(ch)
            i += 1
            while i < n:
                if body[i] == '\\':
                    cur.append(body[i:i + 2])
                    i += 2
                    continue
                cur.append(body[i])
                if body[i] == quote:
                    i += 1
                    break
                i += 1
            continue
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        elif ch == ',' and depth == 0:
            args.append(''.join(cur).strip())
            cur = []
            i += 1
            continue
        cur.append(ch)
        i += 1
    tail = ''.join(cur).strip()
    if tail:
        args.append(tail)
    return args


def parse_str(tok):
    tok = tok.strip()
    if len(tok) < 2 or tok[0] not in "'\"" or tok[-1] != tok[0]:
        raise ValueError('not a Dart string literal: %r' % tok)
    return tok[1:-1].replace("\\'", "'").replace('\\"', '"').replace('\\\\', '\\')


def parse_int_list(tok):
    tok = tok.strip()
    if tok.startswith('const '):
        tok = tok[len('const '):].strip()
    if not (tok.startswith('[') and tok.endswith(']')):
        raise ValueError('not a Dart list literal: %r' % tok)
    inner = tok[1:-1].strip()
    if not inner:
        return []
    return [int(x.strip().replace('_', '')) for x in inner.split(',') if x.strip()]


def calls(src, fname):
    """Every `fname(...)` CALL -- definitions are skipped.

    A call's first argument is a string literal; the definition's is the
    declaration `String id`. That is the discriminator, and it is checked
    rather than assumed: an unrecognised first argument raises.
    """
    found = []
    for m in re.finditer(r'\b%s\s*\(' % re.escape(fname), src):
        body = balanced(src, m.end() - 1)
        args = split_args(body)
        if not args or args[0][:1] not in ("'", '"'):
            continue                      # the declaration, not a call
        found.append(args)
    return found


def parse_seed(path):
    """(domains, families) from the Dart seed.

    domains  -> {id: {'hex', 'dash', 'weight'}}
    families -> [{'id', 'domain', 'dash', 'weight'}] with dash/weight EFFECTIVE
    """
    with open(path, encoding='utf-8') as fh:
        src = strip_comments(fh.read())

    domains = {}
    for args in calls(src, '_domain'):
        # id, displayName, tagPrefix, light, dark, dash, weight, glyph, glyphAlt
        if len(args) != 9:
            raise ValueError('_domain call has %d args, expected 9: %s'
                             % (len(args), args[0]))
        domains[parse_str(args[0])] = {
            'hex': parse_str(args[3]).upper(),
            'dash': parse_int_list(args[5]),
            'weight': int(args[6].strip()),
        }

    families = []
    for args in calls(src, '_family'):
        # id, displayName, domain, connector, dir, topo, shortTag [, named]
        positional = [a for a in args if not re.match(r'^\w+\s*:', a)]
        named = {}
        for a in args:
            m = re.match(r'^(\w+)\s*:(.*)$', a, re.S)
            if m:
                named[m.group(1)] = m.group(2).strip()
        if len(positional) != 7:
            raise ValueError('_family call has %d positional args, expected 7: %s'
                             % (len(positional), positional[0]))
        fid = parse_str(positional[0])
        dom = parse_str(positional[2])
        if dom not in domains:
            raise ValueError('%s names domain %r, which the seed does not '
                             'declare' % (fid, dom))
        # THE FALLBACK, mirroring SignalFamilyDef.effectiveDashPattern /
        # effectiveLineWeightPermille. Note `dash: []` is an explicit override
        # to solid (audio.line_bal) and is NOT the same as an absent `dash:`.
        dash = (parse_int_list(named['dash']) if 'dash' in named
                else domains[dom]['dash'])
        weight = (int(named['weight']) if 'weight' in named
                  else domains[dom]['weight'])
        families.append({'id': fid, 'domain': dom, 'dash': dash,
                         'weight': weight})
    return domains, families

# ------------------------------------------------------------------ conversions

def dash_to_pattern(permille_points):
    """[6000, 3000] -> '6,3'; [1500, 3000] -> '1.5,3'; [] -> 'solid'.

    CR-079: dash patterns are stored as permille-points so a persisted length
    is never a float (CR-001/CR-003). The authority writes them in points, so
    the comparison happens in the authority's units.
    """
    if not permille_points:
        return 'solid'
    parts = []
    for v in permille_points:
        if v % 1000 == 0:
            parts.append(str(v // 1000))
        else:
            parts.append(('%.3f' % (v / 1000.0)).rstrip('0').rstrip('.'))
    return ','.join(parts)


def weight_to_multiplier(permille):
    """1000 -> 1.00x. `Permille`, where 1000 is the base signal weight."""
    return permille / 1000.0

# ----------------------------------------------------------------------- checks

def check():
    auth = load_authority()
    domains, families = parse_seed(SEED)
    auth_fams = {f[0]: (f[1], f[2], f[3]) for f in auth.FAMILIES}
    drifts = []

    # -- domains: the id set, then the hue ---------------------------------
    seed_ids, auth_ids = set(domains), set(auth.DOMAIN_HUE)
    for extra in sorted(seed_ids - auth_ids):
        drifts.append('domain %s is in the Dart seed and not in the authority'
                      % extra)
    for missing in sorted(auth_ids - seed_ids):
        drifts.append('domain %s is in the authority and not in the Dart seed'
                      % missing)
    for did in sorted(seed_ids & auth_ids):
        want = auth.DOMAIN_HUE[did].upper()
        got = domains[did]['hex']
        if got != want:
            drifts.append('domain %-14s hue      %-8s -> %s' % (did, got, want))

    # -- families: the id set, then domain, dash and weight -----------------
    seed_fam_ids = {f['id'] for f in families}
    for extra in sorted(seed_fam_ids - set(auth_fams)):
        drifts.append('family %s is in the Dart seed and not in the authority'
                      % extra)
    for missing in sorted(set(auth_fams) - seed_fam_ids):
        drifts.append('family %s is in the authority and not in the Dart seed'
                      % missing)

    for f in families:
        want = auth_fams.get(f['id'])
        if want is None:
            continue
        want_dom, want_dash, want_wt = want
        if f['domain'] != want_dom:
            drifts.append('family %-24s domain   %-16s -> %s'
                          % (f['id'], f['domain'], want_dom))
        got_dash = dash_to_pattern(f['dash'])
        if got_dash != want_dash:
            drifts.append('family %-24s dash     %-16s -> %s'
                          % (f['id'], got_dash, want_dash))
        got_wt = weight_to_multiplier(f['weight'])
        if abs(got_wt - want_wt) > 1e-9:
            drifts.append('family %-24s weight   %-16s -> %s'
                          % (f['id'], '%.2fx' % got_wt, '%.2fx' % want_wt))

    return drifts, domains, families


def main():
    try:
        drifts, domains, families = check()
    except (OSError, ValueError) as exc:
        # A PARSE FAILURE IS A GATE FAILURE, never a silent pass. If the seed
        # file moves or its helper shape changes, this must go red and be
        # fixed -- a checker that quietly matches nothing is worse than none.
        print('FAIL - could not read the Dart seed (%s):' % SEED_REL)
        print('  %s: %s' % (type(exc).__name__, exc))
        return 1

    print('registry parity: %d domains, %d families read from %s'
          % (len(domains), len(families), SEED_REL))
    if not drifts:
        print('PASS - the Dart seed matches tools/pal1_check.py on every '
              'domain hue, family domain, effective dash and effective weight.')
        return 0
    print('FAIL - %d disagreement(s) with tools/pal1_check.py:' % len(drifts))
    for d in drifts:
        print('  DRIFT  ' + d)
    print()
    print('tools/pal1_check.py is the authority (DR-010 section 11.10.1). Fix')
    print('%s, not the authority -- unless the palette' % SEED_REL)
    print('itself is changing, in which case change both in one commit, run')
    print('tools/pal1_check.py and tools/palette_parity.py, and update')
    print('docs/catalog/seed-devices.md sections 4.3/4.4 to match.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
