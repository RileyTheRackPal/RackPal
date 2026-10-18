---
type: CI Gate
title: Glyph coverage
description: Every non-ASCII character a Dart string literal can draw exists in both bundled Jost weights, checked against the font binary. It is the only gate that imports a third-party Python package, which is why it sat in run_local.ps1 for two months and in neither pipeline.
tags: [gate, ci, fonts, glyphs, jost, fonttools, dr-090, dr-249, dr-248]
timestamp: 2026-10-18T00:00:00Z
resource: tools/glyph_coverage_check.py
status: enforced
---

`python tools/glyph_coverage_check.py` is the `glyph coverage` gate of
`tools/ci/run_local.ps1` and the `Gate: glyph coverage (DR-090)` step of both
pipelines. Ruled by DR-090 section 11.89.8; the face it holds the product to is DR-249's.

# What it defends

The defect shipped twice. A signal glyph went out as a codepoint the face did not carry,
and `NET-NEN006` printed over a net name; then four arrows and primes were absent from
Jost and two live schedule cells emitted them onto printed sheets T6.10 and T6.11. An
absent codepoint maps to `.notdef`, which draws as **nothing** rather than a box.

Both failures share a shape: **both backends emitted identical ops and only the font
behind one of them differed**, so every op-level gate passed. The display list cannot
see it. The gate reads the font binary, which is the only place it is visible.

It checks every non-ASCII character in a Dart string literal under `packages/*/lib` and
`apps/*/lib` against the **intersection** of the two bundled weights' cmaps (a caller who
picks `w500` must not lose a glyph by doing so), plus an explicit `REQUIRED` set so an
empty scan cannot pass vacuously. The `MIN_LITERALS` floor does the same for the regex.

# Why it was missing from the pipelines

It was added on 2026-08-25 (`b7b5ac2e`, board `#772`); the pipeline's first run was
2026-08-27, with a step list written from the gates of the day. **No commit ever chose to
leave it out**, and CI never ran it until 2026-10-18, found only because the step list
was being copied for the macOS definition (DR-255).

The reason it was easy to miss is the real finding: every other gate script is "standard
library only", which is what the pipelines assume of `python`. This one imports
`fontTools`, which a clean agent does not have. Copying the gate line alone would have
produced a red step on the first run, so the pipelines now install it first, from
`tools/ci/requirements.txt`: pinned, with the wheel's sha256, installed with
`--require-hashes --only-binary=:all:`, on the model of `pubspec.lock` (DR-248).

# Blind spots

* **Runtime-composed strings.** A user who names a rack `Sala de máquinas` is outside it
  and always will be; so is catalogue JSON and the seeded registries, which are data.
* **System-font widgets.** Anything `rackpal_ui` draws with a system family rather than
  the bundled one cannot be told apart from a bundled draw.
* **`PATH_BACKED` is an exemption list.** Seventeen registry-data glyphs are drawn as
  geometry and never reach a font. The list is closed and reasoned, and a codepoint that
  migrates into a widget label fails the moment it appears in a `rackpal_ui` literal.
* **It is a floor, not a proof.** It says the codepoints exist, not that they look right.
* **The pin has to be moved by hand.** A new fontTools needs a reviewed edit to
  `tools/ci/requirements.txt`; the local run uses whatever the developer has installed.

# Citations

[1] `tools/glyph_coverage_check.py`, its header (what it covers and does not)
[2] `tools/ci/requirements.txt` (the pin and why it is hashed)
[3] `docs/canonical-decisions.md` DR-090 section 11.89.8, DR-249 section 11.248.4
