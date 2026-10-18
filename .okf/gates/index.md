# CI gates

`pwsh -File tools/ci/run_local.ps1 -SkipBuild` runs the full set. Each concept
below records what its gate defends **and what it deliberately does not**: a
gate's blind spot is as worth knowing as its coverage.

* [Analyzer info ratchet](analyzer-baseline.md) - 0 errors, 0 warnings, and an exactly pinned info count. Scans tests too.
* [Registry parity](registry-parity.md) - the Dart seed agrees with the palette authority on hue, dash and weight, and with seed-devices §4.4 on each family's name, connector, tag, direction and topology (DR-175).
* [PAL-1 conformance](pal1-conformance.md) - the palette survives greyscale. The data is Python's and the rules are rackpal_core's since SFE-A2, so the gate and the clone editor read one implementation; two planted palettes known to fail are sent on every run, so green means the core could have said no.
* [Milestone completeness](milestone-completeness.md) - roadmap section 8.9 as a check (DR-095): no milestone before the current one may hold an exit clause that is neither discharged nor parked on a later milestone by a ruling. It runs twelve planted cases before it reads the board, and its first real run failed on M1's goal line, which the prose called no exit clause and the table counted as one.
* [Byte-exactness sweep](byte-exactness-sweep.md) - .gitattributes pins every extension in a byte-exact root; also the traversal bug worth not repeating.
* [Catalog port order](catalog-port-order.md) - declared order must equal ranked order; FracIndex sorts as a string and 678 of 727 ports were scrambled.
* [Release signature](release-signature.md) - signed, timestamped, and still valid after the certificate expires; canon's recipe for the last one has an unstated precondition.
* [The pipeline itself](the-pipeline-itself.md) - it runs, it passed first try, and every suite sits exactly at its floor; whether it could report a failing test was open until build 481 on the macOS pipeline showed it can.
* [The macOS pipeline](the-macos-pipeline.md) - definition 2, an optional PR check on a hosted image (DR-255): every Windows gate but the timed budgets and the build, floors lower only by named cases, and never blocking, because one free job of 1,800 minutes must not decide what merges.

* [Callbacks have callers](callbacks-have-callers.md) - every function-typed `*Actions` member in `rackpal_ui` must be invoked somewhere; 18 callbacks, one hole on its first run, and two false positives it must not report.
* [Dependency table parity](dependency-table-parity.md) - docs/03 §10.1 and the five pubspecs must agree in BOTH directions; a documented package nobody installed hid for five milestones, and an installed one nobody documented cited the table it was missing from.
* [Commands have callers](commands-have-callers.md) - a source-level reachability graph over every `*/lib/**.dart`: a Command must be built by some declaration reachable from a UI package. The shape shipped FIVE times and three greps got the answer wrong before the graph got it right. Twelve are exempt today, each against the board item that retires it, and an exemption that becomes reachable fails too. Its blind spot is that every UI declaration is a root, so a command behind a callback no mount supplies reads as reachable.
* [Callbacks have suppliers](callbacks-have-suppliers.md) - the THIRD reachability question, and none of the three subsumes another: `#674`'s asks whether a declared callback is INVOKED, `#872`'s whether a Command is CONSTRUCTED on a path from a UI package, and this one whether any mount ever HANDS ONE OVER. `ValidationDrawer` had three callbacks and exactly one mount that passed none, so two commands, three dialogs and PWR-003's whole remedy chain were unreachable while every suite stayed green. A supplier is a construction OF THAT WIDGET, because `onRemedy:` IS supplied elsewhere and a name grep would have missed the defect it is for. Its exemption list is EMPTY.
* [Rule review pack](rule-review-pack.md) - every catalogue rule has a group in the domain-review pack, in the right band; it was dead for three rulings before it was a gate. It does not compare the pack on disk, so wording can still be stale.
* [AC-051 pair coverage](ac-051-pair-coverage.md) - every rule in both bands has a known-bad that fires exactly that rule and a near-miss that does not; the subject is the catalogue, because three enum-driven coverage tests could all pass over a rule with no pair.
* [Glyph coverage](glyph-coverage.md) - every non-ASCII character a Dart literal can draw exists in both bundled Jost weights, read from the font binary because both backends emit identical ops for a missing glyph. It was in `run_local.ps1` for two months and in neither pipeline: it is the one gate that imports a third-party Python package, so the pipelines install a hash-pinned fontTools first.
* [The formatter gate](formatter.md) - `dart format` finds nothing to change (DR-017); it has one correct answer, which is why it is absolute where the analyzer is a ratchet. Dart only, and only as right as the configuration it can resolve.
* [The Windows release build](windows-release-build.md) - the one step that compiles the application the way it ships, on the pinned SDK; it does not run the result, and it builds Windows only.
* [The Windows release output](windows-release-output.md) - the folder the build produced holds a real executable, exactly the expected native libraries and the packaged starters; written after an Android bridge DLL shipped inside a green build.

# Steps that have no concept of their own

Each `Invoke-Gate` call in `tools/ci/run_local.ps1` either has a concept above or
is named here with its reason.

* `flutter pub get (workspace root)` is setup, not a check: it resolves the
  workspace so the steps after it can run, and fails only if the packages cannot
  be resolved. The pipeline's variant, `--enforce-lockfile`, is described in
  `azure-pipelines.yml`.
* `suite: <name>`, one per package suite and the timed suite, is the test run. Its
  floors live in `tools/ci/run_suite.ps1` and nowhere else; the pipeline concept
  above covers what they prove on the service.

# Not yet written up

`flutter pin`, `tracked sources (would a clone compile?)`,
`palette parity` and `JUnit converter self-test`. The pipeline
concept above covers what they prove COLLECTIVELY on the service; it does not
replace a per-gate write-up.
