# Update Log

## 2026-07-28

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
