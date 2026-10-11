---
type: Design Ruling
title: DR-248 · Nothing is adopted until it is fourteen days old, Flutter moves to 3.47.5, and the lint set moves to 11
description: >-
  From #1046. Most of the outdated list was held by the Flutter SDK, so updating every dependency meant
  moving the load-bearing pin. A standing rule: no pub package or SDK release is adopted before it is
  fourteen days old, exceptions named. Flutter 3.44.4 to 3.47.5; very_good_analysis 9.0.0 to 11.0.0 with
  cheap infos fixed and the pin raised only by the remainder.
tags: [ruling, dependencies, supply-chain, cooldown, flutter, pin, lints, analyzer, dr-248, dr-138]
timestamp: 2026-10-11T00:00:00Z
ruling_id: DR-248
canon_section: "11.247"
status: ruled
---

Settled by the user on 2026-10-11 for `#1046`.

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| Cooldown | User, on the recommendation, standing | No release adopted before 14 days old; an exception names its reason |
| Flutter | User, on the recommendation | 3.47.5, the newest stable at least 14 days old (not 3.47.7, not 3.44.9) |
| Lint set | User, on the recommendation | very_good_analysis 11.0.0; cheap new infos fixed, pin raised only by the remainder |
| Lockfile | User, on the recommendation | `pubspec.lock` committed; CI enforces it, sha256 included. Without it the cooldown held on one machine only |

# The trap this ruling records

**"Update everything" was mostly an SDK upgrade in disguise.** `pub outdated` showed whole major
versions available, and most of them could not move without the Flutter pin moving, which the corpus
calls load-bearing. Measure what holds a package back before promising to move it.

# A finding that was wrong, and what actually happened

**This section first said a failed `pub get --enforce-lockfile` rewrites `pubspec.lock`. IT DOES NOT.**
Measured again in a worktree no IDE had open: a mutant pubspec, exit 65, *"Would change 1 dependency"*,
and the lock byte-identical afterwards. **What rewrote the lock was an IDE.** Android Studio and VS Code
were both open on the repository, each with a Dart language server on the global Flutter SDK (3.44.4),
and the Dart tooling re-runs `pub get` whenever a `pubspec.yaml` changes. Proven directly: a comment
appended to one pubspec, and the lock was rewritten two seconds later with no command run. The
"failed enforce run" had simply been the pubspec edit that preceded it.

It cost more than one false sentence. The same race reverted a cooldown upgrade (`meta` 1.19.0 back to
1.18.0, `xml` 7.1.0 back to 7.0.1: the 3.44.4 resolution) between two commands. **Dependency work on a
tree an IDE has open is a race.** It was finished in a sibling worktree (`../w1046`) that no IDE watched.

# Why a cooldown

Two packages published six releases between them in the two days before the upgrade. A maintainer at
work and a hijacked publish look the same on day one; on day fourteen they usually do not.

# Citations

[1] `docs/canonical-decisions.md` §11.247
[2] `docs/11-testing-and-quality.md` §7 (the pin and the cooldown), §8 (the lint pin and the ratchet)
[3] [DR-138](dr-138-lift-the-page-not-re-draw-it.md), whose Flutter-version limb no longer holds
