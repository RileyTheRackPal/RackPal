---
type: Gate
title: Release signature gate — signed, timestamped, and outliving the certificate
description: DR-006 §11.6.2's four build-side clauses. The fourth is the point of the gate, and canon's recipe for it turned out to have an unstated precondition.
tags: [gate, release, signing, timestamp, dr-006]
timestamp: 2026-08-02T00:00:00Z
status: adopted
---

`tools/release/verify_signatures.ps1`. Run against a staged artifact; not yet
part of `run_local.ps1`, because it needs a signed artifact and a certificate
that only a release machine has.

# What it defends

DR-006 §11.6.2's build-side clauses, on the real artifact:

1. **signed** — a signer certificate is present;
2. **timestamped** against an RFC 3161 authority;
3. **valid publisher** — either OURS, or a third party whose signature
   validates on its own merits;
4. **the signature still validates after the certificate expires.**

# Clause 3 is the second version of clause 3

The first demanded the expected subject on EVERY binary, and failed the
artifact on Microsoft's three redistributable VC++ DLLs — which
`sign_artifacts.ps1` deliberately does not re-sign, because replacing a chain
that validates on every Windows machine with a self-signed one makes the
artifact worse. **The two scripts disagreed and the gate was the one that was
wrong.**

What the rule now rejects is the case worth rejecting: a binary that is neither
ours nor verifiably anybody's — how an unexpected DLL of unknown provenance
would look sitting in the shipped folder.

# Clause 4, and the precondition canon does not state

Canon calls this the point of the whole gate: *"it is what proves the timestamp
counter-signature is real rather than a flag somebody passed and nobody
checked… the day the certificate lapses, every previously shipped binary starts
reporting `NotTimeValid` and there is no way to fix already-deployed files."*

It also gives the experiment: mint a short-lived certificate, sign two copies —
one timestamped, one not — wait out the window, and assert
`Get-AuthenticodeSignature` reports `Valid` for the timestamped copy and a
time-validity failure for the other.

**Run as written, on a normal build machine, it is INCONCLUSIVE.** Measured: a
self-signed certificate's root is not trusted there, so BOTH copies report
`UnknownError / terminated in a root certificate which is not trusted`. The
chain engine stops at the root before it ever reaches the time check, and the
difference the clause exists to prove never appears. Canon's step silently
assumes the probe root has been installed into a trusted store — a change to
the machine's security configuration, made for a test.

So the verdict comes from `X509Chain` with an explicit `VerificationTime`,
which is the mechanism Windows itself applies to a countersigned signature;
`AllowUnknownCertificateAuthority` sets the root complaint aside so the time
status underneath becomes visible, and nothing is installed anywhere:

```
chain verified AT NOW          -> NotTimeValid=True  [UntrustedRoot, NotTimeValid]
chain verified AT SIGNING TIME -> NotTimeValid=False [UntrustedRoot]
```

# Its blind spot, stated rather than blurred

**Observed:** the expiry, the time check firing, and the presence and absence
of the counter-signature. **Modelled:** that Windows then verifies at the
counter-signed instant. Observing that end to end needs the probe root trusted
on the machine, which the script will not do to itself.

The script has **three separate INCONCLUSIVE branches that fail the run rather
than scoring green** — including one that fires if an expired certificate
somehow does not produce `NotTimeValid` at all. A check that cannot fail is the
`VACUOUS` mark docs/12 exists to refuse, and this gate refuses it about itself.

**Trust is not asserted by default** (`-RequireTrusted` is opt-in) because it
is a property of the machine the gate ran on, not of the artifact. A
self-signed publisher is untrusted everywhere until the GPO lands, which is the
correct state for a build agent — and an "Unknown publisher" on a machine that
IS supposed to have the `.cer` is the early warning DR-006 consequence 7 names
as `RISK-07`'s replacement.
