#!/usr/bin/env python3
"""List the illustration slots in the user guide, and check the rules on them.

    python tools/plate_index.py              # every slot, one line each
    python tools/plate_index.py --tally      # register by chapter, size by count
    python tools/plate_index.py --check      # the rules; exit 1 on a violation
    python tools/plate_index.py --markdown   # the index as a table, for an artist

WHY THIS EXISTS. docs/22 sets rules for where Riley may be loud, and a rule
that nothing reads is a hope. The slots live in docs/21 as blockquotes whose
first words are bold (`> **PLATE 21.5.4-D · HALF** · Scene 44 · ...`), so a
parser can read them back without the guide having to carry a second copy.

WHY THERE IS NO STATIC LIST IN THE DOCUMENTS. A copy of a moving list is this
corpus's recurring failure (CLAUDE.md, on counts). Ask the guide.

NOT A BUILD GATE. Nothing in the product depends on the art existing, so this
is deliberately not wired into tools/ci/run_local.ps1. Run it when plates move.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUIDE = os.path.join(ROOT, "docs", "21-user-guide.md")
RILEY = os.path.join(ROOT, "docs", "19-riley.md")
PLAN = os.path.join(ROOT, "docs", "22-riley-plate-plan.md")

SIZES = {"SPOT", "MARGIN", "HALF", "FULL", "STRIP"}

# The eight domain marks (docs/19 §7.1), native and transported, as codepoints.
# Used ONLY to ask whether a page carries them: Riley's art draws them as
# geometry, and the guide's text uses them nowhere except where a page is
# meant to be free of them.
DOMAIN_GLYPHS = set("▲△▼▽●◐○◆◇■□✚✳⬢⬡⏚★☆")

# The one section where the bluescreen is allowed (DR-118 §11.117.3).
BSOD_SECTION = "21.13"
# The chapter carrying the three safety sentences (DR-117 §11.116.3).
SAFETY_SECTION = "21.11"

HEAD = re.compile(r"^#{2,3} (21(?:\.\d+)+) ")
SLOT = re.compile(r"^> \*\*(PLATE|SCREEN) (\S+) · (\w+)\*\*(.*)$")


class Slot:
    def __init__(self, kind, ident, size, rest, section, line):
        self.kind = kind
        self.id = ident
        self.size = size
        self.section = section
        self.line = line
        fields = [f.strip() for f in rest.split(" · ") if f.strip()]
        self.scenes: list[int] = []
        self.klass = ""
        self.visor_text = ""
        for f in fields:
            if f.startswith("Scene"):
                self.scenes = [int(n) for n in re.findall(r"\d+", f)]
            elif f in ("Teaching", "Reference"):
                self.klass = f
            elif f.startswith("Visor:"):
                self.visor_text = f[len("Visor:"):].strip()

    @property
    def register(self) -> str:
        """The loudest register this slot's visor text names."""
        v = self.visor_text.lower()
        if not v:
            return ""
        if "bluescreen" in v:
            return "bluescreen"
        if "grawlix" in v:
            return "grawlix"
        # `face` as the register, but "loading face" is the state beside the dash.
        if re.search(r"(?<!loading )\bface\b", v):
            return "face"
        if "loading" in v:
            return "loading"
        if "punctuation" in v:
            return "punctuation"
        if "product mark" in v:
            return "product mark"
        if v.startswith("none"):
            return "none"
        return "other"


def known_scenes() -> set[int]:
    nums: set[int] = set()
    for line in open(RILEY, encoding="utf-8"):
        m = re.match(r"^(\d+)\. \*\*", line)
        if m:
            nums.add(int(m.group(1)))
    for line in open(PLAN, encoding="utf-8"):
        m = re.match(r"^\| (\d+) \|", line)
        if m:
            nums.add(int(m.group(1)))
    return nums


def read_guide() -> tuple[list[Slot], dict[str, list[str]]]:
    slots: list[Slot] = []
    bodies: dict[str, list[str]] = defaultdict(list)
    section = ""
    for n, line in enumerate(open(GUIDE, encoding="utf-8"), start=1):
        line = line.rstrip("\n")
        h = HEAD.match(line)
        if h:
            section = h.group(1)
        m = SLOT.match(line)
        if m:
            slots.append(Slot(m.group(1), m.group(2), m.group(3), m.group(4), section, n))
        if section:
            bodies[section].append(line)
    return slots, bodies


def check(slots: list[Slot], bodies: dict[str, list[str]]) -> list[str]:
    bad: list[str] = []
    scenes = known_scenes()
    seen: Counter[str] = Counter(s.id for s in slots)
    for s in slots:
        where = f"{s.id} (docs/21 line {s.line})"
        if seen[s.id] > 1:
            bad.append(f"{where}: id used {seen[s.id]} times")
        if not s.id.startswith(s.section + "-"):
            bad.append(f"{where}: sits under section {s.section}, id names another")
        if s.size not in SIZES and not (s.kind == "SCREEN" and s.size in ("FULL", "HALF")):
            bad.append(f"{where}: size {s.size} is not one of {sorted(SIZES)}")
        if s.kind == "PLATE":
            if s.klass not in ("Teaching", "Reference"):
                bad.append(f"{where}: no Teaching/Reference class")
            if not s.visor_text:
                bad.append(f"{where}: no Visor field")
            if not s.scenes:
                bad.append(f"{where}: no Scene")
            for sc in s.scenes:
                if sc not in scenes:
                    bad.append(f"{where}: scene {sc} is in neither docs/19 nor docs/22")
            reg = s.register
            if s.klass == "Reference" and reg in ("face", "grawlix", "bluescreen"):
                bad.append(f"{where}: a {reg} in a Reference chapter")
            if s.section == SAFETY_SECTION and reg in ("face", "grawlix", "bluescreen"):
                bad.append(f"{where}: a {reg} in the chapter carrying the safety sentences")
            if reg == "bluescreen" and s.section != BSOD_SECTION:
                bad.append(f"{where}: the bluescreen belongs in {BSOD_SECTION} only")
            if reg == "grawlix" and s.klass == "Teaching":
                pass  # allowed, but see --tally: docs/22 §3 budgets it at once in the book
    glyphs_in_bsod = [
        ln for ln in bodies.get(BSOD_SECTION, []) if DOMAIN_GLYPHS & set(ln)
    ]
    if glyphs_in_bsod:
        bad.append(f"section {BSOD_SECTION} carries a domain glyph: {glyphs_in_bsod[0][:60]!r}")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--tally", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--markdown", action="store_true")
    args = ap.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    slots, bodies = read_guide()
    plates = [s for s in slots if s.kind == "PLATE"]
    screens = [s for s in slots if s.kind == "SCREEN"]

    if args.check:
        bad = check(slots, bodies)
        for b in bad:
            print("FAIL", b)
        print(f"plate index: {len(plates)} plates, {len(screens)} screens, {len(bad)} violations")
        return 1 if bad else 0

    if args.tally:
        by_chapter: dict[str, Counter[str]] = defaultdict(Counter)
        for s in plates:
            by_chapter[".".join(s.section.split(".")[:2])][s.register or "?"] += 1
        regs = ["none", "product mark", "punctuation", "loading", "face", "grawlix", "bluescreen", "other", "?"]
        print("chapter   " + "".join(f"{r[:11]:>12}" for r in regs))
        for ch in sorted(by_chapter, key=lambda c: [int(x) for x in c.split(".")]):
            print(f"{ch:<10}" + "".join(f"{by_chapter[ch][r]:>12}" for r in regs))
        print()
        print("sizes: " + ", ".join(f"{k} {v}" for k, v in sorted(Counter(s.size for s in slots).items())))
        return 0

    if args.markdown:
        print("| Id | Size | Scene | Class | Visor |\n|---|---|---|---|---|")
        for s in slots:
            sc = ", ".join(map(str, s.scenes)) or "-"
            print(f"| {s.id} | {s.size} | {sc} | {s.klass or s.kind.title()} | {s.visor_text or '-'} |")
        return 0

    for s in slots:
        sc = ",".join(map(str, s.scenes)) or "-"
        print(f"{s.id:<12} {s.size:<7} scene {sc:<9} {s.klass or s.kind.lower():<9} {s.register or '-':<13} {s.visor_text}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
