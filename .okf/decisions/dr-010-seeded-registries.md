---
type: Design Ruling
title: DR-010 — the registries ship as a seeded Dart catalog
description: The master registry is Dart, not a JSON asset; the subset is written at document creation, never elided at save; SignalFamilyDef regains its dash.
tags: [ruling, registries, palette, m2, dr-010]
timestamp: 2026-07-28T00:00:00Z
ruling_id: DR-010
canon_section: "11.10"
status: built
---

Settled by the user on 2026-07-28, at the point M2-B became the first code in the
repository ever to read `doc.registries`.

# The finding that forced it

`registries.dart` claimed the content shipped as `assets/catalog/registries.json`
at M1. **It never did.** No such file existed, it was declared in no pubspec, and
`SignalDomainDef`/`SignalFamilyDef` were constructed nowhere but the decoder, so
every document carried six **empty** registry maps. All four starters, all six
fixtures. `buildSeedConnectorFootprints()` was a Dart seed nothing consumed,
which is why `connectors: 0` everywhere too.

# The three clauses

**§11.10.1: the master is seeded Dart.** `rackmate_core` imports no Flutter and
therefore **cannot load an asset at all**; `rootBundle` is Flutter-only. A JSON
master needs injection through two packages, because `rackmate_export` drives core
directly and may never import `rackmate_ui`. This amends
`docs/02-data-model.md:834`.

**§11.10.2: the subset is written at document CREATION, never computed at save.**
A `write()` that recomputed the referenced subset would drop an entry nothing
references, and `write(read(bytes)) == bytes` would fail on any hand-edited or
forward-version file. See [CR-117](/invariants/cr-117-byte-exactness.md).
`kSchemaVersion` does not move. Existing documents are **not** migrated, an
unresolved id degrades to `unknown(rawId)`.

**§11.10.3: `SignalFamilyDef` regains the type-within-domain channel.** Without
`shortTag`, `dashOverride` and a weight override, **all eight digital-video
families draw as one identical solid line** and the dash channel, the one of
CR-078's four that survives greyscale, carries nothing. CR-078 is narrowed, not
reversed: hue stays on the domain.

# The subtlety worth keeping

`dashOverride` is **nullable because `[]` is a real value**. `audio.line_bal`
overrides to *solid* inside the dashed `audio.analog` domain. A non-nullable
`List<int>` defaulting to `const []` cannot tell that from "inherit" and would
silently redraw every inheriting family solid, a defect that ships as a wrong
printed drawing and traces back to nothing.

# Authority

`tools/pal1_check.py` remains the **single authority** for the palette. The Dart
seed is gated against it by
[registry parity](/gates/registry-parity.md), `palette_parity.py` proves the
*docs* agree with the authority; the new gate proves the *code* does.

# Known defect this leaves

`audio.analog` and `pwr` each have **three** glyphs; `SignalDomainDef` has two
slots. So `audio.speaker_cv` and `power.bonding` **render the wrong shape** until
a per-family glyph lands. §11.10.4 kept that out of scope deliberately.

# Citations

[1] canonical-decisions.md §11.10 (`docs/canonical-decisions.md`)
[2] `packages/rackmate_core/lib/src/catalog/seed_registries.dart`
[3] `docs/catalog/seed-devices.md` §4.3 / §4.4, the transcribed content
[4] Commits `e3cb498` (ruling), `a984add` (implementation)
