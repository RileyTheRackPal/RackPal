---
type: CI Gate
title: Rule review pack
description: Every rule in the validation catalogue has a place in the domain-review pack, in the right band. It parses the catalogue and the pack's grouping and writes nothing, so a rule arriving without a group fails the day it arrives.
tags: [gate, ci, validation, rule-catalogue, review, ac-051, ac-040]
timestamp: 2026-10-17T00:00:00Z
resource: tools/rule_review.py
status: enforced
---

`python tools/rule_review.py --check` is the `rule review pack` step of
`tools/ci/run_local.ps1`. Without `--check` the same script writes
`docs/20-rule-review.md`; the gate is the half that parses and writes nothing.

# What it defends

The pack is the document a domain expert marks up (AC-051 names that review as an
exit criterion; AC-040 is the catalogue it reviews). It is **generated** so the
words the reviewer reads are the words the product ships, and a hand-copied pack
drifts the first time a rationale is corrected.

A generator nobody runs stops being true quietly. This one stopped working at
DR-132's `ELE-005` and nothing noticed for three rulings: the plan band (DR-154)
and `RCK-014` (DR-219) reached the catalogue with no group in the pack, the pack's
headline number was already wrong, and no build failed because no build ran it.
Board `#972` made it a gate. It fails when:

- a rule in `packages/rackpal_core/lib/src/validation/rule_catalogue.dart` has no
  group in the script's `GROUPS` table (**a new rule must be placed by hand**; a
  catch-all group would bury it at the bottom of the pack, where a reviewer stops
  reading);
- a group names a rule the catalogue no longer holds;
- a rule sits in the wrong band: the plan advisories (`kPlanRules`) belong to the
  plan group and the v1 catalogue (`kRuleCatalogue`) to the others, read from
  which list each rule is declared in rather than guessed from an id prefix.

# What it deliberately does not

- **It does not compare the pack on disk with the catalogue.** `--check` returns
  before it writes, so a committed `docs/20-rule-review.md` can be stale in wording
  (a corrected rationale, a changed summary) and the gate stays green. Regenerate
  the pack when a rule's text changes.
- **It does not judge the grouping.** A rule under the wrong subject, but in the
  right band, passes. The grouping is editorial.
- **It parses source with a regular expression, not Dart.** It does so on purpose:
  a `dart run` needs a file under `packages/*/tool/`, and anything left there is
  analyzed and counts against the
  [analyzer ratchet](analyzer-baseline.md). The cost is that a rule entry written
  in a shape the pattern does not match is not seen at all, and a rule that is
  never seen is never reported as ungrouped. It was checked field by field against
  a dump of the catalogue once; it has no test of its own.
- **It says nothing about whether a rule works.** That is
  [AC-051 pair coverage](ac-051-pair-coverage.md), which asks the same catalogue a
  different question.

# Citations

[1] `tools/rule_review.py`, its header (the reason it is a gate)
[2] `packages/rackpal_core/lib/src/validation/rule_catalogue.dart`
[3] `docs/20-rule-review.md`, the generated pack
[4] `docs/canonical-decisions.md` AC-040 and AC-051
