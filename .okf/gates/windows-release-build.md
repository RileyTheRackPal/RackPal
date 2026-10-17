---
type: CI Gate
title: The Windows release build
description: flutter build windows --release succeeds on the pinned SDK. It is the one step that compiles the application the way it ships, and it produces the directory the release-output gate then inspects.
tags: [gate, ci, build, windows, release, dr-248, dr-009]
timestamp: 2026-10-17T00:00:00Z
resource: azure-pipelines.yml
status: enforced
---

`flutter build windows --release`, run from `apps/rackpal`, is the
`flutter build windows --release` step of `tools/ci/run_local.ps1` and the
`Build Windows release` step of `azure-pipelines.yml`. Both skip it together:
`run_local.ps1 -SkipBuild` drops this step and
[the release-output gate](windows-release-output.md) with it, because that gate
has nothing to read without a build.

# What it defends

That the application still **builds as a release**, on the SDK the repository
pins. The test suites run in debug and in a Dart VM; this is the only step that
runs the ahead-of-time compile, the CMake configure and the native link a
customer's copy goes through. A change can leave every suite green and still fail
here: a plugin that does not build for Windows, a CMake rule that points at a file
that is gone, a toolchain the agent no longer has.

It runs on the pin, not on whatever is installed. The pin lives in
`azure-pipelines.yml` and is moved only as a reviewed act (DR-248 moved it, under
the rule that nothing is adopted before it is fourteen days old); the
`flutter pin` step refuses a different SDK before this one is reached, and the
dependencies come from the committed lockfile.

In the pipeline it runs **even when a suite failed**, because whether the
application builds is independent information and the artifact is what a reviewer
wants in hand while reading the failure. It sets a variable on success so the
steps that read its output do not file a second, misleading failure on top of the
real one.

# What it deliberately does not

- **It does not run the application.** A release that builds and crashes on launch
  is green here. Nothing in the repository drives the packaged app end to end; the
  repository has no `integration_test` target.
- **It does not look at what it built.** That is
  [the release-output gate](windows-release-output.md), which exists because a
  successful build proved nothing about the contents of the folder: an Android
  bridge DLL once shipped inside a green build.
- **It builds Windows only.** macOS is ruled into v1 (DR-009), and no step builds
  it; the debt that leaves is itemised in `docs/13-macos-debt-register.md`.
- **It does not sign or package.** The pipeline archives the Release directory and
  nothing more: no installer, no signature. See
  [the release signature gate](release-signature.md) for what is checked on a
  signed artifact, which this pipeline does not produce.
- **It says nothing about a clean checkout locally.** `run_local.ps1` builds the
  working tree; only the pipeline builds a clean clone.

# Citations

[1] `azure-pipelines.yml`, the section headed THE WINDOWS RELEASE BUILD
[2] `tools/ci/run_local.ps1`, the `-SkipBuild` parameter
[3] DR-248 (the pin and the cooldown) and DR-009 (macOS in v1), in `docs/canonical-decisions.md`
