---
type: Practice
title: A wrong ruling ID resolves, which is why nothing catches it
description: PLAN-D cited AC-058/D12 for image import hardening across two source files and two derived documents. D12 is localisation. The ID came from a roadmap row written four weeks earlier and was never resolved by anybody, because a citation arrives carrying the authority of whatever it points at and every check this project runs verifies existence rather than content.
tags: [practice, citations, corpus, hardening, ac-058, dr-029, plan-view]
timestamp: 2026-09-07T00:00:00Z
status: adopted
---

Roadmap §8.2 requires every issue and PR to cite a ruling ID, and the requirement
works: this corpus is unusually good at saying *which ruling* a line of code
serves. What it has no defence against is a citation that points at the **wrong**
ruling, because that is the one failure mode that looks exactly like success.

# The instance

`PLAN-D` built the floorplan import's three hardening controls and cited them,
four times, to **`AC-058/D12`**.

| | |
|---|---|
| What the code says D12 is | *"the byte and pixel caps every import path owes"* |
| What canon §AC-058 says D12 is | *"the DSL, the CSV synonym table and all registry display names are structurally English-only"* |
| The item that actually owes the caps | **D8**, *"no security review of file import"*: zip-slip protection, entry-count and uncompressed-size limits, JSON depth and size limits on every import path |

Two source files (`persistence/image_header.dart` and its test) and two derived
documents (docs/03's dependency table, docs/09's roadmap row) carried it. Nobody
resolved it once.

**And it was not invented at the point of use.** It came from docs/09's Plan view
import row, written 2026-08-10 in `ffeb16e`, four weeks before the chapter that
copied it. The chapter did what §8.2 asks: it cited the ID the roadmap gave it.

# Why nothing caught it, and this is the reusable half

**A wrong ID resolves.** That single property defeats every check in play:

* It is not **dangling**. `AC-058` exists, `D12` exists, and both are in canon. A
  reader who verifies the citation *exists* comes away satisfied, and that is the
  only verification anybody performs at speed.
* It is not a **collision**. Collisions are the failure this project already
  defends against, by scanning refs before claiming a new ID. That defence is
  about **allocating** an ID and has nothing to say about **reading** one.
* No gate reaches it. Inspect `run_local.ps1`: the analyzer, the formatter,
  PAL-1, palette parity, registry parity, glyph coverage, the JUnit self-test,
  the AC-051 pair gate, the suites and the build. **Not one of them opens canon.**
  A gate that verified every cited ID existed would be cheap to write and **would
  have passed on this**, which is the point: the defect is semantic, and the
  cheap automatable half is exactly the half that was never wrong.

And the damage is not that a comment is inaccurate. **A citation launders
authority.** `AC-058/D12` in a file header reads as *"a ruling requires this"*,
so the next person to touch those caps treats them as adjudicated and stops
looking. What they cannot then do is find the ruling that ACTUALLY governs them:
a reader who does resolve D12 lands on localisation, concludes the citation is
noise, and is left with no route to D8's real obligations at all. The caps
themselves happen to be right. **The trail back to why they are right was
broken**, in a corpus whose entire premise is that the trail survives.

# The rule

**Resolve a ruling ID the first time you write it down. Read the row, not the ID.**

Ten seconds:

```bash
grep -n "D8\b" docs/canonical-decisions.md | head
```

Then read what came back and check it is about the thing you are building. If the
row does not describe your work in its own words, you have the wrong ID.

**Do this hardest to an ID you copied from a derived document**, which is where
this one came from and is the highest-risk source in the corpus: docs/00-09, 11,
13 and 14 are priority-3 and explicitly allowed to be stale (canon §12 lists
derived edits that are *owed but unmade*). An ID in a roadmap row has, by
construction, less standing than the ruling it names, and it arrives pre-trusted
anyway because the paragraph around it is good.

**Sub-item citations are the sharpest case.** `AC-058` alone covers eleven
findings in one table (D1, D3, D4, D5, D7, D8, D10, D11, D12, D13, D14), so the
slash-suffix is doing all the work and a wrong suffix resolves to a real,
adjacent, plausible-sounding row under the same heading. `D8` and `D12` are three
rows apart.

# What this is not

It is not
[a stated cost is a hypothesis](a-stated-cost-is-a-hypothesis.md), which is about
the **quantity** attached to a correct citation. Here the quantities were measured
and right; the **pointer** was wrong.

It is not
[two documents agreeing is not verification](two-documents-agreeing-is-not-verification.md),
though it rhymes. There, two documents named three fields that existed in neither
the model nor the codec. Here one document named an ID that exists perfectly well
and says something else, and the four places carrying it agreed only because they
were copies of one source.
