---
type: Design Ruling
title: DR-023 — The {SERVICE} fallback chain, and what a line with no service is called
description: Three steps and no fourth: the line's @service=, else the outlet template's tag, else the media's short tag. Refusing would refuse the corpus's own first worked example.
tags: [ruling, m3, labels, idformat, dsl, dr-023]
timestamp: 2026-08-07T00:00:00Z
ruling_id: DR-023
canon_section: "11.22"
status: ruled
---

Settled by the user on 2026-08-07, answering the question
[DR-022](dr-022-service-token-is-the-template-tag.md) §11.21.6 explicitly left
to board #147. DR-022 settled the **source**; this settles the **chain**.

# The chain

`{SERVICE}` resolves from the first of these that is present.

| | Source | Example |
|---|---|---|
| 1 | The line's `@service=` modifier | `Exterior: 6x Cat6 @service=camera` → `EXT-CAM-4` |
| 2 | The `tag` of the `OutletTemplate` the drop's `Outlet` came from | a *TV location* outlet → `LR-TV-1` |
| 3 | The `shortTag` of the drop's media type | `Living Room: 4x Cat6` → `LR-C6-1` |

There is no fourth step and no placeholder. Every step is a fact the person
supplied on the line or stored on the outlet.

# Why the modifier outranks the template

CR-048 evaluates a designator **once at creation and stores it**. A label that
cannot be overridden at the moment of entry can only be corrected by deleting
the drop and re-entering it, and a sixty-drop drill cannot afford that. The
modifier is also the more specific statement: typed on *this line*, about
*these drops*, where the template is a default carried by the outlet.

**The cost is accepted and named.** Six Cat6 on a *TV location* outlet with
`@service=camera` are labelled `CAM` and sit on an outlet called *TV location*.
That is a true record of what the installer was told, and the alternative,
silently ignoring a modifier the person typed, is what `docs/04` §3.4 forbids.

# Why the media tag is not the STR answer DR-022 rejected

`docs/07` §4.1: *"`Service: undetermined` is a first-class, encouraged state
... At rough-in a Cat6 is just a Cat6."* A chain that refuses `Living Room: 4x
Cat6` refuses the corpus's own first worked example of the entry surface, at
the exact point where friction is most expensive.

DR-022 §11.21.5 rejected `structure.undetermined.shortTag`, and the reason was
**not** that a fallback is wrong. It was that `STR` is a *placeholder word*,
identical on every rough-in cable in the project and stored forever by CR-048:
sixty labels that all say the same thing, and the thing they say is "we do not
know". The media tag fails none of that. `C6`, `RG6`, `16/4` and `22/4` **vary
per drop**, they are facts the line stated, and `LR-C6-1` is a sentence an
installer can act on with a label printer in one hand.

**What it costs, stated plainly:** `{SERVICE}` now means *what this drop is
for* when a template or modifier says so, and *what this drop is* when neither
does. One token, two senses. The alternatives cost more: refusing costs the
encouraged state, a placeholder costs sixty identical labels on cable.

# The one hole, and it refuses

`shortTag` is nullable on `MediaTypeDef` (G4, CR-114). All 38 seeded types
carry one, but a **user-created** type from an RJ-009 CSV import may not. That
drop reports `LabelTokensMissing(['SERVICE'])` through the outcome board #152
already built, and is refused with a sentence naming the two fixes. It is not
defaulted, and it is not given the raw media id: a label is printed on cable
and `media.cat6` is not a label.

# What it does not rule

Whether `@service=` also sets the drop's `Service.signalFamily`. `docs/07` §4.1
backs the drop's Service column with the `structure.undetermined` family and
§5.1 maps the CSV `service` column to a `SignalFamilyId`, while the token this
ruling governs is a **label segment**. The two share a word and are different
fields; `@service=camera` names no signal family, because there is none. Drops
created by the loop take `structure.undetermined` until something assigns a
real family, which is §4.1's retroactive-DRC path working as written. A later
ruling may connect them; this one keeps them apart deliberately, so the label
chain is not blocked on the taxonomy question.

# Citations

[1] canonical-decisions.md §11.22 (`docs/canonical-decisions.md`)
[2] DR-022 §11.21.6, which named this as #147's question
[3] docs/07-structure-device.md §4.1 (the encouraged undetermined state) and
    §4.3 (the four worked DSL lines)
[4] `packages/rackmate_core/lib/src/idformat/designator_allocator.dart`, the
    `LabelTokensMissing` outcome the refusal travels on
[5] `packages/rackmate_core/lib/src/catalog/seed_media_types.dart`, the 38
    `shortTag`s step 3 reads
