---
type: Design Ruling
title: DR-177 · A passthrough pair stays one front port to one rear port, and N04 stays unpaired
description: >-
  DR-087 left open whether a passthrough pair should ever link one front port to several rear ports.
  Only N04, the 24-fibre LIU, needs it among 51 seeded templates, so the user ruled no: the pair keeps
  one front key and one rear key, and N04 keeps its honest unpaired notice.
tags: [ruling, passthrough, catalog, fibre, dr-087, dr-177]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-177
canon_section: "11.176"
status: ruled
---

Ruled by the user on 2026-09-15, closing board `#557`.

# The question DR-087 left open

DR-087 §11.86.4 kept the seeded 24-fibre LIU unpaired, because its 12 duplex front adapters each
carry two of its 24 rear splices, and a one-to-one pair between them would be half true. It said in
terms that whether a pair should ever be one-to-many was not ruled.

# What was measured

- Of 51 seeded templates, `N03` and `N04` are the passthroughs, and only `N04` has faces that differ
  in count.
- `N04`'s 36 ports already carry the unpaired notice, a load warning and not an error.
- Pair by order over `N04` pairs twelve and reports the twelve rear ports left over.

# What was ruled

- **No one-to-many pair.** `PassthroughPairDef` keeps one front key and one rear key.
- The cost decided it: a codec change, a migration and a schedule column, for one device.
- Refused: parking the question under the v1.1 community catalog, and keeping `#557` open for it.

No code changes. The ruling records an answer the model already gives.
