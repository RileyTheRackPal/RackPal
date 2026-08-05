---
type: Playbook
title: The ZIP trap — how a file arrives decides whether it is trusted
description: Explorer propagates Mark-of-the-Web into extracted files, so a portable ZIP fetched over HTTP re-arms SmartScreen on every binary inside it, however well signed. The same bytes over a UNC share are a different artifact.
tags: [practice, distribution, signing, smartscreen, motw]
timestamp: 2026-08-02T00:00:00Z
status: adopted
---

**A signed binary is not a trusted binary. How it arrived decides.**

SmartScreen Application Reputation is evaluated on files carrying
**Mark-of-the-Web**: the `Zone.Identifier` alternate data stream a browser or
other zone-aware downloader attaches. MOTW is a property of the DELIVERY, not
of the file.

# The trap

Modern Windows Explorer **propagates MOTW into extracted files**. So a portable
folder zipped and fetched over HTTP (a browser download, a chat link, a
web-based file share) **re-arms SmartScreen for every binary inside it**,
regardless of how well each one is signed.

It fails *silently*. The archive looks fine when it downloads. Nothing is
visible until somebody on a fresh machine gets the blue full-screen prompt, by
which point the natural conclusion is "the signing did not work" and the search
starts in the wrong place entirely.

**The same bytes handed over `\\share\` are not the same artifact.** That
sentence is the whole practice.

# Why it cannot be fixed in the build

This is what forced DR-006 to SPLIT M8's exit clause. *"A signed installer runs
on a clean Windows 11 machine with no SmartScreen warning"* mixes a build
property with a delivery property, and a clause like that cannot be a gate,
passing it depends on something the build does not do. The build side became a
real, checkable gate; the delivery side became a document that has to be read.

Any document offering a ZIP download must say so, every time. That is why it is
repeated in `docs/14-deployment.md` §14.2 rather than cross-referenced.

# The shape, beyond this instance

**A property that lives in the channel cannot be gated at the source.** It is
the same failure as asserting a milestone criterion against the wrong artifact:
docs/12 §5.1's clause 4 was marked DEMONSTRATED on a test measuring the display
list being BUILT rather than PAINTED, and was false for a week. Both are a
claim quietly changing which thing it is about.

When a requirement mixes two, split it and say which half is a gate, and put
the other half somewhere a human will actually read it before acting.
