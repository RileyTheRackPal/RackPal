---
type: Invariant
title: Package layering — what may import what
description: rackmate_core imports no Flutter; rackmate_export never imports rackmate_ui. Both are enforced by tests, and both shape where new code goes.
tags: [invariant, architecture, layering]
timestamp: 2026-07-28T00:00:00Z
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

The layering is not bookkeeping — it has settled real design questions:

- **CR-071 put the schematic symbol in core.** *"A symbol only `rackmate_ui` can
  draw is a symbol that cannot print."* Hence `symbol_layer.dart` and the
  Sugiyama layout live under `core/draw/`, not in the UI package.
- **It decided [DR-010](/decisions/dr-010-seeded-registries.md).** Core imports no
  Flutter, so it **cannot load an asset** — `rootBundle` is Flutter-only. That is
  why the registry master is a seeded Dart catalog rather than
  `assets/catalog/registries.json`.
- **It shapes every derivation.** A number the screen shows and the PDF prints
  must be computed exactly once, in core — which is why the schedule derivation
  lives in `core/derived/` and both the tab and the sheet builders consume it.

# Enforcement

- `no_flutter_import_test.dart` fails the build on a Flutter import in core.
- `storage_layering_test.dart` RULE 1 permits `dart:io` in exactly **two** files.
  This is why the platform split is an injected `isWindows` flag rather than a
  `Platform.isWindows` call — see [DR-009](/decisions/dr-009-macos-in-v1.md).
- `internal_setter_grep_test.dart` asserts that `@internal` entity setters are
  called only from `src/commands/` — it scans `rackmate_ui` too, deliberately,
  because a panel of editable fields is the wrong place to rely on a lint.

# Practical consequence

**New shared logic goes in core by default.** If it cannot, that is usually a
signal it is presentation rather than domain. When something in core seems to
need Flutter, the answer has so far always been an injected seam, not a
dependency.

# Citations

[1] `packages/rackmate_core/test/no_flutter_import_test.dart`
[2] `packages/rackmate_core/test/internal_setter_grep_test.dart`
[3] `packages/rackmate_core/lib/rackmate_core.dart` — the barrel's own header
