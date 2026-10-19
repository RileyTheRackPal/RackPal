---
type: Practice
title: A vendored binary needs a control that a package dependency brings with it
description: >-
  A pub dependency carries a lockfile hash and a resolver that refuses a
  mismatch. A binary committed into the tree carries nothing: it is megabytes of
  opaque bytes that no reviewer reads and no diff shows. Vendoring is not
  "the same dependency, checked in" — it is the same dependency with its
  integrity check removed, so the check has to be rebuilt by hand.
tags: [practice, dependencies, supply-chain, vendoring, testing, plan-k]
timestamp: 2026-09-10T00:00:00Z
---

CR-100 rules that pdfium is *"vendored into the repo rather than downloaded at
build time (a network-fetched binary in a signed release is a supply-chain and
reproducibility problem, not just a CI problem)"*, and DR-153 built it: 7.1 MB of
`pdfium.dll`, committed, by some distance the largest file in the repository.

**Vendoring solves the fetch and quietly removes three other things.** A pub
dependency arrives with a version resolver, a lockfile hash, and a publisher who
can be checked. A committed binary has a path and nothing else.

# What has to be rebuilt

- **A pin.** The release tag, so somebody who does not trust our copy can obtain
  their own, and the SHA-256 of both the archive it came from and the file that
  landed.
- **A test that recomputes it.** Nobody reviews the bytes, so the only thing that
  would notice a swap is arithmetic that runs on every build.
- **A licence in the tree.** A licence that is a URL somebody has to go and find
  is not something a repository can be audited from.

The test is worth being precise about what it proves: **it cannot tell a good
binary from a malicious one.** What it tells you is that nobody swapped it after
the day it was pinned, which is the question a supply chain actually asks.

# The bootstrap has no checksum, and saying so is the point

On a first vendoring run there is nothing to verify against. A tool that
downloads a file and then reports the hash it computed has proven that the bytes
survived transit and nothing else, so it must not present that as verification:

> WROTE THE PIN. Before committing, check these against the release page.
> A checksum computed by the downloader proves the file did not change in
> transit and nothing else.

**The human step is the control, not an inconvenience around it.** An automated
vendoring script that fetches, hashes and commits in one motion has reinvented
the build-time download that CR-100 refused, with an extra file in git.

# Read the licence you vendored, because it may point somewhere else

**The third control was half done for five weeks.** The archive's `LICENSE` was
vendored, and it is the PACKAGER's (MIT, bblanchon/pdfium-binaries), whose last
line says the rest is in `licenses/`: pdfium's own BSD licence and the notices
for every library compiled into it. `licenses/` was not vendored. A test checked
that `LICENSE` existed, which it did, so the check passed over a pointer to
notices that were not in the tree.

It surfaced at #468 (2026-10-18), when the macOS artifact's `LICENSE` differed
from the Windows one in line endings only, and the script stopped rather than
overwrite one licence with another. Each platform now carries `LICENSE` and
`licenses/` beside its binary, and the test asserts a non-empty `licenses/`.

**And copy nothing until every check has passed.** The same stop showed the
script had already placed the binary, leaving a dylib in the tree with no pin
entry: exactly the state the pin exists to rule out, produced by the tool that
writes the pin.

# The tell

A plan that says "vendor it" and stops. Ask what the package manager was doing
that now has no owner, and write down each answer as something in the tree.
