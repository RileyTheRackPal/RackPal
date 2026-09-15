---
type: Design Ruling
title: DR-173 · A matrix's de-embedded zone audio is a stereo pair per zone
description: >-
  V01 and V03 modelled each zone's de-embedded audio as one mono 3-pin port, as the catalogue
  specification said, while a matrix de-embeds a zone in stereo. Each zone is now an L/R pair on two
  balanced 3-pin blocks in one atomic set, so one drag lands both as one cable.
tags: [ruling, catalog, port-sets, stereo-pair, dr-014, dr-173]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-173
canon_section: "11.172"
status: built
---

Ruled by the user on 2026-09-15 and built as `#112`.

# A zone is stereo, and the model said mono

DR-014 §11.14.7 deferred `#112` beside `#111`. V01 declared 8 zone outputs and V03 16, each one
`conn.euroblock_3` port in no set, so the model could not say that a zone's left and right are two
conductors of one feed.

# What was ruled

- **An L/R pair per zone**: a `stereoPair` set of `AUD OUT n L` and `AUD OUT n R` on two balanced 3-pin
  blocks. V01 goes from 8 zone ports to 16, and V03 from 16 to 32.
- **Refused: one 5-pin block per zone**, V05's shape, which hides the pair inside one port and can
  never split.
- **The trade fact that bounds it**, from the user: the Triad TS-AMS8 and TS-AMS16 cannot split zones,
  and the ELAN EL-IPD-MTX-8CH can. An HDMI matrix is the Triad case. A channel-splitting device is
  authored as numbered mono channels.
- **V02's S/PDIF outputs stay one port each**, because S/PDIF carries both channels on one connector.

# What building it found

- **V03's template never passed its port sets.** Its `TemplateBody` left out `portSets:`, so the sets
  were declared and then dropped, and `port_set_integrity_test` named all 32 ports as dangling.
- **The pairs are numbered unpadded**, `AUD OUT 1 L`, because the label grammar refuses `{n@2:2}` by
  design.
- **V01's zone bank now collapses** in the schematic, at 16 ports against a threshold of 8, so pressing
  it expands it rather than starting a cable.
- **The set gesture never consults tier 2** (`#909`): a pair dropped on mismatched connectors raises no
  chip. The DR-128 remedy test's CON-001 case moved to V05's 5-pin output into A03's 3-pin input, the
  one same-family audio shape a census over non-atomic ports found.

# Where it lives

- `packages/rackpal_core/lib/src/catalog/catalog_video.dart`: V01 and V03.
- `packages/rackpal_core/test/catalog/matrix_zone_audio_test.dart`: the pairs, asserted.
- `docs/catalog/seed-devices.md`: the notation, and §6.3's worked example.

A catalogue data correction, and no scope change.
