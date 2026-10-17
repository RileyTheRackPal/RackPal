---
type: Design Ruling
title: DR-006 — RackMate is an internal tool, distributed self-signed
description: No commercial release, so no CA, no hardware token and no reputation ramp. The signing script is parameterised over certificate source, and M8's SmartScreen clause splits because no build-side property can deliver it.
tags: [ruling, distribution, signing, m8, portable, dr-006]
timestamp: 2026-08-02T00:00:00Z
ruling_id: DR-006
canon_section: "11.6"
status: superseded-in-part
superseded_by: [DR-036]
amended_by: [DR-249]
---

RackMate is distributed inside the organisation that builds it. Signing is
self-signed, `New-SelfSignedCertificate`, applied with
`Set-AuthenticodeSignature` **and a timestamp server**, with the public
`.cer` deployed to `LocalMachine\Root` **and** `LocalMachine\TrustedPublisher`
by Group Policy. Microsoft Trusted Signing is the named fallback if external
distribution is ever required.

# What it removes, and what it does not

It removes a **purchasing lead time**, not the release engineering. AC-058/D10
scheduled OV/EV certificate procurement two milestones before release, for
three mechanisms that all vanish: identity verification, the SmartScreen
reputation ramp, and, since the CA/Browser Forum's 2023 Baseline Requirements
, a hardware token for the private key. macOS notarisation, vendored pdfium
(CR-100) and symbol archival are all still M8's.

# M8's SmartScreen clause splits, because no build can deliver it

SmartScreen fires on **Mark-of-the-Web**, which is a function of how a file
ARRIVED, not of what is in it. A clause mixing a build property and a delivery
property cannot be a gate. So:

**Build side**: a real gate: signed, timestamped against an RFC 3161
authority, valid publisher, **and the signature still validates after the
certificate expires**. See [the signature gate](/gates/release-signature.md).

**Distribution side**: documented, not gated: deploy over a Local Intranet UNC
share or Intune/GPO so MOTW is never applied.
[The ZIP trap](/practices/the-zip-trap.md) is the part that must be repeated
every time.

# What is built, and what is not

**Built (board #13, 2026-08-02):** `tools/release/`, staging, the
parameterised signing entry point, and the build-side gate. Documented in
`docs/14-deployment.md`.

**A SCOPE EDIT, AND RECORDED AS ONE.** Consequence 4 says outright that a
portable output before M8 is *"a scope edit under roadmap §8.3 and not
something this consequence grants"*. One was wanted early, for the team to
test with. The edit was made deliberately rather than smuggled in under a
ruling that declines to authorise it.

**Not built:** everything else in M8, installer or MSIX (consequence: the
`.rackmate` association path differs between them and drives the choice),
crash reporter, cold-start budget, documented limits.

# Consequence 3 is the one that cost something, and it was paid

*"The signing script is parameterised over certificate source and never
hardcodes self-signed… This is the only consequence that costs anything now,
and it is the one that must not be skipped: it is the difference between the
named fallback being a config change and being a rewrite."*

`sign_artifacts.ps1` resolves the source (store thumbprint, `.pfx`, or Trusted
Signing) in ONE function; timestamping, hashing, verification and the artifact
list are identical downstream. Adding a fourth source is a branch there and
nothing else. The Trusted Signing path **fails loudly** when signtool or the
dlib is absent rather than falling back to self-signed: a silent downgrade of
the trust model is the worst thing that script could do.

# Two things building it corrected in the ruling itself

**§11.6.2's expiry recipe has an unstated precondition.** As written it is
INCONCLUSIVE on a normal build machine: a self-signed root is untrusted there,
so the chain engine reports `UntrustedRoot` before reaching the time check and
BOTH copies come back identical. See
[the signature gate](/gates/release-signature.md) for what is done instead.

**"Every artifact a release produces" is not "every file it ships."**
Consequence 4's wording, applied literally, re-signed Microsoft's three
redistributable VC++ DLLs, replacing a chain that validates on every Windows
machine with one that validates only where the GPO landed. We do not *produce*
`MSVCP140.dll`. Binaries already signed by another publisher are skipped.
