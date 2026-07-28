# CI gates

`pwsh -File tools/ci/run_local.ps1 -SkipBuild` runs the full set. Each concept
below records what its gate defends **and what it deliberately does not** — a
gate's blind spot is as worth knowing as its coverage.

* [Analyzer info ratchet](analyzer-baseline.md) - 0 errors, 0 warnings, and an exactly pinned info count. Scans tests too.
* [Registry parity](registry-parity.md) - the Dart seed agrees with the palette authority on hue, dash and weight. Blind to descriptive fields, on purpose.
* [Byte-exactness sweep](byte-exactness-sweep.md) - .gitattributes pins every extension in a byte-exact root; also the traversal bug worth not repeating.

# Not yet written up

`flutter pin`, `tracked sources (would a clone compile?)`, `PAL-1 conformance`,
`palette parity`, `JUnit converter self-test`, and the five package suites.
