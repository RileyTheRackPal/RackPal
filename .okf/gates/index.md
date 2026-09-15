# CI gates

`pwsh -File tools/ci/run_local.ps1 -SkipBuild` runs the full set. Each concept
below records what its gate defends **and what it deliberately does not**: a
gate's blind spot is as worth knowing as its coverage.

* [Analyzer info ratchet](analyzer-baseline.md) - 0 errors, 0 warnings, and an exactly pinned info count. Scans tests too.
* [Registry parity](registry-parity.md) - the Dart seed agrees with the palette authority on hue, dash and weight, and with seed-devices §4.4 on each family's name, connector, tag, direction and topology (DR-175).
* [Milestone completeness](milestone-completeness.md) - roadmap section 8.9 as a check (DR-095): no milestone before the current one may hold an exit clause that is neither discharged nor parked on a later milestone by a ruling. It runs twelve planted cases before it reads the board, and its first real run failed on M1's goal line, which the prose called no exit clause and the table counted as one.
* [Byte-exactness sweep](byte-exactness-sweep.md) - .gitattributes pins every extension in a byte-exact root; also the traversal bug worth not repeating.
* [Catalog port order](catalog-port-order.md) - declared order must equal ranked order; FracIndex sorts as a string and 678 of 727 ports were scrambled.
* [Release signature](release-signature.md) - signed, timestamped, and still valid after the certificate expires; canon's recipe for the last one has an unstated precondition.
* [The pipeline itself](the-pipeline-itself.md) - it runs, it passed first try, and every suite sits exactly at its floor; what it cannot tell you is whether it could report a failure, because nothing has ever gone red on the service.

* [Callbacks have callers](callbacks-have-callers.md) - every function-typed `*Actions` member in `rackmate_ui` must be invoked somewhere; 18 callbacks, one hole on its first run, and two false positives it must not report.
* [Dependency table parity](dependency-table-parity.md) - docs/03 §10.1 and the five pubspecs must agree in BOTH directions; a documented package nobody installed hid for five milestones, and an installed one nobody documented cited the table it was missing from.
* [Commands have callers](commands-have-callers.md) - a source-level reachability graph over every `*/lib/**.dart`: a Command must be built by some declaration reachable from a UI package. The shape shipped FIVE times and three greps got the answer wrong before the graph got it right. Twelve are exempt today, each against the board item that retires it, and an exemption that becomes reachable fails too. Its blind spot is that every UI declaration is a root, so a command behind a callback no mount supplies reads as reachable.
* [Callbacks have suppliers](callbacks-have-suppliers.md) - the THIRD reachability question, and none of the three subsumes another: `#674`'s asks whether a declared callback is INVOKED, `#872`'s whether a Command is CONSTRUCTED on a path from a UI package, and this one whether any mount ever HANDS ONE OVER. `ValidationDrawer` had three callbacks and exactly one mount that passed none, so two commands, three dialogs and PWR-003's whole remedy chain were unreachable while every suite stayed green. A supplier is a construction OF THAT WIDGET, because `onRemedy:` IS supplied elsewhere and a name grep would have missed the defect it is for. Its exemption list is EMPTY.

# Not yet written up

`flutter pin`, `tracked sources (would a clone compile?)`, `PAL-1 conformance`,
`palette parity`, `JUnit converter self-test`, `glyph coverage`, and the five
package suites individually. The pipeline concept above covers what they prove
COLLECTIVELY on the service; it does not replace a per-gate write-up.
