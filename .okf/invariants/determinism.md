---
type: Invariant
title: Determinism, the same document gives the same display list and the same bytes
description: Same document, same display list, same exported file. Every sort ends in a unique id, no Map or Set iteration order reaches a drawing, and the only clock is an injected date. The property is held by several tests, each of which proves a different slice of it.
tags: [invariant, determinism, scene, export, sorting, persistence]
timestamp: 2026-10-17T00:00:00Z
status: enforced
---

**Given the same document, the scene builders produce a byte-identical display list,
and the exporter produces a byte-identical file, on any machine, in any order the
document's collections happened to be built in.**

This invariant has no ruling number of its own. It is the M2 exit criterion ("same
input, byte-identical display list"), the contract of `docs/08` section 8.4, and the
reason golden-file testing is possible at all. "Did anything actually change between
revision B and revision C?" is answerable with `diff` only because of it.

# What it forbids

- **A non-total comparator.** Dart's `List.sort` is not stable, so two rows that tie
  on every key may swap. Every comparator therefore ends in a **unique id**, and a
  chain that ends in a designator or a label, which two entities can share, is
  incomplete.
- **Map or Set iteration order reaching a drawing.** Collections built in a different
  order, by a different load path or a different command history, must draw
  identically. Iterate by sorted key.
- **A wall clock.** The one date on a sheet is injected (`issuedAt`); a bare
  `DateTime.now()` anywhere else makes two exports differ.
- **Random identifiers in output.** A PDF's trailer id and creation date come from a
  library that writes a random hash and the wall clock; the export rewrites both,
  in place and at the same length, from the issue date and the file's own contents.
- **Format variation in the writer.** Key order, number formatting and, in a zip
  container, entry timestamps, compression level and entry order all vary by default.

# What holds it, slice by slice

No single test proves the whole property, which is why it is listed here.

| Slice | Test | What it can see |
|---|---|---|
| Schematic display list | `scene/schematic_scene_test.dart`, group "DETERMINISM" | the same document twice, a document whose entities were inserted in the **opposite order**, and two separately constructed equal documents |
| Layout | `scene/sugiyama_test.dart` | the layout stage on its own, under its own "determinism" group |
| Real-sized input | `scene/schematic_perf_test.dart` | determinism on the large fixture, not only a toy |
| Comparing display lists | `scene/op_digest.dart` | the instrument: a lossless text rendering of every op, because a display-list op has no value equality and comparing lists passes for scenes that differ everywhere |
| Derived tables | `derived/schedule_test.dart` | rows that tie on every primary key, built twice, for every sort |
| Container bytes | `persistence/container_determinism_test.dart` | each of the four zip nondeterminism sources, one at a time |
| Exported file | `rackpal_export/test/export_determinism_test.dart` | the injected clock through the real entry point, and one document at one date giving one file |

The digest is exhaustive by construction: it is a `switch` over the sealed op
hierarchy with no default, so adding an op type is a compile error there instead of a
hole in the suite.

# What it does not cover

- **Building the same document twice does not catch a non-total comparator.** The
  same input order sorts the same way every time, so a tie that swaps only when the
  input order changes passes a "twice" test. The slice that can catch it is the one
  that **permutes the input**, and today that is the schematic scene's reversed-
  document case. The derived-table sort test builds twice; read its claim narrowly.
- **No scanner enforces "every comparator ends in an id".** The rule is kept by
  review and by the permutation tests; a new sort in an untested table is unguarded.
- **Cross-platform identity is asserted by construction, not measured.** The tests run
  on one platform. Integer geometry (see [CR-001](cr-001-integer-units.md)) and the
  injected font metrics remove the usual sources of drift, but a floating-point
  rendering difference between Windows and macOS is not something a green run here
  rules out.
- **It is about identity, not correctness.** A deterministic wrong drawing passes.
  Pair it with [CR-117](cr-117-byte-exactness.md), which is determinism's counterpart
  for the saved file.

# Citations

[1] `docs/08-pdf-export.md` section 8.4
[2] `packages/rackpal_core/test/scene/schematic_scene_test.dart`
[3] `packages/rackpal_core/test/scene/op_digest.dart`
[4] `packages/rackpal_core/test/derived/schedule_test.dart`, "every sort is TOTAL"
[5] `packages/rackpal_core/test/persistence/container_determinism_test.dart`
[6] `packages/rackpal_export/test/export_determinism_test.dart`
