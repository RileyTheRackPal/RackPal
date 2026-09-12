# RackPal

Flutter desktop app for AV/low-voltage rack design: elevations, wiring schematic,
schedules, PDF sheet set. Windows-first, macOS ruled in for v1 (DR-009).

## Verify before you claim anything

```bash
pwsh -File tools/ci/run_local.ps1 -SkipBuild
```

All must pass before a commit. **The count is not written here**, on this
file's own rule about a second copy of a moving number: it said *"fifteen"*
until M5-G4 added the AC-051 pair gate and made it sixteen. Count the
`Invoke-Gate` calls in the script. Notes that cost real time:

- **Analyzer is a ratchet pinned to an exact number** in
  `tools/ci/analyze_info_baseline.txt`. **Read the pin from that file**, which
  carries its own history of every move and why; do not trust a number written
  here. This bullet said *"currently 173 infos"* until 2026-09-02, against a file
  saying **233**: the pin had moved twice since (171 at `#226`, then 233 at
  `#246`) and the copy here moved neither time. Same failure as the test-floor
  bullet below, same fix, and the rule generalises: **a second copy of a moving
  number is a liability, not a convenience.** Errors and warnings are gated at
  **zero** and are not ratcheted. Going *under* the pin passes with a warning;
  going over fails.
- **`dart format` is a gate** (DR-017) as of 2026-08-03. Run `dart format .`
  before committing. It is not `--fatal-infos`: the two were separate questions
  and DR-017 took the formatter and kept the ratchet.
- **Anything you leave in `packages/*/tool/` is analyzed.** Scratch scripts inflate
  the info count and fail the gate. Delete them before committing, or keep them in
  the scratchpad.
- **Test floors** live in `tools/ci/run_suite.ps1` and **only there**. Read them from
  `$SuiteFloors`; do not trust a number written in prose, including this bullet.
  Lowering one must be a visible line in a diff. **Re-measure them in any commit that
  adds or removes tests**, which the script says in its own comment and which went
  unheeded until #764 found 3,247 tests of slack under five floors.
  **A COPY OF THESE NUMBERS WENT STALE TWICE ON 2026-08-28 ALONE.** It read
  3263 / 1162 / 838 against a script saying 3365 / 1213 / 841; that was corrected,
  and within the day two concurrent branches re-measured core and ui upward again,
  so the correction was stale before it merged. The figures are therefore no longer
  reproduced here: a second copy of a moving number is a liability, not a
  convenience. CI reports every suite **exactly at its floor**, meaning zero slack,
  so the next deleted test fails the gate rather than hiding.
- **Run suites from the package directory**, not the repo root. Several tests read
  files relative to CWD and fail spuriously otherwise.
- **Stale `build/unit_test_assets` and `build/flutter_assets` cause phantom asset
  failures.** Delete both if a rootBundle test fails for no reason.

## CI, which now exists

`azure-pipelines.yml` is registered as **definition 1, `RackPal CI (Windows)`**, and
**it runs**. First execution was 2026-08-27 (build 20260827.1) against `main` at
`46ec050`: it passed first try, all 24 steps, 22m01s, no fixes. Run 2 took the
warm-cache path at 18m28s.

- **`main` has a blocking build-validation policy** (policy id 1), and it protects
  the branch, not merely the PR. **A direct push to `main` is REFUSED** with
  `TF402455: Pushes to this branch are not permitted; you must use a pull request`.
  This file said the opposite until 2026-08-29 (*"a direct push to `main` still
  lands"*), which was wrong: in Azure Repos a *blocking* policy does both jobs.
  Land work with `az repos pr create`, then
  `az repos pr update --id N --status completed --squash false`, and budget the
  policy build (~18 min) before the PR can complete.
- The pipeline is the same gate set as `run_local.ps1` minus the two local-only
  checks (`flutter pin`, `tracked sources`), which a clean clone cannot fail by
  construction.
- **CI RUNS ON A SELF-HOSTED AGENT SINCE 2026-08-30**, `{agent-host}` in the
  **`Default`** pool (not `LocalMachine`, which exists and has zero agents). It
  lives at `C:\Users\riley\Documents\vsts-agent-win-x64-5.277.0` and runs
  **interactively** from `run.cmd`, NOT as a Windows service: `Get-Service
  vstsagent*` finds nothing and `Agent.Listener.exe` has no parent service. So
  a build sits in `queued` until somebody opens that window, and an
  unexplained queue is a stopped agent rather than a busy one.
  **THE DURATION NOTE HERE HAS BEEN WRONG TWICE, IN OPPOSITE DIRECTIONS**, and
  the numbers below are the first ones measured over the whole population
  rather than generalised from whichever run had just finished. It first read
  *"25.6 minutes, about 35% slower"*, from the single cold-cache first run; it
  was then about to be corrected to *"comfortably faster"*, from the two warm
  PR builds. Both were one sample wearing a trend's clothes.
  **Measured 2026-08-31 over all 38 completed runs (`az pipelines runs list`,
  one cancelled run excluded):**
  - **Hosted, n=33: mean 19.4 min, median 19.0, range 18.0 to 22.0.**
  - **Self-hosted, n=5: mean 20.8 min, median 25.2, range 10.9 to 30.4.**
  The means are close. **THE VARIANCE IS THE STORY**: hosted spans 4.0 minutes
  end to end and self-hosted spans 19.5, nearly five times as wide, on a
  sample of five.
  The five split cleanly by trigger, which is a correlation and not yet a
  cause: the two `refs/pull/*/merge` policy builds took 10.9 and 11.8, and the
  three `refs/heads/*` builds took 25.6, 30.4 and 25.2. The obvious mechanism
  is the one this arrangement always had, written into `azure-pipelines.yml`
  from the start: **it shares the machine with whatever else is running.** A
  branch build starts the instant somebody pushes, which is exactly when that
  person carries on working and starts a local `run_local.ps1`; a policy build
  is waited on. **That is a hypothesis with five data points behind it.** To
  test it, run one branch build with the machine idle and see which mode it
  lands in.
  The move was cost, not engineering: 34 hosted runs spent 643 of the month's
  1,800 free minutes at a mean of 19.4. The clean checkout and the Flutter pin
  both survive it; **"it builds on a machine that is not the author's" does
  not**, and that is now nobody's gate.
- Queue a run against any branch:
  `az pipelines run --org https://{org}.visualstudio.com --project RackMate --id 1 --branch <name>`
- **THE SERVICE HAS GONE RED MORE THAN ONCE AND THE COUNT IS NOT WRITTEN HERE**, on this
  file's own rule. This bullet read *"Nothing has ever gone red"*, then
  **"EXACTLY ONCE"** from 2026-09-02, and both were true when written and wrong within
  days. **Measure it**: `GET /_apis/build/builds?api-version=7.0&$top=500` and count by
  `result`.
- **A FAILING GATE STEP IS PROVEN END TO END, AND THE BUILD THAT PROVES IT IS GONE.**
  Run 11 / build `20260829.7` on `refs/pull/5/merge` failed the analyzer gate with
  `info count rose by 2`, on a tree whose local gates were green (a staged file edited
  after `git add`, so only a clean checkout saw it); the service surfaced it and the PR
  was blocked. **That build has since aged out of retention**: on 2026-09-12 the service
  held 190 records over ids 1 to 211, with 21 gaps, and `20260829.7` is one of them. The
  claim stands on this paragraph now rather than on anything anybody can open, which is
  the argument for writing down what a run PROVED rather than only its number.
- **BOTH REDS CURRENTLY VISIBLE ARE THE MACHINE, NOT THE TREE**, and telling those apart
  is the useful skill. Builds 195 (2026-09-11) and 207 (2026-09-12), both
  `refs/heads/main`, both **overnight**, both a system crash on the agent's own machine:
  - **195's signature is a TORN WORKSPACE.** `flutter pub get` exits 1, and the analyzer
    then reports `Target of URI doesn't exist: 'dart:ui'`. A missing `dart:ui` is not a
    code defect; it is a workspace with no resolved packages.
  - **207's signature is AN AGENT THAT WENT AWAY.** The job exceeds the 120-minute
    maximum and `Agent {agent-host} did not respond to a cancelation request`. Read
    with this file's own note that an unexplained queue is a stopped agent rather than a
    busy one.
- **THE DIAGNOSTIC, WHICH COSTS ONE QUERY.** A red on `refs/heads/main` whose commit
  passed as a `refs/pull/*/merge` build is **the environment, not the tree**: the same
  bytes were green minutes earlier. `195` was `c28ae95`, PR 94's merge, whose own policy
  build passed and whose two successors on `main` passed. Check that before reading a
  single log line, and do not reach for a load or contention theory that the failure's
  own signature does not support.
- **A FAILING TEST is still not proven, and that is a different path sharing a word.**
  No test has ever failed on a run, so the JUnit converter's output has only ever been
  parsed in the green direction: **do not yet treat a green Tests tab as proof the
  reporter works.** Trust the build result; do not yet trust the Tests tab. Every gate
  script was mutation-tested locally, which is not the same evidence. docs/12 §4.1
  carries the measurement.

## The corpus, and which document wins

| Document | Role |
|---|---|
| `docs/canonical-decisions.md` | **Normative.** `CR-nnn`, `AC-nnn`, `RJ-nnn`, `DR-nnn`. §11 is user decisions, §12 is supersessions, §10 is open questions, §13 indexes what §10 answered. |
| `docs/10-decisions.md` | Short-form ADR summary. Where it and a ruling differ, **the ruling wins and docs/10 is wrong**. |
| `docs/12-milestone-board.md` | Evidence and reasoning. Milestone marks, what is actually built, why a number is what it is. |
| `docs/00`–`docs/09`, `docs/11`, `docs/13`, `docs/14` | Derived, priority-3. Edited to match rulings rather than pointered. |

**Canon §12 lists derived-document edits that are owed but unmade.** Read the
ruling, not only the derived sentence. A stale sentence in `docs/09` once produced
a board task instructing weeks of work that a ruling had abolished.

## Process rules (roadmap §8)

- **§8.1** The milestone is the unit of planning; the **exit criterion is the unit
  of truth**. Done means demonstrated, not checklist-ticked.
- **§8.2** Every issue and PR **cites a ruling ID**. No citation means either an
  unadjudicated decision or a re-litigated one.
- **§8.3** Scope changes are **amendments** with a new ruling ID, in their own
  commit. There is one scope list and it is roadmap §2.
- **§8.8** A closed task **names the commit that closed it**. Forward-only from
  2026-08-03; do not backfill.
- **§8.9** A milestone **opens only over a predecessor whose clauses are all
  discharged or parked** (DR-095). Discharged is `DEMONSTRATED` or `CONFIRMED`,
  docs/12 §0's only two discharging marks. **Parked** is reassigned by ruling ID
  to a **named later** milestone, with the structural reason: DR-027 splitting
  M3's Pull Sheet clause is the precedent. **Closing** is the moment that binds;
  opening is soft, and work landing against a later milestone stays legal.
  **Retroactive to M0**, unlike §8.8, because a clause's evidence can be re-run.

## Invariants that bite

- **G4 / CR-114: null is unknown, never estimated.** `0` means measured zero.
  Unknown serializes as an **absent key**, never an explicit `null`. Every rollup
  reports its unknown count rather than fabricating a total.
- **AC-039**: `typicalWatts` is never derived from `nameplateWatts`.
- **CR-001**: integer units only. `Len` = int64 nanometres, `Mass` = int64
  micrograms, `Permille` for fractions. **No floating-point millimetres**, in the
  model or in any file format.
- **CR-117**: byte round-trip. `write(read(bytes)) == bytes`, keys sorted.
- **Package layering**: `rackpal_core` has **zero Flutter imports** (gated).
  `rackpal_export` may never import `rackpal_ui`.
- **Determinism**: same document, same display list, same exported bytes. Sort
  comparators must be **total** (Dart's `List.sort` is not stable), so every chain
  ends in a unique id.
- **CR-078**: colour lives on the signal **domain**, never the family. PAL-1
  (canon §14) is a CI gate over rendered greyscale values.

## Workspace

- `packages/rackpal_core` model, commands, derived, persistence, draw scene, catalog
- `packages/rackpal_ui` Flutter widgets, canvas, inspector, palette
- `packages/rackpal_export` PDF backend
- `packages/rackpal_pdfium` the vendored pdfium binding (`dart:ffi`, DR-153). **The binary is committed, not downloaded** (CR-100) and is placed by a person: `pwsh -File tools/vendor_pdfium.ps1 -Verify` says whether the tree has it
- `packages/rackpal_text` text metrics
- `apps/rackpal` shell, session, storage

## Goldens

- Starters: `cd apps/rackpal && dart run tool/generate_starters.dart`
  (`--check` for CI-style verification). They are checked in and do triple duty as
  goldens, perf fixtures and screenshot source.
- Perf/scene fixtures: `UPDATE_GOLDENS=1 flutter test <path>`. The op-count
  baselines in `schematic_perf_test.dart` are M2-C's record; regenerate content
  only when you mean to invalidate them.
- File shape gotcha: in a `.rmpj`, `registries` is nested under `document`, and
  `Registries.connectorTypes` serializes under the wire name **`connectors`**.

## Board (Azure DevOps)

Org `https://{org}.visualstudio.com`, project **`RackMate`**, area and iteration
**`RackMate`**, tags `rackpal-sync; task`. States: `To Do`, `Doing`, `Done` (there
is no `Removed`).

**THE PROJECT IS `RackMate` AND THAT IS DELIBERATE.** DR-096 §11.95.9 rules in
terms that the rename *"does not rename the Azure DevOps project, the repository or
the board's area path"*. This file said `RackPal` for all three until 2026-08-28,
so the sweep had edited a line inside its own ruling's exclusion list, and every
`az` command built from it fails with `TF200016: project does not exist`.

Hierarchy is **Saga → Epic → Story → Chapter** (DR-097). A **Saga** is a release
band from roadmap §2: v1, v1.1, v1.2, v2, so moving an Epic between Sagas *is* the
visible act of an §8.3 amendment. An **Epic** is a milestone or a ruling-born body
of scope. **An Epic is `Done` when its exit criterion is met (§8.1), not when its
children run out**; children still open at that moment are re-parented to whoever
will deliver them, never left under a closed Epic. **No work item may have no
parent.**

The process is **`RackPal`** (inherited from Basic), not Basic. `Issue` and `Task`
still exist but are **disabled**: everything migrated to `Story` and `Chapter` on
2026-08-28, and the board holds 4 Sagas, 20 Epics, 218 Stories, 524 Chapters with
zero hierarchy violations and zero parentless items.

Board columns are **To Do / Ready / Doing / Needs You / Done** over the three
states, since several columns may map to one state. **`Needs You` is for work
blocked on a human act** (a timed drill, a tape measure, a print run) that no agent
can move. Swimlanes are `Expedite / (default) / Blocked`. Columns and lanes are a
team setting, not a ruling, and are reversible in a click.

`az` quirks, each of which cost a round trip:

- **`--fields "System.Tags=..."` merges rather than replaces** (`add` op), so it can
  only ever *widen* the tag set. To rename a tag: widen every item to the new tag,
  **then** one `DELETE /_apis/wit/tags/{old}`. Deleting first strips the tag from
  everything not yet widened.
- `az devops invoke` is broken for the whole `wit` area (bare `ERROR: 'type'`, even
  on GET) and cannot parse any `-preview.N` api-version. Use a PAT with `curl` or
  `Invoke-RestMethod`.
- **A project's process cannot be changed over REST**; it is web-UI only. A
  `description` PATCH to the same endpoint returns 202, so a 400 there is the
  capability, not your credentials.
- **The process API returns 200 while doing nothing.** It silently ignored two
  rename attempts. Re-read after every write.

The board mirrors **structure**; the reasoning lives in `docs/12` and `docs/13`.

`az` CLI quirks, each learned the hard way:

- **Pass descriptions via `@file`, never inline.** `az` runs through `cmd.exe`, and
  `subprocess.list2cmdline` only quotes arguments containing spaces, so a
  space-free HTML string like `<p>AC-024.</p>` has its `<p>` parsed as a file
  redirect. Symptom: "The system cannot find the file specified".
- `--fields` truncates at the first newline.
- `@project` in WIQL returns empty with exit 0. Name the project literally.
- **A PR description is capped at 4,000 characters** and `az repos pr create`
  refuses the whole call over it, having already validated everything else. The
  work-item description has no such cap, so the habit that works there does not
  transfer. Measure the file before the call; a commit message is the place for
  the long version, and it is under no cap at all. **The refusal is
  `ERROR: Invalid argument value.` and names nothing**, so a call that fails
  right after you shortened it is probably still over.
- **`az repos pr create` SILENTLY STRIPS EVERY NON-ASCII CHARACTER** from a
  description passed by `@file`, even though the file is UTF-8 and the same file
  posts correctly over REST. Measured on PR 101, 2026-09-12: `§` vanished from
  every canon citation, `…` from every menu name, every em dash inside a
  blockquote, and the attribution line's emoji. Nothing warns and the PR is
  created. **Post the description over REST** (`PATCH
  .../pullrequests/{id}?api-version=7.0` with `{"description": ...}` and
  `Content-Type: application/json; charset=utf-8`), or create with `az` and
  immediately PATCH the description back. Same root as the `UnicodeDecodeError`
  on `0xa7` when READING: the CLI is transcoding through cp1252 in both
  directions.

## Committing

- **Atomic commits**: one logical change each, every one gated green, push every
  commit. Green wins over small.
- Message body explains **why**, and names the mechanism when a bug is fixed.
- End with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

- **Bump the version when an issue closes.** `0.EPIC.TASK` (docs/14 §14.0): the
  minor is the milestone epic, the patch is the count of **Done board Tasks**
  under that epic's issues. Not semver, and not per commit. It lives in **six
  files** and `version_parity_test.dart` gates them against each other, which is
  structurally blind to all six being stale together: that is how `v0.2.0` sat
  through thirty M3 tasks (`bdbbdb4`) and `v0.3.30` through forty-six M4 ones.
  **Derive the number in the commit message**, counted two ways that agree, so
  the next person can re-derive it rather than trust it. `M4-0`-style
  decomposition items are Issues and are not counted.
- **The version tracks the CURRENT milestone, not the one an issue is filed
  under.** Work landed early against a later milestone (M5-0a during M4, say)
  does not move the number: the minor would have to jump forward while the
  current milestone is unfinished, and the patch would count backwards. Such an
  issue closes without a bump and is counted when its milestone becomes current.

## House style

Tests **assert the artifact, not the mechanism**. A test that pins an intermediate
value survives the behaviour it was protecting; more than one test in this repo has
been found asserting a defect as intended behaviour. When a comment explains why a
branch exists, keep it, and update it when the branch changes.

**Do not use em dashes in prose.** The sweep this rule used to schedule has run over
every tracked markdown file: **5,883 sites** became a colon, a comma, a semicolon or a
pair of parentheses, chosen by what followed the dash. `docs/research/`,
`docs/m1-implementation-log.md`, `.okf/` and `assets/catalog/sources.md` are all
included; `research/README.md` carries the exception this created to its own
"unedited outputs" claim. **363 of those sites were wrong** and have been restored;
the fourth class below is why.

**THAT SWEEP DID NOT FINISH, AND THIS PARAGRAPH READ AS THOUGH IT HAD UNTIL
2026-09-04.** A second pass that pairs inline code across lines found **61 survivors
in 23 files**, 42 of them in `.okf/` and 19 under `docs/`: canon 15, docs/12 3,
docs/10 1, the m1 log 1, `assets/catalog/sources.md` 1. They are now swept, in the
same commit as this correction. **43 of the 61 sat immediately after a closing
backtick or a `**`**, as in ``` `Placement { … }` — stored elevation geometry ```,
which is the shape the first sweep evidently could not see and the shape to check
first next time. The dash there is punctuation and not data, so the code exception
below does not reach it. A fifth class was added to the four: **an inline quotation**
is left alone for the same reason a blockquote is.

Five classes are deliberately left alone, and a later sweep should leave them alone.
**Code** keeps them, fenced or inline, because there the dash is data rather than
punctuation: `—` is what G4 prints for an unknown. **A table cell whose whole content
is a dash** keeps it for exactly that reason, backticks or no: it is G4's unknown, or
"not applicable", and it is the *value* of that column for that row. Rewritten as a
bare `,` it reads as a typo and the fact is gone. **Blockquotes** keep them, because
canon quotes rulings and critiques word for word and editing a quotation falsifies the
record. **YAML frontmatter** keeps them, because a `title: DR-001 — …` rewritten with a
colon is a parse error, and OKF puts ruling titles in exactly that field. **An inline
quotation** keeps them, on the blockquote's reasoning exactly: `*"a dash inside quoted
words"*` is somebody else's sentence, and the quote marks do not stop being quote marks
because the passage is short enough to sit in a paragraph.

A future sweep should reuse the post-conditions rather than trust a spot-check:
brackets, backticks and emphasis markers must balance, and the **line count must not
change**, since the corpus is hard-wrapped and a swallowed newline reflows a paragraph.
Pair detection has to run over the paragraph rather than the line, for the same reason.

Balancing is necessary and not sufficient. Add one more: **a bracket pair must not
cross a `|`.** Five table rows survived the sweep with `(` in one cell and `)` in the
next, which balances per line and is nonsense per cell, and no post-condition then in
force could see it. The cheap check is that no cell's trimmed content is a lone
bracket.

Two more the 2026-09-04 pass needed, both cheap and both caught in its own dry run:
**a dash that ends a line must not leave a trailing space** where its replacement
lands, and when a parenthesis opens at a line end it belongs on the next line
**inside that line's indent**, since the corpus indents continuations. Run
`git diff --check` and `git diff --stat`: **insertions must equal deletions**, which
is the line-count post-condition stated in a form that reads at a glance.
