# CI gates

`pwsh -File tools/ci/run_local.ps1 -SkipBuild` runs the full set. Each concept
below records what its gate defends **and what it deliberately does not**: a
gate's blind spot is as worth knowing as its coverage.

* [Analyzer info ratchet](analyzer-baseline.md) - 0 errors, 0 warnings, and an exactly pinned info count. Scans tests too.
* [Registry parity](registry-parity.md) - the Dart seed agrees with the palette authority on hue, dash and weight. Blind to descriptive fields, on purpose.
* [Byte-exactness sweep](byte-exactness-sweep.md) - .gitattributes pins every extension in a byte-exact root; also the traversal bug worth not repeating.
* [Catalog port order](catalog-port-order.md) - declared order must equal ranked order; FracIndex sorts as a string and 678 of 727 ports were scrambled.
* [Release signature](release-signature.md) - signed, timestamped, and still valid after the certificate expires; canon's recipe for the last one has an unstated precondition.
* [The pipeline itself](the-pipeline-itself.md) - it runs, it passed first try, and every suite sits exactly at its floor; what it cannot tell you is whether it could report a failure, because nothing has ever gone red on the service.

* [Callbacks have callers](callbacks-have-callers.md) - every function-typed `*Actions` member in `rackmate_ui` must be invoked somewhere; 18 callbacks, one hole on its first run, and two false positives it must not report.
* [Dependency table parity](dependency-table-parity.md) - docs/03 §10.1 and the five pubspecs must agree in BOTH directions; a documented package nobody installed hid for five milestones, and an installed one nobody documented cited the table it was missing from.

# Not yet written up

`flutter pin`, `tracked sources (would a clone compile?)`, `PAL-1 conformance`,
`palette parity`, `JUnit converter self-test`, `glyph coverage`, and the five
package suites individually. The pipeline concept above covers what they prove
COLLECTIVELY on the service; it does not replace a per-gate write-up.
