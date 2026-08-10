---
type: Design Ruling
title: DR-034 — The community library is fetched as an .rmda release asset, never cloned
description: DR-033's read path. Clone does not survive the platform, and the format is already ruled and unbuilt. The bundled snapshot is a floor and the fetch is a ceiling, which is why both first-launch answers were taken.
tags: [ruling, v1.1, catalog, distribution, rmda, determinism, scope, dr-034]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-034
canon_section: "11.33"
status: ruled
---

Settled by the user on 2026-08-09, the same day and conversation as
[DR-033](/decisions/dr-033-community-catalog-submission.md), which it completes.
DR-033 is the **write** path, one device leaving one machine. This is the
**read** path, the whole library arriving on every machine. One feature, two
directions, ruled apart because they fail differently.

# The ruling

1. **One `.rmda` per release tag**, attached as a release asset, fetched over
   HTTPS. Nothing is cloned.
2. **The installer bundles a snapshot**, so a first launch with no connectivity
   still has a library.
3. **First run offers and never blocks**: a dismissible card with the device
   count and download size.
4. **`releases/latest`, unauthenticated, at most once per 24 hours on launch**,
   behind a **non-modal** notice.
5. **Updating is a user action.** The installed tag is recorded.
6. **A separate library**, filterable in the palette, **never merged into the
   seed**.
7. **v1.1**, under DR-033's precondition.

# Why it is not a clone

**Flutter desktop has no git.** Cloning means vendoring libgit2 or shelling out
to a binary that is not on an integrator's site laptop: a native dependency on
both platforms and an entry in the macOS debt register, for a feature whose whole
job is to fetch some JSON. **A clone also drags the history**, every revision of
every device anybody ever proposed, to deliver the current one.

**The third reason decides it: the format is already ruled and not yet built.**
[DR-015](/decisions/dr-015-extension-family.md) ruled `.rmda` as the device
archive, and M4 already owes *"the codec, the library directory service,
import/export, and the palette filter that makes more than one library usable"*.
A community release **is** a library pack, so HTTPS instead of email changes the
transport and nothing else. A tarball of loose `.rmdx` files would be a second
on-disk shape the library directory service carries forever, because the first
users to install one never stop having it.

# The floor and the ceiling

The user took the bundled library **and** the opt-in card rather than choosing.
That is not indecision, it is the better answer. **The bundle is a floor and the
fetch is a ceiling.**

A bundled snapshot alone ties library freshness to the application's release
cadence, which is the exact coupling release tags exist to break. A fetch alone
means a first launch in a half-built house with no wifi shows an empty library,
and since the seed is generic archetypes (DR-002), **the user who most needs a
real SKU is the one standing in the mechanical room**.

A consequence to expect rather than be surprised by: the application ships less
often than the catalog does, so the bundled tag is nearly always behind on first
launch, and **the first-run card and the update notice are the same mechanism**.

# This is not RJ-014's auto-updater

RJ-014 refused an in-app mechanism that updates the **application**, on the
ground that *"auto-update is a security surface before there are users"*, and
permitted a signed installer plus a version-check ping. Nothing here updates the
application: no code is fetched, nothing is executed, and templates *"are inert
data with no executable content"* by docs/06 §7.3. Clause 4 is that permitted
ping, aimed at a catalog.

# Determinism is a gate here, not a preference

Same document, same display list, same exported bytes. The four starters do
triple duty as goldens, perf fixtures and screenshot source. **If a golden could
resolve a template out of a library that arrives over the network, the goldens
would depend on a release tag and stop being goldens.** So seed and community
library are separate resolution scopes, the starters read the seed only, and a
test asserts it.

This is the clause most likely to be violated by accident, because merging both
libraries into one palette list is the obvious shortcut and it stays invisible
until a golden moves under somebody six months later.

# A download is an import

AC-058/D8's JSON depth and size limits apply to a fetched bundle exactly as to a
chosen file, because **the network is not a more trusted input than the disk**,
and the asset is built by whoever holds merge rights on a repository full of
strangers' contributions. `contentHash` is verified before install, and a failed
fetch leaves the previous library in place rather than a half-written directory.

# What it obliges

The catalog repository must **cut releases**: a tag, a workflow bundling every
`.rmdx` into one `.rmda`, and the asset attached. A repository that merges pull
requests and never tags produces an application whose update check truthfully
reports nothing new, forever. That cost belongs to whoever holds the second
repository, not to the application.

# What it does not rule

Not the release cadence, the bundle size budget, or retention of superseded
versions. Not whether a user may pin to an older tag, which costs nothing to add
later and should not be guessed at now. And **no telemetry channel of any kind**:
§10.12(e)'s opt-in local-first position is untouched, and an unauthenticated
release check sends nothing but the fact that somebody launched the app.

# Citations

[1] canonical-decisions.md §11.33 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §12.15, including its correction of §12.14
[3] docs/06-device-builder.md §7.5; docs/09-roadmap.md §2.2
