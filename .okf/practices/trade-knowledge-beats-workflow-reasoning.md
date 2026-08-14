---
type: Playbook
title: Trade objections are questions, not findings
description: >-
  Three rulings have now overruled an objection grounded in "how the work
  happens in the field". The corpus is authoritative about the code and silent
  about the trade, and the two kinds of objection are indistinguishable in
  output unless they are labelled.
tags: [practice, process, rulings, trade, g4, dr-048, dr-055, dr-056]
timestamp: 2026-08-14T00:00:00Z
status: adopted
---

An objection grounded in the corpus, a ruling, a census, a measured figure, is
**evidence**. An objection grounded in *"installers probably do X"* is a guess
wearing the same confident sentence structure. **Mark which one you are making**,
and put the second kind as a question.

# The instances, named rather than counted

**[DR-048](/decisions/dr-048-network-value-is-dated-and-t650-ships.md), canon
§11.47.** The recommendation was to store a device's management URL and never
launch it, because *"the drawing machine is not on the rack's network."* It
frequently is: a project copy lives at the client's home, and UniFi Teleport,
OvrC, Eero Insight, Nice Management Cloud and BlueBolt put a tech on that
network routinely. Two of three recommendations in that ruling were overruled
this way.

**[DR-055](/decisions/dr-055-the-termination-schedule-prints-both-ends.md), canon
§11.54.7.** A field end is terminated at trim-out and a rack end at rack build,
often weeks apart and sometimes by different people, which is a real argument for
two sheets. The user ruled one. Canon records it as *"the objection is sound and
was overruled on trade grounds, not missed."*

**[DR-056](/decisions/dr-056-generic-is-the-trades-word-for-unspecified.md), canon
§11.55.4.** The argument was that pre-filling `Generic` in a manufacturer column
puts a value nobody typed onto a client deliverable, where it reads as a claim
that a real device is a no-name unit, and that the
[G4](/invariants/g4-unknowns-are-counted.md) unknown rollup cannot see a field
holding a value.

**That one is the cleanest case, because the objection was not outweighed, it was
simply wrong.** It depended entirely on how a reader parses the word. `Generic`
is standard in the industry for *unspecified / by others / contractor's choice*,
so it is the trade's own spelling of what `—` means and the people holding the
sheet parse it correctly. There was nothing to trade off.

# Why the corpus cannot catch this

The corpus is authoritative about the code and the rulings, and **silent about
the trade**. Nothing in `docs/` says what a foreman reads a column as, or where a
tech is standing when they open a project. So a workflow claim can be confidently
wrong and pass every check this repository has, which is the same gap
[verify claims by reading the codebase](/practices/verify-codebase-claims-by-reading.md)
covers for code and [census before building](/practices/census-before-building.md)
covers for data. This one covers the industry, and its only instrument is asking.

# The shape

Keep making the arguments: DR-048's and DR-055's were both recorded as *sound*,
and the habit has caught real problems. But **label the kind**, and phrase the
trade ones as questions. The tell is a sentence about people rather than about
code: *"a user would read this as…"*, *"an installer would not…"*, *"nobody
carries…"*. None of those is checkable here.

**And when one is overruled, record the trade fact in the ruling**, not just the
outcome. DR-056 §11.55.3 states what `Generic` means in the field, which is now
the only place in the corpus that says so, and it is what stops the same
objection being raised again in six months by somebody equally reasonable.
