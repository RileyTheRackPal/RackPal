---
type: Invariant
title: Package layering — what may import what
description: rackmate_core imports no Flutter; rackmate_export never imports rackmate_ui. Both are enforced by tests, and both shape where new code goes.
tags: [invariant, architecture, layering]
timestamp: 2026-07-28T12:00:00Z
status: enforced
---

# The packages

| Package | Role | May not import |
|---|---|---|
| `rackmate_core` | pure-Dart domain: model, commands, persistence, derivations, the drawing IR | `package:flutter`, `dart:ui`, `package:pdf` |
| `rackmate_ui` | Flutter widgets and canvases | — |
| `rackmate_export` | PDF/sheet backends | `rackmate_ui` |
| `rackmate_text` | text measurement | — |
| `apps/rackmate` | the shell, storage, session | — |

# Why it keeps deciding things

The layering is not bookkeeping; it has settled real design questions:

- **CR-071 put the schematic symbol in core.** *"A symbol only `rackmate_ui` can
  draw is a symbol that cannot print."* Hence `symbol_layer.dart` and the
  Sugiyama layout live under `core/draw/`, not in the UI package.
- **It decided [DR-010](/decisions/dr-010-seeded-registries.md).** Core imports no
  Flutter, so it **cannot load an asset**: `rootBundle` is Flutter-only. That is
  why the registry master is a seeded Dart catalog rather than
  `assets/catalog/registries.json`.
- **It shapes every derivation.** A number the screen shows and the PDF prints
  must be computed exactly once, in core, which is why the schedule derivation
  lives in `core/derived/` and both the tab and the sheet builders consume it.

# A violation in waiting

`wire_trace.dart`, the deterministic per-link orthogonal staircase, sits in
`rackmate_ui` because M2-D owned `core/draw/scene/` when M2-E needed it. It is
pure geometry over core types.

**But §11.1.2 says every exported interconnect sheet renders `drawn` by
construction, and `rackmate_export` may never import `rackmate_ui`.** So as
things stand *the exporter cannot draw a wire*, and M6's sheets are unbuildable
until it moves. Recorded before M6 starts rather than discovered during it.

**AND IT HAS A SECOND CONSUMER NOW, WHICH IS HOW A DEBT GETS ITS PRICE.**
`PLAN-H/3`'s brief told the plan sheet to *reuse the schematic's tag-pill
geometry*, and `_PillSizer` is private to that same file. The sheet builders live
in core, so the pill was unreachable from there too.

**The chapter did not move the file, and that is the decision rather than the
omission** ([DR-150](/decisions/dr-150-a-pin-has-no-domain.md) §11.149.6): a
thousand-line relocation is M6's migration and would have arrived inside a chapter
about callouts. What it took was the **reasoning**, cited at each site it is used:
near-edge anchoring rather than centring, height from the type size rather than
from font metrics, a stadium radius. **A borrowed rule with its citation is not a
copy of the code**, and the debt is unchanged and still M6's.

# Enforcement

- `no_flutter_import_test.dart` fails the build on a Flutter import in core.
- `storage_layering_test.dart` RULE 1 permits `dart:io` in exactly **two** files.
  This is why the platform split is an injected `isWindows` flag rather than a
  `Platform.isWindows` call, see [DR-009](/decisions/dr-009-macos-in-v1.md).
- `internal_setter_grep_test.dart` asserts that `@internal` entity setters are
  called only from `src/commands/`, it scans `rackmate_ui` too, deliberately,
  because a panel of editable fields is the wrong place to rely on a lint.

# Practical consequence

**New shared logic goes in core by default.** If it cannot, that is usually a
signal it is presentation rather than domain. When something in core seems to
need Flutter, the answer has so far always been an injected seam, not a
dependency.

# Citations

[1] `packages/rackmate_core/test/no_flutter_import_test.dart`
[2] `packages/rackmate_core/test/internal_setter_grep_test.dart`
[3] `packages/rackmate_core/lib/rackmate_core.dart`, the barrel's own header
