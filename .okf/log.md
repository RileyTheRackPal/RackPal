# Update Log

## 2026-07-28

* **Update**: Caught the bundle up with M2-D (`e13fa68`) and M2-E (`219c0bf`),
  which had landed after it was written. Batching that catch-up was itself the
  drift this bundle exists to prevent — maintain as changes land, not after.
* **Creation**: [CR-078 — four encoding channels](/invariants/four-encoding-channels.md),
  recording that the GLYPH CHANNEL CURRENTLY CARRIES NOTHING: there is no `tier`
  field, so `glyphAlt` is unreachable for all eight domains and all 55 families.
* **Creation**: [Diagnose before fixing](/practices/diagnose-before-fixing.md) —
  the salvage post-mortem, where twelve consecutive fix commits touched neither
  cause because a third defect made the surface unable to change at all.
* **Update**: [DR-001](/decisions/dr-001-net-labels-by-default.md) is now BUILT,
  with the measured cost against M2-C's baseline: 4155 -> 6555 ops, the label
  layer 19% of a frame with ~4x headroom.
* **Update**: [Package layering](/invariants/package-layering.md) records a
  violation in waiting — `wire_trace.dart` sits in `rackmate_ui`, which
  `rackmate_export` may never import, so the exporter cannot draw a wire and
  M6's interconnect sheets are unbuildable until it moves.
* **Creation**: Scaffolded the RackMate bundle with `okf_init.py`.
* **Creation**: Established the bundle's spine — the ruling to spec to
  implementation to test chain — in [getting started](/getting-started.md).
* **Creation**: `decisions/` with [DR-001](/decisions/dr-001-net-labels-by-default.md),
  [DR-008](/decisions/dr-008-wiring-model.md),
  [DR-009](/decisions/dr-009-macos-in-v1.md) and
  [DR-010](/decisions/dr-010-seeded-registries.md). DR-002 through DR-007 are
  recorded in the canon but not yet written up here.
* **Creation**: `invariants/` with [CR-117](/invariants/cr-117-byte-exactness.md),
  [G4](/invariants/g4-unknowns-are-counted.md) and
  [package layering](/invariants/package-layering.md).
* **Creation**: `gates/` with the [analyzer ratchet](/gates/analyzer-baseline.md),
  [registry parity](/gates/registry-parity.md) and the
  [byte-exactness sweep](/gates/byte-exactness-sweep.md) — each recording its
  blind spot as well as its coverage.
* **Creation**: `practices/` with
  [decompose before building](/practices/decompose-before-building.md), written up
  because a session died mid-milestone and the task breakdown is what made the
  work recoverable.
