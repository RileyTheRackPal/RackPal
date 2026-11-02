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
`1fab087`: it passed first try, all 24 steps, 22m01s, no fixes. Run 2 took the
warm-cache path at 18m28s.

- **`main` has a blocking build-validation policy** (policy id 1), and it protects
  the branch, not merely the PR. **A direct push to `main` is REFUSED** with
  `TF402455: Pushes to this branch are not permitted; you must use a pull request`.
  This file said the opposite until 2026-08-29 (*"a direct push to `main` still
  lands"*), which was wrong: in Azure Repos a *blocking* policy does both jobs.
  Budget the policy build (~18 min) before a PR can complete.
- **NEVER LET AZURE DEVOPS MAKE A COMMIT** (DR-257 §11.256.2.6). It stamps the
  completing account's profile on every merge commit it creates, which is the
  identity the history rewrite removed, so `--squash false` (and squash, and a
  rebase that has anything to rebase) re-leaks it on the first PR. Land work so:
  1. `az repos pr create`, to learn the PR number `N`.
  2. Locally, on a branch made from the current `origin/main`:
     `git merge --no-ff <branch> -m "Merge pull request N from <branch> into main"`
     under `TZ=UTC0`, then push that merge commit as the PR's source branch tip
     (a fast-forward of the source, so no force). The policy build re-queues on it.
  3. When it is green, confirm `origin/main` is still the merge's first parent,
     then complete over REST with `"completionOptions":
     {"mergeStrategy":"rebase"}`. With nothing to rebase, ADO fast-forwards and
     `main` becomes your merge commit byte for byte (probed on PR 265).
  4. Read `main` back: its tip must be your SHA. If `main` moved first, rebuild the
     merge on the new tip; a real rebase would rewrite every commit as ADO's.
- The pipeline is the same gate set as `run_local.ps1` minus the two local-only
  checks (`flutter pin`, `tracked sources`), which a clean clone cannot fail by
  construction. **THAT SENTENCE HAD A SECOND HALF UNTIL 2026-10-18**: *"and minus two
  more that nobody chose"*, `glyph coverage` and the named `AC-051 pair coverage` step,
  found while copying the step list for macOS. Both are now steps in both pipelines.
  The lesson was in why `glyph coverage` was the one missing: **it is the only gate
  that imports a third-party Python package** (`fontTools`), so copying its line would
  have gone red on a clean agent. A step installs it first from the hash-pinned
  `tools/ci/requirements.txt`. A new gate script that needs a package goes in that file.
- **DEFINITION 2, `RackPal CI (macOS)`** (`azure-pipelines-macos.yml`, DR-255), runs on
  a Microsoft-hosted `macOS-15` image against the one free hosted job of 1,800 minutes
  a month, as an **optional** PR check. **It may never be made blocking**: the month the
  minutes ran out, nothing would merge. It reads the Flutter pin from
  `azure-pipelines.yml`. Its floors differ only where `$SuiteFloorsMacOS` in
  `run_suite.ps1` says, and every difference names its cause. **It builds `RackPal.app`**
  (D1, DR-256: `com.rackpal.rackpal`, no sandbox, hardened runtime) and gates it with
  `verify_macos_build.ps1`. **The image is Intel**, so nothing here ever executes arm64.
- **`flutter create` ON WINDOWS WRITES CRLF**, and `.gitattributes` makes every checkout
  of `apps/rackpal/macos/` LF, so a freshly generated tree and a clone differ on this
  machine. **Git Bash's `grep` and `cat -A` hide carriage returns here**; two agents
  reported the CRLF tree as LF that way. Count bytes in Python before believing either.
- **CI RUNS ON A SELF-HOSTED AGENT SINCE 2026-08-30**, `{agent-host}` in the
  **`Default`** pool (not `LocalMachine`, which exists and has zero agents). It
  lives at `%USERPROFILE%\Documents\vsts-agent-win-x64-5.277.0` and runs
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
  `az pipelines run --project RackMate --id 1 --branch <name>`
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
  bytes were green minutes earlier. `195` was `793839e`, PR 94's merge, whose own policy
  build passed and whose two successors on `main` passed. Check that before reading a
  single log line, and do not reach for a load or contention theory that the failure's
  own signature does not support.
- **AND AN ABSENCE IS NOT AN OBSERVATION UNTIL YOU HAVE WAITED.** A merge to `main`
  queues its own build, and it appears **tens of seconds to a couple of minutes after
  the PR completes**, not instantly. On 2026-09-12 that gap was polled for about two
  minutes after each of two merges, found empty, and reported first as a broken trigger
  and then as *"a pattern rather than a hiccup"*. **Both builds existed**: `210` on
  `484c01f1` and `213` on `5cd09e97`, both `individualCI`, both queued shortly after
  their merges, and a manual build was queued on the false premise and duplicated `210`
  for nothing. **Read `reason` on the newest build for that branch before concluding
  anything**: `individualCI` means the trigger fired and `manual` means a person did.
  Two negative polls are not a pattern; they are two polls.
- **AND THE SECOND TIME IT WAS THE QUERY, NOT THE SERVICE.** On 2026-09-13 a poller on
  `GET /builds?$top=3&branchName=refs/heads/main` printed *"no build yet"* eight times
  after PR 119 merged, and the build **existed for all eight of them**: `249` queued at
  `00:35:04`, three seconds after the merge, and ran 7m52s. It appeared in the poll the
  moment it FINISHED. **The list API's default order puts a build with no `finishTime`
  last**, so a running build falls off the end of a small `$top` and a poll watching for
  it reports an absence it structurally cannot see. Pass
  **`queryOrder=queueTimeDescending`**, or ask for the build by `sourceVersion`, or make
  `$top` bigger than the number of builds that can finish while yours runs. The same
  poller watching `refs/pull/119/merge` with `$top=10` saw `inProgress` fine, which is
  why this looked like a service delay rather than a filter.
- **A FAILING TEST IS PROVEN ON THE SERVICE SINCE 2026-10-18, BY THE macOS PIPELINE.**
  This bullet said *"still not proven"* until then: no test had failed on a run, so the
  JUnit converter had only been parsed in the green direction. Build `481`, the first run
  of definition 2 (`azure-pipelines-macos.yml`, DR-255), failed 23 cases on the pdfium
  debt and one test defect. All 23 reached the Tests tab with their messages, and
  `PublishTestResults` failed its step on them. **The converter and the publish task are
  the same files in both definitions**, so this is evidence for definition 1's reporter
  too; what it is not is a red run OF definition 1. docs/13 §2.5 carries the measurement.

## The corpus, and which document wins

| Document | Role |
|---|---|
| `docs/canonical-decisions.md` | **Normative.** `CR-nnn`, `AC-nnn`, `RJ-nnn`, `DR-nnn`. §11 is user decisions, §12 is supersessions, §10 is open questions, §13 indexes what §10 answered. |
| `docs/10-decisions.md` | Short-form ADR summary. Where it and a ruling differ, **the ruling wins and docs/10 is wrong**. |
| `docs/12-milestone-board.md` | Evidence and reasoning. Milestone marks, what is actually built, why a number is what it is. |
| `docs/00`–`docs/09`, `docs/11`, `docs/13`, `docs/14` | Derived, priority-3. Edited to match rulings rather than pointered. |
| `docs/15-plan-view.md` | Derived spec, priority-3, like `docs/00`–`docs/09`: it cross-references the data model and cites a ruling for every decision. |
| `docs/16-m3g-drill.md`, `docs/17-m4q2-drill.md` | **Drill records**, not specs: the script, conditions form and verdict form for an exit clause that only a person can perform, plus the verdict once given. The mark the verdict earns is docs/12's to state; where a record and docs/12 differ, docs/12 and the ruling win. |
| `docs/18-m4r-mark-legibility.md` | A **paper check** of the same kind as the drills: the half of M4-R that no assertion can perform, kept with its verdict form. Same precedence. |
| `docs/19-riley.md` | A **character reference** written to be handed to an artist. Its own header declares the fixed half normative, by canon §10.12(f), DR-096, DR-117 and DR-118, and the rest open; read it as derived from those rulings, not as a second source of authority. |
| `docs/20-rule-review.md` | **Generated** by `tools/rule_review.py` from the rule catalogue, for an integrator to mark up. Do not edit by hand; `--check` is a gate. The review's outcome is recorded in docs/12, not here. |
| `docs/21-user-guide.md` | A **guide**, and the one document that describes what the application DOES rather than what it should be. It is not a spec: where it and the running application differ, the application is right and the guide is stale. |
| `docs/22-riley-plate-plan.md` | A **plan**, proposed and not ruled, by its own header. Where it and docs/19 or DR-117 / DR-118 disagree, they win. |
| `docs/m1-implementation-log.md` | A **build record** of M1's stages, not a spec: it tracks build status against the specs and redefines no scope. M1 is closed, so it is history; the evidence for M1's marks lives in docs/12 §3. |
| `docs/catalog/seed-devices.md` | **Spec and shipping content at once**: the seeded archetypes and the registries reproduced from canon §6. Gated by `tools/registry_parity.py` and `tools/palette_parity.py`; where it and canon §6 differ, canon wins. The only place a template count is stated (CR-061). |
| `docs/research/` | **Working papers**, non-normative rationale, kept for audit. Its README states the status; the plan documents win wherever they disagree. |
| `docs/reference/keymap-windows.md` | **Generated** from `kKeymap` and held by a golden test (`keymap_reference_golden_test.dart`). Do not edit by hand. |
| `docs/reference/keystone/` | **Reference material**: photographs and technical drawings of the real strap and plate parts, supplied for DR-007 §11.7. Its README says what belongs there. Not prose and not subject to the prose rules. |

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
- `packages/rackpal_pdfium` the vendored pdfium binding (`dart:ffi`, DR-153). **The binaries are committed, not downloaded** (CR-100) and are placed by a person, one per platform from ONE release: `win-x64/pdfium.dll` and a universal `mac-univ/libpdfium.dylib` (#468), each with its licences beside it. `pwsh -File tools/vendor_pdfium.ps1 -Verify` says whether the tree has them. **Run it by FULL PATH** (`pwsh -File C:\...\<worktree>\tools\vendor_pdfium.ps1 ...`): it resolves the repository from its own location, and on 2026-10-18 a run typed from the wrong folder re-stamped the main checkout's pin instead of vendoring into the worktree
- `packages/rackpal_text` text metrics
- `apps/rackpal` shell, session, storage

## Goldens

- Starters: `cd apps/rackpal && dart run tool/generate_starters.dart`
  (`--check` for CI-style verification). They are checked in and do triple duty as
  goldens, perf fixtures and screenshot source.
- Perf/scene fixtures: `UPDATE_GOLDENS=1 flutter test <path>`. The op-count
  baselines in `schematic_perf_test.dart` are M2-C's record; regenerate content
  only when you mean to invalidate them.
- File shape gotcha: in a `.rppj`, `registries` is nested under `document`, and
  `Registries.connectorTypes` serializes under the wire name **`connectors`**.

## Toolchain and dependencies (DR-248)

- **The Flutter pin lives in `azure-pipelines.yml`** (`flutterVersion`,
  `flutterFrameworkRevision`) and nowhere else: `run_local.ps1` reads it. Moving it
  is a reviewed act (docs/11 §7). **Read the version there**, not here.
- **Nothing is adopted until it is fourteen days old** (DR-248, standing): a pub
  package, direct or transitive, or a Flutter release, by its pub.dev publication
  date or Flutter's release feed. An exception names its reason in the commit.
  `flutter upgrade` on a developer machine ignores this, so do not run it bare.
- **`pubspec.lock` is committed** and CI runs `flutter pub get --enforce-lockfile`,
  which builds exactly the committed graph and checks each archive's sha256. A
  dependency change is a lock diff someone can read.
- **AN IDE OPEN ON THIS TREE IS A SECOND WRITER.** Android Studio and VS Code re-run
  `pub get` with the *global* SDK about two seconds after any `pubspec.yaml` edit,
  and rewrite the lock behind you. It reverted an upgrade and produced a false
  finding on 2026-10-11. **Do dependency work in a sibling worktree** no IDE has
  open (`git worktree add ../wNNNN <branch>`, short names: MAX_PATH).
- **A lint-set bump moves two things**: the exact pin in the pubspecs AND the
  versioned include in `analysis_options.yaml`, since every release still ships the
  old rule files. The include's `formatter:` section can change too; this repo keeps
  `trailing_commas: preserve` by an override there.
- **Switching a local SDK by tag**: `git checkout -B stable <tag>`, not a bare
  `checkout <tag>`. A detached HEAD reports channel `[user-branch]` and the pin gate
  refuses it; delete `bin/cache/flutter.version.json` so Flutter recomputes it.
- **The self-hosted agent keeps its tool directory**, so a stale SDK survives a pin
  move; `ensure_flutter.ps1` replaces an SDK that is not the pin (since build 463).
- **Commands handed to the user run in Windows PowerShell 5.1**: no `&&`, Windows
  paths, `if ($LASTEXITCODE -eq 0) { ... }` to chain.

## Board (Azure DevOps)

Org `https://{org}.visualstudio.com`, project **`RackMate`**, area and iteration
**`RackMate`**, tags `rackpal-sync; task`. States: `To Do`, `Doing`, `Done` (there
is no `Removed`).

**THE ORGANISATION IS NOT WRITTEN IN THIS TREE** (DR-257): it repeats a mail
address, and the history was rewritten to remove it. Each machine names it once with
`az devops configure --defaults organization=https://<name>.visualstudio.com
project=RackMate`, after which `az` commands need no `--org`; a REST call reads it
from `git remote get-url origin`. **Do not write it back**, in a file, a commit
message or a ruling. The same holds for the identity: every commit is
`Riley <rileytherackpal@proton.me>` at `+0000`, so set `user.name` and `user.email`
in the repository's own config (the global identity on this machine is not this
one) and commit with `TZ=UTC0`.

**THE PROJECT IS `RackMate` AND THAT IS DELIBERATE.** DR-096 §11.95.9 rules in
terms that the rename *"does not rename the Azure DevOps project, the repository or
the board's area path"*. This file said `RackPal` for all three until 2026-08-28,
so the sweep had edited a line inside its own ruling's exclusion list, and every
`az` command built from it fails with `TF200016: project does not exist`.

Hierarchy is **Saga → Epic → Story → Chapter** (DR-097). A **Saga** is a release
band from roadmap §2, **read the bands there**: this line listed four (v1, v1.1,
v1.2, v2) until 2026-10-12, when DR-188 and DR-246 had made it six. Moving an Epic
between Sagas *is* the visible act of an §8.3 amendment. An **Epic** is a milestone or a ruling-born body
of scope. **An Epic is `Done` when its exit criterion is met (§8.1), not when its
children run out**; children still open at that moment are re-parented to whoever
will deliver them, never left under a closed Epic. **No work item may have no
parent.**

The process is **`RackPal`** (inherited from Basic), not Basic. `Issue` and `Task`
still exist but are **disabled**: everything migrated to `Story` and `Chapter` on
2026-08-28, when the board held 4 Sagas, 20 Epics, 218 Stories, 524 Chapters with
zero hierarchy violations and zero parentless items. **Those are that day's numbers**,
kept as the migration's record; this line read as current until 2026-10-12, by
which time every one had grown. Count the board for today's.

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
  the long version, and it is under no cap at all. **THIS BULLET SAID THE
  REFUSAL "NAMES NOTHING" AND THAT IS NO LONGER TRUE**: on 2026-09-13 it printed
  `ERROR: Invalid argument value.` followed by a blank line and
  `Parameter name: A description for a pull request must not be longer than 4000
  characters.`, three times running. The second line is easy to lose if the
  output is piped through anything that keeps only the first, which is the most
  likely reason it was recorded as silent. **AND THE UNIT IS NEITHER
  CHARACTERS NOR BYTES**, which this bullet has now had wrong in both
  directions: it said bytes, was corrected to *"measure in CHARACTERS, not
  bytes"* on 2026-09-13, and a description of **exactly 4,000 characters was
  refused** on PR 144. **It is 4,000 UTF-16 CODE UNITS**, which is what
  `String.Length` counts in the service's own runtime, so **an astral
  character costs two** and everything in the BMP costs one however many
  UTF-8 bytes it takes.
  **MEASURED ON PR 144, 2026-09-17**, one variable at a time. Every acceptance
  is at or under 4,000 units and both refusals are at 4,001, and nothing else
  separates them:

  | Description | chars | UTF-8 bytes | UTF-16 units | Result |
  |---|---|---|---|---|
  | the real one, with its emoji | 4,000 | 4,013 | 4,001 | **refused** |
  | `x` x 3999 + one emoji | 4,000 | 4,003 | 4,001 | **refused** |
  | `x` x 4000 | 4,000 | 4,000 | 4,000 | accepted |
  | `x` x 3999 + one `§` | 4,000 | 4,001 | 4,000 | accepted |
  | `x` x 3998 + one emoji | 3,999 | 4,002 | 4,000 | accepted |
  | `x` x 3990 + ten `→` | 4,000 | **4,020** | 4,000 | accepted |

  The last row is the one that kills the byte reading, and the fourth kills
  the character reading. **THE STING IS THE ATTRIBUTION LINE**: the emoji this
  repository ends every PR description with is astral, so a description
  trimmed to exactly 4,000 characters is always 4,001 units and always
  refused. Count `len(text.encode('utf-16-le')) // 2`, and the cheapest way to
  stay clear of all three readings is to leave a line of slack.
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
  under that epic's issues. Not semver, and not per commit. **The list of files
  it lives in is `apps/rackpal/test/version_parity_test.dart`**, which gates them
  against each other and is structurally blind to all of them being stale together
  (no count is written here: this bullet gave one until `rackpal_pdfium` joined
  and made it wrong, which is the rule on second copies of a moving number). That
  is how `v0.2.0` sat through thirty M3 tasks (`d250082`) and `v0.3.30` through
  forty-six M4 ones. **Derive the number in the commit message**, counted two
  ways that agree, so the next person can re-derive it rather than trust it.
  `M4-0`-style decomposition items are Issues and are not counted.
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

And one the sweep needed and did not have: **every link target still resolves, anchors
included.** A heading slug keeps its dash, so `## 5. Rules — three tiers` is
`#5-rules--three-tiers`, and the sweep's colon replacement turned it into
`#5-rules-three-tiers` while every link written against the old slug stayed put. That
moved 16 heading anchors, and none of the post-conditions above could see it, because
brackets, backticks, emphasis and line count all came out identical (DOCS-2c `#1067`,
2d and 2g repair the links). The check is to resolve each `[text](file#anchor)` against
the target's headings after the sweep, and to run it over any heading a sweep edits.
