---
type: Design Ruling
title: DR-101 — An id collision on import means somebody typed the same name, and only a person knows which
description: >-
  `templateIdFor` derives a template's id from its display name, identically on
  every machine, so a colliding id on import means "somebody typed the same
  name" rather than "this template came back". Three candidate discriminators
  were checked against the tree and all three fail, so the import asks: add as a
  new version, or import as a separate template.
tags: [ruling, import, device-builder, rmdx, cr-050, cr-062, ac-042, dr-101, dr-100, m4]
timestamp: 2026-08-29T00:00:00Z
ruling_id: DR-101
canon_section: "11.100"
status: ruled
---

# DR-101 · An id collision on import is a question

Board `#236`, under `#184` (M4-M). Settled by the user 2026-08-29, before any
code, for [DR-100](dr-100-the-rmdx-carries-the-body-flat.md)'s reason one level
up: `#236` is the surface that first lets a template from outside this machine
reach a rack.

## The fact that decided it, and the first answer it overturned

`templateIdFor` derives the id **from the display name**: `HDMI Matrix 16x16`
becomes `tpl.hdmi_matrix_16x16`, identically in every project on every machine.
That was `#232`'s deliberate call, so *"a person diffing two `.rmpj` files"*
reads what the device is instead of a UUID, and it is not reopened here.

**Its consequence for import is what nobody had written down.** A colliding id
means *somebody typed the same name*, and between two integrators documenting
the same class of hardware that is close to certain rather than rare.

**The first ruling put to the user priced collisions as rare, and that premise
was wrong and load-bearing.** The user reasonably chose "keep the id, land as a
new version" against it. The local policy was already ruled, in the function's
own header:

> Collisions get a numeric suffix rather than joining an existing id: two
> devices a user happened to name the same thing are two devices, and silently
> merging them would put one template's ports on the other's instances.

So the question was put again against the measurement. **Reading the file the
task names is what caught it**, which is
[re-read a task against canon](../practices/re-read-a-task-against-canon.md)'s
second arm firing for the second time in one milestone.

## There is no signal in the file

Three candidates, all checked against the tree, all failing:

| Candidate | Why it cannot answer |
|---|---|
| `derivedFrom` | Written by **door 3 only**. Door 2 forks `version+1` on the same id and leaves it untouched, so the returning-file case carries no lineage |
| `contentHash` | A labelled placeholder everywhere until `#795`; a placeholder distinguishes nothing |
| The version number | A `.rmdx` carries ONE version, not a chain, so a stranger who iterated their own same-named device to `@4` is indistinguishable from yours returning at `@4` |

**A version-keyed rule was drafted and rejected on the third row.** It merges two
strangers whenever the incomer's version is higher, which is `#232`'s defect
through a narrower door rather than closed. That is
[a rule you invent must be checked against the good cases](../practices/a-rule-you-invent-must-be-checked-against-the-good-cases.md)
firing before the rule shipped.

## The ruling

On collision, and only on collision, **ask**: `[ Add as a new version of it ]`
or `[ Import as a separate template ]`. No default among them, because the whole
finding is that the app cannot tell.

**The prompt is not a hedge**, and the distinction from
[DR-033](dr-033-community-catalog-submission.md)'s rejected save-flow prompt is
the trigger: that one fires on every save and trains the dismissal reflex; this
one fires only when an ambiguity exists, on a gesture the user just initiated,
with the answer available to them and to nothing else. **A question with no
derivable answer is the one case a dialog is the right instrument.**

Also ruled: the pair lives in the **File menu** beside `Export PDF…`, because
import belongs to no template and a card menu would split the verbs; and the
inert-data sentence goes **in the import dialog** rather than a first-run card,
because the hesitation it answers happens at the dialog.

## What building it found

**`IFileDialog` cannot carry body text.** Custom text needs
`IFileDialogCustomize`, a slab of C++ for one sentence with no `NSOpenPanel`
equivalent for D2 to inherit. So the sentence needs an app-side dialog, and
Import gains a confirmation step the ruling did not ask for. It earns the click:
it prints the file's real contents before they enter the document, so a `.rmdx`
claiming to be a 16x16 matrix while reporting `2 ports` is visible there and
nowhere else.

## What it does not rule

It does not make `contentHash` real, so **AC-042's mismatch warning and its badge
cannot be exercised until `#795` lands** and `#236` must not be read as having
discharged them. It says nothing about `.rmda` or several libraries at once, both
M4-N's. And it does not decide what happens when an imported body is
byte-identical to a version already held: detecting that cheaply is `#795`'s
hash.
