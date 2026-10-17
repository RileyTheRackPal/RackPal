---
type: Invariant
title: CR-078, colour lives on the signal domain and a family inherits it
description: A signal family has no colour of its own. The eight domains own the hue, a family reads it through its domain, and the one per-family exception is a project setting that is never a registry field. The jacket colour on a cable is not a hue.
tags: [invariant, palette, cr-078, ac-054, registries, accessibility]
timestamp: 2026-10-17T00:00:00Z
ruling_id: CR-078
status: enforced
---

**Hue encodes the signal domain.** Roughly fifty families do not each get a colour,
because no categorical palette is colour-vision-safe past eight or nine categories.
This page is the ownership half of CR-078: where the colour lives. The other half,
that hue is never the only channel, is
[the four encoding channels](four-encoding-channels.md).

# The rule, in the model's shape

- `SignalDomainDef` owns the visual language: colour (a light and a dark value),
  base dash, base weight, glyph, tag prefix. There are eight entries.
- `SignalFamilyDef` holds a foreign key to its domain, a short tag, and optional
  overrides for dash, weight and glyph. **It has no colour field at all.** This is
  the enforcement that matters: a family cannot carry a hue because the type has
  nowhere to put one. (The first design had a colour per family, forty-three of
  them; CR-078 deleted that palette, and the domain definition was created to
  replace it.)
- Resolution is one function, `resolveSignalStyle` in
  `draw/scene/signal_style.dart`: family, then registry entry, then domain, then
  hue. Nothing else in the drawing layer resolves a channel.

# The one exception, and where it lives

AC-054 reconciled the brief's "colour-coded by cable type" with the domain rule: the
legend prints one row per type, and a user may override the hue of a single family.
That override is **`ProjectSettings.familyColorOverrides`**, a map in the project's
settings, not a field in the family registry. Three consequences keep the rule
honest:

- An override is **theme-independent**. It is a colour a user chose, so it is not
  re-tinted for dark mode; only the seeded hues form a light and dark pair.
- Clearing an override returns the family to its domain's colour, which is a
  different state from an override that happens to equal it, and the style reports
  which one it is, so a legend never says "overridden" about a coincidence.
- The override touches hue only. The other three channels are left alone.

# What enforces it

- **The type.** No colour on `SignalFamilyDef`, as above.
- **The style tests.** `scene/signal_style_test.dart`: every family of a domain
  renders the same hue, the eight domain hues are distinct, an override replaces the
  hue for that family alone, and an override leaves the other channels untouched.
- **The seed matches the authority.** `tools/registry_parity.py` compares the Dart
  seed's domain hues, family-to-domain assignments, and effective dash and weight
  against `tools/pal1_check.py`, and fails on a seed that matched nothing.
- **The palette is legible.** [PAL-1](/gates/pal1-conformance.md) enumerates the
  families as they are actually drawn, effective values after any override, and
  fails a pair that is indistinguishable in greyscale. That gate is this
  invariant's consequence check; this page is what it checks.
- **Jacket colour is not hue.** `Link.jacketColorId` is the sheath that was pulled, a
  physical fact about the building. `jacket_colour_is_not_hue_test.dart` scans the
  drawing roots and fails on names that would route it into a stroke, because
  coupling the two would draw a blue control run and a blue audio run identically
  and would swap a verified palette for whatever was on the reel.

# What it does not cover

- **An override can break legibility.** PAL-1 clears the seeded palette. A user who
  overrides a family to a colour that collides in greyscale gets what they chose;
  the safeguard is that dash, weight and tag still differ.
- **The jacket scan is a source scan by name.** It stops the names it knows about.
  A new accessor for the same fact under a new name is not caught until it is added
  to the list, which is why the test also checks that its own roots exist.
- **The style test runs over the seeded registries.** A registry a user has extended
  is resolved by the same function, but the "one hue per domain" assertion is made
  over the seed.

# Citations

[1] `docs/canonical-decisions.md` CR-078 and AC-054
[2] `packages/rackpal_core/lib/src/model/registries.dart`, `SignalFamilyDef`
[3] `packages/rackpal_core/lib/src/draw/scene/signal_style.dart`
[4] `packages/rackpal_core/test/scene/signal_style_test.dart`
[5] `packages/rackpal_core/test/jacket_colour_is_not_hue_test.dart`
[6] `tools/registry_parity.py` and `tools/pal1_check.py`
