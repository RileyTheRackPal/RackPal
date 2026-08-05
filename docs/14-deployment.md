# 14 · Deployment: the portable build, and how to hand it over

> **Status: the portable build exists; M8 has not started.** This document covers exactly what
> board item #13 delivers — a signed portable folder for internal use. It is **not** M8. There is no
> installer, no MSIX, no crash reporter, no cold-start budget and no `.rmpj` file association;
> those are M8's exit criterion and are untouched. See `docs/12-milestone-board.md` §5.7.

> **This is a scope edit, and it is recorded as one.** DR-006 consequence 4 says plainly that a
> portable output before M8 is not something the ruling grants: *"All release-engineering
> deliverables remain at M8. If a portable output is ever wanted earlier, that is a scope edit under
> roadmap §8.3 and not something this consequence grants."* One was wanted earlier — the team needs
> something to test with. The edit was made deliberately rather than smuggled in under a ruling that
> declines to authorise it.

---

## 14.0 Versioning: `0.EPIC.TASK`

**Set by the user on 2026-08-03, at the `v0.2.0` tag.** Three numbers, and none of them is semver:

| Position | Means | Moves when |
|---|---|---|
| **major** | `0` until the first **public** release | the product ships publicly. Not before, whatever the feature set |
| **minor** | the **milestone epic** under development | work moves to the next epic: M2 ⇒ `2`, M3 ⇒ `3` |
| **patch** | major tasks completed **within that epic** | a major task closes |

**It is deliberately not semver, and the difference matters when reading it.** Semver's minor
promises backward compatibility and its patch promises a bug fix; neither is claimed here. The
middle number says *where in the plan this build came from*, which is the question actually being
asked of an internal alpha handed to a tester, "is this the one with the schematic work in it",
and it maps straight onto the board's epics (`docs/12-milestone-board.md` §5), so a version answers
it without a changelog lookup.

**`v0.2.0` is M2's baseline**, tagged with the milestone's criterion met rather than at its last
commit; M2's completed work (#93, #13, #94, #95 and the #96 field-test items) is inside it. M3's
first task lands as `v0.3.1`.

**The number is written in six places and gated in one.** `apps/rackmate/pubspec.yaml`, the four
library `pubspec.yaml`s, and `kAppVersion` in `app_services.dart`, which is the one that matters,
because it is stamped into `RackDocument.appVersion` on every new document and into every recovery
sidecar. A release that bumps the pubspec and forgets the constant writes the PREVIOUS version
permanently into files the user keeps, and nothing about running the app looks wrong.
`apps/rackmate/test/version_parity_test.dart` compares all six and asserts the leading `0`.

---

## 14.1 The three commands

```powershell
pwsh -File tools/release/new_signing_cert.ps1 -Subject 'CN=<your publisher name>'
pwsh -File tools/release/make_portable.ps1
pwsh -File tools/release/sign_artifacts.ps1 -Path dist/RackMate-portable -Thumbprint <printed above>
pwsh -File tools/release/verify_signatures.ps1 -Path dist/RackMate-portable -ExpectedSubject 'CN=<your publisher name>'
```

The certificate is minted **once** and reused; the other three run per release.

---

## 14.2 THE ZIP TRAP: read this before handing anything to anyone

> **Modern Windows Explorer propagates Mark-of-the-Web into extracted files.**

A portable folder zipped and fetched **over HTTP** (a browser download, a Teams or Slack link, a
web-based file share) **re-arms SmartScreen for every binary inside it**, no matter how well the
binaries are signed. It does so *silently*: the archive looks fine when it downloads, and the
failure is invisible until somebody on a fresh machine gets the blue full-screen prompt.

**The same bytes handed over `\\share\` are not the same artifact.** MOTW is a function of *how the
file arrived*, not of what is in it, so no property of the build can fix this. That is precisely why
DR-006 §11.6.2 splits M8's SmartScreen clause: the build side is a real gate, and the delivery side
is this page.

**So:**

| Do | Do not |
|---|---|
| Copy to a **Local Intranet UNC share** (`\\server\share\RackMate`) and have people copy from there | Post a ZIP to any HTTP/HTTPS link |
| Push with **Intune** or **GPO** | Email the ZIP |
| Hand over a USB stick physically | Put it in a web-based file share and send the URL |

If a ZIP over HTTP is ever genuinely unavoidable, the receiving user must unblock the archive
**before** extracting (`Properties ▸ General ▸ Unblock`, or `Unblock-File`), because unblocking after
extraction leaves every already-extracted binary marked.

---

## 14.3 The certificate has to reach the machines: into **both** stores

The public `.cer` (`dist/rackmate-publisher.cer`, produced by `new_signing_cert.ps1`) goes to every
target machine, ideally by Group Policy:

| Store | What it does | Symptom when it is missing |
|---|---|---|
| `LocalMachine\Root` | Makes the **chain validate** | `Get-AuthenticodeSignature` reports `UnknownError` / *"terminated in a root certificate which is not trusted"* |
| `LocalMachine\TrustedPublisher` | Makes the publisher **trusted** rather than merely known | Signature validates, and Windows still says **Unknown publisher** |

**Deploying one and not the other is the common half-failure.** It produces a valid signature that
still warns, which reads as "the signing did not work" and sends people looking in the wrong place.

**Never distribute the `.pfx` or any private key.** `.gitignore` refuses `*.pfx`, `*.p12`, `*.snk`
and `*.key`. DR-006 self-signs, which makes the key cheap to re-mint and therefore tempting to check
in "just for the build agent", and a self-signed publisher that every org machine has been told to
**trust** is exactly the certificate you least want loose.

**To verify a target machine is correctly set up**, run on that machine:

```powershell
pwsh -File tools/release/verify_signatures.ps1 -Path <folder> -ExpectedSubject 'CN=<publisher>' -RequireTrusted
```

An "Unknown publisher" there is the early warning canon names as the replacement for `RISK-07`
(DR-006 consequence 7): *"whose mitigation is a GPO and a five-minute check, not a purchase order."*

---

## 14.4 What the folder contains, and what it writes

```
RackMate\
  rackmate.exe
  flutter_windows.dll
  screen_retriever_windows_plugin.dll, window_manager_plugin.dll
  MSVCP140.dll, VCRUNTIME140.dll, VCRUNTIME140_1.dll   <- see below
  data\                <- SHIPPED. Replaced by every update.
  portable.txt         <- presence is the mode switch; contents are never read
  RackMateData\        <- OURS. Created on first run. Never in the release.
```

**Updating is "unzip the new version over the old folder".** That is safe by construction:
`RackMateData` is a sibling of `data\` rather than inside it, deliberately, because a portable root
under `data\` would be destroyed by exactly that update, including recovery snapshots holding work
from a crash minutes earlier. `apps/rackmate/test/storage/data_root_test.dart` reads
`windows/runner/main.cpp` and asserts the two names differ, so the collision cannot come back by
editing either end alone.

**The three VC++ runtime DLLs are Microsoft's redistributable**, carried app-local because they are
not part of a clean Windows install. They keep **Microsoft's own signature**:
`sign_artifacts.ps1` skips binaries already signed by another publisher, because replacing a chain
that validates on every Windows machine with a self-signed one makes the artifact worse. The set is
derived from the shipped binaries' PE import tables on every run rather than hardcoded, so a
dependency added in a later milestone is reported instead of discovered by a missing-DLL dialog.

The `api-ms-win-crt-*` Universal CRT is **deliberately absent**: it is in-box on Windows 10 and 11
and serviced by Windows Update.

### What running it leaves on the host machine

**RackMate's own code writes no registry key**: no `Reg*` call, no registry package, nothing under
`HKCU` or `HKLM` from any line we ship, and `apps/rackmate/test/session/registry_claim_test.dart`
derives that from the source rather than trusting this sentence.

**Beyond that, the honest statement is a BOUND and not a list.** RackMate drives the file dialog
itself and sets `FOS_DONTADDTORECENT`, which, as measured against the shipped binary, keeps
everything out of OpenSavePidlMRU and out of `%APPDATA%\Microsoft\Windows\Recent`, so **no project
file name reaches the host**. The rest is not ours: the shell writes values under ComDlg32 that
RackMate does not control (at minimum LastVisitedPidlMRU and CIDSizeMRU, **measured examples
rather than an inventory**) and no supported option prevents them while the shell common dialog is
the dialog.

> **Do not turn that into a closed list.** Canon §11.6.4 records that stating it as one *"has been
> wrong four times running"*, every time by naming the keys that had been measured and closing the
> list, and every time a later measurement found another one. `registry_claim_test.dart` fails if
> the architecture document restates it as a closed list.

So: a portable run leaves shell-owned `HKCU` entries naming this executable and the folders it
browsed (`E:\Jobs`, never `E:\Jobs\Smith Residence.rmpj`) and they survive the stick being
pulled.

---

## 14.5 The build-side gate, and the one clause that matters

`verify_signatures.ps1` implements DR-006 §11.6.2's four clauses. Three are checked against the
artifact directly. The fourth is **the point of the whole gate**:

> *"the signature still validates after the signing certificate has expired … It is what proves the
> timestamp counter-signature is real rather than a flag somebody passed and nobody checked, and it
> is the part people discover too late — the day the certificate lapses, every previously shipped
> binary starts reporting `NotTimeValid` and there is no way to fix already-deployed files."*

```powershell
pwsh -File tools/release/verify_signatures.ps1 -TestExpiry -ExpiryWindowMinutes 3
```

**Canon's recipe carries an unstated precondition, found by running it.** As written (mint a
short-lived certificate, sign two copies, wait, and assert `Get-AuthenticodeSignature` reports
`Valid` for the timestamped one and a time-validity failure for the other), it is **inconclusive on
a normal build machine**. A self-signed certificate's root is not trusted there, so *both* copies
report `UnknownError / terminated in a root certificate which is not trusted`: the chain engine
stops at the root before it ever reaches the time check, and the difference the clause is about is
masked.

The script therefore takes the verdict from `X509Chain` with an explicit `VerificationTime`, the
mechanism Windows itself applies to a countersigned signature, with
`AllowUnknownCertificateAuthority` setting the root complaint aside so the time status underneath
becomes visible. Nothing is installed into any store. Measured:

```
chain verified AT NOW          -> NotTimeValid=True  [UntrustedRoot, NotTimeValid]
chain verified AT SIGNING TIME -> NotTimeValid=False [UntrustedRoot]
```

**What is observed and what is modelled, stated rather than blurred.** The expiry, the time check,
and the presence/absence of the counter-signature are *observed*. That Windows then verifies at the
counter-signed instant is *modelled*. To observe the whole thing end to end and read canon
literally, on a machine you are willing to change: import the probe certificate into
`Cert:\CurrentUser\Root` and re-run.

---

## 14.6 What this does not deliver

Named so that M8 still has its work, and so nobody reads this page as more than it is:

- **no installer and no MSIX**: canon §11.6.5 leaves that choice open, and flags that the
  `.rmpj` file-association path differs between the two and drives it;
- **no `.rmpj` file association**: a consequence of the above;
- **no crash reporter**: M8's third exit clause; `storage_log.dart` and CR-096's redaction check
  are a policy with no reporter behind it;
- **no cold-start budget**: none is defined and none has been measured;
- **no documented limits**: M8's fourth clause is `VACUOUS` until they exist;
- **no auto-update**: RJ-014, reaffirmed by DR-006 consequence 10: a "Check for updates" item and
  a version string, and internally that item can point at the same share the folder came from,
  which is a link and not infrastructure.
