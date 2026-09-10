# Vendored pdfium

`win-x64/pdfium.dll`, committed rather than downloaded, per **CR-100**:

> the pdfium binaries are **vendored into the repo** rather than downloaded at
> build time (a network-fetched binary in a signed release is a supply-chain
> and reproducibility problem, not just a CI problem)

**DR-153 §11.152.3** is the ruling that made it concrete, after DR-138, DR-145
and DR-148 each deferred it. `pdfium.pin.json` records the release tag, the
archive's SHA-256 and the DLL's own SHA-256, so the file sitting here can be
checked without the archive it came from:

```bash
pwsh -File tools/vendor_pdfium.ps1 -Verify
```

## Why it is not a package

`pdfrx`, `pdfium_dart` and `printing` all obtain pdfium by downloading it at
build time, which is the thing CR-100 refuses, and `pdfrx` 2.x additionally
requires Flutter 3.47 against this repo's pinned 3.44.4 (DR-138 §11.137.1).
Either refusal alone ends it. What is left is a direct FFI binding, which is
`packages/rackpal_pdfium`.

## Why a person places it

The vendoring step is the supply-chain boundary CR-100 describes, so it is a
human act by construction. Nothing in CI or in an ordinary build fetches
anything; `-Verify` is the only mode automation uses, and it needs no network.

## Platforms

Windows x64 only, which is the platform this product ships on (DR-009).
macOS binaries are added when macOS work starts, because an unused binary is
an unverified one.
