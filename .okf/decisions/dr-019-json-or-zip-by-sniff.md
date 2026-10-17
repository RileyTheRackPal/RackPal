---
type: Design Ruling
title: "DR-019 · The plan container is JSON-or-zip by sniff; v1 owes a passthrough, not a carrier"
description: >-
  The plan container is JSON-or-zip by sniff; v1 owes a passthrough, not a carrier. The only DR that supersedes another DR. `.rmpj` stays plain pretty JSON with no binary member and becomes a zip container with one, so nothing migrates and CR-091's single file survives; the writer owes stated determinism because zip is nondeterministic and CR-117 is byte round-trip. Base64-in-JSON and a sidecar are rejected with reasons. PNG and JPEG in, no PDF import. It corrects DR-018 §11.17.4, which claimed a migration cost that a read of `persistence/` does not support: the real G5 item is that `Placement` carries no `unknown` map, so an older build silently drops plan pins on save. That passthrough is v1's one new item and lands in M3. The Plan view is now v1.1 unconditionally. Design: Plan view (`docs/15-plan-view.md`). No board item
tags: [ruling, dr-019, canon-11-18]
timestamp: 2026-08-04T00:00:00Z
ruling_id: DR-019
canon_section: "11.18"
status: built
---

**Generated from canon §11.18 on 2026-10-12** (board `#1055`), because the bundle had no
concept for this ruling. Every line below is canon's own text or docs/10's summary; read
the canon section for the reasoning, which this page does not restate.

# How it was settled

**Ruled 2026-08-04.** Answers the question DR-018 §11.17.4 left open and **corrects the premise it

# In one line (docs/10)

**The plan container is JSON-or-zip by sniff; v1 owes a passthrough, not a carrier**. **The only DR that supersedes another DR.** `.rmpj` stays plain pretty JSON with no binary member and becomes a zip container with one, so **nothing migrates** and CR-091's single file survives; the writer owes stated determinism because zip is nondeterministic and CR-117 is byte round-trip. Base64-in-JSON and a sidecar are rejected with reasons. PNG and JPEG in, **no PDF import**. **It corrects DR-018 §11.17.4**, which claimed a migration cost that a read of `persistence/` does not support: the real G5 item is that **`Placement` carries no `unknown` map**, so an older build silently drops plan pins on save. That passthrough is v1's one new item and lands in M3. The Plan view is now v1.1 **unconditionally**. Design: Plan view (`docs/15-plan-view.md`). No board item

# Its clauses, as canon heads them

| Clause | Heading |
|---|---|
| §11.18.1 | DR-018 §11.17.4 was wrong about why the decision was urgent. |
| §11.18.2 | The ruling. |
| §11.18.3 | What it does not rule. |
| §11.18.4 | Scope. |
| §11.18.5 | The general lesson, since this is the second one this week. |
| §11.18.6 | Landed. |

# Citations

[1] `docs/canonical-decisions.md` §11.18
