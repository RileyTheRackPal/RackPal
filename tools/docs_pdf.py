#!/usr/bin/env python3
"""Render corpus markdown to a shareable PDF.

    python3 tools/docs_pdf.py docs/19-riley.md
    python3 tools/docs_pdf.py docs/19-riley.md docs/00-overview.md -o pack.pdf

WHY THIS EXISTS RATHER THAN pandoc. Neither pandoc, wkhtmltopdf,
weasyprint nor reportlab is installed on this machine, and adding a
toolchain dependency so a document can be emailed is a poor trade. Chrome
IS installed, ships a headless PDF printer, and is already the thing every
reader of the output has. So the pipeline is markdown -> HTML -> Chrome.

WHY A CONVERTER AND NOT A LIBRARY. The corpus uses a small, knowable
subset: ATX headings, pipe tables, blockquotes, bullet and ordered lists,
fenced code, `**bold**`, `*italic*`, `` `code` `` and links. That subset
is worth 200 lines of parser and is not worth a dependency. **What it
does NOT support it says so about**, loudly, rather than dropping markup
silently: see [_UNSUPPORTED].

THE TABLES ARE THE WHOLE REASON THIS IS CAREFUL. docs/19's fixed-facts
table and the tier/posture table carry the document's actual content, and
a converter that mangled a pipe table would lose the half a reader needs.
"""

from __future__ import annotations

import argparse
import html
import os
import re
import subprocess
import sys
import tempfile

# Markdown this converter deliberately does not handle. Encountering one
# is reported rather than dropped: a design document that silently lost a
# footnote is worse than one that failed to build.
_UNSUPPORTED = {
    "footnote": re.compile(r"^\[\^[^\]]+\]:"),
    "html block": re.compile(r"^<(?!!--)[a-zA-Z]"),
    "setext heading": re.compile(r"^(=|-){3,}\s*$"),
}

_CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]

_CSS = """
@page { size: Letter; margin: 18mm 16mm 20mm 16mm; }
* { box-sizing: border-box; }
body {
  font: 10.5pt/1.55 "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  color: #1b1b1b; margin: 0; -webkit-print-color-adjust: exact;
}
.doc + .doc { page-break-before: always; }
h1 {
  font-size: 21pt; line-height: 1.15; margin: 0 0 2mm; letter-spacing: -0.01em;
  border-bottom: 2.5pt solid #1b1b1b; padding-bottom: 3mm;
}
h2 {
  font-size: 14pt; margin: 9mm 0 2.5mm; letter-spacing: -0.005em;
  border-bottom: 0.6pt solid #c8c8c8; padding-bottom: 1.5mm;
  page-break-after: avoid;
}
h3 { font-size: 11.5pt; margin: 6mm 0 2mm; page-break-after: avoid; }
h4 { font-size: 10.5pt; margin: 5mm 0 1.5mm; color: #444; page-break-after: avoid; }
p { margin: 0 0 3mm; orphans: 3; widows: 3; }
ul, ol { margin: 0 0 3mm; padding-left: 6mm; }
li { margin: 0 0 1.5mm; }
strong { font-weight: 650; }
code {
  font: 9pt/1.4 "Cascadia Mono", Consolas, "SF Mono", monospace;
  background: #f2f2f0; padding: 0.3mm 1mm; border-radius: 1.5pt;
}
pre {
  background: #f6f6f4; border-left: 2.5pt solid #c8c8c8; padding: 3mm 4mm;
  margin: 0 0 4mm; overflow-x: auto; page-break-inside: avoid;
}
pre code { background: none; padding: 0; font-size: 8.5pt; }
blockquote {
  margin: 0 0 4mm; padding: 2mm 0 2mm 5mm; border-left: 2.5pt solid #8a8a8a;
  color: #3a3a3a; font-style: italic;
}
blockquote p:last-child { margin-bottom: 0; }
hr { border: 0; border-top: 0.6pt solid #d4d4d4; margin: 7mm 0; }
table {
  border-collapse: collapse; width: 100%; margin: 0 0 4mm; font-size: 9pt;
  page-break-inside: auto;
}
th, td {
  border: 0.5pt solid #cfcfcf; padding: 1.8mm 2.2mm; text-align: left;
  vertical-align: top;
}
th { background: #efefec; font-weight: 650; }
tr { page-break-inside: avoid; page-break-after: auto; }
a { color: #1b1b1b; text-decoration: underline; text-underline-offset: 1.5pt; }
.meta {
  font-size: 8.5pt; color: #666; margin: 0 0 7mm;
  border-left: 2.5pt solid #d4d4d4; padding-left: 3mm;
}
"""


def _inline(text: str) -> str:
    """Inline markdown to HTML, code spans first so nothing rewrites them."""
    out: list[str] = []
    # CODE SPANS ARE EXTRACTED BEFORE ANYTHING ELSE RUNS. `**` inside a
    # code span is data, and a converter that bolded it would corrupt
    # exactly the identifiers this corpus is made of.
    parts = re.split(r"(`[^`]+`)", text)
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 1:
            out.append(f"<code>{html.escape(part[1:-1])}</code>")
            continue
        s = html.escape(part)
        s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', s)
        s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
        s = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<em>\1</em>", s)
        out.append(s)
    return "".join(out)


def _row(line: str) -> list[str]:
    cells = line.strip().strip("|").split("|")
    return [c.strip() for c in cells]


def convert(md: str, source: str) -> str:
    """One markdown document to an HTML fragment."""
    lines = md.split("\n")
    out: list[str] = []
    i = 0
    warned: set[str] = set()

    def close(stack: list[str]) -> None:
        while stack:
            out.append(f"</{stack.pop()}>")

    stack: list[str] = []
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        for name, pattern in _UNSUPPORTED.items():
            if pattern.match(stripped) and stripped not in ("---", "***"):
                if name not in warned:
                    warned.add(name)
                    print(
                        f"  ! {source}:{i + 1}: {name} is not supported and "
                        f"is rendered as plain text",
                        file=sys.stderr,
                    )

        if not stripped:
            close(stack)
            i += 1
            continue

        # Fenced code.
        if stripped.startswith("```"):
            close(stack)
            i += 1
            body: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                body.append(lines[i])
                i += 1
            i += 1
            out.append(f"<pre><code>{html.escape(chr(10).join(body))}</code></pre>")
            continue

        # Horizontal rule, checked before headings so `---` is not a setext.
        if re.fullmatch(r"(-{3,}|\*{3,}|_{3,})", stripped):
            close(stack)
            out.append("<hr>")
            i += 1
            continue

        # ATX heading.
        m = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if m:
            close(stack)
            level = len(m.group(1))
            out.append(f"<h{level}>{_inline(m.group(2))}</h{level}>")
            i += 1
            continue

        # Pipe table: a header row followed by a delimiter row.
        if (
            stripped.startswith("|")
            and i + 1 < len(lines)
            and re.fullmatch(r"\|[\s:|-]+\|?", lines[i + 1].strip())
        ):
            close(stack)
            head = _row(stripped)
            i += 2
            out.append("<table><thead><tr>")
            out.extend(f"<th>{_inline(c)}</th>" for c in head)
            out.append("</tr></thead><tbody>")
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = _row(lines[i])
                # SHORT ROWS ARE PADDED RATHER THAN DROPPED. A row with a
                # missing trailing cell is a typo in the source, and
                # losing the whole row would hide it.
                cells += [""] * (len(head) - len(cells))
                out.append("<tr>")
                out.extend(f"<td>{_inline(c)}</td>" for c in cells[: len(head)])
                out.append("</tr>")
                i += 1
            out.append("</tbody></table>")
            continue

        # Blockquote.
        if stripped.startswith(">"):
            close(stack)
            body = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                body.append(lines[i].strip().lstrip(">").strip())
                i += 1
            out.append(f"<blockquote><p>{_inline(' '.join(body))}</p></blockquote>")
            continue

        # Lists. Continuation lines are joined so a wrapped bullet stays
        # one item, which the corpus's hard wrap makes the normal case.
        m = re.match(r"^(\s*)([-*+]|\d+\.)\s+(.*)$", line)
        if m:
            want = "ol" if m.group(2)[0].isdigit() else "ul"
            if not stack or stack[-1] != want:
                close(stack)
                out.append(f"<{want}>")
                stack.append(want)
            body = [m.group(3)]
            i += 1
            while i < len(lines):
                nxt = lines[i]
                if not nxt.strip():
                    break
                if re.match(r"^(\s*)([-*+]|\d+\.)\s+", nxt):
                    break
                if re.match(r"^(#{1,6})\s|^\||^>|^```", nxt.strip()):
                    break
                body.append(nxt.strip())
                i += 1
            out.append(f"<li>{_inline(' '.join(body))}</li>")
            continue

        # Paragraph, joining the corpus's hard wrap back into one flow.
        close(stack)
        body = [stripped]
        i += 1
        while i < len(lines):
            nxt = lines[i].strip()
            if not nxt:
                break
            if re.match(r"^(#{1,6})\s|^\||^>|^```|^(-{3,}|\*{3,})$", nxt):
                break
            if re.match(r"^([-*+]|\d+\.)\s+", nxt):
                break
            body.append(nxt)
            i += 1
        out.append(f"<p>{_inline(' '.join(body))}</p>")

    close(stack)
    return "\n".join(out)


def find_chrome() -> str:
    for path in _CHROME_CANDIDATES:
        if os.path.exists(path):
            return path
    raise SystemExit(
        "No Chrome or Edge found. This tool prints through a headless "
        "browser because no PDF toolchain is installed; install one of "
        f"these, or add its path to _CHROME_CANDIDATES:\n  "
        + "\n  ".join(_CHROME_CANDIDATES)
    )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("sources", nargs="+", help="markdown files, in order")
    ap.add_argument("-o", "--out", help="output PDF (default: first source)")
    args = ap.parse_args()

    docs = []
    for src in args.sources:
        with open(src, encoding="utf-8") as fh:
            text = fh.read()
        print(f"  reading {src}")
        docs.append(
            f'<div class="doc">'
            f'<div class="meta">{html.escape(src)} · RackPal</div>'
            f"{convert(text, src)}</div>"
        )

    out = args.out or os.path.splitext(args.sources[0])[0] + ".pdf"
    page = (
        "<!doctype html><html><head><meta charset='utf-8'>"
        f"<style>{_CSS}</style></head><body>{''.join(docs)}</body></html>"
    )

    with tempfile.TemporaryDirectory() as tmp:
        html_path = os.path.join(tmp, "doc.html")
        with open(html_path, "w", encoding="utf-8") as fh:
            fh.write(page)
        chrome = find_chrome()
        # A THROWAWAY PROFILE, so this never touches the user's own Chrome
        # session and never blocks on one already running.
        subprocess.run(
            [
                chrome,
                "--headless",
                "--disable-gpu",
                f"--user-data-dir={os.path.join(tmp, 'profile')}",
                "--no-pdf-header-footer",
                f"--print-to-pdf={os.path.abspath(out)}",
                "file:///" + html_path.replace("\\", "/"),
            ],
            check=True,
            capture_output=True,
        )

    if not os.path.exists(out):
        raise SystemExit(f"Chrome reported success but {out} was not written.")
    print(f"  wrote {out}  ({os.path.getsize(out):,} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
