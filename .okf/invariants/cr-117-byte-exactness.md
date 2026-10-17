---
type: Invariant
title: CR-117 — write(read(bytes)) == bytes
description: The byte-exactness property the whole persistence suite rests on, and the design rules that fall out of it.
tags: [invariant, persistence, cr-117]
timestamp: 2026-07-28T00:00:00Z
ruling_id: CR-117
status: enforced
---

**`write(read(bytes)) == bytes`.** Not a semantic comparison, the literal byte
property. A document read and written back must be identical on disk.

# What it forbids, and what that has already prevented

This one property has decided at least four design questions in this repo. Each
time, the tempting implementation was the one that breaks it.

| Temptation | Why it breaks CR-117 | Ruling |
|---|---|---|
| Write a new bool field unconditionally | adds a key to every entity in every existing document | [DR-008 §11.8.2](/decisions/dr-008-wiring-model.md) |
| Have `write()` elide registries to the referenced subset | drops an entry nothing references, so a hand-edited or forward-version file loses data silently | [DR-010 §11.10.2](/decisions/dr-010-seeded-registries.md) |
| Normalise an override equal to its base to `null` on the write path | the identical real-world history recorded in a different order produces different stored state | CR-121 |
| Store a derived value | recomputation disagrees with what was stored | CR-107 |

# The additive-optional contract

A new field may be added **without moving `kSchemaVersion`** if it is written
**only when set** and absent otherwise. Absent-key-is-not-null. Then every
document written before the field existed still encodes byte-for-byte.

The pattern to copy is `jacketColorPulledId` and `linkClassLocked`. The pattern
**not** to copy is `designatorLocked`, which is written unconditionally, and sits
three lines away in the same codec function, which is exactly why it gets copied
by mistake.

# How it is enforced

- The **1000-sequence fuzz harness** (`command_roundtrip_test.dart`) applies a
  random command, reverts it, and asserts the JSON is byte-identical. Every new
  command should be registered in it.
- **Goldens are asserted, not regenerated.** A golden diff is a *finding*.
  Regeneration is deliberate, via `UPDATE_GOLDENS=1` with a reviewable diff.
- The [byte-exactness sweep](/gates/byte-exactness-sweep.md) checks that
  `.gitattributes` pins every extension sitting in a byte-exact root, so a
  Windows clone cannot CRLF-normalise a fixture.

# The trap in the tests themselves

A byte-identity assertion does **not** catch an unconditionally-written `null`,
because that re-encodes consistently. What kills it is an **absence** assertion:
"this key does not appear at all". Both `link_class_locked_wire_test.dart` and
`registry_wire_test.dart` are shaped around that.

# Citations

[1] `packages/rackpal_core/test/command_roundtrip_test.dart`
[2] `packages/rackpal_core/test/byte_roundtrip_test.dart`
[3] `apps/rackpal/test/gitattributes_byte_exactness_test.dart`
