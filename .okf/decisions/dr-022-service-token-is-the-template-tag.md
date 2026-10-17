---
type: Design Ruling
title: DR-022 — {SERVICE} in a drop's field label is the outlet template's tag
description: The shipped Residential CI preset throws on the rough-in drop the product most encourages. The corpus's own worked examples name the source, and it is the outlet template, not the signal family.
tags: [ruling, m3, labels, idformat, dr-022]
timestamp: 2026-08-07T00:00:00Z
ruling_id: DR-022
canon_section: "11.21"
status: built
---

Settled by the user on 2026-08-07, before board #152 allocated a single label.

# The measurement that forced it

The two label formats have round-tripped since M0 with exactly one caller
each, the codec. CR-044 ships their defaults, CR-045 gives the grammar, and
neither says where `{SERVICE}` gets its value. Rendering the shipped default
against the drops M3's own exit criterion describes:

| Case | `{ROOM_ABBR}-{SERVICE}-{SEQ}` |
|---|---|
| every token known | `GR-TV-1` |
| service undetermined | **throws** |
| no room | **throws** |

There is no `[...]` around any of the three tokens, so a missing one is a
`MissingTokenValueException` rather than a blank. And the rough-in drop is not
an edge case: `docs/07` §4.1 calls `Service: undetermined` *"a first-class,
encouraged state"*, so **the default cannot render the state the product most
encourages**.

This is [census before building](/practices/census-before-building.md) on a
format string: the pattern was read for a year as an example of what a label
looks like, and nobody had rendered it against a document.

# The ruling

**`{SERVICE}` is the tag of the `OutletTemplate` the drop was created from.**

It is the only answer that reproduces the corpus's own worked examples.
`LR-TV-1`, `MBR-KEY-2` and `EXT-CAM-4` are **TV location**, **Keypad** and
**Camera**: three of the six templates `docs/07` §4.3 seeds. They are not
signal families, and reading them as families is the misreading this ruling
exists to prevent.

`OutletTemplate` gains a `tag` beside its `name`, because `name` is *"TV
location"* and a tag derived from it by truncation is a guess printed on
physical cable.

# Why that is not a migration

`registries.outletTemplates` is `{}` in all four shipped starters and in every
document ever written. A key added to an entity with **zero instances
everywhere** costs no file a byte. That is DR-019's argument for
`Placement.unknown` applied to a smaller surface (canon §11.18; it has no
concept here yet), and it is the reason a model change is cheap enough to
prefer over a cheaper-looking one.

# The two rejected answers

**The signal family's `shortTag`.** Needs no model change and gives
`LR-STR-1`, since `structure.undetermined.shortTag` is `STR`. Rejected because
CR-048 evaluates a designator **once at creation and stores it**: that label
never becomes `LR-NET-1` when a real service is assigned. Sixty labels on
physical cable that all say the same word, and the word is the placeholder.

**Making the segment optional** in the shipped preset,
`{ROOM_ABBR}-[{SERVICE}-]{SEQ}`. Cheapest, needs nothing new, and edits a
CR-044 preset cited in five documents so that its own examples stop rendering.

# The rack label needed no ruling, and that is worth saying

`{FLOOR}{SPACE}-{PANEL}{PORT:2}` throws without a `PORT`, and AC-018 puts
**fourteen of the sixty** drops on unbound far ends. But `rackLabel` is
**optional** in CR-044's own words, so those fourteen simply have none.
Nothing is fabricated and nothing throws, because nothing renders. Recorded so
the next reader does not go looking for the ruling that handled it.

# What it does not rule

Where `{SERVICE}` comes from for a drop with **no template at all** (`Attic:
3x Cat6`). The DSL has an explicit `@service=` modifier for exactly that, and
which wins, and what happens when neither is supplied, is board #147's
question, because that is where the entry surface decides what it can refuse.
This settles the SOURCE, not the fallback chain.

# Citations

[1] canonical-decisions.md §11.21 (`docs/canonical-decisions.md`)
[2] CR-044 (§1.5), the two presets and `rackLabel`'s optionality
[3] `packages/rackmate_core/lib/src/idformat/id_format.dart`, the `[...]` and
    `MissingTokenValueException` semantics the measurement above exercises
[4] docs/07-structure-device.md §4.3, the six seeded templates
