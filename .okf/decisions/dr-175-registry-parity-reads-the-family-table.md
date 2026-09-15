---
type: Design Ruling
title: DR-175 · Registry parity holds the descriptive fields to the specification's family table
description: >-
  The registry parity gate checked the Dart seed's hue, dash and weight against pal1_check.py and was
  blind to each family's name, tag, connector, direction and topology. It now compares those with the
  family table in seed-devices.md section 4.4, which already agreed on all 57 rows.
tags: [ruling, ci, gate, registries, palette, dr-010, dr-175]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-175
canon_section: "11.174"
status: built
---

Ruled by the user on 2026-09-15 and built as `#81`.

# A tripwire that invited the wrong fix

The DR-010 agent's mutation M13 found that `registry_parity.py` gates the numeric half of the palette
and nothing else. A family's display name, short tag, default connector, direction and topology were
pinned only by the starter goldens, and a golden failure says to regenerate the asset, which ships
the typo it caught.

# What was ruled

- **The gate compares the seed with seed-devices §4.4** for the descriptive fields: name, connector
  and tag exactly once markdown emphasis and code marks are removed, and direction and topology by
  the cell's leading symbol or word.
- **The id sets must match both ways**, so a table the gate cannot read fails it.
- **Neither file is the authority for this half.** A drift is fixed in whichever of the two is wrong,
  in one commit, and never by regenerating a starter.
- Refused: a committed snapshot of the fields, rewording the golden failures only, and keeping the
  gate blind.

# What building it found

- The table already agreed with the seed on every row, so the gate starts green.
- The glyph cannot be compared: the seed stores none per family.
- CI prints to a console that cannot encode the table's arrows, so every new message is ASCII.
- Verified by mutation on copies: each kind of drift exits 1, and a bold-only change passes.

# Where it lives

- `tools/registry_parity.py`: `parse_spec`, `plain`, `lead`, and the section 4.4 block in `check`.
- `docs/catalog/seed-devices.md` §4.4: the table, and a note that it is gated.
- [Registry parity](/gates/registry-parity.md): the gate's record.

No scope change: a CI gate's coverage.
