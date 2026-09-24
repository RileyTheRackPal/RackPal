---
type: Invariant
title: Package layering — what may import what
description: rackmate_core imports no Flutter; rackmate_export never imports rackmate_ui. Both are enforced by tests, and both shape where new code goes.
tags: [invariant, architecture, layering]
timestamp: 2026-09-23T12:00:00Z
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

# A violation that waited, and was paid (2026-09-23)

`wire_trace.dart`, the deterministic per-link orthogonal staircase, sat in
`rackpal_ui` from M2-E because M2-D owned `core/draw/scene/` when M2-E needed
it. It was always pure geometry over core types.

**§11.1.2 says every exported interconnect sheet renders `drawn` by
construction, and `rackpal_export` may never import `rackpal_ui`.** So for eight
weeks *the exporter could not draw a wire*, and M6's sheets were unbuildable
until it moved. Recorded before M6 started rather than discovered during it,
which is the part that worked.

**It picked up a second consumer while it waited.** `PLAN-H/3`'s brief told the
plan sheet to *reuse the schematic's tag-pill geometry*, and `_PillSizer` is
private to that same file. [DR-150](/decisions/dr-150-a-pin-has-no-domain.md)
§11.149.6 declined to move a thousand lines inside a chapter about callouts and
borrowed the **reasoning** instead, cited at each site.

**The full-tree review (`#97`, `#98`) moved it** to
`rackpal_core/src/draw/scene/wire_trace.dart` as a pure move: explicit `src/`
imports in place of the barrel, one export line in each barrel, and no test
changed beyond two imports that became unused. `_PillSizer` is still private,
so sharing it with `plan_callouts.dart` is now a visibility change rather than a
layering one, and it has not been made.

# Enforcement

- `no_flutter_import_test.dart` fails the build on a Flutter import in core.
- `rackpal_export/test/support/source_gate.dart` fails it on any route from the
  exporter to `rackpal_ui`, including the three a naive `import` regex misses:
  a barrel re-export, a conditional import, and `import"…"` with no space. A pub
  workspace shares one package config, so the missing pubspec dependency alone
  would not stop the import resolving.
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
