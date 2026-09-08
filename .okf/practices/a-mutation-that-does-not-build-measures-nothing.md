---
type: Playbook
title: A mutation that does not build measures nothing, and it reports as a survivor
description: >-
  A mutation run at PLAN-E/4 printed SURVIVED for the one mutation that mattered
  most. The edit had not compiled. Zero failing tests is the same output for
  "the suite cannot see this defect" and "the suite never ran", and only one of
  those is a finding.
tags: [practice, testing, mutation-testing, tooling, plan-e]
timestamp: 2026-09-08T00:00:00Z
status: adopted
---

Mutation testing answers one question: **would the suite notice?** The answer is
read off a count of failing tests, and a count of zero has two causes that look
identical.

# The instance

`PLAN-E/4` mutated `unpinned_carriers.dart` six ways. The first was the one the
chapter existed for: **make the strip list devices only**, which is
[DR-140](/decisions/dr-140-the-rack-is-pinned-from-the-unpinned-strip.md)'s whole
subject and the defect the brief names.

```
1 devices-only strip (drop the rack loop): SURVIVED (0 failing)
2 an unknown location joins a named room:  KILLED (1 failing)
...
```

Five killed, one survived, and the survivor was the important one. Re-running it
with the plain reporter gave the real answer:

```
Failed to load "test/derived/unpinned_carriers_test.dart":
  lib/src/derived/unpinned_carriers.dart:173:23: Error: 'Rack' isn't a type.
```

`Rack` is not imported in that file. **The mutation never compiled**, so no test
ran, so nothing failed, so the harness printed the same thing it prints for a
genuinely blind suite. Rewritten as a runtime-false guard rather than a type the
file cannot see, the same mutation killed **four** cases.

# Why it is worth a practice

The failure is not "I wrote a bad mutation". It is that **the harness's happiest
output and its most alarming one are the same string.** A run that says SURVIVED
invites exactly one response, which is to go and write the missing test, and
that response is wasted work when the line was never exercised.

It is also the shape most likely to hit the mutation you care about, because the
interesting mutations are the structural ones: deleting a loop, swapping a type,
removing a parameter. Those are the edits that stop compiling. The trivial ones
(flip a boolean, change a number) always build.

# The rule

**A mutation run reports three outcomes, not two.** KILLED, SURVIVED, and DID
NOT BUILD, and the third must be detected rather than inferred from a zero.

- Check for a load failure explicitly. `Failed to load` in the output, or a
  non-zero exit with no test results, is not a survivor.
- **Prefer mutations that cannot fail to compile**: a guard that is always true,
  an argument dropped from a call that has a default, an empty iterable of a
  type the file already names. Reach for a type or an import the file may not
  have only when nothing else expresses the defect.
- **A survivor is a finding and gets read, not filed.** If a mutation of the
  line your chapter is about survives, that is either a missing test or a broken
  mutation, and both are worth the two minutes to tell apart.
- Say which happened in the commit. `run_suite.ps1` carries the count and the
  mutations behind it, and a mutation excluded for not building belongs there
  with its reason, so the next reader does not count it as evidence.

See [assert-the-artifact-not-the-mechanism](assert-the-artifact-not-the-mechanism.md):
mutation testing is how that rule gets checked, so a mutation run that lies is a
check on the checker going quiet.
