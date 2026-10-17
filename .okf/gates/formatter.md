---
type: CI Gate
title: The formatter gate
description: dart format finds nothing to change anywhere in the tree. A gate with no argument about what it measures, added beside the analyzer ratchet and not instead of it.
tags: [gate, ci, formatter, style, dr-017]
timestamp: 2026-10-17T00:00:00Z
resource: tools/ci/run_local.ps1
status: enforced
---

`dart format --output=none --set-exit-if-changed .` from the repository root is the
`formatter` step of `tools/ci/run_local.ps1`, and the pipeline runs the same
command. It prints nothing it would have changed and exits non-zero if anything
would change.

The ruling is [DR-017](/decisions/dr-017-dart-format-is-a-gate-the-analyzer-stays-a.md)
(canon section 11.16): the first ruling about process rather than product.

# What it defends

That the tree stays in the formatter's shape, so a diff shows a change and not
somebody's editor. It was absent for months for the same reason the analyzer is a
ratchet: turning it on before the tree was formatted would have made `main`
permanently red. The tree was formatted in one commit first, and the gate is what
stops it drifting back.

Unlike every other gate here it needs no argument about what it measures. `dart
format` is the definition of the answer, which is why DR-017 took the formatter
and kept the info ratchet: formatting has one correct answer and style infos do
not. The two are separate questions, and this one is **not** `--fatal-infos`. See
[the analyzer ratchet](analyzer-baseline.md) for the other.

# What it deliberately does not

- **It does not look at anything but Dart.** Python tools, PowerShell scripts,
  markdown and YAML are outside it. The corpus has its own gates.
- **It does not judge the style.** Which style that is lives in
  `analysis_options.yaml`: `trailing_commas` is held at `preserve` by an override
  there (DR-248), because the lint set's newer default would reformat most of the
  tree inside a dependency bump. Moving to the other value is a choice of its own,
  one line plus one mechanical commit.
- **It is only as right as the configuration it can see.** The style comes from the
  included lint set, so a tree where packages have not been resolved has been seen
  to format under default style and rewrite unrelated files. Run `pub get` before
  `dart format` in a fresh worktree, and read the diff before trusting it.
- **It says nothing about whether the code is correct,** or about analyzer
  warnings. A formatted file can still fail every other gate.

Run `dart format .` before committing; the gate is the backstop, not the habit.

# Citations

[1] `tools/ci/run_local.ps1`, the comment above the step
[2] `analysis_options.yaml`, the `formatter:` section and its comment
[3] `docs/11-testing-and-quality.md` section 7, as amended by DR-017
