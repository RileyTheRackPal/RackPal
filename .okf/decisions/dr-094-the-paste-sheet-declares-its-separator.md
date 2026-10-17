---
type: Design Ruling
title: DR-094 — The paste sheet declares its separator, and drops what a closed model cannot hold
description: >-
  M3's CSV reader is comma-only and refuses tabs by design, which is a problem
  for a feature whose input is a spreadsheet clipboard. Its own comment names
  the fix: a user-visible choice, not a counter. And an unmapped column is
  dropped rather than preserved, because AC-012 rules TemplateBody closed.
tags: [ruling, device-builder, import, csv, m4-i, dr-094, ac-012, m3-f, rj-004]
timestamp: 2026-08-26T00:00:00Z
ruling_id: DR-094
canon_section: "11.93"
status: built
---

# DR-094 · The sheet declares its separator, and drops what a closed model cannot hold

Board `#222` (M4-I3). [DR-092](dr-092-the-archetype-emits-the-port-4-3-could-not.md)
§11.91.8 and [DR-093](dr-093-the-switch-copies-the-seeded-switch.md) §11.92.7 both left
this open by name.

## Using an engine sometimes means changing it, and the engine says how

`#222`: *"sharing the engine with the Structure CSV import, use it, do not fork it"*. It
is used: quoting, ragged rows, limits, refusals and `normaliseCsvHeader` are all M3's.

But `readCsv` is **comma-only and refuses a tab file rather than sniffing one**, and a
spreadsheet puts tabs on the clipboard. Its own header states the shape the fix had to
take, verbatim:

> If a semicolon dialect later has to be read, it is **a ruling and a user-visible choice,
> not a counter**.

`CsvDelimiter` is that choice: a parameter defaulting to comma, so every M3 caller is
unchanged, exposed by the dialog as *"Tabs (from a spreadsheet)"* and *"Commas (from a
.csv file)"*. The parenthesis is what makes the control answerable, because a person who
has just copied cells does not know what separates them. **No sniffing was added**: a
comma sheet read in tab mode is still diagnosed by name.

**The general shape is worth keeping.** A shared component that refuses a case on purpose
usually documents the terms on which it would accept one. Reading those terms is cheaper
than either forking the component or arguing with it.

## An unmapped column is dropped, and canon is why

`csv_mapping.dart` refuses a "discard this column" option outright, on docs/07 §5.1's
unconditional rule that unmapped columns are *"preserved into the row's `unknown` map"*.
**`PortDef` has no such map**, and AC-012 rules that this is deliberate:

> `TemplateBody` is app-defined and **closed**; there is no forward-compat argument,
> because unknown *keys* are already handled by `EntityMeta.unknown`.

A port inside a template body carries no `EntityMeta`. So the column cannot be kept and
the choice is between dropping it silently and dropping it out loud.

**Out loud.** The sheet shows it as `Not imported` and the summary counts it: *"12 ports
across 2 new banks · 1 column not imported"*. The words are **not imported** and never
"ignored", because it is a loss. Giving `PortDef` an `unknown` map is a model change, a
codec change, four regenerated starters and an argument against AC-012.

## Three smaller rules

**The bank is a target, not a column.** `PortColumnId` has no bank member, and a
spreadsheet of ports very often has a Group column; without it, sixty-eight rows land in
`Not in a bank`.

**A pasted cell is data, never a pattern.** `HDMI {n}` means those seven characters, and
the label grammar has no escape for a literal brace because generalising it is the
milestone's named scope hazard. Literal labels travel **with** the plan rather than after
it, because `autoPortKey` derives a port's key from its label.

**One target, one column.** Assigning a target releases whichever column held it: two
columns both feeding `LABEL` means the second silently wins and the sheet cannot show
which.

## It creates ports, which `Ctrl+V` refuses to

`port_tsv.dart` keeps §4.6's rule: ten values into the last three rows would invent seven
ports, each needing a key nobody chose. **This is the opposite feature**, and creating is
the point of it. The two share `parsePortCell` and nothing else. Their type collision was
a compiler error rather than a subtle one, which is the good kind: this path's plan is
`PortImportPlan`.

## What it does not rule

No semicolon dialect. No `unknown` map. No change to M3's Structure import. And **no
idempotence**: a template has no `fieldLabel` to dedup on and CR-051's key join is a
migration record rather than a match key, so re-pasting the same sheet doubles the ports
and `Ctrl+Z` is one keystroke away.

## Citations

[1] `packages/rackmate_core/lib/src/builder/port_import.dart`
[2] `packages/rackmate_core/lib/src/structure/csv_reader.dart`: `CsvDelimiter`
[3] [two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md)
