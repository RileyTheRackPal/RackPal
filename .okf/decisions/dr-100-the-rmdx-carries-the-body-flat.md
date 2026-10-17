---
type: Design Ruling
title: DR-100 — A .rmdx carries the body flat, because the sections were an illustration with 21 holes in it
description: >-
  The `.rmdx` device-template file is five envelope keys over a `body` that is
  `templateBodyToJson`'s own map, verbatim. docs/06 §7.3's `identity.` /
  `physical.` / `power.` sections placed 18 of the encoder's 39 keys and left 21
  with no home, `model` among them, so a codec built from that worked example
  would have silently dropped a fifth of the model from every shared template.
tags: [ruling, persistence, file-format, rmdx, rmda, cr-117, cr-053, cr-063, dr-015, device-builder, dr-100, m4]
timestamp: 2026-08-29T00:00:00Z
ruling_id: DR-100
canon_section: "11.99"
status: built
---

# DR-100 · A `.rmdx` carries the body flat

Board `#235`, under `#184` (M4-M). Settled by the user 2026-08-29, before any code, on
[DR-077](dr-077-a-template-authored-here-reaches-the-rack.md) and
[DR-098](dr-098-an-override-says-three-things.md)'s precedent. **A format question
answered after the writer exists is a migration rather than an edit.**

## The census that raised it

Run over `_encodeTemplateBody` rather than over the prose, and counted from the function
because `putIfNotNull` and three bare `json[...] =` assignments do not match the pattern
the always-on keys do. That is
[census the field, not the name](../practices/census-before-building.md) doing its job
one more time.

| Measurement | Figure |
|---|---|
| Keys the encoder emits | **39** |
| Keys docs/06 §7.3's worked `.rmdx` places | **18** |
| Keys with no home anywhere in the corpus | **21** |
| Keys the example renames against the encoder | **2** |

**`model` was one of the 21, and it is what made this urgent.** It is a required
constructor parameter, always encoded, and
[DR-056](dr-056-generic-is-the-trades-word-for-unspecified.md) keeps it undefaulted
*specifically* so it prints as an unknown. It is the cell `docs/17`'s clause-2 drill is
sent to look for. A codec written from that example drops it, so the field that proves
[G4](../invariants/g4-unknowns-are-counted.md) works would have gone missing on the one
path built for sharing a device.

The two renames were defects in an illustration and not decisions it was making:
`depthNm` for `bodyDepthNm`, and `chassisWidth` for `chassisWidthNm`, the latter a bare
integer with **no unit in its key** in a format whose own ruling (CR-063) exists to
forbid that.

## Why the sections had less behind them than three documents suggest

The chain is one sentence long, and tracing it is what decided this.

**CR-053's subject is the override key namespace.** It **rejected**
`design-ux-device-builder.md` §5.1's dotted paths (`"identity.name"`,
`"physical.weightKg"`) in favour of typed classes. The sections survive only in that
rejection's trailing clause, whose whole job is to say they do **not** define an override
namespace. It asserts they exist in passing, on the way to discarding the proposal they
came from. Everything downstream, docs/06 §7.3's example and docs/02 §6.4, restates that
clause in a priority-3 derived document.

This is the third instance of **a derived document describing a mechanism is not a ruling
about what the mechanism needs**, after
[DR-056](dr-056-generic-is-the-trades-word-for-unspecified.md) read a Dart constructor as
a product rule and [DR-057](dr-057-pitch-is-a-refinement-not-a-prerequisite.md) priced a
feature cut off docs/06 §5's pseudocode. See
[don't price a decision off a derived artifact](../practices/a-spec-table-is-an-illustration-until-censused.md).

## The ruling

```json
{
  "schemaVersion": 1,
  "kind": "device-template",
  "templateId": "0f3a…",
  "version": 3,
  "contentHash": "sha256:…",
  "body": { "…": "templateBodyToJson's own map, verbatim" }
}
```

`derivedFrom` sits **inside** `body`, where the encoder already puts it, rather than
hoisted to the envelope as §7.3 drew it. It is a `TemplateBody` field, and hoisting it
would be the twenty-second invented assignment and would give one fact two homes.

**The format was recognised, not designed.** A `TemplateSnapshot` already on disk in all
four starters is `{templateId, version, contentHash, capturedAt, body}`. The ruled
`.rmdx` is that shape minus `capturedAt` (a file has no capture time) plus
`schemaVersion` and `kind`. `.rmda` is an array of these plus a manifest
([DR-015](dr-015-extension-family.md)), so the archive inherits it and invents no third
body shape.

## What it buys, as a mechanism rather than as tidiness

**No second description of a `TemplateBody` anywhere in the product.** The alternative was
a 39-row partition that must stay **total** as the class grows, because a key no section
claims silently vanishes from the file and only a gate written for that purpose would
ever say so. `copyTemplateBody`'s own header records the same failure one level down: *a
clone drifts the first time somebody adds field 51.*

The counter-argument was put and is real: a `.rmdx` is the unit people email each other,
`port_validation.dart` already reasons about a hand-edited one arriving, and sections help
a person find a key in a 39-key object. It was outweighed by the 21 holes, each of which
would have been authored with no source, and one more owed on every future field.

## How it is held

`rmdx_codec_test.dart`'s **48-template sweep**: every seeded template, encoded to bytes,
read back, re-encoded, compared byte for byte. A hand-written fixture asserts the fields
somebody thought of; the sweep asserts the fields nobody thought of. **Mutation-verified
by simulating the sectioned layout as an 18-key projection**, which fails the sweep, the
key-set assertion, the `model` assertion and two more.

## What it does not rule

The unit regime (CR-063 stands), the migration chain (`.rmdx` keeps its own, starting at
1 independent of `.rmpj`'s 2), AC-042's warning-never-a-failure rule for `contentHash`
(`#236`), or the import surface. **And nothing here makes `contentHash` real**: every hash
in the tree is a labelled placeholder, so `#236`'s warning cannot fire until `#795` lands.
A newer `.rmdx` is **refused rather than opened read-only**, unlike a `.rmpj`, because
AC-012 makes `TemplateBody` closed with no `unknown` passthrough, so there is nothing to
open read-only with.
