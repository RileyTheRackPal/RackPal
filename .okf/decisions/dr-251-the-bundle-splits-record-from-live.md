---
type: Design Ruling
title: DR-251 · DR-096's record exclusion covers the bundle's decisions and its log, and not its live reference pages
description: >-
  From #1063. DR-096 kept the whole .okf bundle as record, so gate and invariant pages kept pointing at
  package paths the rename had moved, one resource pointer included. decisions/ and log.md stay record;
  gates/, invariants/, practices/, getting-started and index take current names.
tags: [ruling, okf, rename, record, dr-251, dr-096]
timestamp: 2026-10-17T00:00:00Z
ruling_id: DR-251
canon_section: "11.250"
status: ruled
---

Settled by the user on 2026-10-17 for `#1063`. It narrows
[DR-096](dr-096-the-product-is-rackpal.md)'s list of what counts as record.

# What was ruled, and by whom

| Part of the bundle | Chosen by | Treatment |
|---|---|---|
| `decisions/`, `log.md` | User, on the recommendation | Record. Kept in the words, names and paths of their day |
| `gates/`, `invariants/`, `practices/`, `getting-started.md`, `index.md` | User, on the recommendation | Live. Current paths and the RackPal name; a quoted path stays quoted with the current one beside it |

# Record is a property of the page, not of the folder it sits in

DR-096 drew its line at the bundle, because the bundle's decision pages are history and history said
RackMate. The line was one level too coarse: a gate page is not a record of what was said, it is a
pointer to where a test lives today, and a pointer to a moved file is a broken pointer whatever the
folder is called. The question that sorts a page is whether a reader uses it to find something now.

# Owed

The substitution over the live directories is `#1087`; the orientation pages' name is `#1081`. This
page itself is a decision and so is record: it names `rackmate_*` paths because they are the subject.
