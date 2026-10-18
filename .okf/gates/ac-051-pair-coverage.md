---
type: CI Gate
title: AC-051 pair coverage
description: Every rule in the validation catalogue, both bands, has a known-bad design that fires exactly that rule and a near-miss that does not fire it. The subject is the catalogue, not any one evaluator's enum.
tags: [gate, ci, validation, drc, fixtures, ac-051, ac-040]
timestamp: 2026-10-17T00:00:00Z
resource: packages/rackpal_core/test/validation/drc_corpus_test.dart
status: enforced
---

`dart test test/validation/drc_corpus_test.dart`, run from `packages/rackpal_core`,
is the `AC-051 pair coverage` step of `tools/ci/run_local.ps1` and the
`Gate: AC-051 pair coverage` step of both pipelines. The pipelines lacked the named step
until 2026-10-18, so on the service the file ran only inside the core suite and a missing
pair read as one red case among thousands, which is what the step exists to prevent.

# Why it is a named step

The core suite runs this file anyway. It is named separately because what it
protects is a **schedule** control: the roadmap's M5 risk list names the pressure
to add "just one more obvious rule" without its pair as how that milestone
overruns. Buried among thousands of passing tests that failure is one red line;
as a step it reads `AC-051 pair coverage FAILED` in the summary, where whoever is
adding a rule will see it. (Board `#302`, milestone M5-G4.)

# What it defends

AC-051: **no rule ships without its pair.** For each rule, a **known-bad** design
that must produce exactly that finding and nothing else, and a **known-good
near-miss**, one property away and correct, that must not fire it. The near-miss is
the half that gets skipped and the half that matters: a known-bad alone proves a
rule fires, never that it discriminates.

The assertions are:

- every rule in the catalogue, in both bands, has both halves;
- every fixture holds its own contract (a known-bad that also trips two other rules
  is not evidence about this one, so "exactly its own rule" is checked);
- the corpus is not vacuous, and the plan band is gated separately, so a loop over
  an empty band cannot pass silently.

# Why the subject is the catalogue

Before M5-G each evaluator's tests carried their own pairs and their own coverage
assertion, driven off their own enum, and together they still could not enforce
the gate. The catalogue is the **union** of four evaluators' rules (CR-021), so
three coverage tests, each complete over its own enum, all pass while a catalogue
row has no pair at all: no enum mentions it, so no test is looking. The pairs live
in one corpus (`fixtures/drc_corpus.dart`) and the coverage question is asked of
`kRuleCatalogue` and `kPlanRules`.

# What it deliberately does not

- **It proves a pair exists and holds, not that the rule is correct.** A fixture
  author who misjudged the domain writes a pair that passes. The expert review of
  the shipped rules is a separate milestone exit criterion, and
  [the rule review pack](rule-review-pack.md) is its input.
- **It does not check that a rule exists for every hazard.** Only that every rule
  that exists is covered.
- **It pins the catalogue's size on purpose.** The vacuity test asserts the length
  of each band, so adding or removing a rule moves a number in this file
  deliberately and visibly. Read the figures in the test, not here.
- **It tests the evaluators, not the UI.** Whether a refusal is shown, or a finding
  reaches the issues panel, is covered elsewhere.

# Citations

[1] `packages/rackpal_core/test/validation/drc_corpus_test.dart`
[2] `packages/rackpal_core/test/validation/fixtures/drc_corpus.dart`, its header (why one corpus)
[3] `packages/rackpal_core/test/validation/fixtures/drc_fixture.dart`, its header (four evaluators, one question)
[4] `docs/canonical-decisions.md` AC-051, AC-040; DR-154 section 11.153.4 for the plan band
