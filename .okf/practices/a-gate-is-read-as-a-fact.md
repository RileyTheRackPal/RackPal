---
type: Practice
title: A gate's output is read as a fact, so check the gate before filing against the tree
description: >-
  Two of the reachability gate's twelve findings were bugs in the gate. Both
  became board items with DONE WHEN clauses on the gate's word alone, and one of
  them asserted that a class is declared in a file that declares nothing.
tags: [practice, gates, census, tooling, m5]
timestamp: 2026-09-13T00:00:00Z
---

`#872`'s reachability gate reported twelve `Command` classes with no path from a
person. **Ten were real** and are closing one at a time. The other two were the
gate:

* **`SnapshotCommand` does not exist.** `snapshot_command.dart` declares nothing
  and says so in its own header; what it holds is an indented sketch of the class
  inside a `//` comment. The gate's declaration scan had always stripped
  comments. Its Command *inventory* read the raw file.
* **`AddLinkCommand` exists and is not for a person.** It is the only
  Link-minting command needing no device, port or panel, which is what makes it
  the right step in a property sweep and the wrong thing to put in front of
  somebody.

Both became board items, each with a `DONE WHEN` clause, on nothing but the
gate's say-so. `#880`'s first sentence reads *"`SnapshotCommand` is declared in
`snapshot_command.dart`"*. **Opening that file is what settled it**, and it cost
one `cat`.

# The sharper half

**The identical bug was already recorded in that gate's own header, pointing the
other way.** Attempt 2 of its three failed censuses *"let a name in a COMMENT
count as reachable"*, and a real command fell off the list because of it. That
was fixed on the EDGE side of the scan. The same mistake on the NODE side
survived the whole life of the gate, in a file whose header is an essay about
getting this exact question right three times.

**A bug found in one direction of a scan is a reason to check the other
direction, not evidence that the scan is now clean.** A census has at least two
sides: what it counts as a THING, and what it counts as a REFERENCE to a thing.
Fixing one teaches you nothing about the other, and the fix reads like
thoroughness, which is what stops anybody looking.

# What to check

**Before filing a ticket against code a tool named, open the file.** Not to
double-check the tool's arithmetic: to confirm the subject exists and is the
thing the tool thinks it is. A finding is a hypothesis, and a finding from a
gate is a hypothesis wearing a uniform.

**When a gate has two passes over the same text, diff them.** Run both and print
the set difference. Here it was one line of Python and the answer was 73 against
72; the phantom was obvious the moment the two numbers sat next to each other,
and invisible for as long as only one of them was ever computed.

**A gate that carves out an exception must check the exception as hard as the
rule.** A permanent exemption is a standing claim, and the day it stops being
true nothing else will say so. Bind the staleness check to it, and make the
failure message ask which of the two facts is wrong rather than offering the
cheaper deletion.

# Related

* [A gate's scope is part of its claim](a-gates-scope-is-part-of-its-claim.md)
  is the neighbouring failure: there the gate scanned less than its name
  promised, here it scanned more than its subject contained.
* [Diagnose before fixing](diagnose-before-fixing.md) is the general rule these
  two tickets are instances of: twelve consecutive fix commits there touched
  neither cause, and here two tickets were written against a cause that was not
  in the file they named.
* [Two documents agreeing is not
  verification](two-documents-agreeing-is-not-verification.md) is the same
  hazard between prose; this one is between a tool and the prose that quotes it.
