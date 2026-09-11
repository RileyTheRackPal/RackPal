---
type: Playbook
title: A gate's scope is part of its claim, so read its scan and not its name
description: >-
  The reachability gate caught an unreachable callback one chapter and missed an
  entire unreachable feature the next. It scans function-typed fields on *Actions
  records in one package; the importer was free functions in another. Both facts
  are in the gate's source and neither is in its name.
tags: [practice, gates, reachability, census, plan-e, plan-g, plan-h, plan-i, len-a]
timestamp: 2026-09-08T00:00:00Z
status: adopted
---

A green gate is a claim about **what it scanned**. Every gate has a scope, the
scope is narrower than the name, and the difference is where defects live.

# The instance

At `PLAN-E/3`, [callbacks-have-callers](/gates/callbacks-have-callers.md) refused
a finished callback because nothing supplied it, and it was right; that became
[its own practice](a-gate-can-move-a-chapter-boundary.md).

One chapter later, `PLAN-E/5`'s census found that **the entire floorplan importer
has no caller**: six functions and a dialog, all built, all tested, reachable
from nothing, so `AddPlanUnderlayCommand` had no producer and no project could
contain a floorplan. The board was green throughout.

The gate could not have fired. It scans:

- **function-typed fields on `*Actions` records** — the importer is free
  functions;
- inside **`packages/rackpal_ui/lib`** — the importer is in `apps/rackpal/lib`.

Two independent misses, and the file is called `plan_import_actions.dart`, which
reads like something that gate covers.

# The shape

**"We have a gate for that" is not a finding; it is a hypothesis about scope.**
The failure is not that the gate is bad. It is that a gate's *name* is a summary
written for the case it was built for, and a reader one chapter later applies it
to a case it never saw.

This is [a-ticket-is-a-hypothesis-not-a-diagnosis](a-ticket-is-a-hypothesis-not-a-diagnosis.md)
pointed at the tooling instead of at a brief.

# And a third instance, where the gate is a compile error

`PLAN-G` found the same shape in the most trusted mechanism this repository has.
`cable_footage.dart`'s `_isQuantity` is an exhaustive `switch` with no default arm,
left that way on purpose so that *"the day it is added this file stops compiling and
somebody decides, rather than a bound silently joining a purchase."* **It worked**,
seventeen months after the comment was written: adding
`ScheduleLengthSource.planLowerBound` stopped the build in exactly one place.

**In exactly one place.** `schedule.dart`'s `_footageOf` builds the sheet footer's
`Σ 11 runs · 601 ft · 3 estimated` by reading a `Len?` and never asking where the
number came from, so a plan-derived floor would have joined that total with nothing
to stop it. `PLAN-G`'s own ticket said *"the footage rollup"*, singular, on the
strength of the trap's reputation.

**A gate that stops the build is still a gate with a scan**, and the scan here is one
function's argument type. The rule below is unchanged; what this adds is that being a
compile error buys certainty about the site it guards and says nothing whatsoever
about the site beside it.

# And a fourth, where three fired at once and one was designed

`PLAN-H/1` added a fourth `SheetRole` and stopped the build in **three** places:
`build_document.dart`'s switch over the role, `page_sizes.dart`'s over the paper
size, and two role canaries in the suite. Only the `cable_footage.dart` one from
`PLAN-G/1` was ever *designed* as a trap; these are consequences of exhaustiveness
and definite assignment, and they worked identically.

**The useful half is what they did NOT catch.** `ExportRequest` had no field for
the container's bytes and `PdfImageResolver` had zero production call sites, and no
switch anywhere could see that: an absent parameter is not an unhandled case. The
compiler catches the shape of what exists and says nothing about what is missing,
which is the same asymmetry a regex-scanning gate has, arrived at from the other
end.

# And a fifth, where the scan is a `for` loop and the scope is a list name

`PLAN-I` split the rule catalogue in two: `kRuleCatalogue` and `kPlanRules`, one
mechanism over two bands. **Three separate gates then went on proving things about
one band while describing both**, and every one of them reads as a sweep over
everything:

| The sentence in the test name | What the loop said |
|---|---|
| every tier-2 and tier-3 rule can be acknowledged | `for (final rule in kRuleCatalogue)` |
| every rule that files a finding has a severity | `for (final rule in kRuleCatalogue)` |
| every severity, taken one at a time, still exports | `for (final rule in kRuleCatalogue)` |

Nothing broke. Nothing could break: the loops were correct about the collection
they named, the collection stopped being the whole subject, and **a `for` loop has
no way to say it expected more**.

**The tell is that the scope is a NAME rather than a predicate.** A regex gate at
least fails visibly when a file moves. A loop over `kRuleCatalogue` keeps passing
forever, and the fix is the same one `corpusGaps` already carried: sweep the joint
registry, and **count what you reached**, so a loop over an empty band fails
instead of passing silently.

# And the sub-shape worth its own name: a guard written against a stranger

`findings_view.dart` promised in capitals that a fifth `Finding.primaryEntityId`
type would be *"a test failure, not a blank cell"*. The test carrying that promise
asserts `locusLabel` returns null for a **hand-written id belonging to no
collection at all**.

That is a statement about a stranger. It cannot fail when a real type arrives,
because a real type is exactly the thing that resolves. Two arrived, `Net` and
`PlanUnderlay`, and both shipped: `ELE-005`'s findings had been unclickable for
three epics with the promise sitting above them the whole time.

**Replacing it cost nothing and found both on the first run.** Every AC-051 fixture
already evaluates a real document, so the outcome record now carries the label the
panel would print for each finding produced, and the harness fails on a null. The
difference is not rigour. It is that **the census runs the producers**, where the
old guard ran an example the producers cannot generate.

> A guard built from an input you invented tests your imagination. A guard built
> from the system's own output tests the system.

# And a sixth, where the gate was written BY the chapter it failed

`LEN-A/3` shipped a derivation with no production caller on purpose, because
the chapter that would wire it up was two along. It left a case saying so and
naming that chapter as what would break it, which is the practice this corpus
calls *a test asserting an absence names its due date*.

`LEN-A/5` wired it up. **The case stayed green.** The scan walked
`rackpal_core/lib` and the caller landed in `rackpal_ui`.

This is the same failure as the five above with one difference worth naming:
**the author of the gate and the author of the thing that escaped it were the
same person, two chapters apart, and the gate was written specifically to catch
this.** Knowing the rule is not the same as applying it to the gate you are
writing at that moment.

The cheap check, and it is one question: **does the thing this gate is about
live where the gate is looking?** A derivation in `rackpal_core` has callers in
`rackpal_ui` and `apps/rackpal` by construction, because that is what the layering
is for; a scan rooted at the package that DECLARES a symbol can only ever find
the callers that are least likely to exist.

# The rule

**Before relying on a gate to have covered something, read its scan.** Two
questions, both answerable in under a minute from the gate's own source:

1. **What does it match?** A regex over a class shape, a type predicate, a
   filename convention. Anything expressed differently is invisible, however
   similar it looks.
2. **Where does it look?** Almost every gate in this repo names a root. A gate in
   one package says nothing at all about another.

And when you actually need the answer, **census by call site rather than by
gate**: for each public entry point a chapter claims to have built, grep for its
name across `lib/` and subtract its own file. It is one command per symbol,
it produces a number rather than a feeling, and it is what found this. See
[census-before-building](census-before-building.md) and
[ask-what-consumes-each-tasks-output](ask-what-consumes-each-tasks-output.md),
which ask the same question earlier and cheaper.

**A count of zero is the finding.** Write it down as a number, in a table, per
symbol, so the next reader can re-run it instead of trusting it.
