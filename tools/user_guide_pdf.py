#!/usr/bin/env python3
"""Export the user guide (docs/21) as a PDF in RackPal's own console style.

    python tools/user_guide_pdf.py
    python tools/user_guide_pdf.py -o somewhere/guide.pdf

Writes build/user-guide/RackPal-User-Guide-<version>.pdf by default.

WHY THE PDF IS NOT COMMITTED. It is derived from docs/21, which moves
every few days, and a committed copy of a moving document is this
corpus's second-copy failure aimed at the people least able to notice it.
This script is the durable half; run it when a copy is wanted.

WHY IT SITS ON docs_pdf.py. That tool already owns the markdown subset the
corpus uses and the headless-Chrome print, including the cold-start retry.
This file adds only what is particular to a guide handed to users: a
cover, a contents page, the console theme, the wordmark on every page, a
running chapter title, and the keyboard reference as an appendix.

THE LOOK IS THE APP'S, AND DARK ON PURPOSE. The user chose dark pages
throughout, because the PDF is for reading on a screen and not for
printing. Every colour below is a `console_palette.dart` constant, and the
faces are the two the app ships (Jost, Space Mono), loaded from the app's
own asset folder so nothing is installed or downloaded.

THE WORDMARK IS READ OUT OF brand.dart, NEVER SET AS TEXT. DR-089: the
face's licence forbids shipping the font, so the outlines in brand.dart
are the only legal source, and one merged path per lockup is what the
licence permits. The cover takes the ruled lockup; the page header takes
the unruled one, because brand.dart measures the rule as a smudge below a
20 px cap height.

WHAT IT DOES NOT DO. Chrome cannot resolve `target-counter()`, so the
contents page links to each chapter rather than printing page numbers
beside it. The PDF's bookmarks carry the same structure.
"""

from __future__ import annotations

import argparse
import datetime
import html
import os
import re
import subprocess
import sys
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import docs_pdf  # noqa: E402  (a sibling tool, not an installed package)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUIDE = os.path.join(ROOT, "docs", "21-user-guide.md")

# The guide's document number, which its sections are numbered under
# (`§21.5.2`). READ OFF THE FILE NAME, because it has already moved once: the
# guide was written as docs/20 in a slot the rule review already held, and a
# number typed into four patterns below would have had to be found four times.
DOC = re.match(r"(\d+)-", os.path.basename(GUIDE)).group(1)
KEYMAP = os.path.join(ROOT, "docs", "reference", "keymap-windows.md")
BRAND = os.path.join(ROOT, "packages", "rackpal_core", "lib", "src", "draw", "brand.dart")
PUBSPEC = os.path.join(ROOT, "apps", "rackpal", "pubspec.yaml")
FONTS = os.path.join(ROOT, "apps", "rackpal", "assets", "fonts")

# console_palette.dart, by name. Nothing here is a new colour.
CANVAS = "#0B0D10"  # kConsoleCanvas
BASE = "#14181E"  # kConsoleBase
CARD = "#222933"  # kConsoleCard
PRIMARY = "#E2E8F0"  # kConsolePrimaryText
CONTROL = "#E4E7EB"  # kConsoleControlText
ACTIVE = "#A0AEC0"  # kConsoleActive
SECONDARY = "#8190A4"  # kConsoleSecondaryText
INACTIVE_SURFACE = "#2D3748"  # kConsoleInactiveSurface
INACTIVE_INK = "#586679"  # kConsoleInactiveInk
NOTICE = "#86BDDA"  # kConsoleNotice
STATUS_LADDER = ["#C8102E", "#E57200", "#FFD100", "#86BDDA", "#C2FFE0"]

# The lockup box from brand.dart: 2788 wide, cap line to baseline 1486, with
# 12 units of overshoot each way that a tight box would clip.
LOCKUP_VIEWBOX = "0 -12 2788 1510"
RILEY_AT = (2244, 811)  # kRackPalRileyLeft, kRackPalRileyTop

# What the keymap reference calls each scope, and what a user calls it.
SCOPE_NAMES = {
    "global": "Anywhere",
    "rack": "Rack",
    "schematic": "Schematic",
    "structure": "Structured Wiring",
    "builder": "Device Builder",
    "plan": "Site",
    "dialog": "Dialogs",
}


def brand_paths() -> dict[str, str]:
    """The three `d` strings, joined from brand.dart's string literals."""
    src = open(BRAND, encoding="utf-8").read()
    out = {}
    for name in ("_ruledD", "_plainD", "_rileyD"):
        m = re.search(r"const String " + name + r" =((?:\s*'[^']*')+)\s*;", src)
        if not m:
            raise SystemExit(f"{name} not found in brand.dart; has the file moved?")
        out[name] = "".join(re.findall(r"'([^']*)'", m.group(1)))
    return out


def wordmark_svg(paths: dict[str, str], *, ruled: bool, fill: str) -> str:
    lockup = paths["_ruledD"] if ruled else paths["_plainD"]
    x, y = RILEY_AT
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{LOCKUP_VIEWBOX}">'
        f'<path d="{lockup}" fill="{fill}"/>'
        f'<g transform="translate({x} {y})"><path d="{paths["_rileyD"]}" fill="{fill}"/></g>'
        "</svg>"
    )


def app_version() -> str:
    m = re.search(r"^version:\s*(\S+)", open(PUBSPEC, encoding="utf-8").read(), re.M)
    return m.group(1) if m else "unknown"


def guide_date() -> str:
    """The date docs/21 last changed, so a PDF says which text it holds.

    Falls back to today when git is unavailable, which is a copy made from
    an export rather than a checkout.
    """
    try:
        out = subprocess.run(
            ["git", "log", "-1", "--format=%cs", "--", GUIDE],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        if out:
            return out
    except (OSError, subprocess.CalledProcessError):
        pass
    return datetime.date.today().isoformat()


def split_guide(md: str) -> tuple[str, list[tuple[int, str, str]]]:
    """(preface, sections). A section is (level, heading, body markdown).

    The H1 is dropped (the cover replaces it) and the repository-only
    `**Related:**` footer goes with it, since every link in it is a path in
    this repo. Each `##` is a section, and so is each `### <DOC>.5.n`, because
    those are the per-view chapters and each deserves its own first page.
    """
    md = re.split(r"\n---\n\n\*\*Related:\*\*", md)[0]
    lines = md.split("\n")
    preface: list[str] = []
    sections: list[tuple[int, str, list[str]]] = []
    for line in lines:
        if line.startswith("# "):
            continue
        h2 = re.match(r"^## (.*)$", line)
        h3 = re.match(rf"^### ({DOC}\.5\.\d+ .*)$", line)
        if h2 or h3:
            sections.append((2 if h2 else 3, (h2 or h3).group(1), []))
            continue
        if sections:
            sections[-1][2].append(line)
        elif line.startswith(">"):
            preface.append(line)
    tidy = []
    for level, head, body in sections:
        text = "\n".join(body).strip()
        # A trailing rule is the markdown's section separator; pages do that
        # job here.
        text = re.sub(r"\n-{3,}\s*$", "", text).strip()
        tidy.append((level, head, text))
    return "\n".join(preface), tidy


def keymap_appendix() -> str:
    """Key and Action per scope, out of the GENERATED reference.

    The Source and Notes columns are for the people who maintain the
    bindings, so they stay in the repository copy.
    """
    md = open(KEYMAP, encoding="utf-8").read()
    parts = re.split(r"^## (\w+)\s*$", md, flags=re.M)
    out = []
    for i in range(1, len(parts), 2):
        scope, body = parts[i], parts[i + 1]
        rows = [
            docs_pdf._row(line)
            for line in body.split("\n")
            if line.startswith("|") and not re.match(r"^\|[\s:|-]+\|?$", line)
        ][1:]
        out.append(f"### {SCOPE_NAMES.get(scope, scope.title())}\n")
        out.append("| Key | What it does |\n|---|---|")
        out.extend(f"| {r[0]} | {r[1]} |" for r in rows if len(r) >= 2)
        out.append("")
    return "\n".join(out)


def rewrite_links(md: str) -> str:
    """Point the guide at this PDF instead of at the repository."""
    md = re.sub(
        r"\*\*\[`docs/reference/keymap-windows\.md`\]\(reference/keymap-windows\.md\)\*\*",
        "**[Appendix A, Keyboard reference](#appendix-a)**",
        md,
    )
    # The repository copy's instruction to its maintainers, which a reader of
    # the PDF can do nothing with.
    md = md.replace(" Do not edit it by hand.", "")
    # Any other link into the repo becomes its text: a path is not a place
    # a reader of a PDF can go.
    return re.sub(r"\[([^\]]+)\]\((?!#|https?:)[^)]+\)", r"\1", md)


def link_sections(fragment: str, ids: set[str]) -> str:
    """`§21.5.2` becomes a link wherever the PDF holds that section."""

    def one(m: "re.Match[str]") -> str:
        anchor = "s" + m.group(1).replace(".", "-")
        if anchor not in ids:
            return m.group(0)
        return f'<a href="#{anchor}">{m.group(0)}</a>'

    return re.sub(rf"§({DOC}(?:\.\d+)+)", one, fragment)


def short_title(heading: str) -> str:
    """What the running header says: the number and the words before a colon."""
    return heading.split(":")[0].strip()


def css(header_mark: str) -> str:
    font = "file:///" + FONTS.replace("\\", "/")
    mark = "data:image/svg+xml;utf8," + urllib.parse.quote(header_mark)
    return f"""
@font-face {{ font-family: Jost; font-weight: 400; src: url("{font}/Jost-Regular.ttf"); }}
@font-face {{ font-family: Jost; font-weight: 500; src: url("{font}/Jost-Medium.ttf"); }}
@font-face {{ font-family: "Space Mono"; font-weight: 400; src: url("{font}/SpaceMono-Regular.ttf"); }}
@font-face {{ font-family: "Space Mono"; font-weight: 700; src: url("{font}/SpaceMono-Bold.ttf"); }}

@page {{
  size: Letter; margin: 0.95in 0.8in 0.85in 0.8in; background: {CANVAS};
  @top-left {{
    content: url("{mark}"); width: 0.62in; vertical-align: bottom;
    padding-bottom: 10pt;
  }}
  @bottom-left {{
    content: var(--footer, "");
    font: 7pt "Space Mono"; color: {INACTIVE_INK}; vertical-align: top;
    padding-top: 12pt;
  }}
  @bottom-right {{
    content: counter(page) " / " counter(pages);
    font: 7.5pt "Space Mono"; color: {SECONDARY}; vertical-align: top;
    padding-top: 12pt;
  }}
}}
@page cover {{
  margin: 0;
  @top-left {{ content: none; }}
  @bottom-left {{ content: none; }}
  @bottom-right {{ content: none; }}
}}

* {{ box-sizing: border-box; }}
html {{
  background: {CANVAS}; color: {PRIMARY};
  -webkit-print-color-adjust: exact; print-color-adjust: exact;
}}
body {{ margin: 0; font: 400 9.8pt/1.58 Jost, sans-serif; }}

/* ── cover ─────────────────────────────────────────────────────────── */
.cover {{
  page: cover; position: relative; width: 8.5in; height: 11in; overflow: hidden;
  background:
    repeating-linear-gradient(0deg, transparent 0 0.3in, {BASE} 0.3in calc(0.3in + 1px)),
    repeating-linear-gradient(90deg, transparent 0 0.3in, {BASE} 0.3in calc(0.3in + 1px)),
    {CANVAS};
}}
.cover .panel {{
  position: absolute; left: 0.9in; right: 0.9in; top: 1.35in; bottom: 1.1in;
  background: {CANVAS}; border: 1px solid {INACTIVE_SURFACE}; border-radius: 6pt;
  padding: 0.75in 0.7in;
}}
.cover .mark {{ width: 4.6in; }}
.cover .title {{
  margin-top: 0.75in; font: 500 32pt/1.1 Jost; color: {PRIMARY};
  letter-spacing: -0.01em;
}}
.cover .subtitle {{ margin-top: 8pt; font: 400 14pt/1.3 Jost; color: {SECONDARY}; }}
.cover .ladder {{ display: flex; width: 2.6in; height: 4pt; margin-top: 22pt; }}
.cover .ladder span {{ flex: 1; }}
.cover .meta {{
  margin-top: 18pt; font: 400 8pt/1.7 "Space Mono"; color: {SECONDARY};
  letter-spacing: 0.08em; text-transform: uppercase;
}}
.cover .foot {{
  position: absolute; left: 0.7in; right: 0.7in; bottom: 0.6in;
  font: 400 8.5pt/1.5 Jost; color: {INACTIVE_INK};
  border-top: 1px solid {INACTIVE_SURFACE}; padding-top: 10pt;
}}

/* ── contents ──────────────────────────────────────────────────────── */
.front {{ break-before: page; page: front; }}
/* HEADINGS SET NO line-height, AND THAT IS A CHROME WORKAROUND, NOT TASTE.
   A heading in Jost at display size with ANY explicit line-height has its
   text written into the PDF bookmark twice ("ContentsContents"). Bisected
   rule by rule on Chrome 152: the font shorthand triggers it because it
   sets line-height, the same longhands without it do not, and it is
   deterministic. The default line-height is fine for one-line headings. */
.front h1 {{ font-family: Jost; font-weight: 500; font-size: 24pt; margin: 0 0 10pt; }}
.toc {{ list-style: none; padding: 0; margin: 0 0 20pt; }}
.toc li {{ margin: 0; border-bottom: 1px solid {BASE}; }}
.toc a {{ display: flex; gap: 14pt; padding: 2.3pt 0; color: {PRIMARY}; text-decoration: none; }}
.toc .n {{ font: 400 8.5pt/1.9 "Space Mono"; color: {NOTICE}; width: 0.62in; flex: none; }}
.toc li.sub a {{ padding-left: 0.3in; color: {ACTIVE}; font-size: 9.2pt; }}
.about {{
  background: {BASE}; border-left: 2pt solid {NOTICE}; border-radius: 0 4pt 4pt 0;
  padding: 10pt 14pt; margin-top: 6pt; color: {ACTIVE}; font-size: 8.8pt;
  line-height: 1.5; break-inside: avoid;
}}
.about h2 {{ font-family: Jost; font-weight: 500; font-size: 11pt; color: {PRIMARY}; margin: 0 0 6pt; border: 0; padding: 0; }}
.about p {{ margin: 0 0 6pt; }}

/* ── chapters ──────────────────────────────────────────────────────── */
section.chapter {{ break-before: page; }}
h2.chapter-head, h3.chapter-head {{
  margin: 0 0 18pt; padding: 0 0 12pt; border-bottom: 1px solid {INACTIVE_SURFACE};
  font-family: Jost; font-weight: 500; font-size: 23pt; color: {PRIMARY};
  letter-spacing: -0.005em;
}}
/* INLINE, NOT A BLOCK ABOVE THE TITLE: Chrome collapses the space after a
   block-level span, and the bookmark then reads "21.1What it is". */
.chapter-head .num {{
  font-family: "Space Mono"; font-weight: 400; font-size: 12pt;
  color: {NOTICE}; margin-right: 8pt; vertical-align: 3pt;
}}
h3 {{
  font-family: Jost; font-weight: 500; font-size: 14pt; color: {PRIMARY};
  margin: 20pt 0 8pt;
  break-after: avoid;
}}
/* NOT text-transform: uppercase, which Chrome carries into the bookmark,
   so every task heading would shout from the outline. */
h4 {{
  font-family: Jost; font-weight: 500; font-size: 10.6pt; color: {NOTICE};
  margin: 16pt 0 6pt; break-after: avoid;
}}
p {{ margin: 0 0 8pt; orphans: 3; widows: 3; }}
ul, ol {{ margin: 0 0 9pt; padding-left: 16pt; }}
li {{ margin: 0 0 4pt; }}
li::marker {{ color: {NOTICE}; }}
li > p {{ margin-bottom: 5pt; }}
strong {{ font-weight: 500; color: #FFFFFF; }}
em {{ color: {CONTROL}; }}
a {{ color: {NOTICE}; text-decoration: none; }}
code {{
  font: 400 8.2pt/1.4 "Space Mono"; color: {CONTROL};
  background: {CARD}; border: 1px solid {INACTIVE_SURFACE}; border-radius: 2.5pt;
  padding: 0 2.5pt; white-space: nowrap;
}}
pre {{
  background: {BASE}; border-left: 2pt solid {NOTICE}; border-radius: 0 4pt 4pt 0;
  padding: 9pt 12pt; margin: 0 0 10pt; break-inside: avoid;
}}
pre code {{ background: none; border: 0; padding: 0; font-size: 8.4pt; white-space: pre; }}
blockquote {{
  background: {BASE}; border-left: 2pt solid {NOTICE}; border-radius: 0 4pt 4pt 0;
  margin: 0 0 10pt; padding: 9pt 13pt; color: {ACTIVE};
}}
blockquote p:last-child {{ margin-bottom: 0; }}
hr {{ display: none; }}
table {{
  width: 100%; border-collapse: collapse; margin: 2pt 0 12pt; font-size: 8.6pt;
  line-height: 1.45;
}}
th {{
  background: {CARD}; color: {ACTIVE}; text-align: left; font-weight: 500;
  font-size: 7.4pt; letter-spacing: 0.08em; text-transform: uppercase;
  padding: 5pt 7pt;
}}
td {{ padding: 5pt 7pt; border-bottom: 1px solid {INACTIVE_SURFACE}; vertical-align: top; }}
tbody tr:nth-child(even) td {{ background: {BASE}; }}
tr {{ break-inside: avoid; }}
th:empty {{ display: none; }}
.keys table {{ table-layout: fixed; }}
.keys th:first-child, .keys td:first-child {{ width: 1.9in; }}
table code {{ white-space: normal; }}
"""


def page_rules(sections: list[tuple[str, str]]) -> str:
    """One named page per chapter, carrying its running header."""
    rules = []
    for name, title in sections:
        rules.append(
            f"@page {name} {{ @top-right {{ content: {css_string(title)}; "
            f"font: 400 8.4pt Jost; color: {SECONDARY}; vertical-align: bottom; "
            f"padding-bottom: 11pt; }} }}"
        )
    return "\n".join(rules)


def css_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build(out: str) -> None:
    paths = brand_paths()
    version = app_version()
    date = guide_date()
    preface, sections = split_guide(open(GUIDE, encoding="utf-8").read())

    ids: set[str] = set()
    toc: list[str] = []
    chapters: list[str] = []
    named: list[tuple[str, str]] = [("front", "Contents")]
    for level, head, body in sections:
        anchor = docs_pdf._anchor(head, ids)
        num, _, title = head.partition(" ")
        page = f"p{anchor}"
        named.append((page, short_title(head)))
        cls = "sub" if level == 3 else ""
        toc.append(
            f'<li class="{cls}"><a href="#{anchor}"><span class="n">{html.escape(num)}'
            f"</span><span>{docs_pdf._inline(title)}</span></a></li>"
        )
        body_html = docs_pdf.convert(rewrite_links(body), "docs/21-user-guide.md", ids)
        chapters.append(
            f'<section class="chapter" style="page: {page}">'
            f'<h{level} class="chapter-head" id="{anchor}"><span class="num">'
            f"{html.escape(num)}</span> {docs_pdf._inline(title)}</h{level}>"
            f"{body_html}</section>"
        )

    appendix_id = "appendix-a"
    ids.add(appendix_id)
    named.append(("pappendix", "Appendix A · Keyboard reference"))
    toc.append(
        f'<li><a href="#{appendix_id}"><span class="n">A</span>'
        "<span>Keyboard reference</span></a></li>"
    )
    chapters.append(
        '<section class="chapter keys" style="page: pappendix">'
        f'<h2 class="chapter-head" id="{appendix_id}"><span class="num">APPENDIX A'
        "</span> Keyboard reference</h2>"
        "<p>Every key RackPal binds on Windows, by where it works. Generated from "
        "the application's own keybinding registry, so it cannot disagree with "
        "the software.</p>"
        f"{docs_pdf.convert(keymap_appendix(), 'keymap-windows.md', ids)}</section>"
    )

    body = "".join(chapters)
    body = link_sections(body, ids)
    # `> ?` AND NOT `>\s?`: `\s` matches the newline after a bare `>`, which
    # is the preface's paragraph break, and ran its paragraphs together.
    about = docs_pdf.convert(re.sub(r"^> ?", "", preface, flags=re.M), "preface", ids)
    about = link_sections(about, ids)

    ladder = "".join(f'<span style="background:{c}"></span>' for c in STATUS_LADDER)
    cover = (
        '<div class="cover"><div class="panel">'
        f'<div class="mark">{wordmark_svg(paths, ruled=True, fill=PRIMARY)}</div>'
        '<div class="title">User guide</div>'
        '<div class="subtitle">Running a job, view by view</div>'
        f'<div class="ladder">{ladder}</div>'
        f'<div class="meta">Version {html.escape(version)} · {date}<br>'
        "Windows · pre-release</div>"
        '<div class="foot">For AV and low-voltage integrators. Describes what '
        f"RackPal does today; section {DOC}.8 lists what is not built yet. Code "
        "AGPLv3-or-later, device catalog CC0.</div>"
        "</div></div>"
    )
    front = (
        '<div class="front"><h1>Contents</h1>'
        f'<ul class="toc">{"".join(toc)}</ul>'
        f'<div class="about"><h2>About this guide</h2>{about}</div></div>'
    )

    header_mark = wordmark_svg(paths, ruled=False, fill=SECONDARY)
    footer = css_string(f"RackPal user guide · v{version}")
    style = (
        css(header_mark).replace('var(--footer, "")', footer)
        + page_rules(named)
    )
    page = (
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        f"<title>RackPal user guide {html.escape(version)}</title>"
        f"<style>{style}</style></head><body>{cover}{front}{body}</body></html>"
    )

    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    docs_pdf.print_pdf(page, out, ("--generate-pdf-document-outline",))
    print(f"  wrote {out}  ({os.path.getsize(out):,} bytes)")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("-o", "--out", help="output PDF")
    args = ap.parse_args()
    out = args.out or os.path.join(
        ROOT, "build", "user-guide", f"RackPal-User-Guide-{app_version()}.pdf"
    )
    build(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
