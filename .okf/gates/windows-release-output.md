---
type: CI Gate
title: The Windows release output
description: What flutter build windows --release actually produced is what was meant to ship, meaning a real executable, exactly the expected native libraries, and the packaged starters. The inputs gate reads the dependency graph; this one reads the folder.
tags: [gate, ci, build, windows, release, packaging, dr-153, cr-117]
timestamp: 2026-10-17T00:00:00Z
resource: tools/ci/verify_windows_build.ps1
status: enforced
---

`pwsh -File tools/ci/verify_windows_build.ps1` is the `windows release output` step
of `tools/ci/run_local.ps1`. It reads
`apps/rackpal/build/windows/x64/runner/Release/`, so it runs only after
[the release build](windows-release-build.md) and is skipped with it.

# The failure it was written after

`apps/rackpal/test/flutter_dependency_test.dart` reads `pubspec.lock` and the
generated plugin list: the **inputs**. Nothing looked at the directory that gets
zipped and copied onto a client's USB stick. `dartjni.dll`, an Android JNI bridge,
sat in that directory beside `rackpal.exe` in a Windows-only build, pulled in by
two Android implementation packages that came along with their umbrella packages.
It could never load, it was weight and one more unsigned binary for an enterprise
allowlist to refuse, and it was found by somebody listing a folder.

# What it defends

- **`rackpal.exe` exists and is not a stub.** The size bound is deliberately far
  below the real size so it never becomes a maintenance chore, and far above zero.
- **The native set is exactly the expected set.** The script holds a table of
  expected DLLs, each with the reason it must ship. The list is *expected*, not
  *allowed*: an unexpected DLL fails, and a **missing** one fails too, because a
  list that only forbids cannot notice the plugin that quietly stopped shipping.
  The shipped set is printed on every run, so the failure nobody predicted is
  visible. `dartjni.dll` is named, so the message says what happened last time.
- **The vendored PDF library arrives.** `pdfium.dll` is the one entry a person put
  there by hand (DR-153): vendored rather than fetched, installed by one CMake
  rule. Its absence breaks no developer build, because the library also resolves
  from the working tree, and only makes a CAD plot unimportable on a packaged copy.
- **The four starter projects reached the bundle**, are not empty, and contain no
  carriage-return bytes. That last check repeats the byte-exactness property
  ([CR-117](/invariants/cr-117-byte-exactness.md)) on the *shipped* copy, so a
  clean clone that checked them out CRLF-normalised shows up here.

# What it deliberately does not

- **It checks that starters were packaged, not that they open.** The roadmap's rule
  is that the app opens the four starters. Opening needs the app driven end to end,
  which this repository cannot do.
- **It cannot tell a legitimate new DLL from a stray one.** It reports and fails;
  a person decides, and adds the DLL to the table *with its reason* if it belongs.
- **It does not verify signatures or publisher.** See
  [the release signature gate](release-signature.md).
- **It does not check the contents of the executable or the DLLs,** only their
  names, presence and (for the executable) a size floor.
- **Its starter list is a second copy of something git knows.** It names the files
  and takes the extension from one constant, which has gone stale at two renames of
  the project format. It stays hand-written because this gate reads the bundle and
  must not take the source tree's word for what shipped. A rename therefore touches
  this script, and because `run_local.ps1 -SkipBuild` is the documented iteration
  path, a rename passes locally and fails on the agent.

# Citations

[1] `tools/ci/verify_windows_build.ps1`, its header
[2] `apps/rackpal/test/flutter_dependency_test.dart`, the inputs gate
[3] `apps/rackpal/test/pdfium_install_test.dart`, the source-side gate for the CMake rule
[4] DR-153 section 11.152.3 in `docs/canonical-decisions.md`
