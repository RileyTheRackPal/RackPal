---
type: Gate
title: Dependency table parity
description: >-
  Every package named in docs/03 section 10.1 must resolve to a workspace
  pubspec, and every workspace dependency must resolve to a row. Written after a
  document described a state-management layer nobody had built, for five
  milestones, with nothing able to fail.
tags: [gate, architecture, dependencies, verification, practice, dr-088]
timestamp: 2026-08-25T00:00:00Z
status: adopted
---

`apps/rackmate/test/dependency_table_test.dart`.

# What it defends

`docs/03-architecture.md` §10.1 is the project's record of **which third-party
packages it depends on and why**. Every row now carries a **Status** cell:
`in use`, `planned (Mn)`, `planned (unscheduled)` or `n/a`. The gate asserts
three things:

1. every **`in use`** row resolves to a dependency declared in some workspace
   `pubspec.yaml`;
2. every dependency declared in any workspace `pubspec.yaml` resolves to a **row**;
3. no **`planned`** row is already installed.

On its first run: 24 rows, 23 naming a package, 16 `in use`, and 23 third-party
dependencies across five pubspecs.

# The defect that produced it

Two of them, in opposite directions, found together (**DR-088**).

**Forward.** **ADR-011** accepted `flutter_riverpod` as the state-management
choice and §4 spent a numbered section describing the provider layer. At v0.4.63,
five milestones later, `riverpod` appeared in **zero** Dart files, pubspecs and
lockfiles. Seven of the eight rows in this class were similar: `printing`,
`desktop_drop`, `logging`, `intl`, `flutter_localizations`, `integration_test`,
`benchmark_harness`.

**Reverse.** `screen_retriever ^0.2.0`, a direct app dependency, was in **no**
row. Its pubspec comment **cites "§10.1's `window_manager` row"** by name, so the
author had the table open, read a row out of it, and did not add one.

**A gate with only one direction would have been green through half of this**,
which is why there are three tests and not one.

# Why nothing else saw it

* The analyzer sees nothing: a package named only in markdown is not code, and
  a package installed and imported is perfectly legal.
* `flutter pub get` is happy either way. An unused row costs nothing and an
  undocumented dependency resolves fine.
* `flutter_dependency_test.dart` reasons about `pubspec.lock`, and asks whether
  Android implementation packages leaked into a Windows graph. A row that
  describes nothing is invisible to it.
* **The corpus is under test and the tests read prose for *shape*, not for
  truth.** `registry_claim_test.dart` checks that a claim is worded as a bound;
  nothing checked that a claim's subject existed.

# The `VERIFY:` marker is the general lesson

ADR-011 carried `VERIFY: Riverpod 3 API surface BEFORE THE PROVIDER LAYER IS
WRITTEN`. **The condition never came true, so the check never fired**, and the
document went on describing the layer. A precondition attached to work that does
not happen is not a tripwire, and every other `VERIFY:` in this corpus that is
conditioned on future work is inert on the same reasoning. This gate asserts a
**claim** instead of scheduling a look, which is the difference that makes it
capable of failing.

# What it deliberately does not flag

**The workspace's own packages.** `rackmate_core`, `rackmate_ui`, `rackmate_text`
and `rackmate_export` are path dependencies on this repository, and §10.1
documents third-party choices. The exclusion is **derived by listing
`packages/`**, never enumerated, so a new package is covered the moment it exists.

**A `planned` row's plan.** Seven rows are recorded and not adjudicated
(DR-088 §11.87.8). Whether `printing` is still M6's intention is M6's question.

# No exemption list, and that was a choice

The cheap shape is a `const _knownMissing = [...]` at the top of the file. This
repository has already written down why that is a trap:
[a test's exemption list is where the bug lives](/practices/a-tests-exemption-list-is-where-the-bug-lives.md).
The status lives in **a cell on the row it describes**, is read by the gate rather
than trusted by it, and cannot change without the diff naming the dependency whose
state changed.

# Its own blind spots, stated

* **It is a line parser, not a YAML parser.** A dependency declared with unusual
  indentation, or in a block scalar, is invisible. False negatives are acceptable
  here; a flaky false positive is not.
* **It does not read `pubspec.lock`**, so transitive packages need no row.
* **It does not check the constraint.** A row saying `^1.16.0` beside a pubspec
  saying `^2.0.0` passes. Folding version drift in would fail the build on routine
  bumps until people learned to ignore it, which is how a gate dies.
* **It reads one table in one file.** Other documents make dependency claims and
  are unguarded; `README.md`'s tech-stack table is the nearest one.

# It was watched failing

All three directions, plus the anti-vacuity case that matters, were confirmed to
report the offending name before the file was trusted:

| Break | Reported |
|---|---|
| `printing` flipped to `in use` while uninstalled | `line 883: printing` |
| the `screen_retriever` row deleted | `screen_retriever (apps/rackmate/pubspec.yaml)` |
| `path` flipped to `planned (M6)` while installed | `line 882: path is planned (M6)` |
| the **Status column removed from the header** | the header it actually found, quoted back |

**The fourth is the one that would have made the whole file vacuous.** Without
the Status column, every row's second cell holds the constraint, every status
compares unequal to `in use`, direction (1) asserts over an empty set, and the
suite goes green while checking nothing. Alongside it: floors of 20 parsed rows,
15 `in use` rows and 15 third-party dependencies, and a positive and a negative
control on the pubspec parser. See
[assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md).
