# Vendored pdfium

One release, `chromium/8044`, one artifact per platform, committed rather than
downloaded, per **CR-100**:

> the pdfium binaries are **vendored into the repo** rather than downloaded at
> build time (a network-fetched binary in a signed release is a supply-chain
> and reproducibility problem, not just a CI problem)

| Folder | Binary | For |
|---|---|---|
| `win-x64/` | `pdfium.dll` | Windows x64 |
| `mac-univ/` | `libpdfium.dylib` | macOS, **universal**: an x86_64 and an arm64 slice in one file, so `dlopen` picks the slice for the CPU (#468) |

**DR-153 §11.152.3** is the ruling that made it concrete, after DR-138, DR-145
and DR-148 each deferred it. `pdfium.pin.json` records the release tag and, per
platform, the archive's SHA-256 and the binary's own, so every file sitting here
can be checked without the archive it came from:

```bash
pwsh -File tools/vendor_pdfium.ps1 -Verify
```

## The licences travel with each binary

Each folder holds its binary's `LICENSE` and `licenses/`. The `LICENSE` is the
**packager's** (MIT, bblanchon/pdfium-binaries), and it points at `licenses/`:
pdfium's own BSD licence and the notices for every library compiled into it,
which BSD-style terms require a binary distribution to carry. **Until #468 only
the packager's file was vendored**, at the top of this folder, so the notices
were not in the tree at all. They now sit beside the binary they cover, per
platform, because two builds of one release can compile in different
third-party code. For `chromium/8044` the two sets are the same fourteen files,
and the two `LICENSE` files differ only in line endings.

## Why it is not a package

`pdfrx`, `pdfium_dart` and `printing` all obtain pdfium by downloading it at
build time, which is the thing CR-100 refuses, and `pdfrx` 2.x additionally
required a newer Flutter than the pin of the day (DR-138 §11.137.1). Either
refusal alone ends it. What is left is a direct FFI binding, which is
`packages/rackpal_pdfium`.

## Why a person places it

The vendoring step is the supply-chain boundary CR-100 describes, so it is a
human act by construction. Nothing in CI or in an ordinary build fetches
anything; `-Verify` is the only mode automation uses, and it needs no network.
`-Bootstrap` checks the archive against the digest GitHub publishes for the
release asset before it records anything, and copies nothing until every check
has passed.

## Which slice anything here actually runs

The hosted macOS image (DR-255) is **Intel**, so CI loads the x86_64 slice. The
arm64 slice is checked for presence by `pdfium_vendoring_test.dart`, which reads
the dylib's Mach-O header on every OS, and is **executed only on an Apple
Silicon Mac**. No CI here runs it.
