# Milestone board: M0 → M9 → v1

This is the **status** document. [The roadmap](09-roadmap.md) is the plan, written before any of
it was built; [the M1 implementation log](m1-implementation-log.md) is the build diary for one
milestone. Neither reflects the repository as it stands, and the roadmap in particular carries
**zero ticked checkboxes against fifty-nine unticked ones** after M0 and most of M1 have shipped.
This file closes that gap for all ten milestones.

**Why it is written the way it is.** The only thing this board is for is separating what has been
**demonstrated** from what is merely **believed**. A board that said "M1: done" would be worthless,
and worse than worthless in this repository specifically, because this project has repeatedly
shipped claims that did not survive measurement:

| The claim | What measurement found |
|---|---|
| The schematic canvas works | It rendered a fabricated symbol behind a run of eight consecutive `fix:` commits, ten in the eighteen-commit detour overall, with zero tests; salvaged and reverted at `b560a50`. (`docs/m1-implementation-log.md:824` says *"twelve consecutive"*; over the range this board cites, `git log --oneline e433ae0^..1eec6bf` shows ten `fix:` subjects and a longest unbroken run of eight, `1eec6bf` back to `3965667`, broken by `a66668b`. The figure is corrected here rather than inherited, a table about unmeasured claims drifting is the last place to restate one) |
| The rear elevation renders | It was blank. Nothing in the regression net observed `Face.rear` in emitted bytes until `elevation_true_scale_test.dart` was written for that purpose (`0fa532d`) |
| PAL-1 is verified clear | Asserted three times by reading an eight-row domain table instead of enumerating the 385 family pairs actually drawn. The palette carried **fourteen** collisions (canon §14.3) |
| The registry-claim row is accurate | Wrong four times running; the fix was to state a **bound** rather than a closed list, enforced by `apps/rackpal/test/session/registry_claim_test.dart` |
| The catalog weight is right | It was 1000× off, behind a test that only asserted non-null (`b560a50`) |

Every one of those was an honest claim at the moment it was written. The failure mode is not lying;
it is an assertion that quietly stops covering the thing it names. So **every row below cites the
file, test, line or commit that would have to be wrong for the row to be wrong**, in the citation
style of [the M1 log](m1-implementation-log.md). A status with no citation is a status this board
does not carry.

**Scope.** This file does not change scope. Moving an item between v1, v1.1, v1.2, v2 and
not-doing is an edit to [roadmap §2](09-roadmap.md#2-the-scope-ruling) with a new ruling ID
(roadmap §8.3). **§7.3 below lays out options for such a decision with their costs, and §7.5 states
in terms that it makes none.**

---

## 0. The legend

The distinction the whole document turns on is between a clause that has been **run** and a clause
that is **expected to hold**.

| Mark | Meaning | The test it must pass |
|---|---|---|
| **DEMONSTRATED** | Checked by running something in this repository, and the run is named. | A reader can execute the cited test or command and watch it pass. |
| **CONFIRMED** | A clause naming a physical act or a wall-clock drill was **performed by a person and passed**, and who did it and when is recorded. | Nobody can re-run it from a terminal. It discharges the clause and it is **not a gate**. |
| **BELIEVED** | Code exists that is intended to satisfy the clause; nothing has measured it. | The implementation is citable. The measurement is not. |
| **VACUOUS** | The clause passes only because the thing it constrains does not exist. | True today, and true for a reason that will stop being true. |
| **REFUTED** | The act was **performed and it failed**. | Stronger information than any "not yet": the attempt was made, so the gap is a measured fact and the remedy is known. |
| **UNPERFORMED** | The clause names a physical act, a human judgement or a wall-clock drill that nobody has done. | No amount of code discharges it. Somebody has to do the thing. |
| **NOT BUILT** | Nothing exists. | Grep returns nothing. |

`DEMONSTRATED` and `CONFIRMED` are the only marks that discharge an exit clause. The rest are
distinguished because the **remedy** differs: `BELIEVED` wants a test, `VACUOUS` wants the test
rewritten when the subject appears, `REFUTED` wants the named fix, `UNPERFORMED` wants a person and
ten minutes, and `NOT BUILT` wants the feature. **The seven rows above are ordered strongest to
weakest, and that order is what "weakest" means below.** Every clause carries exactly one of the
seven; a mark that reads "demonstrated in spirit" or "demonstrated but" is not a mark, it is a
negotiation.

**A clause that is not discharged may be parked, and its mark cell then says where it went:**
`**NOT BUILT**, parked on M6 by DR-027`. That is roadmap §8.9's park (DR-095 §11.94.5): a ruling ID
and a named later milestone, written in the one cell the milestone-completeness gate (`#780`) reads.
**A park keeps the clause's true mark.** It moves who owes the clause, not what has been shown, so a
parked clause never reads as discharged. **A row that is not an exit clause says so in its Clause
cell**, as M1's goal line and M8's licence row do, and is counted neither discharged nor owed.

**Why `CONFIRMED` and `REFUTED` exist, and why they are not `DEMONSTRATED` and `UNPERFORMED`.**
The first draft of this legend had five marks and assumed every undischarged clause was a flavour
of *not yet*. Two of M1's clauses then met a human on 2026-07-27 and broke that assumption in both
directions at once: the tape measure **passed** and the keyboard-only drill **failed**. Neither
outcome fits a five-mark legend, a human pass is not something a reader can execute, and a
measured failure is not a "not yet". Collapsing the first into `DEMONSTRATED` would have quietly
claimed CI coverage this repository does not have; collapsing the second into `NOT BUILT` would
have thrown away the most expensive information on this board, which is that somebody actually
tried. The remedy differs, so the mark differs.

**A milestone's status is the weakest mark across its exit clauses**, not the average and not the
mode. This is roadmap §8.1: *the exit criterion is the unit of truth*.

**That rule is applied here, not merely asserted.** It resolves to three headline statuses, and
every headline in this file names the weakest mark that produced it so a reader can check the
arithmetic against the clause table beneath it:

| Headline | When |
|---|---|
| **COMPLETE** | **Every** exit clause is `DEMONSTRATED` or `CONFIRMED`. Nothing weaker, anywhere. |
| **PARTIAL** | At least one exit clause is discharged and at least one is not. |
| **NOT STARTED** | No exit clause is discharged. |

Two headlines cost this board something when the rule was actually applied, and both are named
here rather than buried. **M0 WAS `PARTIAL`, not complete, until 2026-08-27**: two of its own exit
conjuncts were `VACUOUS`, and the same `VACUOUS` mark still unseats M5's clause 3 (§5.4) and the
roadmap's global *"goldens pass"* limb (§4.3); an exemption granted to one milestone and to no
other is a preference, not a finding (§2.3). **Both are now `DEMONSTRATED`**, and the headline is
kept because of how they closed: not by the argument §2.3 withdrew, but because their subjects
came into existence and DR-095's §8.9 worklist noticed. **A clause whose `VACUOUS` reason has
expired reads exactly like one whose reason still holds**, which is the argument for a gate over a
habit. **M6 is `NOT STARTED`, not partial**: real M1-slice work sits inside it, but zero of its
five exit clauses is demonstrated, and grading "partial" against work-in-the-milestone rather than
against the criterion is precisely the substitution roadmap §8.1 forbids (§5.5). Where a milestone
contains real work its headline does not credit, the **short reason** column says so; the headline
still tracks the criterion.

---

## 1. The board at a glance

Verified against the working tree at `0fa532d`, by reading code rather than checkboxes. Suite
counts from that session: `rackpal_core` 886, `rackpal_ui` 351, `apps/rackpal` 651,
`rackpal_export` 183, `rackpal_text` 1, **2072 passing, 0 failing**. `flutter analyze`: 195
issues, all info-level, **zero errors, zero warnings**. `flutter build windows --release`: exit 0.

**M2's row alone was re-audited at `ea0af6d`** (M2-F) and again after M2-G, against the thirteen
local gates: `rackpal_core` 1380, `rackpal_ui` 592, `apps/rackpal` 690, `rackpal_export` 183,
`rackpal_text` 1, **2846 passing, 0 failing**, analyzer pinned at exactly 194 infos by
`tools/ci/analyze_info_baseline.txt`. **Every other row is still as of `0fa532d`** and carries
whatever drift the intervening milestones introduced; a row this file has not re-read is a row it
does not vouch for, and saying so is cheaper than a footnote per row that would go stale the same
way. Board item #92 is the scheduled full sweep.

| # | Milestone | Size | Exit clauses demonstrated | Status: weakest mark | The short reason |
|---|---|---|---|---|---|
| **M0** | Foundations | `S` | **8 of 8** | **CRITERION MET**: `DEMONSTRATED` | **The last two clauses closed on 2026-08-27, and both had been `VACUOUS` for reasons that expired without anyone noticing** (§0: *"true today, and true for a reason that will stop being true"*). Clause 4a needed a command that touches `doc.templates`; M4-S landed one, and `command_roundtrip_test.dart` now draws `SaveTemplateToProjectCommand` **717 times across its 1000 sequences** (`8af36ed`, `#513`). Clause 5 needed a derived pipeline to snapshot; three exist, and `epoch_mask_test.dart` now folds them into the same changed-key set, moving on **9 of 35 command cases** and guarded by a source-reading field count so the projection cannot fall behind (`38167ec`, `#507`). Both figures are measured rather than asserted, because §5.1's `#587` records an arm offered thousands of times that fired zero |
| **M1** | Elevation release | `L` | **8 of 8** | **CRITERION MET**: `CONFIRMED` | All eight clauses discharged. Two by a person, not a gate: the tape measure on 2026-07-27, the keyboard-only drill on 2026-07-28 at **under three minutes** against a four-minute criterion. The drill's re-run **failed first**, the palette filter could not be edited and the caret was drawn below the canvas, neither of which any remedy had named and neither of which 2206 tests could see (§3.5), then passed against `616a301`. The three-minute figure is a 140+ wpm operator who knew the keymap; §3.2 records that condition because M7's accessibility criterion rests on this clause. The goal line's *"ships to real users"* is **not** met |
| **M2** | Wiring + live schedule | `M` | **5 of 5** | **CRITERION MET**: `CONFIRMED` | All five clauses discharged. Four by tests; one by a person, not a gate, **the user made sixty connections on 2026-08-01, in roughly 5–7 minutes, without multi-draw, which is still unbuilt (#93)**. The clause carries no time bound, so that figure is a data point rather than a threshold met. M2-G then found the half of clause 4 nobody had measured: the sheet took **64 ms to paint** beside a 3 ms build, and is 10.6 ms now (§5.1). The goal line is met; the roadmap's global *"ends green"* rule is **not**, for the same reason it is not for any milestone, no CI service has ever run (§4.1) |
| **M3** | Structure + field | `M` | **4 of 5**, the fifth parked | **CRITERION MET**: `CONFIRMED` | **The header of §5.2 read `NOT STARTED` until 2026-08-27, and DR-095 §11.94.8 exists because a ruling was written on that staleness.** DR-040 (§11.39) and M3-K (`#661`, four tasks Done, 2026-08-11) built clauses 2b and 4: `BindEndpoint`, `@panel=` landing forty-six drops on a panel's rear port, and the rack label allocated through the one format engine. Clause 3's derivation ships and its **sheet is M6's** by DR-027, which is the parked one, `#574`. **Clause 1 is `CONFIRMED`**: the 60-drop drill, closed on the operator's confirmation 2026-08-27 (`#89`, `#163`–`#165`). Run 1 on 2026-08-13 is kept at §4.1 of docs/16 as `UNVERIFIABLE` because the app was closed without saving, and the procedure, not the operator, is what failed |
| **M4** | Device builder | **`L`** *(was `M`)* | **2 of 2** | **CRITERION MET**: `CONFIRMED` | **The builder authors a device.** M4-A through M4-E (`#172`–`#176`) are closed: `Project ▸ New device template…` gives a full-window editor with five sections, real undo, a Save that lands a snapshot in the project, and a virtualised port grid with editable columns, seven column packs, live validation dots and a footer readout (§5.3.1–5.3.5). **THE EXIT CRITERION'S SHAPE IS DEMONSTRATED**: M4-G and M4-H (`#178`, `#179`) add a docked Quick Add bar whose mini-DSL and label patterns author whole banks from one typed line, and a test types docs/06 §9.1's eight commands to get **68 ports across 6 banks with focus never leaving the bar** (§5.3.6). **M4-G is feature-complete**, field mode and inline autocomplete included, so the DSL teaches itself. **CLAUSE 1 IS CONFIRMED: the user ran the drill on 2026-08-15 and authored the 68-port template, named and saved, IN 93 SECONDS against a 180-second criterion** (§5.3.7). The drill found `Ctrl+Enter` missing on its first run, which fourteen green gates could not. **CLAUSE 2 IS NOW CONFIRMED, performed on 2026-09-01** (§5.3.30), and it was performable only from §5.3.13: it could not be, for four days, because a template authored in the builder saved into the project and **no surface offered it for placement** (§5.3.8). M4-S (`#701`, DR-077) makes the palette list the DOCUMENT's own shelf, forks a version on a second `Save`, and resolves the newest version at placement; the equipment-list half is read through `File ▸ Export PDF…`, which is the criterion's own reading rather than a missing view. `#251` demonstrated it: every unknown column printed `—` and said so, which is G4/CR-114 read off a printed sheet for the first time. **The archetype path ran the same day at 46 SECONDS against the DSL path's 93** (`#250`), which is what settled whether the generators earned their place. **EVERY M4 STORY IS NOW CLOSED** (§5.3.1–§5.3.30), the last being the drill itself (`#188`), and **95 chapters are Done under this epic with none left open or re-parented**, which is where `v0.4.95` comes from. **M4-P shipped RJ-012's two extensibility surfaces and found each chapter to be something else underneath**: the builder could not save a field device at all, the media-type editor's real gap was MERGE rather than create, and connector aliases were already resolved and only lacked a writer (§5.3.28, DR-107, `v0.4.93`). **RJ-012 stays two-thirds met**: its third surface, a per-family colour override row in settings, has nowhere to go because `ProjectSettings` has no editor and none is assigned to any milestone (`#805`). **M4-K made the rear panel a derived drawing and gave the builder its right dock**, three previews all coming from the scene builders that print rather than from preview widgets (§5.3.26, DR-105, CR-086, `v0.4.89`); **its parked nudge canvas was then un-parked by DR-106 and built** as a sixth `Panel` section, with its align/distribute arithmetic in core (§5.3.27, `v0.4.90`). **M4-O made the Device Manager tab a real browser** and found, while doing it, that the `Project ▸ New device template…` menu item DR-104 assumed existed does not (§5.3.25, DR-104, `v0.4.86`). **M4-L gave three modelled-since-M0 fields their first producer** (`DeviceOverrides`, `derivedFrom`, `PortOverrides`, §5.3.22), **M4-M made `.rmdx` a real format with both file verbs, a real `contentHash` and a size cap on every import path** (§5.3.23, DR-100, DR-101, `v0.4.78`), and **M4-N built the whole library subsystem: the writable shelf, the `.rmda` archive, both file verbs, provenance as a sealed class and a palette that lists several libraries at once and can place from them** (§5.3.24, DR-102, DR-103, `v0.4.83`). **None of the three moved this criterion**, and that was the point of the row for a fortnight: story after story closed while clause 2 remained a person with a document to read. **It was read on 2026-09-01** (§5.3.30), which is the only thing that could ever have closed it. **Decomposed on 2026-08-02 into 17 issues and 63 tasks (#172–#251)**, which re-sized it: DR-015's library subsystem was never in the `M` |
| **M5** | Validation | `M` | **3 of 3** | **CRITERION MET**: `CONFIRMED` | **CLOSED 2026-09-07 (DR-135 §11.134).** All three clauses discharged. Clause 1 is `DEMONSTRATED` at **29 of 29** by `drc_corpus_test.dart`, which `run_local.ps1` runs as a step of its own and whose subject is `kRuleCatalogue` rather than any evaluator enum, so a registered rule without a pair fails the build; that is also why it moved from 28 to 29 when DR-132 restored `ELE-005` and no gate had to change (§5.4.7). Clause 3 was `VACUOUS` *because no rule existed* and that reason expired; it is `DEMONSTRATED` in a stronger form than `#310` asked for, since `ExportError` is **sealed with three arms and none of them is about a rule** (§5.4.8, DR-119). **Clause 2 was the whole gap for a fortnight and is `CONFIRMED` on 2026-09-06** (§5.4.11), signed by the reviewing integrator against a pack generated from the live catalogue: **twelve findings, four rulings, six fields the model has and no producer writes**, and the catalog half signed PROVISIONAL on the reviewer's own hedge. **All twenty Stories under epic 23 are `Done` and 61 Chapters beneath them**, which is where `v0.5.61` comes from and why the close itself owes no bump. The successor is **the Plan view, not M6** (DR-029 §11.28.4) |
| **Plan view** | *an epic, no number* | **`L`** | **4 of 7**, 1 parked | **IN PROGRESS**: `UNPERFORMED` | **RE-MARKED 2026-09-24 AT `#943`; IT READ `0 of 7`, `NOT BUILT` UNTIL THEN.** Four clauses are `DEMONSTRATED` by named tests (§5.9's table), one stays parked on M6 by DR-155, and the two that remain are physical acts, a real rough-in pinned by a person and a greyscale laser print, which is `PLAN-J`'s drill (`#606`) and no agent can perform. The weakest mark is `UNPERFORMED`, which is a person and an afternoon rather than a feature. The history this row carried is kept below; where it says a clause has not moved, it is describing the epic before `PLAN-K`. **OPENED 2026-09-07 over a closed M5 (DR-135 §11.134), which is §8.9's condition met rather than assumed.** Added to v1 by DR-029 on 2026-08-09 and **sequenced before M6**. `SheetRole` has 3 values, `DocumentCodec` has one implementation and `looksLikeZip` still refuses; **`DiagramCanvas` gained its `drawImage` at PLAN-A** (§5.9.1), which is the root every other issue consumes and which moves **no clause**, because the criterion is about a printed `T1.01` that nothing yet builds. **Not one of the seven clauses has moved**, and opening an epic discharges nothing. **Decomposed 2026-08-10** into 10 issues and 43 chapters, exit criterion at DR-037 §11.36.1 (§5.9). **This epic takes the `0.6` band** (DR-135 §11.134.4); the version was `v0.6.0` at open. **THE COUNT IS NOT WRITTEN HERE**, on this file's own rule about a second copy of a moving number: it read *"`v0.6.21` with twenty-one chapters `Done` of 43"* through six chapter closes, and the fix is to read `az boards query` for Chapters under this epic's stories rather than a sentence. The chapter total is no longer 43 either, since `PLAN-F/0` was added by a defect. **PLAN-A through PLAN-E are closed**, and `PLAN-F` is open. The plan set answered `PLAN-D/5` (§5.9.5) and then refused `PLAN-D/1`'s rasteriser, so `PLAN-D/3` ships a pure-Dart page lifter and the picker instead, with pdfium deferred rather than cancelled (§5.9.6). `PLAN-E` closed on six chapters rather than five (§5.9.7 to §5.9.12), and `PLAN-F/1` gave `PlanScale` the writer it had lacked since `PLAN-C` (§5.9.14). **`PLAN-F` IS CLOSED** on `PLAN-F/3` (§5.9.17), which found a count with no reader one chapter after the census that should have caught it and a property that passed only because every fixture in the package defaults to the interesting state; roadmap §2's calibration bullet closes with it and **no exit clause moves** |
| **M6** | Full sheet set | `M` | **0 of 5** | **NOT STARTED**, `NOT BUILT` | **4 of 12 sheet slots ship** and are real work, but the criterion is *all four starters export a complete set*, and no clause of it is demonstrated (§5.5). **This read `3 of 12` until 2026-09-23** and had been wrong since `PLAN-H/1` landed `T1.01` on 2026-09-09: the slot was built, the row's count was not touched, and `sheet_def.dart`'s own header said *"exactly three sheet ROLES"* beside an enum with four. Found while writing docs/21, which is the first document in this corpus aimed at somebody who cannot read the enum. **The set became 12 slots at DR-048**, which moved `T6.50` Network/IP Schedule into v1, and **becomes 13** when `T1.01` lands ahead of it |
| **M7** | Platform + access | `M` | **0 of 4** | **NOT STARTED**: `NOT BUILT` | Windows-only; no `Intent` registry; no l10n at all |
| **M8** | Release engineering | `S` | **0 of 4** | **NOT STARTED**: `NOT BUILT` | No installer, no signing, no crash reporter. **Re-scoped by DR-006** |
| **M9** | Beta hardening | `M` | **0 of 1** | **NOT STARTED**: `UNPERFORMED` | Nothing is installable, so nothing is testable by anyone outside this machine |

**Every epic on the board is now decomposed to task level: 2026-08-03.** 12 epics, **141 issues,
354 tasks**, no orphans. M3 and M4 were already decomposed; M5–M9 gained a work layer beside the
exit-clause rows they already had; M0, M1 and M2 gained a **retrospective** layer, and every row in
it says so in its own description, because a task reconstructed after the fact that looks
contemporaneous is a costume rather than a record. Roadmap §8.8, a closed task names the commit
that closed it, is **forward-only from this date** by explicit decision; nothing was backfilled.

**Read the far milestones' decompositions with the right expectation, and this is the honest caveat
on the whole exercise.** Decomposition normally happens at a milestone's start (§5's practice, and
board `#71`), and it earns its keep by being read against the tree as it actually is: M4's
decomposition found that `Command` is hard-typed to `RackDocument`, that `ConnectorTypeDef.pitch`
does not exist, and that `derivedFrom` appears nowhere, none of which is inferable from the
specification. **M5's and M6's decompositions are grounded in the same way** (the 28-rule catalogue
and the sheet table are both real, present artifacts). **M8's and M9's are substantially spec
restatement**, because the tree they will run against does not exist yet. Re-read them before
starting rather than trusting them; that is what the `Mn-0` rows now say.

**Three things the sweep found, none of them decomposition:**

- **macOS debt `D14` had no board item at all**, and it is the one row in docs/13 that **is not
  about macOS**: docs/08:509 requires a non-US platform locale to substitute A4/A3, `SheetSize`
  has exactly two values and neither is A4, so **a Windows machine in a metric locale has the
  problem today**. Now `#453`, and sequenced with M6 where page setup is actually built, rather
  than with the macOS work where it would be found late because it is filed under the wrong heading.
- **`D13`'s register text is stale in one detail**: it says the dialog filter is hard-coded to
  `.rackpal`; DR-015 made that `*.rmpj;*.rackpal` at `dc22ddc`. The hard-coding is unchanged, only
  the strings moved. The work itself is M4's (`#234`), so `#453`'s sibling row just points there.
- **`D7` is closed on the board**, matching docs/13 §2.2, the debt cleared and its owed gate was
  paid at `#94` on 2026-08-02. The board had still read `To Do`.

**One drift this file should not paper over:** M0's and M1's exit-clause rows still read `To Do` on
the board while §3 of this file records **M1 as `CRITERION MET`, all eight clauses discharged**. The
board was not mass-updated to match, because M0 carries two clauses that are true only `VACUOUS`ly
(§2.2) and M1's goal line, *"and it ships to real users"*, is genuinely not met. **Those are
judgements this file already makes carefully, and a bulk state change would have flattened them into
a tick.** The rows are wrong in the direction of understatement, which is the safe direction, but
they are wrong.

**The global rule the roadmap sets for every milestone** (§4, verbatim):

> **Every milestone ends green**: CI passes, goldens pass, the app opens the four starter projects.
> A milestone that ends with a known-broken build has not ended.

Of its three limbs, exactly one is satisfiable today. **The app opens the four starter projects**:
`apps/rackpal/test/starters/starter_assets_test.dart` opens each of
`apps/rackpal/assets/starters/*.rackpal` through the real `DocumentStore`/`DartIoFileStore` path
and asserts `Ok`, not read-only, no migration on open, 48 templates. **CI passes** is still
unsatisfiable: a pipeline *definition* now exists and no service has ever executed it (§4.1).
**Goldens pass** is vacuous: there are no goldens (§4.3). So the roadmap's
own per-milestone green rule **has never been satisfiable for any milestone, including M0**. That
is the single most consequential finding on this board and it is the subject of §4.

---

## 2. M0, Foundations · `S` · **CRITERION MET**, weakest mark `DEMONSTRATED` *(was `PARTIAL`/`VACUOUS` until 2026-08-27)*

### 2.1 The exit criterion, verbatim (roadmap §4, M0)

> `dart test` green in `rackmate_core` with: the 1/32-inch clearance test and the 45U-accumulation
> test passing exactly (CR-001); `write(read(bytes)) == bytes` on three fixtures (CR-117, AC-016
> #24); the command round-trip property test (`apply; revert` leaves the JSON byte-identical,
> including `templates.keys` — AC-015) passing on 1,000 generated command sequences; the epoch-mask
> coverage test passing for every command type; one v0→v1 migration fixture in the golden corpus.
> `rackmate_core` has zero Flutter imports, enforced by a test that fails the build.

### 2.2 Clause by clause

| # | Clause | Mark | Evidence |
|---|---|---|---|
| 1 | `dart test` green in `rackpal_core` | **DEMONSTRATED** | Run this session: **886 passing, 0 failing** |
| 2 | 1/32-inch clearance exact, 45U accumulation exact (CR-001) | **DEMONSTRATED** | `packages/rackpal_core/test/units_test.dart:6` "1/32 inch inter-panel clearance is exact" and `:15` "zero accumulated error across a 45U rack stack", exact integer nanometre arithmetic, no tolerance |
| 3 | `write(read(bytes)) == bytes` on **three** fixtures | **DEMONSTRATED: exceeded** | `packages/rackpal_core/test/byte_roundtrip_test.dart` writes and re-reads **four** real files under `packages/rackpal_core/test/fixtures/`: `a_empty_project`, `b_rack_and_device`, `c_fuller_project`, `d_templates_and_power` |
| 4 | Command round-trip on 1,000 generated sequences | **DEMONSTRATED** | `packages/rackpal_core/test/command_roundtrip_test.dart:35` `_sequenceCount = 1000`, seeded `Random(20260718 + i)`, byte identity of real `JsonDocumentCodec` output asserted after `apply;revert` **at every step**. The run log shows 1000 discrete cases |
| 4a | *…"including `templates.keys`: AC-015"* | **DEMONSTRATED** *(was `VACUOUS`)* | `command_roundtrip_test.dart` gained a `saveTemplateToProject` arm on 2026-08-27 (`8af36ed`). Its first draft **failed**, on seed `20260724` step 2, with `"templates"` returning `{}` where a snapshot had been: the generator drew a version from a literal range and broke `SaveTemplateToProjectCommand`'s documented precondition, which is that `nextTemplateVersion` guarantees the key is free. The command was right; the arm now calls that function as the one production caller does |
| 5 | Epoch-mask coverage for **every command type** | **DEMONSTRATED** *(was `VACUOUS`)* | The **command-type** limb was always covered; the **epoch-mask** limb is covered as of `38167ec`. `epoch_mask_test.dart` now snapshots `buildEquipmentList` and `computeRackRollups` alongside the persisted maps, under a `derived:` prefix, so all twenty-odd per-command tests gained derived coverage with no call-site change. `device_loads` rides in through `EquipmentRow.loads`, which resolves it per device. §4.5 row 5 is paid |
| 6 | One v0→v1 migration fixture in the golden corpus | **DEMONSTRATED: exceeded** | `packages/rackpal_core/test/migration_corpus_test.dart` covers v0→v1 synthetically **and** a real v1→v2 file fixture, `packages/rackpal_core/test/fixtures/v1_templates_and_power.rackpal.json` |
| 7 | Zero Flutter imports, enforced by a test that fails the build | **DEMONSTRATED** | `packages/rackpal_core/test/no_flutter_import_test.dart` scans whole import/export directives (not a naive prefix match) and carries a **vacuity guard** counting files scanned, the guard is the thing that makes it a real gate rather than a test that passes on an empty glob |

**Package layout** matches CR-083's five-member list exactly: `pubspec.yaml`'s workspace at
`:7-12` lists `rackpal_core`, `rackpal_text`, `rackpal_export`, `rackpal_ui`, `apps/rackpal`.
**The demonstration of the six discharged clauses is recorded in the closing commit** per roadmap
§8.1: `b94bd60`, *"feat(core): implement rackpal_core through M0's command/undo system"*.

### 2.3 Why M0 WAS `PARTIAL`, and what the unbuilt checklist had to do with it: nothing

The M0 **checklist**'s last line, *"CI: analyze, test, goldens, format, the no-Flutter-import
test, the epoch-mask coverage test"*, is **entirely unbuilt**. There is no `.github` directory
(`ls -a` at the repo root; a maxdepth-3 search for `yml`/`yaml` returns only six pubspecs, the
workspace root and its five members, plus `analysis_options.yaml` and `dart_test.yaml`).

Roadmap §8.1 is explicit that *"a milestone is not 'done' when the checklist is ticked; it is done
when its exit criterion has been demonstrated"*, and the exit criterion above does not name CI. **So
the missing CI is not what unseats M0.** What unseats M0 is inside the criterion: two of its own
conjuncts, `templates.keys` (AC-015) and the epoch-mask letter (AC-014), are `VACUOUS`, and §0's
rule is that a milestone's status is the weakest mark across its exit clauses.

**An earlier draft of this file marked M0 `COMPLETE — DEMONSTRATED` and argued here that the two
vacuous clauses "neither unseats the criterion". That argument is withdrawn.** It is recorded
rather than deleted because it is the exact failure mode the table at the top of this document
catalogues. The same `VACUOUS` mark unseats M5's clause 3 (§5.4) and the roadmap's global
*"goldens pass"* limb, which §4.3 calls *"vacuous for every milestone to date"*, an exemption
granted to one milestone and to no other is a preference, not a finding. M0's six discharged
clauses are still discharged and the work behind them is still good; `b94bd60` still records their
demonstration. What changed is the headline, which is the only thing a reader skimming §1 sees.

Separately and unchanged: **no gate in this project is mechanical**, and that is a project-level
fact, not an M0 footnote. See §4.1.

### 2.4 What closed the two vacuous clauses, 2026-08-27

**Neither was closed by an argument, and that distinction is the whole of §2.3.** The withdrawn
draft recorded there tried to reason the two clauses away; what discharged them was a command that
touches the map and a pipeline to snapshot, neither of which existed when that argument was made.

- **AC-015 / `templates.keys`**: wanted *"a command that touches `doc.templates`… the clause becomes
  real the day M4 or M1's copy-on-place lands, and not before."* **M4-S landed
  `SaveTemplateToProjectCommand`**, and `8af36ed` (`#513`) put it in the fuzz. AC-015's template
  refcounting is still deferred and this does not speak to it: what is covered is the narrower thing
  the M0 criterion names, that a command touching `templates` leaves the map byte-identical across
  apply-revert.
- **Epoch-mask letter (AC-014)**: wanted `epoch_mask_test.dart` extended to the derived outputs, and
  called it *"cheap today and more expensive with every derived consumer added."* Paid at `38167ec`
  (`#507`), and the estimate held: the derived half folds into the existing changed-key set, so
  twenty-odd tests gained coverage without a call-site change. §4.5 row 5 is closed by the same
  commit.

**Both were surfaced by DR-095, not by anyone reading this section.** §8.9 forced a worklist across
every milestone before the current one, and these two are what it found in M0. A clause whose
`VACUOUS` reason has expired reads exactly like one whose reason still holds, which is the argument
for a gate rather than a habit.

---

## 3. M1, The elevation release · `L` · CRITERION MET, weakest mark `CONFIRMED`

The sole `L`, and the critical path's centre of gravity (canon §11.1.5). **All eight exit clauses
are now discharged.** Two of them by a person rather than by a gate: clause 5 (the physical tape
measure) on 2026-07-27, and clause 3 (the keyboard-only drill) on 2026-07-28. The goal line's
*"and it ships to real users"* is a separate promise and is **not** met, see §3.4.

**Two clauses were closed by acts no agent can perform, and both are recorded with their human
provenance in §3.2, because a human check is not a CI gate.** Neither is re-run by CI; neither
survives a change to the subsystem under it. That is the price of a criterion that asks about
paper and about wall-clock time, and it is stated rather than hidden.

**The path clause 3 took is the most instructive thing in this document.** It went
`NOT BUILT` → `REFUTED` → (remedy built, mark deliberately unchanged) → **the re-run found the
path still impossible for two reasons the remedy had never named** → fixed → `CONFIRMED`. The
discipline that kept it at `REFUTED` while its named remedy was already written is what made that
second failure visible instead of assumed away. Had building the remedy been allowed to discharge
the clause, M1 would have been marked complete over a build whose device palette could not be
used at all. §3.5 records what was actually wrong.

### 3.1 The exit criterion, verbatim (roadmap §4, M1)

> A user opens the app, creates a 42U rack, populates it with 20 devices in under four minutes
> **using only the keyboard**, and exports a three-sheet PDF whose elevations are dimensionally
> correct against a physical tape measure at true scale and whose equipment list matches the rack
> contents exactly. The baseline-y parity test passes within 0.5% on a kerning-heavy string. Undo
> restores every operation in that sequence.

Its **goal** line carries a clause the criterion does not: *"The smallest genuinely useful release,
**and it ships to real users.**"*

### 3.2 Clause by clause

| # | Clause | Mark | Evidence / what is missing |
|---|---|---|---|
| 1 | A user opens the app | **DEMONSTRATED** | `flutter build windows --release` exit 0, `√ Built build\windows\x64\runner\Release\rackpal.exe`; `apps/rackpal/test/starters/starter_assets_test.dart` opens all four starters through the real store |
| 2 | **…creates a 42U rack** | **DEMONSTRATED** | `AddRackCommand` and docs/04 §9's three-field dialog now exist, and the whole path is driven against the real screen: `packages/rackpal_ui/test/canvas/rack_creation_test.dart` presses `Ctrl+Alt+N`, types a name, commits with `Enter`, and asserts the header reads `RK-2` / `42U`, no pointer after the initial focus click. `packages/rackpal_core/test/rack_commands_test.dart` covers the command (designator allocation, order, preset-vs-typed height, undo/redo, byte round trip). **This is the CAPABILITY, not the drill.** The row it discharges is "creates a 42U rack"; the wall-clock, keyboard-only sequence is clause 3, which is **CONFIRMED** as of 2026-07-28, see there. *Was* **NOT BUILT**, on the grep for `AddRack`/`addRack`/`createRack` returning nothing; that grep now returns `packages/rackpal_core/lib/src/commands/rack_commands.dart:59`. `apps/rackpal/lib/src/session/blank_document.dart` still seeds `kBlankProjectRackHeightU = 42` for `Ctrl+N`, and `apps/rackpal/test/session/blank_document_test.dart` now pins that seeded rack field-for-field against what the dialog builds |
| 3 | 20 devices **in under four minutes, keyboard only** | **CONFIRMED**: by the user, 2026-07-28 | **Performed and passed on 2026-07-28: under three minutes, keyboard only**, against the build carrying `616a301`. A ~25% margin under the criterion, and both halves, the speed and the keyboard-only constraint, now measured in the SAME run, which the 2026-07-27 attempt never managed. **THE OPERATOR'S CONDITIONS ARE PART OF THE MEASUREMENT AND ARE RECORDED RATHER THAN DROPPED:** the user types 140+ wpm and had already learned most of the shortcut names. That is a fast, trained operator, and it is volunteered here because the number means something different without it. The clause says "a user" and is satisfied literally, this reading is not a hedge on the mark. But **it does not establish the time for a first-run or a slower-typing operator**, and clause 3 is load-bearing for M7's accessibility criterion, where exactly that population is the subject. A run by someone who has not memorised the keymap is worth having before M7 leans on this number; see §3.4. **A CONFIRMED mark is not a gate**: no CI job re-runs this, and it does not survive a change to the keymap; the regression net named below is what guards the mechanism between drills., *Previous mark, kept because REFUTED records a measured fact and deleting it would erase why any of the remedy exists:* **the user timed it on 2026-07-27: under four minutes, but with mouse and keyboard combined, and reported no full keyboard path exists.** So the *speed* half is demonstrated and the *keyboard-only* half is refused, which matters, because the constraint is the point: it is what makes the tool faster than Visio for a populated rack, and it is load-bearing for M7's accessibility criterion. **The named fix has since been built, and building it does not discharge the clause.** REFUTED means the act was performed and failed; only the act being performed again can move it, and no agent can perform it. What landed: `Esc` now clears the selection (docs/04 §8's third limb, `rack_canvas_screen.dart`'s `_onEscape`); a quick-add that the loop itself is repeating keeps caret-targeting live (`_selectionIsLastQuickAdd`); a cycle whose caret lands on an occupied U falls back to lowest-free-U *and says so* rather than jamming; and a refused cycle hands focus back to the canvas instead of stranding it on the modal scope. The regression net is `packages/rackpal_ui/test/canvas/keyboard_only_placement_test.dart` (11 cases, each written to fail if one half of the fix is removed) and `rack_creation_test.dart`'s twenty-device drill, which drives the caret to U5 first so the caret path and the lowest-free-U fallback give different answers. The earlier citation in this row (`rack_canvas_screen.dart:2216-2229` for a gap the code documented *against itself*) is **dead**: that comment was replaced by the fix and no line range holds it any more. The user also reports the interface "feels quite good already though may need a bit of optimization". **THE FIRST ATTEMPT TO RE-RUN THE DRILL FOUND THE PATH STILL IMPOSSIBLE, FOR REASONS NOTHING ABOVE PREDICTED**: see §3.5. Neither of the two blockers was in the remedy list this row had been carrying, and both had been shipped since M1's earliest days; the drill could not have passed on any build before `616a301` |
| 4 | Exports a **three-sheet** PDF | **DEMONSTRATED** | `packages/rackpal_core/lib/src/draw/sheet/sheet_def.dart` declares exactly `SheetRole.rackElevationFront` / `rackElevationRear` / `equipmentList`, and its header names the 2N+1 trap; `packages/rackpal_export/test/scale_notice_test.dart:141` `expect(out.sheetCount, 3)` |
| 5 | Elevations dimensionally correct **against a physical tape measure** at true scale | **CONFIRMED**: by the user, 2026-07-27 | The one clause of this criterion that no test could discharge, because it asks about *paper*. Verified by the user against a printed sheet this session and reported correct. The in-repo evidence remains `packages/rackpal_export/test/elevation_true_scale_test.dart`, which composes real `q`/`Q`/`cm` into PDF user space, derives every expectation from the literals `44_450_000` / `25_400_000` / `72.0` / `482_600_000` / `450_850_000`, regexes the ratio *n* back out of the sheet's own `SCALE` field, and takes its 0.01 pt tolerance from `PdfNum.precision = 5` rather than tuning it, but that test is titled, in `docs/m1-implementation-log.md:1434`, *"how dimensionally correct against a tape measure is proved **without a printer**"*, and the print chain (driver scaling, fit-to-page, media stretch) is exactly what it cannot reach. **Provenance is a human check, not a gate**: it is not re-run by CI and does not survive a change to the fit engine. AC-058 D13's full print matrix (ANSI B laser, ANSI D plotter, photocopy) is still scheduled at M6 and has not run |
| 6 | Equipment list matches rack contents **exactly** | **DEMONSTRATED** | `packages/rackpal_export/test/starters_export_test.dart` asserts a **bijection in both directions** over all four real starter files: designator multiset equality against the document, **plus** every designator recovered as actual text from a `T6.30` content stream |
| 7 | Baseline-y parity within 0.5% on a kerning-heavy string | **DEMONSTRATED** | `apps/rackpal/test/baseline_parity_test.dart`, fixture `AV Wa To Ty`, `tol = 0.005 * m.lineHeight` at line 208. Both backends' baselines are recovered **independently from real output**: PDF `cm`/`Td` operators out of the emitted stream; Flutter's recorded translate + `paintOffset` + `paragraph.alphabeticBaseline`, and it additionally pins Skia's line width to `PdfFont.stringMetrics` within 1%. This is `RISK-01`'s stop-the-line gate and it is genuinely green |
| 8 | Undo restores every operation in that sequence | **DEMONSTRATED** | `command_roundtrip_test.dart` at the core level, plus UI-level coverage in `packages/rackpal_ui/test/canvas/{rack_canvas_screen,rack_compaction,rack_resize_drag}_test.dart` and `test/inspector/{rack_inspector_panel,shrink_rack_dialog}_test.dart`, including *"Preset and Apply lands the preset AND the resize AND every displacement as ONE undo entry"* |
| — | *Goal clause, not an exit clause:* **"and it ships to real users"** | **NOT BUILT** | No installer, no signing, no release artefact of any kind. See M8 and DR-006. §1 counts M1's exit clauses as eight, and this goal line is not one of them; board `#66` sits under M8 by DR-097, although its description still reads *"EXIT CLAUSE of M1"* |

The exporter demonstration is recorded in the closing commit `0fa532d`.

### 3.3 Unbuilt M1 checklist items

Not exit clauses, but every one is scope that a later milestone now inherits.

| Item | State | Citation | Who inherits it |
|---|---|---|---|
| **The outline tree** | **NOT BUILT** | No outline-tree surface anywhere in `lib/`: grep for `TreeView` and `Ctrl+Alt+3` across `packages/*/lib` and `apps/*/lib` returns nothing, and every `outline` hit is a drawing term (`packages/rackpal_core/lib/src/draw/scene/rack_style.dart:45`, `:51`, `:70`, enclosure, rail and device-body outlines) | **M7.** Roadmap §4 M7 *Risks* names "the outline tree shipping in M1" as its mitigation, and docs/04:455 names it as the primary AT surface. Retrofitting canvas accessibility late is precisely the structural risk that line warns about |
| **The Staging Bin** | Model-only | `packages/rackpal_ui/lib/src/canvas/staging_bin_overlay.dart:107` renders the honest text *"Staging Bin, not in this build"*; `rack_canvas_screen.dart:2981` states no command produces a `StagedPlacement` | M1 tail |
| **Shelves with auto-pack** | **NOT BUILT** | No `ShelfPlacement` handling in any UI file; `rack_shrink.dart:276`, *"DEVICES ON A SHELF ARE DELIBERATELY ABSENT"* | M1 tail |
| **0U occupants from the inspector** | **NOT BUILT** | No editing path | M1 tail |
| **Locks** | **BUILT** at `#913`, DR-186 §11.185, 2026-09-18 | Was *"half-built: honoured as immovable anchors by the compaction planner; no `Ctrl+L`, no way to set `Placement.locked`"*, which stood for the whole of M1 to M5. `Ctrl+L`, a `Locked` checkbox and a padlock badge now set it, and a locked device refuses a drag, a nudge, a width change and a bottom-trimmed shrink. The schematic's half of the same key, `SheetItem.pinned`, lands with it | closed |
| **Copy-on-place with `DeviceOverrides`** | **NOT BUILT** | Nothing writes one; `inspector_panel.dart:21` defers device-property editing | **M4** will hit this on day one |
| **`sources.md` provenance as a gate** | Prose, not a gate | `assets/catalog/sources.md` exists (166 lines) and the catalog is real (48 templates = 30 rack-side + 18 field, `packages/rackpal_core/test/catalog/seed_catalog_test.dart:19` and `:40`). But **no test anywhere names the file**: `grep -rn "sources\.md"` across all four test trees returns **nothing at all**. Its only references in the repository are three orienting `lib/` comments, `catalog_connectors.dart:15`, `rack_presets.dart:21`, `seed_catalog.dart:6`. Nothing parses the file; nothing cross-references a numeric field to a citation | §4.4 |
| **The connector-footprint CI assertion** | Real test, no CI | `seed_catalog_test.dart:281`, with `:303` and `:316` proving the exempt set is both truly footprint-free and actually reachable. It is a **CI assertion with no CI** | §4.1 |

### 3.4 What would finish M1

In the order that makes each cheaper than the next:

1. ~~**An `AddRackCommand` and the New-rack dialog**~~, **BUILT.** `packages/rackpal_core/lib/src/commands/rack_commands.dart` and
   `packages/rackpal_ui/lib/src/inspector/new_rack_dialog.dart`, reached by `Ctrl+Alt+N`, by the
   rack header's overflow menu, and by the rack-less panel's own button. **Deleting** a rack is
   still not possible, deliberately: a removal has to answer what happens to the rack's occupants
   and docs/04 settles nothing about it (rack_commands.dart's header states the choice). Multi-rack
   *layout* is still unbuilt, the canvas edits one rack at a time and switches between them.
2. ~~**RUN AND TIME THE 20-DEVICE DRILL AGAIN.**~~, **DONE, 2026-07-28, by the user.** Clause 3
   is `CONFIRMED`. It took two attempts and the first one failed for reasons this list had never
   named (§3.5). The sentence this item used to end on is worth keeping because it was right
   twice over: **a criterion nobody has stopwatch-tested is a criterion nobody has met**, and
   tests passing is not a person with a stopwatch. On 2026-07-28 the whole suite was green while
   the palette filter could not be edited at all. **Measured: under three minutes, keyboard only.**
3. **Print one sheet and put a tape on it.** Ten minutes of physical work gating the claim the
   whole M1 story rests on. The emitted-byte test is excellent and is *not* the clause.
   *(Performed by the user on 2026-07-27, see §3.2 clause 5, which is CONFIRMED. Kept here as the
   shape of the work, because AC-058 D13's full print matrix is still M6 and has not run.)*
4. **The outline tree**, because it is M7's named mitigation and it is cheaper now. With clauses 3
   and 5 both closed, this and *"ships to real users"* are what is actually left of M1; neither
   is an exit clause, and neither gates M2 or M4.
5. **Re-run the drill with an operator who has NOT memorised the keymap.** Not an M1 clause, M1 is
   met, and deliberately not written as one. The 2026-07-28 figure was set by a 140+ wpm typist
   who already knew the shortcut names, which is the best case and is recorded as such in §3.2.
   **M7's accessibility criterion is where that distinction stops being cosmetic**, because its
   subject is precisely the operator who does not know the keymap and may not be typing at all.
   Doing this before M7 costs one afternoon; discovering it inside M7 costs a redesign of the
   keyboard path. It is cheap now for the same reason the outline tree is.

### 3.5 What the drill's first re-run actually found

Recorded at length because the board's marks are only worth what the evidence behind them is
worth, and this is the clearest measurement anyone has of the gap between "the suite is green"
and "the thing works". Both defects predate every remedy clause 3 had been carrying. Both were
found by a person opening the app, not by any of 2206 passing tests. Fixed in `616a301`.

**1. Every text field on the rack screen had its editing keys stolen.** `RackCanvasScreen` mounts
its `Shortcuts` above the whole palette + canvas + inspector `Row`, so the palette filter and the
five `RackInspector` fields are *descendants* of it, while `DefaultTextEditingShortcuts` (the
only thing in Flutter that turns `Backspace` into a character delete) is installed by
`WidgetsApp` at the *root*. Key events dispatch **leaf → root**, so the canvas keymap was
consulted first and text editing last. Eleven keys: `Backspace`, `Delete`, `↑`, `↓`, `Home`,
`End`, `PgUp`, `PgDn`, `Esc`, `/`, `Ctrl+Z`. A mistyped filter could not be corrected or cleared,
which made the palette unusable for the rest of the session, and the drill's inner loop is
`/ query ⏎`, so the drill was not merely slow, it was **impossible**. Worse and unreported:
with a device selected, that same `Backspace` ran a real `RemoveDeviceCommand`.

This was live from `5a2a2b6` (2026-07-18), which added the search field to a tree where `6bc5be0`
had already bound `Backspace`, nine days, spanning every M1 assessment in this document.

**2. The insertion caret was drawn below the visible canvas.** `ViewportController` opens at
`Matrix4.identity()` and nothing seeded it. Rack scene space is bottom-origin
(`yBottomOfU(1) == rackHeight`), so on the default 42U Blank project the caret sits at scene
y = 924 against a canvas around 870 px tall. It was active and painting the whole time, ~54 px
under the fold, along with the bottom of the rack. Two further causes compounded it: `/` moved
focus to the filter, which extinguished the caret the ensuing placement was aimed at, and every
placement became the sole selection, extinguishing it again exactly when the keep-typing loop
needed it.

**Why nothing caught either.** The suite was **structurally blind, not thin**. `tester.enterText`
is `showKeyboard` + `testTextInput.enterText` and emits *no key events*; `receiveAction`
likewise. Every `sendKeyEvent` in the repository fired while the *canvas* had focus. The
intersection "real key event + text field focused" was **empty across the whole repository**, and
`grep -rn backspace --include=*.dart` matched one production line and zero tests. Separately,
every caret test asserted `CaretController.active`, a controller state, and none asked whether
the resulting line landed inside the canvas rect.

**What this cost the board, stated plainly.** §3.2 clause 3 spent this period listing a remedy
that was real, was built, was mutation-tested, and **would not have made the drill passable**,
because neither defect was in it. The mark stayed `REFUTED` on the rule that only a person can
move it, and that rule is the only reason the error surfaced at all.

**The gate that now exists.** `packages/rackpal_ui/test/canvas/palette_search_keys_test.dart`,
13 cases, two-sided: gate-always-enabled kills T0/T1/T2/T3, gate-always-disabled (a fix that
merely unbinds the keys) kills T2b/T3b, and removing both caret-visibility mechanisms kills
C2/C2b. Its C2 case carries an **anti-vacuity guard** because the first version of that case
passed with the fix deleted, the harness mounts no tab strip, so its canvas was taller than the
real app's and the 42U rack already fitted. That near-miss is the fifth instance of this
repository's signature defect and is why the guard is written as an assertion rather than a
comment.

---

## 4. Drift: what the documents say that the code does not

Read this section before trusting any other document in `docs/`. Each entry states the drift, the
evidence, and which document sites are stale.

### 4.1 DISCHARGED 2026-08-27: the pipeline runs, and it has been red

**This heading has now been corrected twice and the pair is the record, which is why neither
correction is written over.** It read *"There is no CI. There has never been any CI."*, verified by a
maxdepth-3 search for `yml`/`yaml` returning eight files and no workflow among them. It then read
*"There is a CI file. No CI service has ever run it."*, when that search returned a ninth,
`azure-pipelines.yml`. Both were true when written and both are now false.

**MEASURED 2026-09-02 over the whole run list, not from the last run anybody looked at.** Definition
1, `RackPal CI (Windows)`. First execution **2026-08-27**, build `20260827.1`, against `main`, and it
passed first try. `az pipelines runs list` returns **51**: 48 succeeded, one cancelled, one in
progress, and **one failed**, run 11 on `refs/pull/5/merge` on 2026-08-29.

**The row is discharged on its own subject, which is whether the service runs the file at all.** It
does, fifty times. What is left here is history, and history belongs out of §4.

**WHAT RUN 11 PROVES IS NARROWER THAN THE FIRST DRAFT OF THIS PARAGRAPH CLAIMED, AND THE DIFFERENCE
IS THE USEFUL PART.** That draft said the service-side reporting path *"has been exercised in the red
direction"*, full stop. Run 11 is build `20260829.7` and it failed the **analyzer gate**, with
`info count rose by 2`, on a tree whose fifteen local gates were all green: a `git add` had staged a
file that was then edited, so the commit carried the un-fixed version and only a clean checkout could
see it. **A PowerShell gate step failing, being surfaced, and blocking the PR is therefore proven.**

**A FAILING TEST ON THE SERVICE IS STILL NOT.** No test has ever failed on a run, so the JUnit
converter's output has only ever been parsed in the green direction, and the specific worry the
paragraph below raises, *"do not yet treat a green Tests tab as proof the reporter works"*, **stands
unanswered**. Those are two different reporting paths sharing one word, and collapsing them is how
this row would go quietly wrong a third time. The honest state: the **build** result is trusted, the
**Tests tab** is not yet. `CLAUDE.md` carries the same correction.

**What the rest of this section says about run 1 is kept verbatim below**, because the reasoning is
still the right reasoning and because a row edited into agreement with the present tense teaches
nobody anything about how it went wrong.

**What exists:** an Azure DevOps pipeline definition targeting a Windows agent, Flutter pinned to
3.44.4 *and verified after install*, the analyzer gate, both palette gates, the JUnit converter
self-test, all five suites with non-vacuity floors, `flutter build windows --release`, and a
published release ZIP. Plus `tools/ci/`, `analyze_gate.ps1`, `run_suite.ps1`,
`junit_from_dart_test.py`, `junit_converter_selftest.py`, `ensure_flutter.ps1`,
`verify_windows_build.ps1`, `verify_tracked_sources.ps1` and `run_local.ps1`, all of which run on a
developer machine and were mutation-tested there.

*Everything from here to the end of §4.1 is the row as it stood before 2026-08-27 and is kept as
history. Its condition has been met: the run number is `20260827.1`.*

**What does NOT exist, and this is the part that matters for every claim below:** a run. No Azure
DevOps service has parsed the YAML, resolved a task name, fetched the pinned SDK archive, or built
on a hosted image. The file's own header says so in capitals and lists the four things only run 1
can prove. **Until a run number can be cited here, this row stays in section 4**: a pipeline
nobody has executed is a plan, and this document exists to separate plans from measurements.
`docs/11 §7`'s `.github/workflows/ci.yaml` job matrix is still a different, unbuilt thing.

The pre-existing contradictions below are therefore **unchanged in substance**: the gates the
corpus calls mechanical are still not mechanical on any server.

This contradicts, directly:

- **roadmap §8.4**: *"Green means green. CI runs analyze, test, goldens, format, the
  no-Flutter-import test, the epoch-mask coverage test and the connector-footprint assertion."*
- **roadmap §8.6**: *"Fixture gates are enforced by CI, not by review."*
- **roadmap §4, M0 checklist**, last line.
- **docs/11 §7**, which prints a full `.github/workflows/ci.yaml` job matrix.
- **Every sentence in the corpus containing "CI assertion" or "fails the build"**: AC-050's
  footprint gate, AC-052's provenance gate, AC-051's fixture-pair gate, docs/05:171's
  glyph-resolution test.

**What is actually true:** every gate in this project is still *a test somebody must remember to
run*, the somebody now has one command (`pwsh -File tools/ci/run_local.ps1`) instead of six, which
is an improvement in ergonomics and not in enforcement. The tests are real and mostly excellent;
nothing rejects a push. The roadmap's global per-milestone rule, *"EVERY MILESTONE ENDS GREEN: CI
passes"*, has never been satisfiable for any milestone, M0 included, and becomes satisfiable on
the day a pipeline run number can be written into this section.

> **RESOLVED 2026-08-03 by DR-017 (canon §11.16): adopt `dart format` as a gate, keep the
> analyzer's info ratchet.** Closed by three commits. `b6ff394` formatted the tree, **124** files rather than the 88
> recorded below, and lowered the info pin 194 to 173 because 21 of the 22 long-line infos existed
> only because nobody had run the formatter. `ecdf3b2` added `dart format --set-exit-if-changed` to
> `azure-pipelines.yml` and `tools/ci/run_local.ps1` as **gate 1b**, mutation-tested by planting a
> formatting defect and watching it read FAIL (1) with the other eight fast gates green. The docs/11
> §7 half of the choice was paid too: that section described a **GitHub Actions** workflow with a
> three-OS matrix, and the pipeline has been Azure DevOps on one Windows agent for months, so §7 is
> rewritten against `azure-pipelines.yml` with a labelled list of what is designed and not built.
>
> **The number in this section aged while the question sat open**, which is the argument against
> deferring a mechanical decision: 88 files when it was written, 124 when it was paid. The analysis
> below is left as written, because it is what produced the answer.

**Two of the documented gates fail today**, so the CI shape as written in docs/11 §7 would go red
on the first push:

| Gate as documented | Result today |
|---|---|
| `dart analyze --fatal-infos --fatal-warnings .` | **Exits 1.** 195 style infos. (Plain `flutter analyze` is clean of errors and warnings, the failure is entirely `--fatal-infos`) |
| `dart format --output=none --set-exit-if-changed .` | **Exits 1.** *"Formatted 316 files (88 changed)"*, e.g. `packages/rackpal_ui/test/stroke_scaling_test.dart:101`, where the checked-in code splits a `const Stroke(...)` across five lines and the formatter joins it |

**This is not a toolchain mismatch.** The installed SDK is Dart 3.12.2 / Flutter 3.44.4, and
`3.44.4` is exactly the version docs/11 §7 pins. So the decision is a real one and it is the user's:
**either format the 88 files and clear the 195 infos, or amend docs/11 §7 to the gates actually
intended.** Standing up CI without deciding this produces a permanently red main branch, which is
worse than no CI because it trains people to ignore it (docs/11 §8's own argument for
`--fatal-infos`, turned around).

**`azure-pipelines.yml` does not pre-empt that decision, and says so.** It runs neither of the two
gates above as written: `dart format --set-exit-if-changed` is deliberately absent, and the
analyzer gate is *zero errors, zero warnings, plus a ratcheted info count* pinned in
`tools/ci/analyze_info_baseline.txt` rather than `--fatal-infos`. Both choices are argued in the
file. **That was written while the decision was open. It is now made, as `DR-017`** (see the block at
the head of this section): the analyzer gate stayed a ratchet and the format gate was added beside
it, so `azure-pipelines.yml` runs both and neither was pre-empted by the other.

**The sentence above this one still stands, and is the reason this section does not close.** Every
gate is still a test somebody must remember to run, because the pipeline has never executed.

**Run 1 is scheduled for M5** (user, 2026-08-03), and the stated reason is a workload argument, not
a tidiness one: **M5 is where most of the design locks in, and it is the milestone made of frequent
small edits**: 28 rules, each landing with a known-bad and a known-good near-miss (AC-051). That
is precisely the shape of work where *a test somebody must remember to run* fails. A gate skipped
once in fifty small commits is a gate that was not enforcing anything, and it will be skipped on
the commit that matters.

**There is a hard dependency here that neither section had drawn.** **M5-G4** (board #302) is
*"the CI gate, a registered rule without its pair fails the build"*, and its own description says
**enforced by CI, not by review** (roadmap §8.6). Board #298 goes further: the fixture-pair gate is
*"the schedule control, not a quality nicety"*, and `RISK-03` names it as the mechanism that blocks
scope drift **mechanically**. **All of that is false while the pipeline has never run.** Wired into
`run_local.ps1` alone, M5-G4 is a convention, and a convention is exactly what `RISK-03` says will
not hold against *"just one more obvious rule"*. **Run 1 is therefore a prerequisite of M5-G4
meaning what it claims**, not merely convenient company for it.

It also lands beside canon §10.11's beta-gate answer, likewise held to M5, which by then is less a
coincidence than a pattern: M5 is where this project stops deciding against a plan.

### 4.2 The M2 detour is reconciled in code, not in the documents

**Eighteen** commits (`e433ae0` … `1eec6bf`) added a schematic canvas with **zero tests**:
`git rev-list --count e433ae0^..1eec6bf` returns 18. `b560a50`
salvaged the symbol geometry and hit-testing into `rackpal_core`, deleted `sugiyama.dart` outright,
its commit message: *"It was dead (nothing constructed it) AND broken"*, naming a
`ConcurrentModificationError` on any graph with an edge and a divide-by-zero for single-node
layers, and replaced both tabs with an inert `UnbuiltView` whose `heading` getter
(`unbuilt_view.dart:73`) is `'$viewName — not built'`.

`packages/rackpal_ui/lib/src/shell/unbuilt_view.dart`'s header **reconciles the two governing
texts that conflict here**:

- **roadmap §4, M1** *"What M1 deliberately lacks"*, *"an empty Schedule tab that explains it is
  coming is a lie, so the tab does not exist yet"*, versus
- **docs/05 §12, line 780**: *"The v1 tab strip shows three tabs: Rack, Schematic, Schedule."*

It resolves them by keeping three tabs whose first line of copy is *"not built"*, and it makes that
honest mechanically: `packages/rackpal_ui/test/shell/unbuilt_view_test.dart` walks the semantics
subtree and **fails if any node offers `SemanticsAction.tap`**, so the panel provably cannot promise
anything.

**That reconciliation exists only in a source comment.** Neither docs/09 nor docs/05 has been
edited, so the next reader meets the same contradiction the salvage already settled.

### 4.3 There are no goldens

Zero occurrences of `matchesGoldenFile` or `goldenFileComparator` anywhere. No `goldens/`
directory. No `@Tags(['golden'])` on any test. **No `flutter_test_config.dart`**, so rule 1 of the
four rules docs/11 §3.1 gives for removing the system-font variable, *"register the bundled TTFs in
`flutter_test_config.dart` via `FontLoader` before any golden runs"* (docs/11:240), has nowhere to
live, under a heading that calls font strategy *"the thing that actually makes goldens flaky"*.

Meanwhile `dart_test.yaml` declares the `golden`, `slow` and `perf` tags; docs/11 §2's test pyramid
budgets **~150 pixel goldens and ~400 display-list goldens**; and the roadmap's per-milestone rule
says *"goldens pass"*. That clause is **vacuous for every milestone to date**.

One caution about vocabulary: the phrase "golden corpus" **is** satisfied in the sense docs/11 §2.5
uses it, the byte round-trip fixtures and the migration corpus. That is a different sense of the
word and it does not discharge "goldens pass".

### 4.4 AC-052's provenance gate is prose, not a build gate

`assets/catalog/sources.md` exists (166 lines); the catalog is real and asserted at 48 templates
(`seed_catalog_test.dart:19`, `:40`). But **nothing reads the file, and no test so much as names
it**:

```text
$ grep -rn "sources\.md" packages/rackpal_core/test packages/rackpal_ui/test \
      packages/rackpal_export/test apps/rackpal/test
$                     # no output — zero hits across all four test trees
```

Its only references anywhere in the repository are **three orienting comments in `lib/`**, none of
which reads or parses anything:
`packages/rackpal_core/lib/src/catalog/catalog_connectors.dart:15`,
`rack_presets.dart:21` and `seed_catalog.dart:6`.

The nearest thing to a provenance test is a group *name* at `seed_catalog_test.dart:51`,
`group('provenance-adjacent invariants (docs/catalog/seed-devices.md §7.2)', …)`. Note the file it
names: **`docs/catalog/seed-devices.md`, not `assets/catalog/sources.md`.** Those are two different
documents, and the group's own four tests say so, every manufacturer is `Generic`, no `typePrefix`
collides, field devices are 0U, every rack-side template declares a depth and a weight. Those are
invariants about the catalog's **content**. None of them is about its **citations**, which is what
AC-052 gates on. "Provenance-adjacent" is the group's own word for the distance, and it is accurate.

- **docs/11:148** claims *"an uncited template fails the build"*.
- **docs/00:174** makes the catalog's **count** depend on the gate: *"The count is set by the
  provenance gate … not by a target number (CR-061, AC-052)."*
- **`RISK-04`**'s early warning, *"`sources.md` lagging template count by more than ~10 entries"*, 
  is **unmeasurable** as things stand.

Contrast the connector-footprint assertion, which **is** real and well-built
(`seed_catalog_test.dart:281`, `:303`, `:316`). The difference between the two is the template for
what mechanising AC-052 looks like.

### 4.5 The epoch-mask coverage test has drifted behind the code

`packages/rackpal_core/test/epoch_mask_test.dart`'s header says it snapshots persisted document
maps rather than derived outputs *"because no derived-data pipeline exists yet in this milestone"*.

`packages/rackpal_core/lib/src/derived/device_loads.dart`, `equipment_list.dart` and `totals.dart`
**now exist** and drive the chip strip, the rollups and the `T6.30` sheet, exactly the outputs
AC-014 wants mask-checked, and the test still does not see them.

This is the same shape as every defect in the table at the top of this document: **an assertion that
was honest when written and quietly stopped covering the thing it names.**

**RE-MEASURED 2026-09-23 BY THE FULL-TREE REVIEW (`#97`), AND THE PARAGRAPH ABOVE IS HALF STALE.**
The test has since learned two derived outputs, `derived:equipmentList` and
`derived:rackRollups`, so "still does not see them" is no longer true of those. The larger drift
is the other axis, the COMMANDS. A census of every `Command<RackDocument>` subclass in `lib/`
against the file found **24 of 73 with a case and 49 without**. It is worse than a count: the
test's `_knownMutableKeys` names nine top-level maps, and `ports`, `templates`, `underlays`,
`sheets`, `ackedFindings`, `registries` and `settings` are not among them, so a command that writes
any of those **cannot be given a case here at all** without first extending the mapping. Commands
that write ports (`ConnectPortsCommand`, `BindEndpointCommand`, `MoveEndpointCommand`,
`SetPortFactCommand`) are therefore untested for AC-014 by construction. No defect from this gap
was found by the review; two mask defects were found by other means (`#932`, `#933`, §4.15), which is
the argument for closing it rather than a reason to believe it is harmless.

**CLOSED 2026-09-24 BY `#944` AT `56b37d1d`, AND THE COUNT ABOVE WAS LOW.** A census that follows
`extends` through abstract bases finds **71** concrete document commands, and **52** had no case:
two more than the review's 49, because a name grep counts a command covered when a comment mentions
it (`SetMountNoteCommand`, `SetRoomEstimateCommand`). All 71 now have one, over `whole_house.rppj`,
and a census test fails when a new command lands without one. **No mask was found wrong.**

The work was not the cases. `_knownMutableKeys` gained the seven maps named above plus `info`, and
`_changedTopLevelKeys` now diffs the UNION of the keys before and after: `underlays` is omitted when
empty, so the first underlay a project gets was invisible to the old loop (`changed: {}`, measured
by putting it back). The new maps are mapped by READER: only the Rack view and the Schematic
subscribe to single epochs, so a command writing a map must declare an epoch each screen reading it
hears. The check is per map, not per field, and the test says where that bites.

**A CORRECTION TO THE PARAGRAPH ABOVE.** It says two mask defects were found by other means, `#932`
and `#933`. **Only `#933` was a mask defect**: a command declaring `style`. `#932` was a screen that
did not SUBSCRIBE to `wires`, which is the consumer side, and no test of declared masks can see it.
`#932`'s own regression test is the guard for that class.

### 4.6 Font: Jost supersedes CR-080's IBM Plex; the docs have not caught up

The code is unambiguous. `apps/rackpal/pubspec.yaml` bundles **Jost Regular AND Jost Medium**,
each twice (under `fonts:` at `:146-151` and under `assets:` at `:153-154`), with the reasoning
inline at `:125-144`; commit `0545090`, *"style: swap the bundled font from IBM Plex Sans to Jost"*,
made the swap and `875db98` added the second weight; every test fixture uses Jost, `apps/rackpal/test/baseline_parity_test.dart:81-82`
(`const String _kFamily = 'Jost'; const FontRef _kFont = FontRef(_kFamily);`) and a literal
`const FontRef _font = FontRef('Jost')` in eight `packages/rackpal_export/test/` files, including
`elevation_true_scale_test.dart:132` and `starters_export_test.dart:41`.

**Not propagated to:** docs/08 §10.1 (lines 1144–1154, the whole `RackBody`/`RackCond`/`RackMono`
table), docs/11:236, docs/03:146's asset tree, docs/05:171, and canon:1203, :1211, :3299, :4089.
**CR-080 itself carries no amendment**, which roadmap §8.3 requires for a ruling change.

> **The two canon line numbers moved in this commit, and are quoted post-move.** The DR-006 edit to
> `docs/canonical-decisions.md` inserts two lines at 2615 and two at 2924, shifting everything below
> by four: `git show HEAD:docs/canonical-decisions.md | grep -n "IBM Plex"` gives 3295 and 4085,
> and the working tree gives **3299** and **4089**. The figures above are the working-tree ones.
> `:1203` and `:1211` are above the first insertion and did not move.

Two consequences beyond the stale prose, **one of them now partly discharged**. The weights: this
entry read *"only Regular is bundled"* until `875db98`, which added **Medium (500)** under DR-090
§11.89.8 after an audit found **28 sites asking for `w600`/`w700`** against a single face and
Flutter synthesising the difference. **`RackMono` now exists**: Space Mono (SIL OFL 1.1, no Reserved Font Name), Regular and Bold,
bundled at `71b9bd1` and wired into the two call sites that were asking for a generic
`fontFamily: 'monospace'` nothing provided. `drop_entry_panel.dart` places its caret by counting
spaces, so a proportional fallback would have put it under the wrong character with nothing
failing. **SemiBold and Condensed still do not exist**, nor does `RackMono` **Italic**, which
docs/08 §10.1 wants for a derived `LEN`: `FontRef` carries a `bool bold` and no slant, so the file
would be an asset no code could reach.

The second is **partly discharged and now gated**. The four codepoints, `U+2192`, `U+2194`,
`U+2032` and `U+2033`, were absent from the bundled build and mapped to `.notdef`, which draws as
NOTHING rather than as a box; two live schedule cells emit the first onto `T6.10` and `T6.11`, and
no shipped starter does, which is why nothing ever failed. All four, plus seven more, are added at
`b7b5ac2` by `tools/build_jost_glyphs.py`, built from the face's own contours with every constant
measured per weight. **`tools/glyph_coverage_check.py` is now the fifteenth gate** and reads the
font binary, which is the only place this class of defect is visible.

**The Noto Sans Symbols 2 fallback still does not exist**, which is what docs/05:171's
glyph-resolution test depends on, and neither the test nor the fallback is present. What the new
gate covers instead is narrower and its blind spots are in its header: it sees Dart string
literals, not runtime-composed strings or user data. It carries one closed exempt set, the fifteen
domain and device glyphs that are registry DATA drawn as geometry, and one single entry, `U+03A3`,
which is a letterform rather than a shape and therefore the one thing here that could not be built
from the face's own material and checked by measurement.

**A third consequence was found by the same audit and is not about weights at all.** `main.dart`
set no `fontFamily`, so the application drew its **diagram in Jost and its chrome in Segoe UI**
from M1 until `875db98`. Both faces render, so no gate could see it.

### 4.7 CLOSED 2026-08-25: `kSchemaVersion` is 2 and the documents now print 2

**Ten sites corrected in docs/02 and docs/03**, and the semantic change below is written down in docs/02's reader-behaviour table where it belongs. **docs/06's `.rmdev` example was left alone**, exactly as the warning at the foot of this section says: `.rmdev` has its own parallel migration chain (CR-063) and no codec exists to decide its version, so bumping it would have been inventing a fact. The warning was worth its space.

**This section's own line numbers had drifted and its fixture path was pre-rename** (`v1_templates_and_power.rackpal.json`; the file is `.rmpj.json`), so the sites were found by content rather than by the line numbers recorded below. A drift register drifts too.

The record of what was wrong, unchanged:

`packages/rackpal_core/lib/src/units/constants.dart:22`, `const kSchemaVersion = 2`, and `:35`,
`const kMinReaderVersion = 2`, with a real `migrateV1ToV2` in `persistence/migrations.dart` and a
checked-in v1 input fixture (`packages/rackpal_core/test/fixtures/v1_templates_and_power.rackpal.json`)
proving old files still open.

**Stale:** docs/02:142 (the constants block), :167 (`int schemaVersion, minReaderVersion; // 1, 1`),
:948 and :950 (the example document), :1698; docs/03:759 and :775 (both `const kSchemaVersion = 1`
snippets, and the `migrations` map still commented out).

**A semantic change nobody has written down:** raising `kMinReaderVersion` to 2 means a v1 reader now
**refuses** a v2 file rather than opening it read-only. docs/02's own reader-behaviour table, 
**:1692-1693**, the `schemaVersion` / `minReaderVersion` rows, is the place that has to say so.

> **Contested — verify before editing.** The brief that produced this board also lists
> **docs/06:320** as stale. It is not obviously stale: that `"schemaVersion": 1` sits inside a
> **`.rmdev`** example (docs/06 §7.3), and `.rmdev` has its **own parallel migration chain and its
> own corpus** per CR-063 and docs/11 §2.5. Its version is independent of `kSchemaVersion` and may
> legitimately still be 1. Do not bump it without checking `packages/rackmate_core`'s `.rmdev`
> codec — which does not exist yet (M4), so today the honest answer is that **nothing in code
> decides this**.

### 4.8 Already closed: `file_selector` / `path_provider`

Listed here because it is frequently re-reported as drift and **is not**. docs/03 §10.1 has been
rewritten: line 845 is a *"(no file-dialog package)"* row explaining the `IFileDialog` /
`FOS_DONTADDTORECENT` trade and stating the residual leak as a **bound** rather than a closed list;
line 847 is the `path_provider_windows` row explaining the umbrella / `dartjni.dll` problem.
docs/08:1085 matches.

The enforcement is real and mechanical:
`apps/rackpal/test/session/session_layering_test.dart` RULE 14d fails if `file_selector` returns;
RULE 7 pins the dialog to one call site; `apps/rackpal/test/session/registry_claim_test.dart`
fails if the doc row restates the bound as a closed list; `apps/rackpal/test/flutter_dependency_test.dart`
asserts no `*_android` or `jni` package is in `pubspec.lock`. The Release directory built this
session, `apps/rackpal/build/windows/x64/runner/Release/`, contains no `dartjni.dll`, and
neither does anywhere else in the tree (`find . -name dartjni.dll` returns nothing).
**Nothing to fix.**

### 4.9 The four starter projects do not do the job the documents assign them

**docs/11:133** requires *"At least one exercises the Structure device and at least one exports a
full sheet set."* Neither is possible yet, Structure is M3, the full sheet set is M6.

Worse, the regression net has a hole on exactly the axis it was built to guard.
`packages/rackpal_export/test/elevation_true_scale_test.dart` states in its own fixture commentary
that *"the four starters contain no `Face.rear` and no partial-width placement whatsoever, so
before this fixture nothing anywhere observed the rear reflection in emitted bytes"*, which is how
the blank-rear-elevation defect named in `0fa532d` survived. It took a purpose-built synthetic
fixture to find it.

All four starters are authored by `apps/rackpal/tool/generate_starters.dart`, so growing them is a
generator edit, not hand-authoring.

### 4.10 The roadmap carries no status at all

Zero ticked checkboxes against fifty-nine unticked ones. Roadmap §8.1 puts the demonstration in the
milestone's **closing commit message**, and that part works, `b94bd60` for M0 and `0fa532d` for
M1's exporter are both detailed and honest. What is missing is the **index from milestone to
commit**, which is what this file is.

### 4.11 DISCHARGED: DR-006's propagation into the derived documents

**All nine sites were paid on 2026-08-03 and this section is kept as the record of what was owed, not as a list of work.** Re-verified 2026-08-25 before the M5 jump: every site below carries its own *(Owed edit, paid 2026-08-03)* marker in the document it belongs to, and docs/09 §4 M6's carries the sentence that makes this section worth keeping: *"a board task had already been written against the stale sentence and had to be withdrawn."* **A debt list that stays phrased as a debt after it is paid sends the next reader to chase nine finished things**, which is the same failure one direction over.

DR-006 (canon §11.6) is recorded, and canon §12.9 indexes what it supersedes. Parts 1–3 of the
canon carry their pointers already (canon §12.8, rows 12–17). **The derived documents do not**, and
canon §12.9 lists the debt explicitly rather than claiming it paid:

| Document | Site | Owed change |
|---|---|---|
| docs/09 §4, M6 | Exit criterion, last sentence | *"Windows OV/EV certificate procurement starts here"*, **deleted** |
| docs/09 §4, M8 | Exit criterion, first clause; and *Risks* (*"This is a purchasing decision, made at M6"*) | The split criterion of canon §11.6.2; there is no purchasing decision |
| docs/09 §7 | `RISK-07` | Retired in its stated form; replaced per canon §11.6.3/7 |
| docs/09 §7 | `RISK-08`, mitigation column | Population is internal; M9's criterion unchanged |
| docs/11 §11 | Rows 1–2 of the distribution table | Self-signed with a timestamp; the split exit criterion |

**Four more sites are owed and were on neither list.** They are not about signing, which is why a
debt index built around the signing change missed them: they are places that count the user
decisions or schedule §10.3, and DR-006 falsifies both. They are recorded here, and added to canon
§12.9's table in the same edit, so that "work the debt list to completion" actually completes it:

| Document | Site | What it now says | Owed change |
|---|---|---|---|
| docs/09 §8 | Item 7, at **:498** | *"**Five are now answered, `DR-001` through `DR-005`**"*, and *"pricing (§10.3) wants deciding before M6"* | Six are settled, five answered, §10.3 **moot** under DR-006, and pricing needs deciding neither before M6 nor at all while DR-006 stands (canon §11.6.3/12, §13) |
| docs/10 | **:6** | *"…and Part 4's binding user decisions `DR-001`–`DR-005`"* | `DR-001`–`DR-006` |
| docs/10 | **:11**, and the DR table headed at **:37** with rows **:42-46** | *"the five user decisions `DR-001`–`DR-005`"*, over a five-row table with no DR-006 row | Six decisions; a DR-006 row |
| docs/00 §11 | **:216** | *"…and the binding user decisions `DR-001`–`DR-005`"* | `DR-001`–`DR-006` |

**This board is the index that records the gap in the meantime.** §5.5 and §5.7 quote the roadmap
**verbatim** and state the DR-006 amendment beneath, the same pattern canon §12.8 uses inside the
record, precisely so that a reader who meets the stale sentence first is not misled by it.

### 4.12 CLOSED 2026-08-25: three stale fixture copies at the repo root

**Deleted, and `kByteExactRoots` lost the root with them.** The three carried the **pre-rename**
extension `.rackpal.json` while the live ones are `.rmpj.json`, so they predated DR-015's rename and
had been unreferenced ever since. **The vacuity guard in
`gitattributes_byte_exactness_test.dart` is what forced the second half of the edit**: it asserts
every root holds files and says *"either it moved — update `kByteExactRoots` — or the goldens are
gone"*. Deleting the files alone would have failed it, correctly, and the message named the fix. A
guard doing its job on a tidy-up is the cheapest possible demonstration that it works.

The record of what was wrong, unchanged:

`test/fixtures/{a_empty_project,b_rack_and_device,c_fuller_project}.rackpal.json` were **tracked**
(`git ls-files test/`). The real ones live at `packages/rackpal_core/test/fixtures/`, because
`byte_roundtrip_test.dart:443` and `codec_split_test.dart:29` use the package-relative path
`test/fixtures/…`. The root copies are an artefact of running the suite from the wrong directory,
are referenced by nothing, and will rot silently, and
`apps/rackpal/test/gitattributes_byte_exactness_test.dart:66` even lists `test/fixtures` as a path
it cares about.

### 4.13 Closed at `d8aedca`: 678 of 727 seed ports were in the wrong order

**Recorded because it was shipped, not because it is still open.** `PortBuilder._next` emitted
`a0 … a9, a10 …` into a `FracIndex`, which is `extension type const FracIndex(String v)` with **no
comparison operator**, so every consumer sorts it with `a.order.v.compareTo(b.order.v)`, a raw
string compare, and `'a10'.compareTo('a2')` is negative. From the **tenth declaration onward** an
affected template's ports sorted into an order that was neither declaration order nor anything else.

**Measured: 29 of the 45 seed templates with ports, 678 of 727 ports.** Four rules read that field
and all four were wrong on those ports, FIXED_ORDER (docs/05 §3, which is what
`buildSymbolGeometry` DRAWS, so `A01`'s zone speaker outputs were drawn out of sequence on the
sheet), `PORT_SEQ` on the schedule, `chainOutputFor` (DR-012.1), and `portsInBank` (DR-012.2).

**Nothing in the suite compared a template's declared order with its ranked order**, so nothing
could see it. It was found by a measurement taken for something else, #93 printing the fixture's
banks to choose a test target, and reading `A01` as `src.1.l src.3.l src.3.r src.4.l … src.1.r`.
`packages/rackpal_core/test/catalog/catalog_order_test.dart` is now that comparison over the whole
catalog, with a coverage assertion that the catalog still crosses the tenth declaration (**29 of
45**) so the gate cannot become vacuous by the catalog shrinking.

**What it cost to fix, stated because a status document that silently improves is this file's own
failure mode.** One line in `catalog_ports.dart` and two regenerated golden sets, the 300-link perf
fixture (405 changed lines) and the four starter projects (881 each). **Every changed line is an
`"order"` value**: no id, key, link or timestamp moved, which is what makes the regeneration a
data-only change rather than a golden quietly re-baselined. **Existing saved documents are NOT
migrated**, and correctly so: a `TemplateSnapshot` is a snapshot (docs/02 §6), and rewriting the
order values inside one would silently change a device the user placed months ago.

---

### 4.14 RJ-017 accepted five items into hardening and the decomposition produced tasks for none

**Found while placing DR-089's wordmark on the board, 2026-08-25.** RJ-017 accepted *"Icon,
wordmark, window and document icons, file-type registration for `.rackmate` and `.rmdev`, and a
trademark search before any certificate or domain is bought"* into the hardening milestone under
AC-058/D9. Canon §10.12(f) then named the mascot, **Riley the RackPal**, and filed three surfaces
as `#563`–`#565`.

**Neither `M8-0` nor `M9-0` produced a task for any of the five, and both are marked Done.** M8
carries `M8-A`…`M8-G`, M9 carries `M9-A`…`M9-F`, and not one of the thirteen is the icon, the
wordmark, the window icon, the document icon or the trademark search. File-type registration
survives only by accident, inside `#498` under the Store epic, because a Store listing needed it
for its own reasons. `#768` is the row that should have existed since the decomposition and now
does; `#769` is the wordmark inside it, closed at `28ba595`.

**THE SHAPE, WHICH IS THE POINT OF RECORDING IT.** A ruling that accepts something into a milestone
is not a task in that milestone. The only thing between the two is a decomposition that has to
remember, and `M8-0`/`M9-0` are Done, so nothing was ever going to look again. This is the same
class as §4.11's DR-006 debt and §4.7's `schemaVersion`, and it is **not** the class §8.8 addresses:
no closed task lied about a commit, the task simply never existed.

**WHAT IS STILL OWED, AND IT IS NOT NOTHING.** Of the five, the wordmark is done. The **application
icon** is scoped by §10.12(f) to Riley and blocked on assets, and it needs a reduced mark for 16 and
32 px because a character face at taskbar size is mud. The **window and document icons** are
unstarted, and the document icon interacts with `#498`'s open question about distinct `.rmdx` and
`.rmda` marks. The **trademark search** is unstarted and is the one with an external gate on it:
RJ-017 places it *before any certificate or domain is bought*, so it is cheap now and expensive at
the moment someone reaches for a code-signing certificate in M8-A.

**A SECOND DECOMPOSITION SHOULD BE SUSPECTED, NOT ASSUMED.** This one was found by walking from a
ruling to the board for an unrelated reason. Nothing has walked the other twelve `Mn-0` items
against the rulings they were meant to decompose, and until something does, the count of items in
this class is **at least one and unknown**.

### 4.15 The full-tree review, `#97` · 2026-09-23 · `DR-194` to `DR-197` · no version move

**Scope, stated so nobody reads more into it than was done.** `#97` was filed after M2 over 212
library files and ~68,700 lines. It ran at M5-plus-Plan-view over **170,437 lines of non-test Dart**,
and **it did not read every line**. It ran six strands, each a census or a probe rather than a
read-through, in `#97`'s own priority order: claims that stopped covering what they name; the
gaps between slices (epoch masks against their consumers, apply/revert symmetry, `doc.ports`
readers); layering; tests that pass for the wrong reason; dead public API; and `#98`'s refactor
candidates. Every behavioural claim below was **probed on a mounted screen or the real import
path** before it was written down, and one was withdrawn when the probe was the author's own grep
filter (see `#933`).

**Baseline.** All nineteen local gates green on `main` at `f71ec40c` before any change.

| Finding | Kind | Disposition |
|---|---|---|
| `wire_trace.dart` in `rackpal_ui`, so the exporter cannot draw a wire | layering | **MOVED**, `#931` at `0506ef5a`; `#98`'s one non-optional item |
| The Rack view never listened to `wires`; the outlet chip and findings drawer went stale on a wires-only commit | gap between slices | **FIXED**, `#932` at `9bf8312b`. Masked in the app by a shell that rebuilds everything |
| Two rack display toggles declared `style`, which only the Schematic hears; its DR-187 freeze wrote every symbol position into the file | gap between slices | **FIXED**, `#933`. A unit test asserted the defect |
| Three comments describing code that had changed: no incremental path, a misplaced doc comment, a crash reporter "at M2" | stale claim | **FIXED**, `#934` |
| `AddMediaTypeCommand` overwrote an occupied id and its undo deleted it; the header promised otherwise | stale claim, reachable | **FIXED**, `#935` |
| One CSV import naming a cable in two spellings that slug alike offers two new types and makes one | UI | **FIXED** by DR-197, `#937`: one row per id, every spelling an alias |
| Release builds report nothing anywhere, including a startup failure; the §12.4-safe storage log has no sink | release risk | **BUILT** by DR-194, which pulled §9.9's local half forward: the log (`#939`), the startup-failure window (`#940`), `Help ▸ Open diagnostics folder…` (`#941`). M8 keeps its exit clause |
| AC-014's coverage | test drift | **CLOSED** by `#944` at `56b37d1d`: all 71 document commands have a case, and a census fails on the next one without. None was wrong. §4.5 |
| 210 of the analyzer's 233 infos were two lints, 116 of them catalogue facts | ratchet | **CLEARED** by DR-195, `#936`: 233 to 23, facts kept under a documented ignore, cascades swept. The first sweep also stripped 45 fixture values `#246` had argued are data, and was corrected in the same chapter (§11.194.3) |
| `#98`'s refactor candidates | structure | **DECIDED** by DR-196: `wire_trace.dart` moved (`#931`), `json_codec.dart` left alone, the two canvas screens re-asked at M7 (`#942`) |
| 42 public declarations nothing in `lib/` or `tool/` calls | dead code | **CLOSED** by `#945` (§4.19): 20 deleted, 20 kept with a reason, and two turned out to be evidence of live defects (a Structure named `'STR-1'` against CR-045; a settings row that governed nothing, DR-201). This cell once said *"Listed on `#97`"* and the list was never posted there |
| `SemanticsService.announce` deprecated after Flutter 3.35 | deprecation | It is the channel M7's NVDA clause rests on. **FIXED** by `#946` at `49a2699b`: `sendAnnouncement` to the owner's view; analyzer pin 23 to 21 |
| The Plan view's clause table reads "0 of 7" and stops at `PLAN-F` | stale status | **FILED** as `PLAN-J/0` (`#943`), with PLAN-J/2's unperformable print step. See below |

**THE MOST CONSEQUENTIAL FINDING IS NOT IN THE CODE.** The request that started this review said
"before we dive into M6". The completeness gate names the current milestone as **the Plan view**
(`#588`), and §1 and §5.9 mark it `0 of 7`, `NOT BUILT`, in prose that ends at `PLAN-F`. The tree
has since gained the importer, the vendored rasteriser (`PLAN-K`), `PlanScale`'s writer, pins,
and `SheetRole.devicePlan`. That table is a second copy of a moving status that stopped being
moved, and §8.9 makes it load-bearing: M6 opens properly only once all seven clauses are
discharged or parked. At least three are human acts that no agent can perform.

**THE REVIEW'S OWN ERRORS, BECAUSE THEY ARE THE MOST TRANSFERABLE PART.** Three claims this review
made were wrong and each was caught by running it rather than by re-reading it. "No command declares
`style`" came from a `grep -v` that also dropped the one file that does, and the corrected reading
was the worse defect (`#933`). "Re-importing that sheet mints a duplicate" was derived from two
equivalence rules disagreeing, and a probe found a third that reconciles them. And the analyzer
sweep's mechanical cascade conversion folded two statements into a `??=` initialiser, which the
analyzer called clean and `shake_animation_test.dart` would have failed; it was caught reading the
diff. A confident derivation is a hypothesis until something has run it.

**WHAT THE REVIEW DID NOT DO.** It did not read the storage layer beyond the atomic writer, the
persistence codec beyond its gates, or the 42 dead declarations one by one. It ran no mutation
pass over the thousand-sequence round-trip test. Those are real gaps and not implied clean, and
`#947` owes the first, second and fourth of them; `#945` owes the third.

### 4.16 The first line-coverage measurement · 2026-09-24 at `a6d29b02` · `#948`, `#947`, `DR-198`

**Nobody had measured it.** No gate, no pipeline step and no line of this file mentions coverage.
`flutter test --coverage` over the four suites, each package counting its own tests only:

| Package | Lines | Covered |
|---|---|---|
| `rackpal_core` | 22,048 | **91.8%** |
| `rackpal_ui` | 18,019 | **93.1%** |
| `rackpal_export` | 338 | **88.5%** |
| `apps/rackpal` | 3,650 | **83.0%** |

**THE PERCENTAGES ARE NOT THE FINDING, AND NO PERCENTAGE IS A GATE.** The lowest files were mostly
`==`/`hashCode`, `const` constructors and native startup; one uncovered line was an artifact of
coverage losing an `await`'s continuation in a widget test. A percent gate would be defended by
testing getters. What the measurement bought was a list of specific places nothing had run, and
each was read before it was called a gap:

| Found | Disposition |
|---|---|
| Two of eight `mergeWith` overrides never executed (`RenameEntityCommand`, `SetRackHeightCommand`); `SetZeroUSpanCommand` neither fuzzed nor undone by any test | **Proven** by `#948`, on the saved bytes after one undo. No defect |
| `wire_trace.dart`'s tests left in `rackpal_ui` when `#931` moved the code, so core covered it at **1%** | **Moved** by `#948`: 97.1%. The fixture splits, ui re-exporting core's half |
| `DocumentStore._classifyOpen` never ran: no test made a READ fail after the file was found | **Proven** by `#947`, through the real `open`. Four branches right; the fifth is DR-198 |
| A sharing violation on open said *"Something went wrong that RackPal does not have a specific explanation for"*, while save has had `SaveLocked` all along | **DR-198**: `OpenLocked`, named, OK only, recents kept. The user's choice of four |
| `LibraryIo`/`DeviceTemplateIo`'s members the shell calls, and `runCsvImport`, had never run: every test called the function underneath | **Driven from the real menu and button** by `#947`, failures read off the dialog on screen |
| `runCsvImport` caught `on Exception` beside a comment claiming the whole contract, while `import_guard.dart` catches `on Object` citing it as doing the same | **FIXED** by `#947`: an `Error` from the store escaped the import unreported. Red first |
| The file error dialog's primary button, and Enter, never pressed | **Proven** by `#947` |
| Found BY those route tests: every library or template refusal was titled *"That is not a device library"*, including a file that is one and is too large or from a newer RackPal | **DR-199**: a title per cause. The user's choice of three |

**THE SHAPE, AGAIN.** Three of those are one defect class this repository keeps finding: a route
proved by calling its handler has never been proved reachable (`#943` found the first). And the
CSV catch is the class §4.15 opened with, twice over: a comment describing more than its code
does, and a second file citing the first as its precedent. Neither could be seen by reading one
file; both fell out of asking what had never run.

**STILL OWED on `#947`:** the storage layer read beyond the atomic writer, the codec read for G4, and
the round-trip fuzz's mutation pass (and that it generates about half the commands).
`outlet_plate_actions.dart`'s uninvoked actions were the last coverage item, closed in the same
branch. The mutation pass is §4.17.

### 4.17 The round-trip fuzz's mutation pass · 2026-09-25 · `#947` · two defects fixed

**What was measured first, with the loop instrumented over all 1,000 sequences.** The fuzz generated
**27 of the 71** document command classes. `ConnectPortsCommand`, whose data-dependent revert the
file's header calls *"the step this harness exists for"*, was drawn **8 times**, and **never onto a
port an earlier connect had made**, which is the only case that tests it. And the loop asserted
half the law it states: `revert` restores the bytes, but the trailing `apply` was run and never
compared with the first (no generated command differed when it was).

**The pass.** Ten realistic `revert` mutations, one per fuzzed command, each run against the fuzz
**alone**:

| Mutation | Fuzz alone |
|---|---|
| `MoveDeviceCommand` reverts to the new index | killed |
| `MoveDeviceCommand` leaves `localRevision` one up | killed |
| `RemoveLinkCommand` forgets the net | killed |
| `ConnectPortsCommand` removes ports it did not mint | **SURVIVED** (the deterministic test caught it); **killed** after the fix below |
| `SetRuleOverrideCommand` clears instead of restoring | killed |
| `AcknowledgeFindingCommand` revert is a no-op | killed |
| `RemoveStructureCommand` forgets the device | killed |
| `SetLinkClassCommand` forgets the lock | killed |
| `AddZeroUChannelCommand` removes nothing | killed |
| `RemoveOutletCommand` forgets the outlet | killed |

**What changed.** The fuzz asserts the trailing `apply`. Half the sequences start with two devices
from the generator's own `addDevice` arm: 154 connects, 3 onto an existing port, and the fuzz now
counts those and fails at zero, since three is thin. The 44 commands it never generates get
`apply; revert; apply` on the saved bytes at one real state each, in `epoch_mask_test.dart`'s
per-command cases over `whole_house.rppj`, so **every one of the 71 has its undo checked on the
file**, in the fuzz or there.

**THAT CHECK FOUND TWO DEFECTS ON ITS FIRST RUN, BOTH IN COMMANDS THE FUZZ NEVER DREW, AND BOTH
BEHIND UNIT TESTS THAT ASSERTED A FIELD WHILE THE FILE CHANGED:**

- **`SetConnectorAliasesCommand` emptied `matesWith`**, on the edit and not only the undo: `_write`
  rebuilt the def field by field and left it out. The mating rule returns nothing for a connector
  with an empty list, so adding one alias to an XLR stopped a real connector mismatch on it being
  flagged. The new tests compare the whole saved def minus `aliases`, so the next forgotten field
  fails too.
- **`RemovePathwayCommand`'s undo left every cable through the pathway stamped** as edited by
  `removePathway`, one revision up. Its test checked each `pathwayId` came back, and passed.

**STILL OWED on `#947`:** the storage layer read beyond the atomic writer, and the codec read for G4.
Both are §4.18, and `#947` closes with them.

### 4.18 The storage layer read and the codec's G4 read · 2026-09-26 · `#947` closes · `DR-200`

**The codec, for G4.** Unknown is an absent key, never an explicit `null`, and `0` is a measurement
(G4, CR-114). It was asserted field by field in whichever test shipped each field.
`g4_wire_test.dart` now walks every field in `SetEntityPropertyCommand`'s seven tables on real
entities from `whole_house.rppj`: cleared, **31 fields** write no JSON `null` and re-save byte for
byte; zeroed, **12 measured fields** keep their `0`. A hand-edited explicit `null` reads as unknown
and re-saves as an absent key. **The codec was already right**: two encoder mutations (unknown
written as `null`, a zero dropped as unknown) are killed, and none of the 15 committed starters and
fixtures holds a JSON `null`. It is a guard against the next field, not a fix.

**The storage layer, read beside a fresh coverage run.** Most of what never ran is `==`,
`toString`, `const` constructors, the two production-only platform wrappers (injected precisely
because they cannot run under test), and the pre-update snapshot's failure, which the session
tests drive end to end and the storage-only run cannot see. Two findings:

| Found | Disposition |
|---|---|
| `prefs_store_test`'s *"round-trips a full set of preferences"* held **four of eight** fields; coach marks, port-column packs, favourites and undo depth were each added after it | **Full now**, compared as the whole saved form so the next field is covered too; `_packsFromJson`'s "unknown names are kept" promise pinned |
| On open, a path too long for Windows read *"Something went wrong…"* while save has named it all along. DR-198's shape, one arm further down the same switch | **DR-200**: `OpenPathTooLong`, the length and `kWindowsMaxPath`, OK only, recents kept. The user's choice of three |

**`#947` CLOSES.** Its four items, across three merges: the storage layer beyond the atomic writer
(this section), the codec for G4 (this section), the round-trip fuzz's mutation pass (§4.17), and
the coverage gaps it absorbed from §4.16. Five defects fixed across them, all found by asking what
had never run: the CSV import that let an `Error` escape, the connector alias edit that emptied
`matesWith`, the pathway removal whose undo stamped every cable, and the two open errors with no
explanation (DR-198, DR-200). Plus DR-199's refusal titles.

### 4.19 The declarations nothing calls · 2026-09-29 · `#945` · `DR-201`

The census (a public top-level function or class named at most once in its own file and nowhere
else in `lib/` or `tool/`) found **41** at `a13a2dcf`: 11 called by nothing at all, 30 called only
by tests. **"Only tests call it" is not one finding but three**, so each was read before it was
touched:

| Disposition | Count | How it was decided |
|---|---|---|
| **Deleted, no caller anywhere** | 11 + 1 | the census's 11, plus the orphan below; a live replacement already did the job (`FloorplanIo`, `marqueeSelectionIn`, the Structured Wiring tab), or nothing needed it. Includes the `unknown(raw)` enum machinery both headers called *"implemented and unit-tested end-to-end"*: no caller, no test ever, per `git log -S` |
| **Deleted with the tests of their own logic** | 8 | the product never runs that logic (`isOpenFinding`: `drc.dart` drops `off` itself; `pdfHasLiftablePage`: the import refuses first) |
| **Kept, `@visibleForTesting`** | 13 | a handle on live logic that tests reach it through; the analyzer now enforces what a comment used to ask |
| **Kept, caller scheduled** | 3 | `wiringStandardExceptions` for T5.01 (`#331`); the brand paths for M8-H (`#768`) |
| **Kept, feature never wired** | 4 | the port grid's Tab moves; `#949` asks whether the grid needs them |
| **Fixed, the helper was the evidence** | 1 | `allocateStructureDesignator` sat unused while both "create one" offers wrote `'STR-1'`, ignoring the project's format (CR-045) and any device already holding it |
| **Ruled, the setting did nothing** (its resolver deleted) | 1 | `resolveDesignatorCollision` was the only reader of the collision policy row. **DR-201** removed the row and kept the stored value |

**AN UNCALLED HELPER IS SOMETIMES THE ONLY TRACE OF A RULE NOBODY FOLLOWS.** Two of the 41 were not
clutter but evidence: a helper written to obey a ruling, left unused beside a literal that broke it,
and a resolver whose absence meant a user-visible setting governed nothing. Deleting either on sight
would have erased the evidence and kept the defect.

**AND DELETING A CALLER CAN ORPHAN ITS CALLEE.** The first deletion batch removed
`pickAndImportFloorplan` and claimed `FloorplanIo` called `importFloorplanFrom` itself. It did not;
the removed function was the only caller. A second census run found the orphan, and its two tests,
which guarded the live size cap, were rewritten onto the functions the product uses. And the same
thing happened one level down: deleting the uncalled `showStructureEditor` orphaned
`StructureEditorScreen.onDone`, which only that opener passed, so the editor's **Done** button could
never appear. The census does not look at parameters; `#875`'s callbacks-have-suppliers test did,
and failed the app suite until `onDone` went too. **The census is run to a fixpoint**, the structural
tests are run with it, and at the end the census lists exactly the 20 kept on purpose.

**TWO MORE THINGS THE PRUNE NEARLY TOOK.** `backupOf` is live, and its only assertion sat inside the
`offersBackup` test; it was restored as its own test. And the test-only floor drops (core 12, ui 3,
plus DR-201's 4 core) say beside each number that no product-run logic lost its coverage.

### 4.20 The builder's second Save, and a verdict about nobody · 2026-09-29 · `#950` · `DR-202` · no version move

Reported by the user: on a new template, Save *"will save a new version rather than saving the
edits to the original template"* until the template is closed and reopened, and the `Breaking` chip
*"is a bit confusing, especially if it is a brand new template"*.

**THE FIRST WAS DR-077 §11.76.3 UNDONE, AND ITS TESTS WERE GREEN THE WHOLE TIME.** The fix was right
when made, because the builder was a dialog that built its wiring once per opening. `#778`
(`e1ba9958`, 2026-08-26) made it a view, and from then the shell built `buildDeviceBuilderActions`
inside `build`. The closure is the only record of a new template's minted
id; a save is a document change, a document change is a shell rebuild, and the fresh closure had
forgotten. Measured through the shell before the fix: two Saves wrote `tpl.zone_amp_8@1` and
`tpl.zone_amp_8_2@1`, two templates with one name. The five §11.76.3 cases each built one closure
and called it twice, which is the product's behaviour only if nothing rebuilds between presses.
`builder_save_route_test.dart` now presses the real button in the real shell, and it was red first.

**THE SECOND WAS A BASELINE, NOT A LABEL.** The chip diffed against the body the window opened with,
which for a new template is a blank, so a height read `Breaking`. DR-202 moved the baseline to the
newest version a device is placed from and draws nothing when there is none; with the id fixed, it
also stopped every Save forking a snapshot nobody could reach.

| Changed | Where |
|---|---|
| Wiring built once per authoring session, cleared on New and on close | `AppShellState._builderActionsFor` |
| `planTemplateSave`: replace while unplaced, fork once placed, never a seeded `@1` | `template_snapshot_commands.dart` |
| Save's undo restores the snapshot a replace overwrote, as the same object | `SaveTemplateToProjectCommand.revert` |
| `newestPlacedTemplateVersion`, the version-sensitive count its file said door 2 would need | `template_usage.dart` |
| Chip: `placedBaseline`, `Breaking · N placed`, version in the tooltip | `device_builder_screen.dart` |

**Scope.** No scope change. `#951`, the layout half of the same report, is separate and waits on a
mockup the user asked to see first.

### 4.21 Size and mounting, asked once · 2026-09-30 · `#951` · `DR-203` · no version move

The same report's other half: *"data has to be entered multiple times in some situations."* The
user confirmed the three the author found (heights and `Occupies`, 0U and `Occupies`, width and
span) and asked for the rest to be checked. **The check found three the user had not hit**: the
Passthrough switch a section away from the pairing it gates, a hosted card that could not be saved,
and a rear-only lacing bar that could not either.

**THE CENSUS THAT SET THE DEFAULT.** Of the seed catalog's 25 rack-ear devices, 21 take the same RU
front and rear and 4 are front-only; the rear height defaulted to 0, so the common case was the one
that typed its height twice. The rear now follows the front until it is typed.

**THE SWEEP THAT MAKES THE DERIVATION SAFE.** `derivedOccupancy` rewrites `side`, the heights and
the span whenever occupancy is edited. A derivation the shipped catalog disagreed with would rewrite
a real device the moment somebody touched its height, so a test runs it over every seeded template
and asserts no disagreement; there is none.

| Changed | Where |
|---|---|
| `mountTakesRackUnits`, `twelfthsForWidth`, `derivedOccupancy`, `hasMeantOccupancy` | `builder/occupancy_rules.dart` |
| `Size and mounting` on Identity; Physical loses six rows | `device_builder_screen.dart` |
| Occupancy edits write their consequences in one undo entry; `_impliedSide` retired | `_writeDerived` |
| Passthrough toggle beside `Pair front to rear` | `port_grid.dart` |
| The builder's two rows in the user guide | `docs/21` |

**A LAYOUT COST, MEASURED.** Identity is now taller than a 720 px window, so typing the height
scrolls the form. Two picker tests had to choose the domain before typing, because the lazily built
list dropped the picker once it scrolled away. And the Passthrough chip, at full height, wrapped the
Ports toolbar at the 1000 px minimum and overflowed the grid by 2 px; it is compact.

**Scope.** No scope change.

---

## 5. M2 → M9: the unstarted, and where real work sits inside them

### 5.1 M2, Wiring and the live schedule · `M` · CRITERION MET, weakest mark `CONFIRMED`

> **Re-audited at `ea0af6d`, after M2-A…M2-F.** Everything below the exit criterion was rewritten
> against the tree rather than edited: the previous revision of this section marked all five clauses
> `NOT BUILT` and said *"no drag-to-connect gesture, no magnetic snap, no chain-draw"*, *"no schedule
> tab and no schedule derivation"*, *"no perf test and no CI to run one in"*. Four of the five are
> now discharged and the fifth names a human act. **The paragraph this board is proudest of is the
> one that says a claim stopped covering the thing it named** — so the old text is not softened
> here, it is superseded, and what replaced each clause is cited.
>
> **Updated 2026-08-01 at `bc0c3d4`.** The fifth clause was performed by the user and passed, and
> M2-G measured the half of clause 4 that `rackmate_core` structurally could not reach. **M2's
> headline moves to CRITERION MET.**

> **Exit criterion, verbatim.** Starting from the M1 output, a user creates 60 connections without
> touching a menu; the schedule tab shows 60 correctly-sorted rows with both labels on both ends and
> conductor colours where they exist; the schematic re-lays-out deterministically (same input ⇒
> byte-identical display list) and routes a 300-connection fixture within one frame at commit, with
> the **label-layer commit cost measured and recorded** on that fixture rather than assumed (AC-016
> #20). The keyboard-only path to create a connection works end-to-end with screen-reader
> announcements.

| Clause | Mark | Why |
|---|---|---|
| 60 connections without touching a menu | **CONFIRMED**: by the user, 2026-08-01 | **Performed and passed: sixty connections, roughly 5–7 minutes, reported against this clause and therefore under its own menu-free constraint.** THE OPERATOR'S CONDITION IS PART OF THE MEASUREMENT AND IS RECORDED RATHER THAN DROPPED, as M1's clause 3 records its own: *"after a bit of practice"*. **The clause carries no time bound**: it asks for sixty connections without a menu, and 5–7 minutes is a data point rather than a threshold met, so nothing here is graded against a number the criterion does not state. **It was done WITHOUT multi-draw**, which is still unbuilt (#93): the figure is what the pin-to-pin, chain-draw and atomic-set gestures deliver on their own, and it is therefore a floor. **A CONFIRMED mark is not a gate**: no CI job re-runs this and it does not survive a change to the keymap; the regression net named below is what guards the mechanism between drills |
| Schedule shows 60 sorted rows, both labels both ends, conductor colours | **DEMONSTRATED** | `packages/rackpal_core/test/derived/schedule_test.dart:806`, a test named for this clause and asserting it verbatim: sixty rows fed in deliberately out of room order so the sort has to do the work, AC-025's room-then-pathway ordering, both labels on both ends, and `['red', 'black']` off a real speaker pair's conductors |
| Deterministic re-layout ⇒ byte-identical display list | **DEMONSTRATED** | `packages/rackpal_core/test/scene/schematic_perf_test.dart:234` and `:242`, the same 300-link document twice, and **a separately decoded copy of the same bytes**, both through `op_digest.dart`, which is the instrument written for this clause's word *byte-identical*. `sugiyama_test.dart:470` holds the layer beneath it |
| 300-connection fixture within one frame; **label-layer cost measured and recorded** | **DEMONSTRATED, on both halves, as of M2-G** | `schematic_perf_test.dart:279`/`:312` for the COMMIT path, timed in a gate step of their own, one test at a time, with the op counts they print asserted in the core suite at `:265`/`:284` (DR-178 §11.177; both steps block a merge, so the number is still defended on every push), and `packages/rackpal_ui/test/draw/paint_budget_test.dart` for the PAINT path. **The paint half was unmeasured when this row was first marked, and measuring it found 64 ms: nearly four frames.** See the note below the table: the mark stood on a scene build of ~3 ms while the thing that put it on screen took twenty times longer, which no reading of "within one frame at commit" survives. It is 10.6 ms now |
| Keyboard path + screen-reader announcements | **DEMONSTRATED: at the channel, not with a screen reader** | `packages/rackpal_ui/test/canvas/schematic/schematic_keyboard_connect_test.dart:151` walks arrows → `W` → `Enter` to one `Link`, and `:639` intercepts `SystemChannels.accessibility` to assert a commit is announced **once** and never as a cancellation. The limit is stated rather than assumed: what is verified is the platform message, not NVDA reading it aloud, and M7's accessibility criterion is where a real reader meets this |

**The paint half of clause 4, and why this row was half-right for a week.**
When M2-F re-audited this section it marked clause 4 `DEMONSTRATED` and cited
`schematic_perf_test.dart`. That test is real and it measures the clause's own words, 
*"the label-layer commit cost"*, but `rackpal_core` is a pure-Dart package and **cannot touch a
`ui.Canvas`**, so what was demonstrated was the display list being BUILT, not the display list being
PAINTED. M2-G measured the second half and found the 300-link fixture taking **63.9 ms to replay,
against a 16.7 ms frame**, while the build it was cited beside took about 3 ms. On any reading of
*"within one frame at commit"* that includes getting the sheet onto the screen, the clause was
false and the citation could not see it.

**83 % of that paint was repeated text layout.** `FlutterDiagramCanvas.drawText` built a fresh
`TextPainter`, and a native `ui.Paragraph`, on every call, and a pan re-records the picture, so
the 300-link sheet laid out 2 374 runs per frame over a working set of 703. With M2-G's cache the
same replay is **10.6 ms**, inside the budget. The figures are recorded by
`paint_budget_test.dart`, which states plainly that `flutter test` does not register the shipped
Jost so the absolute milliseconds are the test font's, the RATIO is font-independent and is what
the row now rests on.

**The roadmap's own sizing for that cache did not survive the measurement either.** docs/09's M2
risk paragraph says the cache "must be sized for" ~10,000 runs and warns that "a 2,000-entry LRU
against ~10,000 runs thrashes". The census counts a working set of **703**. The prescribed 2,000 is
a good number for the opposite reason to the one given, and the prescribed KEY, 
`(text, styleId, quantisedScale)`, would have caused the thrash it feared, because `sizePt` is in
diagram units and the zoom is applied to the canvas, so scale is not a term at all
(`text_run_cache_test.dart` measures that: the same run at two zooms is one layout).

**What guards clause 1 between drills.** A `CONFIRMED` mark discharges the clause and guards
nothing, so the mechanism it rests on is covered separately: the keyboard route
(`schematic_keyboard_connect_test.dart`), drag-to-connect with the 12 screen-px magnetic snap
(`schematic_drag_connect_test.dart`), chain-draw and DR-012.3's family-weighted magnet, and
`atomicConnect` for the multi-conductor sets (`schematic_atomic_set_test.dart`). ~~**Multi-draw is
the one gesture of RJ-001's four that is not built**~~, **built at `e078c0b`, board item #93**;
`multi_draw_test.dart`, `pin_selection_test.dart`, `schematic_pin_selection_test.dart` and
`schematic_multi_draw_test.dart` are its four suites, the last of which is one group per claim in
docs/05:484. All four of RJ-001's gestures now exist. **The drill passed WITHOUT it**, which is the
useful thing the run established beyond the mark and which does not change now that it is built:
multi-draw is a throughput improvement on a clause that was already met, not a requirement of it,
and no re-run is owed.

**What the run does NOT establish.** A first-run operator's time, the report says *"after a bit of
practice"*, and M1's clause 3 carries the same caveat for the same reason. This board does not lean
on that figure anywhere, and unlike M1's keyboard-only drill no later milestone's criterion rests on
it, so no follow-up run is owed.

**What was `NOT BUILT` in the previous revision and is not now**, since a status document that
silently improves is the failure mode this file is written against:

- the schedule derivation (`packages/rackpal_core/lib/src/derived/schedule.dart`) and the Schedule
  tab that renders it, CR-105/AC-035's *live from an empty project* is `schedule_test.dart:254`;
- Sugiyama phases 0–3 (`draw/scene/sugiyama.dart`) and the schematic scene builder;
- net labels as the default render (DR-001), the domain filter bar, hue-by-domain styling
  (`signal_style.dart`, PAL-1 gated), and `wire_trace.dart`'s drawn mode;
- the connect commands, tier-1 topology (`TOP-001`…`TOP-005`) and DR-011's pin-to-pin gesture;
- `Ctrl+1..4`, `app_shell.dart`'s `kViewKeyToTabIndex`, with `Ctrl+3` deliberately dead per CR-071;
- **CR-105's signposting and AC-048's coach mark**, which M2-F's last phase landed: a port-count
  chip on every device with unwired pins, clicking it switches to the Schematic with that device
  selected (`packages/rackpal_ui/test/canvas/port_chip_test.dart`,
  `apps/rackpal/test/session/signposting_test.dart`), and the domain-filter coach mark fires on the
  first sheet, persisted per USER in app-support prefs under DR-012.4.

**Two claims in this section that were wrong and are corrected rather than deleted.** The old text
said `AddLinkCommand`/`RemoveLinkCommand` were *"referenced from `lib/` code in exactly two places,
both of them the `UnbuiltView` copy strings"*. That was true and is not: four link-minting commands
now have real callers, and `apps/rackpal/test/unbuilt_copy_accuracy_test.dart` was widened during
M2-F precisely because it scanned for `AddLinkCommand(` alone and would have stayed green while both
copies lied. The old text also called `symbol_layer.dart` *"a symbol renderer and hit-tester that no
screen consumes"*, `schematic_canvas_screen.dart` consumes both.

**What M2 still carries, with its criterion met.** ~~Multi-draw (#93) and the portable build
(#13).~~ **Both are done**: multi-draw at `e078c0b`, the portable build at `bee96bd`. Neither was
named by the exit criterion, which is why neither held the headline, roadmap §8.1: *the exit
criterion is the unit of truth*, and grading a milestone against work-in-the-milestone rather
than against its criterion is the substitution §5.5 refuses for M6. The six tier-2 spring-back rules
are **not** M2's at all, canon defers them to M5 (§11.12.5), and implementing one as a tier-1
refusal would make the product unable to draw a mistake, which CR-017 and G2 exist to prevent.

**#124 is built (`b128a42`), and it exposes a gap in CR-081 worth recording.** The pennant's family
glyph is drawn as GEOMETRY rather than as a character, because as a character it was measured by
`PdfFontMeasurer` over Jost (which carries none of the four Unicode blocks these symbols live in,
so it returned a near-zero advance) and painted on screen by a `TextPainter` that fell back to a
system face and drew it full width. The net name landed on top of the token, and the field read
`NET-NEN006`. **CR-081's *"both backends share this one measurer"* is true of the MEASURER and says
nothing about the FONT FALLBACK behind it**: every gate compared the two backends' ops and the ops
were identical; what differed was what a `TextPainter` did with one of them, and the PDF path
embeds the subset it measures with, so export was self-consistent and only the screen lied. A
parity claim stated over a shared component does not cover what is downstream of it. The fix's
content is not the geometry but that the width is now COMPUTED from the type size and read by both
the sizer and the emitter, so no font can put them out of step. Cost, stated: five ops per flag
where a family resolves, up from four, and unlike `ff712d2`'s accidental fifth this one is
structural and does not come back.

**DR-015 renamed the project file, and the rename found two silent-loss paths that had nothing to
do with naming.** `.rmpj` ships at `dc22ddc`; `.rackpal` is still opened and still saved in place.
Both defects are the same mistake, **rebuilding a filename you already have**, and neither was
found by a failing test. They were found by asking what the app's own files are called.

**The snapshot prune** rebuilt its path from `pathFor`, which now spells `.rmpj`. Ten `.rackpal`
snapshots left by an earlier build would therefore be **counted**, so the ten-per-document cap
reads as already met, and then **fail to delete, silently**, because a snapshot that will not
delete is deliberately swallowed as disk clutter rather than a failure. The old files would sit in
AppData forever and the new ones would pile up behind them. `_entriesFor` now carries the path each
file actually has.

**The recovery scan** classified snapshots by the current extension only. A recovery pair exists
*only across a crash*, so the one window in which a `.rackpal` snapshot meets a `.rmpj` build is
exactly the window the feature exists for: the previous build died with unsaved work and the user
installed this one before reopening. The sidecar would have been left an orphan, and `scan`
deletes orphans **silently**, so a crash recovery would have gone without a word.

**Neither is about extensions**, which is why they are recorded here rather than left in the commit.
A path that is derived twice is a path that can disagree with itself, and `symbol_layer.dart`'s
header already records what that cost the last time (*"the painter and the hit-tester each computed
a pin centre and disagreed by half a pin for as long as nobody compared them"*). The rename did not
create these; it made an existing derivation visible by changing one of its inputs. Five tests now
pin the back-compat promise and every one of them dies if the legacy spelling is dropped from
`kDocumentExtensions`.

**The `drawn`-mode router took six field reports in a row, and what they were all reports of is one
decision.** `38baed1` … `5d53512`, against #96. A staircase is out of one pin, along a corridor,
into the other; **where that corridor sits on its own axis is the only free variable in the router**,
and five of the six reports were that variable being set wrong. docs/05 §10 phase 4 now carries
the corrected rule; what belongs here is the evidence, and three things in it generalise.

**First, the spec's own mechanism was channel allocation wearing a different name, and nobody
noticed for as long as nobody built it.** Phase 4 read *"offset within the gutter by the link's rank
in a total order terminating in UUID"* in the same paragraph as *"no channel allocation"*. A rank in
a total order over links **is** a comparison between links. The built answer, the i-th pin on an
edge escapes i steps further out, is a pure function of one pin's own index, which is what makes
canon §11.1.3's *"same input ⇒ byte-identical display list"* structural rather than maintained. A
contradiction inside one paragraph survived every review this corpus has had; it did not survive
someone trying to write the code.

**Second, two of the six fixes were in the wrong place, and both were *plausible* in the wrong
place.** `ebee4c2` added a detour candidate that pushed the corridor out past both bodies, correct
behaviour, correct measurements, closed the report. It was later provably dead: the staircase's own
corridor is never further out than that candidate, so it could never clear a pin column the
staircase failed to clear. It had been compensating one layer late for a corridor placed wrong
upstream, and it fired in exactly the cases where its answer and the staircase's coincided. **A fix
that closes the report is not evidence the fix is at the cause**: `diagnose-before-fixing` again,
in the form where the measurements agree with you.

**Third, and the one worth carrying: a test that counts the mechanism will certify the defect it
was written to forbid.** `wire_trace_layering_test.dart` group 1 asserted *distinct corridors per
pin*, which is the mechanism. What the reader sees is *no two cables drawn along one line*, which is
the artifact. `b48e96c` let the two halves of an edge reuse one set of comb heights, on the argument
that the detour sends them round opposite sides of the body, true of the detour, which is the last
resort, and false of the ordinary staircase, which is what nearly every cable takes. The test
counted corridors **per half**, passed, and the sheet drew 24 collinear pairs: **10885 units, a
fifth of all the ink on a 48-cable edge, painted twice.** The test was not weak, it was *precise
about the wrong quantity*. It now measures collinear overlap between the drawn segments themselves
and reports zero. The same trap caught the replacement mid-flight, a first version of the
crossed-patch test keyed on each route's topmost point, and the mutation it existed to kill survived
it, because a wrongly-placed corridor still *reaches* its far escape and only doubles back
afterwards. Counting the horizontal runs kills it with `one corridor carries 48 of the 48 cables`.

**What is not claimed.** Two cables per corridor on a reverse-patched panel is the floor, not a
defect left in: cable n and cable 47−n are mirror images in every quantity a per-link router is
allowed to consult, so nothing this file may look at can separate them. That is channel allocation,
§11.1.3 item 2, v1.2. Two links leaving *different* symbols can still share a corridor, unchanged.

**DR-014 is built (#110, `acdae02` + `0e5c568`).** A wire drawn from an already-wired set member to
a **different device** now splits the set automatically, no modifier, no mode letter, no dialog,
because #110's own costing found no free single modifier to bind one to (`Ctrl` is the magnet
suppressor and additive selection, `Alt` is DR-001's hover, `Shift` is multi-draw's run-selection).
It closes the field report *"the Right analog audio channels can't have connections made once the
left channel is made"*, which was `atomicConnect` working correctly against a pair that had already
become one cable. **§11.11.2 is amended, not overturned**: the branch is still decided by the jack,
and what changed is that a set which is already one cable has no legal set gesture left, so a full
member arms the pin-to-pin path. Four conditions keep the split from firing where the gesture could
mean anything else, and the third, never lift the LAST conductor out of a link, is what stops a
split from being a silent delete of a cable the user cannot see. The announcement names the
conductor counts on both cables, per DR-012.2, and the Edit menu says `splitSet`.

**DR-013 is built (#95, `48f1198`), and D7's gate is paid (#94, `7c2ac49`).**
Deleting a wired device now cascades (its cables, its materialised ports and any net no survivor
still carries) after a confirmation naming the count, with an undo that restores every one under
its own id. The `TODO(post-M0)` that DR-011.1 turned from inert into a live defect is closed: a
schedule can no longer print a row citing a device the document does not have (CR-017). Building it
made a **latent defect reachable**, which the property suite caught immediately, a `Link` can now
vanish without `RemoveLinkCommand` doing it, so *"apply ran and found nothing"* became a legal state
that the nullable-capture guard was reporting as *"revert before apply"*, throwing out of undo.
Separately, `keymap_source_ban_test.dart` closes the hole §4's own D7 discussion named: the
`SingleActivator` ban now covers `rackpal_ui`, the package every binding surface except the File
menu lives in, and it landed **before** M3-C rather than after.

**The portable build (#13), and why it is not M8 arriving early.** `docs/14-deployment.md` and
`tools/release/`. **It is a scope edit and is recorded as one**: DR-006 consequence 4 says outright
that a portable output before M8 is *"a scope edit under roadmap §8.3 and not something this
consequence grants"*, and one was wanted early so the team has something to test with. What it
delivers is a signed, timestamped portable folder, nothing else. **M8's four exit clauses are
untouched**: no installer, no crash reporter, no cold-start budget, no documented limits, and §5.7's
marks do not move. The app half needed no code at all: `data_root.dart` has been the portable seam
since M0, and docs/03:847's claim that pinning `path_provider_windows` to one call site *"keeps M2's
portable build a one-function change"* held exactly, **verified by running the staged tree, which
wrote `RackPalData\sessions\<uuid>.lease` beside the executable rather than under AppData**.

**Two findings from building it, both recorded because they are corrections to the corpus and not
to the code.** First, **DR-006 §11.6.2's expiry recipe has an unstated precondition**: run as
written on a normal build machine it is INCONCLUSIVE, because a self-signed root is untrusted there
and the chain engine reports `UntrustedRoot` before it ever reaches the time check, so *both* the
timestamped and the untimestamped copy come back identical and the difference the clause exists to
prove is masked. `verify_signatures.ps1` takes the verdict from `X509Chain` with an explicit
`VerificationTime` instead, and states plainly which half is observed and which is modelled. Second,
**"every artifact a release produces" is not "every file it ships"**: the first signing run replaced
Microsoft's signature on the three redistributable VC++ DLLs with a self-signed one, trading a chain
that validates on every Windows machine for one that validates only where the GPO has landed.
Binaries already signed by another publisher are now skipped.

#### 5.1.9 THE PERFORMANCE CRITERION IS MET AT 300 LINKS AND MISSED BY 5.8x AT 3,600 (`#702`)

**Measured on 2026-08-15**, when M8-F1's scale probe was pulled forward to answer a question about
persistence and answered a different one instead.

M2's criterion is *"routes a 300-connection fixture within one frame at commit"*, and it is met:
**5.8 ms against a 16.7 ms budget**. 300 links is a house with one rack, and the criterion was
written for it. Nobody had asked what happens past 300.

| Document | Links | Scene build | Ops |
|---|---|---|---|
| committed fixture | 300 | **5.8 ms** | 7,155 |
| headroom fixture, 12 pods | 3,600 | **97 ms** | 78,660 |
| scale probe, 1x | 1,200 | 93 ms | 17,304 |
| scale probe, 3x | 3,600 | 110 ms | 51,800 |
| scale probe, 6x | 7,200 | 207 ms | 103,600 |

Two independently-shaped documents agree on the order of magnitude, which is what makes this a
property of the layout rather than of one fixture.

**IT IS NOT A ONCE-PER-OPEN COST, WHICH IS THE PART THAT MATTERS.**
`schematic_canvas_screen.dart` caches the scene on `(epoch, palette, theme)` and its header argues
correctly that it must not rebuild "because a chip was clicked, a symbol was hovered or a pointer
moved". But `_onDocumentChanged` bumps `_sceneEpoch` on **every** document change, so the cache
misses on every edit. With the schematic tab open on a large job, **every cable drawn costs about
100 ms**, which is six dropped frames per gesture.

**AC-008 PRESCRIBED THE REMEDY AND HALF OF IT WAS BUILT.** It rules that L3a splits into eight
per-domain sub-pictures so *"an edit to one HDMI run rebuilds ~1,200 ops and seven pictures replay
untouched"*. `SchematicScene.domainFragments` exists and `schematic_paint_plan.dart:257` reads it,
**but that is a paint-side saving**: the recompute still runs `buildSchematicScene` over the whole
document. The partition was built for the half that was already cheap.

**Filed as `#702`, parented under M6, and the user's ruling on 2026-08-15 is that it is fixed before
M6's testing phase**, on the ground that a schematic which janks on every edit is the specific
experience this product exists to beat. A ruling is owed first: DR-011.4 says a link must not
re-lay-out the sheet, which is the shape of an incremental rebuild, but nothing says what a rename,
a delete, a template change or a registry edit invalidate, and Sugiyama's determinism guarantees
have to survive the answer.

**The gate now defends it as a ratchet rather than a budget.** `schematic_perf_test.dart` gained a
headroom group at 12 pods asserting a 400 ms ceiling, because a case asserting the real budget would
fail on every commit and a permanently red gate is one people learn to ignore. It **also** asserts
the number is over one frame, so the day `#702` lands the test fails and tells whoever fixed it to
delete the ceiling and assert `_oneFrameMs`.

**Two things the fixture work is worth keeping.** `buildSchematicFixture` gained a `pods` parameter
and pod 1 is byte-identical to the committed golden: the first draft hoisted the sheet block above
the pod loop, shifting `nextId`'s global counter by one for every later id, and the golden caught it
on the first run. And the shape assertion caught the device count: **94 per pod, not 93**, because
`schematic_fixture.dart`'s own header omits the Structure device from its total.

#### 5.1.10 THE PAN JANK WAS THE GRID, AND FOUR COMMITS CHASED THE WRONG THING FIRST (`#709`)

**Reported by the user on 2026-08-16**: panning either canvas ran "at an abysmal framerate", with
the middle mouse button, the wheel and sideways scroll alike. Fixed on 2026-08-17 by `#709`.

**THE CAUSE.** `GridPainter` padded the region it baked by **one full viewport on every side**,
which is nine screens of anti-aliased lines rasterised for every frame of a pan. `_minScreenSpacing
= 5` switches the minor tier on below about 0.71x zoom and the major below about 0.14x, so the cost
appeared exactly at working zoom and vanished when zoomed out. Both canvases share the painter,
which is why both were slow. The padding is now two tiles.

**FOUR COMMITS LANDED BEFORE THAT, ALL ON A PREMISE THAT WAS FALSE**, and the sequence is recorded
because the mistake was cheap to make and expensive to unmake.

| | What it assumed | What was true |
|---|---|---|
| `#704` | A pan should repaint nothing; move the transform to a layer | Broke both canvases in the user's hands. Its tests asserted a field the listener under test had just written, so they were vacuous |
| `#705` | The base plan is rebuilt per frame | Real and kept: the memoised plan stands on its own |
| `#706` | The engine should keep the raster | Six lines, no state; kept |
| `#708` | The display-list walk is expensive during a pan | Reverted. The profiler, once bounded to the pan window, returned **seven samples, six with no Dart frame at all** |

**Dart is idle while you pan.** Every commit above `#709` was optimising Dart-side work in a frame
where Dart does nothing. The first profiling run said otherwise only because the query was
unbounded (`timeOrigin: 0`, `timeExtent: 1 << 40`) and returned the whole ring buffer back to
launch. The decisive evidence was the user's own: *"buttery smooth zoomed all the way out"*, which
says the cost scales with **pixels covered**, not with ops issued, and no amount of Dart-side
caching addresses that.

**`#702` IS UNAFFECTED AND STAYS FILED.** §5.1.9's 88 ms is at twelve pods; the largest shipped
starter, `whole_house.rmpj`, has 96 devices and 27 links. It is a headroom defect, not an MVP one,
and it was never what the user was feeling.

**AND THE PAINT WORK EXPOSED A SECOND DEFECT WORTH NAMING.** Once the opening view framed the whole
rack (DR-066, `#710`), the keep-the-caret-visible pan began firing across rack switches with the
incoming rack's geometry and the outgoing rack's matrix, panning 1984px to rescue a caret that was
never lost. Canon §11.65.4 has the mechanism. It predates the framing change and was merely too
small to notice at zoom 1.0.

### 5.2 M3, Structure and the field · `M` · **4 of 5 discharged, 1 parked** · weakest mark `CONFIRMED` · ~~hard-blocked on M2~~ (block lifted at M2-F, §5.1)

> **Exit criterion, verbatim.** A 60-drop whole-house rough-in is entered in under fifteen minutes,
> produces 60 `Link`s each with one `fieldLabel` and one `rackLabel`, and exports a Pull Sheet
> sorted by room and pathway with per-room footage subtotals and initial boxes. **Fourteen of those
> drops have unbound far ends and every one of them still schedules, prints and carries a `W`
> number** (AC-018). Requirement 6 is met.

**Clause 3 is AMENDED by DR-027 and the blockquote above is its original wording, kept because a
quoted criterion is the record.** M3 owes the **derivation**: the rows, the sort by room then
pathway, and the per-room footage subtotals, as tested `rackpal_core` output. **M6 owes the
sheet**: the `SheetRole`, the layout, the initial boxes and the page. `SheetRole` has three values
and none is a Pull Sheet, so M3 could not have discharged a clause about a sheet it does not own,
and reading the clause loosely enough to call it met is the checklist-ticking §8.1 refuses. The same
seam already governs AC-018's PRINTS clause (#574), which is parked on M6 for the identical reason;
one seam, two clauses. M6's own criterion needs no addition, since *"all four starter projects
export a complete set"* already contains the sheet.

**Every clause NOT BUILT** *(as recorded when M3 opened; superseded below by M3-A and M3-B, and the
file paths and line numbers in this paragraph are the ones that were true then)*. Model only,
inherited from M0:
`packages/rackpal_core/lib/src/model/{outlet,structure_body,location,pathway}.dart`, persisted and
byte-round-tripped by the `c_fuller_project` fixture. Grepping `Outlet`/`StructureBody`/`Pathway`/
`Location` across `packages/rackpal_ui/lib` and `apps/rackpal/lib` finds **no Structure UI at
all**: only three **hard-coded demo Locations** at
`packages/rackpal_ui/lib/src/canvas/rack_canvas_screen.dart:4030-4032` (Main House / Media Closet /
Living Room), whose own comment at `:4026-4027` says *"the project Locations panel (CR-112) and the
'+ New…' creation flow remain out of scope, so these are seeded rather than creatable"*, and a
chip-strip `Outlets` label at `rack_metrics_row.dart:136`.

The AC-018 clause is **unreachable by construction**: nothing schedules and nothing prints a `W`
number. That M2 block, `Link` + `Endpoint` reaching the UI, is discharged as of `ea0af6d` (§5.1).

**M3-B is CLOSED as of `4ae5a54`** (board #84, six commits from `d1b5266`), and the paragraph above
is now stale in one detail rather than wrong in outline: **grepping `Location` across
`packages/rackpal_ui/lib` no longer finds only the demo three.** There is a project-level Locations
panel at `packages/rackpal_ui/lib/src/project/locations_panel.dart`, reached from a second
top-level menu, and `Location` is creatable, renameable, movable and deletable through commands.
The three hard-coded demo Locations **are gone as of `5f5bce5`** (#143), which was sequenced after
the panel precisely so the dropdown did not go empty in between. That closes the last part of the
M3-B paragraph above that was still describing the tree as of M0.

**M3-A is CLOSED as of `6cb7e5a`** (board #83, eight tasks), and the criterion was demonstrated
rather than inferred from the ticks. That issue opens *"AC-018 is currently unreachable BY
CONSTRUCTION; M2-B's schedule already handles unbound ends correctly, so the work is producing the
drops, not teaching the schedule."* Nothing joined the entry loop to `buildSchedule` until the
closing commit: seven drops from one typed line now produce seven schedule rows, each with a W
number and a field label and no rack label, asserted as a SET so a duplicate cannot hide inside a
matching count (G1). **AC-018's fourth clause, "prints", is not claimed and is not reachable in M3
at all**: `SheetRole` has three values and none is a cable schedule, which is #574.

**#575 was the last task, and what it found is the part worth keeping.** Its premise ("the command
layer is done, nothing in the app calls it") had already been discharged by M3-C/1 two days
earlier, so the remaining work was the twenty lines between a typed line and the undo stack, which
had **no tests at all**. Both defects there were invisible to all fourteen gates:

*The preview's actor reached the document.* `DropEntryPanel` re-plans on every keystroke to draw its
preview, with `actor: 'preview'` and a throwaway clock, and `planDropLine` threads both into every
command it builds. `onCommit` applied those commands, so sixty cables would have recorded the
literal string `preview` as their author. A comment claimed the app rebuilt them; it did not, and
the comment was the only thing making the design sound right. Labels, W numbers, net names and the
byte round-trip are identical either way, so nothing but a test naming `EntityMeta` could have
caught it.

*`keystone` was asserted on every drop, and it prints.* `derived/schedule.dart` calls
`StructureOrigin.terminationField` "what the trim-out crew actually installs" and puts it on the
Termination Schedule. A drop line never says how the wall end is finished, so `4x Cat6, 2x RG6, 2x
16/4` produced rows ordering a keystone jack for an F barrel and for something that is not a jack.
Now `unterminated`, which the code says outright is the nearest true value and not the right one:
**the field should be nullable** (G4, CR-114), and `_terminationOf` already returns
`TerminationType?` for every link that is not a home run. Owed, and filed rather than smuggled in.

**#143's own stated ground had already lapsed, and the correction is the useful part.** It argues
the demo three were *"a lie that survives into a user's document"*. They could not have been, and
had not been since the persistence layer landed: `RackCanvasScreen.document` is `@visibleForTesting`
and the shell always passes `controller:`, so **production never reached the demo fallback at all**.
What they actually were is FIXTURE data that the whole app suite and much of the `rackpal_ui` suite
open, which is a smaller problem of the same shape: three rooms no gesture created, sitting under
every assertion made against that document. The removal stands; the reason is narrower than the one
written on the board, and a task whose justification decays between being written and being done is
the ordinary cost of decomposing a milestone in advance rather than an argument against it.

**M3-B needed one ruling and it is DR-021** (canon §11.20). The corpus specified the tree's shape
(CR-047) and its owner (CR-112) and said nothing at all about what deleting a node costs, which is
the one question of the four the panel had to answer. **The census is the part worth keeping**: the
question was put to the user with seven carriers of a `locationId` and answered against **nine**,
because a case-sensitive grep for `locationId` finds neither of `Pathway`'s, which are spelled
`fromLocationId` and `toLocationId`. That is DR-012's habit applied to a smaller question, and it
was the difference between a delete that clears every reference and one that leaves two dangling in
a file people email each other.

**M3-B/3 turned out to be a gate rather than a decision**, which the task itself predicted.
`schedule.dart` has carried `kUngroupedTitle` (`NO ROOM RECORDED`) since M2-B and one case touched
it; nothing asserted the seven properties that make it an answer instead of a string, and **the
failure is invisible on every fixture in the corpus**, because they all give every drop a room. It
is also no longer an exotic state: from DR-021 §11.20.2, deleting a room clears
`PlaceEndpoint.locationId` on every drop in it, so an ordinary undoable gesture now produces the
roomless drop that band exists for. The PDF half is **not** covered and is not silently skipped:
`rackpal_export` paginates the equipment list and no cable-schedule sheet exists yet.

**M3 owes one small thing that is not an exit clause, and it is not the one first recorded here.**
DR-018 §11.17.4 put the *raster carrier* on M3 on the ground that omitting it would cost a format
migration. **DR-019 read `persistence/` and that ground did not hold**: the zip sniff already returns
a typed error, `minReaderVersion` signals forward-incompat, and an absent entity map and an absent
key are how this format says "not present" (G4, CR-114). No existing file would migrate. The
container is therefore built with the Plan view, not here.

What M3 does owe is narrower and real. **`Placement` carries no `unknown` passthrough**: `Port`,
`SheetItem`, `EntityMeta` and the root envelope all do, and `json_codec.dart` decodes
`OffRackPlacement` as exactly `locationId` and `mountNote`. A build predating a later placement field
therefore **drops it silently on save**, and under DR-006 this is an internal tool whose users share
files. That is days of work, it protects every future placement field rather than only the Plan
view's pin, and it is roadmap §2.1's newest v1 row (DR-019 §11.18.2(5)).

**It adds no clause to M3's exit criterion and no week to its `M`.** The criterion is a 60-drop
rough-in producing a Pull Sheet; a forward-compat guard neither helps nor hinders it. Design:
[Plan view](15-plan-view.md). Canon §11.18, §12.12.

**M3 also grows for the second time, and this one is a surface rather than a field.** DR-020
(2026-08-04) puts the **as-built tally** here: one table an installer tabs down to record
`terminatedLength` and the new `Link.spliceCount` per run, reusing the Structure editor's
bulk-entry ergonomics rather than inventing a second table (AC-048). The reason it lands in M3
rather than later is that **M9's exit criterion is three internal users on three real jobs**, and a
tally that has never met an actual pull is a tally nobody has validated. The reason it is cheap is
that the model is already there: `terminatedLength`, `roughInStatus` and `TestResult` all ship, and
`derived/schedule.dart` already projects two of them into every `ScheduleEntry`. **The as-built
story was 80 % modelled and 0 % reachable.**

DR-007 was M3's first growth (keystone strap geometry) and §5.2's cost note already put M3 at the
upper end of its `M`. This is the second. **M3 stays `M`**, a column on a table the milestone
already builds is not a new screen, but the row should be read as `M`-at-its-ceiling, and a third
addition would be the one that moves it.

**M3-C gained a sixth task before its first, and the census is why.** M3-C/1 (#147) is the
repeat-entry loop, whose worked line is docs/07 §4.3's `Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x
22/4`. Opening it turned up that **`Registries.mediaTypes` was `{}` in every document the product
had ever written**, so `Cat6` had nowhere to resolve and no task owned filling it. #582 (M3-C/6) is
that task, **closed at `acd63d5`**, and it is worth three notes beyond its own commit message.

*The count is 38, not 34.* Canon §6.5 prints 34 rows and four of them carry two ids on one line
joined by `·`. Reading the table as 34 types silently drops `media.14_4`, `media.22_2`, `media.om4`
and `media.conduit_ent`, and docs/07 §5.1's synonym block resolves to three of those four. This is
the same shape of error as DR-021's, which was asked with seven `locationId` carriers and answered
against nine: **the field, not the name.**

*The shipped starter spoke a private dialect.* `whole_house.dart` named `media.cat6_utp`,
`media.speaker_16_4` and `media.fiber_os2_2f` for cables the corpus spells `media.cat6`,
`media.16_4` and `media.os2`. Because it registered its own `MediaTypeDef` for each, the document
was internally consistent and nothing failed: 27 links simply carried media that **no CSV import,
no drop DSL and no wide-mode header match could reach**, and would not have until someone typed
`Cat6` into a starter and got nothing. Corrected in the same commit.

*One derived-document sentence was false and is now true.* docs/07 §5.1 closed with "Every target
above resolves in `assets/catalog/registries.json`; a CI assertion enforces it". That file has
never existed and could not have been loaded by `rackpal_core` if it had; DR-010 §11.10.1 settled
the master as seeded Dart. The assertion now exists, transcribes the block from the doc rather than
reading it out of the code, and checks the converse too, that the seed invents no synonym the doc
does not list.

**M3-D/1 is closed at `b4b9115`, and it was held open for eleven days on purpose.** The two drop
label formats had round-tripped since M0 with exactly one caller each, the codec, which is precisely
where `netNameFormat` sat until M2-A wired it. `b4b9115` gave both an allocator through the one
format engine (CR-045, CR-049), so a project's customised pattern is honoured rather than bypassed.

**It was not marked done then, and the reason is §8.1.** Nothing outside its own tests called either
allocator, and done means demonstrated. The caller is **M3-C/1**: `drop_line_planner.dart` allocates
every drop's field label through `allocateOutletFieldLabel` at `20c0801`, and the sixty drops in the
keystroke measurement reach the document carrying labels this task produced. Recorded because the
alternative was a green tick over a function nothing invoked, which is the shape of "checklist-
ticked" §8.1 exists to refuse.

Its measurement is what forced two rulings. `{ROOM_ABBR}-{SERVICE}-{SEQ}` wraps nothing in `[...]`,
so it **throws** on the state docs/07 §4.1 calls *"first-class, encouraged"*: that is DR-022's
evidence, and DR-023 is the chain that answered it. The rack label needed no ruling and got none,
because `rackLabel` is optional (CR-044) and AC-018's fourteen unbound drops simply have none.

**M3-C/1 is closed, and the number it produced is 5.82.** #147's instruction was not "build a text
field": *"write the loop first, drive it with a keyboard, and time ten drops on a stub UI. If ten
drops are not on pace, no amount of table polish will make sixty."* Closed across four commits, the
last at `bf43a38`, in three layers that can each be driven alone: a parser that takes text and needs
no document (`73073dc`), a planner that takes a parsed line and a document and mutates neither
(`20c0801`), and the surface (`64f8108`).

*The measurement, and what it is not.* Sixty drops across ten rooms cost **349 keystrokes, 5.82 per
drop**, or **292 and 4.87** when the rooms are typed by code rather than by name. Both are gated.
Neither times a person: fifteen seconds per drop *including thinking* is a human fact and **#163
(M3-G/1) is still the only thing that can measure it**. What is measured here is the part the
surface controls, which is the part that could have made the drill impossible before anyone ran it.
The first version of that test asserted "under four" because four sounded right; the figure is 5.82
and the assertion is now a ceiling over the measurement rather than a target somebody hoped for.

*One ruling, DR-023 (canon §11.22), and the corpus's own example caught the implementation.* The
chain is `@service=`, then the outlet template's tag, then the media's `shortTag`. Step 1 was
written first as "use the modifier literally", which renders `EXT-CAMERA-1` where docs/01 §571
prints `EXT-CAM-4`. `CAMERA` is not `CAM`: the modifier names an `OutletTemplate` exactly as step 2
does, and differs only in how that template is chosen. **`EXT-CAM-4` was not reproducible until #150
seeds the six templates**, because `outletTemplates` was `{}` in every document, and that was gated
in both directions rather than left to be noticed. #150 closed at `5abb8b3` and the gate is now the
label itself; see below.

*Two outcomes that are deliberately not refusals.* A missing room and a missing Structure device are
what a blank project is always missing, and both are one keystroke away. As refusals they would make
the surface print an error for the most ordinary thing that can happen on line one; as their own
outcomes it prints an offer. Nothing is created behind the user's back either way.

*What M3-C/1 unblocks.* #575 (M3-A/6) was waiting on exactly this, and it is the last open task
under M3-A.

**What #582 did not do, stated so #147 does not assume it.** `kUnstatedMedia` survives. Its
standing note names two conditions for its own deletion, `mediaTypes` seeded **and** a family able
to name its typical cable; only the first is met, because canon §6.5's `supports[]` is one of the
eight fields DR-010 §11.10.4 keeps out until something reads it. So a connect gesture still cannot
pick a cable, and the reason has changed from *there is no id* to *there are 38 and nothing says
which*.

**M3-C/4 (#150) closed at `5abb8b3`, and the number that made it a real task is seventeen.**
`registries.outletTemplates` was `{}` in every document the product has ever written. It was not,
however, unreferenced: `whole_house.rmpj` carries **seventeen outlets** whose `outletTemplateId`
reads `outlet.tv_location`, `outlet.ap`, `outlet.camera`, `outlet.data_only` or
`outlet.ceiling_speaker_pair`, and every one of those references had dangled since the fixture was
authored. Five of the six ids are therefore transcribed rather than chosen; `outlet.keypad` is the
only one this seed named first. Nine templates ship: CR-108's six, then TIA-570-D Grade 1/2/3.

*What the ruling specified, and what had to be censused.* Canon §1673 names the six templates and
stops. The recipes came from the fixture's own drops, which are the only executable statement of
what these produce, plus docs/07 §4.3 and docs/01 §519/§521. **One source disagrees and is named in
the seed header rather than dropped**: docs/02 §6.2's worked JSON gives `outlet.tv_location` a fifth
drop, `1 × media.cat5e` for `ctl.ir_emitter`, and `media.cat6a_futp` for the twisted pair. It is
outvoted three to two, and taking Cat6A would put the seeded TV location at odds with
`Living Room: 4x Cat6`, the first drop line the corpus prints. The IR run is not wrong; canon §2202
accepts exactly that Cat5e at a TV location. It is one integrator's habit, and a seeded preset is
the wrong place to make it everyone's.

*The tags are the corpus's own labels, and the census settled two spellings.* DR-022 §11.21.4 is
explicit that a tag is authored beside the name and never derived from it, so all six come from
field labels the corpus actually prints. **KEYPAD is `KEY`**, canon §11.21's `MBR-KEY-2`, not
docs/08's `KIT-KP-1` and not design-ux-schematic's `MBR-KY-2`: three spellings, and canon is
normative over a derived sheet. **CEILING SPEAKER PAIR is `SPK`**, and that one was three-way.
docs/07 §4's labelled table prints `LR-SPK-1` in FIELD LABEL with `CLG` in the OUTLET column beside
it, so docs/08's `GR-CLG-1` is an outlet designation that wandered one column left. The whole-house
fixture's `GR-AUD-1` is the third reading and it loses **on principle rather than on count**: `AUD`
is `audio.analog`'s domain tag prefix, which is precisely the family-shaped answer DR-022 §11.21.5
rejected, a word that never varies and never becomes anything else, stored forever by CR-048.
docs/08's three labels were corrected at `88a1730`; the fixture's are hand-authored rather than
template-generated and are a separate question.

*Two absences that are G4 rather than oversights.* **The three grades carry no tag.** No label
anywhere in the corpus renders a grade, so there is no attested word, and inventing `G2` would print
a guess on physical cable. `tag` is nullable, null is unknown (CR-114), and DR-023's chain falls
through to step 3, so a Grade 2 outlet's drops label `LR-C6A-1` and `LR-RG6Q-1`: what they are,
which is true. **Keypad's service is `structure.undetermined`**, and that is the finding this task
turned up. docs/07 §4's table prints `Keypad` in its SERVICE column and there is no keypad family
among the 55: a keypad speaks Cresnet, Lutron QS, DALI, KNX, RS-485 or a contact closure depending
on a control system chosen months after the 22/4 is pulled.

*The seed's `service` is intent, and the Link's is not.* `AddHomeRunCommand` writes
`structure.undetermined` unconditionally, and docs/07 §4.1 says why: at rough-in a Cat6 is just a
Cat6. docs/02 §6.2 prints both facts in one file, `outlet.tv_location`'s drops naming `net.ethernet`
and `rf.catv` while `W001.services[0].signalFamily` reads `structure.undetermined`. Nothing consumes
the field yet, and the note that matters for whoever wires `+ Add outlet ▾` is that it must **not**
copy `service` onto the Link.

*What it retires.* `drop_line_planner_test.dart` had asserted since M3-C/1, in as many words, that
`EXT-CAM-4` could not come out of a real document. It now does, all six of it, from a project that
authored nothing. One test was deleted and its replacement asserts the corpus's own line.

*What #150 did not do, so the next reader does not assume it.* `OutletTemplate` still has **no
`tia570Grade` field**, so a grade preset cannot stamp the very standards tag it exists to carry
(CR-108; the fixture sets `'TIA-570-D Grade 2'` by hand). It carries no location-field requirements
either, so AC-034/m24's rule that a ceiling speaker pair is never asked for a compass direction has
no model to read. And there is **no instantiating builder**: `+ Add outlet ▾` turning a template
into one `Outlet` and N `Link`s is the Structure editor's, not the catalog's. This shipped the
master.

**Two of those three absences closed at M3-C/5, and the third is still open.** The field landed at
`7516df4` and the gesture at `cc96e0d`/`7ea2e44`; AC-034/m24's template-driven inspector fields are
the one left, and DR-024 §11.23.4 keeps them out deliberately.

**M3-C/5 (#151) closed at `7ea2e44`, and it was re-scoped before it was built.** #151 read
*"TIA-570-D presets"*, and #150 had already shipped all three of them: the task's data half was
done by its neighbour, without either being wrong. Rather than open it, find it two thirds
finished and re-scope in the dark, the change is **DR-024** (canon §11.23) under roadmap §8.3, with
a real question inside it rather than only bookkeeping.

*The question, and why the cheap answer loses.* Does the grade stamp live on `OutletTemplate`, or
does the builder special-case the three seeded ids? The special case needs no model change and works
for exactly the three presets this repository ships, **which is the opposite of what CR-108 ruled**:
user-defined templates are first-class, so a shop authoring its own Grade 2, or one citing a
builder's spec rather than TIA's, would stamp nothing, and an id rename would be a silent behaviour
change. So `OutletTemplate.tia570Grade: String?`, a free string because CR-108 deleted
`StructureGrade` and kept the field as a **citation for specs that cite one**. The three presets
carry the exact string the whole-house fixture already writes by hand, and a test pins it: a free
`String?` makes a divergent spelling of the same standard possible and silent.

*CR-117 held, and it mattered more here than for `tag`.* Nine templates had shipped four commits
earlier, so a document written between `5abb8b3` and `7516df4` carries the three grade entries with
no `tia570Grade` key. Reading yields null, writing omits it, `write(read(bytes)) == bytes`. Gated in
both directions.

*The gesture is the first caller DR-023 step 2 has ever had, and that is the finding.* The chain is
`@service=`, then the outlet template's tag, then the media's `shortTag`. **The middle arm has been
unreachable since it was ruled**, because nothing in the product created an `Outlet` *from* a
template: the DSL creates bare outlets, and the only outlets carrying an `outletTemplateId` were the
seventeen hand-authored ones in the whole-house fixture. `LR-TV-1`, DR-022's own first worked
example, could be produced only by typing `@service=tv`, which is step 1 wearing step 2's clothes.
It now comes out of a menu pick with nothing typed.

*What it deliberately does not do.* It **creates** an outlet and never joins one, because docs/07
§4.3 says *"as one `Outlet`"* and `outletTemplateId` is provenance (CR-108, *"what created it"*):
adding a recipe to a plate that already exists would either overwrite that or leave drops
disagreeing with the template they name. `@outlet="…"` remains the gesture for an existing plate.
And the template's `OutletDrop.service` is **not** copied onto the `Link`: `AddHomeRunCommand`
writes `structure.undetermined` and docs/07 §4.1 says why, so the template's service stays the
recipe's intent, which is the pair of facts docs/02 §6.2 prints in one file.

*One refactor, and the reason it is one.* The label, the `W` number, the net name, the endpoint and
the refusals are one behaviour with two entry surfaces now, so they moved into
`structure/drop_build.dart` (unexported) and `planDropLine` calls it. Two copies would drift exactly
the way CR-107 ruled `StructureDrop` and `Link` would: *"the drop schedule says 78 ft and the wiring
schedule says 90 ft, and nobody knows which to bill against."* All 62 existing planner tests pass
unchanged, which is what makes it a refactor rather than a rewrite.

*Three stale sentences of my own, fixed in passing.* `_serviceTagFor`'s doc still said
`outletTemplates` is `{}` in every document and `EXT-CAM-4` is unreachable until #150; canon §11.22's
heading was `##` where every other §11.x is `###`, putting DR-023 at the same level as §12; and
`.okf/decisions/dr-023-*.md` had an unquoted colon in its frontmatter `description:`, which made the
OKF conformance checker call the **whole bundle** non-conformant. It is conformant now.

**M3-J was decomposed on 2026-08-08, four tasks (#583–#586), and it had none until then.** DR-020
postdates the decomposition that issue #70 performed, so the epic it added carried a brief and no
work items. That is the failure mode decomposing an epic before starting it exists to prevent, arriving on an
epic nobody had started.

*M3-J/1 (#583) closed at `f43406d` before the epic was decomposed, and is a task anyway.*
`StructureOrigin.terminationField` was non-nullable while `derived/schedule.dart` calls it *"what the
trim-out crew actually installs"* and prints it, so both entry surfaces had to write a decision they
did not have. M3-A/6 had already changed the drop line from `keystone` to `unterminated` and its own
comment said outright that this was *"the nearest true value, not the right one"*. **`unterminated`
is a decision**, a coil left deliberately bare, and a drop entered at rough-in has no answer at
all; a non-nullable enum cannot tell those apart, which is G4's central prohibition. The unknown
path already existed and was unreachable: `ScheduleEntry.terminationType` has always been
`TerminationType?` and `_terminationOf` has always had a *"then nothing"* arm that no home run could
reach. One behaviour change is gated and stated: **a null origin outranks nothing**, so it falls
through to a `PlaceEndpoint.intendedTermination` rather than printing a dash over a stated intent.
CR-117 held without a schema bump, because the key was unconditional before and every document ever
written carries it.

*M3-J/4 (#586) is the boundary #569 asked to settle, and the answer is a census rather than a
decision.* DR-020 §11.19.2(4) asks for *"a new `maxLength` on the media registry"*. `MediaTypeDef`
has carried `maxRunLengthPassive` and `maxRunLengthActive` since M0, and **M3-C/6 seeded the first
of them at `acd63d5`**: seven of the 38 types carry a length and thirty-one are deliberately null.
So M3 owns the field, M3 has already shipped it, and M5 owes only the rule. **The hazard is that
there are two fields**: `maxRunLengthActive` is null on all 38 and gated as such, so a `LEN-002`
written against it would compile, pass a fixture pair, and never fire on a real document. Silent
non-firing is the worst failure mode a validation rule has, and it is now written down before M5
starts rather than found there.

*#586 closed at the commit below, and the correction went into the ruling rather than only the
board.* Canon gains **§11.19.7**, which names the field, records that M3-C/6 shipped it, rules that
`LEN-002` reads `maxRunLengthPassive` and not the empty active one, and states that the rule is
silent-with-a-count on the thirty-one types with no declared maximum. §11.19.2(4) keeps its wording
and gains a pointer; nothing it ruled changes. Three derived documents named a field that does not
exist and now name the one that does (docs/02 §5's `LEN-002` row, docs/09 §3 and its risks table,
docs/10's DR-020 row), and both `MediaTypeDef` fields carry the choice in their own doc comments,
which is where M5's implementer will actually be standing.

*M3-J/2 (#584) closed at `70a93f4`.* `Link.spliceCount: int?`, the second of DR-020's three v1
items. The nullability is the task rather than a detail: a non-nullable `int` defaulting to `0`
cannot tell *"nobody has looked"* from *"somebody looked and there are none"*, and four of the eight
tests exist to keep those apart. `putIfNotNull` is the right writer precisely because it compares
against null and not against zero, so a confirmed none reaches disk as `"spliceCount": 0` while an
unlooked-at run has no key. Wired to a `LinkField` row, which is the AC-013 retrofit; that table had
held exactly one row since M3-A/7.

*One item was found unowned and given a home rather than a task.* DR-020 §11.19.4 leaves open
whether `PathwayKind` gains `attic` and `crawlspace`, and says it is **"Owed at M3, when `Pathway`
gets its editor"**. That editor is #156 (M3-E/1) and no item claimed the question; it is recorded
there with the ruling's own framing on both sides, so it is decided rather than rediscovered.
**Answered as DR-031 at `a9ecede`**: both values are in, because what a `PathwayKind` value carries
is a consequence an integrator acts on, and the "these are spaces and `Location` models spaces"
objection fails on the fact that `fromLocationId`/`toLocationId` are ENDPOINTS, so a space in the
middle of a run has no field to live in.

*What M3-J is blocked on, stated so the order is not re-derived.* **M3-J/3 needs #148.** DR-020
§11.19.5 says twice that the tally is *"a column on a table the milestone already builds, not a new
screen"*, and that is why M3 stayed `M` when the ruling grew it. M3-J/2 (`Link.spliceCount`) and
M3-J/4 are unblocked and can land in any order. **#148 closed on 2026-08-08, so M3-J/3 is
unblocked**: the table it needs a column on is built, and `StructureColumnId` plus
`kStructureOptionalColumns` are where that column goes.

**M3-J/3 (#585) closed the same day, and M3-J closed with it.** §11.19.3's "80 % modelled and 0 %
reachable" was still half true after #148: five of the seven as-built columns RENDERED and none of
them could be typed into. Two were missing outright, `SPLICES` (M3-J/2's own field, which had no
column at all) and `TERMINATED`. All seven are enterable now, and `kStructureAsBuiltColumns` turns
the set on as **one switch** at the top of `⚙ Columns`, because reaching that table through seven
menu entries would put the cost §11.19.2(5) is about back in a different place. `ROUGH-IN` is
deliberately not in the group: it is one of §4.1's eight defaults, since "how far along is this
run" is what the rough-in table is already about, where these seven answer "what did we actually
do" on a second visit weeks later.

*The parsers are in core and every one of them refuses with a sentence, because null is already
taken.* An empty box means UNKNOWN and is a legal edit (G4), so a parser answering null for both
"cleared" and "nonsense" would let `62 ft 3` silently erase a measurement. That string is #585's
own example of what must not be accepted and it has a test.

*A length column is WHOLE UNITS and a decimal is refused, which is the finding worth keeping.*
`scheduleLengthCell` rounds, because docs/08 §3.2 prints `78` and cable is cut in whole feet. A
cell that accepted `62.5` would store a value its own column then displays as `63`, so the number
on screen and the number in the file would disagree the moment it was typed. **A stored precise
value is not clobbered by this**: a cell commits only when its text changes, so tabbing past a run
measured at 62 ft 6 in leaves it exactly where it is. A date is `YYYY-MM-DD` and nothing else,
because `03/04` is March and April at the same time; `DateTime.utc(2026, 2, 31)` is March 3rd and
throws nothing, so the parser compares the parts back rather than trusting the constructor.

*Three rules the columns enforce, each of them G4 at a keyboard.* A splice count keeps `0` and
blank apart, which is the entire reason §11.19.2(3) made the field nullable. `TEST` is three states
and null is NOT TESTED rather than failed, so the control can return to unknown after somebody has
answered once. And **`CERT ID` is refused on a cable with no result**: `TestResult` requires
`pass`, so accepting a certificate would write a verdict nobody gave, on the one column whose whole
purpose is to be evidence. Re-testing a failed run keeps its certificate and headroom, because
changing the verdict is not the same act as re-certifying.

*One thing the generic machinery could not do for us.* `TestResult` has no `operator ==`, as no def
in this model does, so "nothing to do" is checked in the edit action rather than left to
`buildSetEntityProperty`. Without it, filling `PASS` down a column already all `PASS` would build
sixty commands replacing objects with equal ones and cost an undo step that visibly changes
nothing.

*And the measurement the brief asked for.* #585's own framing is that "the ergonomics are the
feature, not the columns" and that "a tally that costs an inspector visit per cable has not
shipped". **Closing out sixty runs costs three gestures and three undo steps**: three fills over
sixty rows for tested, dated and credited, each one `LabelKey.fillCells`, so backing out "we marked
them all tested" is one keystroke rather than sixty. The test drives the real controller and
asserts the undo depth as well as the writes, because the depth is half the claim.

*Closed at `f580c2a`.* The AC-013 retrofit lands on `terminatedLength`, `test`, `installedBy` and
`terminatedAt`; `routedLength` and `cutLength` stay plain and read-only, and that asymmetry is a
task boundary stated in three places rather than an oversight, since #153 (M3-D/2) owns them.

**M3-C/2 (#148) closed across five commits, and the design finding is that the table is a
projection.** docs/07 §4.1's eight default columns, FIELD LABEL through ROUGH-IN, are **all already
on `ScheduleEntry`**, resolved, with the registry lookups done and the unknowns counted. So
`derived/structure_table.dart` filters and regroups rather than re-deriving, and `structureCell`
delegates to `ScheduleEntry.cell` for six of the eight. A second derivation is exactly what CR-107
deleted `StructureDrop` for, and the editor is the surface people trust most because they are typing
into it: *"the drop schedule says 78 ft and the wiring schedule says 90 ft, and nobody knows which
to bill against"*, one layer up. The widget test does not look for `LR-C6-1`; it walks every default
column of every row, asks core what the cell says, and requires that string on screen.

*What the table adds that the sheet does not have.* The room order is the **location tree's** rather
than the sheet's sort, because §4 draws the two side by side and two panels disagreeing about which
room is third is the defect nobody reports and everybody distrusts. The per-room and total counts
the status bar prints. And no preset and no filter in the derivation: an editor that hid a row would
let somebody delete a room's last drop and see nothing change.

*One design bug, caught by its own test.* `spareCount` was written as `dropCount - connectedCount`,
which makes `hasUnresolvedEnds` **arithmetically impossible to trip**: a `PortEndpoint` naming a
port nobody holds would have been reported as an ordinary spare drop, silently. Spare is counted
from the ends now, `unresolvedPort` is neither connected nor spare, and the status bar's own
arithmetic exposes the fault.

*§4.1's `conduit` column landed as `PATHWAY KIND`, and the rename is a finding rather than a
preference.* CR-016 made the conduit a first-class `Pathway`, so *"which conduit"* is already the
default `PATHWAY` column; a second column naming the same thing would undo RJ-004's demotion by
accident. What is genuinely invisible without it is the **kind**, which is what `CODE-001` reads.
Two other items on §4.1's optional list are deliberately absent and say so in the source: the
`unknown`-map columns a CSV import preserves, because there is no importer yet and a menu entry for
a column that can never hold a value is a promise about an unbuilt feature, and reel ID, cut
outright by RJ-004.

*What the §4 wireframe draws and the editor does not.* `shell_tabs_test.dart` proves no surface
*"fabricates a device, a port label or a control that does nothing"*, and a new surface meets that
for free by not drawing the control. **No tab strip**: the matrix is #149 and `[Outlets]` and
`[Pathways]` are later, and a strip whose three other tabs open nothing is `UnbuiltView` in a new
hat. AC-048 asks that the editor **open in table mode**, which one surface satisfies outright. No
`[Group into pathway]`, `[Renumber…]`, `[Import CSV…]`, `[Export CSV]` and no `Labels:` profile
pickers. A test asserts each of those six labels is absent, so the day one is built the test says
the other five still are not.

*The route replaced two menu items rather than joining them.* `Project ▸ Add drops…` (M3-C/1) and
`Add outlet…` (M3-C/5) each shipped with a doc comment saying it sat on that menu only until this
editor existed. Both are gone; `Project ▸ Structured wiring…` stands where they were, under the
name CR-110 gives it. Quick add is the bar across the top of the table and `Add outlet` the
button beneath it, which is where §4 draws each. RULE 14's menu-item pin goes **8 → 7, the first
time that number has ever gone down**, and the accelerator count did not move a fourth time.

*And the route test found a defect in M3-C/1's loop.* On a blank project the quick-add bar offers to
create the Structure device on `Enter`, keeps the line, and lets the same key commit it. **The
second press created a second Structure device.** `_plan` is computed from a document that the offer
arms mutate, and `didUpdateWidget` cannot notice, because commands mutate `RackDocument` **in
place** and the reference stays `identical`. The commit arm was safe by accident: it clears the
field, and clearing fires the text listener. It survived M3-C/1 because every test there started
from a project that already had a Structure body, which a real new project does not, so the first
thing a new user does was the one path nothing drove.

*Inline editing is four columns, and the other sixteen are named rather than forgotten.*
`structureColumnIsEditable` says which four have a `Command` to write through today, and groups the
rest by what each would need: a picker for the columns that name registry entries, a unit parser for
the three lengths, a colour control for the jacket pair. A text box that silently accepted `Cat6a`
into a `MediaTypeId` would be worse than a cell that cannot be typed into. `Link.roughInStatus` took
the AC-013 retrofit on the way, which is what wiring a field to a Command **is**.

*An editable cell is always the real control, and that is what buys the tab order.* A widget that
exists only once clicked is not in the focus tree, so `Tab` cannot reach it. Rendering the input
always makes tab order the widget order, which is why #148's three-item list, *"fill-down, tab
order, paste"*, produced **two** keymap rows and not three: a `Tab` row would shadow a framework
default to reimplement what it already does correctly.

*The two that are keys landed in a fifth scope.* `KeyScope.structure` holds `Ctrl+D` and `Ctrl+V`,
both acting on the focused cell, because neither has an honest answer outside a grid and a global
row would have to decline everywhere else. The arbitration test's counts move **48 → 50**. docs/13
§3.5 called M3-C *"the largest remaining binding surface in v1, in the ungated package; if D7
regresses anywhere, here"*; the gate landed before the task, and the surface added two rows.

*Filling a rack label down is refused, and that is the feature.* Rack labels are unique where set
(CR-113), so a fill would put two rows on one panel position. The refusal comes from the same
builder a typed cell goes through, which is why `onEdit` takes a **list** of edits rather than
writing values itself: `buildSetStructureOriginProperty`'s `alsoUsedLabels` is the only thing that
can see a batch colliding with itself, and a batch checked one edit at a time against an unmutated
document cannot. A paste taller than the table is refused whole for the neighbouring reason: pasting
does not create drops, and ten clipboard rows into the last three would invent seven cables each
needing a room, a media type and a label nobody chose.

*Two test findings worth keeping.* `doc.links.values` is map insertion order and does **not** match
the table's, which sorts by `Link.order` then id, so every *"the row above"* assertion reads its
order off `buildStructureTable`; reading it anywhere else was testing a different table. And
building a `StructureOrigin` command through `buildSetStructureOriginProperty<Object?>` **compiles
and then throws at apply time**, with `(Link, String) => void is not a subtype of (Link, Object?)
=> void`, because `EntityField.set` is a typed closure, so each column names its concrete type.

*Closed at `b0ab0d7` (the row model), `80778b0` (the columns), `6c839bf` (the surface), `9bee69c`
(the route and the loop fix), `d302c7e` (inline editing) and `02c540e` (fill-down and paste).*

**M3-C/3 (#149) closed across four commits, and the claim it had to make good is arithmetic rather
than architectural.** The task reads *"one editor, two views of the same rows"*, and "the same rows"
is easy to satisfy in a widget tree and easy to lose in a tally: a grid that counted `doc.links` for
itself would be a third derivation of one fact, which is what CR-107 deleted `StructureDrop` for.
So `derived/structure_matrix.dart` is a projection of `buildStructureTable`, which is a projection
of `buildSchedule`, and the first test group asserts that the matrix's Σ **is** the table's drop
count rather than that it equals some number.

*Where the two views deliberately disagree, and why that is not drift.* The table omits a room with
no drops, because the tree beside it already lists every room and forty empty bands would push the
drops off the screen. The matrix must show it, because **a `0` cell is where a person types `2`**,
and a bulk-entry grid you cannot enter the first drop on is not one. Which locations get a row is
`LocationKind`'s answer rather than a second notion of "room": `room`, `zone` and `outdoor` take
drops, and a `site`, `building` or `floor` gets a row only when it already carries one, which an
import or a reparent can produce and which hiding would hide cable somebody paid for.

*A cell is a TARGET and not a delta, and that is the finding worth keeping.* The surface hands over
the number a person typed and `planMatrixCell` works out what it means against the current document.
A `+1` computed by the widget is `+1` against whatever it last drew, and the thing a grid of sixty
cells does most is go stale: an undo, a typed line, another cell's gesture. The count it reads back
and the rows a decrement then takes come off **one** call to `buildStructureTable`, so the number a
person saw and the cables that go are the same list. A cell already at its number produces no
command at all, because tabbing across a row commits every cell it passes and an undo step per
keystroke is not a grid.

*§4.2's decrement clause, read exactly.* "The highest-sequence UNCONNECTED drops" means last in the
table's own order, reusing that comparator rather than inventing a second one, so the runs that go
are the ones visible at the bottom of the room's band. A landed run is **stepped over**, not taken
and not made to refuse the whole gesture; the refusal is for when there are not enough spares, and
it names the floor the cell cannot go below rather than only saying no (CR-017's spring-back).
`unresolvedPort` is takeable, because a `PortEndpoint` naming a port this document does not hold is
a fault rather than a connection and refusing would make the fault permanent.

*The one question §4.2 does not answer, answered.* An increment creates a plate, exactly as the
typed line does. **The matrix does not know about plates**: a cell is a room and a cable, and a real
plate is mixed media (§4's `WP-1` carries Cat6 and RG6), so no cell can correspond to one. The
tempting rule, join the room's first outlet, is worse than it looks, because it puts speaker cable
on a TV plate somebody else created. So the plate count is one per gesture, §4.2's own `Outlets`
column is where that is visible rather than hidden, and a decrement never takes the outlet with it.
That is `planOutletFromTemplate`'s rule from the other side.

*The spinner became a number box, which is #148's argument again.* §4.2 draws "integer spinners";
six rooms by nine media is 54 of them and 108 arrow buttons, each costing a click where a keystroke
does, and a pair of arrows is not in the focus tree in a way `Tab` can walk across a row. Rendering
the real input makes tab order the widget order, so **this task added no `kKeymap` row either** and
the arbitration count stays at 50.

*The keybindings stayed wrapped around the whole editor, which looks looser and is stricter.*
`Shortcuts` only sees a key when the FOCUSED widget is inside it, so scoping `Ctrl+D` and `Ctrl+V`
to the table body would have made them silently do nothing whenever focus sat in the quick-add bar,
which is the exact thing `kNoCaretForFill` exists to prevent. On the matrix they say so instead.
Filling a count down a room column would be a legible gesture, but *"eight rooms all get four
Cat6"* makes 32 cables and an outlet each from one keystroke, and that is a ruling rather than an
afternoon.

*What the tab strip did to #148's absent-controls test.* `Matrix` left the list and `Outlets`
joined it, which is the bookkeeping that test is for: the day one is built it says the others still
are not. `+ Room` is absent and is **not** owed, because the loop above the grid already creates a
room on `Enter` and CR-112 puts the second path in the top-level location surface, the `Site` view
since DR-168 (it read `Project ▸ Locations…` here until then); a third would be a third
place one rule lives. `+ Media column` has no "create new type" row, which is M4-P2's editor.

*And §4.2's tinted `EMT` column is absent, which corrects a pointer rather than deferring a
feature.* `seed_media_types.dart` said `isPathwayOnly` "belongs with the Structure matrix's EMT
column (#149)", and that reading does not survive contact: the flag's whole purpose is that such a
media type creates a `Pathway` instead of a `Link`, and **nothing in this product creates a
`Pathway` at all**. Seeding the flag alone would mark three types with a fact no code could act on,
and tinting a column would claim CR-109 holds when it does not. It goes to **#156** (M3-E/1), which
owns `Pathway.kind` and `containsLineVoltage` through to the UI. Until then the drop line and the
matrix both make `Link`s out of `Office: 1x ENT`, which is a pre-existing CR-109 gap this task
found rather than introduced, and both source comments now name the right task.
**Discharged at `b093062` (the drop line) and `2618272` (the column)**, and the deferral was worth
its cost: building the tint here would have shipped a cell that accepted a number and read back `0`,
because a DR-032 pathway recorded neither its medium nor its room until **DR-035** said it must.

*Closed at `30a3a6f` (the grid model), `096daf7` (the cell planner), `263f403` (the tab and the
route) and `13c42a0` (the derived docs).* Core 1937, UI 785, app 765.

**And closing #149 surfaced a capability M3 promises, draws and has never had a task for: a
structured run's service is `structure.undetermined` forever and no gesture can change it.** #587
is the task; it is a **decomposition gap rather than a scope change** (§8.3), because docs/07 §4.1
already promises the capability and §4's wireframe already draws a SERVICE column reading
`HDBaseT`, `Ethernet`, `CATV`, `Speaker`, `Keypad`, none of which any gesture can produce.

*The starting value is right and is not what is missing.* §4.1 calls `Service: undetermined` *"a
first-class, encouraged state"* and `seed_outlet_templates.dart` says the instantiating gesture
*"must NOT copy `service` onto the Link"*. What is missing is the second half of §4.1's own
sentence: *"the DRC validates RETROACTIVELY when a `Service` later assigns a real family"*. **There
is no later.** `buildAddHomeRunCommand` hardcodes the family with no parameter, `Service
.signalFamily` still carries the pending-AC-013 marker, there is no `LinkField` row, and the four
`signalFamily` references in `rackpal_ui/lib` and `apps/rackpal/lib` are all the schematic
building a NEW link from two ports.

*Three things look like they set it.* `@service=camera` sets the label tag and nothing else, and the
planner does not warn, because as far as DR-023 is concerned the modifier was applied. An
`OutletTemplate`'s `OutletDrop.service` is intent, and docs/02 §6.2 prints both facts in one file on
purpose. And #148 grouped the SERVICE column with `MEDIA` as *"needs a picker, not a text box"*,
which is true and insufficient: there is no Command behind the picker.

*It is load-bearing for M5 rather than cosmetic.* SIG-001 (#272), SIG-002 (#273) and LEN-001 (#284)
all read the service family, so LEN-001 cannot know a run is Ethernet and §4.1's own worked example,
*"an HDBaseT run patched into a switch throws the error it should, when it should"*, cannot fire on
any drop this product creates. There is no workaround either: re-drawing the run in the schematic
does give it a real family, and strips the `structureOrigin` that made it a drop.

*Why it is filed as RULING NEEDED.* docs/07 §5.1's import table maps a `service` column to
**`SignalFamilyId`**, and its accepted headers are a contractor's `use` / `purpose` / `function`
column. DR-023 §11.22 resolves `@service=` through an `OutletTemplate` by tag then by name, so its
value is a template handle. One word, two targets, and `@service=poe` names a family no template
carries. **M3-F cannot be written until this is settled**, because #159 has to know what a
contractor's `Use` column becomes.

**M3-D/2 (#153) closed at `36994ef`, and the ratification it was written to obtain had already been
granted.** The task has two halves and only one of them was work. Its ruling half asks for
`Outlet.nominalRunLength` to be *"ratified or overruled before anything reads it"*, on the ground
that four sources of one number with three of them documented is how a schedule comes to disagree
with itself. **DR-026 §11.25.2 ratified it as implemented, provisionally, on 2026-08-09** and found
that the deadline had passed long before: the tier shipped at M2-B, `whole_house` sets the field on
all seventeen outlets while setting `cutLength` on none, and the ruling says in terms that #153
*"ratifies behaviour that already ships"* and that M3-D/2 is unblocked by it. Recorded here because
the ruling reasoned FROM `ScheduleLengthSource`'s doc comment, and that comment carried no pointer
back, so the one place a reader would look was the one place the answer was not. It now cites the
ruling, and so do docs/08's two derived sentences, which named only the room estimate.

*The build half is the retrofit M3-J/3 deferred, in the three places it said so.* `routedLength` and
`cutLength` take the AC-013 conversion and gain `LinkField` rows, which is one change and not two:
this model's standing note is that a field converts *"as each is wired to a Command"*, so converting
without wiring claims a Command that does not exist and wiring without converting leaves the field
writable behind the command stack. All three of AC-024's lengths now go through `parseLengthCell`,
so the three columns cannot disagree about what `62.5` means.

*The artifact is that a printed sheet changes what it claims.* `_lengthOf` reads `cutLength` first,
so filling the column promotes a row from an italic estimate to an upright measurement, and
**clearing it demotes the row back to the estimate rather than to a blank**. The second direction is
the one that matters on a jobsite, and it is the one a chain built to run forwards only would have
got wrong: a number typed into the wrong row has to be retractable to what the takeoff believed.
The room subtotal follows the promotion, because a subtotal still adding the nominal after somebody
measured is a figure nobody can reconcile against the sheet's own rows.

*Two tests changed and the second one is the finding.* `structure_table_test.dart` asserted that CUT
and ROUTED were **not** editable; that case existed to keep #585's task boundary deliberate, and the
boundary is what this task removes, so the assertion follows it and says so in place. The other is
worth more than its diff: `schedule_screen_test.dart` in **`rackpal_ui`** built a fixture with
`..cutLength =`, and the moment the setter became `@internal` that became an
`INVALID_USE_OF_INTERNAL_MEMBER` warning against a gate whose threshold is zero. **The AC-013
boundary caught a real cross-package write on the first build in which it could**, in a widget test
nobody would have thought to audit, and the fix was to use the constructor every other field on that
same Link already used.

*What it does not do.* It adds no length SOURCE: the chain is still the four tiers DR-026 ratified,
and the plan-derived bound DR-020 §11.19.2(2) describes is not among them and will not behave like
them when it lands. It does not touch `LEN-002`, which is M5's, and it does not give the two new
columns a place on any rendered sheet, which is M6's under DR-027.

**M3-D/3 (#154) closed at `8361c15`: `derived/cable_footage.dart`, AC-024's second change.** The
takeoff is a **third reader of the one schedule derivation** rather than a second scan over
`doc.links`, and that is the design rather than convenience. `ScheduleGroup.footage` already sums a
ROOM for the person walking the house; this sums a MEDIA TYPE for the person at a counter deciding
what to buy, which is #585's own distinction: *"how much cable to order, not how much went in the
wall."* Building it off `buildSchedule`'s rows is what makes the two numbers unable to disagree
about a length, a media type or which cables are real pulls (docs/08 §3.1), and a test drives that
seam directly by setting a cut length and watching the sheet's subtotal and the takeoff's line move
together.

*The G4 rule is the task, and `Rollup.fromScan` is where it already lived.* A media type nothing
known contributed to is **null and not zero**, because `0` reads as *"buy none"* to the person
holding the page, and a room whose lengths simply have not been entered must not print as if it
needed no cable. The waste figure of an unknown subtotal is unknown too: ten percent of *"we do not
know"* is not a number. Nothing here re-spells the rule, which is `totals.dart`'s whole argument for
being a factory rather than a shared function.

*Only `fieldCable` reaches a purchase quantity, and the fourth exclusion is the one worth defending.*
Jumpers and power cords are assemblies bought by the piece and docs/08 §2.2 gives them their own
rollup, so folding them in would both double-count them and put a patch cord into a spool order;
`internal` is a link inside one device. **A run whose class nobody has established is excluded as
well**, on the strength of `kUndeterminedClassGroupTitle`'s own comment: its footage *"must not join
a room's subtotal ... it is the number an installer orders cable against"*. Ordering is precisely
what this rollup is for, so that argument applies with more force here, not less. All four are
counted by reason.

*The waste factor is applied at the rollup and never written back to a `Link`.* Baking it in would
make an installer's measured 62 ft read 68 ft on the sheet they measured it against, and would
compound the next time somebody changed the setting. The arithmetic is integer permille (CR-001):
`Permille.toFraction()` exists but its own comment calls it display-only, and a takeoff is
arithmetic somebody buys against.

*`_isQuantity` is an exhaustive switch with no default arm, and that is a decision about a feature
that does not exist yet.* DR-020 §11.19.2(2) rules that a plan-derived bound *"never enters the
footage rollup as a quantity"*, and DR-029 puts the Plan view in v1 before M6. A `default: true`
would admit that bound to a purchase order silently on the day the source is added; this way the
build stops and a person decides.

**The box count is NOT built, and the reason is the one canon §11.19.7 already wrote down.** AC-024's
example ends *"→ 3 boxes (1000 ft)"*. `MediaTypeDef` has **no packaging field**, and no shipped
media type carries a sourced package size, so a box count means hard-coding 1000 ft as a universal:
false for RG6, for 16/4, and for anything on a reel. Adding a nullable `packageLength` and dividing
where set would be worse, because that is the exact shape §11.19.7 refuses, a field null on all 38
behind a rule that compiles, passes its own fixture and never fires on a real document. **Owed, with
the missing field named**, rather than faked. Nothing in roadmap §2 or docs/08 §2.2 requires it:
both say *"footage rollup by media with waste factor"* and stop.

*No surface, and that is DR-027 rather than an M3-D/1 repeat.* Nothing outside its tests calls
`buildCableFootage`, which is the shape §8.1 refused for M3-D/1. The difference is a ruling: the
materials rollup belongs to `T6.30`, DR-027 §11.26.2 puts every rendered sheet in M6, and §11.26.4
names the derivation as the load-bearing half M3 owes. Recorded so the next reader does not mistake
one for the other.

**M3-D/4 (#155) closed at `59ea14a`, and its decision half was already made: the seam is DR-027.**
The task asks
to *"decide the seam"* between M3's exit criterion, which says a rough-in *"exports a Pull Sheet"*,
and `sheet_def.dart:15-20`, which assigns that sheet to M6. **DR-027 §11.26.2 ratified exactly the
seam #155 proposed** on 2026-08-09, on the user's *"M6 is where sheets are going to be rendered and
I'd like to work those issues out all at once"*. So the task's remaining content is the
demonstration, and the demonstration was genuinely absent.

*Every part of clause 3 was tested and the clause was not, which is a distinction §8.1 makes and a
suite cannot.* The sort, the room grouping and the footage rollup each had passing cases in
`schedule_test.dart`. **None of them had ever been pointed at the same document.** A milestone whose
evidence is three unit tests over three fixtures has demonstrated three mechanisms; the clause is a
compound claim about one rough-in, and `pull_sheet_clause_test.dart` is that rough-in: three rooms,
two pathways, six drops, and lengths deliberately mixed between measured, estimated and unknown.

*The fixture is built to falsify rather than to agree.* Rooms are created Kitchen, Attic, Bedroom
and pathways Riser, Attic Run, so the expected output is never the insertion order and a build that
merely preserved it fails instead of coinciding. The Bedroom exists for one assertion: a room where
nothing is known reports **`null` and not `0`**, because a `0` subtotal on a Pull Sheet reads as
*"this room needs no cable"*. Kitchen carries the mixed case, where a cut 52 ft and an estimated
45 ft both count as quantities, one drop supplies nothing, and the estimate is counted separately so
the subtotal's standing stays visible.

*And the last case asserts the seam itself, in executable form.* `SheetRole` is pinned to its three
values, so if a `pullSheet` role ever appears that case fails and whoever added it has to say
whether M3's clause or M6's now owns the sheet. **The clause's "initial boxes" are deliberately not
asserted anywhere in M3**, because DR-027 gives them to M6 along with the layout and the page;
claiming them here would be the checklist-ticking §8.1 refuses, on the one clause that has already
been amended once for exactly that reason.

*One derived row corrected.* docs/13's M3-D row described the straddle as a live tension. It now
cites the ruling that ended it and names the test that demonstrates M3's half.

*No Pull Sheet column changes, and that is worth stating because the task's title implies some.*
docs/08 §3.2 gives the sheet one length column, `LEN`, which is the cut length; `ROUTED` and
`TERM. LEN` are Structure-editor columns under `⚙ Columns` and were never sheet columns. M3-D/2
made both enterable without adding either to any sheet.

**M3-D IS CLOSED as of `59ea14a`** (board #86, four tasks). Its own one-line brief was *"the same
gap the net names had"*, and all four halves of it are discharged: both drop labels allocate through
the one format engine (M3-D/1 at `b4b9115`, demonstrated by M3-C/1's caller), all three of AC-024's
lengths are Command-backed and enterable (M3-D/2 at `36994ef`), the footage rollup by media applies
its waste factor at the rollup and reports null rather than zero (M3-D/3 at `8361c15`), and clause
3's derivation is demonstrated on one rough-in (M3-D/4 at `59ea14a`).

**Two of its four tasks turned out to be already-answered questions, and that is the pattern worth
carrying into M3-E.** #153 asked for a ratification DR-026 §11.25.2 had granted, and #155 asked to
decide a seam DR-027 §11.26.2 had ruled, both on 2026-08-09 and both AFTER the tasks were written.
Neither task was wrong and neither was empty: what remained in each case was the build half plus the
work of recording the ruling where the code and the derived documents would be read. **A task
written before a ruling should be re-read against canon before it is priced**, which is #153's own
warning ("the task must not be picked up and priced as preventive") generalised by a second
instance. M3-E/2 (#157) is the next task in this milestone with a DR-026 clause behind it.

*What M3-D leaves for other milestones, stated so none of it is mistaken for a gap.* `LEN-002` reads
`MediaTypeDef.maxRunLengthPassive` and is M5's (canon §11.19.7). Every rendered sheet, including the
Pull Sheet and T6.30's materials block, is M6's under DR-027. A packaging field for AC-024's box
count does not exist and is deliberately not invented (see M3-D/3 above). And the plan-derived
bound, which DR-020 §11.19.2(2) forbids entering the footage rollup as a quantity, arrives with the
Plan view; `_isQuantity`'s exhaustive switch is what will stop it entering silently.

**M3-E opened 2026-08-09, and the census found the entity could not be created at all.** #156's
title is *"`Pathway.kind` and `containsLineVoltage`, modelled through to the UI"*, and both fields
sat at their constructor defaults on an entity **no gesture in the product could produce**. There
was no create command, no accessor table and no editor; the only writers of `doc.pathways` were
`RemoveLocationCommand` clearing the two location references during DR-021's cascade. So
`Link.pathwayId` could never point at anything real and every drop's `PATH` cell was the unknown
marker by construction. **This is M3-C/1's finding again**, *"nothing in the app ever materialises a
port"*, and it was found the same way: by censusing before pricing.

*Filed as #591 rather than absorbed into #156.* A decomposition gap and not a scope change (§8.3),
on #587's precedent: CR-016 makes the pathway first-class, docs/07 §4 draws a `[ Pathways ]` tab,
docs/08 §3.2 prints the column. The capability was promised and no task owned the gesture. Closed at
`bcb1b31` with the four fields retrofitted, a `PathwayField` table, an add and a remove.

*The delete is deliberately not a cascade, and the distinction is the design.* DR-021 makes deleting
a `Location` take its subtree and clear nine references **because a location contains things**.
Nothing lives inside a pathway. So nothing else is destroyed: `Link.pathwayId` is cleared on every
run through it, each one recorded so undo restores both, and the cable survives having lost its
recorded route, which is the state every drop in this product was in until this commit. A dangling
id would print a `PATH` cell identical to *"nobody said"*, which is the G4 failure.

**And the user named where a pathway will actually be set, which caps how far the Structure editor's
tab should go.** On 2026-08-09: *"Pathway will likely be set in the plan view, once a pathway is
actually determined and set on site."*

That is **DR-020 applied to the pathway itself**. §11.19.1 rules that the route is *discovered, not
designed*, because structure forces a run through a crawlspace instead of an attic and nobody knows
which until the framing is open; DR-026 §11.25.1 already used that reasoning to make
`Pathway.designator` hand-entered, calling an established trunk *"an as-built fact"*. The statement
extends it from the designator to the entity: a pathway is created when somebody has walked it, and
the Plan view is where they will be standing.

Two consequences, recorded rather than left in a conversation. **docs/07 §4's `[ Pathways ]` tab is
still owed and should be built small**: a list and an editor for what exists, not the place a
pathway is born, and certainly not a routing surface. And **the Plan view epic (#588) carries this
as an inbound expectation**, so pathway assignment is not discovered late by whoever decomposes it;
DR-029 sequences that epic before M6, so it is not far off. Neither is a ruling and neither is
recorded as one: this is a stated expectation about a surface, and the ruling that would move any
scope has not been asked for.

**#156 is closed, and it took five commits because it was four obligations wearing one title.** The
title names two fields reaching a UI; the task's own comments added CR-109's
`MediaTypeDef.isPathwayOnly` and DR-020 §11.19.4's open enum question, and §4.2's tinted `EMT`
column was routed here by this board (above). Closed at `719fa34` (the flag), `a9ecede` (DR-031's
`attic` and `crawlspace`), `b093062` (DR-032, a conduit drop line builds a `Pathway`), `d5d36b8`
`b3facd5` `620aa8e` (the `[ Pathways ]` tab) and `2618272` (the `EMT` column). Core 1948 → 2013,
UI 791 → 807, app 766 → 784.

*The tab is a list and an editor, and that cap is the user's.* Seven columns, the whole of `Pathway`
minus the two location references, with `KIND` and `LINE VOLTAGE` as the controls M5's `CODE-001`
and `CODE-002` were waiting on. **No rule fires there and a test in each package asserts the
silence**, because "the validation is missing" and "the validation is M5's on purpose" look identical
from outside. There is no routing surface and `[Group into pathway]` is still unbuilt, which is
DR-020 §11.19.1 applied to the entity: the route is discovered, not designed, and the user said the
Plan view is where somebody will be standing.

*Two defects were found by building it, and both were surfaces contradicting themselves.* The status
bar's `8 pathways` counted only pathways **that had drops in them**: `outletCount`'s rule applied to
the field beside it, coherent until DR-032 made `Office: 1x ENT` build a pathway and no cable, after
which the bar read `0 pathways` on the keystroke after somebody made one. Its test asserted
`pathwayCount, 1` on a two-pathway document, which is house style's "a defect asserted as intended
behaviour" caught in the act. And the `EMT` column could not have worked as drawn: a matrix cell is a
target, and a DR-032 pathway recorded neither its medium nor its room, so the cell would have
accepted a number and read back `0` forever. That is **DR-035**, taken before the column was built
rather than discovered by shipping it.

*Three tests were asserting absences that this task filled, and all three said so in their own
comments.* `structure_matrix_test`'s "the seed columns are eight, and EMT is not one of them", its UI
twin, and `structure_editor_screen_test`'s unbuilt-control list. That is the bookkeeping those
assertions were written for, and it worked: each one named the day it would come due.

*What M3-E still owes.* #157, which DR-026 §11.25.1 already ruled and is a build rather than a
decision. And #158's single-instance assumptions.

**M3-G opened 2026-08-11 with a census, and the drill is REFUTED BY CONSTRUCTION before anybody
starts a stopwatch.** #163's instruction is *"run the drill EARLY, on a rough build ... a drill run
on a rough build finds them while the design can still move."* Read as a procedure that is a person
and a clock. Read as an instruction it is **find the reasons the drill cannot pass while they are
still cheap**, and two of them are reachable from a grep. Neither needed fifteen minutes of anyone's
time to find, and neither would have been visible from the suite: 2206 tests were the M1 precedent
that #163 quotes, and this milestone's are green over both holes.

*The criterion, clause by clause. **Rows carry the ruling that last touched them, not the
commit this section was written at.** The earlier form of this caption read `against 01c698d`,
which is 2026-08-10. **DR-040 superseded two of these rows on 2026-08-11, the following day.** The
caption was still accurate the moment it was written and stopped being so before anyone read it
again; DR-095 §11.94.8 took it as current on 2026-08-26 and built a ruling on it.*

**THE MARKS BELOW REPLACED A `State` COLUMN ON 2026-09-15 (`#92`, DR-095 §11.94.6).** It read
`needs a person`, `BUILT`, `BUILT as derivation`, `REACHABLE` and `M6's`, and none of those is one of
§0's seven. Each row was re-read against a named run rather than renamed: `BUILT` became
`DEMONSTRATED` only where a test asserts the clause itself on one document, which
`drop_line_planner_test.dart`'s whole-drill test does for four rows at sixty drops, and a row that
could not name one would have been marked `BELIEVED`. None had to be.

| # | Clause | Mark | Evidence |
|---|---|---|---|
| 1 | 60 drops entered in under fifteen minutes | **CONFIRMED**: by the user, closed 2026-08-27 | The 60-drop drill (`#89`, `#163`–`#165`), closed on the operator's confirmation that it was run and verified. **What the record does not hold**, and says so rather than infers it: the run's date and elapsed time, `verify_drill.dart`'s output, and `#164`'s operator conditions. **Asked on 2026-09-15, the operator does not remember the time**, so it is not recoverable. docs/16 §4.1 records only run 1, 2026-08-13, as `UNVERIFIABLE`. The surface half is gated: the script is 433 keystrokes, 7.22 per drop (`drop_line_planner_test.dart:874`) |
| 2 | 60 `Link`s each with one `fieldLabel` | **DEMONSTRATED** | `packages/rackpal_core/test/structure/drop_line_planner_test.dart:874`, *"THE WHOLE DRILL, MINUS THE HUMAN"*: docs/16 §2's ten lines through the real planner on one document, sixty links, sixty distinct field labels asserted as a set |
| 2b | ...and one `rackLabel` | **DEMONSTRATED** | The same test: forty-six distinct rack labels on the landed drops and none on the fourteen open ones, which DR-022 §11.21 rules have none. Built by DR-040 §11.39 (M3-K, `#661`, `#663`–`#666`) |
| 3 | Pull Sheet sorted by room then pathway, per-room footage subtotals | **DEMONSTRATED** | The derivation M3 owes under DR-027 §11.26.2, asserted on one rough-in by `packages/rackpal_core/test/derived/pull_sheet_clause_test.dart:218` (room, then pathway, then designator) and `:249` (per-room subtotals that state what they could not measure) |
| 3b | ...as a sheet, with initial boxes | **NOT BUILT**, parked on M6 by DR-027 | `SheetRole` has no Pull Sheet value; the sheet, its initial boxes and the page are M6's (§11.26.2) |
| 4 | fourteen of them have unbound far ends | **DEMONSTRATED** | `drop_line_planner_test.dart:874`: fourteen open and forty-six landed, from `@panel=` on seven of the ten lines (DR-040 §11.39.2) |
| 4b | ...and each still schedules and carries a `W` number | **DEMONSTRATED** | `drop_line_planner_test.dart:874` asserts a `W` number on all sixty, and `pull_sheet_clause_test.dart:201` puts every drop on the sheet, unbound far ends included. `drop_entry_panel_test.dart:420`, cited here until 2026-09-15, was named for sixty drops and types nine; its name now says what it checks |
| 4c | ...and prints | **NOT BUILT**, parked on M6 by DR-027 | `#574` |

*Clause 2b and clause 4 are one hole wearing two numbers.* The shipped rack-label pattern is
`{FLOOR}{SPACE}-{PANEL}{PORT:2}` (`project_settings.dart:31`), and `{PANEL}` and `{PORT}` are facts
about a landing. Nothing in the product records a landing, so the pattern cannot render, so the
allocator is not called, so the label can only be a string a person types into the `RACK LBL` cell.
The two absences are not independent and closing either one alone closes nothing.

***`BindEndpoint` appears in zero `.dart` files.*** AC-018 §2186 names it: *"Binding it later is one
command (`BindEndpoint`) that preserves the ID, the length, the jacket, and the test result."* It is
cited in `docs/01` §535 and `docs/02` §663 as though it exists. It is specified, it is derived into
two documents, and it has never been written. **`LNK-020`, the advisory whose canonical example text
is literally `14 links have unbound endpoints`, is also unwritten**, which is M5's and correctly so,
but it is worth naming here because it is the check that would have reported this state out loud.

*What the criterion's own arithmetic requires, and why it needs a ruling rather than a build.* Sixty
`Link`s **each** with a `rackLabel`, and fourteen with unbound far ends, cannot both be literally
true: DR-022 §11.21 already settled that the fourteen *"simply have none"*, because `rackLabel` is
optional under CR-044. So the criterion means **46 landed and labelled, 14 open and unlabelled**, and
the product today makes 60 open and unlabelled. The gap is not a slow surface. It is a state the
product cannot express.

*Why this is filed before the drill rather than after it.* A refuted drill is only worth its
diagnosis, and M1's cost a person two runs to produce one. This diagnosis cost a census, which is
`.okf/practices/census-before-building.md` applied to a milestone's exit criterion instead of to a
task. **The stopwatch is still owed** and nothing here discharges #163:
what is discharged is the part that would have wasted the first run.

**The census produced DR-040 (canon §11.39) and M3-K, four tasks, #663 to #666.** The user took the
expensive-looking option, and it is cheaper than it reads: `derivePortId` is a pure UUIDv5 over
`(deviceId, portKey)`, so a pin's id is knowable before the pin exists, and DR-011.1 already rules
that ports materialise inside a command's `apply()`. `BindEndpoint` inherits both rather than
inventing either. **A third absence surfaced while the ruling was being written**, and it is the one
that would have cost the second run rather than the first: `{FLOOR}` and `{SPACE}` have **no editor
anywhere in the product**, so building the binding alone would have produced forty-six bound drops
carrying no label at all. That is why #663 lands first and why it is the cheapest of the four.

*It is a decomposition gap, not a growth, and the distinction is #591's.* The clause was always in
the criterion; no task owned the gesture. That is the third time in this milestone, after #591 (no
gesture created a `Pathway`) and #587, and all three were found the same way. **The row still costs
what it costs**: four tasks arriving at an exit criterion have the same effect on a calendar as a
growth would, and §5.2 already read M3 as `M`-at-its-ceiling before them.

**M3-K CLOSED the same day it opened, four tasks, `175ec74` `a662283` `9e68bda` `7fb2ffe`.** Each is
worth one line beyond its commit message:

*#663 was the cheapest and it unblocked the other three.* Two controls on a panel that already had
three. What made it first is that **without it the other three are unobservable**: `{FLOOR}` and
`{SPACE}` had no editor, so every rack label the binding produced would have come out absent and the
build would have looked broken for a reason that was not the binding. It also had a defect of its
own that three EXISTING delete cases caught: the dialog is a fixed 720 × 520, two new fields pushed
`Delete location` out of the detail pane, and the button now lives outside the scroll view where no
future field can take its place. The new case mounts the REAL 720 × 520 rather than the test
harness's roomier 800 × 600, with an anti-vacuity guard on §3.5's C2 precedent.

*#664 wrote a command canon has cited since AC-018 and nobody had built.* Its test group transcribes
§2186's clause rather than paraphrasing it, because the clause IS a list of what must not change and
a bind that rebuilt the `Link` would pass every endpoint assertion while losing the id, the length,
the jacket and the test result.

*#665 gave `allocateOutletRackLabel` its first caller in a milestone.* The allocator shipped with
M3-D/1 and had four callers, all in its own test file. **It was not uncalled, it was uncallable**, and
that distinction is the whole of why M3-D/1 closing green was not a bookkeeping error.

*#666 cost the drill 84 keystrokes and bought forty-six landings.* `@panel=` on seven of ten lines
takes the script from 349 to 433, which is 1.8 keystrokes per landed drop against roughly seven for a
hand-typed `RACK LBL` cell. **That ratio is the argument for it being a modifier and not a column**,
and it is measured rather than asserted.

**The drill kit is built and the stopwatch is the only thing left.** `docs/16-m3g-drill.md` carries
the script, #164's conditions form and #165's verdict form; `apps/rackpal/tool/verify_drill.dart`
reads the saved `.rmpj` and checks AC-018 clause by clause, reporting all thirteen rather than
stopping at the first failure. **The script was driven through the real planner before any person
touches it, and its first draft was wrong**: twelve drops open where the criterion wants fourteen,
caught by the verifier on the run that existed to test the verifier. It is now gated end to end,
which is the whole drill minus the human.

*What that gate does and does not settle.* It settles that the FILE half of AC-018 is achievable:
sixty drops, fourteen open, forty-six landed and labelled, every label unique as a set, and no
unbound drop carrying a rack label. **It settles nothing about the clock.** Fifteen seconds per drop
INCLUDING thinking is a human fact, #163 is still the only instrument for it, and M1's precedent is
that the two defects which refuted that drill were invisible to 2206 passing tests and were found by
a person opening the app.

**M3-H opened and closed on 2026-08-11, three tasks, #166 to #168, five commits.** The low-voltage
box's internal geometry: `ee593c8` (DR-041), `00df1d7` (the model), `74b6734` (the four gestures),
`eccbc6a` (the plate geometry), `3358cdd` (the arrange planner), `7623c34` (the Outlets tab).

*It cost a ruling before it could start, and the ruling is most of what this entry is for.* DR-007
§11.7.8 change 3 forbade **any dimensioned rendering** until a caliper had been put on real parts.
DR-038 discharged the cell on 2026-08-10 and named in the same breath what was still missing: the
plate opening and where the grid sits inside it. That is four figures, and the task could not draw a
rectangle without them.

| Figure | Value | Provenance |
|---|---|---|
| Cell, the front nose | 14.5 × 16 mm | DR-028, ruled; DR-038 makes it uniform |
| Gang opening | 33.34 × 66.68 mm | **Measured 2026-08-11**, confirming §11.7.8's "about" to 0.04 mm |
| Cell pitch, vertical | 22 mm | **Measured** |
| Cell pitch, horizontal | 15.95 mm | **Measured**, after being derived to 15.947 |
| Gang pitch, horizontal | 1.8125 in | **A STANDARD NOBODY MEASURED**, and it says so in the source |

***A wrong figure was refuted by arithmetic before it reached a line of code, and that is the part
worth reusing.*** The gang pitch arrived as **22 mm**, which cannot coexist with a 33.34 mm opening:
two openings 22 mm apart overlap by 11.34 mm. **The check is one line and needs no tools, a pitch
cannot be smaller than the opening is wide**, and every figure in the table above sits in an
inequality with at least one other. The reading was real; it was the *vertical cell* pitch, and what
recovered it was the user's own question, *"are we speaking vertically or horizontally?"*, which
exposed that the request had never named an axis. §11.7.9's lesson was that a physical reference
beats a careful reading; this adds that **arithmetic beats a physical reading that was answering a
different question**. `plate_geometry_test.dart` carries the five inequalities as a test, so the
class of error is gated rather than remembered.

*One figure was derived before it was measured, and the corpus records the order rather than the
agreement.* Even margins across the opening give 15.947 and the caliper gave 15.95. The derivation
was offered as an option and labelled as exactly the inference change 3 forbade. **Agreement after
the fact is not evidence the inference was safe before it**: an even-margin layout is one
manufacturing convention among several, and a wider centre web would have satisfied every stated
constraint while breaking every 4- and 6-port drawing.

*What was built, clause by clause against the ruling as it now stands.*

| # | DR-007 clause | State | Evidence |
|---|---|---|---|
| §11.7.1 | `W ∈ {1,2}`, `H ∈ {1,2,3}`, and five ports do not exist | **BUILT as a derived constraint** | `isValidStrapSize`; no set literal of `{1,2,3,4,6}` exists in the package, and the test enumerates the bounds rather than transcribing the table |
| §11.7.2 | every occupant is 1 × 1 | **BUILT** | no orientation field, no occupant span, no packing search anywhere. `plate_arrange.dart`'s header says why looking for one would be a defect |
| §11.7.2.1 | cells are a function of TERMINATION | **BUILT** | `cellsRequiredFor`; `TerminationType.bindingPost` added, which the ruling names as "the smallest change that makes this table computable" |
| §11.7.3 | `Outlet` gains an ordered gang list | **BUILT** | `Outlet.gangs`, positional, no minted id, on `ConductorRef`'s argument |
| §11.7.4 | blank inserts are occupants, not absence | **BUILT, and it is the invariant that would have been invisible if got wrong** | an absent cell entry is undecided and a `BlankInsert` is a purchase; collapsing them would order two blanks for every unfinished plate |
| §11.7.5 | the keystone follows the convention | **BUILT by consumption** | `outlets_view.dart` reads `ResolvedJacketColor.keystone` and never `jacketColorPulledId`; the exception prints as text and never as a hue |
| §11.7.7 | the printing half stays at M6 | **UNCHANGED** | `T5.01` is not touched. M6 now inherits a settled geometry |
| §11.7.8 ch.1 | one N-gang cover plate, N = `gangs.length` | **BUILT as a getter** | `PlateFill.coverPlateGangs`. Storing it would be CR-107's second copy of one physical fact |
| §11.7.8 ch.2 | the grid is CENTRED in the opening | **BUILT** | and the tests assert the SYMMETRY rather than the margins, because a test pinning "cell 0's top is 13.36 units" passes on a top-anchored renderer that happens to have the first row right |
| §11.7.10 | does the gang enter the field label | **RULED: no token** | the user, on 2026-08-11: *"There's no need for this when the plate diagrams will have each keystone labeled."* A label is printed on cable at rough-in and which gang a jack ends up in is decided at trim-out, so a token would go stale on the wall. No `IdFormat` grammar change |

***`kSchemaVersion` did not move, and fixture (f) rather than gangs bolted onto (c) is why that is
evidence instead of an assertion.*** Fixtures (a) to (d) are checked-in bytes written before `gangs`
existed and they regenerate byte-identical, because an empty gang list emits no key. Mutating (c)
would have proved the encoder while destroying the proof. That is fixture (d)'s own argument, reused
one milestone later.

*The commands landed in the same change as the field, and that is the practice paying rather than
being cited.* `.okf/practices/a-modelled-field-is-not-a-reachable-one.md` records four fields that
were modelled, persisted, round-tripped and read by several consumers with nothing able to set them,
each found while implementing something else. **`Outlet.gangs` would have been the fifth**: it had a
codec, a golden fixture and a derived rollup before it had a writer. It has four now.

*Two defects were found by writing the widget tests, not by shipping them.* A `Spacer` inside a
`Wrap` threw on every pump, which no analyzer catches. And the cell picker returned a bare
`CellOccupant?`, in which `Clear it` and a dismissed dialog are the same value: **pressing Escape
would have erased a cell**, a destructive cancel, and the kind of thing found by accident three
weeks later. It returns a record now and a case drives the dismissal.

**M3-H/4 closed the same day, `bed4639`, and it is DR-041's own mechanism paying out.** The two
things the entry above listed as open, the plate outline and the unmeasured gang pitch, were both
measured within the day: **2.75 × 4.5 in** and **1.8125 in**, DR-042 (§11.41).

***Nothing was superseded and nothing was withdrawn, which is the whole return.*** §11.40.4 left the
gang pitch a **stated choice rather than a ruled figure**, on §11.27.2's rule that an unruled figure
with provenance outranks a ruled figure without one, and predicted that a later caliper reading would
win *"with nothing to withdraw"*. It did: **no §12 row, no supersession entry, no corpus edit
reversing an earlier claim.** §11.27.2 records the other path costing a retraction inside the
normative document within hours. The rule is worth one sentence in a source file: **when a figure is
needed before it can be measured, record it where a measurement can replace it silently.**

*The check that carries DR-042 is an invariant rather than an inequality, and that is a new shape.*
Neither figure had an inequality to test against, because both were new. What tested them is that
the plastic between a plate's edge and its outermost opening comes out **18.255 mm for every gang
count**, which holds only if the outline formula and the pitch are *both* right and drifts with `N`
if either is wrong. Evidence about the pair, not a restatement of one of them.
`.okf/practices/a-dimension-sits-in-an-inequality.md` gains it as a second instance: **where a single
figure has an inequality, a set of figures has an invariant.**

*What the measurement bought that a reader can see.* The Outlets tab drew each gang as a
free-floating box with an arbitrary gap, which is a picture of some holes. It draws **one plate with
N openings at the real pitch** now, with real plastic around the edge, so §11.7.8 change 2's *"blank
plastic above and below"* is something a person can look at rather than something the corpus asserts.
**Three defects surfaced getting there and all three are the kind that ship**: `cellAt` returns plate
coordinates while each gang widget's box *is* its opening, so a missing rebase would have shifted
every cell by 18 × 24 mm and still looked like a plate; a 3-gang plate is 647 units wide and the pane
gave it 287, so it clipped, and a clipped dimensioned drawing looks correct while omitting a gang;
and a cell-size assertion comparing doubles by identity caught a `64.0` against a
`64.00000000000003`, because `DBox` stores corners and `(top + h) − top` is not `h` for every `top`.

**What M3-H does NOT settle, as it now stands.** The **strap's own plastic** outside the opening,
which §11.7.9 B keeps invisible because the cover plate hides it in every elevation this product
draws, and **anything in depth**, which §11.7.9 C files as a box-fill fact and box fill is not v1.
Neither blocks a drawing. **DR-007 §11.7.8's three changes are fully discharged and no figure in the
keystone geometry is an *"about"*.** **Nothing here touches M3's exit criterion**, which DR-007 §11.7
states outright: a 60-drop rough-in schedules and prints without knowing which cell a keystone
occupies. This is the milestone growth that ruling booked in advance, delivered.

**M3-L opened and closed on 2026-08-11, three tasks, #671 to #673, plus two rulings.** The field
termination gets entry paths: `4561baf` (DR-043), `a644a07` (multi-select), `17905dd` (the template
field and the item grammar, with DR-044).

*Why it exists.* M3-H's `Arrange` reads DR-007 §11.7.2.1's cell-count table, which keys on
`StructureOrigin.terminationField`. **Nothing in the product set that field**, so `Arrange` correctly
refused every drop the product could create. Found by running the feature, which is how all five
instances of `a-modelled-field-is-not-a-reachable-one` have been found.

***THE BOARD ASKED FOR A MODIFIER AND THE MODIFIER IS NOT THE LOAD-BEARING FIX.*** #668 proposed
`@term=` on the drop line. The question raised beside it was whether a mouse path exists at all,
because *"typing a large amount of text is going to put off a lot of people"*. **A modifier serves
the person already typing.** A census found **five** drop-entry surfaces, four of them already
mouse-driven, and `+ Add outlet ▾` is the one a mouse-first person lives in: it was also the only
route that could not express a termination. So `OutletDrop.termination` is the load-bearing change
and the colon grammar ships beside it.

*The same census corrected #668's own arithmetic.* That task claimed sixty drops meant ~420
keystrokes of `FIELD TERM`. It is a **dropdown**, and `Ctrl+D` fills it down: one dropdown plus
fifty-nine keypresses. **The task overstated the pain by about seven times**, and the estimate came
from reasoning about a surface rather than opening it.

***DR-043 WAS WRONG ONE CLAUSE DEEP AND A CENSUS CAUGHT IT BEFORE A LINE WAS BUILT.*** §11.42.5 left
the shipped templates null because *"a shop authoring its own template says what it terminates in"*.
**Nothing in this product can author an `OutletTemplate`**: no command, no editor, and
`seed_outlet_templates.dart`'s own header says so. The field would have been null everywhere for
ever. DR-044 seeds all nine. **This is the fifth instance of that practice and the first caught
BEFORE the field was written** rather than in the next milestone.

*A euroblock occupies zero cells, correcting M3-H.* §11.7.2.1's table does not mention `euroblock`
and M3-H put it beside `keystone` on an inference nobody wrote down. It is a screw terminal on a
device: the keypad fills the gang, and a plate sized to give it a keystone as well is one cell too
big on every keypad drop in a house. **Found by seeding a value and having to say what the value
meant.** A fact you write down gets audited; a fact you infer does not.

*Asking beat offering, and one row is the evidence.* Twisted pair seeds as **`punchdown`**, not the
`keystone` that was recommended. Face-on the two are the same object (§11.7.9 B) so no drawing
changes, and the **Termination Schedule** does: the recommendation would have looked right and
printed a false column on every data drop in every job.

***AND A SENTENCE OF DR-044 WAS FALSE, REFUTED BY THE GOLDENS WITHIN THE HOUR.*** §11.43.6 claimed
`registries.outletTemplates` is `{}` in every shipped starter. **All four carry all nine**, and
`starter_assets_test.dart` failed on every one. The claim was **inherited verbatim** from a paragraph
on `OutletTemplate.tag` where it had been false since DR-022: those starters carry `tag` on six
templates on disk today. Doc comment, to second doc comment, to normative ruling, in three steps and
one afternoon, each step looking like a citation of the one before. **A sentence asserting a count is
not checkable by reading the sentence**, and what caught it was a test that reads the bytes.

*What M3-L does not settle.* **There is still no authoring surface for `OutletTemplate`**, so a shop
cannot write its own recipe; DR-024 §11.23.4 already holds that open and DR-033/DR-034 place it in
the community-catalog work. §11.43.5 records it as a live cap on DR-043 §11.42.2's argument rather
than a discharged one. The batch bar also offers only the columns the table is SHOWING, so `FIELD
TERM` must be switched on through `⚙ Columns` before it can be bulk-set.

**M3-H/5 (#674) closed 2026-08-12 at `f8c4481`, and it is a defect M3-H shipped.** Nothing deleted a
gang. `RemoveGangCommand` was built and tested including undo, `OutletsActions.onRemoveGang` was
declared, and `buildOutletsActions` implemented it with its bounds check and refusal sentence.
**No widget invoked it**, so the only ways to remove a gang were `Ctrl+Z` and a full destructive
`Arrange`. **Found by the user asking what the current method was**, which is the same instrument
that found #591, #587 and #668: using the thing.

***IT IS THE SIXTH INSTANCE OF THAT PRACTICE AND IT SITS ONE LAYER ABOVE WHERE THE PRACTICE
LOOKS.*** `a-modelled-field-is-not-a-reachable-one` says *"grep for what WRITES it"*, and **the field
had a writer**. What it lacked was a caller for the callback in front of that writer, so the check as
written passes on this defect. `gang_commands.dart`'s own header argues that its commands shipped in
the same change as the field precisely so `Outlet.gangs` would not be the fifth instance. It was not.
This was.

*Why nothing else saw it, which is worth more than the fix.* A declared-and-implemented callback
hides **better** than an unreachable field, because both ends are present and only the middle is
missing: the analyzer sees nothing unused (the record is constructed with every member and passed to
a child), the app-side implementation has passing tests, the command has passing tests including
undo, and every reader compiles. The only absent thing is a widget saying `actions.onRemoveGang(...)`,
and **no Dart type can require one**.

*So it is a gate rather than a habit.* `actions_have_callers_test.dart` scans every function-typed
member of a `*Actions` record in `rackpal_ui` and fails when one has no call site: **18 callbacks,
one hole** on its first run. **It was watched failing before being trusted** and names the offender
exactly. It skips nested records deliberately, because `StructureEditorActions.dropEntry` and
`.outlets` are passed rather than invoked and a naive scan reports both, and a gate that cries wolf
on its first run is a gate people learn to ignore.

*The gesture itself.* A small delete beside each gang's strap picker, adjacent to the thing it
deletes rather than folded into a dialog labelled `6-port` or behind a right-click this app teaches
nowhere. It confirms and **counts what it discards** when the strap holds anything, and goes without
a prompt when it does not, because a dialog for a gesture that destroys nothing trains people to
dismiss dialogs.

*Two of the author's own errors were caught by gates rather than by the author.* `draw_source_gate_test`
refused a production comment citing `outlets_actions_have_callers_test.dart` when the file is
`actions_have_callers_test.dart`. And **the first draft of the undo case asserted nothing and
passed**: it built a FRESH `RemoveGangCommand` to revert one already applied, which finds the index
out of range on an empty gang list and no-ops. The harness now hands back the command it actually
ran, which is the only version of that assertion that means anything.

**M3-M opened and closed on 2026-08-12, two tasks, #676 and #677, one commit `bda1276` plus DR-045.**
Requested from the field rather than from the model: AVoIP and HDBaseT vendors recommend against a
keystone plus a patch cable, and access points mount straight to the box with no plate at all.

*What was missing, and it was two things.* `TerminationType` had no value for a **male plug**:
`keystone` and `punchdown` are both a jack, and `fieldConnector` names no connector, so the
Termination Schedule could not tell somebody whether to reach for a crimper. And a **plateless outlet
was indistinguishable from an unfinished one**.

***THE CELL COUNT WAS ASKED, NOT ASSUMED, AND THAT IS DR-044 PAYING.*** `rj45Plug` occupies zero
cells. The identical guess was available for `euroblock` at M3-H, was taken silently, and cost a
correction one milestone later. **A termination's cell count is now a question this project asks out
loud every time the enum grows**, which is the cheapest possible form of that lesson.

***THE PLATELESS OUTLET IS A G4 DEFECT M3-H SHIPPED.*** `_NoGangs` read *"This outlet has no gangs
yet. Add one, or press Arrange…"* for an AP box that is **finished**, so a correct plate read as
unfinished work. It is DR-007 §11.7.4's blank-insert-versus-empty-cell distinction one level up and
got wrong the same way: *nobody has said* and *somebody said no plate* are different facts. **The
derivation was never wrong**: `PlateFill.isSettled` has returned true for a plateless outlet since
M3-H, and only the sentence threw it away. Three arms now, and an unknown termination sits in the
third, because "needs no plate" over an unrecorded termination is the guess that omits a part from a
materials sheet.

*Two smaller findings.* The plate pane and the drop list said the **same sentence** for an empty
outlet, noticed only because a finder matched both, which is the same duplicate-copy collision the
batch bar hit with the status bar at M3-L/3. And an M3-H test asserted the collapsed sentence, so it
is four cases now, one per arm.

**#678 IS FILED AND NOT BUILT.** Asked how many cells a plug occupies, the user answered *"zero, but
the plate is a separate question"*: some off-plate runs still come through a **pass-through or brush
plate**, which occupies no strap cell and **is a purchasable line item**. §11.7.8 change 1 separates a
strap from a cover plate; this is a **third** object with no strap behind it, and
`PlateFill.coverPlateGangs` structurally cannot express it because it returns `gangs.length` and a
plateless outlet has zero gangs by construction. Nothing is wrong today; the materials sheet simply
does not know about a part that gets bought.

**M3-N closed 2026-08-12, one commit `422e2e6` plus DR-046.** Reported as *"the rack termination
shouldn't be automatically set by the field termination"*.

***IT WAS WORSE THAN AUTOMATIC: THERE WAS ONLY ONE FIELD.***
`StructureOrigin.terminationField` is documented as *"how the WALL-PLATE end is finished"*.
`FIELD TERM` read it, and `RACK TERM` read it too by way of `_terminationOf`. **Two columns, one
value, since M3-C.** So a speaker run with a phoenix connector at the panel and binding posts in the
room was not awkward to express, it was **inexpressible**, and the column most people saw showed the
other end's data: `RACK TERM` was a **default** and `FIELD TERM` was **optional**.

***THE 90 % IS THE ARGUMENT AGAINST A DEFAULT, NOT FOR ONE.*** The user's own figure is that nine
Cat6 runs in ten match at both ends, and that is exactly why nothing copies: if the product fills the
second field, a schedule can no longer tell a stated value from an assumed one, which is the defect
being removed wearing a different hat. The convenience is a **gesture**, `Rack term: same as field`
on the batch bar, which writes real values, lands as one undo entry, and **skips rows whose field end
is unknown** rather than copying *"nobody has said"* into a second column.

*The drop line takes a second colon*, `2x 16/4:binding post:euroblock`, field first. One colon still
means the field end alone, so every line written under DR-043 parses unchanged.

**#679 IS FILED AND NOT BUILT.** The **printed** Termination Schedule's `TERM` column still resolves
to the field end, so the sheet and the editor now disagree about what `TERM` means. Splitting or
renaming it re-lays a twelve-column landscape page whose 690 pt is already allocated, and **DR-027
§11.26 moved every sheet to M6 for exactly this reason**. §11.45.5 records the inconsistency as
**stated** rather than hidden.

> **RULED 2026-08-13 as DR-055 (§11.54), and the census restated the problem before it solved it.**
> #679's framing, *"the sheet and the editor disagree"*, is the smaller half.
> **`terminationRack` reaches no printed output anywhere**: its only consumer in the tree is the
> editor's own column, and `rackmate_export` holds not one reference to any schedule column. It is
> absent from the one sheet that drops every row where `!row.landsInRack`, sorts
> `rackThenPanelThenPort` and groups by rack, so **the rack-side work order could not state the
> rack-side termination.**
>
> ***THE ARGUMENT WAS ALREADY ON THE SHEET, ABOUT ITS OTHER COLUMNS.*** §3.3 prints both ends of
> identity (`RACK LABEL` / `FIELD LABEL`), location (`RACK / RU / FACE` / `FAR END`) and port
> (`PORT` / `FAR PORT`). Termination was **the only per-end fact collapsed into one column**, filed
> in the *spec* block beside `MEDIA` as though it belonged to the cable. DR-046 ruled that collapse
> wrong in the **model** and nobody carried it across. That is DR-053's lesson recurring inside a
> day: a rule argued for one entity is evidence about its neighbours.
>
> *The width objection dissolved on reading §3.4.* The sheet is 690 pt and fully allocated, which is
> what made this look expensive; §3.4 has always said a new column's width comes from
> `CONDUCTOR / NOTES` first and then `MEDIA`. Applying the sheet's own rule fits the thirteenth
> column with no new decision, and Σ stays 690.
>
> **Still M6's, and the ruling ships no code.** §11.26.4 keeps the derivation in M3 and it was
> already done; a `header` and a `widthPt` are presentation. Board **#693**. `rackmate_export` has
> no schedule renderer at all, so there is no page to re-lay while the constant waits. docs/08 §3.3
> is edited to match rather than pointered.

***FOUR OF THE AUTHOR'S OWN MISTAKES, AND ONE IS A PATTERN WORTH THE ENTRY.*** A six-space search
string matched **inside** an eight-space line, so a scripted replace hit the same site twice; the
wrong duplicate was deleted; and `buildAddHomeRunCommand` ended up taking the new parameter without
forwarding it. **The field parsed, planned, and then vanished**, and every layer looked correct in
isolation. It was found by probing the chain end to end rather than by reading it, which is the same
instrument that found #591, #668 and #674. The other three: a guard comparing against `kUnknownCell`
when `_valueFor` already maps that to `''`, so it never fired; a test harness mirroring `fieldTerm`
but not `rackTerm`; and three column tests that pinned the old default set. **Every one of the four
was caught by a test rather than by review.**

**#678 closed 2026-08-12 at `911258f`, ruling `8f673cb`, and the ruling is the interesting half.**
The task and canon §11.44.6 both frame it as *"is the pass-through plate a property of the OUTLET or
of the DROP"*. **It is neither**, and a census before pricing is what said so.

***THE DISTINCTION WAS ALREADY HALF-BUILT AND THE FIELD'S TYPE WAS HIDING IT.*** `Gang.strap` is
`Strap?`, and null already meant *"nobody has picked a part yet"*. A brush plate is a gang opening
somebody **decided** gets no strap, so the two states were sharing one spelling. That is DR-007
§11.7.4's cell distinction at a **third scale**: a cell (no entry versus `BlankInsert`), an outlet
(no drops versus needs-no-plate, §11.44.4) and now a gang. **Each of the first two was got wrong
once and cost a correction a milestone later**, so this one was ruled before a line of it existed.

*Both named options were live and both are refused, with reasons.* The **drop** buys nothing:
`StructureOrigin.outletId` is non-nullable, so every drop already has an outlet to hang the fact on,
and it costs three claims about one physical object for three runs through one brush plate. The
**outlet** cannot express a mixed plate (one 2-gang cover, a strap behind one opening and a brush at
the other), and it duplicates a fact the gangs carry, which is the shape CR-107 deleted
`StructureDrop` over.

***THE VOCABULARY WAS ASKED AND ONE OPTION WAS DECLINED, WHICH IS §11.44.2 PAYING A SECOND TIME.***
`brush` and `bullNose`, because the user names a whole brush plate, a Decora-format insert and a
bull-nose or grommet plate as parts they buy. **A keystone-format brush insert was offered and
declined**, so there is no fourth `CellOccupant` and nothing here touches a strap's cells. A
declined option is evidence; an unasked one is not.

*The plate is derived and the rule is a fact about stock.* `derived/plate_materials.dart`: every
opening a pass-through of **one** style is one integral N-gang plate, anything else is a Decora plate
plus one insert per brushed opening. Nobody manufactures every Decora-plus-brush combination, and
mixed styles fail the same way, which is why the rule keys on *one style* rather than on *all
pass-through*. **No field records which form was bought** (§11.27.2): a shop stocking inserts rather
than brush plates can be served later by an override that wins with nothing to withdraw.

**ONE SENTENCE THE PRODUCT USED TO SAY IS NOW A GUESS, AND IT IS SAID DIFFERENTLY.** A plate with
openings and nothing fitted read *"3-gang cover plate"*, which was true while there was one kind of
plate. It reads *"3-gang plate, kind unknown"* now, because an unfitted opening could still make the
whole plate one integral part. **One strap anywhere settles it**, so the finished plate is unchanged
and only the half-built one is newly honest. `CoverPlateKind` has five values rather than a nullable
style, on `EquipmentMounting`'s precedent: *"no plate at all"* and *"nobody can say yet"* are
different facts.

***THE DEFECT THIS CHANGE WOULD HAVE SHIPPED IS IN `Arrange`, AND BOTH ENDS WERE GREEN.*** That
gesture rebuilds a plate from nothing, so a brushed opening would have been **deleted by a gesture
nobody thinks of as destructive**. Core proves the plan carries the pass-throughs to keep, and
`outlets_view_test.dart`'s harness **reimplements** arrange without the loop that re-fits them, so
neither suite could see the twenty lines in between. `apps/rackpal/test/session/outlet_plate_actions_test.dart`
is new for exactly that reason: **`buildOutletsActions` had no test of its own**, which is
`callbacks-have-callers` one layer along. It was **watched failing** with the loop disabled before it
was trusted.

*Two of the author's own mistakes were caught by the gates rather than by the author, again.* The
both-keys refusal case mutated its fixture with a `replaceFirst` on `'"strap":{'`, which matches
nothing because the file is written with a 2-space indent (CR-091): **it asserted a refusal against
an untouched document and passed**, and now decodes, injects and re-encodes instead. And
`plate_materials.dart` sat **untracked** while all fourteen local gates were green, which
`verify_tracked_sources` named exactly, on the barrel export it had already been added to.

**#587 closed 2026-08-13, DR-025 delivered whole.** The task named three things: the Command
(`515d61e`), the modifier (`48ae15b`) and the picker (`80fd007`, on `a1c5a8e`, `379a9cd` and
`22aa6d6`). Until the last of them the SERVICE column was read-only, so `@signal=` on a drop line
was the only way to state a family and **a run created before the ruling could never be corrected**.
§11.24.5's *"the DRC validates RETROACTIVELY when a `Service` later assigns a real family"* now has
its later.

***THE CONTROL WAS CHOSEN BY MEASUREMENT AND THE MEASUREMENT CONTRADICTED THE OBVIOUS ANSWER.*** A
`DropdownButton` was the natural fit, since three choice columns already use one. Its menu inherits
its **button's** width; SERVICE is 76 points, the 55 seeded labels average 22 characters and reach
45, and a throwaway harness put the menu at **116 points wide with every row clamped to 84**. So
`AUD·Speaker level, low-Z` and `AUD·Speaker, constant-voltage 70 / 100 / 25 V` both render
`AUD·Speaker…`. The three enum columns keep their dropdown because `PULLED` and `RJ45` fit, and that
asymmetry is `structureColumnChoicesAreRegistryBacked` rather than a taste.

*The filter box is not a text box, and the difference is the whole task.* SERVICE was grouped with
MEDIA as *"derived, needs a picker not a text box"*; a box that committed what was typed would put
that straight back. It narrows and never writes, and it matches on the tokens `@signal=` already
accepts, so `hbt` finds HDBaseT and the product does not acquire a second vocabulary for one fact.

***A CRASH WAS CLOSED THAT THIS CHANGE WOULD OTHERWISE HAVE INTRODUCED.*** `DropdownButton` asserts
exactly one item matches its value, and `typeCell` prints a bare id when a `Service` names a family
the registries do not hold: a spelling no menu offers, so the **whole table** would throw rather
than one cell misbehaving. The enum columns cannot reach it because the enum **is** their menu, which
makes SERVICE the first column where a document can say something its control cannot represent. The
cell degrades to read-only text, and the state is separately made unreachable below.

**A GATE WAS MISSING AND NOBODY OWNED THE GAP.** A `PortDef` carries two registry references and only
the connector half was gated; `registry_parity.py` compares the seeded registry against
`pal1_check.py` and does not look at the catalog at all, and its concept file's stated blind spots do
not cover this because it is a third thing rather than a corner of the second. `catalog_ports.dart`
builds `SignalFamilyId(family)` from a raw string and `AtomicConnectCommand` carries it onto both the
`Service` and the `Net` with nothing in between to object. Measured before the test was written: 48
parts name 34 distinct families and all 34 resolve, **which is a fact about this catalog on this date
and not an invariant**. `379a9cd` makes it one, and proves the check by mutation rather than by
reading.

*Two defects in the in-flight work are recorded because both are instances of named practices.* The
tests typed `V·AV-over-IP` and `V·HDBaseT 5Play`, which are the shapes **canon §11.24.1's prose**
uses and which the catalog spells nowhere: `verify-codebase-claims-by-reading`, in the session that
most needed it. And the UI harness had no `service` arm, so it returned *"That column cannot be typed
into"* on a column the app applies, four lines below a comment added by M3-L/3 saying **"a harness
stricter than the product tests a product that does not exist"**.

**One consequence worth a later look rather than a task.** Groups run in domain-id order, which is
`schematic_filter.dart`'s order and is why it was chosen, so `video.digital` sorts **last** and
`VID·HDBaseT (5Play)` lays out some 1800 points below the fold. The filter box is what makes that
reachable. If a second surface ever wants domains in trade-frequency order, that is a change to both
lists or to neither.

**DR-074 IS BUILT (`#720`, phases `#721`–`#725`, `af79813`, `229fde2`, `c967d8b`, `fb50f67`,
`fb7811d`).** A drop punched into the wrong port can be moved, and either end can be taken back off
its jack. This closes the gap DR-040 §11.39.6 opened and which DR-071 §11.70.4 and DR-073 §11.72.7
each recorded as still owed; both keep their own words and carry a pointer, because each is that
ruling's record of what was true on the day.

**THE MOVE IS ONE COMMAND WITH ONE UNDO ENTRY**, which is the clause worth the record: unland then
re-land costs two steps and leaves the document momentarily saying a cable nobody has moved is lying
loose in the rack. Three things survive a move and each survives for its own reason, so each has its
own test: the freed pin (`ConnectPortsCommand`'s rule), the termination (it says how the cable END is
finished, not which hole it is in), and a hand-set rack label.

**THE HAND-SET LABEL NEEDED A BIT, AND THE BIT COULD NOT BE A TABLE ROW.** `StructureOriginField`
drives every other origin field through `SetEntityPropertyCommand`, whose `revert` calls the same
`set` closure `apply` does. A row that locked on the way in would re-lock on the way back out, so an
assertion would survive its own undo. `SetRackLabelCommand` writes the pair instead, on
`SetLinkClassCommand`'s precedent, and the `@internal`-setter agreement test names the exemption
literally so a second field escaping the table still fails it.

**THREE FINDINGS CAME OUT OF WRITING THE TESTS RATHER THAN THE CODE, and all three are copy.**

* **A move never exhausts a panel**, because a moving cable frees the hole it leaves. The first
  test written asserted the opposite from arithmetic. What DOES refuse is a panel whose only free
  position is the one this cable is in, and the refusal it hit said *"that drop was not landed"*:
  telling a person their cable is loose when it is exactly where they left it, which is the worse of
  the two things they can believe about a rack they cannot see. A move now has its own sentence.
* **`buildBindEndpointCommand` was still telling users a move is impossible** (*"not something this
  can do yet"*), four commits after it became possible. Its test asserted
  `contains('already landed')` and would have gone on passing over copy that had become false; it
  now pins the whole sentence.
* **The corpus has three spellings for one physical state.** `AddHomeRunCommand` wrote *"not yet
  landed"*, the shipped starters say *"Rack end not yet terminated"* on 27 open ends, and an unland
  needed a third. `_endOf` prints that string straight into the schedule's TO column, so this is
  what an installer reads. The two paths CODE controls now share `kUnlandedEndDescription` (*"not
  landed"*, settled by the user 2026-08-19); **documents already on disk and the authored starters
  keep their own words**, because the description is persisted and rewriting it would move the bytes
  of every file holding a drop (CR-117).

**ONE CORPUS GAP FOUND AND NOT CLOSED HERE.** `docs/10-decisions.md`'s short-form table **stops at
DR-036** while canon is at DR-074: thirty-eight rulings have no summary row. Adding one row for
DR-074 alone would make an abandoned table look current, which is worse than an obviously stale one.
Recorded as a task somebody should take deliberately.

**#702 IS BUILT (DR-076, phases `#728`–`#731`).** The schematic no longer rebuilds the whole document
on every edit. Measured at 3,600 links, best of five: a cold build is ~96 ms, the `holdAt` path a
wire edit used to take is ~90 ms, reusing the layout is ~46 ms and reusing the whole symbol tier is
~20 ms. **On the shipped 300-link fixture (a house with one rack, which is what M2's criterion was
written against) a wires-only rebuild is 0.913 ms against a 16.7 ms frame**, and that case now
fails if an edit ever costs a frame.

**THE ISSUE'S OWN PRESCRIPTION WAS THE SMALLER HALF, AND THE MEASUREMENT IS WHY THE RULING EXISTS.**
#702 cites AC-008's eight per-domain sub-pictures. Symbols alone, with zero links, are ~75 ms and
49,860 of the 78,660 ops, and they are domain-independent: a perfect eight-way split cannot touch
them. AC-008 is retained and **resequenced** (§11.75.6) rather than withdrawn.

**THE MECHANISM WAS ALREADY IN THE TREE AND NOTHING READ IT.** `DocEpochs` has carried six
independent notifiers since M0, with its own doc saying they exist so a widget can subscribe to
exactly the epochs it cares about. The schematic collapsed all six into one `_sceneEpoch`. The
invalidation matrix the issue asked for was therefore mostly written already, per command, in every
`touches` declaration.

**WHICH EDIT GETS WHICH PATH IS WORTH RECORDING, because the headline figure is not the common one.**
Seven commands declare `wires` alone (a link class, a jacket colour) and eight declare
`wires | meta`, including every connect, bind and move, because materialising a port mints a
designator. So **drawing a cable takes the ~46 ms path, not the ~20 ms one.** Splitting `meta` into
device-affecting and link-affecting would close that and is a new epoch channel and a new ruling.

**TWO CORRECTIONS TO THIS TASK'S OWN RECORD, kept because both were caught by measuring rather than
by review.** The ruling first quoted single-run figures where this repo measures best-of-N, which
made the cold build read 144 ms instead of 87. And it claimed a full rebuild "reshuffles the sheet
under the cursor of the person who just drew a wire" as though that happened today: it does not,
because `holdAt` already prevents it, and the 88-of-91 figure is what that hold buys.

**A TEST WAS VERIFIED BY MUTATION AND THE RESULT CHANGED WHAT IT CLAIMS.** The rename case asserts
§11.75.3's "symbols rebuild, layout does not". With the reuse removed, a rename to `MTX-9` still
moves nothing, and so does `MATRIX-SWITCHER-MAIN-RACK-1`; only a ~180-character designator makes a
full rebuild demonstrably move the sheet. **At any name a person would type, both paths agree on
this fixture**, so §11.75.3's reuse is justified by cost rather than by an observed churn, and the
test says so where a later reader would otherwise tidy the absurd length away.

### 5.3 M4, The device builder · `L` · CRITERION MET, weakest mark `CONFIRMED`

> **Exit criterion, verbatim.** A 16×16 matrix template is authored from scratch **in under three
> minutes by a user who has seen the tool once**, and a template saved with exactly three fields plus
> ports places into a rack and appears correctly in the equipment list with `—` in every unknown
> column and an accurate unknown count in the rollup.

*The criterion, clause by clause (`#92`, DR-095 §11.94.6).* **This section had no clause table until
2026-09-15.** Both marks were already recorded, in §5.3.7 and §5.3.30, and are gathered here rather
than re-judged.

| # | Clause | Mark | Evidence |
|---|---|---|---|
| 1 | A 16×16 matrix template authored from scratch in under three minutes by a user who has seen the tool once | **CONFIRMED**: by the user, 2026-08-15 | §5.3.7: **93 seconds** on the build carrying `ce5f70f`, checked in the footer at 68 ports across 6 banks. The archetype path (`#250`) took 46 seconds on 2026-09-01 (§5.3.30) |
| 2 | A template saved with exactly three fields plus ports places into a rack and appears in the equipment list with `—` in every unknown column and an accurate unknown count | **CONFIRMED**: by the user, 2026-09-01 | §5.3.30, `#251`: a dash in every unknown column, each stated as unknown, read off a printed sheet. `clause2_drill_expectations_test.dart` checks the drill's script and says in terms that it does not discharge the clause |

**M4 IS CLOSED. BOTH CLAUSES OF THE CRITERION ARE CONFIRMED**, each by a drill a person ran, the
second of them on 2026-09-01, and §5.3.1 through §5.3.30 below are the record. **95 chapters are Done under this
epic and none was left open or re-parented**, which is the count `v0.4.95` is derived from.
The last story to close was M4-Q (`#188`, the drill, which is a person and not a chapter). M4-K closed at §5.3.26 with `#227` parked by DR-105 §11.104.6;
**DR-106 §11.105.1 then lifted the park and `#227` was built at §5.3.27**, under `#804` rather than
by reopening a closed story, because §8.9 makes closing the binding moment.

**THE SENTENCE THAT USED TO OPEN THIS SECTION NAMED SEVEN CLOSED STORIES AND WENT ON NAMING THEM
FOR SIX MORE**, which is the drift this document exists to prevent and had no gate against. It read
*"M4-A through M4-E, M4-G and M4-H are CLOSED"* while M4-I, M4-J, M4-L, M4-M, M4-R, M4-S and M4-T
had all closed behind it. A reader taking it at face value would have re-opened work that shipped.

M4-A through M4-C are machinery under no surface at all; **M4-D builds the
surface**, **M4-E builds the product** and **M4-G makes it fast**, which is the pair that moves the
exit criterion at
all. A 16×16 matrix can now be authored from scratch, and **M4-G types one in eight lines**
(§5.3.6). Whether it takes **under three minutes by a user who has seen the tool once** is the
clause still open, and it rests on the drill (M4-Q, `#188`) alone.

**A pattern across all five, and the next one should expect it.** Every one was written from a
field's or a type's ABSENCE, and every one turned out to be partly a corpus question rather than an
authoring job: M4-A found its required-fields "contradiction" was a Dart constructor read as a
product rule, M4-B found `genderApplies` was a complete transcription already sitting in canon §6.3,
M4-C found docs/06 §7.2's change-class table was examples rather than a specification, and M4-E
found §4.5's column table names **nine columns with no model field** while the model carries
**eight fields no column names**. **Four for four, the first useful hour went into reading, not
typing.**

#### 5.3.1 M4-A, `Command` goes generic · CLOSED · `e964e28`, `881cdbe`

**Four tasks, two commits, and the arithmetic is the finding.** #189 (the interface), #190 (the
stack) and #191 (the migration) are one commit, because Dart will not let them be three. An
override's parameter type must be a supertype of the base's, so every `apply(RackDocument doc)`
stops overriding the moment `Command` gains `<A>`, and all 36 subclasses break in the same instant.
The escape, leaving `UndoStack` holding a raw `Command`, is closed by `strict-raw-types: true` in
`analysis_options.yaml`: `strict_raw_type` is a **warning**, and warnings are gated at zero. #192 is
the second commit.

**The blast radius was 38 files, not the ~24 the task estimated**, and the difference is where
nobody looked: `List<Command>` also appears in four structure planners
(`drop_build`, `drop_line_planner`, `matrix_plan`, `outlet_template_planner`), in
`csv_import_apply.dart`, and in both of the app's session action files. The estimate counted
`packages/rackpal_core/lib/src/commands/` and stopped there. It is a census miss of the ordinary
kind: the noun searched for was the directory, not the type.

**`EpochMask` became nullable, and null is NOT `EpochMask.none`.** `none` asserts a command touched
no epoch. Null says the aggregate has no epoch model to touch, which is true of a
`Command<TemplateBody>` and of nothing else. This is G4's shape applied to a mask, and the reason
it matters is mechanical rather than philosophical: a document command returning `none` invalidates
nothing, so the model changes and the canvas does not repaint. `epoch_mask_test` now asserts that
every `Command<RackDocument>` declares one, which is an assertion the nullability made both
possible and necessary.

**M4-A/4 needed a piece no task had written down, and filling it is a decomposition gap rather than
an amendment (§11.24.7's test).** "Discarded on close-without-save" cannot be implemented while the
session edits the library's own `TemplateBody`: dropping the stack would leave every cancelled edit
in memory for the next device placed from that template to pick up, and no test reading only the
undo stack would see it. `TemplateEditSession` therefore deep-copies, via `copyTemplateBody`, new in
`json_codec.dart`. CR-106 and `TemplateBody`'s own header comment both already promised the
capability; no task was ever cut for it.

**The copy is a codec round trip, not a hand-written clone.** `TemplateBody` has ~50 fields and
eight growable lists, and a clone drifts the first time somebody adds field 51, where a forgotten
field is a *list shared between the copy and the original*. The encode/decode pair is already under
CR-117's gate, so a field the copy loses is a field the file loses, and that gate fails first.

**Two tests were watched failing, and both watchings changed the tests.** With `copyTemplateBody`
sabotaged to `(b) => b`, the two identity tests fail and the 48-template byte sweep **passes**: a
body compared with itself is trivially byte-identical. So the sweep catches a copy that *loses* a
field and the identity tests catch one that *shares* one, and neither covers the other. Separately,
the field-table test was rewritten after watching it: write-then-read one field at a time passes
when two descriptor rows are pointed at one body field, and write-all-then-read-all fails, because
the second write clobbers the first. Confirmed by aliasing `model` onto `manufacturer`.

**What M4-A does NOT deliver, stated so nobody reads the closure as more than it is.** There is no
builder window, no form, no port grid, and nothing in `rackpal_ui` or `apps/rackpal` reaches
`TemplateEditSession` at all. Its file header says so rather than leaving it to be discovered, per
`a modelled field is not a reachable one`. **The row above is now `L`** to match roadmap §6 and
§5.3's own re-derivation, which had moved the estimate while this heading still read `M`.

**The required-fields question this section first filed as open was NOT open, and the correction is
worth more than the question was.** It read: #175 names three required fields as `displayName`, RU
height and `typePrefix` while `TemplateBody`'s constructor requires `manufacturer`, `model` and
`displayName`, so which binds? **Neither answer was needed, because they are not claims about the
same thing.** AC-049 rules the FORM's required set, docs/06 §1 and §3 state it, and the constructor
is a Dart signature the builder satisfies by supplying values. A constructor parameter was read as a
product rule. This is `re-read a task against canon` failing in its own documented shape, and the
cheap check it prescribes, one grep of §11 for the task's nouns, would have caught it.

**The census run to check it did find a real unruled question, and that is DR-056 (§11.55).**
`docs/06` §3.1 has always said `manufacturer` *"Defaults to `Generic`"*, in a derived priority-3
document, justified by a sentence about the seed. Whether that reaches a USER's untouched field was
never ruled, and it is a printed difference: `equipment_list.dart:428` trims blank to null and
`equipment_sheet.dart:606` prints `—` for it, so a blank manufacturer is an unknown on paper and
`Generic` is not.

**Ruled 2026-08-14: the form pre-fills `Generic`, on trade grounds.** `Generic` is the industry's
standard token for *unspecified / by others* in a manufacturer column, so it is the trade's own
spelling of what `—` says rather than a fabricated value. The counter-argument, that a value nobody
typed reaches a client deliverable invisibly to the unknown rollup, **was put and answered**: it
assumed a reader parses `Generic` as a product claim, and the trade does not. Recorded in §11.55.4
as the third overrule of that class, and the generalisation is *put trade objections as questions,
not findings*. `model` stays undefaulted and still prints `—`.

#### 5.3.2 M4-B, the two registry fields · CLOSED · `b7f3534`

**`ConnectorTypeDef.pitch` and `.genderApplies` exist, are encoded and are authored.** Both were
documented from M0 and declared by neither the Dart nor the codec, which `json_codec.dart`'s own
registry-drift note recorded for `genderApplies` and nothing recorded for `pitch`.

**The two were authorable on opposite terms, and the task knew this about neither.**
`genderApplies` **was never open work**: canon §6.3 carries a complete yes/no column for every
connector id, so all 49 are a transcription, 31 true and 18 false. The task read as an authoring
job because it was written from the *field's* absence rather than from the corpus, which is
`re-read a task against canon` again. `pitch` is stated for **13 rows naming 14 ids** in
docs/catalog §5.2 and nowhere else; **6 more inherit** from a connector sharing their shell
(DR-057 §11.56.2), and **29 have none, permanently** (§11.56.3).

**The registry ships 49 connectors, not the 44 a grep said.** The count came from
`grep -c "_c('conn"`, which misses every multi-line call. Census the field, not the pattern that
happens to match most of it.

**THE FINDING IS A NEAR MISS AND IT IS RECORDED AS ONE.** Sparse pitch was measured as a feature
cut, auto-layout available on **14 of 45** templates with ports, and was put to the user as a
priced trade-off. The price was read off **docs/06 §5's pseudocode**, *"flow left → right at
`ConnectorTypeDef.pitch`"*, in a derived priority-3 document. **CR-071 §1 rules the layout is
"auto-laid-out from connector footprints"**, docs/catalog §5.2's own introduction agrees, and
roadmap §2 names only the footprint table. **No ruling mentions pitch.** The algorithm advances by
`pitch ?? (footprintWidth + gutter)` and runs on 45 of 45. The cut was never real, and the check
that caught it ran while the ruling was already being drafted.

That is the second premise error in three days, after DR-056 §11.55.1 read a Dart constructor as a
product rule. §11.56.5 pairs them: **a derived document describing a mechanism is not a ruling
about what the mechanism needs.**

**Two things the census found and M4-B did not fix.** The task names the registry-parity CI gate as
the one that moves with these fields; `tools/registry_parity.py` is **palette-only** and the gate
that actually holds them is `seed_catalog_test.dart`. And **`MediaTypeDef.isPathwayOnly` is written
and read by nothing in the codec**, so a pathway-only media type does not survive a save, which
would silently turn CR-109's three seeded conduit types into ordinary cable types on reload. Filed,
not folded in.

**What M4-B does NOT deliver.** No panel layer: `scene/panel_layer.dart` does not exist, and M4-K
(`#182`) owns the algorithm, the gutter constant and the no-cutout skip. `pitch` therefore has no
reader in `lib/` yet, exactly as `footprintWidth` has had none since M1, and both files say so.

#### 5.3.3 M4-C, `derivedFrom` and the change class · CLOSED · `b841643`, `55a89c2`, `92c6a3b`

**Three tasks, three commits, and the estimate held for the first time this milestone.** #196 the
model field and its codec, #197 the change-class computer, #198 CR-062's stale-fork rule. Nothing in
the exit criterion is discharged: M4-C builds no surface either, and the criterion is a
demonstration by a person.

**`derivedFrom` was missing because AC-042 reads like it cut the field, and it did not.** Four
documents name it: docs/06 §7.3's Duplicate row, that section's worked `.rmdx` example, docs/02 §7's
fork row and DR-015's `.rmda` provenance. AC-042 deleted the `signature` field and the
**cryptographic** provenance chain in one sentence, and DR-015 §11.15.3 separates the two halves that
ruling argued as one. This is on the kept side, beside `contentHash`. A task was written for it
precisely because anybody reading AC-042 alone concludes the opposite.

**It is NOT a `TemplateRef`, and the difference is the whole design.** A ref carries `contentHash`
because it must resolve to an embedded snapshot and prove it got the right one (CR-054). A
`TemplateOrigin` resolves to nothing in particular: the source may be a catalog archetype this
machine has never seen or a library template deleted years ago, and both are ordinary. Hanging an
integrity check on a link with no integrity to check is the apparatus AC-042 cut. It lives on the
**body** rather than beside `TemplateSnapshot.version` for `submittedBy`'s reason: a `.rmdx` has no
snapshot to hang it on, because the whole file **is** one template.

**docs/06 §7.2's change-class table is EXAMPLES, not a specification, and that is #197's finding.**
Its three rows name roughly a third of the fields a `TemplateBody` carries; the other ~70 needed a
rule. The rule adopted: **the class answers a question about a device somebody has already placed in
a project already drawn.** Safe means nothing about its placement or connections changes meaning.
Additive means something new appeared and nothing was invalidated. Breaking means a connection may
orphan, the occupancy or tiling changes, **or installed work becomes wrong**.

**That third clause is read off the doc rather than invented.** A connector retype orphans nothing;
it makes the cable already in the wall the wrong cable, and §7.2 files it under breaking anyway. So
`pinoutVariant` (AC-052 names it as the IR emitter/receiver hazard) and `polarity` (AC-030 put it on
the terminal so a typo would be inexpressible) are classed with it.

**And the table's apparent contradiction dissolves rather than needing a patch.** `depth` and
`weight` are safe while `frontU` is breaking, which reads like an oversight. It is not: `frontU`
changes how many U the device occupies, so everything below it is now in the wrong place, and
`depth` moves nothing at all: it changes a number M5 raises a **finding** from, and a finding is not
a migration. The same reading puts the clearance requirements and `chassisWidth` on the safe side
and `widthClass` / `nominalSpanTwelfths` on the breaking side, because those two decide how a device
**tiles** within a U.

**The table is gated in both directions, and that is not decoration.** The default sitting under an
unclassified field would be `safe`, which is the single wrong answer that costs somebody a job, so
`_diffMap` throws instead and `template_change_class_coverage_test.dart` greps the codec's own
encoders and asserts the two key sets match exactly. A class left behind for a field the codec
dropped fails too: a table that **looks** maintained and is not is worse than an obviously stale one.

**The gate was watched failing three times, twice for its own bugs, and the second one is a
repeat.** An arrow-bodied encoder ran into the next function, so `_encodeBankDef` "emitted"
`frontKey`. Then a `dart format`-wrapped `putIfNotNull(json, 'containerWeightCapacityUg', …)` was
invisible to a per-line matcher: **that is M4-B's 44-vs-49 connector miscount exactly, six days
later, and by the identical mechanism.** Census the field, not the pattern that happens to match most
of it.

**Two rules generalise §7.2's "new column data on existing ports".** Filling in a previously absent
fact is additive whatever the field costs to change; and a value that **only grew**, a list that
gained entries without losing any or a `maxConnections` raised, is additive on a field declared
breaking, because nothing that existed stopped existing. The counterpart is stated as a known
over-warn rather than hidden: *"retyped incompatibly"* is computed as *"retyped"*, since the compat
matrix is M5's. Over-warning on an advisory label is recoverable; under-warning ships a breaking
change labelled safe.

**#198 found a gap in CR-062 and it is DR-058 (§11.57).** The ruling says what a fork shows when its
source **was corrected** and nothing about what it shows when the source **cannot be found at all**,
which is the routine case rather than an exotic one: a project opened on a second machine, or a
library template deleted years ago, or a shelf holding only a version older than the fork claims.
Ruled by the user on 2026-08-14: **no badge on the device, and the rollup reports the count.** That
is G4 applied to a comparison instead of to a value, and a resolver answering `current` when it
merely failed to look is the same defect as a rollup that totals what it could price and omits what
it could not.

**What M4-C does NOT deliver.** No `Duplicate`, so nothing writes a `derivedFrom` and nothing calls
`classifyTemplateChange`: both are M4-D's shell (`#175`). No badge widget, no save dialog, no
library. `builder/fork_status.dart` and `builder/template_change_class.dart` say so in their own
headers rather than leaving it to be discovered, per `a modelled field is not a reachable one`. The
`rackpal_ui` paragraph below still holds unchanged.

#### 5.3.4 M4-D, the builder shell and the metadata form · CLOSED · `27bf82f`, `3d153c0`, `56c052a`, `f105481`, `675292b`

**THE FIRST M4 TASK A PERSON CAN OPEN.** `Project ▸ New device template…` opens a full-window
editor over M4-A's `TemplateEditSession`, with four sections, real commands, real undo, and a Save
that writes a `TemplateSnapshot` into the project. Four issues into the milestone, the exit
criterion still reads **0 of 2** clauses, and that is correct rather than disappointing: the
criterion is a 16×16 matrix authored in under three minutes, which needs the port grid (M4-E) and
the drill (M4-Q).

**AC-049 IS THE WHOLE SCREEN, and `_canSave` is where it lives.** Three fields block a save and
nothing else may join them: a fourth condition creeping into that getter is how this screen becomes
the thing the ruling deleted. Every optional field is optional on purpose, and the form says so
under the Identity section rather than leaving it to be inferred.

**Two panes, though docs/06 §2 draws three.** The right dock is three live previews and a batch
inspector; the previews are M4-K and the inspector needs a grid selection, which is M4-E. There is
nothing to put in a 340px dock, so it is not drawn, and the section rail lists **four** of §3's
seven for the same reason. `shell_tabs_test.dart`'s rule, and the Structure editor's own precedent:
`#148` shipped with no tab strip at all because one surface satisfied its ruling, and `#149` added
the strip when there was a second thing to switch to.

**M4-C's change class finally has a surface**, beside `[Save]` with its deciding reasons in the
tooltip, which is docs/06 §7.2's *"shown prominently before save"* read literally.

**FOUR DEFECTS AND TWO GATES, all found by writing the test rather than by reading the code.**

| | What it was | Why it mattered |
|---|---|---|
| Undo did not move the text boxes | A `TextEditingController` seeded once never hears a change it did not cause | Undo reverted the model while the field showed the typed text, and the next keystroke wrote the stale value back over the restored one |
| `_canSave`'s RU clause was `frontU >= 0` | A non-nullable `int` defaulting to `0` can never be absent, so the gate always passed | A new template saved as a 0U device: wrong for a rack-mount box and invisible on an elevation. **AC-049's own stall wearing a different hat**: a default silently supplying one of the three facts the user was meant to supply |
| The header `Row` overflowed by 18px | Too many fixed children below some width | No user reaches it (`kMinWindowWidth` is 1000), but a header that throws below a threshold is one nobody may safely add a control to, and it still owes `[Duplicate]` and `[Submit]` |
| The field-table census could not see three `bool`s | Only two values exist, so two aliased rows both write `true` and both read `true` | Its **third** shape: snapshot every field, write one probe, assert exactly one reading moved. Watched failing by aliasing `isContainer` onto `isPassthrough` |

The two gates that pushed back were both right. **`Len` and `Mass` are extension types**, so they
erase to `int` and a `case TemplateField<Len>()` is unreachable code the analyzer refuses; the `int`
probe adds 7 nanometres, which is a daft chassis depth and a perfectly good probe. And
**`internal_setter_grep_test` flagged `TemplateBody.widthClass = v`**, whose `@internal` twin belongs
to `Rack`: a NAME collision the grep's own header already documents. `src/builder/` joins the two
exempt directories, because CR-106 makes `template_commands.dart` a command file that simply does
not live in `commands/`, its aggregate being a `TemplateBody`.

**DR-059 came out of this task's census and is a §8.3 amendment in its own commit** (`27bf82f`,
canon §11.58). docs/06 §3.4 promised *"a glyph from a built-in icon set"* in one derived,
priority-3 sentence with no ruling behind it; put to the user as a scope question with a
recommendation to drop it, and ruled IN. The census had already found the better argument:
`accentColor` is authored on **0 of the 48** seeded templates and read by **no renderer at all**
(`device_layer.dart` fills every device with `palette.deviceFill`), so Appearance would have shipped
two controls and no channel that reaches paper. CR-078's *"hue is never used alone"* applies hardest
to the elevation, which is the sheet that gets photocopied and taped inside the rack door.

**Draft is derived, never stored** (M4-D/4). `ports.isEmpty && category.isEmpty`, computed, with no
model field and no codec key. A stored flag is a second source of truth that can disagree with the
body, and **a user-togglable one would restore the incomplete-template idea AC-049 exists to
delete**. Zero ports alone would have marked X01, X02 and X03 as drafts forever.

**Save writes into the project, and the form says so.** docs/06 §7.1's three storage locations,
minus the user library (M4-N), leaves per-project embedded snapshots, which every `.rmpj` has
carried since M0. A save FORKS (CR-050): `nextTemplateVersion` allocates in the caller so redo is
idempotent, and revert removes only the key it added.

**What M4-D does NOT deliver.** No port grid, no Quick Add, no panel layout, no previews, no
library, no `Duplicate & edit`, and no `.rmdx`. `contentHash` is written as a labelled placeholder
rather than a real sha256, because the hash belongs with the codec that decides which bytes it
covers (M4-M). The seventeen glyph marks are M4-K's.

**No builder surface exists** *(as recorded when M4 opened; M4-A adds `rackpal_core`'s `builder/`
directory but no UI. **M4-D ends this**: `packages/rackpal_ui/lib/src/builder/` now holds
`device_builder_screen.dart`, and the paragraph below is kept as the record of what was true when
the milestone started)*. `ls packages/rackpal_ui/lib/src/` returns exactly five directories,
`canvas/`, `draw/`, `inspector/` (`inspector_panel`, `rack_inspector_panel`, `shrink_rack_dialog`),
`palette/` (one file) and `shell/`. No `builder/`, no port grid, no form. Grep for `rmdev` across
`packages/*/lib` and `apps/*/lib` returns **nothing**, so the single-file `.rmdev` codec and its
`contentHash` warning do not exist. `TemplateBody`/`PortDef`/`TemplateSnapshot` exist in core
(`packages/rackpal_core/lib/src/model/template.dart`, `port.dart`) and are exercised only by the 48
seeded catalog templates.

**One of those five is a starting point, not an absence.** `draw/` holds
`packages/rackpal_ui/lib/src/draw/flutter_canvas.dart:52`, `final class FlutterDiagramCanvas
implements DiagramCanvas`, the on-screen backend of the same IR the PDF side replays. A port grid
is a `DiagramScene` fragment like any other, so the builder's rendering surface is the one part of
M4 that is already built and already parity-tested. That is a narrower claim than "no surface to
build on" and it is the accurate one.

**Note the second half of the criterion is partly pre-satisfied by other work.** The equipment list
already renders `—` per unknown column with an accurate unknown count
(`packages/rackpal_core/lib/src/derived/totals.dart`,
`packages/rackpal_ui/lib/src/canvas/rack_metrics_row.dart`). What is missing is any way to **author
the template** that would exercise it.

**Its gate is now clear, and the reason is worth stating precisely.** Roadmap §5 lists `M1→M4`
among the hard blocks, and §3 of this file now marks M1 **CRITERION MET**: all eight exit
clauses discharged. Under roadmap §8.1, *the exit criterion is the unit of truth*, the gate is
the criterion and nothing else, so **M4's hard block is discharged.** What is NOT discharged is
M1's goal line, *"and it ships to real users"*, and its six open checklist items (§3.3). Neither
is an exit clause, so neither holds this gate; both are real work and are tracked where they
belong. Sequencing M4 remains a priority judgement, not a blocked move.

What is true is narrower and still useful. The artifact the roadmap's `M1→M4` arrow actually names
is *"devices exist"*, and it does: `TemplateBody`/`PortDef`/`TemplateSnapshot` are in core, 48
templates place into a rack, and the equipment list renders them. **M1 has no open exit
clause left, and the one that was open longest was never an input to a device builder**: clause
3 was a keyboard drill, and a stopwatch is not a template editor. (When this paragraph was
written the list was three: rack creation, since built; the drill, re-run and CONFIRMED on
2026-07-28; and a sheet nobody had printed, which the user printed and measured on 2026-07-27.
All three are now closed, so M4's formal gate is no longer held open by any of them.)
So M4 is the milestone whose **gate is now clear and whose inputs are all
present**, which is a different and weaker claim than "free to start", and it is the one the
evidence supports.

**Two honest caveats before starting.** M4 will immediately surface **copy-on-place with
`DeviceOverrides`**, which M1 left unbuilt (nothing writes one), and **typed `PortOverrides`**, which
need the device-property editing `inspector_panel.dart:21` explicitly defers. Both are M1 debt that
M4 pays.

**Device libraries (#170) are M4 scope and are parented to epic #22: the opposite call from #169
two paragraphs down, and the difference is structural rather than a preference.** Roadmap §M4's
checklist names `.rmda` device archives as a line item, added under DR-015 §11.15.5; end-user
documentation appears on no milestone's checklist at all. Under §8.1 the exit criterion is the unit
of truth for *doneness* and the checklist is the unit of *scope*, so an item on M4's checklist
belongs in M4's rollup and an item on nobody's does not.

**The criterion is not amended to name libraries, and that is deliberate.** M4's criterion is a
demonstration (three minutes, three fields, a place into a rack) and it names none of the pattern
DSL, the media-type editor or undo throughout the builder either, all of which sit on that same
checklist. A criterion that grew a clause per checklist line would stop being a demonstration and
become a second scope list, and §8.3 says there is exactly one of those.

**Why "from the getgo" is an argument rather than a preference.** The builder's output is a template,
and until a writable library directory exists a template's only home is the project that placed it,
docs/06 §7.1 names three storage locations and only the seeded catalog and the per-project embedded
snapshots are built. So requirement 2's actual promise, *author the long tail once and use it
everywhere*, is not delivered by the builder alone. Shipping the builder and deferring the library
ships a version in which a user's second project re-authors the first project's devices, and a
builder is judged on the second project rather than the first.

**The uncounted cost: since resolved, and the paragraph is kept because the resolution is the
interesting part.** §6 sized M4 at `M`, 5–7 weeks, and that figure predated the DR-015 scope edit;
nothing had moved it. Of the five things #170 enumerates, the `.rmdx` codec was already its own
checklist line and therefore already inside the number; the library directory service, template
provenance in the palette model, the import/export surface and the palette filter were not, and
neither was parameterising the Windows file dialog, which #170 sequences before the codec. The
re-derivation was deferred to M4's decomposition (#71) on the grounds that it is the first moment
there are tasks to count against.

**M4 was decomposed on 2026-08-02 (17 issues, 63 tasks, `#172`–`#251` under epic `#22`) and the
row is now `L`, 7–9 weeks.** The +2 is exactly the DR-015 subsystem: library directory service,
`.rmda` codec, import/export, provenance, palette filter, library browser, file dialog. Roadmap §6
and canon §12.7 move with it, and the plan total goes 42–65 → **44–67 weeks**.

**Decomposition surfaced two costs that no estimate had ever held, and neither is a library.**
First, **`Command` is hard-typed to `RackDocument`**: `undo_stack.dart`'s own header records this
as deferred M0 debt and says to revisit it when the builder's stack is built. CR-106 requires that
stack, so ~24 command files move, and doing it after the builder UI exists means rewriting the
builder's commands too (`#172`). Second, **`ConnectorTypeDef.pitch` does not exist**;
`footprintWidth`/`footprintHeight` do, and `json_codec.dart:2209` records pitch and `genderApplies`
among fields the documents show and the Dart never declared. **Step 2 of docs/06 §5's auto-layout
algorithm, *flow left → right at `ConnectorTypeDef.pitch`*, cannot be written today** (`#173`).
A third, smaller one: `derivedFrom` appears nowhere in `packages/`, though the fork chain, CR-062's
stale-fork badge and `.rmdx`'s own worked example all reference it (`#174`).

**All three findings are now closed** (§8.8): `#172` at `e964e28`/`881cdbe`, `#173` at `b7f3534`,
`#174` at `b841643`/`55a89c2`/`92c6a3b`. The paragraphs above are the decomposition's record of what
it found on 2026-08-02, not a live claim about the tree.

**The number that was NOT adopted, recorded because hiding it would make the adopted one look
better than it is.** Summing all 17 issues bottom-up gives roughly **10–15 weeks**, against the
7–9 written into §6. Only ~1.5–2 of that gap is DR-015; the remainder says the pre-DR-015 base of
5–7 was already optimistic. That is a different claim requiring a different kind of evidence, 
velocity against real tasks, which this project has for M1 and M2 and not for a builder, so it is
**flagged for the first M4 task to answer with data rather than written in on the strength of a
bottom-up sum, which is the estimating method most reliably biased upward.** If M4's early issues
land near their estimates, §6 moves again and this paragraph is the receipt.

**M4 is also the trigger for end-user documentation (#169), and the reason is a property of the
milestone list rather than a preference.** The four surfaces a user spends time in arrive one per
milestone, the elevation (M1), the schematic (M2), Structure and the field (M3), the device builder
(M4). **Every milestone after M4 adds behaviour to a surface that already exists**: findings (M5),
sheets (M6), platform and access (M7), release engineering (M8), hardening (M9). So M4 is the first
point at which documenting the interface is not documenting a moving target, and it is still four
milestones ahead of anyone outside the team needing it. Writing earlier pays for the same page twice,
screenshots and step lists are the most perishable artifact in a doc set. Writing later means
writing during M9, which is the milestone that puts the product in front of people who are not the
team, and documentation discovered as a release blocker gets written by whoever is least busy rather
than by whoever knows the answer.

**#169 is not parented to this epic, and that is the same call §5.5 makes for M6.** Roadmap §8.1
makes the exit criterion the unit of truth; hanging documentation off M4 would put work M4's
criterion does not name into M4's rollup and make the milestone read incomplete for a reason that is
not its own. The post-M2 bug hunt (#96) is unparented for the identical reason. **Its first task is
scoping, not writing**: the one thing already known is that the *vocabulary* is the comprehension
barrier rather than the gestures: domain, family, net, link, service, conductor, endpoint and
template all leak from the model into the UI, several of them narrower here than in trade usage, and
a user who has not been given them cannot read the filter bar. **And the corpus is the source of
truth for that document, never the source of text**: docs/00–14 argue, cite rulings and record what
was rejected, which is the builder's genre; lifting prose from it is how a project ships a
specification with screenshots pasted in.


#### 5.3.5 M4-E, the port grid · CLOSED · `f372a8d`, `3e19c7d`, `6c1cda4`, `a36b964`, `77d7b72`, `c9dc527`, `fdf56c7`

**The first clause of the exit criterion is now reachable, and only the first.** A 16×16 matrix can
be authored in this grid; whether it takes under three minutes is M4-Q's drill (`#188`) and depends
on Quick Add (M4-G), which does not exist. Board #203 through #207 are closed.

**THE DECOMPOSITION HAD A HOLE, AND IT IS THE FINDING TO CARRY FORWARD.** M4-E's five tasks build a
grid, its columns, its packs, its validation dots and its footer. **Not one of them creates a port.**
Quick Add is M4-G, archetypes are M4-I, paste is M4-I3, and the application's only entry point opens
a blank template, so as decomposed the milestone task shipped a virtualised view of nothing. `+ Add
port` and `Delete` land with the grid instead. That is `check a decomposition for holes` in its
stated form: ask what produces each task's input. **Deleting is in none of the five either**, and a
grid you can add to but not remove from is one nobody can correct a mis-click in.

**THIS IS THE FOURTH TABLE IN THE APPLICATION AND THE THIRD WITH BANDED ROWS.**
`structure_editor_screen.dart`'s `_DropTable` already solved every structural problem it has: a
horizontal scroll carrying the header with its rows, `SliverPersistentHeader(pinned: true)` per
band, `SliverList.builder` for virtualisation, and a `LayoutBuilder` that refuses to squeeze a
column below its authored width. Copied in shape, and the columns live in **core** the way
`derived/structure_table.dart`'s do, so 49 field accessors and every rule below are tested without
pumping a widget.

##### The census, which is the reason M4-E took longer than a grid should

docs/06 §4.5 names the seven packs and their columns. Measured against `PortDef`, field by field:

- **NINE columns §4.5 names have no field to write to**: `VLANs`, `Segment`, `Address`, `Universe`,
  `Receptacle`, `Outlet mode`, `Seq step`, `Seq delay`, `Circuit`. Building a cell for any of them
  means inventing a model field inside a grid task, or shipping a control that writes nowhere, and
  `actions_have_callers_test.dart` is a gate about the second. Not built; named in the source.
- **EIGHT fields the model carries are named by no column at all**: `balanced`, `conductorCount`,
  `maxCurrentMa`, `channelIndex`, `bus.protocol`, `bus.addressable`, `power.drawWatts`, and the
  `carriedProtocols`/`acceptedFamilies` pair. They have round-tripped through the codec since M0
  with no way to author them: `a modelled field is not a reachable one`, in its original form. Six
  join the pack that already draws their neighbours; `channelIndex` belongs with port sets (M4-J2)
  and the two family lists need a multi-select the grid has no cell shape for.

**docs/06 §4.5's column table is owed an edit**, and this is the third M4 task in a row where a
derived document turned out to be an illustration rather than a specification (M4-A's required
fields, M4-C's change-class table, now this). **Four for four counting M4-B.**

##### What the grid rules, and why

**ONE ORDER, NOT TWO.** Rows are `portsInDeclaredOrder` and a band is a RUN of that order rather
than a re-sort of it, so the grid's reading and `PORT_SEQ`'s reading are the same reading. That is
also why `AddPortCommand` only appends: `PortDef.order` is a `FracIndex` compared as a raw string,
nothing in this package mints one BETWEEN two others, and inserting mid-list is a reorder, which is
M4-F4 (`#211`). **Closed: `orderBetween` exists as of `5a0d922`** (§5.3.11), and `AddPortCommand`
still appends, because appending is what an add means.

**THE DESIG COLUMN GOES THROUGH `allocatePortDesignator`.** CR-042 rules that the template supplies
a hint and the project allocates, so the cell previews what THIS project would render, honours a
project that numbers differently, and switches to the typed value the moment one is typed. A hint of
whitespace is **not** pinned: clearing the cell means back to automatic, never "deliberately
unnumbered". Two allocation failures report UNKNOWN rather than a number: the commercial
`{DEV_BLOCK}{PORT_SEQ:2}` preset needs a token no template can supply, and a pattern with no
`PORT_SEQ` renders the same string for every port. Allocation accumulates across the template
exactly as one device's pins allocate against one another, which is the only reason the second is
visible at all.

**THE KEY FOLLOWS THE LABEL ON EXACTLY TWO CONDITIONS**, and the user chose the rule: it must not
have been typed, and the port must be new in this session. `PortDef.key` is the migration join
(CR-051), so a published key silently following a typo correction would rewire an existing project's
cables. The touched-key set is **session-only and never stored** (reopen a saved template and every
key is the author's, because it was saved) and it is **monotonic**, recording both sides of a rename
so an undo lands on a key it still remembers.

**AUTO-REVEAL KEYS ON THE DOMAIN, NOT THE FAMILY.** §4.5's rule is "the bank's dominant family", and
the catalog ships 34 families against eight domains canon fixes, so the rule table is eight rows
rather than a list that grows with the community library. `ctl` reveals two packs, because control
is RS-232 and RS-485 in the same breath. Advanced is never auto-revealed; Passthrough follows
`isPassthrough`, because a patch panel's pairing is a fact about the device rather than one bank's
traffic. A pack the person toggles overrides the reveal for the session, and the open set is
remembered per CATEGORY in `prefs.json` beside the coach marks, on §11.12.4's ruling that UI chrome
does not belong in the document.

**NONE OF THE VALIDATION BLOCKS SAVING**, which docs/06 says twice and AC-049 explains: three fields
make a template, so a checker that can stop a save is a fourth required field wearing a warning
triangle. Two severities, drawn as a filled dot and a hollow one, shape rather than colour alone
(CR-078's discipline). The IR pinout is the only warning about hardware rather than paper, and the
seeded registries already explain why in their own comment: emitter and receiver share a plug and
have opposite pinouts, so plugging one into the other destroys the emitter. **The S/PDIF rule keys
on the family and not the connector**, though §4.5 words it as "an RCA carrying spdif": coaxial
S/PDIF is 75 ohm on a BNC too, and the seeded catalog's own default connector for that family is
`conn.rca75` rather than `conn.rca`.

**Two validation rules name catalog ids, and a test holds them.** The durable form is a field on
`SignalFamilyDef`, which is not built, so a rename in the seeded registries would otherwise switch a
safety check off in silence. `port_validation_test.dart` resolves every id against the shipped
registries and asserts which IR families exist. **It said "exactly two, because the hazard IS that
they are two" until DR-126 §11.125**, which is the right instinct on the wrong count: the hazard is
a two-conductor TS plug meeting a jack that supplies +12 V, so the split that matters is powered
against passive and there are three. The test now NAMES the three rather than counting them, because
a count of three passes on a merge back to two the day somebody adds a fourth.

**PANEL FILL IS ABSENT FROM THE FOOTER, AND THAT IS A DECISION.** §4.5's worked line ends
`· Panel fill R: 71%`; that number comes only from the auto-layout, which is M4-K, and every port
this editor creates sits at the origin. A guess is G4's fabrication and `Panel fill R: —` is what
the Structure editor's band header already rejected, because a dash belongs in a column where a
reader compares values, not in a running sentence. The clause arrives with the number.

##### One widget was extracted rather than copied

The SIGNAL column needs the SERVICE column's picker, which was private to
`structure_editor_screen.dart`. It now lives in `widgets/family_picker.dart` and both surfaces use
it. A copy would have been the cheaper edit and the wrong one: that widget carries a **measured**
finding (#587 put a `DropdownButton`'s menu at 116 points with every row clamped to 84, so two
different speaker families both arrive as `AUD·Speaker…`) and a **ruling** (DR-025 §11.24.3: the
filter narrows and never commits, because an unresolved value must not invent a family). Two copies
of a control encoding two decisions is two places for one of them to be forgotten. The Structure
editor's own tests pass untouched.

**CONNECTOR gets a menu rather than M3-L's read-only degradation, and the difference is a blank
row.** A `DropdownButton` asserts exactly one item matches its value, so the Structure editor lets
an unrecognised SERVICE fall back to text; here the same fallback would catch every brand-new port,
because a blank row names no connector at all, and a cell you cannot open is a port you cannot
finish.

##### Three defects found by tests before a user could

1. **The touched-key set lived in the grid's own `State`**, and the rail rebuilds the grid on every
   section change. A walk to Physical and back therefore forgot that the author had chosen a key,
   and the label started dragging it again. It is a fact about the editing session and now lives
   beside the session.
2. **The first cell tests asserted on the `TemplateBody` the test passed in**, which
   `TemplateEditSession` deep-copies on purpose (CR-106). Every assertion was reading an object
   nothing had touched, and five passed for that reason before the sixth exposed it. The harness
   presses `[Save]` and reads what the editor hands over.
3. **The `*Actions` gate caught a documented distinction the code did not make.** The two pack
   callbacks were nullable, with a comment explaining that null meant "nobody is remembering" and
   empty meant "everything closed", which nothing downstream could act on, because the screen folded
   null to empty on the way past. Non-nullable with defaults now.

**What M4-E does NOT deliver.** No Quick Add, no DSL, no label patterns, no archetypes, no paste, no
fill-down, no multi-row edit, no TSV, no reorder, no sort, no bank CRUD and no pairing action:
M4-F through M4-J own those, and the grid's Bank and Paired columns are read-only until M4-J. No
panel layout, no previews, no batch inspector. Enter commits and stays rather than moving down,
because moving down is spreadsheet ergonomics and belongs with M4-F's fill-down; Tab already moves
right, and a test drives real Tab events rather than finding the next cell.

#### 5.3.6 M4-G and M4-H, Quick Add and the pattern language · CLOSED · `0d60b80`, `a16bc73`, `158a60f`, `70d4fc5`, `34e4c3b`, `06cf577`, `3947192`, `c57c6b1`, `560fc98`, `438e268`, `34091b5`, `2a8180c`

**THE EXIT CRITERION'S SHAPE IS DEMONSTRATED FOR THE FIRST TIME, AND ONLY ITS SHAPE.** A test types
docs/06 §9.1's eight commands into the bar and asserts **68 ports across 6 banks with focus still in
the field**. That number is computed by running the commands, not restated from the document.
**Whether a person can do it in under three minutes remains entirely unmeasured** and is M4-Q
(`#188`), which no agent can perform. Board `#213`, `#214`, `#217`, `#218` and `#219` are closed;
`#215` and `#216` closed last, and with them the DSL teaches itself: AC-050's discoverability
argument is answered.

**M4-H WAS FOLDED INTO M4-G's DELIVERY**, settled by the user on 2026-08-15. Every one of §9.1's
thirteen steps quotes a label pattern, so a Quick Add without the pattern language produces sixteen
ports called `HDMI IN {n:2}` and cannot perform a single step of the example the milestone is
measured by. That is `check a decomposition for holes` firing on the milestone that earned the
practice. **A decomposition change, not a scope one**: roadmap §2 already names the pattern DSL, so
§8.3 is not engaged.

##### The census, and it is five for five

DR-060 §11.59.2. Board `#178` and `#214` both assert that `aliases` *"already exists on both
`ConnectorTypeDef` and `SignalFamilyDef`"*, and canon CR-058 says the same. Measured:

| | Finding |
|---|---|
| `ConnectorTypeDef.aliases` | **Populated**, 22 entries |
| `SignalFamilyDef.aliases` | **55 families, zero aliases**, behind a `_family()` helper that did not accept the parameter |
| canon §6.3's alias table | Lists **connector aliases only**; §6.4 lists none |

So CR-058's orthogonality claim, `hdbt` and `rj45` giving the same connector and different families,
**was unresolvable by anything in the tree**: both were aliases on `conn.rj45` and nothing mapped
either to a family. **The fifth consecutive M4 issue written from a document's assertion that
dissolved on contact with the source**, and the first useful hour went into reading for the fifth
time.

##### Three findings that came from reading a caller rather than a document

1. **`resolveSignalFamilyToken` ALREADY EXISTED** (`drop_line_planner.dart:707`), exported, shared by
   the CSV `signal` column and `@signal=`, **and its own docstring named this ruling as the
   precondition for widening it**, warning one paragraph earlier that *"two copies would be two
   chances to disagree about what `hbt` means"*. Quick Add widened the chain by one step; both
   callers inherit it.
2. **A SINGLE FIRST-HIT-WINS CHAIN WAS THE FIRST DRAFT AND `c13` KILLED IT.** A rack PDU has C13
   outlets and a C14 inlet, both `power.ac_iec` because CR-058 makes inlet/outlet a role. One chain
   resolves `c13` family-first and takes that family's `defaultConnector`, which is `conn.iec_c14`,
   **putting the wrong connector on every outlet of every power strip in the catalog, silently, on
   the panel drawing an electrician builds from.** The two registries now answer independently: a
   family knows a *default* connector and a default loses to a named one.
3. **`rj45` WAS ONE EDIT FROM A SILENT REGRESSION.** It was reasoned to be dead data and nearly
   deleted; `portConnectorShortLabel` prints `aliases.first.toUpperCase()` in the grid's CONN column,
   so every `RJ45` cell M4-E shipped would have become `RJ45 (8P8C)`. `hdbt` was genuinely dead and
   did go. **Grep the readers before tidying seeded data.**

##### What the tests caught that reasoning did not

**Four defects, and every one was found by a test that asserted an artifact rather than a
mechanism.**

- **`{n@2:2}` reported the wrong error.** The "modifiers do not compose" check sat after the branch
  that swallowed it, so the message read *"`2:2` is not a whole number"*: a true sentence about the
  wrong problem. Visible only because the test asserts the MESSAGE.
- **`repair` promised a whole pattern and delivered a fragment** in three of six sites, and the test
  file carried a comment EXCUSING the exceptions. The gate had been written around the defect rather
  than at it: `a stated difference the code does not make`, one milestone after M4-E recorded it.
- **The chip for `{L,}` did not parse.** `{L}` is read as a token NAME, so the repair handed back a
  second error. Found by widening the "every chip parses" loop from two cases to twelve. **The
  narrow loop was the bug's hiding place and the comment explaining the exemption was the lid.**
- **`@Control` built three banks.** docs/06 §4.2 states the numeric suffix inside the clause about
  `@bank` being OMITTED; applying it to explicit names gave Control, Control 2 and Control 3, and a
  template with EIGHT banks against a criterion that says six. **The parse-level test was green
  throughout**: it asserted three steps yielded the string `Control` three times, which they did.
  Only building the ports and counting banks caught it.

##### An invariant was invented, gated, and disproved by its own gate

DR-060 §11.59.10(a) made `aliases.first` a display token, and `1 de9 bi` promptly derived a bank
called **"DE9 Ports"**: a connector shell labelling a signal bank. A gate was written, *"no family
may lead with a token that names a connector"*, and **it failed on the first run against `hdmi`**,
which names `conn.hdmi_a` AND `video.hdmi.2_0` and where "HDMI Inputs" is exactly what §4.1 asks
for. What separates `hdmi` from `de9` is that one word is the signal's own name and the other is a
shell it arrives on, **which is a fact about English and not about the data model**. The artifact is
pinned instead: eight commands and the exact bank each derives. The failed attempt is recorded in
the test file so nobody rebuilds it.

##### Three keymap gates, in sequence, on one commit

**And the middle one caught a comment that stated its rule backwards.**

1. **D7's source ban** caught a `SingleActivator` built inline in the widget. `one-keymap-registry`
   is a named practice in this repo's own OKF bundle and the violation was written anyway.
2. **`meaningDrift`** caught a note explaining, confidently and at length, that differing labels
   across scopes were permitted *"precisely because the labels differ"*. Differing labels are what
   the rule forbids. `CommitWireIntent`'s docstring had already argued the case and named that
   position as *"the smaller edit and the wrong one"*, because **a keyboard-only user cannot see a
   scope boundary**. The correct answer was better than the draft: `Enter` already means *"Commit
   what is in flight"* in two scopes under DR-011.6, and a typed Quick Add command is in flight in
   exactly the sense a half-drawn wire is. Three surfaces, three intent types, one meaning.
3. **The framework-shadow tripwire**, whose comment reads *"What must not happen is a SIXTEENTH
   arriving unnoticed"*. This is the sixteenth. The row carries its argument: it shadows `Enter`
   over **one text field**, the narrowest scope in that list, because the failure that test
   remembers is a `Backspace` taken from six text fields for nine days.

`KeyScope.builder` is a sixth scope holding exactly one row, and the smallness is the finding: the
whole thirteen-step path is a text field and one key. **`Tab` is deliberately unclaimed** until
M4-G4 needs it and can argue for it.

##### Two user calls, recorded with what they overruled

DR-060 §11.59.10. **(a)** A derived bank name comes from the family's first alias, not docs/06
§4.2's stated display name, which would produce "HDMI 2.0 (18 Gbps) Inputs" against the "HDMI
Inputs" §4.1's own table prints: **here the prose was the illustration and the examples were the
specification.** **(b)** `euro2` defaults to `audio.speaker_lowz`, overruling a recommendation to
leave it unknown; the user ruled low-Z the overwhelming case in these racks, which is a fact about
the trade. §11.59.4's "either half may come back UNKNOWN" is now carried by `xlr` alone, and the
ruling says so, because a later reader finding `euro2` resolved would otherwise think the invariant
had eroded.

##### The two tasks that close it, and what each cost

**AUTOCOMPLETE IS NOT ON `Tab`, AND THE KEYMAP DECIDED THAT.** Tab was the design the user picked;
`meaningDrift` refused it, because the schematic already spends Tab on *"next candidate pin for the
wire in flight"* and advancing THROUGH offers is close to the opposite of taking one. Put back to
the user as a real collision, they chose **right-arrow**, which is fish and zsh-autosuggestions'
accept and shares a label with `pinCaretRight` **without straining**: the caret does move right,
through the suggestion when one is showing. DR-011.6's shape on a second key. It is gated on an
offer existing AND on the caret being at the end of the line, through a real `Action` whose
`isActionEnabled` is false otherwise, because right-arrow MOVES THE CARET and a binding that
swallowed it would stop a user walking their own command. **A ghost the key would not take is a lie
drawn in grey.**

**A PROPERTY GATE FOUND A PARSER BUG NO HAND-WRITTEN TEST HAD.** Field mode needs
`renderQuickAdd`, and gating it with `parse(render(p)) == p` failed immediately on `16 euro2 out`.
The cause was in the **parser**: `connector ??= connectorHit?.id ?? familyHit?.defaultConnector`
lets the FIRST token's family DEFAULT occupy the connector slot, so no later token can name one, and
`16 speaker euro2 out` resolved to a **binding post** instead of a euroblock. DR-060 §11.59.4's rule
is *"a default loses to a named one"*, and that draft applied it **within a token but not across
tokens**. Named and inherited connectors are tracked separately now.

**EVERY TEST IN THE BAR'S FILE FAILED THE MOMENT FIELD MODE LANDED**, and the failure was the useful
part: `find.byType(TextField)` had silently stopped meaning "the command line" the instant five more
text fields appeared beside it. **The finder had been standing in for identity** and worked only
while there was exactly one. The same mistake then repeated one layer down: the first fix navigated
`find.ancestor(of: text('Qty'), matching: Column)`, which resolves to the bar's ENTIRE Column, so
the test typed into the command line and asserted against it. Both are keys now.

##### Two fixes after the merge, from reading the real output

**THE FIRST DEFECT THIS MILESTONE WHERE A WRONG ANSWER DESTROYS HARDWARE.** `1 ir35 in "IR IN"`,
which is docs/06 §9.1's own step 12, resolved to **`ctl.ir_emitter`**. The catalog states the reason
that is dangerous in a comment sitting **directly above the two families' declarations**: emitter and
receiver pinouts are incompatible and plugging one into the other's jack destroys the emitter and can
damage the supply. AC-052 makes `pinoutVariant` mandatory on every 3.5 mm IR port for that reason.

**It survived every gate**, because an emitter port with direction `in` is not structurally invalid,
so no validation dot could flag it. DR-060 §11.59.11 rules the direction picks the family, in a
named one-row table, and states the bar for admitting a second: a wrong answer must destroy hardware
rather than merely inconvenience someone.

**THE SUMMARY LINE WAS RULED DOWN BY THE USER AFTER READING IT RENDERED.** Field mode had made five
of its seven fields redundant. It also printed **`1 ports`** on four of the eight steps, **`HDMI ·
HDMI`** wherever a connector is named after its signal, and `IEC device power (C13/C14, C19/C20)` on
a line read at a glance. **A dozen `contains` assertions were green throughout**, because a
`contains` assertion cannot see grammar or density. The line now says only what no control shows,
and its tests pin whole strings.

**What M4-G does NOT deliver.** No archetype generators, no paste (M4-I). `both`
and `pass` create their ports and **not** their `PassthroughPairDef` pairing, which is M4-J and is
asserted absent by a test so its arrival is a visible diff. No `poe:`, `z:`, `dte` or `tap:`
modifiers: §9.1's thirteen steps exercise none of them, and the grid's column packs already author
all four.

#### 5.3.7 M4-Q1, the drill · CLAUSE 1 CONFIRMED · **93 seconds** · `da0ac86`

> **The clause.** *A 16×16 matrix template is authored from scratch in under three minutes by a
> user who has seen the tool once.*

**Performed by the user on 2026-08-15 against the build carrying `ce5f70f`. 93 SECONDS, a 48%
margin under the criterion.** Full scope: named, RU height set, the eight Quick Add commands typed,
`Ctrl+S`. **The result was checked rather than assumed**, in the footer M4-E5 built: **68 ports
across 6 banks.** Typed DSL throughout, not the field-mode controls.

##### THE DRILL FOUND A MISSING KEYSTROKE THAT FOURTEEN GREEN GATES COULD NOT

The run **used the mouse to change section**, reported as a preference. It was not one. docs/06
§9.1 spends **step 5** on `Ctrl+Enter`, *"Jump to Ports"*, and **the binding had never been built**:
`KeyScope.builder` held the Quick Add commit and its autocomplete and nothing else.

**Every gate was green over that hole and would have stayed green forever.** The keymap arbitration
suite checks that what IS in the table is consistent across platforms; it cannot fail for a row the
specification promises and nobody wrote. **This is the second time a drill has found what the whole
test suite could not**, after M1's clause 3 (§3.5), and it is the entire argument for M4-Q existing
as a human act rather than a job.

Built in `da0ac86`, with the deliberate departure that it does **not** gate on the required fields
being satisfied, despite §9.1's parenthetical: AC-049 took the metadata form off the critical path,
and a jump refused because a field is blank would put back the gate that ruling removed, on the one
surface a stopwatch is pointed at.

##### The operator's conditions, recorded rather than dropped

**M1's clause 3 set this precedent in capitals and it binds here.** The user types **140+ wpm**, and
is not a user who has seen the tool once: **they specified this grammar the same afternoon**, chose
its autocomplete key after the keymap refused their first choice, and ruled on its bank naming and
its `euro2` default. That is the fastest possible operator of a DSL they designed.

**The clause says "a user" and 93 seconds satisfies it literally; this reading is not a hedge on the
mark.** But clause 1 is load-bearing for **M7's accessibility criterion**, whose subject is exactly
the person who has NOT memorised the vocabulary, and **93 seconds establishes nothing about them**.
A run by someone who has not seen the DSL is worth having before M7 leans on this number. Inline
autocomplete (`#216`) exists precisely for that population and was **not** exercised in this run.

**§9.3's invariant survives intact.** It states that focus never leaves Quick Add *during steps 6 to
13*, and the mouse was used at step 5, reaching Ports. The eight banks themselves were pure typing.

**A CONFIRMED mark is not a gate.** No CI job re-runs this, and it does not survive a change to the
keymap or the grammar. What guards the mechanism between drills is
`packages/rackpal_ui/test/builder/quick_add_bar_test.dart`, which types the same eight commands and
asserts 68 ports across 6 banks with focus still in the bar, and
`quick_add_test.dart`'s build group, which asserts the same totals in core.

##### What clause 2 still owes, and it is the whole of M4's remainder

*A template saved with exactly three fields plus ports places into a rack and appears correctly in
the equipment list with `—` in every unknown column and an accurate unknown count in the rollup.*
Board `#251`. **Untested by this drill and by any other.** `#250`, the archetype path, is blocked
on M4-I, which is not built; the DSL path is the only one that exists.

#### 5.3.8 CLAUSE 2 CANNOT BE PERFORMED, and the reason is a hole in the decomposition

> **CLOSED BY M4-S on 2026-08-19** (`#701`, DR-077 §11.76, built `#732`–`#738`). Everything below is
> the record of what was true for four days and is kept unedited, because the finding is the useful
> part. The palette now lists `buildPlaceableTemplates(doc)`, a second `Save` forks a version rather
> than minting a second template, and placement resolves the newest version rather than a pinned
> `@1`. **Clause 2 can be performed and `#251` is unblocked.** The second finding below was
> ANSWERED rather than built: `T6.30` is a sheet, and the criterion is read through
> `File ▸ Export PDF…` (DR-077 §11.76.4). See §5.3.13.

**Found on 2026-08-15 while writing the drill route for `#251`, before the user spent time on it.**

> **Clause 2, verbatim.** *A template saved with exactly three fields plus ports **places into a
> rack** and appears correctly in the equipment list with `—` in every unknown column and an
> accurate unknown count in the rollup.*

**A TEMPLATE AUTHORED IN THE BUILDER CANNOT BE PLACED.** It saves, it round-trips, and no surface
offers it:

| | |
|---|---|
| `SaveTemplateToProjectCommand` | writes the body to `RackDocument.templates['<id>@<version>']` (`device_builder_actions.dart`) |
| The palette | is built from `buildSeedCatalog()`, the 48 shipped archetypes (`rack_canvas_screen.dart:357`) |
| `_catalog` | is `late final` and **never mutated**: a grep for subscripts of it finds one read at :3187 and no write at all |
| `doc.templates` | is read only to resolve snapshots for devices ALREADY placed (:3092, :3360) and by demo construction |

So the 93-second template of §5.3.7 exists in the project and can never reach a rack. **Clause 2's
first half has no route, and its second half is therefore unreachable.**

**A SECOND FINDING BESIDE IT.** `buildEquipmentList` has **exactly one caller in the whole tree**,
`rackpal_export`'s `build_document.dart:86`. **There is no equipment list on screen.** Even given a
placed device, clause 2 could today only be checked through a PDF export, which is a question about
what the criterion means and not merely a missing view.

**THIS BELONGS TO NO ISSUE.** M4-N (`#170`) is the LIBRARY subsystem: `.rmda` archives, several
libraries loaded at once, filtering by which one a device came from. This is the plain in-project
case and none of M4's nineteen issues names it. `#251` is the drill for clause 2 and is blocked by
it.

**IT IS §5.3.5's FINDING MIRRORED, one level up.** M4-E's was *"five tasks build a grid and not one
of them creates a port"*: **ask what produces each task's input.** This is the other direction.
**Ask what CONSUMES each task's output.** M4-D built a save, gated it, tested it, and nothing reads
what it saved. A decomposition can be complete on both counts and still leave a milestone's criterion
unreachable, because the two questions are asked of different ends of the same task.

#### 5.3.9 M4-F0, the selection five tasks needed and none of them built

**M4-F (`#177`) was censused against its own tasks at pick-up on 2026-08-15, before any code.**
Two findings, and the second is the one that would have cost time.

**FINDING 1: FIVE OPERATIONS ARE NAMED BY BOTH docs/06 §4.6 AND `#177`'s OWN DESCRIPTION, AND BY NO
TASK.** §4.6 tabulates fourteen editing operations. M4-F/1 through /5 own five. `Mirror bank`
correctly belongs to M4-J1 and `Delete` shipped in M4-E. The remainder had no home:

| Orphan | Filed as |
|---|---|
| `Duplicate` `Ctrl+J` | `#696` |
| `Renumber…` `Ctrl+R` | `#697` |
| `Find & replace` `Ctrl+H` | `#698` |
| `Change type…` `Ctrl+T` | `#699` |
| `Move to bank…` `Ctrl+M` | `#700` |

Three of the five turn out to depend on F4's between-generator, which is why filing them before
building mattered rather than after: `Duplicate` clones *below itself*, `Move to bank…` must write
`order` as well as `bankKey` or it splits the target band in two, and both are the `FracIndex`
midpoint `nextOrder` has declined to mint since M0.

**FINDING 2: "THE SELECTION" HAD NO REFERENT.** §4.6 describes the thing all fourteen operations act
on twice, incompatibly: *"the top cell of the selection"* is a column of cells with a top, and
*"select N rows, edit any cell"* is a set of rows. The grid had neither. It had `_ticked`, a
`Set<String>` read by exactly one thing, the delete button.

**Settled by the user as DR-061** (§11.60) and filed as `#695`, landing before F1. The rectangle was
priced against §4.6's own table rather than against its *"integrators live in Excel"* sentence: nine
rows want whole rows, three name their own columns inside their own definitions, one wants a single
column, one is a single cell. **A rectangle would have been read by `Fill down` alone.**

**Closed the same day** by `9239849`, `81cd430`, `2b65402` and `9969ded`, fourteen gates green on
each. 41 cases: 33 in core over the algebra, 8 widget cases over the gestures.

**THE PART WORTH KEEPING IS HOW THE ONE DEFECT WAS FOUND.** Enter's move down was written into
`onSubmitted`. `EditableText` calls `onEditingComplete` first, and its default for a `done` action
is to **unfocus the field**; only then does `onSubmitted` run. So the commit landed, focus was
already gone, and directional traversal had no origin to move from. **Every one of the fourteen
gates passed.**

What found it was the shape of the test rather than its subject: type into row 1, press `Enter`,
then type again **with no finder in between**, and assert all three labels at the end. The second
line had gone into the same cell as the first. **A test that had looked up row 2's cell and typed
into it would have passed against a grid where `Enter` does nothing at all**, which is `drive the
keyboard, not the finder` stated as a positive rule: to test a route, name only its start.

#### 5.3.10 M4-F2, and the two things `docs/06` §4.6 said that could not both be true

**Closed 2026-08-15/16** by `e48f2ec` (DR-063), `fdb14ee` (core), `a855589` (the grid), `f17645f`
(the widget cases) and `6d16e5b` (the dock). 29 cases: 16 in core, 13 widget.

**§4.6's multi-row row asked for a `—` that already meant something else.** *"Mixed values render
`—` and are left untouched unless explicitly set."* The second half is the safety property and is
enforced. The first half spells a **disagreement** the way the whole product spells an **unknown**.
Eight ports nobody has measured and eight carrying 75 Ω and 110 Ω are different facts, and the dash
told the reader the first while the second was true, on the one surface built for looking at many
rows at once. **DR-063: `—` keeps its single meaning and a disagreement reads `Mixed (N values)`.**
That is CR-114's rollup rule (report the unknown count, never fabricate a total) pointed at a column
of N rows.

**§4.6 also said "edit any cell", and two cells could not survive it.** One label written across
eight selected rows names eight ports `HDMI IN`, and on ports created that session the key follows
the label, so the same gesture mints eight colliding keys suffixed `.2`, `.3`, `.4`. `LABEL` and
`DESIG` therefore edit one row; `Ctrl+Shift+D` already writes a column of labels (DR-062), so the
capability is routed rather than lost. A confirmation dialog was rejected: §4 says any interaction
costing one click per port is a design failure, and a modal in the grid is that failure wearing a
safety label.

**THE DOCK EXISTS, IN ONE STATE, AND IT READS.** §2's 340 px third pane is drawn only when more than
one row is selected, because its other state is M4-K's three live previews. Editing across a
selection happens in the grid, which is §4.6's own sentence and is built. Setting a field **from**
the dock is `#703`: every column's control lives in `port_grid.dart` bound to one port's value, and
`Mixed` is not a value, so a shared control needs extracting and giving a third valueless state
first. That is a refactor across ~40 call sites and it was filed rather than rushed.

**Three findings worth keeping.**

`PortColumnFill` needed a type-erased `read` and `write`, and only one of those is easy. Return
types are covariant so reading is sound; **parameters are contravariant**, so `PortField<Object?>
.set` throws before it is called. The cast lives inside the closure at the switch arm where `T` is
still known. **Extension types make the failure silent rather than loud** (a `PortField<
ConnectorTypeId>` IS a `PortField<String>` at run time), so a test walks every batch column, reads a
port and writes the value straight back, asserting no command comes out.

**The widget tests failed twice on a finder before they failed on the code.** `find.byType(
DropdownButton<PortDirection>).at(row)` is off by one: Quick Add's field-mode bar sits above the grid
and carries its own direction picker. The fix is not `.at(row + 1)`, which silently tests the wrong
row the day Quick Add changes; the bar's picker is unset and a row's never is, so a non-null value
identifies a row cell and the helper asserts the count first. **One throwaway diagnostic printing
the count and each widget's value settled in a minute what two guesses had not.**

**A test caught the author rather than the code.** The dock's close case clicked a row *inside* the
selection and failed, because DR-061 deliberately leaves the selection alone there: collapsing it
would make multi-row edit impossible to start. The test was wrong and the ruling was right.

#### 5.3.11 M4-F4, and the character `nextOrder` had been extending with since M0

**Closed 2026-08-16** by `5a0d922` (the index generator), `4572d49` (the planner) and `bc09185` (the
handle and the chords). 46 cases: 15 on the generator, 22 on the planner, 9 widget.

**THE DEFECT IS THE FINDING, and it was in code that had been correct for four milestones.**
`nextOrder` bumps the last character of the largest index, or appends one when that character is
already the alphabet's last. It appended `'0'`. `'0'` is the **lowest** character, so `'az'` was
followed by `'az0'`, and **nothing is representable between that pair**: an index strictly between
them would have to be `'az'` plus something below the lowest character there is.

Nothing had ever needed to insert between two ports, so nothing had ever asked. A template reaches
that pair at its **63rd port**. `16 hdmi in` typed four times reaches it, and a 64-port patchbay is
the canonical device this grid exists for. The fix is one character: extending with `'1'` spends one
of 62 slots and leaves the gap open permanently (DR-064). **Reverting it was tried, and the 200-long
allocation chain test fails**, which is the only evidence that the test is doing anything.

**The general midpoint generator `nextOrder` declined to write in M0 was right to wait.** Its comment
called it *"untested generality"* while no surface reordered, and that was true until this task. It
is now written with the tests the comment was holding out for, including a seeded 1000-insertion
property test, and it returns **null rather than renumbering** for the one shape that has no answer.
CR-027 chose a string index over an integer `sortOrder` precisely so neighbours are never renumbered;
a generator that quietly renumbered to avoid a null would have thrown away the reason for the type.

**A CHAIN OF INSERTIONS WALKS THE ALPHABET INSTEAD OF GROWING.** When two neighbours have no room at
the character where they part, the naive answer is `before` plus a middle character, which chains to
`a3V`, `a3VV`, `a3VVV`: a byte per drag, forever. Growing `before`'s own **tail** through `nextOrder`
gives `a3V`, `a3W`, `a3X`. Both are correct and one of them is a file that grows.

**THE BAND EDGE IS A WALL, AND THE TOOLKIT DECIDED THAT, NOT TASTE.** No reorderable list hands a
dragged item to a sibling list, and the grid's bands are pinned sticky headers over per-band lists.
The alternative was one flat list with the headers demoted to ordinary items, which costs the pinned
header a person forty rows into the HDMI inputs is reading to know they are the HDMI inputs. So the
drag stays within a bank and the `Bank` column is the way across (DR-064). The keyboard follows the
same wall on purpose: `Alt+↑` could have crossed, being pure arithmetic, and a chord that sometimes
means *move* and sometimes means *move and reclassify* is how a jack ends up in the wrong bank on a
printed panel.

**THE DRAG TEST OVERSHOOTS ON PURPOSE.** Two attempts to pin a landing spot by pixel distance gave
two different answers (`2 × pitch` landed one slot, `2.6 × pitch` landed three), because how much
travel becomes one index is `SliverReorderableList`'s arithmetic over animations that are still
running. Pinning a distance would have been asserting Flutter's easing curve. Aiming the drag far
past the second bank exercises the same path, clamps at the band's end, and **asserts the wall
through the actual gesture**, which is a stronger claim than the middle landing was.

**`onReorder` is deprecated for the off-by-one this would have hit.** It reports a destination
measured against the list *before* the dragged row leaves it, so dropping row 0 at the foot answers
`length` rather than `length - 1`. The analyzer named the replacement before the bug could be
written, which is one of the few times a deprecation warning has been load-bearing here.

**Arbitration took the pair without an argument**, which is the first time in three builder tasks.
`Alt+↑`/`Alt+↓` are bound nowhere else, unlike `Ctrl+D` (F1) and `Ctrl+V` (F3), each of which forced
a shipped label to be rewritten. Alt rather than Shift because `Shift+Arrow` is the range extension
every grid binds and this one will want it.

#### 5.3.12 M4-F5, the one place in the grid where the obvious behaviour is wrong

**Closed 2026-08-16** by `83bed51` (core) and `a695bc8` (the headers, the badge and the confirm).
33 cases: 23 core, 10 widget.

**EVERY SPREADSHEET SORTS BY WRITING THE ROWS, and here that is the wrong answer.** In a spreadsheet
the row order carries no meaning beyond itself. In this grid it carries four: FIXED_ORDER draws the
symbol's pins in it, `PORT_SEQ` numbers the schedule by it, the panel auto-layout places jacks by
it, and `J{PORT_SEQ:2}` prints it on the silkscreen. Somebody who clicks `IMPEDANCE` to find the odd
one out has said nothing about where the jacks are on the chassis. So a click sorts the view, and
most of the core cases assert the **declared order is unchanged**, which is the half a screenshot
cannot show.

**THE EVIDENCE IS LEFT VISIBLE ON PURPOSE.** A sorted grid shows `J01` somewhere in the middle,
because `portSeq` is the declared rank and the designator renders from it. Suppressing that would
have been easy and would have removed the one glance that tells a person what they are looking at.
It is the reason the badge can be believed.

**THE COMMIT IS A PERMUTATION, WHICH FELL OUT OF SORTING WITHIN A BAND.** Each band's ports already
occupy a set of positions; the commit hands those same positions back out in the sorted order. Three
things follow and all three were wanted: no index is minted so a commit can never run out of room,
the band keeps its place so sorting the HDMI inputs cannot move the outputs, and only the ports that
actually move are written. Had the sort flattened the bands instead, the commit would have
interleaved the banks in the declared order, which reorders the bands themselves.

**AN UNKNOWN SORTS LAST IN BOTH DIRECTIONS**, so the null branch runs outside the direction flip. A
blank-is-smallest sort answers *"the lowest impedance on this device is eight ports nobody has
measured"*, to the person most likely to act on it. That is DR-063's argument one task later against
a different reading of the same absence, and it went the same way.

**AC-058/D5 HAD ALREADY RULED THE CONFIRM**, which is the second time in this milestone that reading
the corpus first replaced a decision with a lookup. `completeness §D5` lists `Commit sort order`
beside `Ctrl+X` on a wired device as an unaudited data-loss edge, and credits `Renumber` with having
a diff. The diff is the honest reading and it is 64 lines in a modal on the device this grid exists
for. What a person cannot see is not *which* rows move, which is on screen in front of them, but
what else follows the order.

**A FINDER CAUGHT THE AUTHOR, for the third time in this milestone.** The confirm's `3 ports` also
matched the band header's own row count, which reads `3 ports`. Unscoped, the assertion passed on
the wrong widget in one arrangement and failed in another. Every count assertion in this grid now
has two candidates by construction, because the bands count rows too.

#### 5.3.13 M4-S, the template that could not reach a rack · CLOSED · `60b2b33`, `90a015f`, `b131dcd`, `4904be8`, `e224cbc`, `94a6e01`

**Closed 2026-08-19**, six commits, fourteen gates green on each. 42 cases: 15 core, 7 app, 20
widget. Settled by the user as **DR-077** (canon §11.76) before any code, because three of the four
questions were product decisions and the fourth was about what the criterion means.

**§5.3.8's finding is discharged. Clause 2 can now be performed**, and `#251` is unblocked.

**THE CENSUS IS THE PART WORTH KEEPING, because three of the four pieces needed no change at all.**

| | |
|---|---|
| `blank_document.dart` | already wrote all 48 seeded archetypes **into `doc.templates`** at version 1 |
| `buildPlaceFromCatalogCommand` | already resolved from `doc.templates`, never from the seed catalog |
| `SaveTemplateToProjectCommand` | already wrote an authored body into that same map |
| `DevicePalettePanel` | was handed `buildSeedCatalog()`, a constant, by `rack_canvas_screen.dart:368` |

**A document's `templates` map is the one shelf a project has**, and the seeded catalog is a
contributor to it rather than a second shelf beside it. The whole defect was one widget reading a
constant while standing next to the answer, and §5.3.8 had already named the line.

**FOUR MORE THINGS THE CENSUS FOUND THAT §5.3.8 DID NOT, and two of them were live defects.**

| Found | What it was |
|---|---|
| `_catalog` is `late final` | Pointed at the right shelf it would still never have noticed a save. Now memoised on `stateId` through `DocumentMemo`, which is `ScheduleScreen`'s mechanism used for `ScheduleScreen`'s reason |
| `catalogTemplateKey` pins `@1` | A **read-side** pin on a **write-side** key. The moment a second version exists the palette offers a row resolving a stale body |
| The arm-drag body lookup read `_catalog` | It would have refused to arm a drag on **every authored template, silently**, because the row the palette drew and the map the gesture consulted were two different lists |
| A second `[Save]` minted `tpl.foo_2` | `editing` was null on every call, so the ordinary save-and-keep-working path produced two templates with one display name |

The last is CR-050's own rule sitting implemented and uncalled in `nextTemplateVersion`, and it is
the reason the version pin mattered: fixing the save without the read would have made the palette
offer v1 of a template the user had corrected twice.

**A TEMPLATE WITH NO CATEGORY WAS INVISIBLE**, which is the same class as the rest and one step
later. `_canSave` requires a display name, a type prefix and a meant occupancy, and **not** a
category; the panel iterated `kCatalogCategoryOrder`. Such a template was not refused and not
badged: it was absent. It now lands in a trailing `Uncategorised` group, and so does a category from
a build this one does not know.

**THE PROVENANCE ANSWER IS THE USER'S AND IT IS BOTH.** An authored template is filed into its own
category with a badge **and** repeated in a `This project` group pinned above the nine, because the
category is where a person looks for a network switch and the pinned group is where a person looks
for what they saved thirty seconds ago. **The pinned group is browse-state only**: a search flattens
to one list, and a row appearing twice there makes the match count wrong and `Enter`-on-the-top-match
ambiguous, so search shows each template once, still badged.

**THE EQUIPMENT LIST QUESTION WAS ANSWERED AND NOT BUILT** (DR-077 §11.76.4). `T6.30` is a sheet,
the corpus promises no view of it, M1's own criterion already reads it through an exported PDF, and
`File ▸ Export PDF…` emits it today. An on-screen equipment list is the §8.3 amendment the ruling
declines: a second table that must never drift from the sheet, added to unblock a criterion that did
not ask for it.

**TWO DEFECTS IN THE TESTS THEMSELVES ARE RECORDED, because both were caught by output rather than
by review.** The palette fixture was named `HDMI Matrix 16x16` and **V03 already ships under that
exact name**, so a two-row assertion found three; and the placement case was written against
`buildDemoRackDocument`, whose AMP-1 occupies the U the insertion caret opens on, so the route
refused with `Occupied by AMP-1 (U4-U5).` and the first reading of that was "the feature does not
work". **Printing the refusal is what settled it**, which is
`print the output before claiming copy is done` in its other register: the run said the feature
worked and the assertion said it did not.

**WHAT M4-S DOES NOT DELIVER.** No library subsystem: M4-N (`#170`) still owns `.rmda` archives,
several libraries at once and filtering by which one a device came from, and a template authored in
one project still does not appear in another. No `Duplicate & edit` from a catalog card, which is
M4-O's (`#186`), so nothing writes a `derivedFrom` and CR-062's badge has a producer for the first
time with still nothing to badge. No on-screen equipment list, by ruling. No version number on a
palette row: a row shows the newest version's body and does not print which version that is.

**THE DRILL ROUTE FOR `#251` IS WRITTEN AND UNRUN.** `docs/17-m4q2-drill.md` carries the script, the
thirteen-column expectation table, the refutation list and the verdict form. Two of its cells were
MEASURED rather than described: `MANUFACTURER` prints `Generic` and not a dash (DR-056's pre-fill is
not an unknown), and the subtotal band reads verbatim
`RK-1 SUBTOTAL   1 DEVICE   — (1 unknown)   — (1 unknown)`, which is CR-114's rollup rule in one
line. Both came out of running the derivation against a minimal authored template and printing it,
not out of reading `equipment_sheet.dart`.

**THE LESSON IS §5.3.5's, POINTING THE OTHER WAY**, and it is now a practice in the bundle rather
than a paragraph in this file. M4-E's was *"five tasks build a grid and not one of them creates a
port"*: ask what **produces** each task's input. This one is ask what **consumes** each task's
output. M4-D built a save, gated it, tested it, and nothing read what it saved, while
`device_builder_actions.dart`'s own header asserted *"a template authored here is therefore
placeable immediately"* from the day it shipped. **Seventeen issues, sixty-three tasks and fourteen
green gates could not see it.**

#### 5.3.14 M4-F6 through M4-F11, the five orphans and the refactor · CLOSED · `0ed6e71`, `bba3102`, `c0f657c`, `3c76f76`, `98ebc99`, `25d57aa`, `9c8efdb`

**Closed 2026-08-19**, seven commits, fourteen gates green on each. 96 cases: 72 in core, 24 widget.
**M4-F (`#177`) is now CLOSED**, twelve tasks, and every operation `docs/06` §4.6 tabulates exists.

**Settled by the user as DR-078** (canon §11.77) before any code, on three questions the census raised
and no task could answer alone.

**THE CENSUS FOUND A COLLISION FIVE CHORDS DEEP, AND IT WAS THE FOURTH ONE.** `builderFillDown`'s
note established the check ("`Ctrl+D` is not a Flutter text editing binding on any platform this
ships to") and this is the first time it has come back positive: **`Ctrl+T` is
`TransposeCharactersIntent` in `_macShortcuts`**, and DR-009 puts macOS in v1. The collision runs
**our** way, because Flutter dispatches leaf to root while `DefaultTextEditingShortcuts` sits at the
app root (`docs/04` §8), so on macOS inside a builder cell `Ctrl+T` opens `Change type…` and does not
transpose. Taken deliberately, recorded in `docs/13` §3.6. `Ctrl+J`, `Ctrl+R`, `Ctrl+H` and `Ctrl+M`
are clean in every platform map. **Arbitration structurally cannot see a framework default**, so the
keymap notes are the only place that check is written down.

| Task | What the trap turned out to be |
|---|---|
| `#696` `Ctrl+J` | *"Past the highest existing index"* is a claim about the TEMPLATE, and the series key must NOT include the digit width, or `IN 1` and `IN 01` count as two and one lands on the other |
| `#697` `Ctrl+R` | `Start` is not decoration: `{n}` counts from 1, so renumbering a sub-range was otherwise unexpressible. Renumber does **not** refuse under a sort, unlike `Duplicate`, and the dialog says which order it means |
| `#700` `Ctrl+M` | A move writes `bankKey` **and** `order`, or the destination band splits in two. The core case asserts the BANDS a person sees rather than the key values |
| `#699` `Ctrl+T` | `direction` and `topology` are never written, because the model cannot tell a chosen value from a defaulted one and DR-060 forbids the overwrite. The preview NAMES what it leaves alone |
| `#698` `Ctrl+H` | A rename that would collide, or empty a key, is marked and skipped: `RenamePortKeyCommand` throws on both, and a dialog must not hand it a command that will |
| `#703` dock writes | `null` is a legitimate menu item (G4), so a mixed control passing `value: null` MATCHED the unknown row and displayed the dash: the exact confusion DR-063 exists to end |

**THE TESTS FOUND FIVE THINGS NO READING WOULD HAVE, and three of them were the tests themselves.**
Three label assertions indexed positionally into a list whose clones land after the last SELECTED
row. A `Find & replace` toolbar overflowed its dialog by **243 px**, which is `_ScheduleToolbar`'s
lesson one screen over: a toolbar sized by its labels cannot be laid out on one line by assertion.
Two finders were ambiguous against the grid BEHIND a modal, because the grid has a `KEY` column
header and a gutter full of checkboxes. **A record of records holding `List`s compared unequal while
printing two identical-looking values**, which is why the band assertions are flat strings.

**THE FIFTH IS THE ONE WORTH KEEPING, and Flutter's own warning found it rather than an assertion.**
A tap on the dock's `Mixed (2 values)` **text** missed its hit test, so the menu never opened;
`find.text('Front').last` then hit a **grid** cell, the multi-row edit applied, and the assertion
passed **with the dock never touched**. The test was green and testing the wrong pane. Every dock
control is keyed now, which is a production affordance rather than a test hook: the dock and the grid
draw the same widget types over the same columns, so without a key nothing can say which it is
looking at. **That is the fourth time in this milestone a finder has caught the author** (§5.3.12),
and the first time the catch came from a warning nobody had asserted on.

**M4-F11 IS A REFACTOR THAT WAS FILED RATHER THAN RUSHED, AND THE FILING PAID.** `#703` recorded at
M4-F2 exactly why the dock could not write: every control was private to `port_grid.dart` and bound
to ONE port's value, and *"mixed is not a value"*. 445 lines moved to `port_cells.dart` behind 118
existing widget cases, and the mixed state came out as **one parameter**: `mixedLabel` non-null means
render DR-063's reading and hold NOTHING. The safety property is then structural rather than
remembered, which is what the task asked for.

**WHAT M4-F DOES NOT DELIVER.** `Mirror bank` is M4-J1's and remains the one §4.6 row with no
implementation. A mixed control cannot express *"set them all to unknown"*, which is available per
row in the grid and is written down in three places rather than discovered. `LABEL` and `DESIG` have
no dock control at all, by DR-063.

#### 5.3.15 M4-T, the three rulings M4 owed · CLOSED · `b119a1b`, `d7cc706`, `7bef94f`

**Closed 2026-08-21**, three commits, fourteen gates green on each. **There is no code in any of
them**: the deliverable is canon §11.79 through §11.81 and three concepts in the bundle.

**THE CENSUS'S HEADLINE IS THAT THERE WAS ALMOST NOTHING TO FIND, and that is a result rather than
an absence.** Every remaining M4 issue was read against canon for a decision nobody had adjudicated.
Against **ten open issues and thirty-one open tasks**, the census produced **one genuine blocker, one
half-blocker and one loose thread**. DR-057, DR-059, DR-060, DR-061, DR-062, DR-063, DR-077 and
DR-078 all landed *during* this milestone for exactly this purpose, and a thin census is the
evidence that they worked.

**DR-059's OWN STATED PRICE WAS WRONG IN BOTH HALVES, AND MEASURING IT TOOK FOUR MINUTES.** §11.58.8
deferred `accentColor` on the ground that reaching `device_layer.dart` *"changes the elevation,
regenerates four starters' goldens and must clear PAL-1"*. `accentColor` occurs **0 times** in all
four `.rmpj` starters and **0 times** anywhere in `catalog/`, so no golden moves; and the PAL-1 gate
prints its own scope on every run, *"55 families, 385 in-band cross-domain pairs checked"*, which has
no device in it. **Neither half survives contact with the tree.** §11.58 is **left as written**,
because it is the record of what was believed on the day.

**THE REAL COST WAS THE ONE NOBODY HAD NAMED.** `device_layer.dart:134` fills the body and then
draws **four** text ops over it, all dark inks chosen against a near-white `deviceFill`, and one of
the eight shipped swatches is `Rgb(0x00, 0x00, 0x00)`. **A ruling deferred for its cost had been
deferred for the wrong cost entirely.** That is `a stated cost is a hypothesis until it is measured`,
filed in the bundle on this its third instance, after DR-057's sparse-`pitch` cut that was never real
and `#702`'s eight-way split that could not touch the domain-independent symbols.

**THE SEQUENCING CLAUSE IS THE ONE THAT MOVES THIS BOARD.** CR-078's *"hue is never used alone"* is
satisfied **vacuously** today: every device is one uniform fill, so no two differ by hue at all.
Accents make them differ by hue **and nothing else** until DR-059's seventeen marks exist, so DR-080
forbids the fill shipping before `#694`'s artwork. **`#694` is an Issue carrying zero Tasks**, and it
has moved from beside M4's critical path onto it.

| Ruling | What it settles | What it unblocks |
|---|---|---|
| **DR-080** §11.79 | The accent becomes the device body fill, instance override first; the four label colours are computed from its WCAG luminance rather than read from `RackStyle` | `#694` (M4-R), and it tells `#228`'s previews what to draw |
| **DR-081** §11.80 | `channelIndex`, `acceptedFamilies` and `carriedProtocols` each get a cell, and the multi-select **shape** is the deliverable. **Authoring only** | `#224` (M4-J2) |
| **DR-082** §11.81 | `parity` and `flowControl` become closed value sets, with no `Other` row | Nothing. It was a comment, not a blocker, and is recorded as such |

**DR-081'S RESTRAINT CLAUSE IS WORTH MORE THAN ITS CELL.** Nothing reads `acceptedFamilies` at
connect time in v1. Arming a rule here would have built an M5 rule outside M5's registry without the
fixture pair AC-051 demands, and **roadmap §4 names "just one more obvious rule" as the mechanism by
which M5 overruns**. DR-012 is undisturbed for a mechanical reason rather than a diplomatic one: both
lists are non-nullable and default to `[]`, so an empty list reads as *states no constraint* and
every one of the 727 seed ports keeps the behaviour it has.

**TWO COSTS ARE ACCEPTED IN WRITING SO M6 IS NOT AMBUSHED BY THEM**: the elevation's text palette
becomes data-dependent where `RackStyle.deviceDesignator` is one value today, and a 42U rack of
saturated bodies is an ink load nothing has measured. **`#357`'s print matrix is now told to look**,
which is the difference between an accepted cost and a discovery on paper.

**WHAT M4-T DOES NOT DELIVER.** No code, anywhere. `#694` is still undecomposed, `#224` still has no
multi-select cell, neither dropdown exists, and `device_layer.dart` still fills every device with
`palette.deviceFill`. **These rulings are what that work will cite. The work itself is unstarted**,
and this section is not evidence that any of it is built.

#### 5.3.16 M4-R, the seventeen marks and the accent that ships with them · CLOSED · DRILL CONFIRMED 2026-08-28 · `a915a04`, `95be9e6`, `64b953c`, `e58a922`, `365b3b7`, `77e9cf1`, `e356866`, `42f3391`, `811c5c6`

**Nine commits, 2026-08-21, fourteen gates green on each. `#694` had ZERO tasks that morning** and
now has nine, of which eight are closed and `#757`'s printed half is not. `rackpal_core` went
**3,140 → 3,197** and `rackpal_ui` **1,115 → 1,117**.

**TWO RULINGS CAME OUT OF THE PICK-UP CENSUS, BEFORE ANY ARTWORK.** DR-083 (§11.82) placed the mark
and settled the hatch collision; DR-084 (§11.83) made the seeded catalog author its own marks. Both
were taken from measurements rather than from the corpus, which is the whole difference between this
section and the three DR-059 sentences it had to correct.

**DR-059 WAS WRONG THREE TIMES AND THE TREE SAID SO EACH TIME.** This is the finding of the whole
issue and it generalises past the glyph:

| The sentence | What the tree said |
|---|---|
| *"regenerates four starters' goldens and must clear PAL-1"* (§11.58.8) | `accentColor` occurs **0 times** in the starters and **0 times** in `catalog/`, so no golden moved; `pal1_check.py` enumerates 385 `SignalFamilyDef` pairs and has **no device concept** |
| *"sequenced with M4-K, the first surface a device glyph appears on at all"* (§11.58.7) | `panel_layer.dart` **does not exist**. M4-K is unstarted and DR-080 made `device_layer.dart` that surface, so `#694` was never blocked on `#182` |
| *"`display` is the modal answer rather than the right one"*, deferred to the picker | True, and its cost was never counted: **0 of 48** templates authored a glyph, so seventeen marks shipped as **nine** and **eight were unreachable** |

**§11.58 IS LEFT AS WRITTEN.** Each correction lives in the ruling that found it, on DR-080
§11.79.2's precedent. A ruling records what was believed on the day, and editing that falsifies the
record rather than improving it.

**AND TWO OF THIS SESSION'S OWN RULINGS WERE WRONG IN THE SAME WAY**, which is the reason the table
above is not a complaint about DR-059. **DR-084's first draft** said the codec writes `glyph` *"only
when it differs from the category default"*; `json_codec.dart:3420` writes it whenever it is
non-null and the comment above it explains why, so the economy is a property of what is AUTHORED and
the real figure is **26 of 48**. **DR-083 said the knockout costs "two extra ops"**; it costs
**one**, because the ruling counted the mark, which draws on every device hatched or not. Both were
caught by writing something that had to COMPUTE the number rather than assert it, and both are
recorded in place.

**THE COLLAPSE IS THE FINDING WORTH KEEPING.** `device_glyph_test` asserted *"every one of the 48
seeded templates resolves to a mark"* and passed, correctly, for weeks: they do. **An existence
assertion cannot see a collapse.** Forty-eight resolving to nine satisfies it exactly as well as
forty-eight resolving to seventeen, and the number that mattered was never asked for. `census before
building` gains that as its sixth instance and its first of a different shape: the earlier five found
a field that was **empty**, which the first query anybody writes catches, while this one **resolves
perfectly and collapses**.

**THE ELEVATION HAD NO OP CENSUS AT ALL, AND THAT IS WHY NONE OF THIS WAS VISIBLE.** `#753` added a
path op to every device on every elevation and all 3,152 core cases stayed green. The schematic has
`schematic_perf_test`'s baselines; the elevation had a **text-run** census beside them and nothing
else, and a mark is a path. `#757` adds one, pinning the relationship rather than a total: **exactly
one mark per visible device**, which is what a person could check by eye. On the committed fixture:
24 devices, 24 marks, 14 distinct silhouettes.

**WHAT THE GATES CAUGHT THAT LOCAL GREEN COULD NOT**, listed because each is an argument for keeping
them: `tracked sources` found an untracked `lib/` file **twice**, either of which would have shipped
a commit no clone could compile while every local command stayed green; the analyzer ratchet caught
`DIRECTIVES_ORDERING` and `DOCUMENT_IGNORES`, both diagnosed only by **diffing the by-rule table**
against the previous green run because the headline named an unrelated pre-existing info; and
`draw_source_gate_test` failed a production comment citing a test file that does not exist, which was
**my own header, in the sentence explaining that the port is missing**.

| Task | What it did |
|---|---|
| `#751` | DR-083: the mark rides the designator line; the mark wins over a hatch; DR-059's sequencing corrected |
| `#752` | The seventeen marks as geometry. One op per mark, advance computed from the type size, circles as four cubics so no op-kind assertion depends on which mark a device carries |
| `#753` | The mark reaches the elevation. The guard chooses between mark and no mark, **never** between text and no text, because this function has already shipped a blackout |
| `#758` | DR-084: the seeded catalog authors its own marks |
| `#759` | 26 templates authored, four starters and the perf fixture regenerated. Three independent counts agree on 26 |
| `#755` | DR-080's accent fill, and the four label inks computed from its WCAG luminance. `pal1_check.py`'s figures pinned in Dart, because no port of it has ever existed |
| `#754` | The hatch knockout, asserted by **order** rather than presence: a backing rect drawn before the hatch is painted over and does nothing while still appearing in the op list |
| `#756` | The builder picker draws the marks through the elevation's own geometry (CR-086), never a look-alike |
| `#757` | The elevation op census, and `docs/18`'s printed drill. **The print is unrun** |

**THE DRILL RAN ON 2026-08-28 AND THE CAP SURVIVED.** `#757` closes and with it `#694`.
**Seventeen marks, read at 8 pt off an ANSI B plot, and the four suspect neighbourhoods held. No
mark was redrawn.** Printed on an **HP DesignJet T790** at 100%, then **photocopied on a Brother
mono laser** from a section cut out of the plot. Full conditions and their limits are `docs/18` §7.

**THE PLOTTER IS AN INKJET, SO THE COPY IS WHERE THE TONER CAME FROM**, and that is the sentence a
later reader must not lose. A DesignJet lays down ink, and ink spreads at a stroke edge where toner
does not, so the plot met the **size** condition and not the **laser** one. The photocopy met the
laser condition, and it is the harsher of the two anyway: DR-059 capped the set against the
photocopy specifically, which is exactly the limb that has now been measured. **AC-054's ANSI B
laser print is still owed and is `M6-J`'s (`#357`)**, unchanged by this run.

The copy covered the marks in the cut section rather than all seventeen, which is the honest way to
get an ANSI B plot through a Letter copier and is recorded rather than smoothed over. Whole-sheet
copy coverage needs a copier that takes ANSI B, which is M6's machine.

**WHAT M4-R STILL DOES NOT DELIVER.** The previews M4-K owns are unbuilt, so the builder picker is
the only surface besides the elevation that draws a mark.

#### 5.3.17 M4-J1, the bank tree, and the field that has never had a reader · CLOSED · `dbd7d19`, `6a4e41c`, `817acfd`, `ab7eeb8`

**Four commits, fourteen gates green on each.** `rackpal_core` **3,197 → 3,224**, `rackpal_ui`
**1,117 → 1,139**. `#760` is DR-085 (§11.84); `#223` is the CRUD, the tree, the menu and the mirror.

**THE PICK-UP CENSUS FOUND SOMETHING LARGER THAN THE MISSING ACTION, and it re-scoped the issue.**
`#181` reads as *"the editor over three models"*. It is not:

| Model | Writers outside the seeded catalog | The surface reading it |
|---|---|---|
| `PortSetDef` | **none** | a **live** `SET` dropdown built from that empty list (`port_grid.dart`) |
| `PassthroughPairDef` | **none that create one** | `PAIRED WITH`, read-only |
| `BankDef` | one, `quick_add.dart:721` | the grid's bands, and `Ctrl+M`'s destinations |

**A person authoring a template from scratch opens the `SET` picker, finds one entry, `—`, and will
find only that one forever.** So M4-J is **the two missing producers**, and `Mirror bank` is its
smallest task rather than its largest. That is
`a modelled field is not a reachable one` **with the halves reversed**: the practice was filed on
`NetworkConfig`, a writer with no reader, and the census question everybody writes, *"what writes
this?"*, finds that shape and misses this one entirely.

**`BankDef.order` HAS NO READER AND NEVER HAS.** Found while deciding what the tree should sort by.
It is allocated by `nextOrder`, encoded by `json_codec`, and read by **nothing that orders
anything**: `symbol_layer.dart` orders pins by `PortDef.order`, `buildPortTable` bands by first
appearance over the declared port order, and `movableBanks` follows the grid. **Making the tree its
first reader was the tempting move and is the wrong one**, because the tree is navigation and a
navigation list whose order differs from the surface it navigates is a defect rather than a
preference. Recorded rather than fixed: reordering banks is not a docs/06 §4.6 operation, so no
gesture can write the field, and if one is ever ruled it takes this field and the grid takes a
reader with it.

**THREE UI DECISIONS WERE PUT TO THE USER BEFORE ANY WIDGET, and all three were taken.** The tree
**jumps and hides nothing** (a filter would leave `Fill down`, `Renumber…` and `Duplicate` reasoning
about rows the person cannot see, against a full declared order they no longer share); it is mounted
on **every** section, with a click switching to Ports (a rail that reflowed under the cursor is how
somebody clicks the wrong tile); and the menu hangs off **both** the tree row and the grid's band
header, built once by `bankMenuItems`.

**THE JUMP IS A LOOP AND NOT AN OFFSET, which is the implementation note worth keeping.** Two
obvious approaches are both wrong on this grid. Computing the target offset needs a row height, and
a row has none declared: it is as tall as a `TextField` at the current text scale, so the arithmetic
would have to invent a constant and the next person to change the row's padding would break
navigation with fourteen gates green. `Scrollable.ensureVisible` needs a `BuildContext`, and a
`SliverPersistentHeader` four screens down has never been laid out, so its `GlobalKey` holds
nothing. The grid therefore pages toward the target a viewport at a time until the header exists,
then lets `ensureVisible` place it: no invented constants, bounded by the scroll extent over the
viewport, and the intermediate frames read as the fast scroll the gesture is.

**FOUR GRID TESTS WENT RED AND ALL FOUR WERE RIGHT TO.** They asserted `find.text('HDMI Inputs')`
over the whole screen, which silently meant *the band header* right up until the rail started naming
banks too. Scoped through a `_inGrid` finder rather than loosened, because a bank's name is now on
screen twice **by design** and a finder that cannot say which one it means is not asserting what its
name claims.

**Two smaller things the work settled, each because a surface arrived.** `AddBankCommand`'s
`LabelKey` moved from `quickAddPorts` to a new `addBank`: inside a transaction the transaction's
label is what the Edit menu shows, so while Quick Add was the only caller that getter was
unreachable prose, and the tree runs it bare. And `portMoveToBankRefusalMessage` stopped pointing at
a *"Banks section"* that has never existed; it names the tree's `+`.

| Task | What it did |
|---|---|
| `#760` | DR-085 (§11.84): the three clauses `Mirror bank`'s one docs/06 row cannot answer, and the census above |
| `#223` | `RenameBankCommand`, `RemoveBankCommand`, `planMirrorBank`, `mirrorBankCommands`, `buildBankTree`, `bankLabelIsTaken`, `mirrorBankImpact`; the rail's tree, both menu mount points, and the three dialogs |

**WHAT M4-J1 DOES NOT DELIVER.** No `PortSetDef` producer (`#224`) and no `PassthroughPairDef`
producer (`#225`), which the census above makes the larger half of `#181`. No bank reordering, for
the reason `BankDef.order` is recorded above. A mirror does **not** pair the two banks: a matrix's
mirrored output is a second output, not a passthrough (DR-085 §11.84.6).

#### 5.3.18 M4-J2, the port set's missing producer and the role column that could spell `+` four ways · CLOSED · `109d5e6`, `a02eeef`

**Two commits, fourteen gates green on each.** `rackpal_core` **3,224 → 3,245**, `rackpal_ui`
**1,139 → 1,151**. `#761` is DR-086 (§11.85); `#224` is the gesture, the closed role list and the
first editor `atomicConnect` has ever had.

**THE PICK-UP CENSUS FOUND THE SAME FIELD UNREACHABLE IN BOTH DIRECTIONS, WHICH IS TWO DIFFERENT
DEFECTS.** DR-085 §11.84.2 had already found the producer missing under a live `SET` dropdown. This
one adds the other half:

| | |
|---|---|
| `PortSetDef` | **no producer** outside the seeded catalog, under a live, editable picker |
| `PortSetDef.kind` | **no reader** outside the codec: not `resolvePortSet`, not `planAtomicConnect`, not any drawing, schedule or rule |

Seventeen seeded declarations write `kind`, `json_codec` round-trips it, and **no decision anywhere
in the product consults it**. DR-086 §11.85.3 gives it its first reader by making it the source of
the role vocabulary.

**AND THE ENUM'S OWN RANGE WAS THE THIRD FINDING.** `SetKind` has four values. `componentVideo` is
authored **zero** times, and it is the case CR-055 leads with. `balancedPair` is authored **once**,
as A04's `bal`, *"Balanced input pair"*, whose two ports carry roles `L` and `R`: as authored it
means *a stereo pair that happens to be balanced*, which `PortDef.balanced` already records on each
port, and **not** the two legs of one balanced line. It is kept for CR-117's sake and not offered.

**THE GESTURE WAS CHOSEN AGAINST MEASURED EVIDENCE, NOT TASTE.** A `SETS` tree in the rail beside
M4-J1's `BANKS` is the symmetric answer and was the cheap one to build on what J1 had just landed.
`port_set_integrity_test.dart` records what separating *declare a set* from *fill it* cost when the
catalog did exactly that: **90 `setKey` references, 72 dangling; 16 sets declared, 7 referenced by
nothing; 7 `atomicConnect` sets with fewer than two members.** Below two members the AC-053 gesture
is undefined and degrades to a one-conductor link **with no error**. So the set is made FROM the
rows, and a one-member set became something only a `Delete` or a hand-edited file can produce.

**THE CLOSED ROLE LIST IS A CORRECTNESS FIX WEARING A TIDINESS HAT.** `planAtomicConnect` compares
`setRole` by **string equality** to report a `RoleMismatch`, and `atomic_connect.dart`'s header had
already written the warning down: the exposure *"opens the moment M4 lets a user author a
template"*. With free text, `+`, `plus`, `POS` and `Pos` are four roles, and whoever types the fourth
warns against every seeded amplifier they connect to. The list is spelled exactly as the seed spells
it, ASCII hyphen included, and a test asserts **both** halves: that the hyphen is `U+002D`, and that
the 35 seeded member ports carry nothing outside the closed list. That second half is what makes it
a join rather than a preference.

**`Ungroup` IS A DECOMPOSITION HOLE FOUND WHILE BUILDING, and it is recorded as one** (DR-086
§11.85.8, added after the ruling). The clauses left nowhere for a set a person no longer wants to go,
and **the capability was already there with only the cleanup missing**: the `SET` column lists `null`
first, so clearing both members already takes them out and strands the `PortSetDef`. That is
`port_set_integrity_test`'s own *"declared, referenced by nothing"* row arriving in an authored
template. `Ctrl+Shift+G` is now the **only** thing that removes a `PortSetDef`, and §11.85.6's rule
that DELETING the last member does not remove one stands unchanged beside it.

**TWO DEFECTS THE WIDGET CASES CAUGHT BEFORE ANYBODY OPENED THE DIALOG.** The kind dropdown
overflowed by **0.65 points** on its longest row, `Component video · Y / Pb / Pr`, and Flutter
painted the striped bar over it. And pressing `Ctrl+Shift+G` with nothing selected, then ticking two
rows and pressing it again, left *"select the ports first"* on screen with two rows plainly selected.
Neither is visible from the code and both are the first thing a person would hit.

**AND ONE FALSE EXPLANATION THAT NEARLY SHIPPED IN A COMMENT.** The analyzer warned
`COLLECTION_METHODS_UNRELATED_TYPE` on a test looking up a `Map<String, …>` with a `PortKey`, and the
comment written for the fix said the test had been passing **vacuously**. It had not: `PortKey` is an
`extension type` over `String` (`ids.dart:37`), so at runtime it **is** the key, and the assertion had
been real all along. Caught by running a probe rather than by re-reading the paragraph, which is
`a stated cost is a hypothesis` pointed at a claim about a test. The warning is obeyed anyway,
because warnings are gated at zero.

| Task | What it did |
|---|---|
| `#761` | DR-086 (§11.85): the gesture, the closed role list, the kind that is not offered, `atomicConnect`'s editor, and `Ungroup` |
| `#224` | `AddPortSetCommand`, `RemovePortSetCommand`, `buildGroupAsSet`, `buildUngroupPortSets`, `setRolesFor`, `setKindOptions`, `portSetLabelIsTaken`, `uniquePortSetKey`; `Ctrl+G`, `Ctrl+Shift+G`, the group dialog, and the `ROLE` cell |

**WHAT M4-J2 DOES NOT DELIVER.** No `PassthroughPairDef` producer (`#225`). No set on the schematic
symbol or in the panel layout, both of which are banks' work (CR-055). And **no reader for `SetKind`
downstream of the builder**: it opens a role vocabulary and nothing in a drawing, schedule or rule
consults it yet.

#### 5.3.19 M4-J3, the pair with no creator, and the panel the model cannot describe · CLOSED · `b73e1f4`, `9cb1f51`

**Two commits, fourteen gates green on each.** `rackpal_core` **3,245 → 3,263**, `rackpal_ui`
**1,151 → 1,162**. `#762` is DR-087 (§11.86); `#225` is the action, the editable cell and the
commands under both.

**THE THIRD MODEL IN THIS ISSUE WITH A SURFACE AND NO PRODUCER, and the third FIELD with no
reader.** `PassthroughPairDef`'s only writer was `RenamePortKeyCommand`, rewriting pairs that
already existed, and `PAIRED WITH` was read-only. Beside it, `sameNet` joins `BankDef.order`
(§5.3.17) and `PortSetDef.kind` (§5.3.18): written by 24 seeded pairs, round-tripped, and consulted
by no trace, schedule or rule. **Three in one issue is not three coincidences.** All three were
modelled from a design document at M0 and the surfaces that would have exercised them were scheduled
four milestones later, so nothing failed in between.

**THE SEEDED CATALOG SHIPS A PASSTHROUGH THE MODEL CANNOT EXPRESS, and finding it took reading the
port loop rather than the field.** N04, the 24-fibre LIU, is `isPassthrough: true` with **12
`conn.lc_duplex` front adapters, 24 rear splices and zero pairs**. A duplex adapter carries two
fibres, so the relationship is **1 front : 2 rear**, and `PassthroughPairDef` holds exactly one key
each side. A naive pair-by-order would have written **twelve half-true pairings** and left twelve
splices looking forgotten rather than deliberately unpaired.

**DR-087 §11.86.4 LEAVES IT UNPAIRED, WHICH IS G4 APPLIED TO A JOIN RATHER THAN TO A NUMBER.** `LC 01
→ SPL 01` is not a rounding error: it is a row on the Termination Schedule naming one of the two
splices that adapter really terminates. Re-authoring the panel as 24 simplex ports would make it
expressible and was declined on AC-025's ground, which is N03's own description in the catalog:
modelling both faces the same way is the error that makes the schedule wrong on the one column the
trim tech needs. **Sometimes the honest answer is that the model is too narrow, recorded rather than
worked around.** A core case pins the 12/24/zero and asserts `rears == fronts * 2`, so whoever
re-authors N04 reads the reason first.

**THE ACTION IS ADDITIVE, AND THE ARGUMENT IS A REPAIR RATHER THAN A PURITY.** Replacing every pair
is the simpler rule and puts a hand-corrected crossing back on one press, twenty-four pairs deep in
the undo stack. The core case that proves the difference **crosses two positions on purpose first**
and asserts they survive the run; a case that ran once over a blank panel would have proved the
pairing and said nothing about the property that decided the design.

**IT REPORTS ITS OUTCOME AND NOT ONLY ITS REFUSALS**, which is new on this toolbar. *"Paired 12
ports. 12 rear ports had no partner left."* is the sentence that stops a person counting rows, and
it is the LIU's shape arriving on a template somebody authored.

**TWO TEST DEFECTS WORTH THE SPACE, both found by running rather than by reading.** `SET` and `PAIRED
WITH` are both a `DropdownButton` over a nullable string, so a finder written
`find.byType(...).first` picks the **SET** cell of row one: every `PAIRED WITH` case in the first
draft tested the wrong column and passed. And locating a row by its **label** broke the moment a pair
existed, because once F1 is paired with R2 the string `R2` is on screen twice, in R2's own label cell
and in F1's picker. Rows are found by **key**, which appears in exactly one place.

| Task | What it did |
|---|---|
| `#762` | DR-087 (§11.86): the additive run, the cell whose options are the validation, the LIU, and `sameNet` |
| `#225` | `AddPassthroughPairCommand`, `RemovePassthroughPairCommand`, `buildPairFrontToRearByOrder`, `buildSetPassthroughPartner`, `passthroughPartners`; the toolbar action and the editable `PAIRED WITH` cell |

**WHAT M4-J3 DOES NOT DELIVER.** The trace docs/06 §4.7 promises: nothing follows a pair from a front
jack to a rear punchdown, and `wire_trace.dart` does not mention passthrough at all. That is M5's and
M6's, and it is the reason `sameNet` still has no reader.

#### 5.3.20 M4-J closes, and what three unreachable models in one issue have in common

**`#181` IS CLOSED** with `#760`, `#223`, `#761`, `#224`, `#762` and `#225` all Done. Its title,
*"banks, port sets and passthrough pairing in the UI"*, describes an **editor over three existing
models**; the pick-up census turned it into **two missing producers plus a small action**, and the
build turned up a third missing producer and three fields nothing reads.

| Model or field | What was missing | Where it is recorded |
|---|---|---|
| `BankDef` | partly reachable: one writer, no rename, remove or mirror | §5.3.17 |
| `BankDef.order` | **no reader anywhere** | §5.3.17, canon §11.84.7 |
| `PortSetDef` | **no producer** under a live picker | §5.3.18, canon §11.85.1 |
| `PortSetDef.kind` | **no reader** outside the codec | §5.3.18 |
| `PassthroughPairDef` | **no creator** under a read-only cell | §5.3.19, canon §11.86.1 |
| `sameNet` | **no reader** anywhere | §5.3.19 |

**THE COMMON CAUSE IS SCHEDULING, NOT CARELESSNESS.** All six were modelled from a design document at
M0, encoded by the codec, and gated by the byte round trip. The surfaces that would have exercised
them were scheduled four milestones later, so between M0 and M4 nothing could fail: a field with no
writer round-trips perfectly, and a field with no reader round-trips perfectly too.

**AND THE CENSUS QUESTION THAT FINDS THEM IS NOT THE ONE THIS REPO HAD.**
`a modelled field is not a reachable one` prescribes *"grep for what WRITES it"*, which finds
`PortSetDef`'s shape and misses the other two entirely. The two that work here are **"where does a
person make the FIRST one?"**, asked of every collection a control offers choices from, and **"what
reads this, and what would it do differently if the value changed?"** Both are now in the OKF
practice.

**THE `rackpal_core` FIGURES IN FOUR COMMIT MESSAGES ARE THREE TOO HIGH, and the corpus is corrected
rather than the history.** `ab7eeb8` states the suite going `3,221 → 3,227` when the three cases it
added took it to **3,224**, and the next two commits and the merge did arithmetic on that base. The
true chain, measured file by file after the merge, is
**3,213 → 3,221 → 3,224 → 3,245 → 3,263**: the three new core files hold 27, 21 and 18 cases and
`bank_commands_test.dart` began the session at 16.

The messages are on `main` and stay as written, on §11.79.2's precedent for a ruling: a record says
what was believed on the day, and rewriting a pushed history to hide an arithmetic slip costs more
than the slip. **This paragraph is where the number is true**, and `counts written out in prose are a
liability` gains an instance whose whole content is that I stated a suite total instead of reading
one. `ui` was stated four times and was right four times, because those figures came off a run.

**Version `v0.4.63`, derived two ways that agree.** By hierarchy walk: Epic `#22`'s 21 issues hold 92
tasks, of which **63** are `Done` once `#225` and `#762` close. By arithmetic from the last release:
`v0.4.49` plus M4-R's **8** closed tasks (`#751`-`#756`, `#758`, `#759`; `#757` is the unrun printed
drill and is still open) plus M4-J's **6** (`#760`, `#223`, `#761`, `#224`, `#762`, `#225`) is **63**.

#### 5.3.21 M4-I, the three generators, and the spec that was already in the repository · CLOSED · `8c5d502`, `1910f84`, `3660b81`, `8f664fc`, `5d26036`, `84bb162`

**`#180` IS CLOSED** with `#220`, `#221` and `#222` all Done, six commits, fifteen gates green on
each. Three rulings: **DR-092** (§11.91), **DR-093** (§11.92), **DR-094** (§11.93). **77 core cases
and 37 UI cases**, counted off three runs rather than summed from the commit messages: 50 in
`archetypes_test.dart`, 27 in `port_import_test.dart`, 37 in `archetype_dialogs_test.dart`. The
floors moved core 3281 to 3358 and ui 1176 to 1213, which is the same 77 and 37 arriving a second
way.

**THE PATTERN OF THE PREVIOUS FIVE HELD FOR A SIXTH TIME, AND THIS TIME IT WAS AN ARITHMETIC HOLE.**
§5.3 records that every M4 issue so far turned out to be partly a corpus question rather than an
authoring job. M4-I's was a **count**:

> docs/06 §4.3's Matrix I/O checkbox list emits **67** ports. §9.2 step 6 promises **68 across 6
> banks**, and §9's target device enumerates all sixty-eight.

The missing one is `IR IN`, which §9.1 types at step 12 and for which §4.3's control list, written
as *"control (LAN + RS-232)"*, has **no producer at all**. That is
`ask what produces each task's input` arriving one level down from where the practice found it: the
feature's own worked example names a port the feature's own controls cannot make. DR-092 §11.91.2
puts it on the per-output IR tick, because a matrix that flashes emitters is routing IR and one
without them has nothing to route.

**FOUR MORE OF §4.3's CLAUSES WERE ILLUSTRATIONS.** "Above Quick Add" contradicts §2's own layout
sketch and the invariant §9.3 rests on. "Connector per side" cannot express either side of the
worked example, because `rj45` defaults to `net.ethernet` and the output side is `video.hdbaset` on
that same connector. "4 to 7 banks" describes a matrix somebody would author; the range the
generator enforces is **2 to 7**. And the de-embed default of `audio.line_bal` on XLR3 is right for
the family and wrong for every rack matrix ever built.

**THE SWITCH'S SPECIFICATION WAS ALREADY IN THE REPOSITORY, AND IT IS NOT §4.3.** `#221`'s whole
statement is one line. `catalog_network.dart`'s **N01** is a 48-port PoE switch with four SFP28
uplinks, an out-of-band management port, a front-panel console and two PSU inlets, authored at M0
and reviewed since. Censusing it answered four questions the line could not, and the most valuable
answer was **what N01 declines to say**:

| N01 writes | N01 omits | Why the omission is the finding |
|---|---|---|
| `PoeSpec.role: pse` | `PoeSpec.type` | A second spelling of `standard`; two fields holding one fact disagree the first time somebody edits one |
| `PoeSpec.standard` | `PoeSpec.watts` | N01 declares `btType3`, whose PSE maximum is 60 W, **and** a `poeBudget` of 740 W across 48 ports, which is **15.4 W each**. Writing 60 into every port offers a rollup 2,880 W on a device whose nameplate is 900 |

That is DR-079 §11.78's false pass, in the direction that does not announce itself, and the seed had
already declined to make it.

**THE ONE SHARED-COMPONENT CHANGE M4-I3 NEEDED WAS THE ONE THAT COMPONENT'S OWN COMMENT ASKED FOR.**
`readCsv` is comma-only and **refuses** a tab file rather than sniffing one, which is a problem for a
feature whose input is a spreadsheet clipboard. Its header states the shape the fix had to take,
verbatim: *"a ruling and a user-visible choice, not a counter"*. `CsvDelimiter` is a parameter
defaulting to comma, so every M3 caller is untouched, and the dialog exposes it as *"Tabs (from a
spreadsheet)"* / *"Commas (from a .csv file)"*. **No sniffing was added.**

**AND ONE COMPONENT COULD NOT BE SHARED, FOR A REASON CANON ALREADY RECORDS.** `csv_mapping.dart`
refuses a "discard this column" option outright, on docs/07 §5.1's unconditional rule that unmapped
columns are preserved into the row's `unknown` map. **`PortDef` has no such map**, and AC-012 (§2)
is why: *"`TemplateBody` is app-defined and closed; there is no forward-compat argument"*. So the
column is dropped and **counted** rather than dropped and hidden, which is the only honest option a
closed model leaves.

**FOUR DEFECTS, AND EVERY ONE WAS FOUND BY WRITING SOMETHING OTHER THAN THE FEATURE.**

| Defect | Found by | Class |
|---|---|---|
| A side whose type resolved to neither registry was labelled `IN IN 01`: the fallback substituted the direction word and then appended it again | a test over an unresolvable type | fallback that reads as a value |
| Every generated C14 claimed `Gender.genderless`, while `conn.iec_c14` declares `genderApplies: true` and all thirteen seeded C14 inlets write `male` | censusing the seed before writing the NEXT generator | **a non-nullable enum with a default has already answered before anybody asks** |
| The paste preview counted banks by looking for an explicit bank cell, so a sheet with no bank column previewed `0 banks` and then made one | the preview-versus-build test | two derivations of one number |
| The paste test's fixture said `Source (out)` in a direction column, a spelling `parsePortCell` refuses, and `direction == source` passed anyway off `video.hdmi.2_0`'s default | reading the assertion again after the connector column failed beside it | **a false pass in a test written to catch false passes** |

**THE SECOND ONE IS THE ONE WORTH KEEPING.** G4 governs nullable fields: *null is unknown, never
estimated*. `PortDef.gender` is a **non-nullable `Gender` defaulting to `genderless`**, so silence
there is not a gap somebody can later fill: it is a positive claim, made by the constructor, that
this connector has no gender. The defence is knowing which fields are shaped that way, and the
generators now write the one whose answer is definitional. `1 c14 in` through Quick Add still has
the defect, and the fix is a per-connector table of definitional genders that no registry field
carries.

**THE ALLOCATOR IS THE MECHANISM ALL THREE TASKS SHARE.** `buildQuickAdd` allocated keys, orders and
ordinals straight off `body`, which is correct while the one command list it returns is the only
thing in flight. Six plans from one button are not, and neither are forty-eight pasted rows: none of
their commands has run when the next is planned, so independent snapshots mint repeated keys.
`QuickAddBatch` holds that state across a run and `buildQuickAdd` became its one-plan case, so there
is **one allocator** and not three. A test generates a switch and a matrix into one template and
another pastes a sheet on top of an archetype, in both cases asserting that no key repeats.

**WHAT M4-I DOES NOT DELIVER.** The import is **not idempotent**, unlike `csv_import_plan.dart`'s
Structure re-import: a template has no `fieldLabel` to dedup on and CR-051's key join is a migration
record rather than a match key, so re-pasting the same sheet doubles the ports and `Ctrl+Z` is one
keystroke away (DR-094 §11.93.8). No accelerator is bound to any of the three buttons. And nothing
here pairs a passthrough: that is M4-J's and it is closed.

**Version `v0.4.66`, derived two ways that agree.** By hierarchy walk: Epic `#22`'s **22** issues
hold **92** tasks, of which **66** are `Done`. By arithmetic from the last release: `v0.4.63` plus
M4-I's **3** closed tasks (`#220`, `#221`, `#222`) is **66**. The issue count moved 21 to 22 since
§5.3.20 was written and the task count did not, which is a decomposition item added with no tasks
under it and does not touch the patch number.

#### 5.3.22 M4-L, the three doors and the fourth that needed a resolver first · CLOSED · `e58562f`, `c426060`, `76bcd5d`, `da750e0`, `b484241`, `e62c229`, `148d10e`, `a994a95`, `5631c8f`, `5b594ed`, `a33a71f`, `70d2cbe`

**Written on 2026-08-29, four days after the fact, and the delay is the finding.** M4-L closed at
`v0.4.73` on 2026-08-25 and this section did not exist until M4-M was already three chapters in.
For those four days the board said `Done`, the version said 73, and **the document this corpus
names as its evidence authority said nothing at all**. Nothing failed, because nothing gates it.
That is the same shape as `docs/13`'s D13 row (§5.3.23's M4-M1, and `docs/13` §2.3), one document further out: a record that
has stopped describing the tree is trusted exactly as much as one that has not.

**TWO RULINGS CAME FIRST, AND BOTH WERE CENSUSES RATHER THAN OPINIONS.** DR-098 (§11.97) and
DR-099 (§11.98) were settled before any code, on DR-077's precedent. Between them they found that
`DeviceOverrides` and `PortOverrides` had existed since M0, both codec-covered, both under CR-117's
byte gate, and **neither had ever been constructed by anything but its own class and the codec**.
Every `overrides` block in the shipped corpus was empty: four starters and six fixtures holding
800+ of them and **zero keys** between them, measured by walking the parsed JSON rather than
grepping a field name, because `displayName` also lives inside every `TemplateBody` and the naive
grep returns 847.

**THE MODEL CHANGE IS TRI-STATE AND THE THIRD STATE IS A PRESENT KEY** (`c426060`). CR-114 rules
that an unknown serializes as an **absent** key; on this type an absent key already meant "inherit
the template's value", so `null` was carrying two different statements. Spelling unknown as
`"weight": null` would have given two states one spelling and the file could not tell them apart.
The set of unknown fields therefore rides in a `cleared` list, omitted when empty, which every
override block in the corpus is: **the addition is byte-invisible to existing files and no
`kSchemaVersion` advance is owed**, asserted by a round-trip case rather than claimed. `cleared` is
sorted by the enum's own order rather than the set's, because Dart's `Set` iterates in insertion
order and two documents that cleared the same fields in a different sequence would otherwise write
different bytes.

**`displayName` AND `typePrefix` WERE DELETED AND NO TEST NAMED EITHER.** That is how the deletion
was checked: removing them broke nothing, because nothing had ever asserted them. The same absence
the ruling's census found in the shipped corpus, arriving from the other direction.

**DOOR 1's WIDGET TEST FOUND THE ONE PATH IT COULD NOT REACH** (`da750e0`), and it is the part
worth keeping. The first draft of the `Value` segment seeded its box from the template and bailed
out when there was nothing to seed from. **No demo template states a mass**, so tapping `Value` on
the demo rack did nothing at all: no box, no state change, no feedback. Stating a value for a fact
the template omits is door 1's commonest use, and it was the only path that could not be reached.
The assertion that now guards it is the **rollup**, not the field: DR-098 exists because a rack
subtotal could total a figure the user had no way to disown, so the unknown case drives the real
screen and reads `computeRackRollups`, asserting both halves.

**DOOR 2 IS A ROUTE AND A REFUSAL** (`148d10e`, `a994a95`), and DR-099 is why it refuses rather
than offers. `TemplateEditSession` is `late final` inside the builder's `State`, so handing that
screen a different template is ignored; loading one means a new `key`, which destroys the `State`
and the draft with it. **That is not recoverable in any sense**: the session is an in-memory deep
copy, so there is nothing for `Ctrl+Z` to reach and nothing on disk to reopen. The user is still
taken to the Device Manager, because *"finish it first"* is useless without showing them what "it"
is.

**DOOR 3 GAVE `derivedFrom` ITS FIRST PRODUCER** (`5631c8f`). `fork_status.dart` had carried
CR-062's stale-fork rule since M4-C and said in its own header that *"nothing writes a `derivedFrom`
yet"*: **the badge had a rule and nothing to badge.** A forked template now answers
`resolveForkStatus` against the source it was copied from.

**M4-L4 OWED A RESOLVER BEFORE A FORM, AND GOT ONE** (`5b594ed`, `a33a71f`), which DR-098 §11.97.6
ruled in advance. `PortOverrides` had **no reader anywhere in the tree**: three fields, codec-covered
since M0, under CR-117's gate, consumed by nothing. An editor written against that is §5.3.8's
finding one level down, a save that changes nothing a person can see. So `derived/port_facts.dart`
landed first and `connect_target.dart` came to it, which means a corrected connector reaches the pin
the connect gesture acts on and tier-1 rules are evaluated against. The load-bearing test is
therefore not *"the dropdown changed"* but that the **connect target** answers with the correction,
and it was watched failing with the resolver sabotaged.

**`PortOverrides.label` WAS DELETED AS A DUPLICATE.** It meant "what this jack is called on this
instance", which is exactly what `Port.userLabel` means, and `userLabel` is the one with a reader:
`schedule.dart` has printed it since DR-054. **No test named the deleted one either**, so the suite
could not have told anybody whether it worked.

**THE DEMO FIXTURE CANNOT EXERCISE THE PORT FORM, and finding that out changed the test.** The
first draft drove `RackCanvasScreen`, selected `SW-1`, a network switch, and asserted the section
listed its jacks. **The count came back 0: every template on the demo document has zero ports.** A
screen-level test would have been asserting an empty list while looking like an integration test.
The section is mounted directly over a document that has ports instead.

##### THE PIPELINE'S FIRST RED, and it caught something the local gate structurally cannot

`70d2cbe`. `run_local.ps1` passed all fifteen gates on that tree, and build `20260829.7` failed the
analyzer gate on `refs/pull/5/merge` with *"info count rose by 2 (173 → 175)"*. **Both were telling
the truth about different trees**: the local gate analyses the WORKING TREE and the service checks
out the COMMIT. Two `cascade_invocations` had been fixed and the fix was never committed, because
the file was `git add`ed BEFORE the fix and the commit that followed named a different pathspec, so
the index kept the pre-fix content while the working tree carried the corrected version. Every local
check after that read the corrected file and passed.

**`git add` THEN EDIT THEN `git commit <other paths>` IS THE TRAP**, and an explicit pathspec makes
it MORE likely rather than less: the pathspec protects a concurrent session's work and in exchange
silently omits a file the author already staged and then changed. A bare `git commit -a` would have
caught this and swallowed the other session's work instead. **Neither habit is safe alone**; the
check is `git diff` before committing.

**This is also the first evidence the service's failure-reporting path works at all.** §4.1 recorded
that every gate script had been mutation-tested locally while the service-side failure path was
exercised in the green direction only, and said not to treat a green Tests tab as proof the reporter
works. It is now proof.

**Version `v0.4.73`, derived two ways that agree.** By hierarchy walk: Epic `#22`'s **22** issues
hold **94** chapters, of which **73** are `Done`. By arithmetic: `v0.4.68` plus the five closed
since (`#230`, `#231`, `#232`, `#233`, `#794`) is 73. **The walk needed a different query than last
time**: DR-097 migrated every `Task` to `Chapter`, so the WIQL that derived `v0.4.68`
(`WorkItemType = 'Task'`) returns **zero** and would have produced a patch number of 0 with no
error. Counting by parentage rather than by type is what survives the migration.

**WHAT M4-L DOES NOT DELIVER.** The stale-fork badge still has no surface: `fork_status.dart` has
had its rule since M4-C, door 3 now gives it something to badge, and **a widget is still nobody's**
(§11.98.5). Nothing here touches the exit criterion.

#### 5.3.23 M4-M, the `.rmdx` file format and every path that reads one · CLOSED · `v0.4.78` · `106d195`, `13299bb`, `acb1952`, `6712bbe`, `1440cfa`, `bacc610`, `b74e1c8`, `7957313`, `aab6744`, `1059296`, `fa7f8ed`, `1e64e28`, `e389df3`

**Five chapters, two rulings, and four PRs, all green on the service before completing.** M4-M is
the first story in this milestone to land entirely through the branch policy CI made blocking
(§4.1), which is worth the line only because it is now unremarkable.

**FOUR OF THE FIVE CHAPTERS WERE PARTLY A READING JOB, and §5.3's own header predicted it.** That
header records the pattern across M4-A through M4-E: *"Four for four, the first useful hour went
into reading, not typing."* M4-M makes it nine for nine, and the two places the reading was skipped
are the two that had to be corrected afterwards.

##### M4-M1: the task asked for work another task had finished (`#234`, `106d195`, `13299bb`)

`#234` reads *"`file_dialog_channel.cpp` holds ONE hardcoded `COMDLG_FILTERSPEC` array shared by
Open and Save. Filter and default extension become parameters of the method call."* All of that was
true once and none of it still was: **`2180a35` (M3-F/4, `#162`) made the filter a named KIND on the
wire before M4 opened**, and said *"closing D13 before D2"* in its own subject line.

**The stale document was `docs/13`'s D13 row, and the board item is a transcription of it.** That
row was wrong in **all four** of its clauses, including naming an extension DR-015 had renamed, and
`docs/13`'s own preamble had predicted the consequence in terms: *"a row that has stopped describing
the tree is worse than a missing row, because it is trusted."* It was. `#475` and `#476` were opened
against it and part of `#234` was written from it. Cleared in `docs/13` §2.3.

**Canon was not stale**, so `re-read a task against canon` would have come back clean. The check
that finds this is one grep of the FILE the task names, for the noun it says is missing. That is the
practice's second arm and it is recorded there.

**What was actually owed**: the `device` kind `.rmdx` needs; a table in place of two parallel
ternaries, because two kinds fit `csv ? a : b` and three do not and a nested pair can then disagree
about what `device` means; and **the gate nobody had asked for**, that every `FileDialogType` value
has a `kFileKinds` row. That last one catches a SILENT failure: an unrecognised kind does not throw
and does not open an empty dialog, it falls back to the project filter, so an
`Export device template…` would offer `*.rmpj` and read as a mis-wired feature rather than an
un-taught runner. **Two assertions it replaced were mechanism assertions** pinned to the exact
source text of a ternary, which the third kind broke on contact.

##### M4-M2: DR-100, and a worked example with 21 holes in it (`#235`, `acb1952`, `6712bbe`)

Censused over `_encodeTemplateBody` rather than over the prose, and counted from the function
because `putIfNotNull` and three bare `json[...] =` assignments do not match the pattern the
always-on keys do:

| Measurement | Figure |
|---|---|
| Keys the encoder emits | **39** |
| Keys docs/06 §7.3's worked `.rmdx` places | **18** |
| Keys with no home anywhere in the corpus | **21** |
| Keys the example renames against the encoder | **2** |

**`model` was one of the 21.** It is required, always encoded, and DR-056 keeps it undefaulted
*specifically* so it prints as an unknown: it is the cell `docs/17`'s clause-2 drill is sent to look
for. A codec built from that example drops it, so **the field that proves G4 works would have gone
missing on the one path built for sharing a device.**

**The sections' footing was one sentence long, and inside a rejection.** CR-053's subject is the
override key namespace and it **refused** the dotted-path proposal the sections came from; they
survive only in that refusal's trailing clause, whose job is to say they do not define an override
namespace. Everything downstream restates it in a priority-3 document. Third instance of §11.56.5.

**The format was recognised, not designed.** A `TemplateSnapshot` already on disk in all four
starters is `{templateId, version, contentHash, capturedAt, body}`; the ruled `.rmdx` is that minus
`capturedAt` plus `schemaVersion` and `kind`. The gate is a **48-template byte sweep**, because the
defect DR-100 prevents is silent: an unclaimed key does not throw, does not warn and does not fail
to encode. A hand-written fixture asserts the fields its author remembered, which is the same set
that would have been partitioned.

##### M4-M3: DR-101, and the first answer that had to be overturned (`#236`, `bacc610`, `b74e1c8`, `7957313`)

**`templateIdFor` derives the id FROM THE DISPLAY NAME**, identically on every machine, which was
`#232`'s deliberate call so a person diffing two `.rmpj` files reads what the device is instead of a
UUID. Its consequence for import had not been written down: **a colliding id means "somebody typed
the same name", not "this template came back"**, and between two integrators documenting the same
class of hardware that is close to certain.

**The question was first put to the user pricing collisions as rare, and that premise was wrong and
load-bearing.** The answer chosen against it would have shipped the defect `templateIdFor`'s own
header refuses in terms: *"silently merging them would put one template's ports on the other's
instances."* Every placed instance of the incumbent would have taken a CR-062 stale-fork badge
pointing at somebody else's device. The question was put again against the measurement.

**Three discriminators were checked against the tree and all three fail**: `derivedFrom` is written
by door 3 only, so a door-2 fork carries no lineage; `contentHash` was a placeholder everywhere; and
a `.rmdx` carries one version rather than a chain, so a stranger who iterated their own same-named
device to `@4` is indistinguishable from yours returning at `@4`. **A version-keyed rule was drafted
and rejected on that third row.**

**A platform fact decided part of the surface.** DR-101 §11.100.5 rules the inert-data sentence into
*"the import dialog"*; `IFileDialog` has no body text, and adding any means `IFileDialogCustomize`,
a slab of C++ with no `NSOpenPanel` equivalent for D2 to inherit. So Import gained a confirmation
step the ruling did not ask for. It earns the click by printing the file's real contents before they
enter the document.

##### M4-M2/1: the hash was the easy half (`#795`, `1059296`, `fa7f8ed`)

**The census found something the task's own description did not claim: `contentHash` had NO
VERIFYING READER ANYWHERE.** It was written, round-tripped through the codec and never compared, so
AC-042's warning had no implementation rather than a placeholder input. Making the hash real and
stopping there would have moved `a modelled field is not a reachable one` one step along instead of
closing it, so the verifier ships in the same change and the import dialog is its first caller.

**The third state was the whole job.** Computing a sha256 is arithmetic somebody else wrote; the
risk was everything that is NOT a hash: ~150 test fixtures carrying `'h'`, every project ever
written carrying `sha256:seed-A01`, every builder save carrying `unhashed:<id>@<v>`. Reading any of
those as a MISMATCH badges every device in every document that predates the change, which is
AC-042's own reasoning arriving from the other side. `templateHashMatches` answers `bool?` and
`null` means *nothing to check against*: G4's shape on a comparison rather than on a value.

**A prefix is not a claim anybody checked.** Three placeholders read `sha256:` and none was a digest,
harmless while no value in the tree was one and three lies the moment one was. The verifier checks
length and alphabet; `sha256:structure-no-template` is re-spelled `no-template:structure`.

**THE CENSUS WAS SCOPED WRONG AND THE MISS IS RECORDED.** The first pass grepped
`packages/*/lib apps/*/lib`, found eight writers and handled them; **two more sat in `tool/`**, and
one of those generates four SHIPPED artifacts. The starters would have kept `sha256:seed-A01` while
a fresh blank project got real hashes: two conventions in one product, in the files a new user opens
first. Caught only because `generate_starters.dart --check` reported four files unchanged when they
should have moved, and had they been generated at build time rather than checked in, nothing would
have said anything. `census before building` gains the variant: **scoping a census by directory is a
filter that needs the same justification as a query.**

**A test was pinning the placeholder** as intended behaviour, and it was honest when written: that
WAS the behaviour and the label was deliberate. It failed on this change, which is the good case.

##### M4-M4: the caps existed and ran too late (`#237`, `1e64e28`, `e389df3`)

Three paths refused an oversized file only after `readBytes` had pulled it entirely into memory,
which is the cap doing its paperwork and none of its job, and **the CSV import had no cap at all**.
Every path now asks `stat` first; the in-memory check stays behind it, because a caller that must
read to parse has already paid.

**The gate found three call sites on its first run**, which is the argument for it existing.
`import_hardening_test.dart` is a **census as a test**: it sweeps both source trees for
`jsonDecode(` and `readBytes(`, comments stripped, and fails on a hit its own map does not name. Two
of the three were real import paths that read before they measured, and **one of those was `#236`'s,
two hours old**. Written this way because `#795`'s census was scoped by directory: a gate that lists
what it covers cannot tell you about what it does not.

**The third copy is where the rule broke.** The first draft wrote the check inline at three call
sites; two treated a stat that could not answer as "carry on" and the third let the failure escape,
turning a network blink into a broken backup-open on a path that had survived one for a milestone.
One function now, and `null` and THROWN are the same answer: **cannot tell**, and neither is
evidence a file is too big.

**An index-keyed fault silently retargeted.** `FakeFileStore` injects failures by operation index and
a test armed one at `operationCount + 1` with a comment naming which call that was. One added `stat`
made the comment false within the hour. **Probed rather than guessed**: the test fails at +1, fails
at +7 and passes only at +2, so it does discriminate. A positional assertion about a call sequence
retargets rather than failing to compile.

**The exclusions are argued in writing**, which is the corrected census practice in use.
`prefs.json`, `recents.json` and the recovery sidecar are written by this app into its own data root
and never picked from a dialog, so they are not *"arriving by email from strangers"* in D8's sense,
and capping them would let a corrupt prefs file refuse to start the app.

##### Version `v0.4.78`, and the disagreement that caught a mistake

By hierarchy walk: Epic `#22`'s **22** stories hold **95** chapters, of which **78** are `Done`. By
arithmetic: `v0.4.73` plus the five closed since (`#234`, `#235`, `#236`, `#795`, `#237`) is 78.

**They disagreed at first, 77 against 78**, because the arithmetic counted `#237` while the board
still had the card open: the work was finished and pushed and nobody had moved it. Counting twice
turned that into a five-second check instead of a wrong number in six files, which
`version_parity_test` is structurally blind to, being an equality check between the six.

**WHAT M4-M DOES NOT DELIVER.** There is **no library**. M4-N (`#170`) owns `.rmda`, the directory
service and more than one library in the palette, so an imported template lands in **this project
only** and does not appear in another job. The stale-fork badge still has no surface. And **nothing
here touches the exit criterion**: clause 2 is demonstrated by a person, and the drill is deferred
to the end of the milestone by the user's decision.

#### 5.3.24 M4-N, the library subsystem, and the palette that lists what it can place · CLOSED · `v0.4.83` · `2180a35`, `3c04f52`, `a6c972c`, `aab5900`, `cd252e8`, `99d5f5d`

**Five chapters, `#238` through `#242`, and the milestone's whole remaining library scope.** DR-015
§11.15.5 named four absences in 2026: *"no library directory service, no import/export surface, no
notion of a template's SOURCE library, and no palette filter keyed to one."* All four are now
built, plus the two things nobody had written down: what happens when you place a library row, and
what happens when a library will not open.

**THE HEADLINE: an imported library's devices are in the palette, filterable by which library
offered them, and placeable.** Before this, a template authored in one job travelled with that
project file and appeared nowhere else, which is the sentence
`device_builder_actions.dart` has been apologising for since M4-D and which requirement 2's
*"author the long tail once and use it everywhere"* was written against.

##### The chapter-by-chapter, and what each census found

| Chapter | What it built | What the census found first |
|---|---|---|
| `#238` M4-N1 | `library_directory.dart`, the writable shelf under the data root | The premise held. docs/06 §7.1 has named three storage locations since M0 and only two existed |
| `#239` M4-N2 | `rmda_codec.dart`, the archive format | DR-015's *"array of `TemplateBody`"* cannot carry a version, a hash or a source, so it writes the same entry `.rmdx` does and says so in its header rather than deciding quietly |
| `#240` M4-N3 | Import and export, with `#237`'s size cap on the read | Two defects only a pumped widget could see: a fixed-height picker overflowing the dialog by 56px, and an Export button that stayed enabled after the name was cleared |
| `#241` M4-N4 | `TemplateProvenance` as a sealed class; the merge | **The architectural call the chapter was going to make was already shipped.** DR-102 §11.101.1 recorded it: M4-S built `TemplateProvenance` on a runtime object in exactly the prescribed shape |
| `#242` M4-N5 | The source chips, and copy-on-place | **DR-102's palette lists rows the placement path cannot resolve**, and a click on any palette row had been announcing a refusal for a gesture nobody made |

##### `#242`'s finding, which is the one that would have shipped visible

`buildPlaceFromCatalogCommand` opens with `resolveLatestTemplate(doc, catalogId)` and has resolved
out of `RackDocument.templates` since M0. A library template is not in the document. So DR-102
§11.101.3's merged palette, built literally, lists a badged row that answers *"Unknown catalog
template"* on double-click and names an id the user can see on screen.

**DR-103 rules the mechanism, and it is AC-041 rather than a new idea.** v1 is copy-on-place: the
snapshot is embedded and `templateRef{templateId, version, contentHash}` records what was placed.
docs/02's rejected-alternatives table is blunter, naming *"a live library reference"* as what
embedded snapshots refuse and *"drawings that change silently across machines"* as the cost. A
device resolving out of a `.rmda` on one person's shelf **is** that alternative.

**THE ORDERING IS THE ENGINEERING.** The placement is built BEFORE the copy is committed, because
`transact` rolls back on a throw and a refusal is not a throw: adding the template first and
discovering "the rack is full" second leaves a template in the project for a device that was never
placed. `buildPlaceFromCatalogCommand` gained a `using:` parameter for exactly that one caller.

**AND `transact` ALREADY EXISTED**, which is the sixth time this milestone the hardest-looking item
was already in the tree. It groups any number of commands into one undo entry and applies each on
`add` so the next sees it, so the copy and the placement are one `Ctrl+Z` with no composite command
written.

##### The collision is the common case, and DR-101 answers it one level down

`templateIdFor` derives an id from the display name identically on every machine, so two libraries
that each hold an `HDMI Matrix 16x16` collide **by construction**. DR-103 §11.102.3's three cases
are all decidable with no prompt: the key is free (copy it verbatim, version preserved), the key
holds an identical body (copy nothing, and this is also every placement after the first), or the key
holds a different body (mint a fresh id at v1, which is `buildTemplateImport`'s `separateTemplate`
branch reached through the palette instead of through an import).

**The comparison is a RECOMPUTED hash over both bodies, not the two claimed strings.** Comparing
claims would answer "cannot tell" for every template written before `#795` and every hand-authored
one, and there is no user to ask in the middle of a double-click. What gets **written** is still the
claim, never the recomputation, or AC-042's mismatch warning becomes unreachable.

##### A defect older than the chapter that found it

Every pointer-down on a palette row arms a drag (AC-016 #23, no gesture-outcome branch). The
pointer-up reached `_commitOrNoopPaletteDrag`, found `phase != dragging`, and said:

> Released outside the rack — HDMI Matrix 4x4 was not placed. The Staging Bin is not in this build.

**For a gesture nobody made.** A single CLICK on a palette row did this, which docs/04 §3.1 step 1
defines as *"a click still means 'show details'"*; so did the second half of every DOUBLE-click,
landing after the placement and overwriting *"Placed MTX-1 at RK-1 U1, front."*
`DragPreviewPhase.armed`'s own comment says what it is, *"might still just be a click/double-click"*,
so the message now fires only from `lifted`.

**It was found because it was eating DR-103 §11.102.4's copy announcement**, and a grep found **no
test asserting that string anywhere in the repository, in either direction**. That is how it
survived a milestone. `palette_click_is_not_a_drag_test.dart` now holds all three cases including
the one that must keep saying it, and the fix is mutation-checked: removing the guard fails the
first two and correctly leaves the third green.

##### What the chips do NOT do, which is a decision

The source row appears **only when a library is on the shelf**, not merely when there is more than
one source. `All` / `Catalog` / `This project` on a project with no libraries is a real control and
was declined twice over: DR-077 §11.76.2's pinned group already answers the only question it could,
and **M4's exit criterion clause 2 is a stopwatch drill on this exact panel that has not been run**
(`#251`). Adding chrome above the search box changes the surface that drill will measure, for every
user who never loads a library. A session without libraries is pixel-identical to what shipped
before `#242`.

##### WHAT M4-N DOES NOT DELIVER

**No browser.** Favourites, smart folders and search over port signal families are M4-O's (`#186`),
and DR-102 §11.101.6 makes the palette usable without them, which is the whole reason its shape was
chosen over requiring a template to be added to the project first.

**No way to remove a library from inside the app.** The shelf is a folder, `#240`'s import is the
only thing that writes to it, and the file manager is the only thing that can take one off. DR-103
§11.102.9 names that as a real gap rather than closing it.

**Nothing here touches the exit criterion.** Clause 2 is demonstrated by a person, and the drill is
deferred to the end of the milestone by the user's decision. This is the fourth story in a row to
close without moving it.

#### 5.3.25 M4-O, the browser, and the menu item a doc comment invented · CLOSED · `v0.4.86` · `75f922a`, `5fffd24`, `9a9b27a`, `d9024f2`, `8e26df8`

**Three chapters, `#243` through `#245`, and the last of DR-015 §11.15.5's four named absences.**
The `Device Manager` tab has carried that name since DR-091 and rendered `DeviceBuilderScreen`
directly: a *manager* showing one editor and no list. It is a browser now, and the editor opens from
it.

**THE HEADLINE IS A CORRECTION AND IT IS RECORDED HERE RATHER THAN IN A COMMIT NOBODY REREADS.**
DR-104 §11.103.2's first draft said the tab's new-template entry point had to be rebuilt in the
browser *"and `Project ▸ New device template…` must keep working unchanged, because it is what
`#251`'s stopwatch drill uses"*. **There is no `Project` menu.** The application has exactly one,
`File`, with nine items, and no new-template item anywhere.

The sentence came from a doc comment in `app_shell.dart` opening *"docs/06's Device Builder, from
`Project ▸ New device template…`"*, which documents a method that no longer exists. That is
[don't price a decision off a derived artifact] firing on a **ruling** rather than on a task, and it
is the second time in this corpus a comment has been read as a product fact. Canon §11.103.2 now
carries the correction.

**It changed what the chapter was.** With no menu route to fall back on, `#243` either shipped the
entry point or M4 lost the ability to author a device, so the browser's own button is load-bearing
and its test asserts the callback fires rather than that the button renders. **And `#251`'s drill
route is `Ctrl+2`**, not a menu item; the drill's first step was corrected before it was run.

##### The census moved the cost in both directions

`#186` was written in 2026 against a tree with none of the library subsystem in it. Four of the five
things it asks for already existed by the time it started:

| What `#186` wanted | What was already there |
|---|---|
| A list of every template | `buildPlaceableTemplates(doc, libraries:)`, merged and tagged, landed the day before (`#241`) |
| Search over port signal families | `PortDef.signalFamily` is on the DEFINITION, so it is a scan and not a resolver |
| `Used in this project` | `countDevicesOnTemplate` |
| Somewhere for favourites | `AppPrefs`, already persisting per-user collections in that exact shape |
| The elevation strip as a card thumbnail | **Nothing.** `buildRackScene` takes a document and a rack |

**The expensive item is the one the chapter did not flag**, which is the eighth time this milestone
a census has moved a chapter's price and the second time it moved it both ways at once. DR-104
§11.103.3 substitutes M4-R's glyph mark and **records the substitution** rather than making it
quietly: the mark is the device's identity on the real elevation since M4-R, and a strip would need
a synthetic one-device rack and a full `buildRackScene` per card on the one surface whose card count
is unbounded. Anyone overturning that should bring a measurement at 200 cards.

##### `#244` was nearly built wrong, and the corpus stopped it

The obvious implementation of *"search over port signal families"* is
`resolveSignalFamilyToken(registries, query)`. That function's own docstring refuses it:

> **THREE CALLERS NOW, AND THE THIRD IS NOT A COPY.** The SERVICE picker's filter box also has to
> understand `hbt`, but it FILTERS where this RESOLVES: `@signal=hdb` must refuse, and typing `hdb`
> into the box must show HDBaseT.

A resolver matches a whole token exactly. Using it would have made `hdbaset` work and `hdb` fail,
which is the wrong half. The matcher is the **fourth** caller of that vocabulary and the **second**
that filters, built the way the filtering one is built.

**IT IS ADDITIVE BY CONSTRUCTION, AND `#251` IS WHY.** The palette's search is the field the
stopwatch drill measures and the drill has not been run, so no query that matched before may stop
matching. Two keys: `plain` is the old comparison exactly, `ports` is the new vocabulary, and a hit
on either is a match. `model` joined the plain key because `#244` asks for `16x16` in terms and it
was in none of the five fields.

##### What the tests found that the gates could not

**A 2px overflow, twice in one milestone.** The star's `IconButton` has a 28px minimum tap target
and the browser card's fixed 132px extent could not hold it: the yellow and black stripe, on the
first run of `device_browser_screen_test.dart`. `#240`'s export picker was the same shape. **A fixed
extent is this milestone's most reliable defect**, and only a pumped widget has ever caught one.

**A missing `setState` that door 2 was getting away with.** `_openTemplateForEditing` assigned
`_editingTemplateId` without notifying, which reached the screen anyway while the tab built the
builder unconditionally, because the tab switch WAS the rebuild. The moment the tab has to choose on
that field, door 2 opened onto the browser. `door_two_test.dart` caught it, and one of that file's
cases would otherwise have gone on passing while asserting a refusal that could no longer fire,
because the tab's first `TextField` is the search box now.

##### What M4-O does NOT deliver

**No RU-height or mount-method chip.** Both are VALUE filters and not yes/no ones: a useful RU chip
is `1U` / `2U` / `3U+`, and *"has an RU height?"* is true of everything. They are a different
control, worth building, and named as absent rather than shipped as something that reads like a bug.

**No `Recently used` smart folder.** `Used in this project` ships as a chip over an existing
producer; recency has none. It needs a per-user MRU written on every placement, which is a store
plus a callback from `rackpal_ui` to the shell, and it is scope this chapter did not price.

**No discard-and-return route out of the builder.** Save-and-close returns to the browser, which is
safe because the draft is saved by definition, and it is also the first thing ever to clear
`_editingTemplateId`. Going back with a DIRTY draft is the case DR-091 §11.90.6 protects with
`wantKeepAlive`: the builder holds an edit session, not a view, so swapping it for the browser
destroys the copy that makes closing without saving a complete undo.

**The browser does not place.** DR-104 §11.103.2 made it a full tab, so placing from it would mean
switching tabs mid-gesture and choosing a rack the user cannot see. No ruling grants that.

**And nothing here touches the exit criterion.** Clause 2 is demonstrated by a person. That is now
**five stories in a row** to close without moving it, and `#251` is the only work left on it.

#### 5.3.26 M4-K, the rear panel that is derived, and four assumptions the tests refused · CLOSED · `v0.4.89` · `0a37a27`, `9e4be83`, `711330b`, `d1905d1`, `6938d17`, `a075c18`

**Three of four chapters. `#227` is parked by ruling, not dropped.** DR-105 §11.104.6 defers the
nudge canvas and names the milestone it stays under; §8.9's discharge rule is satisfied by a park
with a reason, and the reason is that CR-071 part 1 calls the canvas optional in terms while the
model half of it shipped anyway. `PortDef.position` is nullable, an override beats the flow, and
`PanelSlot.nudged` reports which is which, so `#227` is now UI-only work over a finished model.

**The panel is DERIVED and never stored.** docs/06 §5's non-negotiable, that a template with no
layout data is complete, holds here by construction: nothing downstream reads a coordinate, and
`buildPanelGeometry` writes nothing. Schema 3's migration dropped 727 explicit zeros that had been
serialising as *measured* positions under G4/CR-114, which is the invariant that made the
nullability worth its cost rather than a tidy-up.

##### One drawing, or it is not a drawing

`#229`'s whole content is a refusal: **a preview-only widget is forbidden**, because CR-086's sharp
form is that a symbol which cannot print is not a symbol. Two drawings of one thing disagree
silently, on paper, which is the half nobody looks at until a job site does. That forced three
pieces of work that a hand-drawn Flutter `Path` would have skipped:

| The cheap version | What landed instead |
|---|---|
| A `CustomPainter` shaped like a rack strip | `buildDeviceLayer` over a placeholder `DeviceInstance`, replayed through `FlutterDiagramCanvas` |
| A symbol sized in the widget layer | `sizeSymbolForBody`, extracted from `schematic_scene.dart` and asserted against it over all 93 fixture devices |
| Cutouts drawn from `RenderedPanel` coordinates | `buildPanelLayer`, emitting the same `DiagramOp` IR every other layer emits |

**The symbol extraction was not a convenience.** `schematic_scene.dart` already carried a warning
that its gu-denominated sizing and `buildSymbolGeometry`'s diagram-unit sizing are *"the two
transcriptions"* a test keeps in agreement. A third transcription in `rackpal_ui` would have been
reachable by no test in `rackpal_core`. The split is now by INPUT rather than by behaviour:
everything derivable from a body plus a measurer is public, everything needing the document stays
private.

##### Bank collapse, and the baseline that decided where it switches on

CR-103 rules that banks over eight auto-collapse *"on first layout AND in the symbol preview"*.
`#229` requires the preview to use the real builder, so building it there offers the schematic
canvas the same behaviour in the same commit. **It is off by default and the preview passes
`true`.** Turning it on for the canvas invalidates `schematic_perf_test.dart`'s **4155-op** M2-C
baseline and every schematic golden, mid-M4, for a canvas nobody is currently editing. Regenerating
those is cheap; deciding whether the new numbers are RIGHT is not, and that judgement belongs to
whoever is looking at the schematic. CR-103 is therefore honoured in one of its two named places
and the other is owed as `#801`.

**It forced a refactor rather than a flag**, and this is the part worth keeping. The sizer counted
every port to reserve the box; the builder assigned ports to edges separately. Two loops doing the
same arithmetic, survivable until collapse existed: **a sizer counting 48 ports while the builder
draws one pin reserves 24 pitches of empty edge, and nothing in this repository would have reported
it.** Edge assignment happens once now, in `layOutSymbolEdges`, and both callers consume it, so the
flag cannot be honoured by one and not the other by construction rather than by care.

`BankDef.collapseInSymbol` has defaulted to `true` since board 96-L and **nothing had ever read it**;
22 seeded banks above the threshold carried the value inertly. This is the code that reads it.

##### Four assumptions the tests refused, and one that reframed the invariant

The pattern is the same one this board keeps recording, and the count is the point: **five
belief-shaped assertions this milestone, four of them in this story.**

| I asserted | The measurement |
|---|---|
| 40 RJ45 ports overflow a 1U panel | They do not. A cutout is 10 mm, so 40 is 400 mm inside a 432 mm chassis, one row. The seeded **N01** is used instead, and it is one of exactly two archetypes that genuinely overflow |
| A zero-U body draws nothing | It lays out and draws normally. `frontU`/`rearU` are RACK occupancy, and a wall plate has holes without occupying any U. The refusal belongs in the widget, which knows what it is drawing into |
| Collapsing never makes the reserved box taller | **V01: 67gu loose, 69gu tight**, and correct. See below |
| A01 is front-only | A01 is 3U front **and** 3U rear, as most chassis are. Exactly four seeded archetypes are front-only and **N03** is the only one with ports |

**The V01 case changed a test rather than a line of code, which is why it is the valuable one.** The
reserved height carries the top/bottom label bands, whose depth is the *widest* label, because #96-A
turned those labels a quarter turn to read inward. Collapsing swaps sixteen short labels for one
long `AUX[1..16]`, so the band deepens as the pin run shortens. **Enforcing my rule would have made
the sizer reserve less room than the builder draws in**: the exact defect the refactor existed to
prevent, introduced by the test written to prove it had been prevented. The assertion is now the
invariant stated directly: the reserved box contains the drawn box, both axes, every seeded
template.

##### Three gates caught what reading the diff could not

Recorded because all three failures **render**, which is the class this corpus keeps finding:

- **CR-082's stroke knobs.** `draw_source_gate_test.dart` refuses a `Stroke` that names
  `hairlineFloor` while inheriting `scaleWithGeometry`; the chassis field did exactly that. The
  analyzer then called the explicit default redundant, so two gates disagreed and the source gate
  won, matching `symbol_layer.dart:722`'s record of the same standoff.
- **The font-weight coverage gate.** The overflow chip asked for `w600`. Jost bundles exactly
  Regular and Medium, so **Flutter would have synthesised it and nothing would have failed**: it
  would have looked slightly wrong on screen and printed differently, forever, with no error
  anywhere.
- **The port grid's own empty text.** The symbol pane's empty state read "No ports yet", which is
  what the grid six inches to its left already says. Two widgets carrying one string is how
  `find.text` locates the wrong one and passes.

##### The dock yields to the grid, and the threshold is measured

340 px of dock on a narrow window leaves the port grid too little to draw its own archetype bar: at
434 px it overflows by 203, so the bar alone needs about 637. Add the 200 px section rail and the
dividers and the floor is a shade over **1180**. A grid that cannot draw its own toolbar is worse
than a preview a person cannot see, and docs/06 §2 sizes this window for *"a 68-row virtualised
grid"*, so the dock is what gives way. **`#802` owes this window a real narrow layout.**

> **SUPERSEDED at §5.3.29 (DR-108).** The arithmetic above stopped one term short: the floor is
> **1203**, not 1180, so the dock was admitted 23 px before it fit, and that band is the only part of
> this a person could reach. It also measured the ARCHETYPE BAR rather than the dock, since the grid
> scrolls its own columns and nothing else in it had a floor. `#803` made the bar a `Wrap` and the
> floor is gone; `kPreviewDockMinWindow` is deleted.

**The first attempt at that gate silently did nothing.** It used a `LayoutBuilder`, and a `Row`
hands its non-flex children unbounded width, so it read `maxWidth: infinity` and drew the dock at
every size while looking like it was measuring something. It measures the window now.

**A separate finding, filed rather than fixed: the port grid overflows an 800 px window by 63 px on
its own**, with the dock already gone. That predates this story. The dock test does not assert it
clean, which would fail for a defect it does not own, nor assert it dirty, which would pin the
defect as intended behaviour: `#803` holds it.

> **CLOSED at §5.3.29.** The 63 px is real and **no window can reach it**: `kMinWindowWidth` is 1000
> and the builder is a `Dialog.fullscreen`. Wrapping the archetype bar fixed it anyway, and turned up
> the reachable defect this ticket was not looking at.

##### What this does not do

T2.02, the printed Rear Panel sheet, is **not fed by `buildPanelLayer` yet** (DR-105 §11.104.5).
That is a wiring decision rather than a capability one, and when the sheet is built it calls this
function rather than growing its own. The symbol still defers connector glyphs, pin colour by
domain and the model line under the name, all on `symbol_layer.dart`'s own list; pulling them in
here would put them in the preview and not on the sheet, which is the divergence this story exists
to forbid.

**And nothing here touches the exit criterion.** Clause 2 is demonstrated by a person. That is now
**six stories in a row** to close without moving it, and `#251` is still the only work left on it.

---

#### 5.3.27 The nudge canvas, un-parked, and a twelfth that meant two things · CLOSED · `v0.4.90` · `b82cbe1`, `2761ce4`, `7981669`

**`#227` was parked and is now built.** DR-105 §11.104.6 deferred it; M4-K closed without it at §5.3.26;
DR-106 §11.105.1 lifts the park. **M4-K stays closed and the chapter was re-parented to `#804`**, because
§8.9 makes closing the binding moment and §5.3.26 is the record of a story that closed with three of four
chapters and a named park. Reopening it to tidy a board would falsify that record.

**Nothing in DR-105 §11.104.6 was wrong.** The reasons it gave for parking are the reasons the park was
cheap to reverse: CR-071 part 1 calls the canvas optional in terms, nothing downstream reads a coordinate,
and the expensive half shipped anyway. `#227` was UI over a finished model.

##### The interaction, which CR-071 named and DR-105 §11.104.8 explicitly declined to decide

| Question | DR-106 | Why the alternative lost |
|---|---|---|
| Where does it live | A sixth rail section, `Panel`, after Ports | The dock is 340 px and the drawing is 482.6 mm wide. `#802` already records that this window has no narrow layout |
| One arrow press | 1 mm; `Shift` 0.1 mm, `Ctrl` 10 mm | 1 mm alone is forty keypresses to move a jack 40 mm. CR-071 says 1 mm **snap**, not 1 mm only |
| `Reset to auto` | The selection when there is one, everything when there is not | One control whose label says which it will do before it is pressed |
| Align/distribute | Six align, two distribute | Distribute is the load-bearing half: it is what turns eight hand-nudged XLRs into a row |

##### The arithmetic is in core, and that is not tidiness

`panel_arrange.dart` builds every edit as `SetPortFieldCommand`s and mints no command type of its own,
which is `port_commands.dart`'s own rule read literally: a single typed write to a single port is the
shape that command already is, and a bespoke one would be a second undo path to one field. **Sixteen core
tests assert the geometry without pumping a widget**; the canvas's own eighteen assert only what a widget
test can see and a core test cannot.

**Distribute equalises GAPS, not centres**, and the reason is this drawing specifically: a rear panel
mixes cutout sizes constantly, a 19 mm XLR beside a 10 mm RJ45 beside a 24 mm binding post. Even centres
leaves the gaps visibly uneven, which is the "eight near-misses" look the operation exists to fix.

**And the first fixture written for it could not tell the two apart.** It read `rj45 / xlr3 / rj45`, and
with equal END widths the centre spacings are `w/2 + gap + wm/2` on both sides, so equal gaps IMPLY equal
centres and the assertion passed for the wrong reason. The odd width has to sit at an end. **That is the
sixth belief-shaped assertion the tests have refused across M4-K and this chapter**, and the only one
where the defect was in the fixture rather than in the claim.

##### A twelfth meant two things, and no test could see which

`PanelPosition` is `{ruOffset, xTwelfth, xFineNm, yFineNm}`. **The corpus declares the field and never
says what the twelfth measures.** `#226` implemented `kRackUnit.nm ~/ 12`, 3.70 mm, under a comment
calling it *"docs/research's twelfth-of-a-rack-unit grid"*, which the corpus does not say anywhere. DR-106's
first draft then asserted 40 mm as a statement about that same code. **So the ruling and the
implementation disagreed, and both were confident.**

**Ruled at DR-106 §11.105.7: a twelfth of `kPanelWidth`, 40.22 mm.** `ruOffset` + `yFineNm` is coarse plus
fine vertically, so the x pair must mirror it, and a 3.70 mm coarse unit beside a nanometre-precision fine
field buys nothing: nothing would ever set it. The corpus reaches the same place independently, since all
three of its worked examples carry `xTwelfth: 0` with the offset in `xFineNm`, at 12.7 mm and 25.4 mm.

**Why nothing caught it.** `panel_layer_test.dart`'s override test pinned `y` and did not pin `x`. It pins
x now, which is the whole reason this was a one-line change rather than a migration: every stored value is
0, and DR-106 makes nudging never write the field. **Exactly the position `BankDef.collapseInSymbol` was in
when its default was corrected while inert**, one story earlier.

##### Two decisions where a comment is the only thing standing between correct and plausible

**The selection halo is deliberately NOT a `DiagramOp`.** Everything else this canvas draws is, per CR-086.
But CR-082 rules that selection halos are screen chrome and constant in device pixels, and an op would be
replayable into the PDF backend: the first person to wire this panel to T2.02 would print somebody's
selection. It is drawn straight onto the Flutter canvas, stroke width divided by the scale.

**Toolbar buttons disable rather than silently no-op.** `buildPanelArrange` already returns an empty list
below `minimumSelection`, so an enabled button would be a control that does nothing and says nothing. The
widget test reads `onPressed` rather than a pixel, because a disabled-LOOKING control that is really live
is the same shape as twelve green assertions on a line reading `1 ports`.

##### What the gates caught that reading the diff did not

`port_commands_test.dart` walks `PortDefField.all`, writes a probe through every entry and reads every
field back to prove none is aliased onto another. Its default arm fails with
`no probe for panelPosition: teach this switch its type`.
**A field with a new type cannot silently join that table**; the test
refuses until somebody writes a probe. That is "one entry per column, and no entry without one" enforced
mechanically rather than by comment, and it is the fourth gate in two stories to catch something a careful
reading of the diff did not.

##### What this does not do

It does not touch the v1.1 interactive Rear Panel view (`Ctrl+3`), which CR-071 part 3 places outside v1.
It does not feed T2.02, still DR-105 §11.104.5's. It does not make a nudged position mean anything to the
netlist, the schedule or any export: ports connect by IDENTITY and a coordinate is a drawing fact. And it
does not refuse an overlapping or off-panel nudge (DR-106 §11.105.6), because a person who drags two
cutouts together is describing hardware this model does not know about.

**And nothing here moves the exit criterion.** Clause 2 is a person, and `#251` is still the only work left
on it.

---

#### 5.3.28 M4-P, three chapters that were each something else underneath · CLOSED · `v0.4.93` · `6649cf1`, `bcb89bf`, `6cff4dc`, `7b2c098`, `60d45b9`

**M4's last buildable story.** Three chapters, and **all three were smaller in the part their board
item described and larger in what a census found**. That is the pattern this milestone has been
recording since §5.3.26, stated here once more because it stopped being a coincidence three stories
ago: the board item names the intent, the code says what is actually missing, and they differ nearly
every time.

| Chapter | What it read | What it was |
|---|---|---|
| `#246` | *"fewer sections, same three required fields"* | The builder **could not save a field device at all** |
| `#247` | *"the media-type editor"* | Create already shipped at M3-F/6; the gap was **merge** |
| `#248` | *"connector aliases"* | The resolver already honoured them; only the **writer** was missing |

##### `#246`: a save gate that refused an entire device class

AC-049's gate accepted a zero RU height only when `side == zeroUVertical`. **Every one of AC-031's
18 shipped field templates is `{front: 0, rear: 0, side: none, notInRack}`**, so `Save` was disabled
for all of them and stayed disabled whatever the person typed. The 18 ship in the seed catalog and
nobody could author a nineteenth. It went unseen because a rack device cannot reach that state and
the field-device path had no test, so every existing builder test passed.

**The fix re-opened the hole the gate exists to close, and five tests said so.** `notInRack` was
`TemplateBody`'s DEFAULT, so admitting it let a blank new template save with no height: the stall
AC-049's own comment names. A default cannot be evidence that a zero was MEANT; `zeroUVertical`
works in that role precisely because nobody reaches it by accident.

**So the default moved to `rackEars`**, which restored the gate's reasoning intact and fixed a second
defect nobody had filed: every new template was opening in the stripped field-device form, rack
fields hidden, until the author found the Mount method dropdown.

**MEASURED RATHER THAN REASONED, because 92 files construct a bare `TemplateBody`.** All five suites
were run under the change before it was kept: core 3625, export 189, app 916 unchanged, and exactly
one ui test moved, one asserting the old default's LABEL. Persistence was checked too and is
untouched: `json_codec` writes `mountMethod` unconditionally and its reader carries its own separate
`?? 'notInRack'` fallback, so the two defaults are independent and no stored file is reinterpreted.
The WIRE fallback deliberately stays.

##### `#247`: a rename cannot reunify what an import split

`AddMediaTypeCommand` and `mediaTypeIdFor` already existed, built for the CSV import. RJ-012 ships
this editor *"because users hit it"*, and `csv_import_apply.dart` is how: an unmatched value CREATES
a media type rather than rejecting the row (RJ-009), which is correct. A typo in row 40 therefore
becomes `media.cat_6e_riser` beside `media.cat6e`, and the schedule prints two rows for one cable.
**The duplicate is already written into cable runs, so only a merge can fix it.**

The id freezes at creation, which is what makes an edit one map write: re-deriving it on rename
would be a document-wide rewrite and CR-117 would see the whole file churn for a cosmetic edit.

**The merge test does not enumerate the fields.** It serialises the document and asserts the loser's
id appears NOWHERE in the bytes, so a sixth field naming a `MediaTypeId` fails that test rather than
being silently orphaned. Mutation-tested: skipping the pathways loop makes it fail.

**Two census misses, both mine, both caught.** `Outlet` has no media at all: the field is on
`OutletDrop`, which hangs off `OutletTemplate.drops` in the REGISTRY, and the first draft wrote
`Outlet.media` from a grep that found the field and assumed its owner. And the fixture referenced
only three of the five fields, so the "nowhere in the wire" assertion would have passed over a
command that ignored `Link` and `Pathway` entirely.

##### `#248`: the chapter was a refusal

`resolveConnectorToken` already resolved a typed token by alias, then by the id's tail. Only the
writer was missing. **A colliding alias is refused before it is stored**, and the refusal names the
owner, because the resolver returns the FIRST match in map order: two connectors answering to one
word would resolve differently in two documents with the same registries.

**The two refusals are now a gate rather than a sentence.** RJ-012 rejects a general registry
authoring UI; AC-011 withdraws user-authored validation rules from every document, because rules are
Dart functions keyed by `ruleId` and a UI for them would make the app an interpreter for user input.
`refused_surfaces_test.dart` fails if a command creating a signal family, a connector type, a colour
scheme or a validation rule ever appears. The ruling states the reason, the test states the
consequence: the split this repository already uses for PAL-1 and the analyzer pin.

**It carries its own vacuity guard**, because a test about an absence is the easiest kind to pass for
nothing: the scan walks `../<package>/lib` relative to the CWD, and if that stops resolving every
refusal passes over an empty list. A test asserts the walk sees 200+ files and a known one by name.

`RuleOverride` turned out to argue AC-011 harder than the ruling does. It requires a severity, a
**reason**, an **author** and a **time**: a signed exception to a shipped rule, with nowhere to put a
condition. The test pins it against ever gaining an `expression`, `predicate`, `script` or
`condition`.

##### RJ-012 is two-thirds met, and this says so

The ruling names **three** v1 surfaces. The third, *"a per-family colour override row in settings"*,
has nowhere to go: `ProjectSettings.familyColorOverrides` exists and `signal_style.dart` consumes it,
but **no file in `rackpal_ui` or `apps/rackpal` references it**, and roughly twenty `ProjectSettings`
fields have no producer at all, including `displayUnits`, which CR-097 makes authoritative over any
app preference. There is no settings surface in the app and none assigned to any milestone; the
corpus's only mention is M1's own deferral list, item 5, left unowned. **`#805`.**

##### And one ruling clause was withdrawn before it was built

DR-107 §11.106.4 first ruled that a field device's panel should take its height from its own cutouts.
The code was written, two tests refused it, and the census those failures forced overturned the
clause: `T2.02` is `Rack Elevation: Rear`, one per `Rack`, so a field device never appears on it, and
**no shipped field template is a plate** anyway. *"Wall plate, parametric N keystones"* comes from a
critique's wishlist that AC-031 did not adopt. `#806`, filed against the plate width, was withdrawn
too: `plate_geometry.dart` already carries caliper-measured plate dimensions under DR-041/DR-042.

**Both errors were priced off a description rather than off the code**, which is the one habit this
milestone can point at and say cost something every time it appeared.

##### What is left

**M4 has no buildable chapters.** `#250` and `#251` are M4-Q, the drill: a person, a stopwatch and a
document to read. Clause 2 has now survived **eight stories** closing without moving it.

---

#### 5.3.29 Four debt chapters, three of which were filed against the wrong thing · CLOSED · `v0.4.93` · `67c9a68`, `8259526`, `2f20c5a`, `c4079d7`

Story `#800` held M4-K's three findings and `#805` produced a fourth. **The version does not move**:
all four sit under epic `786`, DR-097's cross-cutting debt epic, and docs/14 §14.0 counts Done
chapters under the CURRENT milestone's epic, which is M4's `22`. `#805` set that precedent three
commits earlier.

**`#807`, and `IdFormat` validates nothing.** `const IdFormat(this.pattern)` stores the string and
checks none of it; `IdFormatSyntaxException` comes from `_parsePattern`, which only `render()` calls.
So the codec accepted **any** string a file carried, and a hand-edited or corrupted `.rmpj` opened
cleanly and threw the first time a designator was minted, a whole subsystem away from the field that
caused it. `_decodeIdFormat` now forces the parse for all six settings patterns and names the field
it refused, following `json_codec.dart`'s own stated convention rather than a new one: every enum but
two decodes through the strict throwing path, *"which surfaces as a whole-document `Err` at the
`read()` boundary rather than a silent guess"*, and substituting a default pattern for one an author
did not write is exactly that guess (G4, CR-114).

**THE TWO CHECKS ARE NOT DISJOINT, which the first draft assumed.** `unrecognisedTokens()` is
regex-based and never throws; `requiredTokens()` runs the parser and throws for a malformed pattern
**and** for an unknown token name. Running the throwing one first while catching only the syntax type
let an unknown token escape unhandled. `project_settings_dialog.dart`, built five days earlier under
`#805`, had the identical mistake one package away, where `N{NOPE}` threw straight out of a text
field. The wire test caught it there first.

##### `#803` was filed against a width no window can open

The ticket says the port grid overflows an 800 px window by 63 px, in the `Row` at
`port_grid.dart:1456`. That is true and it is **unreachable**: `kMinWindowWidth` is 1000, enforced
through `setMinimumSize`, and the builder is a `Dialog.fullscreen`. Sweeping the range a person can
actually reach found the defect that mattered, and it was not the one filed.

| window | before |
|---|---|
| 1000 to 1179 | clean, the dock is off |
| **1180** | **overflows by 23** |
| 1190 | overflows by 13 |
| 1200 | overflows by 3 |
| 1203 | overflows by 0.0000076 |
| 1210 and up | clean |

`kPreviewDockMinWindow` was 1180 and the layout did not fit until 1203, so **the dock was admitted
23 px before there was room for it**. Its own doc comment called the number *"MEASURED, NOT CHOSEN"*
and put the floor at *"a shade over 1180"*; the arithmetic stopped one term short.

**The fix is structural rather than a nudge to the constant.** As a `Row`, `_ArchetypeBar`'s three
buttons had a hard natural width of about 637 and **nothing else in the grid had one**, because the
grid scrolls its own columns. The bar alone set the floor under the whole window, which is why a dock
threshold existed at all. Wrapping it removes the floor, and 1180, 1190 and 1200 all go clean without
the constant being touched. `_Toolbar` gets the same treatment, beyond the ticket's letter and
load-bearing for what follows: with both bars wrapping, the dock fits at **1000**.

**A fourth finding, filed rather than fixed.** At 800 px the header's inner controls `Row` overflows
by 22. `_Header` is already a `Wrap` for exactly this reason and keeps its controls as ONE wrap child
on purpose, so `Save` and `Save & Close` cannot land on different lines; every fix preserving that
intent makes the status chips a third wrap child, which `WrapAlignment.spaceBetween` then centres in
the header **at every width**. It trades a visible change everywhere for an invisible one at a width
the app refuses to open, so the sweep starts at 900 and says why.

##### `#802`: the dock stops being a threshold and becomes a control (DR-108)

With the floor gone there is nothing left for a threshold to measure, so `kPreviewDockMinWindow` is
deleted. The complaint the ticket was filed for, that the dock *"gives way SILENTLY"*, is answered by
construction rather than by copy: nothing gives way on its own, so there is no disappearance to
explain. A labelled toggle on the grid toolbar hides the previews, **on the toolbar and not on the
dock**, because a control reachable only while the dock is drawn cannot bring it back. A dangling
`VerticalDivider` goes with it: it was drawn for the whole ports section and the dock separately
inside it, so every window under the old threshold got a rule down the right edge with nothing beyond.

##### `#801`: one argument that removes 47 of 48 ports (DR-109)

Priced as one line, and it is not. `symbolHitRegions` emits one region per entry in
`RenderedSymbol.allPorts`, and a collapsed bank contributes **one** entry, so collapsing a 48-port
switch takes 47 ports off the sheet: no pin, no hit region, no selection, no wire. **Nothing in
`rackpal_ui` or `rackpal_export` read `isCollapsed` or `collapsedCount`**, so there was no way back
and the PDF backend was equally unaware. **Sixty-five schematic tests failed and they were not stale
fixtures**; they were the product telling the truth.

CR-103 always owned the answer: any bank *"may be collapsed by the user at any time"*, which means
nothing unless it can be un-collapsed. So the chapter ships both halves. `expandedBanks` threads from
`buildSchematicScene` through the symbol tier to `layOutSymbolEdges`, keyed by device then bank, as an
**exception set** so auto-collapse stays the default and the user's choice is the deviation. A click
on a vector pin expands it and `B` collapses it again; the key exists because every modifier on that
canvas is spoken for.

**Two mistakes worth recording.** The gesture was hooked at the RELEASE first and never fired: a
release only reaches `_releaseWireAt` when `_armWireFrom` claimed the press, and a pin the wire rules
refuse never arms, so the press is the one path both cases share. Then `B` did nothing, because the
early return came before the caret was set and the key had nothing to act on.

**The default moved rather than the two call sites, and the seam test is why.**
`symbol_sizing_seam_test.dart` reproduces every symbol in the 300-link fixture through
`sizeSymbolForBody` **without** the flag and compares it to the scene. It is the guard against the
preview and the sheet drifting apart (`#229`, CR-086), so the value it exercises has to be the value
the sheet uses. It failed on the first attempt, which is how this was found.

**The op baseline: 4,155 to 2,371 on the symbol layer, 1,784 ops and 42.9%.** `_kM2cOps` is kept
rather than overwritten, because it is M2-C's record and editing it in place would leave the file
claiming M2-C measured a number that did not exist until today. **Measured twice and equal**: the
committed fixture reports 3,319 total against 948 label ops and the nets-and-registries document
reports 3,556 against 1,185, both leaving 2,371, which is the check that the symbol layer moved and
the label layer did not.

**Four fixtures changed and none was regenerated.** `schematic_test_document.dart` and
`wire_trace_layering_test.dart` set `collapseInSymbol = false`, CR-103's own per-bank escape said in
the model: those tests are about the wire gesture, pin selection, multi-draw and tracing, they predate
the feature, and rewriting them to work through vector pins would change what they cover.
`net_label_comb_test.dart` failed for a better reason, its N03 fixture being exactly what collapse
eats, so its comb tests would have gone on passing over an edge with two pins on it, **vacuous rather
than wrong**, and group 0's coverage assertion is what noticed. `paint_budget_test.dart` goes the
other way and expands everything: its text runs had fallen 2,374 to 1,066, and a budget measured
against the collapsed sheet quietly halves what it watches.

**Floors across the four commits:** core 3662 to 3672, ui 1389 to 1403. Keymap census 24 to 25 in the
schematic scope, 66 to 67 overall.

#### 5.3.30 M4-Q2 and M4-Q3, the drills that closed the milestone · CLAUSE 2 CONFIRMED · **46 seconds** · `v0.4.95`

> **The rest of the clause.** *…and a template saved with exactly three fields plus ports places into
> a rack and appears correctly in the equipment list with `—` in every unknown column and an accurate
> unknown count in the rollup.*

**Both performed by the user on 2026-09-01, and both clean.** That is worth saying plainly rather
than passing over: the two drills before these were each refuted on their first run, so a clean run
is a result and not an absence of one.

##### `#250`, the archetype path: 46 seconds

**46 SECONDS against a 180-second criterion, and against the DSL path's 93** (§5.3.7, 2026-08-15).
The chapter existed to answer one question in terms: *"if this path is not dramatically shorter in
practice, the generators have not earned their place"*. **51% of the DSL path's time**, on a route
that does not require the operator to have specified the grammar, so they earned it.

**The comparison is not like for like, and that is the point of running both.** §5.3.7 records the
operator's conditions in capitals: the 93-second run was made by somebody typing 140+ wpm who had
chosen that DSL's autocomplete key and ruled on its bank naming. The archetype path asks for four
tick boxes and two type tokens, and its counts pre-fill at 16 because the criterion's device is a
16×16. **The floor under it is much lower**, which is what a seven-step path is for.

##### `#251`, the second clause: every unknown said so

A template saved with three fields plus ports placed into a rack and appeared in the equipment list
with **a dash in every unknown column, each explicitly stated as unknown** rather than left blank or
defaulted to zero. That is **G4 and CR-114 holding end to end on a real document**: null is unknown
and never estimated, `0` means measured zero, and every rollup reports its unknown count rather than
fabricating a total. The invariant has had unit coverage since M0; this is the first time a person
read it off a printed sheet.

##### What the drills cost, over three runs

| Run | Result | What it found |
|---|---|---|
| M1 clause 3 | refuted first time | a palette filter that could not be edited, a caret drawn below the canvas |
| `#249`, DSL path | **93 s** | `Ctrl+Enter` promised by docs/06 §9.1 step 5 and never built |
| `#250`, archetype path | **46 s** | nothing |
| `#251`, clause 2 | demonstrated | nothing |

**Two of four runs found a defect no gate could see**, and the third finding of this session arrived
the same way: `#808`, the rack inspector's port list painted outside its own scroll viewport, was
reported by the user *while running these drills* and had been passing fifteen green gates because
nothing mounted `InspectorPanel` at all. **That is the whole argument for M4-Q being a human act
rather than a job**, and it is now three milestones' worth of evidence rather than one.

##### The corpus was wrong about how to start, in both paths

Both paths open on `Ctrl+Shift+N`, and **there is no such binding**. `Ctrl+N` is `New document`;
the builder opens from the Device Manager tab's `New device template…` button. This is M4-O's
finding at §5.3.25, that the `Project ▸ New device template…` menu item DR-104 assumed exists does
not, and it never reached docs/06 §9. **It also falsifies the DSL path's "zero mouse clicks"**,
which is a claim about the whole route and not about steps 6 to 13. docs/06 is priority-3 and owes
the correction; the ruling and the code win in the meantime.

### 5.4 M5, Validation · `M` · **CLOSED 2026-09-07**, 3 of 3 discharged, weakest mark `CONFIRMED` · ~~hard-blocked on M2~~ (block lifted at M2-F, §5.1)

> **Exit criterion, verbatim.** Every one of the **28** rules has a known-bad fixture producing
> exactly that finding and a known-good near-miss producing none — **no rule ships without its pair**
> (AC-051). A domain-expert review of the 28 rules and of the catalog data is signed off. No rule, at
> any severity, prevents a PDF from being written to disk.

**THE NUMBER IN THAT QUOTE IS 28 AND THE CATALOGUE NOW HOLDS 29** (DR-132 §11.131 restored
`ELE-005`). **This is a derived edit owed by that ruling, not a second amendment**, and the reason is
which half of the sentence binds: the clause is *"no rule ships without its pair"*, and
`drc_corpus_test.dart` asserts it over `kRuleCatalogue` rather than over a literal, so it moved to
29/29 by itself and the gate stayed green. **The quote is left verbatim because §8.1 makes the
criterion the unit of truth and a criterion edited in place is a criterion nobody can audit**; the
correction sits beside it instead.

**THE SIGN-OFF CLAUSE IS A DIFFERENT MATTER AND THE 28 THERE IS CORRECT.** The review was signed at
03:08 on 2026-09-06 (`605c05d`) and `ELE-005` shipped at 15:22 the same day (`a74e7f8`), so **the
systematic read covered 28 rules and not this one**. It is not unreviewed: DR-132 records the same
reviewer's explicit judgement on it, *"I feel like having a warning for that is important to prevent
blowing speakers out"*, which is domain-expert input on that rule specifically. **What it has not had
is the systematic pass**, and `#845` is where that lands.

| Clause | Mark | Why |
|---|---|---|
| 28 rules × fixture pair | **DEMONSTRATED: 29/29** | `dart test test/validation/drc_corpus_test.dart` from `packages/rackpal_core`, and `run_local.ps1` runs it as a step of its own named `AC-051 pair coverage`. **58 fixtures: 29 known-bad and 29 near-misses, one pair per rule, no rule with two and none with none.** It read 28/28 and 56 until DR-132 restored `ELE-005`; the mark moved without the gate changing, because its subject is `kRuleCatalogue` rather than any evaluator's enum, which is what makes it enforce CR-021 rather than restate it (§5.4.7). Three assertions, and the third is the anti-vacuity one: a corpus that walked nothing would report no gaps and pass |
| Domain-expert sign-off on the 28 rules and the catalog data | **CONFIRMED 2026-09-06** | Signed by Riley, reviewing integrator. **Two scopes, and they do not carry the same weight**: the 28 rules SIGNED outright, the catalog data SIGNED PROVISIONAL on the reviewer's own hedge, *"there may be signal families we are missing, but I haven't found any yet"*. §5.4.11 has the record. **The review returned twelve findings and produced four rulings**, and found six fields the model has and no producer writes; `#845` is the second pass, against a product a team has used rather than against a document |
| No rule prevents a PDF being written | **DEMONSTRATED** | `packages/rackpal_export/test/findings_never_block_export_test.dart`, 316 lines. The `VACUOUS` mark expired the moment rules existed, and §0 predicted exactly that: *"true today, and true for a reason that will stop being true."* It is not replaced by the assertion `#310` asked for, which would have been vacuous a second way, but by the type system: **`ExportError` is sealed with three arms and none of them is about a rule** (§5.4.8, DR-119) |

**WHAT THIS MEANS FOR §8.9, STATED HERE SO NOBODY HAS TO INFER IT.** M5's successor is **the Plan
view**, not M6, on DR-029 §11.28.4 and roadmap §4: M6's criterion is that all four starters export a
*complete* set, and a plan sheet arriving afterwards would make that criterion run twice (§5.9).

**ALL THREE CLAUSES ARE NOW DISCHARGED, so §8.9's condition on opening a successor is met.** This
paragraph read *"clause 2 above is `UNPERFORMED`, so it is neither discharged nor parked"* and that
was true until 2026-09-06.

**M5 IS CLOSED, 2026-09-07, DR-135 §11.134.** This paragraph read *"what is not yet true is that M5
is closed"* until then, and the reason it was true is worth keeping: the exit criterion is the unit
of truth (§8.1) and its clauses were discharged, but DR-127 §11.126 had amended M5's scope with five
items on the day of the review, four of them unbuilt (`#838`, `#839`, `#840`, `#841`). **A clause
discharged is not a backlog emptied**, and DR-127 §11.126.4 records the other half: that amendment
was taken on the ground that M5's buildable work was finished, which had stopped being true by the
time it was written.

**THE RE-MEASUREMENT THIS PARAGRAPH DEMANDED HAS BEEN TAKEN, AND THAT IS WHAT CLOSES M5 RATHER THAN
THE CLAUSE TABLE ABOVE.** It asked that *"M5's remaining cost be re-measured before its successor
opens rather than after"*. Measured on 2026-09-07 against the board: **all twenty Stories under epic
23 are `Done`**, the four DR-127 items among them (§5.4.12 to §5.4.15), and **61 Chapters beneath
them are `Done` with none open or re-parented**. `#845`, the second sign-off pass, is **not
outstanding M5 work**: it was re-parented to M9 (epic 27) because it can only be performed against a
product a team has used, which §5.4.11.3 argued before anybody needed the answer. **The remaining
cost is zero**, which is a measurement and not a shrug.

#### 5.4.1 M5-0a, the catalogue corrected before the engine exists · CLOSED · `bd71eef`, `91ac48f`, `31eac36`, `6f2ad64`, `4933588`, `aa25cba`

**Closed 2026-08-19** (`#740`, DR-079 §11.78), six commits, fourteen gates green on each. 21 core
cases. **The user reviewed the corpus against NEC and US practice and returned four findings**, three
of which the text confirmed.

**THE ONE THAT MATTERED WAS A FALSE PASS.** `CODE-002` read *"error when the pathway is a plenum
space and the jacket is not `cmp`/`lszh`"*. **LSZH is a jacket compound characteristic, not a UL
listing**: it is an IEC concern about smoke density and halogen acid gas and says nothing about the
flame spread testing a plenum listing rests on. So the product would have told somebody their
unlisted cable was **fine** in a plenum. **A false pass is worse than a false failure**, because the
false failure gets argued with and the false pass gets built.

**READING THE MODEL RATHER THAN THE RULE FOUND THREE MORE.** `JacketRating` mixed four axes (article,
listing, material, application); `Link` carried **both** a `JacketRating?` **and** a bare
undocumented `bool plenum`, so it could say `cmp` and `plenum: false` at once; and the vocabulary had
no `CL2P`/`CL3P`, no `FPL` family, no fibre `OFN`/`OFC` classes and no `CATV` family.

**THE TIMING IS THE ARGUMENT FOR NOT WAITING FOR M5.** No file on disk carried `lszh` (the starters
use `cmr` and `cl2`), the codec resolves by enum **name**, `jacketOptions` is empty on all 38 seeded
media types, and the only reader outside core was one label table. **Today it was a rename; the first
customer file carrying a value makes it a migration.**

| Finding | Landed as |
|---|---|
| LSZH treated as satisfying NEC plenum | `JacketListing`, 28 values across five articles; LSZH and direct burial become tri-state fields; `Link.plenum` deleted |
| Rules over-simplified | `CODE-001` and `CODE-002` become **warnings** that cite the article and name the exception the product cannot see |
| Power arithmetic reads as compliance | The 80% figure is a planning estimate and says so in five places. **No arithmetic changed** |
| TIA citations stale | Retrieved-on dates (DR-051's mechanism), and **`TIA-607` is cited nowhere in this corpus**, which is recorded rather than worked around |

**THE SUBSTITUTION TABLE ANSWERS THREE WAYS AND THAT IS THE DESIGN.** `substitutesFor` returns yes,
no, or **null when the two listings are from different articles** (G4): a fibre listing does not
satisfy a communications requirement. A caller reading that null as `false` reintroduces the false
failure and reading it as `true` reintroduces the false pass the whole ruling was raised over. Twelve
of the 21 cases are negative, because **a table recording only permissions cannot fail**.

**WHAT M5 STILL OWES IS UNCHANGED.** No rule engine exists, so §11.78.3 and §11.78.4 are catalogue
rows and prose that become behaviour when M5 builds them. The catalogue stays at **28**. Every clause
below still stands.

**FOURTH TIME THE TRADE HAS OVERRULED THE CORPUS** (`trade knowledge beats my workflow reasoning`),
and the first time the corpus was wrong **in the user's favour**, which is the direction that does
not announce itself.

Two persisted shells survive from M0 (`packages/rackpal_core/lib/src/model/acked_finding.dart` and
`rule_override.dart`) both codec-round-tripped and **never produced by anything**. The rack
editor's Validation drawer and Rack Vitals are both listed *not started* in
`docs/m1-implementation-log.md` §2 §1, `:47` (*"Rack Vitals stays not-started (§5, needs the
validation engine)"*) and `:56` (*"Validation drawer … not started"*), for this reason.

#### 5.4.2 The M5 decomposition was audited before the jump, and it was a rule short

**Censused 2026-08-25, before any M5 work.** `#23` holds **14 issues and 51 tasks**, of which
`#72` (decompose) and `#740` (M5-0a) are closed. The nine build issues `M5-A` through `M5-I` were
decomposed at `#72` and have not been read since. Two findings, and the first is a hole.

**`LEN-002` HAD NO TASK.** Canon's catalogue is **28 rules = 8 tier-1 + 6 tier-2 + 14 tier-3**
(docs/02 §5). The board enumerated **27**: `M5-C` 8, `M5-D` 6 plus a chips task, `M5-E` **13**. The
missing one is the fourteenth tier-3 rule, the generic `LEN-002` that DR-020 added (canon §11.19,
§12.13) and that reads its maximum off `MediaTypeDef.maxRunLengthPassive`. Filed as `#763`.

**AND NINE BOARD ITEMS STILL SAID 27.** `counts written out in prose are a liability` with the board
as the document: DR-020's sweep corrected **31 sites across 10 files** in `docs/` and **never touched
Azure DevOps**, so every M5 item authored before that ruling kept the old number and nothing could
fail. The corpus and the board have disagreed for as long as DR-020 has existed.

**TWO OF THE NINE WOULD HAVE SHIPPED THE WRONG NUMBER AS A GATE**, which is why this was worth an
hour before the milestone rather than a correction during it:

| Item | What it would have built |
|---|---|
| `#256` `M5-A4` | *"the 27-rule count, asserted by a test"*: a **passing** test pinning the catalogue one short, which is then the thing every later reader trusts |
| `#300` / `#301` `M5-G2/G3` | 27 known-bad fixtures and 27 near-misses, leaving `LEN-002` shipping **without its pair** and breaking AC-051, which is this milestone's own exit criterion |

`#254`'s description needed more than the total changed: it read *"8 tier-1, 6 tier-2, 13 tier-3 =
27"*, so swapping only the sum would have left arithmetic that does not add up. All nine carry a note
saying what moved and why.

**THE DECOMPOSITION IS OTHERWISE SOUND AND NEEDS NO FURTHER SUBDIVISION.** Every rule is one task,
which is the right grain because AC-051 makes a rule and its fixture pair indivisible: a rule task
that closed without its two fixtures would break the exit criterion silently. The four non-rule
issues (`M5-A` registry, `M5-B` findings and acknowledgement, `M5-F` the issues list and `Why?`
viewer, `M5-G` the fixture corpus and its gate) are 4, 4, 4 and 4 tasks, which is the size M4's
closed issues actually ran at. **`M5-H` is a human act with an external dependency** and cannot be
subdivided usefully; `M5-I` is three assertions about one property.

**WHAT THE AUDIT DID NOT CHECK, stated so nobody reads it as more than it is.** It compared the rule
IDs and the counts. It did **not** re-read each task's description against the catalogue row it
implements, so a task whose body describes the rule wrongly would still be there. That is the
`re-read a task against canon` pass, and it belongs to whoever picks up each rule.

#### 5.4.3 M5 landing is the trigger on the last open canon question

**§10.11, *what the beta gate actually is*, is the only entry in canon §10 still owing an answer**
(canon §13), and it was **DEFERRED 2026-08-03 with a trigger rather than a date**: held *"until M5
(Validation) lands and the UI is largely frozen, on the ground that the bar is easier to state
against a product than against a plan."*

**So starting M5 starts the clock on it.** The answer is owed **before the M6 recruiting ask
(M6-J5)** and not before M9, because you cannot ask three people to commit real jobs without saying
what you will judge. Recorded here rather than left in §13 alone, because a trigger that fires on a
milestone belongs in that milestone's section: this is where somebody looks when they pick M5 up, and
§13 is where somebody looks when they are already thinking about open questions.

Nothing about M5's own scope depends on it. It is an M6 input that M5 unblocks.

#### 5.4.4 M5-A and M5-B, the whole mechanism and not one rule · CLOSED · `11028a8`, `bd158a1`, `d17d614`, `d6500b8`, `d6356db`

**Closed 2026-09-02** (`#252`, `#257`), five commits, fifteen gates green on each. The core floor in
`tools/ci/run_suite.ps1` moved 3672 to 3751 across them, re-measured at every commit.

**WHAT THIS IS NOT IS THE THING THE EXIT CRITERION COUNTS**, and §5.4's table says `0/28` after both
stories exactly as it did before them. The clause asks for 28 rules each with a known-bad and a
known-good fixture (AC-051). **Not one rule predicate was written here.** What was written is
everything a rule predicate lands on, which is why the count is unmoved and the row's *reasons* were
all false and had to be replaced.

| Story | What it left behind |
|---|---|
| **M5-A** | `RuleMeta` and the catalogue as **data**, parsed out of docs/02 §5 by a test that fails when the two disagree, so CR-021's *"a rule not listed there does not exist"* is a gate and not a slogan. The connector mating matrix moves onto `ConnectorTypeDef.matesWith` because `CON-001` and `SIG-002` both read it and *"duplicating the data into predicates is how the two drift apart"*. An empty list is **unknown and skips** (G4), which is what let 40 of 49 be seeded without the other nine reading as failures |
| **M5-B** | `Finding`, computed and never stored, with a fingerprint built from stable ids and nothing else; the acknowledgement at both of CR-019's scopes with RJ-006's reason enforced at exactly one; `ruleOverrides` with a writer and the catalogue/override/acknowledgement order. `ackedFindings` and `ruleOverrides` were both **codec entries with no writer**, so CR-117 had never been carried across either map; both now have `command_roundtrip_test` arms |

**THE MARK FOR THIS PAIR IS `DEMONSTRATED` AND IT DISCHARGES NOTHING**, which is the distinction §0
exists for. Every claim above is a named test that a reader can run. None of them is an exit clause:
M5's three clauses are the fixture pairs, the sign-off and the PDF, and this pair of stories is
underneath all three rather than any of them. **A milestone can be half built and still `0/28`.**

**M5-B4 (`#261`) is parked on M6-C by DR-111** (canon §11.110): it asks the acknowledgement to reach
`T0.02`, `SheetRole` still carries three values, and DR-027 already rules that M6 owns every rendered
sheet. §11.110.6 records that the first disposition was reasoned from `#322`'s description without
reading its children, and that `#324` **is** `#261`.

**M5-C AND M5-D LAND, AND THE TABLE ABOVE GAINS TWO ROWS.** `M5-C` closed at PR 27 and had no row
here, which is the omission this section exists to prevent; both are recorded now.

| Story | What it left behind |
|---|---|
| **M5-C** | The eight tier-1 rules as `evaluatePlacement`, with `PLC-001..003` ratified from CR-017's three placement-coherence conditions. Two of the three had **no writer to refuse**: `#269` built the Width position control so `PLC-002` has a gesture, and `#270` built 0U channels and their occupants so `PLC-003` has a chain. A census-as-a-test over `lib/` sources went red twice, each time naming a new writer, and is the reason those two exist rather than being noticed later |
| **M5-D** | `evaluateSpringBack` and the six tier-2 predicates, docs/05 §7.3's amber ring, and the reason chip with `[ Connect anyway ]`. Three rulings: DR-113 (`SIG-001` fires on the joint, not the path), DR-113 §11.112.5 (a passthrough is a physical joint and not a signal endpoint) and DR-114 (a verdict is not a cursor; `[ Why? ]` waits for M5-F3; a spring-back leaves the gesture armed). **Nothing files a tier-3 finding on override**, which is M5-B1 paying off rather than a gap: `Finding` is computed, so the finding appears on the next pass over a document that now holds the cable |

**THE AC-051 NEAR-MISS TABLE PAID FOR ITSELF ON THE DAY IT SHIPPED.** `SIG-001`'s passthrough case
cleared and then **`SIG-002` fired**, because a patch panel's RJ45 declares `net.ethernet` and does
not list `video.hdbaset` in `acceptedFamilies`. So patching HDBaseT through a panel would still have
sprung back, one rule along, for the same wrong reason. That is the known-good half of AC-051 doing
exactly what `#298` says it is for, and it is why the pair is indivisible from the rule.

**AND IT FOUND SOMETHING OLDER: EIGHT M2 TESTS WERE ASSERTING THAT THE PRODUCT MAKES CABLES NO
INSTALLER WOULD MAKE.** The connect suites drew `freePin('MTX-1')` to `freePin('AMP-1')` and asserted
a commit. Measured: `MTX-1` is the seed catalog's V03, sixteen HDMI **inputs** and then sixteen
outputs with the first four inputs wired, so both ends were **sinks**. Two inputs, nothing driving
the cable, which is `DIR-001`. Arming from an output does not rescue it either, because `AMP-1`'s
first free sink is `src.2.l`, an RCA analog jack.

**The rules are right and the fixture choices were wrong**, and the shape of the fix is the finding.
`clearConnectPair` **searches** for a pair both tiers accept rather than naming one, because both
pairs picked by hand looked obviously fine and neither was, twice in one afternoon. A search cannot
be wrong that way, and when a seventh rule lands it re-answers instead of going stale. The split
suite cannot be fixed that way at all: this fixture holds no free analog audio **source** for the R
leg to land on, so those gestures press `[ Connect anyway ]`, which earns the override end-to-end
coverage the suite did not have.

**`#278` DOES NOT CLOSE, AND THE REASON IS A MEASURED CATALOG HOLE.** Its own description says *"a
remedy chip that only explains has not remedied: `SIG-001`'s inserts a device"*, and there is no
device. Every `video.hdbaset` port in the seed catalog is a **source** (`HDBT OUT` on V03, V04 and
V05) plus exactly one sink, F02 the flat panel's `HDBT IN`. V06 is the **transmitter**, V07 is an
AVoIP encoder, and V06's own description says the receiver half *"is a Device Builder fork of this
shape (P4, the role parameter is used for extender halves only)"* while `seed_catalog.dart` puts
variant-picking *"out of scope for this stage (M4)"*.

Inserting V06 where a receiver belongs would put a transmitter in the signal path and call it a fix,
which is the fabrication G4 forbids for a value. **Ruled by the user 2026-09-03: author a seeded RX
archetype**, filed as `#812`, with AC-052 binding: uncited safety-adjacent fields do not ship, so its
PoH class and power draw need real sources. `#811` is the sibling hole, and it is a question rather
than a task: **landing a run's loose end consults neither tier**, because `_armLandingFrom` builds
its candidates from occupancy alone by a decision that predates both, so an HDBaseT run dragged onto
a switch port is the flagship hazard arriving through a gesture that never asks.

**THE MARK FOR M5-C AND M5-D IS `DEMONSTRATED` AND IT DISCHARGES NOTHING**, on §0's terms and for the
reason the M5-A/B pair records: M5's three clauses are the fixture pairs, the sign-off and the PDF,
and fourteen of the twenty-eight rules now exist underneath all three rather than being any of them.
**A milestone can be half built and still `0/28`.**

**`#278` AND `#812` CLOSE, AND M5-D IS COMPLETE ON ITS OWN CRITERION.** The chip has its remedy, so
the sentence `#278` was filed under is discharged rather than ticked: *"a remedy chip that only
explains has not remedied."*

**THE REMEDY HAD NOTHING TO INSERT, AND THE FIX WAS NOT THE ONE FILED.** `#812` was written as
*"author a seeded RX archetype"*, priced before anybody read docs/catalog/seed-devices.md §540. That
section's own rejected alternative is *"separate `TX` and `RX` templates"*, and P4's is *"four
separate templates, which spends four of thirty rack-side slots on two products."* **The receiver
was never missing.** It is specified port for port at §540, down to `notInRack`, 0 W and `[poh:pd]`;
what was missing was P4's `role` parameter, which had no implementation because the PICKER it feeds
is M4-deferred and nothing else had needed it.

So `catalog_roles.dart` implements the parameter and `buildSeedCatalog()` still returns 48 bodies,
asserted by a test that fails if a variant ever enters that map. Shipping V08 would have reversed a
considered ruling by accident and left P4's own *"used exactly twice"* false.

**NO NEW BYTE SURFACE, WHICH IS WHY THE ID CARRIES THE ROLE.** A placed device snapshots its whole
`TemplateBody` (AC-041), and `templateKey` is `"$templateId@$version"`, so two halves under one id
collide on that key. The derived half takes `V06:receiver` and the document needs no `role` field:
the snapshot it already stores IS the resolved half. CR-117 is untouched.

**PoH CAN STATE A ROLE AND CANNOT STATE A STANDARD**, and the absence is the finding rather than an
omission. `PoeStandard` is `{af, at, btType3, btType4}`, IEEE 802.3 and nothing else, while docs/01
:470 says PoH *"is based on 802.3at but modified, and is **not** interoperable with a standard PoE
PSE"*. Naming one of those four to avoid an empty field is what G4 and AC-052 forbid. The same look
found `#813`: V06's transmitter is `[poh:pse]` in §540 and carries no `PoeSpec` in code, so the
annotation was never transcribed. Filed rather than fixed in passing, because a PSE spec on a shipped
body is a data change with a power-rollup consequence.

**AND THE REMEDY'S SECOND LINK DOES NOT EXIST (DR-115).** docs/05 §5 asked for both links in one undo
step. `SIG-001`'s target is an Ethernet jack by construction (DR-113), so the receiver's `HDMI OUT`
into it fails `SIG-002` and `CON-001` together: **the remedy would refuse its own second cable, on
the only case the rule has.** Canon §280 says only *"inserts a device, correctly"*, so the ruling
narrows the derived sentence rather than the other way round, and the HDMI end is left OPEN, which
AC-018, `unlandedHomeRunIds` and `LNK-020` already give this product a vocabulary for.

**THE SUITE CAUGHT THE COMMENT CLAIMING THE IMPLEMENTATION WAS SAFE.**
`insertHdbasetReceiver`'s doc read *"nothing is written on a refusal: every check that can fail runs
before the first `tx.add`"*, and that was false as written: the tier-1 check ran AFTER the snapshot
and the device had applied, so a full source pin minted a receiver and then refused the cable,
leaving an orphan wired to nothing. It surfaced because one test asked for a second insert from the
same pin, where `maxConnections: 1` makes `TOP-003` fire. The fix moves the occupancy check in front,
with the argument that occupancy is the ONLY tier-1 rule reachable against a device one frame old
written out rather than assumed.

**M5-D's TALLY.** Six rules with their AC-051 pairs, the amber ring, the chip, the spring-back, the
override and the inserting remedy: **`#272`-`#278` and `#812` all `DEMONSTRATED`**, with two adjacent
findings still open under the story and named rather than absorbed. `#811` asks whether binding a run
end consults the rule stack at all, which wants a ruling before code; `#813` is V06's missing PSE
spec. Neither is part of what `#271` was filed to deliver, and leaving them under it is the honest
place for them until somebody schedules them.

**THE MARK IS STILL `DEMONSTRATED` AND STILL DISCHARGES NOTHING.** Fourteen of the twenty-eight rules
exist and two tiers of surface exist, and M5's three clauses remain the fixture pairs, the sign-off
and the PDF. **A milestone can be two-thirds built and still `0/28`.**

**M5-E LANDS WHOLE: FOURTEEN TIER-3 RULES AND THE EVALUATOR THEY RUN ON.** With M5-C's eight and
M5-D's six, **all twenty-eight catalogue rules now have predicates**, which is the first time the
number in docs/02 §5 has described the code rather than the plan.

| Story | What it left behind |
|---|---|
| **M5-E** | `evaluateDocument`, and `RCK-001/002/003/012/013`, `PWR-001/003`, `NET-001`, `LEN-001/002`, `ELE-003`, `CODE-001/002`, `LNK-020`. The catalogue coverage gate now runs BOTH ways, which it could not while the tier was part-built: **a row with no predicate is a rule the product claims to check and does not**, and nothing else in the tree would have noticed |

**SEVERITY IS RESOLVED IN ONE PLACE, IN THREE STEPS, IN THAT ORDER.** `projectSeverity` applies
`ruleOverrides`; `Severity.off` drops the finding, which is what off MEANS and the only place it can
be honoured without every predicate re-implementing it; then an acknowledgement demotes (CR-019).
Demoting before overriding would let an override resurrect something somebody turned off. **A
predicate returns facts and the evaluator decides what they are worth**, which is why a predicate
that tried to choose its own severity was overwritten rather than obeyed (below).

**THE OUTPUT ORDER IS PART OF THE CONTRACT, AND IT IS NOT BY SEVERITY.** Severity is a per-project
setting, so sorting by it would churn the whole list the moment somebody demotes one rule and a
reader diffing two runs would see movement that means nothing. Rule id, then fingerprint, which is
derived from the target ids and is therefore total: `List.sort` is not stable.

**THE FIRST RULE PAIR EXPOSED A FLAW IN THE FINGERPRINT, NOT A TYPO.** `RCK-001`'s first draft
looped faces on the OUTSIDE and emitted a finding inside. Measured, every seeded rack-side archetype
is `OccupancySide.both` except the patch panel, so two devices in one U produced TWO findings with
IDENTICAL targets and therefore identical fingerprints. `Finding.targetFingerprint` is what an
`AckedFinding` matches on, so accepting the front collision would have silenced the rear one:
**CR-019's instance scope failing in silence.** The pair is the unit now, the faces are a detail of
the sentence, and `RCK-002` takes the same shape for the same reason.

**AND A RULE WAS INVENTED AND CAUGHT.** `LEN-001`'s unknown case stamped `advisory` on a genuinely
good argument: an unmeasured run is a checklist item, and reporting it as an error buries the runs
that are actually too long. **That argument is not in the catalogue.** docs/02 §5.3 gives one
severity and one row and says only that the unknown case emits its sentence *"rather than passing
silently"*, so a predicate choosing a second severity is inventing a rule (CR-021). The evaluator
overwrote it, which is the single-place design working. The MESSAGE distinguishes the two cases and
the severity does not.

**`PWR-001` IS THE FIRST CONSUMER `diversityFactorsByCategory` HAS EVER HAD.** The field has sat on
`ProjectSettings` since M0 with no reader, exactly as `genderApplies` and `pinoutVariant` did
(§11.109). AC-020 gives its worked case and docs/02 §5.3 gives the sum as *"typical x diversity
factor, in VA"*. **An absent entry applies no de-rating**, which is not the fabrication G4 forbids: a
diversity factor is a reduction somebody CLAIMS, and its absence means nobody has claimed one.
Refusing to sum instead would silence the rule on every project, since the map defaults to empty on
purpose so an old file cannot decode carrying a convention its author never wrote.

**THE TWO CODE RULES ASK RATHER THAN ASSERT, AND NEITHER SENTENCE SAYS "VIOLATES".** DR-079 demoted
both and gave the same shape of reason twice: this product cannot see the thing the article turns on.
`CODE-001` cites NEC 725.136 and says the article permits arrangements this product does not model;
`CODE-002` cites 800.154 and names 300.22(C)'s metal-raceway exception. **A DRC that overstated its
reach on a code question would be worse than one that stayed silent, because somebody would believe
it.**

**AND A TEST ASSERTION WAS TOO CLEVER TO WORK**, which is worth recording because it will be tempting
again: `isNot(contains('violat'))` failed against a sentence ending *"so this is a check rather than
a violation"*. A substring cannot express "does not ASSERT a violation".

**WHAT M5-E DOES NOT DO, STATED SO NOBODY READS THE CLOSURE AS MORE THAN IT IS.** Nothing SURFACES
any of these findings: there is no issues list, no badge on a sheet, no count anywhere a user can
see. That is `M5-F` (`#293`), and the fixture corpus AC-051's exit criterion actually rests on is
`M5-G` (`#298`). **A user of this build cannot tell that fourteen rules exist.**

**THE MARK IS `DEMONSTRATED` AND IT DISCHARGES NOTHING**, on §0's terms and for the reason the
M5-A/B and M5-C/D pairs record. M5's three clauses are the fixture pairs, the sign-off and the PDF.
Twenty-eight rules and two tiers of surface exist underneath all three rather than being any of them.
**A milestone can be nearly all built and still `0/28`.**

#### 5.4.5 ARCH-A, a question that had two answers, and the third recorded number to stop tracking · CLOSED · `962dfa7`, `63e5850`, `33f4708`, `789cfec`

**It began as a question, not a task.** *"What state management are we using and why?"* The corpus
answered **Riverpod** in four places. The repository answered **nothing** in every place.

**THE MEASUREMENT.** At `v0.4.63`, `riverpod` occurs **zero** times in any Dart file, any
`pubspec.yaml` and the lockfile, and `ProviderScope` likewise. Seven tracked files mention the
package and **all seven are prose**; three are under `docs/research/`, which is working papers, so
the sweep touched four. ADR-011 was accepted at M0 and five milestones passed.

| | ADR-011 said | The tree has |
|---|---|---|
| container | `ProviderScope`, one per document | nothing; `AppServices` passed by constructor |
| DI | `ProviderScope(overrides:)` | one constructor parameter |
| epochs | `ValueNotifier<int>` × 6 | `SimpleNotifier<int>` × 7, pure Dart under D1 |
| derived | `DerivedRegistry derived` | not built, **deliberately**, and the reason is in the source |
| ui state | four `*Provider` declarations | nine `ChangeNotifier`s owned by the screens' `State` |

**WHAT MAKES THIS WORTH A SECTION RATHER THAN A CORRECTION.** ADR-011 carried
`VERIFY: ... before the provider layer is written`. **That condition never came true, so the check
never fired.** Nothing was edited wrongly, no reviewer could have caught it in a diff, and every
sentence involved was true when written. A precondition attached to work that does not happen is not
a tripwire, and the same reasoning voids every other `VERIFY:` in the corpus that waits on future
work.

**THE SECOND FINDING WAS LARGER THAN THE FIRST.** §10.1 is titled *"The full table"*. Audited
against all five pubspecs it was wrong **in both directions**: **eight** packages named and installed
nowhere (`flutter_riverpod`, `printing`, `desktop_drop`, `logging`, `intl`, `flutter_localizations`,
`integration_test`, `benchmark_harness`), and **two** installed and named nowhere
(`screen_retriever ^0.2.0`, `fake_async ^1.3.3`).

**`screen_retriever` is the row that settles what kind of failure this is.** Its twenty-line pubspec
justification **cites "§10.1's `window_manager` row"** by name. The author had the table open, read a
row out of it, added a package on the strength of it, and did not add a row. Care was not the missing
ingredient. **Nothing could fail**, because a dependency table is prose no gate reads: the same
sentence `§5.4.2` earned about the board three days earlier.

**THE THIRD INSTANCE TURNED UP WHILE FIXING THE SECOND.** Raising the app suite's floor for the new
gate meant measuring it, and four of the five floors had stopped tracking:

| Suite | Floor | Actual | Slack |
|---|---|---|---|
| `rackpal_core` | 976 | 3263 | **+2287** |
| `rackpal_text` | 1 | 1 | exact |
| `rackpal_export` | 183 | 189 | +6 |
| `rackpal_ui` | 382 | 1162 | **+780** |
| `rackpal_app` | 664 | 838 | +174 |

`run_suite.ps1`'s own comment orders a re-measure *"in any commit that adds or removes tests"* and
records **131 tests of slack** as the defect that prompted the rule. It had reached **3,247**. Two
thousand two hundred and eighty-seven core tests could have stopped being discovered while the script
printed a cheerful `+2287` and exited 0. All five are now exact.

**Three recorded numbers, in one week, that quietly stopped tracking their subject: a rule count on
the board, a dependency table in `docs/03`, and four test floors in CI.** None was introduced by an
edit. Each was true when written. The common shape is a number **maintained by intention rather than
by a gate**, and the only durable answer found so far is to make something read it.

The remedy is `apps/rackpal/test/dependency_table_test.dart`, which runs in **three directions** and
was watched failing in all three plus the anti-vacuity case that would otherwise have made it inert.
Ruled at **DR-088** (canon §11.87, §12.27). **No version bump**: `#764` is parentless, so its tasks
are not under M5's epic, and docs/14 §14.0 counts Done tasks under the **current** milestone's epic.

#### 5.4.6 M5-F, the surface, and a viewer promised over a field nobody had built · CLOSED · `v0.5.50` · `cc37461`, `a3ab151`, `cbf1625`, `0772946`

**Closed 2026-09-04, four chapters, `#294`-`#297`.** §5.4.4 ended on the sentence that this story
exists to falsify: *"a user of this build cannot tell that fourteen rules exist."*

**THIS PARAGRAPH SAID "THEY CAN NOW" AND THAT WAS NOT TRUE, MEASURED 2026-09-06 (`#847`).**
`DrcPanel` appears in exactly two files in the tree: the one that defines it and the one that tests
it. **Nothing in `apps/rackpal` mounts it**, and outside that widget file nothing calls
`evaluateDocument` or `groupFindings` at all. So the list, the grouping, the severity filter, the
acknowledge flow and the `Why?` viewer are real, tested, and **unreachable by any gesture a person
can make**.

**AND IT IS TRUE AGAIN AS OF DR-133 (`#847`, §5.4.16), which is recorded HERE so a reader meets one
current answer rather than two corrections and a guess about which won.** The validation drawer is
mounted, so everything listed above is reachable, and it opens itself on the first error rather than
waiting to be found. **The sentence was wrong for two days and is now right for a different reason
than it was first written**: it was asserted from what M5-F built, and it holds because something
mounts it.

**The chapters below are not withdrawn and the Story stays closed**, which is §8.1 rather than
generosity: each built what it said, and M5's three clauses are the fixture pairs, the sign-off and
the export, none of which says a user can see a finding. **What was wrong is the sentence**, and a
closed chapter asserting a user-visible outcome nobody can reach is the most believable kind of wrong
record.

**FOUND THE WAY EVERY OTHER GAP THIS MILESTONE WAS FOUND**: by trying to use the thing. DR-129 went
looking for the panel's caller in order to wire `PWR-003`'s remedy button to it, and there was no
caller. **The widget's tests pass because they mount it themselves**, which is the producer-gap shape
one layer out: the thing exists, something reads it, and no path a person walks reaches it.

| Chapter | What it left behind |
|---|---|
| **M5-F1** | The findings list, grouped by severity, rule or locus and filterable by severity. `groupFindings` is in **core**, not in the panel, because the panel is one of three consumers and the other two are not widgets: sheet `T0.02` prints open findings and acknowledgements (CR-022) and docs/05 §8's device rollup chip counts them. **Three surfaces disagreeing about which findings belong together is one document with three answers** |
| **M5-F2** | Acknowledgement from the list, at both of CR-019's scopes, with the reason captured. The dialog **asks** `evaluateAcknowledgement` on every keystroke and renders its refusal verbatim rather than implementing *"a project mute needs a reason"* a second time |
| **M5-F3** | `RuleMeta.rationale` and the `[ Why? ]` viewer over it, which discharges DR-114's deferral |
| **M5-F4** | The per-rule severity control, `off` included, and the asymmetry that setting an override always needs a reason and withdrawing one never does |

**THE LOCUS TYPES WERE CENSUSED, NOT ASSUMED.** `Finding.primaryEntityId` is nullable and could name
any entity. Across all fourteen tier-3 predicates it is set from exactly four: `Link`, `Rack`,
`DeviceInstance`, `Circuit`. All four carry a designator, so `locusLabel` is short and total instead
of a twelve-arm switch over types no rule produces. **A fifth type is a test failure, not a blank
cell**: a later rule pointing at a `Port` returns null and trips the guard rather than drawing an
empty group header nobody can click.

**THE ACKNOWLEDGEMENT JOIN IS RE-RUN RATHER THAN CARRIED.** `evaluateDocument` applies a demotion and
then no longer holds the fact that there *was* one, which is precisely what the list needs: docs/05
§8 renders an acknowledged badge hollow with the reason in its tooltip. So the join goes back through
`acknowledgementFor` and nothing else, because the project-wide `*` mute is exactly the case a second
hand-written matcher gets wrong.

**M5-F1 IS THE FIRST CONSUMER `StatusMarker` HAS EVER HAD.** `status_marker.dart` records that
nothing drew a status marker and that DR-090 §11.89.6's gate was therefore vacuous and had to be made
structural. Severity now reaches the screen only through `StatusMarker`, so every row carries a shape
as well as a colour, and the gate has offenders to count.

**AND THE GATE THEN REFUSED THIS STORY'S OWN CODE, CORRECTLY.** M5-F2's refusal text took a console
severity's fill. A **form refusal about an empty text field is not a severity** and should not borrow
a finding's vocabulary; it takes the theme's error colour instead. The scan is textual and does not
skip comments, so the comment explaining the fix deliberately does not spell the offending expression
out. **Weakening the gate to admit a justified exception was the alternative and was not taken.**

**THE PREMISE OF M5-F3 WAS FALSE, AND THAT IS THE CHAPTER.** AC-058/D1 says
`CompatibilityRuleDef.rationale` *"gets the viewer `[ Why? ]` already promises"*, and the
completeness critique says rule rationale *"exists in the model with no viewer"*. Measured: it does
not exist. The type is from `docs/research/design-data-model.md`, a priority-3 document, and was
never built. `RuleMeta` carried `summary` and `governing` and nothing a person could read as an
answer. **So the chapter is not "wire a viewer to existing data", it is: author the data, then build
the viewer.** `rationale` is REQUIRED on the constructor, so the catalogue cannot carry a rule with
no explanation.

**ONE TEXT SERVES TWO CHAPTERS ON PURPOSE.** M5-H1 wants the same 28 rules *"in trade language, not
model language"* for review. Writing them twice would give the project two texts to keep in step and
let the reviewed one drift from the shipped one. **M5-H2's corrections therefore land on the words
the product actually shows.**

**THE TRADE-LANGUAGE RULE IS CHECKABLE RATHER THAN ASPIRATIONAL**, and its ban list is proved
non-vacuous by a second test. One test bans this repository's own vocabulary from every rationale:
`acceptedFamilies`, `maxConnections`, `heightU`, `hostDeviceId`, `startTwelfth`, `ruIndex`,
`MediaTypeDef` and twenty more. **A ban list naming words nobody writes would pass forever**, so the
second test requires every banned word to appear in some `summary`, the summaries being the same 28
rules in model language.

**`off` IS OFFERED PLAINLY BECAUSE IT IS A LEGITIMATE ANSWER.** `#297` rules it *"a legitimate answer
a professional is allowed to give"*, so it sits in the list with the others rather than behind a
confirmation implying the person is doing something wrong. **A tool that will not let an integrator
say "this rule does not apply to my jobs" is a tool they stop opening**, which is the position CR-019
took deliberately over a nag that cannot be silenced.

**AND THE DEFAULT DEMOTION IS THE FINDING'S OWN SEVERITY, NOT `off`.** CR-019 makes acknowledgement a
demotion, and the case the model exists for is the inspector's *"noted, justified, and still an
error"*. Defaulting to `off` would make the one-click path the one that hides evidence: a person
working down a list of twelve would silently empty it. Hiding is still offered, it is just not the
default. **`Withdraw` ships beside `Acknowledge` for the same reason**, since a surface that can only
acknowledge is a one-way door and CR-019's whole argument for demotion over deletion is that the
person stays in charge of their document.

**FIVE DEFECTS, AND NONE WAS A TYPO.** They are recorded because four of the five produce a symptom
that points somewhere other than the cause:

1. **THE TEST HARNESS DEADLOCKED.** An `async` helper returning the dialog's own future is flattened
   by Dart, so awaiting the helper did not resolve until the dialog closed. Every test hung. The
   result future is held in a variable now.
2. **A HANG WITH NO ASSERTION AND NO EXCEPTION**, two minutes, reported as *"did not complete"*. A
   radio was tapped and `enterText` called **without pumping**, so the reason field was still
   disabled, the text never arrived, `Apply` stayed disabled and the await on the result waited
   forever. **A missing pump between a state change and the input that depends on it produces a hang
   rather than a failure, and a hang names nothing.**
3. **A VERTICAL OVERFLOW at 800x600**, which is a real screen and not a test artifact: `AlertDialog`
   does not scroll its content.
4. **A HORIZONTAL OVERFLOW of 127 px**, because `DropdownButton` sizes itself to its widest item.
   Fixed with `Expanded` plus `isExpanded` and **not** by shortening the copy, which would have
   hidden the bug until the next long label.
5. **A `Spacer` in `AlertDialog.actions` throws.** That is an `OverflowBar`, not a `Row`.

**Two vacuous assertions were found and replaced**, both in this story's own tests.
`expect(statusForSeverity(s), isNotNull)` cannot fail against a non-nullable return; what is worth
pinning is that the three markers are **distinct**, which is the failure a reader would suffer. And
both empty-state tests would have passed with the two constants equal, so a test asserts they differ:
**an empty list under an active filter reads as a broken panel unless it says which empty it is.**

**Floors re-measured in the commits that added the tests**, per `run_suite.ps1`'s own instruction:
core 3909 to 3932, ui 1444 to 1483.

#### 5.4.7 M5-G, one corpus, and a gate whose subject is the catalogue · CLOSED · `v0.5.54` · `b890154`

**Closed 2026-09-04, four chapters, `#299`-`#302`, in one commit** because the four are one artifact.
This is the story M5's first exit clause actually rests on.

**THE TICKET READ AS GREENFIELD AND THE TREE DISAGREED.** `#298` asks for a fixture corpus as though
none existed. Measured, **three of the four evaluators already had both AC-051 halves**:
`connect_rules_test.dart` had `_refusals()` and `_nearMisses()` with a coverage assertion and cited
`#298` by name in its own comment; `spring_back_rules_test.dart` had the same pair;
`placement_rules_test.dart` had a known-bad and a near-miss per `PLC` rule as named tests, and its
header already said the corpus and its gate were M5-G's while *"the DISCIPLINE is not deferred with
them"*. Only tier 3 was genuinely short.

**MY OWN FIRST CENSUS OF THAT WAS WRONG AND IS RECORDED AS WRONG.** It reported placement as having
no near-miss half. The error was grepping for a **table** shape rather than for the cases, which were
there as named tests. **The corrected measurement is not a claim in a commit message, it is the gate
finding the real gaps itself**, which is the only form of this that survives the next reader.

**THE STRUCTURAL GAP MATTERED MORE THAN THE MISSING FIXTURES.** Each tier's coverage test drove off
**its own enum**: `ConnectRule.values`, `SpringBackRule.values`. Nothing had the catalogue as its
subject. So all three could pass green while a catalogue row had no pair at all, because no enum
mentions it and no test is looking for it. **CR-021 makes the catalogue what decides a rule exists,
and it is the union of four evaluators' rules.** `#302` asks that a REGISTERED rule without its pair
fail the build, so the gate's subject has to be `kRuleCatalogue`. That is why the tier-1 and tier-2
tables were **absorbed rather than federated**: the data moved into `test/validation/fixtures/`, the
assertions did not, and `connect_rules_test.dart` and `spring_back_rules_test.dart` still own
everything they asserted before and now read their rows from the corpus.

**FOUR EVALUATORS, NOT ONE, WHICH IS THE FORMAT'S WHOLE PROBLEM.** `#299` asks for *"a document plus
the expected finding set"*, which is literally true for tier 3 and false for the rest. Tier 1 refuses
a gesture through **two** evaluators, `evaluateConnect` (`TOP-001..005`) and `evaluatePlacement`
(`PLC-001..003`); tier 2 springs back through `evaluateSpringBack`; tier 3 describes a document.
**A format built around one evaluator could have expressed fourteen of the twenty-eight rules and
looked complete doing it.** So every tier normalises to one question, WHICH RULE IDS FIRED, and both
halves of AC-051 become one comparison. Messages come back too, so the connect corpus's `mustName`
contract survived the move.

**WHAT THE HARNESS CAUGHT IS THE POINT OF THE HARNESS.** `#300` requires a known-bad to fire
**exactly** its own rule, and enforcing that found four real problems in fixtures that looked right:

1. **Seed-catalog devices state a mass, an outlet draw and an unsupported-mass limit**, so placing
   one to test RU overlap also armed `PWR-003` and `RCK-013`. Fixed with minimal hand-built bodies
   where every unstated field is unknown and therefore silent (G4).
2. **`cat6` declares its own passive limit**, so a 120 m Ethernet run fires `LEN-002` as well as
   `LEN-001`. That fixture now uses a medium declaring none.
3. **`LEN-001` and `LEN-002` fire on an ABSENT length, by design**, because docs/02 §5.3 makes
   *"length unknown, cannot verify"* a finding rather than silence. Four fixtures about jackets and
   home runs were arming both length rules simply by not stating a length.
4. **The absorbed tier-1 and tier-2 fixtures all pass the "and nothing else" contract**, which they
   had never been checked against before.

**None of the four was a typo. Each is a fixture that would have passed review as evidence about a
rule it was not testing**, which is the same defect class §5.2 records under a different name.

**THE GATE IS A NAMED STEP EVEN THOUGH THE CORE SUITE RUNS THE FILE ANYWAY**, and the reason is a
schedule control rather than a coverage one. Roadmap M5's risk list names the pressure to add *"just
one more obvious rule"* without its pair as how this milestone overruns. **Buried among 3,900 passing
tests that failure is one red line; in the gate summary it reads as `AC-051 pair coverage FAILED`,
which is where somebody adding a rule will see it.** §4.1 had already drawn this dependency in the
other direction: M5-G4 is a convention until a service runs it, and CI existing since 2026-08-27 is
what made it a gate.

**MEASURED AT CLOSURE: 56 fixtures, 28 known-bad, 28 near-miss, across 28 rules**, one pair each.
The corpus is `packages/rackpal_core/test/validation/fixtures/`, 1,996 lines over seven files. Core's
floor moved 3932 to 3935.

**AND CLAUDE.md'S GATE COUNT WAS COLLATERAL.** It said *"fifteen gates"*; the pair gate makes
sixteen. **The number was removed rather than updated**, on that file's own rule about a second copy
of a moving number, which it had already broken twice in the same paragraph about test floors.

#### 5.4.8 M5-I, the clause that was `VACUOUS` and is now a type · CLOSED · `v0.5.57` · `c500cf5`

**Closed 2026-09-04, three chapters, `#308`-`#310`.** Canon gains §11.118 (DR-119).

**THE STAMP `#310` IS ABOUT DOES NOT EXIST.** It asks to prove the `ISSUED FOR CONSTRUCTION` stamp is
the only thing an error gates, *"via `ExportSpec.issuedForConstruction`"*. Measured: neither exists.
`ExportSpec` appears nowhere in shipped code, no stamp is drawn, and `ExportRequest` carries
`documentJson`, `fontBytes`, `fileName` and `issuedAt` and nothing else.

**THIS IS THE SECOND TIME IN TWO STORIES THAT A CLAUSE DESCRIBED A FIELD NOBODY BUILT**, after M5-F3
and `CompatibilityRuleDef.rationale` (§5.4.6). Neither sentence is wrong about the **design**; what
neither says is that the tree does not have it. **A corpus sentence in the present tense is a claim
about the design, not about the code**, and pricing a chapter off one without reading the tree is how
both were mis-scoped. DR-119 names the pattern, and §1's standing caveat on every decomposition is
the same warning written before either instance.

**A VACUOUS ASSERTION WAS THE TEMPTING MOVE AND WAS REFUSED.** Writing the test `#310` asks for and
letting it pass over a stamp that is not there would be green forever and mean nothing. That is the
exact failure this repository keeps finding in its own suite: `status_marker_source_test.dart`
records a gate that would have counted zero offenders and passed, and `run_suite.ps1`'s header
records green-over-nothing as the recurring shape.

**SO THE CLAUSE IS PROVED IN THE STRONGER FORM AVAILABLE TODAY: NOTHING IS GATED, AND THE TYPE SYSTEM
SAYS SO.** `ExportError` is sealed with three arms, `ExportDocumentUnreadable`, `ExportNoRacks` and
`ExportFontMissing`, and none is about a rule. **An exhaustive switch over those arms fails to
compile if a fourth appears**, so whoever adds *"export refused because the project has errors"* has
to come to this file and argue with CR-022 rather than ship past it. A source scan is the second cue:
`rackpal_export` never mentions `evaluateDocument`, `kDrcRules`, `AckedFinding` or
`blockExportOnErrors`. **The exporter cannot gate on a finding it never asks for**, which is a better
guarantee than the one `#310` requested.

**THE FIXTURE IS PINNED BY RULE NAME, NOT BY SEVERITY SET.** `#308` wants open findings at every
severity, and it has three: `RCK-001` error, `RCK-003` warning, `LNK-020` advisory. The test asserts
that **map**, because a fixture edit that lost one source and gained another would satisfy a
set-of-severities assertion and quietly stop testing what the file says it tests.

**AND "BYTES REACH DISK" IS TAKEN LITERALLY.** The test writes a real file and checks the length
matches, the header is `%PDF-`, and the sheet count is non-zero. Then it exports three more times,
once per severity with the other two overridden `off`: **a project whose only finding is an ERROR is
the case somebody would most expect to be refused.** Export's floor moved 189 to 195.

**WHAT M6 INHERITS.** The stamp's gating will be the first gating the export path has ever had, and
this file is where that tightening lands. **M5's clause is discharged either way**, because CR-022/G3
is about a rule blocking an export and a stamp is not a rule.

#### 5.4.9 M5-H1, the pack that is generated, and the two chapters that need a person · `68c87a7`

**Landed 2026-09-04, `#304`, and the census half of `#692`.** No version bump was taken at the time;
see §5.4.10, which is where that decision is corrected rather than left implicit.

**GENERATED, NOT WRITTEN, AND THAT IS THE CHAPTER'S ONE STRUCTURAL DECISION.** `#304`: *"a reviewer
who has to learn the words 'net', 'service' and 'conductor' first is a reviewer who signs off on the
vocabulary rather than the rules."* The words a reviewer marks up have to be the words the product
ships, so `tools/rule_review.py` reads the catalogue and emits `docs/20-rule-review.md`. **A
hand-copied pack drifts from the code the first time a rationale is corrected, and M5-H2 exists to
produce exactly those corrections**: re-run the tool afterwards and the pack is current again.

**It parses the Dart source rather than running `dart`**, because a `dart run` needs a file under
`packages/*/tool/` and anything left there is analyzed and counts against the ratchet. The parse was
checked field by field against a `dart run` dump of `kRuleCatalogue` and agreed on all 28 rules.

**GROUPED BY SUBJECT, NOT BY TIER.** A reviewer thinks in subjects: signal compatibility, cable
lengths, power, racks, code, drawing integrity. The tier is a **consequence**, so it is stated per
rule as what happens in plain words, refused outright or springs back with an override or listed
afterwards, rather than as a heading. **An unplaced rule is a hard error rather than a catch-all
group**, because the bottom of the pack is where a reviewer stops reading.

**WHAT IT DOES NOT ASK is whether there should be more checks.** The set is capped at 28 and adding
to it is its own decision (CR-021, AC-040), so a gap becomes a separate question rather than a change
to this list.

**AND A CLAIM HAD TO BE CORRECTED IN THE PACK'S OWN FIRST DRAFT.** It told the reviewer an error
*"holds back the `ISSUED FOR CONSTRUCTION` stamp"*. DR-119 had ruled the day before that the stamp
does not exist. **That is the mistake the ruling is about, made while writing the ruling's own
follow-up work**, and it is recorded here rather than quietly fixed: a present-tense sentence about a
design reads as a sentence about the tree even to somebody who has just finished proving it is not
one. The pack says what is true today, that nothing blocks a drawing or an export at any level.

**`#692`'s CENSUS CHANGED ITS OWN QUESTION.** The ticket names Lutron HomeWorks QS and Legrand
Vantage. Censused: **55 families in 8 groups, and `ctl.lutron_qs` already shipped.** Vantage did not.
The ticket predicted this and asked for the census before any pricing, which is why Part 2 of the
pack is a list to mark up rather than a proposal. The pack also states what a new family costs, seven
fields plus a dash and weight that PAL-1 gates against its group-mates, **so the reviewer's answer is
informed rather than free**.

**THE ANSWER TO THE FIRST NAME ARRIVED FROM THE USER BEFORE THE REVIEW DID**, and three rulings came
with it: DR-120 shipped `ctl.vantage` and `F19` the load-controlling keypad, and DR-121 gave P4 a
control-bus variant axis after the fixture proved a keypad had been carrying three bus ports for one
cable (canon §11.119, §11.120, §12.28, §12.29). **The pack was regenerated and is current**: 56
families, `ctl.vantage` listed, and re-running `tools/rule_review.py` against the tree today produces
no diff.

**WHAT WAS LEFT WAS NOT BUILDABLE, AND IS NOW DONE.** `#305` was the review pass and `#306` the
sign-off with name, date and scope, **rules and catalog data being separate scopes**. Both were
`UNPERFORMED` in §0's sense: somebody had to do the thing. Somebody did; see §5.4.11.

#### 5.4.11 M5-H2 and M5-H3, the sign-off and what it is signing · CLOSED · `v0.5.60` · `#305`, `#306`

**Signed off by Riley, reviewing integrator, 2026-09-06.** The clause asks for name, date and
**two scopes**, and the two do not carry the same weight:

| Scope | State | Why |
|---|---|---|
| **The 28 rules** | **SIGNED** | All 28 read, twelve findings returned, every one dispositioned. Four rulings came out of it |
| **The catalog data** | **SIGNED, PROVISIONAL** | 56 families reviewed and none found missing, in the reviewer's own words *"but I haven't found any yet"*. `#845` is the item that finishes it |

**THE HEDGE IS THE REVIEWER'S AND IS RECORDED AS THEY PUT IT**, rather than smoothed into an
acceptance: *"this isn't totally finalized until M8/M9. There may be signal families we are missing,
but I haven't found any yet."* Absence of a find after one reading is not evidence of absence, and
the honest form of that is a scope that says so.

**5.4.11.1 WHAT THE REVIEW ACTUALLY BOUGHT, MEASURED.** `#303`'s own description predicted the
value: *"a code-adjacent rule that is subtly wrong is worse than absent, because the tool's silence
reads as approval."* It found worse than that. **Six fields that the model has, the documents
describe, and no producer ever writes**, five of them inside this milestone:

| Field | Ruling | What it cost |
|---|---|---|
| `maxConnections` | DR-124 | `TOP-003` refused a dual-head flasher's second head at the gesture, with no escape |
| `RuleMeta`'s severity band | DR-125 | `RCK-003`'s `advisory` had never reached a user since M5-E |
| `acceptedFamilies` | DR-126 | `SIG-002` refused every cross-family pairing in the shipped catalogue |
| `InlineAdapter` | DR-128 | `CON-001` told people to declare an adapter the product could not create |
| `ShelfPlacement` | DR-128 | Nothing a person did put a device on a shelf |
| `Finding.remedy` | DR-128 | The panel button vanished between the predicate and the panel, twice |

**ALL SIX SURFACED THE SAME WAY: a rule firing on a connection that is correct.** That is now the
strongest single signal in this repository that a field has no producer, and it is a better detector
than reading, because it costs nothing to notice and arrives on its own. `#841` is the census nobody
has run.

**5.4.11.2 THE REVIEW ALSO CORRECTED THE RULINGS IT PRODUCED, TWICE.** DR-125 §11.124.3 framed
`DIR-003` as a rule keyed on the wrong field, over a census that was a row short; DR-126 found the
missing row and the predicate turned out to be correct all along. DR-128's first answer for
`PWR-003` was the 0U PDU, chosen by an agent listing what the catalogue happened to hold, and the
reviewer returned the trade fact that the ordinary fix is a passive strip on a shelf. **Neither
correction came from the pack. Both came from somebody who wires racks.**

**5.4.11.3 WHY THIS CLOSES AT ALL, GIVEN THE CAVEAT.** §8.1: done means demonstrated, and the thing
to demonstrate is that a domain expert read the rules and the catalog data and said what they think.
That happened, at length, and it moved four rulings. **A clause is discharged by evidence, not by an
empty backlog**, and `#845` is not a defect in this sign-off: it is the second pass, against a
product a team has used rather than against a document, which is a different act on different
evidence and cannot be performed today.

**5.4.11.4 THE VERSION REACHES `v0.5.60`, DERIVED TWO WAYS THAT AGREE.** The board query for Done
Chapters under epic 23 returns **60**. `v0.5.58` was current and **two CHAPTERS closed here**, `#305`
and `#306`, which is also 60. **`#837` is a STORY and is not counted**, which is docs/14 §14.0's rule
and the thing most likely to be got wrong today: DR-127 created four Stories and one Chapter, and
only the Chapter would ever move this digit.

**5.4.11.5 WHAT THE SECOND PASS WILL HAVE THAT THIS ONE DID NOT.** DR-125 §11.124.5 states the
limit of any pack: *"a pair proves a rule fires, not that it fires correctly."* The same holds one
level up. **This review proved the rules READ correctly. Only use proves they FIRE at the right
time**, and the three remedies DR-128 shipped have never been pressed on a real job. `#845` carries
that list; `#844` carries the shelf model, parked on the same evidence.

#### 5.4.10 The version was one behind, and the reason is worth more than the digit

**`v0.5.57` was current while the board held 58 Done Chapters under epic 23.** `68c87a7` closed
`#304` and declined the bump, reasoning that `#305` and `#306` are the review itself and cannot be
done by an agent, **so the pack shipped rather than the sign-off**. That is true about the STORY and
not about the rule: docs/14 §14.0 counts Done **Chapters**, and `#304` is one.

**Derived two ways, which is the discipline that caught it.** 57 plus the one chapter that closed
without a bump is 58; the board query for Done Chapters under epic 23 returns 58. **The two agree,
and neither is a number anybody typed twice.**

**ONE WRINKLE IS RECORDED RATHER THAN RESOLVED**, because resolving it silently is how the next
person inherits a number they cannot re-derive. That 58 includes **`#587`, which is M3 work**: it
closed 2026-08-13, during M3, and was re-parented under epic 23 by the `#690` hierarchy repair long
afterwards. The 0.5 series has counted it since the re-parenting, so the digit is consistent with
itself. **The alternative reading, that the patch counts only chapters whose work belongs to the
milestone, gives 57 and is equally defensible.** What is not defensible is switching between the two
without saying so, so the mechanical reading is kept: **the patch is the count of Done Chapters under
the epic, and the board is the register.** `#764` is unaffected either way and §5.4.5 already says
why, being parentless.

**THE WRINKLE IS RESOLVED AS OF §5.4.17, AND THIS PARAGRAPH IS LEFT STANDING RATHER THAN EDITED**,
because it is the reasoning that made the fix findable. `#690` is re-parented to epic 21, `#587` goes
with it, and **both readings now return the same number**, so the choice this paragraph made between
them no longer has to be remembered. The mechanical reading is still the rule; it simply no longer
disagrees with anything.

**This is the second time an unpaid bump has been paid in a later commit**, after `7d61656` which
records that `94a8f2c` said *"no version bump"* for the wrong reason. **The parity gate cannot see
this class of error**: `version_parity_test.dart` compares the six files against each other and is
structurally blind to all six being stale together, which is how `v0.2.0` sat through thirty M3 tasks
and `v0.3.30` through forty-six M4 ones.

#### 5.4.12 M5-N1, the census that should have run first, and what it narrowed · CLOSED · `#841`

**Six fields with no producer surfaced in M5 and four of them were found by a user's review**, which
is an expensive way to run a census. `#841` is the cheap way, run at last: sweep `PortDef`'s
constructor against `catalog_ports.dart`'s `p()` and ask what the shipped catalogue cannot say.

**ELEVEN FIELDS HAVE NO `p()` PARAMETER, AND THE HEADLINE IS NOT THE FINDING.** `position`,
`designatorHint`, `topology`, `conductorCount`, `level`, `channelIndex`, `wavelengthNm`, `bus`,
`serial`, `renamedFrom`, `carriedProtocols`. **Almost every one is written by the DEVICE BUILDER**,
where a person authors a port. They are not fields nothing can write; they are fields **the shipped
catalogue cannot express**, which is a narrower claim and the one worth making.

**THE SHARP QUESTION IS WHO READS ONE OUTSIDE THE BUILDER**, because there every seeded device takes
the default and the reader decides on a value nobody could have authored. That is DR-124's and
DR-126's shape exactly. Censused, **two do**:

| Field | Read by | Verdict |
|---|---|---|
| `topology` | `ConnectTarget.isMultidrop` | **COVERED, deliberately.** The seed declares `PortDirection.busNode` instead and the getter accepts either. That file has said so since M5-C |
| `carriedProtocols` | `template_facts.dart`, `template_search.dart` | **OPEN.** Nothing seeded populates it, so **searching the shipped catalogue by protocol matches nothing and always has**. `#846` |

**5.4.12.1 THE CENSUS FOUND THREE STALE CLAIMS, WHICH IS MORE THAN IT FOUND FIELDS.** All three sit
in `connect_target.dart`, in doc comments that REASON from them, and all three were falsified by
rulings from the preceding two days:

- *"Not one of the seed catalog's ports declares `maxConnections`"*: false since DR-124, which
  corrected a different paragraph four lines below and left this one standing.
- *"`PortDef.acceptedFamilies` ... is populated on NONE of the 727 seed catalog ports"*: false since
  DR-126, which populated eighteen.
- *"Three fields, one pattern"*: two of the three have since gained a producer.

**THIS IS THE COST OF A CORRECTION THAT EDITS ONE PARAGRAPH.** DR-124 knew `maxConnections` had
become authorable, said so in the place it was working, and did not sweep the file. A confident
bolded sentence three paragraphs up outlived it by a day. **The lesson is not "sweep harder"**: it is
that a claim about what the catalogue contains belongs in a test, where it fails, rather than in
prose, where it is believed.

**5.4.12.2 SO THE CENSUS IS A TEST.** `seed_producer_census_test.dart` names the eleven rather than
counting them, because a count of eleven passes on the wrong eleven. A field LEAVING the list means
something gained a producer and the list should shrink in the same commit; a field JOINING it means
`PortDef` grew something the catalogue cannot express, and the reason string asks the `#841` question
of whoever put it there. It also asserts its own parsers find something, on `#237`'s precedent: a
scan whose pattern stops matching reports a clean sweep.

**`carriedProtocols` IS NOT PRICED HERE**, and its third option is real: if protocol search is not a
v1 feature, deleting two dead reads and a field is cheaper and more honest than filling it, and the
data is a trade question under AC-052 rather than a code one.

**5.4.12.3 AND ITS OWN BUMP WENT UNPAID, WHICH IS THE THIRD TIME.** `#841` is a Chapter, it closed,
and the commit that closed it left the six files at `v0.5.60`. Paid in `#840`'s branch at
**`v0.5.61`**, derived the two ways §5.4.10 requires: the board query for Done Chapters under epic 23
returns 61, and 60 plus the one chapter that closed without a bump is 61. **`#840` itself is a Story
with no Chapters and moves the digit by nothing**, which is §5.4.11.4's rule and DR-127's `#837`
precedent.

**Three misses now, all the same shape**: a commit whose subject is the work forgets a digit that
lives in six other files, and `version_parity_test.dart` cannot see it because all six are stale
together. **The tell is that every one of the three was caught by DERIVING rather than by reading**,
which is the argument for the derivation being written into the commit message rather than the
number being copied out of it.

#### 5.4.13 M5-M, the code row that reads as a different kind, and the button ruled twice · CLOSED · `#840`

**DR-129 §11.128.** The M5-H2 reviewer's twelfth finding was one sentence: *"a code-adjacent finding
wants more than a row in a panel."*

**THE ARTICLE WAS PROSE.** `CODE-002`'s message ends *"Verify against NEC 800.154"*, which is correct
and puts the citation at the end of a sentence beginning with a cable designator. `RuleMeta` carried
`summary`, `rationale` and `governing`, and **`governing` holds this repository's ids, not the
code's**, so nothing in the model said "this rule turns on a document the product cannot read".

`RuleMeta` gains `codeCitation`, on DR-125's precedent that the catalogue authorises the fact and the
surface renders it. **Two rules and no others**, named in a test rather than counted.

**A DIFFERENT SHAPE, NOT A LOUDER COLOUR.** `ConsoleStatus.caution` had been defined, themed, and
reachable by no finding since M5-F; `status_marker.dart` draws it as a **diamond** where warning is a
triangle. DR-079 demoted both code rules to `warning` because *"this product cannot see the thing the
code article turns on"*, so a code row is not a louder warning but a different question, and a shape
says "different kind" where a colour says "different amount". **The severity is untouched**: the
filter still finds these under Warning and an override still moves them.

**5.4.13.1 AND THE PANEL FINALLY RENDERS `Finding.remedy`, WHICH DR-128 SAID IT ALREADY DID.**
§11.127.5 states the panel *"renders it as a button"*. It did not: the field shipped, `PWR-003`
declared one, `addOutletsToRack` implemented it, and `drc_panel.dart` never read the field.

**That is the second phantom button in two rulings.** The first was `SpringBackRemedy`'s two members,
and **Dart's exhaustive switch caught it within the hour** because a chip handler must match every
enum value. **A nullable field a widget ignores has no such backstop**: it compiles, and every test
that could have noticed was written against the model. `remedy_pairing_test.dart` is the backstop,
asserting the pairing in both directions in the shape the chips already use.

**5.4.13.2 AND THE PANEL ITSELF HAS NO HOST, WHICH IS `#847` AND NOT THIS.** Wiring the button meant
finding the panel's caller, and there is none: `DrcPanel` is referenced by its own definition and its
own test and by nothing else in the tree. **Everything M5-F built is unreachable**, and §5.4.6's
closing sentence is corrected above. Mounting it is a shell decision that `docs/04` §4.1 already
describes a seam for (`PanelHost` keyed by `PanelId`, neither of which exists), and improvising one
inside a rule-surfacing chapter would be the shelf mistake a second time.

**WHAT WAS OFFERED AND NOT TAKEN**: a separate verification dialog for code rules, recording who
checked what against which edition. `AckedFinding` already carries `reason`, `by` and `at`, so the
record exists; what a code acknowledgement wants is a different QUESTION, and the place that earns
its keep is **T0.02, the exceptions sheet, which is M6-C and not built**. Designing the form before
the page is the same error in a different direction.

#### 5.4.14 M5-L, the cabinet head end, and a fallback that did not exist either · CLOSED · `#839`

**DR-130 §11.129.** The M5-H2 reviewer's eleventh finding: a cabinet head end is **the COMMON
residential case rather than an edge**.

**THE FINDING'S OWN FALLBACK WAS NOT AVAILABLE.** DR-125 dispositioned this as *"expressible as
`OffRackPlacement` with a `mountNote`, but crude"*. Censused before pricing, which is what that
ruling requires of itself:

| | |
|---|---|
| modelled, serialized, round-tripped | yes, since M0 |
| written by a gesture | **no. Nothing** |
| the one hit in `commands/` | `location_commands.dart` carrying it across a location clear so it is not destroyed. A preserver, not a producer |
| rendered anywhere | no widget, no schedule, no exporter |
| actual writers | `apps/rackpal/tool/starters/`, the starter generator |

So four seeded devices carried sentences like *"Ceiling mount, rear of room"* that **no user could
have typed**, and the finding had been priced against a workaround reachable only by hand-editing
JSON. **Eighth field this milestone with no producer**, and the first found by censusing a ruling's
own escape hatch rather than by a rule firing on a connection that is correct.

**5.4.14.1 THE USER TOOK THE SMALLEST OF FOUR OPTIONS**, and the reasoning is not timidity: what a
common case needs first is to be **sayable**. A device in the AV closet on the top shelf should print
that way on the schedule and in the PDF rather than appearing as a device with no location, and a
note reaches every one of those surfaces. Geometry reaches none of them without a drawing nobody has
drawn, which is `#844`'s argument and does not improve by being made twice. A first-class container
reusing DR-128's `ShelfPlacement` would have **unparked `#844` by accident**, six commits after it
was parked.

**5.4.14.2 BUILT IN THREE COMMITS, EACH ONE A LAYER**, because the milestone has now twice shipped a
layer and described the next one as done. `55c4146` the writer, `a346742` the sheet, `d90a590` the
control. **The last is where `#847`'s lesson was spent**: seven of that commit's eight tests mount
`InspectorPanel` themselves, which is exactly how `DrcPanel` passes its own suite while nothing in
the product mounts it. The eighth mounts `RackCanvasScreen` and asserts **the screen hands over the
callback**, which is the one assertion a panel test cannot make about itself.

**5.4.14.3 TWO GATES AND ONE CANARY CAUGHT REAL THINGS**, all three worth recording:

- **The canary earned its keep on its first run.** The test asserting no `PLC` finding asked
  `evaluateDocument` for one. `PLC-001` is **tier 1** and that entry point never emits one for any
  document, so the assertion passed on a rule it was not reaching. The silence is now measured in
  `evaluatePlacement`, where the rule lives, and `RCK-002`, its tier-3 half, is asserted quiet too.
- **`epoch_mask_test`** caught `EquipmentRow` reaching 14 fields against a projection written for 13.
  A field the projection cannot see is a change AC-014 cannot see.
- **A doc comment was overstated and is corrected.** `Finding.withSeverity` claimed that forgetting a
  field at the constructor *"is a compile error rather than a quiet loss"*. It is not: a field with a
  default is a **silent drop** at a call site that omits it, which is the very defect that method was
  written to stop. What one copy site buys is one place to remember, not a compiler that remembers.
  Same class as the three stale claims `#841` found in `connect_target.dart`.

**5.4.14.4 NO RULE WAS ADDED, and the count stays at 28.** `PLC-001` asks whether a rail position
fits inside a rack; a cabinet has neither, so the rule is unevaluatable and silent, which is G4
rather than an omission. Making it fire would be fabricating a rack. **Whether a cabinet's outlets,
watts and BTU should roll up as a rack's do is left open and filed**, because the honest version of
that question needs the container the ruling declined.

#### 5.4.15 M5-K, the switchable device that was the speaker, and a rule that already had an id · CLOSED · `#838`

**DR-131 §11.130 and DR-132 §11.131.** The M5-H2 reviewer's fifth finding: *"`maxTapWatts` exists on
the model; a tap SELECTOR and CV-to-Low-Z switching do not."*

**5.4.15.1 THE USER'S CORRECTION RELOCATED THE WHOLE PROBLEM.** The question went to them as a
switchable AMPLIFIER and asked how its mode is recorded. The premise was wrong: *"Amplifiers are very
rarely switchable, and if they support both Low-Z and CV, they almost always have separate outputs
instead of a switch. Speakers are the only CV devices that I've seen with taps/switches for
Low-Z/CV in person."*

**The catalogue already agreed, and nobody had checked.** `A05`, the only rack-side CV source,
declares two `audio.speaker_cv` bus nodes at `nominalVoltage: 70` and **has no low-Z output at all**.
The amp side needed nothing, and a mode switch was one chapter from being built onto a model that was
already right. **Third trade correction this milestone**, after the passive power strip and the
shelf, all three the same shape.

**5.4.15.2 THE MILESTONE'S NINTH AND TENTH PRODUCER GAPS, FOUND BY COLLIDING WITH THEM.**
DR-131 was drafted ruling the tap onto `DeviceInstance`, and **`Port.tapWatts` already existed**,
documented as *"per INSTALLATION, not per template"* and written by nothing. The census that priced
the ruling grepped `maxTapWatts` and never grepped `tapWatts`: `census-the-field-not-the-name` for the
fifth recorded time. `PortDef.bus.maxTapWatts`, the capacity half, was declared on **zero of 727
seeded ports** because `p()` had no `bus` parameter.

| | authorable | in the data | read by |
|---|---|---|---|
| `Port.tapWatts` | no | n/a | nothing |
| `bus.maxTapWatts` | in the device builder only | 0 of 727 | nothing |

**5.4.15.3 PATCHING `ELE-006` WAS THE WRONG LEVEL, AND THE GATE PROVED IT IN A MINUTE.** Teaching the
rule to ignore a bypassed source made **`SIG-002` refuse the same correct connection**: the sink's
`acceptedFamilies` never listed `audio.speaker_cv` and the source still called itself constant
voltage. **Two rules disagreeing with one physical switch** is the signal that the fact belongs
upstream, so the bypass now moves the resolved family in `resolvePortSignalFamily` and neither rule
needed changing.

**That surfaced a defect nobody had ticketed**: both `_oneOf` and `SIG-002`'s acceptance check read
`def.signalFamily`, the raw TEMPLATE value, so **every port-family correction `#233` lets a person
make has been invisible to every tier-2 rule** since that resolver was built.

**5.4.15.4 `ELE-005` WAS NOT A NEW RULE, AND A DUPLICATE WAS TWO GREPS AWAY.** The plan was to mint
`ELE-007`. `docs/research/design-data-model.md` line 1136 already specified `ELE-005` as *"warning: Σ
of 70 V/100 V `tapWatts` on a net > 80% of the amp channel rating"*, matching the severity the user
asked for and the 80% `PWR-001` independently sets. **`ELE-007` was taken too**, by a
satellite-splitter rule in the same document. AC-040 is amended to 29 by DR-132, `ELE-004` stays cut,
and every count guarding that number moved in the same commit.

**5.4.15.5 THE TESTS CAUGHT TWO DEFECTS THE AC-051 PAIR COULD NOT.** DR-125 §11.124.5's limit again:
a pair proves a rule fires, not that it fires correctly. **The amplifier was being reported as a
speaker nobody had measured**, because its own port has no tap and landed in the unknown list. And
the first draft of the near-miss **fired**, summing 220 against a 200 W budget; it is now
60+60+60+20, on the boundary exactly, which also catches a `<=` written as `<`.

**5.4.15.6 AND THE EXHAUSTIVE SWITCH ONLY CAUGHT HALF.** Adding two `PortFactField` values forced
every branch of `SetPortFactCommand` to be written before it compiled.
`device_ports_section.dart` lists its controls **by hand**, so both fields compiled green with no way
to set either, exactly as DR-128's nullable `Finding.remedy` did. `port_tap_controls_test.dart` is
the gate, in `remedy_pairing_test.dart`'s shape.

#### 5.4.16 M5, the panel gets a host, and it was in the layout table all along · CLOSED · `#847`

**DR-133 §11.132.** Ordered into M5 by the user behind `#838` and `#839`, and settled mostly by
**reading docs/04** rather than by deciding anything.

**5.4.16.1 THE ITEM WAS FILED CLAIMING A DECISION THAT WAS ALREADY MADE.** `#847` said *"mounting it
is a shell decision, not a widget one"* and listed three open questions. **docs/04 answers all
three.** §1's layout table carries a row for it, written and never built:

| Element | Default | Range | Behaviour |
|---|---|---|---|
| **Validation drawer** | 28 px | 28 / 320 | Auto-expands to 180 px **once**, on the first *error* per session, never again |

and §8's keymap names `F7` re-check, `F8` next issue, `Shift+F8` previous, none of which was bound.

**One of those answers is better than what was about to be proposed.** A keybinding was going to be
offered; the spec says **it opens by itself**, and a person who does not know the validation engine
exists cannot press a key to find it. That is precisely the state §5.4.6's closing sentence claimed
to have ended.

**5.4.16.2 THE SHELL BECAME A COLUMN, WHICH IS WHY NO SEAM WAS NEEDED.** The drawer is a horizontal
band under the palette/canvas/inspector row, not a fourth column, so it wanted neither the unbuilt
`PanelHost` nor a share of the inspector's 320 px. **The whole `#847` estimate rested on a seam the
work did not touch.**

**5.4.16.3 THE ONE THING THE SPEC DOES NOT SAY.** *"The first error per session"* leaves open what an
error IS at that moment, and `RuleOverride` and `AckedFinding` both move severities. **Ruled: the
RESOLVED severity**, so a project that demoted a rule is not overruled by a drawer, which is RJ-006's
whole reason for keeping the acknowledgement machinery.

**5.4.16.4 THREE THINGS CAUGHT THIS CHAPTER, AND TWO WERE GATES NOBODY HAD MET.**

- **`draw_source_gate_test`** asserts every test file a production comment cites actually exists,
  because a reader following a dead reference *"finds nothing, which reads exactly like the gate
  having been deleted"*. A comment named `drc_drawer_test.dart` against a file called
  `validation_drawer_test.dart`.
- **RULE 14 in `session_layering_test`** failed a keymap group bound two-of-three. Its own words:
  *"a partial keymap reads as a whole one, so a group lands only when it is complete."* `F7` had been
  left out on the argument that a re-check key has nothing to do while validation recomputes on every
  build. **The rule was right and so was the argument's opposite**: "re-check" promises to re-run the
  check and does, and a phantom button is one that does NOTHING.
- **Two self-inflicted defects, found before committing**: an unreachable `else if (advisories > 1)`
  that would have printed *"3 advisory"*, and an `onHeightChanged` parameter with no gesture calling
  it, which is the ninth-and-tenth producer gap's shape committed by the person who had just written
  the practice note about it.

**5.4.16.5 EVALUATION RECOMPUTES ON BUILD, AND THAT IS FILED RATHER THAN HIDDEN.** `evaluateDocument`
walks the whole document on every frame of this screen. The epoch machinery exists so a derived view
can recompute only when the epochs it reads bump, and wiring it is real work with a real payoff.
**It is not this chapter**: `#847` is about the panel being reachable at all, and a correctness
problem would be worse to ship than a performance one.

#### 5.4.17 M3-O closes on evidence it already had, and a work item nobody could ever close · CLOSED · `#690`

**DR-025 §11.24.** `#690` was the last item standing between M5 and its clause count, and **it had
no work in it**. Its own description says so in its first sentence: *"Created 2026-08-13 as
HIERARCHY REPAIR, not new scope. The work is `#587` and predates this issue."* It then sat `To Do`
for twenty four days.

**5.4.17.1 DEMONSTRATED RATHER THAN ASSERTED, BECAUSE §8.1 SAYS SO.** The item lists three missing
things, *"the modifier and the Command behind it"* and the picker. All three are built, and the
whole chain is reachable:

| DR-025 clause | Where it lives | State |
|---|---|---|
| §11.24.3 `@signal=` names the family | `drop_line_parser.dart:191`, `drop_line_planner.dart:390` | built |
| §11.24.3 an unresolved value REFUSES | `resolveSignalFamilyToken`, one resolver, three callers | built |
| §11.24.5 a run can gain a family after the fact | `SetSignalFamilyCommand` | built |
| §11.24.6 the family is stored TWICE, both or neither | the command writes `Service` and `Net` | built |
| the SERVICE column becomes a picker | `FamilyPicker`, mounted at `structure_editor_screen.dart:2192` | built |
| the cell reaches a command | `structure_edit_actions.dart:158` to `buildSetSignalFamily` | built |
| §11.24.3's owed docs/07 §5.1 edit | the `service` row split from a new `signal` row | made |

Run rather than read: `signal_modifier_test.dart` and `signal_family_command_test.dart` are twenty
tests and pass, and `structure_editor_route_test.dart` is forty one including *"a bulk SERVICE set is
one undo, and both fields come back"*, which is the end to end path through the real shell. **The
closing commit is `8756c79`** (§8.8), over `b4cf8e7`, `48ae15b`, `515d61e`, `80fd007` and `ecb015c`.

**5.4.17.2 THE FINDING IS A NEW SHAPE OF THE MILESTONE'S OWN THEME.** M5 found ten fields that were
modelled and unreachable, and one panel. This is the same defect one level up: **a work item that
nothing could ever close.** Every other item on this board closes when a commit cites it. `#690`'s
work had already landed when it was created, so no future commit would ever name it, and the board
offers no other way for a Story to become `Done`. It was not forgotten. **It was unreachable**, in
exactly the sense the rest of this milestone has been using the word.

The cheap check is the one `#841` reached for a field: **a hierarchy repair that wraps completed work
must be closed in the same act that creates it**, because the act of creation is the last moment
anybody has a reason to look at it.

**5.4.17.3 THE PARENTAGE IS FIXED, AND §5.4.10's WRINKLE IS NOW RESOLVED RATHER THAN RECORDED.**
`#690` is re-parented from epic 23 (M5) to epic **21** (M3), where its work was done and where its
ruling belongs. That carries its Done child `#587` with it, and **that child is what §5.4.10 recorded
as a wrinkle it could not resolve**: an M3 chapter counted in M5's patch digit, leaving *"the patch
counts Done Chapters under the epic"* at 61 and *"the patch counts chapters whose work belongs to the
milestone"* at 60, both defensible and neither correct.

**RE-PARENTING DISSOLVES THE AMBIGUITY INSTEAD OF PICKING A SIDE OF IT**, which is a third option
§5.4.10 did not have while the item's home was wrong. **Both readings now return 60**, so the two
derivations agree again and neither is a rule anybody has to remember having chosen.

**THE VERSION IS THEREFORE ONE AHEAD, AND THAT IS STATED HERE SO IT IS NOT READ AS A SKIPPED BUMP.**
`v0.5.61` has shipped and a version does not count backwards. It stays at `v0.5.61` and does not move
when `#846` closes, because that close takes the register from 60 to 61 and the two meet. This is
§5.4.10's failure inverted, and it is written down for §5.4.10's own reason: **resolving it silently
is how the next person inherits a number they cannot re-derive.**

**5.4.17.4 SO M5's OPEN COUNT WAS WRONG, NOT ITS WORK.** The epic held two open Stories and one of
them was M3's. **M5's only genuinely open item is `#846`**, under `#842`.

#### 5.4.18 M5-N, the field that was a second copy, and the cell a closed item never built · CLOSED · `#846`

**DR-134 §11.133**, a §8.3 amendment. M5's last genuinely open item, and the one where **the case put
to the user was wrong in its facts**.

**5.4.18.1 THE RECOMMENDATION WAS RELAYED BEFORE THE MEASUREMENT WAS TAKEN.** `#846` reads
*"searching the shipped catalogue by protocol matches nothing, and always has"*, and it was passed on
with *"deleting two dead reads and a field is cheaper and more honest than filling it"*. Both halves
are false, and both were checkable in one command:

| The claim | Measured |
|---|---|
| protocol search matches nothing | it matches. `dante` finds the seeded DSP twice, by the `audio.dante` family on its `dante.pri` / `dante.sec` ports and by the device's own `dante` tag. **`template_search_test.dart` has asserted it since M4** |
| two dead reads | neither is dead. `templateHasFamilyPrefix` tests `signalFamily` first; the search tokeniser already adds `connector.v` and `signalFamily.v` per port. Both are **widenings of paths that work** |

**A FINDING ABOUT A FIELD IS NOT A FINDING ABOUT THE FEATURE IT IS PART OF**, and that is the
reusable half. `#841`'s census asked the right question, *what reads this outside the builder*, and
answered it right, *two things do*. Reading that as *the feature those two implement is broken* is a
different claim needing a different measurement, and the measurement was sitting in a test file.

**5.4.18.2 THE REAL CASE IS BETTER AND CAME FROM THE SPEC'S OWN WORKED EXAMPLE.** docs/02 §6.2 uses
`carriedProtocols` for exactly two things, and the model already records both with a producer **and**
a consumer:

- **eARC over HDMI.** `PortDef.returnChannel` has a builder column, seed data on two catalogue
  entries, a spring-back rule and a schematic consumer. **§6.2's example writes the eARC fact twice
  on one port**, once in each field, and only the copy that is not `carriedProtocols` is read.
- **Dante over RJ45.** A signal family on a dedicated port, plus a device tag.

So the field was not an unfinished feature. **It was a weaker spelling of two facts already recorded
properly**, and it cost 737 empty arrays per starter, which is `position`'s defect one field over in
the same encoder (DR-105 §11.104.3).

**5.4.18.3 THE USER CHOSE TO BUILD DR-081's CELL RATHER THAN NARROW IT**, which is what makes this an
amendment worth its own commit. DR-081 ordered one multi-select over both family lists and said
*"THE CELL SHAPE IS THE DELIVERABLE, NOT THE TWO COLUMNS"*. **`#224`, the item DR-081 landed that
scope on, is `Done` and the cell was never built.** The surviving field is the one that needed it:
`acceptedFamilies` gained eighteen seeded ports at DR-126 and **three connect-time readers**, so a
value the DRC consults had no gesture that could correct it. That is this milestone's own defect,
found ten times, and shipping it knowingly on the day of the tenth would be worse than the nine that
were accidents.

**5.4.18.4 WHAT MADE THE CELL SHAPE A DELIVERABLE IS ONE FACT ABOUT DART.** `==` on a `List` is
IDENTITY. Every scalar cell in the grid compares readings with it, and **four places were wrong the
moment a column held a set**, each failing differently:

| Where | What it would have done |
|---|---|
| `port_fill.dart`'s `_set` | never skip, so a fill-down files a command per row that changes nothing: an undo entry that appears to do nothing when reverted, which is M4-D's shipped defect |
| `summariseBatch`'s `contains` | eight ports that all accept nothing hold eight different empty lists, so the dock reads **`Mixed (8 values)`** on a selection that agrees completely, with nothing ticked |
| `port_grid.dart`'s cell setter | the same check, inline |
| `port_commands_test.dart`'s alias census | **caught itself on the first run**: the getter hands back `List.unmodifiable`, a fresh object per call, so every probe reported `acceptedFamilies` as having moved |

**THE LAST ONE IS THE INSTRUCTIVE ONE**, because loosening the test was the right fix only because
the getter was right. A stable reference would have meant handing out the live list, which is the
aliasing that file exists to detect, one level down. `acceptedFamiliesEqual` is core's one rule and
all four use it.

**5.4.18.5 THE COPY SAYS `Own family only`, AND DR-081's OWN WORDING WOULD HAVE SAID THE OPPOSITE.**
§11.80.5 spells an empty list *"this port constrains nothing"*. `ConnectTarget.acceptsFamily` is
`signalFamily == f || acceptedFamilies.contains(f)`: **the list only ever WIDENS**, so an empty one
is the NARROWEST state rather than the loosest, and a cell printing *no constraint* would tell an
installer the reverse of what the port does. **The distinction §11.80.5 was drawing survives intact**
(an empty list is a statement, not an unknown, so it is not the dash either); only its wording does
not.

**5.4.18.6 TWO MORE DEFECTS THE TESTS FOUND IN CODE WRITTEN AN HOUR EARLIER.** The menu's
`SingleChildScrollView` adopted the `PrimaryScrollController` the grid's own list already held, and
the framework throws the moment the menu opens over a scrollable grid. And the widget test's first
finder was `find.text` on a family label, **which is on screen twice** once the port accepts that
family: the cell summary and the menu row. The rows carry keys for exactly that, and this is
`a finder that cannot say which one` catching itself with the tool it recommends.

**5.4.18.7 AND THE `.rmdx` CHAIN GOT ITS FIRST STEP, NINE DAYS AFTER SHIPPING EMPTY.** Deleting the
field moves the bytes of a device-exchange file too, and its `contentHash` covers them, so every
`.rmdx` written before this would have imported reporting a mismatch. `migrateRmdxToCurrent` shipped
with no steps at M4-M and argued for itself in advance: it bought *"the SEAM plus the refusal, so
that the first person to bump `kRmdxSchemaVersion` adds a row to a table that already exists instead
of discovering that `.rmdx` never had a chain and inventing one under deadline."* **That person
arrived and it was a row.** The migration recomputes the hash, which is a real cost stated in
§11.133.7: a migrated file verifies against itself and nothing more, taken because a warning that
fires on every older file is one a person learns to click past.

**5.4.18.8 THE VERSION DOES NOT MOVE, AND §5.4.17 PREDICTED THAT IN WRITING.** Closing `#846` takes
the register from 60 to 61. `v0.5.61` has shipped since `#840` and was one ahead from the moment
`#690` was re-parented, so **the two meet here and no bump is owed**. Derived the two ways §5.4.10
requires: the board query for Done Chapters under epic 23 returns 61, and 60 plus this chapter is 61.


### 5.5 M6, The full sheet set · `M` · NOT STARTED, weakest mark `NOT BUILT` · blocked three ways

> **Exit criterion, verbatim.** All four starter projects export a complete sheet set; the legend has
> been verified under deuteranopia and protanopia simulation and on a real greyscale laser print
> (AC-054); the ANSI B laser, ANSI D plotter and photocopy reproductions have all been **physically
> inspected and signed off** (AC-058 D13). Requirement 7 is met. **Windows OV/EV certificate
> procurement starts here**, two milestones before release.

> **Amended by DR-006 (canon §11.6).** The last sentence — *"Windows OV/EV certificate procurement
> starts here"* — **is withdrawn.** RackMate is an internal tool; signing is self-signed, with
> Microsoft Trusted Signing as the named fallback at M8, and neither has an OV/EV reputation ramp.
> The rest of the criterion stands unchanged.

| Clause | Mark | Why |
|---|---|---|
| All four starters export a **complete sheet set** | **NOT BUILT** | They export **3 of 12 slots**. Missing: `T0.00` cover/index, `T0.01` legend, `T0.02` exceptions, `T6.01+` interconnect, `T6.10` pull sheet, `T6.11` termination schedule, `T6.20` unused home runs, `T6.50` network/IP schedule (added to v1 by DR-048, `AUTO`), `T5.01` pinout details. `sheet_def.dart:15-20` states this plainly and states **why**: *"most of them need `Link`s, which do not exist until M2. They are absent from `SheetRole` rather than stubbed"*, and `T6.50` joins them for the neighbouring reason: `NetworkConfig` has existed since M0 with no writer, so the sheet would have had nothing to print |
| Legend under deuteranopia / protanopia simulation | **UNPERFORMED** | No legend sheet exists to verify |
| Real greyscale laser print (AC-054) | **UNPERFORMED** | Nothing has been printed |
| ANSI B laser / ANSI D plotter / photocopy, physically inspected and signed off (AC-058 D13) | **UNPERFORMED** | Nothing has been printed |
| Requirement 7 met | **NOT BUILT** | Follows from clause 1. (`NOT MET` is not one of §0's seven marks; the mark is the one clause 1 carries. Note this is distinct from `REFUTED`, which requires that somebody actually attempted the act and it failed; nobody has attempted this one) |

**Why this is `NOT STARTED` and not `PARTIAL`.** Real, tested, shipped work sits inside M6, more
than in any other unstarted milestone, and none of it discharges a clause of M6's criterion, which
is about **complete** sheet sets and **physical** sign-off. §0's rule grades the criterion, not the
work. The work is described next so the headline does not erase it.

**What exists is M1's slice, and it is real.** `packages/rackpal_core/lib/src/draw/sheet/` carries
`sheet_frame.dart` (border, outer/inner rules), `title_block.dart`, `revision_block.dart`,
`sheet_furniture.dart` (which composes them into **one `DiagramScene` fragment so `rackpal_ui`
can replay the identical object**, a deliberate and documented deviation from docs/08 §5's
`PageTheme` mechanism) `drawing_scale.dart` (the honest `1:n` / `NTS` report),
`elevation_sheet.dart` and `equipment_sheet.dart`. All are tested
(`packages/rackpal_core/test/sheet/*.dart`, `packages/rackpal_export/test/sheet_furniture_pdf_test.dart`),
all four starters export real PDF bytes (`packages/rackpal_export/test/starters_export_test.dart`),
and export is wired into the app with a full error surface
(`apps/rackpal/test/session/export_controller_test.dart`).

**Furniture is incomplete against DR-005.** The **zone band and grid are not drawn**, 
`packages/rackpal_core/lib/src/draw/sheet/sheet_frame.dart:377` says so verbatim (*"The zone band
between them is NOT drawn, see the file header"*) and `:23-30` records the deviation and the arithmetic behind it (*"THE 6 PT INSET vs §5.1's ZONE BAND, recorded rather than papered over"*). There are no
revision clouds and no `RevisionEntry`-driven lettered triangle. There is no `ISSUED FOR
CONSTRUCTION` stamp (grep across core and export `lib/` returns nothing). Also absent: dry-run sheet
count, the 40-sheet warning, the 2000-sheet cap, export preview, progress/cancel, and the `kIsWeb`
isolate guard.

**Incremental cost from here:** nine sheet roles, the zone band and grid, revision clouds, the IFC
stamp, and the export-dialog apparatus. **Hard-blocked three ways** as a join on M2, M3 and M5, the
milestone most exposed to slip anywhere upstream (roadmap §5).

**M6 grew on 2026-08-12, by one `AUTO` sheet, and the interesting part is what the growth was made
of.** DR-048 (canon §11.47, §12.20) moves **`T6.50` Network/IP Schedule** into v1, superseding
DR-005 §11.5.3 for that slot alone. `T6.40` Power Schedule does not move, and the asymmetry is the
whole argument: **`NetworkConfig` has been in the format since M0 and the power data has not**, so
`T6.50` is a sheet over data the model already holds while `T6.40` would be a sheet plus the model
to feed it.

***THE FIELD HAD NO WRITER ANYWHERE, NOT EVEN A TEST FIXTURE.*** `NetworkConfig{hostname, ip,
subnet, gw, mac, vlans[], portRole}` on `Port`, plus `DeviceInstance.macAddressPrimary`: modelled
since M0, encoded and decoded, and the single assignment in the entire tree is `json_codec.dart`'s
decoder. It is the **seventh** instance of the reachability practice and the **first found by
reading rather than by using**, because the feature request was censused before it was priced
rather than after. Every earlier instance had at least a fixture.

***A RESERVED SHEET ID WAS THE MOST AUTHORITATIVE-LOOKING STATEMENT ABOUT IT, AND IT WAS NOT ONE.***
`sheet_def.dart`'s `kReservedNcsIds` reserves `T6.50` for *"the v1.1 Network/IP Schedule"*, citing
docs/08 §2.2, which is a derived document. **Roadmap §2 carried no row for it in any release**:
`grep -in network docs/09-roadmap.md` returned nothing. So a modelled field, a working codec and a
reserved sheet number together read as *nearly shipped* while the thing was zero percent reachable,
which is §5.2's *two documents agreeing is not verification* wearing a sheet id.

**The sheet is `AUTO` rather than `ON`**, iff at least one device carries a network value, on the
pattern `T6.20` and `T5.01` already set. A residential job with no managed switch must not print a
blank page, because an empty sheet in a client deliverable (DR-005) reads as an omission rather than
as an absence.

**One defect is fixed with the work rather than filed.** `_encodeNetworkConfig` writes
`{'vlans': n.vlans}` **unconditionally**, so an untouched list encodes as `"vlans": []`, which under
CR-114 claims *measured zero* where the fact is *nobody said*. It has never mattered because nothing
ever constructed one; it becomes the common case on a device-level record. Filing it would mean
shipping the defect and the fix in that order.

### 5.6 M7, Platform and access · `M` · NOT STARTED, weakest mark `NOT BUILT`

> **Exit criterion, verbatim.** A reviewer opens a `.rackmate` file on a tablet and reads the
> elevation, the schedule and the PDF; the NVDA matrix passes on the elevation, the schedule and the
> connection-creation path; no keybinding is bound twice in the generated table; the pseudo-locale
> build shows no hard-coded English in the primary surfaces.

| Clause | Mark | Why |
|---|---|---|
| Tablet read-only surfaces | **NOT BUILT** | `apps/rackpal` has only a `windows/` platform directory, no `android`/`ios`/`macos`/`linux`, which `apps/rackpal/pubspec.yaml`'s `path_provider_windows` comment states as a deliberate fact. No explicit statement for the two unavailable surfaces either |
| NVDA / VoiceOver matrix | **NOT BUILT** | And the connection-creation path it must pass on does not exist (M2) |
| No keybinding bound twice **in the generated table** | **NOT BUILT: nothing generates a table** | Keybindings are hand-written `SingleActivator` maps in exactly two files: `apps/rackpal/lib/src/session/app_shell.dart:69-76` (`kFileShortcuts`, four file bindings at `:71`, `:72`, `:73` and `:74-75`, asserted at exactly four by `session_layering_test` RULE 14) and `packages/rackpal_ui/lib/src/canvas/rack_canvas_screen.dart:3278-3350` (the canvas `Shortcuts` map, **18** `SingleActivator` entries counted over that range, `Ctrl+Alt+N` for the New-rack dialog is the newest, and `Esc` is now bound to a ladder rather than a single cancel). Nothing generates a table and nothing arbitrates collisions. CR-101's 16 collisions are unfixed because the ~40-binding keymap does not exist |
| Pseudo-locale build shows no hard-coded English | **NOT BUILT** | **No localisation at all**: `apps/rackpal/pubspec.yaml` has no `flutter_localizations` dependency, no `.arb` files, no `AppLocalizations`, so docs/11 §7's `flutter gen-l10n && git diff --exit-code` gate has nothing to run against |

**Inherits an unpaid M1 debt:** roadmap §4 M7 *Risks* names the outline tree shipping in M1 as this
milestone's mitigation, and it did not ship (§3.3).

**Also missing:** WCAG AA verification, raised filtered-wire alpha, non-colour encoding on rack
fills, the in-app glossary, the single-voice error-message catalogue, the eight empty states, and
progress/cancel on every operation over 500 ms.

### 5.7 M8, Release engineering · `S` · NOT STARTED, weakest mark `NOT BUILT` · **re-scoped by DR-006**

> **Exit criterion, verbatim.** A signed installer runs on a clean Windows 11 machine **with no
> SmartScreen warning**, the app cold-starts within budget, a deliberately induced crash produces a
> local report containing **no project content**, and the documented limits behave as documented.

> **Amended by DR-006 (canon §11.6).** The SmartScreen clause is **split**, because no build-side
> property can deliver it: SmartScreen fires on **Mark-of-the-Web**, a function of *how a file is
> distributed*, not of the binary. The build-side gate becomes **signed, timestamped, valid publisher
> in file properties, and the signature still validates after the signing certificate has expired**.
> The distribution-side requirement — deploy over a Local Intranet UNC share or Intune/GPO so MOTW is
> never applied, and never over an HTTP-fetched ZIP — is **documented, not a build gate**. Full text
> and the ZIP trap: canon §11.6.

| Clause (as amended) | Mark | Why |
|---|---|---|
| Signed, timestamped installer; signature outlives the cert | **NOT BUILT** | A whole-word search for `msix`, `Inno Setup`, `signtool` and `codesign` across every source, script and manifest returns **nothing** outside `docs/` prose, build outputs, `.dart_tool/` caches and `.git/`. No installer configuration, no packaging tool, no signing script |
| Cold-start within budget | **NOT BUILT** | No budget is defined and none has been measured |
| Induced crash ⇒ local report with **no project content** | **NOT BUILT** | No crash reporter exists. The only related artefact is `apps/rackpal/lib/src/storage/storage_log.dart` and `session_layering_test` RULE 13's CR-096 redaction check, **a policy with no reporter behind it** |
| Documented limits behave as documented | **VACUOUS** | No documented limits, no 1.5× soft warning, no 3× open-read-only gate in code |
| *(not an exit clause: M8 checklist)* Licence / EULA, `showLicensePage`, version-check ping | **NOT BUILT** | Listed for completeness. M8's exit criterion has **four** clauses; this row is checklist scope, and it does not enter the weakest-mark arithmetic |

**One thing this milestone inherits cleanly:** the Release build is already lean.
`apps/rackpal/build/windows/x64/runner/Release/` (**not** the repo-root `build/`, which holds only
`native_assets/`, `test_cache/` and `unit_test_assets/`) contains six entries: `rackpal.exe`,
`flutter_windows.dll`, two plugin DLLs (`screen_retriever_windows_plugin.dll`,
`window_manager_plugin.dll`), `data/` and `native_assets.json`. The load-bearing fact is what is
absent: **no `dartjni.dll`**, here or anywhere in the tree, which
`apps/rackpal/test/flutter_dependency_test.dart` asserts and which the `flutter build windows
--release` run this session confirms.

### 5.8 M9, Beta hardening · `M` · NOT STARTED, weakest mark `UNPERFORMED` · hard-blocked on M8

**`#844` IS PARKED HERE AS A MAYBE (DR-128 §11.127.10), and it is the first thing in this milestone
that is a MODEL question rather than a hardening one.** Building `PWR-003`'s remedy needed shelf
placement, which nothing in the product could do, and the user returned five trade facts about what
a shelf actually holds: sub-1U devices stack, a shallow device leaves room at the back for a power
strip, a modem sits sideways or upright, and Penn Elecom and Marantz make shelves for specific gear.

**AC-043 cuts three of the five by name and never considered the fourth**, which is that
`TemplateBody` has no body height in `Len` at all. So the auto-pack half shipped at DR-128 as an
IMPLEMENTATION of AC-043, and the rest waits on evidence: *"I'll see how the team reacts to the
version you're building now."* It sits in M9 because the trigger is a team using a build, which is
what beta hardening is for. **A maybe, not a schedule**, and moving it to M8 if the reaction says
it must precede release is one Story between two Epics.
> **Exit criterion, verbatim.** Three integrators have each produced a sheet set they were willing to
> send to a client or a job site, and none of the three needed to leave the app to fix something.
> **That is the only exit criterion that matters and it is deliberately a judgement, not a metric.**

**Unreachable on two counts.** Nothing is installable, so no integrator can run it (M8); and only 3
of 11 sheets exist, so no sheet set is sendable (M6).

No beta artefacts of any kind exist in the repo: no integrator names, no real-project fixtures
beyond the four synthetic starters (`apps/rackpal/assets/starters/{apartment,home_theatre,small_office,whole_house}.rackpal`,
all authored by `apps/rackpal/tool/generate_starters.dart`), and no performance harness to measure
against recorded budgets, **zero `@Tags(['perf'])` tests exist**.

`RISK-08`'s early warning (*"no named integrator by the end of M6"*) is moot because M6 has not
started, but **the recruiting lead time is already running against the calendar**, and it does not
depend on anything being built. Under DR-006 the population changes (three integrators become three
internal users on three real jobs, §7.2's M9 row) but the lead time does not.

### 5.9 The Plan view · `L` · **OPEN since 2026-09-07**, 4 of 7 discharged, 1 parked, weakest mark `UNPERFORMED` · decomposed 2026-08-10

> **Exit criterion, verbatim** (DR-037 §11.36.1, roadmap §4). An architect's floorplan PDF is
> imported **without leaving the app**, calibrated from one known dimension, and the rack plus every
> drop of a real rough-in carries a pin. The project exports a sheet set whose `T1.01` places a
> callout for every pinned drop, each printing the designator its Pull Sheet row prints. **A person
> who has never seen the building is handed the printed `T1.01` and the printed Pull Sheet, and
> locates every drop without asking a question.** The set is printed on a real greyscale laser at
> ANSI B and every callout stays legible over the screened underlay (AC-054).
> `write(read(bytes)) == bytes` holds on the zip path across a write, a reopen and a second write,
> and a project with **no** underlay writes bytes identical to what the plain-JSON path writes today.

**An epic, not a milestone number** (DR-029 §11.28.4), on this board's own precedent (#55 macOS,
#100 Store). Sequenced **before M6** because M6's criterion is that all four starters export a
*complete* set, and a plan sheet arriving afterwards would make that criterion run twice.

**OPENED 2026-09-07 BY DR-135 §11.134, OVER A CLOSED M5.** §8.9's condition is that a milestone opens
only over a predecessor whose clauses are all discharged or parked, and M5's three are discharged
(§5.4). **Opening discharges nothing here**: all seven clauses below are still `NOT BUILT` or
`UNPERFORMED`, and the header said `0 of 7` for that reason. **RE-MARKED 2026-09-24 AT
`#943`**, and that sentence describes the epic at its opening: four clauses are now
`DEMONSTRATED`, one is parked on M6, and the two left are the physical acts of `PLAN-J`. §8.9
also says closing is the moment that binds and opening is soft, so this line records a fact
rather than claiming a permission.

**AND THE REQUEST THAT OPENED IT NAMED M6.** It self-corrected before any work started, which is
what the note in §5.4 exists for, but the near miss is recorded because the sequencing lives in three
places (DR-029 §11.28.4, roadmap §4, §5.4 of this file) and was still nearly missed. **`M6-A` does
not exist as work anybody can start**; the first buildable row of the current epic is `PLAN-A`.

**THIS EPIC TAKES THE `0.6` VERSION BAND** (DR-135 §11.134.4), which pushes M6 to `0.7` and M9 to
`0.10`. The version at open is `v0.6.0`: 0 of 43 Chapters `Done`, `PLAN-0` (`#589`) being the Story
that decomposed the epic rather than a Chapter that built anything.

| Clause | Mark | Why |
|---|---|---|
| PDF imported without leaving the app | **DEMONSTRATED** | `apps/rackpal/test/session/plan_import_pdfium_test.dart` imports a vector PDF page through the SHIPPING path on the vendored pdfium (DR-153, `PLAN-K`) and counts the ink in the stored image, so a blank page cannot pass. `floorplan_menu_route_test.dart` (`#943`) drives `File ▸ Import floorplan…` through the real menu bar, the file dialog and the details dialog of the running app and finds the plan in the document with its image as a member: the "without leaving the app" half, which nothing had driven. **Not yet shown on DR-145's actual three-page CAD plot**, which is `PLAN-J/1`'s to find out; a refusal there would be `REFUTED`, and the more useful result. Until 2026-09-24 this cell read `NOT BUILT`, "no import path of any kind", true before `PLAN-D` |
| Calibrated from a known dimension | **DEMONSTRATED** | `packages/rackpal_ui/test/canvas/plan/plan_calibrate_test.dart`, "THE WHOLE GESTURE WRITES A SCALE, AND ONE UNDO TAKES IT": two picks and a united distance write a `PlanScale` whose factor the case reads back (9,144,000 nm per pixel), and one undo removes it. `PLAN-F/1` gave `PlanScale` its writer. Until 2026-09-24 this cell said the pick did not exist |
| Rack and every drop pinned | **UNPERFORMED** | The GESTURE is built and tested (`plan_pin_arm_test.dart`, `plan_canvas_screen_test.dart`), and `PlanPin` rides all three carriers through the codec (`plan_serialization_test.dart`). The clause is a PERSON pinning every drop of a REAL rough-in, which no test is and no agent can do: `PLAN-J/1` (`#647`). The M3-I passthrough never protected a pin, as this cell recorded on 2026-09-07; DR-136's reader stamp closes that from the other end. Was `NOT BUILT` until 2026-09-24 |
| `T1.01` with a callout per pin | **DEMONSTRATED** | `SheetRole.devicePlan` exports (`build_document.dart`); `packages/rackpal_core/test/sheet/plan_sheet_test.dart` places one callout per pin and prints each CARRIER's own designator (DR-150 §11.149.3). The join the clause names, that the same designator "appears on every Pull Sheet row for that drop", was argued and never run until `plan_callout_pull_sheet_test.dart` (`#943`): a rough-in imported from CSV, every outlet pinned, and all six Pull Sheet rows checked to show their callout's string; red when the Pull Sheet cell drops the outlet. Until 2026-09-24 this cell said `SheetRole` had three values |
| The stranger locates every drop | **UNPERFORMED**, parked on M6 by DR-155 | The Pull Sheet does not print: `SheetRole` has no Pull Sheet and `rackpal_export` never references `ScheduleView`, so this clause named an artifact the product cannot produce (DR-155 §11.154). M6 owns it as a clause of its own. The park was ruled on 2026-09-11 and this cell did not say so until 2026-09-24 |
| Greyscale laser at ANSI B | **UNPERFORMED** | A physical print on a real greyscale laser, every callout legible over the screened underlay (AC-054). DR-150 §11.149.4 settled the screening by arithmetic; the paper is `PLAN-J/2` (`#648`). No agent can perform it (docs/13 D11) |
| CR-117 on the zip path | **DEMONSTRATED** | `apps/rackpal/test/storage/document_store_test.dart`, "CR-117 on the zip path, through the store" (`#943`): a project carrying a calibrated, PDF-sourced floorplan is SAVED through `DocumentStore` with a real PNG and its source as members, REOPENED, and saved again from what the reopen produced, twice, and the file on disk is byte-identical each time; the members come back byte for byte; and a project with no underlay writes exactly the plain-JSON bytes and does not sniff as a zip. The halves were proven apart before this, the codec's three steps over JSON (`plan_serialization_test.dart`) and the container's over a hand-written string (`container_determinism_test.dart`), and never composed at the boundary a person uses. **Corroborated by the user**, who reported on 2026-09-24 that they had "checked it and it's been working fine with the project I've been designing": a person saving and reopening real work, recorded as that and not as a byte comparison. Was `NOT BUILT` until 2026-09-24, because the clause is about a document carrying an underlay |

**What the decomposition found by reading the tree rather than the design.** Three things, and none
was inferable from docs/15:

- **`Location.riseAllowance` does not exist**, and DR-020 §11.19.2(1) plus docs/15 §4.1 both spend it
  as though it does. Grep returns zero occurrences in every `.dart` file. DR-037 §11.36.5 adds it.
  **Third instance of this shape**, after `MediaTypeDef.maxLength` (§11.19.7) and `unknown` on
  `Placement` (§11.18.1): a design document and a ruling agreeing with each other reads exactly like
  verification and is not.
- **`PdfImage(..., alpha: true)` writes an `/SMask`.** docs/08 row 9 forbids alpha and was written
  about `ExtGState`; a PNG underlay with an alpha channel would have emitted an alpha path into the
  document **without anybody calling `setGraphicState`**. Read out of `pdf-3.13.0/lib/src/pdf/obj/image.dart`,
  not recalled. DR-037 §11.36.3 puts the flatten in the export backend where it can catch this.
- **`cable_footage.dart:302`'s `_isQuantity` was already waiting for this day.** Its header says the
  switch was left exhaustive with no default arm so that *"the day it is added this file stops
  compiling and somebody decides, rather than a bound silently joining a purchase"*. It is the one
  place in this tree where a future decision was booby-trapped into the build, and it worked.

**Two dependencies are already paid**, which is why this is not worse than `L`: M3-I's `unknown`
passthrough (#568, `Done`) and `archive`/`image`, both **already in the resolved tree transitively
via `pdf`** and both MIT, so the licence census DR-036 ran covers them and no new copyleft question
opens.

**Decomposed 2026-08-10 into 10 issues (#597–#606) and 43 tasks (#607–#649), `PLAN-A`…`PLAN-J`**,
closing #589.
Read it against the tree before starting rather than trusting it, per §1's caveat on every
decomposition: `PLAN-E`'s canvas row rests on the claim that the viewport, selection, hit-test and
drag-preview machinery are reusable, and **that claim has not been tested by anything except a
read**.

#### 5.9.1 PLAN-A, the amendment spent, and a defect ten minutes old · CLOSED · `v0.6.5` · `10dc11e`, `5e11575`

**Closed 2026-09-07** (`#597`, five Chapters `#607`–`#611`, DR-029 §11.28.6). **No exit clause moves**:
this is the root every other issue in the epic consumes, and the criterion is about a printed `T1.01`
that nothing yet builds.

**`draw/canvas.dart`'s amendment clause was spent, once, and the file now says so.** The header
forbids a new method without an amendment; DR-029 §11.28.6 is that amendment, and the note added
beside it records that **the clause is not weakened by having been used**: one method cost a user
ruling, a canon subsection and edits in three documents, and the next one costs the same.

**TWO THINGS DELIBERATELY DID NOT COME WITH IT**, because the obvious reading of *"images"* brings
both. There is **no `opacity` parameter**: an opacity argument is an `/ExtGState` by the shortest
available route and docs/08 row 9 forbids alpha *"absolutely, with no exception"*. And there is **no
fit rule**: `ImageRef.aspectRatio` sits on the handle so a scene builder can choose a destination
that does not stretch the picture (DR-030's rule), rather than have the canvas letterbox silently and
leave the caller unable to say where the ink landed.

**THE OP CARRIES A CONTAINER-MEMBER REFERENCE AND NEVER PIXELS**, which is the property that made the
addition safe. A display list is compared byte for byte (M2-C) and held whole while a sheet set lays
out; a `Uint8List` on the op would put megabytes into the one structure whose purpose is to be cheap
to compare, and would drag a decoder into a package that is Flutter-free by gate. Each backend
declares its own resolver over its own image type, so neither `ui.Image` nor `PdfImage` reaches the
IR.

**5.9.1.1 THE COMPILE-ERROR TRAP FIRED, AND NOT WHERE THE CHAPTER EXPECTED.** `PLAN-A/2` predicted
that *"every exhaustive switch over ops stops compiling until it is handled"*. Measured: **this
repository contains exactly one such switch and it is not in production code**. It is
`test/scene/op_digest.dart`, the determinism instrument, whose own header explains that it is a
switch rather than a `toString()` for precisely this reason. So the compiler required a decision
about what an image contributes to *"same document, same display list"* before anything could build.
**It contributes its reference and its rect**: two scenes naming the same member at the same rect ARE
the same drawing instruction, and whether the bytes behind that member moved is CR-117's question
rather than this instrument's. Three test canvases also needed the method; **nothing in `lib/` did**,
because `replay` is virtual dispatch.

**5.9.1.2 A MIRRORED FLOORPLAN HAS A CORRECT BOUNDING BOX**, which is why both backend tests read
corners rather than rects. A PDF image XObject occupies the unit square with its **top** row at
`v = 1`, and `PdfDiagramCanvas` carries one global Y-flip (CR-085), so the naive call lands the
picture upside down **inside exactly the right box** and every dimensional assertion still passes.
The counter-flip follows `drawText`'s own idiom. The content-stream harness learned to record `Do`
with the CTM in force, so the assertion is about where the ink lands on the paper.

**BOTH ORIENTATION SUITES WERE MUTATION-TESTED RATHER THAN TRUSTED.** Delete the PDF counter-flip and
**three of four** orientation cases fail; flip the Flutter destination rect and **five of five** fail.
The harness gained its own cases too, one of which feeds it an upright and a flipped placement with
**identical boxes** and asserts it can tell them apart.

**5.9.1.3 THE TEST FOUND A DEFECT WRITTEN TEN MINUTES EARLIER, AND THE SHAPE IS WORTH KEEPING.**
`BoundsCanvas.drawImage` was written `_ink(_toRoot(dst))`. `_ink` already maps through the CTM, so
every underlay would have inked at **twice its own translation**. No sibling method makes that
mistake, so no assertion about a rect could have caught it, and a bounds pass that is wrong in the
loose direction does not crash: it makes every sheet containing a plan scale to fit a box half again
too big. `image_op_test.dart`'s translated case caught it on its first run, which is the argument for
writing the transform case at all rather than only the identity one.

**5.9.1.4 PLAN-A/4 IS ANSWERED WITHOUT A REGENERATION, AND THAT IS THE RESULT.** The op-count
baselines in `schematic_perf_test.dart` are M2-C's record, and the chapter said in its own words that
a moved number *"is a finding and not a rebase"*. **None moved.** No scene emits an `OpImage` until
`PLAN-C`, so the sealed hierarchy grew and the counts did not. Recorded as a result rather than as an
absence, on §5.1's `#587` precedent.

**5.9.1.5 PAL-1's EXCLUSION WAS AN ABSENCE AND IS NOW A CHECK.** `tools/pal1_check.py` enumerates
`FAMILIES`, a hand-written list, so the underlay was outside PAL-1 **because nobody had added it**,
which reads identically to an oversight. `NOT_A_SIGNAL_FAMILY` now names it and DR-030's logo with
the reason, `check_exclusions()` **fails the gate if an excluded id ever appears in `FAMILIES`**
(verified by adding one in a throwaway process: exit 1), and the exclusion is **printed on every
run**, because a check nobody can see declining to check something is indistinguishable from one that
checked it and passed. **The obligation the exclusion does not cover is named in the same place**:
every PAL-1 pair to date is drawn on white, docs/15 §7 requires callout glyphs to stay separable
against a **non-white** background, and that is `PLAN-H/3`'s to check against a rendered sheet.

**5.9.1.6 THE VERSION IS `v0.6.5`, DERIVED THE TWO WAYS §14.0 REQUIRES.** The board query for `Done`
Chapters under epic 588 returns **5**; and `v0.6.0` at the band's open plus the five Chapters closed
here is 5. Floors re-measured in the same commit: core 4093 to 4109, export 195 to 209, ui 1532 to
1539.

**5.9.1.7 WHAT PLAN-A DID NOT TOUCH, AGAINST THE FIVE FILES DOCS/15 §7 PREDICTED IT WOULD.**
`canvas.dart`, `ops.dart`, the bounds canvas and both backends: as predicted. **Hit-test: nothing.**
`hit_test.dart` reads `DiagramScene.hits`, which scene builders populate, and an op type reaches it
by no path at all. **The op-count baselines: nothing**, per §5.9.1.4. So of the six things a design
document listed, two were wrong, and the one file that did break was on nobody's list. docs/15 §7 is
corrected in place rather than pointered.

#### 5.9.2 PLAN-B, the container, and three facts about zip that reading would not have given · CLOSED · `v0.6.10` · `6902404`

**Closed 2026-09-07** (`#598`, five Chapters `#612`-`#616`, DR-019 §11.18.2). **No exit clause moves**:
the `CR-117 on the zip path` clause names *"a write, a reopen and a second write"* over a document
carrying an underlay, and `PlanUnderlay` does not exist until `PLAN-C`. What ships is the envelope
that clause will be measured through, gated on its own terms.

**5.9.2.1 IT IS AN ENVELOPE AND NOT A SECOND CODEC, WHICH IS A CENSUS OVERRULING TWO DOCUMENTS.**
`codec.dart`'s header has said since M0 that *"`JsonDocumentCodec` is the only implementation in
M0"*, and `#613` was written to end that sentence. Censused before building it: **`DocumentCodec.read`
has exactly two callers in the tree and neither is the app's open path.** `DocumentStore` reads
through a `Deserializer` and writes through `encodeToJsonTree` plus a serializer, deliberately, for
the two-phase snapshot split `serialization.dart` spends forty lines justifying. **A container behind
`DocumentCodec` would have been unreachable from the one gesture that opens a project**, which is
this repository's most-found defect wearing a seam that already existed. So `container.dart` splits
BYTES into the document JSON plus its members and hands the JSON half to the pipeline that is already
there, and DR-019's *"one encoder serves both"* falls out rather than being maintained by hand.

**5.9.2.2 THE FOUR NONDETERMINISM SOURCES ARE THREE PLUS ONE.** DR-019 §11.18.2(2) names entry order,
timestamps, compression level and extra fields. Measured against `archive 4.0.9`: the first three are
real and are fixed. **Extra fields are already absent**, so that one is not fixed but **guarded** by a
test asserting zero, and a dependency bump that starts emitting a UT or Zip64 field fails the build
instead of quietly breaking the round trip. **The level default is `bestSpeed`** and differs from both
6 and 9, so *leave it alone* was itself a choice a dependency could change underneath.

**5.9.2.3 THE TWO-SECOND TRAP, WHICH THIS WORK FELL INTO AND CAUGHT.** The MS-DOS time field a zip
stores has **two-second granularity**. The first measurement of the wall-clock source used a 1.1
second gap, reported *deterministic*, and was wrong: both calls had landed in the same bucket. **Any
test of this that waits under two seconds asserts nothing.** The one that does is slower than its
neighbours and says why, which is the only reason the next person will not shorten it.

**5.9.2.4 A ZIP IS A DECOMPRESSION-BOMB SURFACE AND THE HARDENING CENSUS CAUGHT IT ON THE FIRST RUN.**
`import_hardening_test.dart` failed the moment `container.dart` appeared, for the **fourth** time and
the first where the hazard was not JSON depth but the **inflate**: `checkJsonLimits` runs on
`document.json`, which only exists after unzipping, so **a one-megabyte file declaring ten gigabytes
would have exhausted memory before any existing cap fired**. DR-015 §11.15.4 avoided needing this
bound by choosing a single JSON file for `.rmda`, *"because the zip buys only a decompression-bomb
surface"*; DR-019 buys that surface deliberately, so this is the bill. `readContainerParts` checks the
central directory against `ContainerLimits` **before inflating**, then keeps a running total over what
actually came out, **because a header can lie**, and the residual is written down rather than implied.

**5.9.2.5 A TRUNCATED ZIP DOES NOT THROW, AND THAT MEASUREMENT IS THE DIFFERENCE BETWEEN THIS AND A
SHIPPED SHELL.** `ZipDecoder` reads the central directory, which lives at the **end** of the file, so a
truncated archive simply has none: **it returns an EMPTY archive and throws nothing.** Cut at 10, 25,
50, 75, 90 and 99 percent, all six decoded *successfully* with zero entries, as did a file that was
only the four signature bytes. **Written from the assumption instead**, `ContainerUnreadableError`
would have been the exception arm, nothing would ever have reached it, and **every truncated project
would have reported "this is not a RackPal project" and been refused the `.bak` that would have
rescued it.** Zero entries is therefore the damage signature, and the exception arm is documented as
the belt-and-braces one it turned out to be.

**5.9.2.6 `OpenZipContainer` CHANGED MEANING, AND ITS COPY WAS A LIE THE MOMENT THIS SHIPPED.** It read
*"RackPal projects are plain JSON. If the project is inside the archive, extract it first and open the
`.rmpj` file."* **That advice now destroys a project**: a project with a floorplan IS a zip archive,
and extracting it yields a `document.json` with the underlay left behind. The state survives as the
**foreign-archive** case and names what the archive held; `OpenContainerUnreadable` and
`OpenContainerTooLarge` join it, and only the damaged one offers a backup. **A test asserting the
error TYPE would have left that sentence standing**, which is why the tests assert the words
(`print the output before claiming copy is done`).

**5.9.2.7 THE PASSTHROUGH IS §11.18.2(5)'s ARGUMENT ONE LAYER OUT, AND IT WAS NOT IN ANY CHAPTER.**
DR-019 gave `Placement` and `Outlet` an `unknown` map so a build predating a field does not silently
drop it on save. **A container member is the same hazard with bigger stakes**, and none of `#612`-`#616`
asked for it: without it, opening a project that carries a floorplan and pressing Ctrl+S writes plain
JSON and **deletes the architect's page**, with nothing on screen suggesting anything happened. So
members ride from `OpenedDocument` through `DocumentSession` to `DocumentStore.save` untouched, and
this build preserves members it has no model for. `PlanUnderlay` gives them meaning at `PLAN-C`.

**5.9.2.8 BYTE IDENTITY IS PROVEN OVER THE CORPUS, AND THE NO-MEMBER WRITE IS AN IDENTITY.**
`writeContainerBytes` **returns its input object unchanged** when there are no members, so there is no
second encoder that could drift from the first, and `identical()` says so rather than `==`. Asserted
over the four checked-in starters rather than a fixture, together with the negative `#615` asked for:
nothing writes a zip unless a member exists, and the boundary is the member COUNT rather than its
size, because a zero-byte underlay is a corrupt import rather than an absent one.

**5.9.2.9 THE VERSION IS `v0.6.10`.** The board query for `Done` Chapters under epic 588 returns
**10**; and `v0.6.5` plus this issue's five Chapters is 10. Floors re-measured: core 4109 to 4144, app
916 to 930.

#### 5.9.3 PLAN-C, the plan model, and a protection DR-019 bought that could never have worked · CLOSED · `v0.6.16` · `da8087e`, `e620e68`

**Closed 2026-09-07** (`#599`, six Chapters `#617`–`#622`, DR-037, and **DR-136 §11.135**, which this
issue produced). **No exit clause moves**, and one becomes measurable: `CR-117 on the zip path` is
about a document *carrying* an underlay across a write, a reopen and a second write, and there is now
a document that can carry one. The clause still needs `PLAN-D`'s import to make one the ordinary way.

**BOTH OF THIS ISSUE'S FINDINGS WERE RE-MEASURED BEFORE BUILDING AND BOTH HELD.**
`Location.riseAllowance`: **zero occurrences** across every `.dart` file, while DR-020 §11.19.2(1)
and docs/15 §4.1 both spend it as though it ships. The plan model: four mentions in the tree, all of
them comments PLAN-A and PLAN-B had written about a thing that did not exist.

**5.9.3.1 THE TEST `#621` ASKED FOR CANNOT BE WRITTEN, AND THAT IS THE MILESTONE'S REAL FINDING.**
Its brief: *"The plan pin is the first field that map exists to protect, so write the test that proves
it: a document with pins, read by a codec that does not know the key, written back, still carrying
them."* **It does not carry them.** `Placement.unknown` is a **reserved container and not a
harvester**: it preserves what a writer deliberately put inside it and collects no unrecognised
sibling keys. `placement.dart` says so in capitals and names the ruling a harvester would need;
`_unknownBag` repeats it. `planPin` is a sibling key like any other.

**SO DR-019 §11.18.1's HAZARD WAS NEVER CLOSED.** That paragraph described it exactly, *"a build that
predates the Plan view, opening a file that has plan pins, silently drops them on save"*, and
§11.18.2(5) bought the bag as the remedy. M3-I built the bag correctly. **The remedy simply does not
reach the hazard**, and nothing noticed for a month because the field it protected did not exist.
**This is `two documents agreeing is not verification` in its costliest form**: the ruling and the
implementation agreed with each other, and neither agreed with the hazard.

**5.9.3.2 THE USER CHOSE TO REFUSE THE WRITE RATHER THAN PRESERVE THE FIELD** (DR-136 §11.135.2). A
document carrying an underlay or a pin stamps `minReaderVersion` **5**, so a build that cannot model a
pin opens it **read-only** and never gets to write the version that lost it. The narrower fix, and it
leaves harvesting exactly where `placement.dart` left it. **The costs are named in the ruling rather
than discovered**: every re-saved document reads read-only on an older build, and a project becomes
unsaveable there the moment somebody drops one pin.

**5.9.3.3 THE SCHEMA MOVES TO 5 FOR A REASON THIS FORMAT'S TRIGGER DID NOT HAVE.** That trigger, stated
twice in `json_codec.dart`, asks whether existing files stop re-encoding byte for byte. **These
additions are byte-invisible.** The advance is owed because `minReaderVersion` became conditional and
**the stamp needs a number**: a conditional 5 written by a build declaring 4 would make this build
refuse its own file.

**AND THE BYTE-INVISIBILITY IS MEASURED RATHER THAN CLAIMED.** Regenerating the four starters and the
five byte-roundtrip fixtures moves **exactly one line each**, `schemaVersion 4 -> 5`, and nothing
else. That only holds because **the `underlays` map is OMITTED WHEN EMPTY, unlike its fourteen
siblings**: writing `"underlays": {}` would have added a key to every `.rmpj` in existence and made
the ruling false in the commit that stated it. It is also what CR-114 says, and what this codec chose
twice recently (DR-105's 727 origins, DR-134's 737 empty arrays).

**5.9.3.4 `PxPt` IS ENFORCED RATHER THAN AGREED.** The three-point-types decision is only worth its
cost if the type system holds it, so there is no arithmetic, no conversion, no supertype, and no
mention of `Pt` or `DPt` in the file's code at all. `px_pt_separation_test.dart` is a **source** gate
as well as a behavioural one, on `draw_source_gate_test.dart`'s precedent: the changes that reopen the
hole are one-liners that look like tidying, and a running program cannot tell a collapsed type from a
separate one. What it costs is specific: a `Pt` accepted where a `PxPt` was meant does not throw, it
rounds the pin to the 2.5 mm lattice and moves the dot, and the person who finds out is an installer
looking for the wrong wall.

**5.9.3.5 THE EPOCH MASKS ARE TESTED AGAINST A LISTENER, INCLUDING THE NEGATIVES.** `#622` asked for
this and named the scar: DR-011.4's first implementation silently did nothing because a `meta` bump
advanced the scene epoch past the stamp the `wires` listener had just written, and an
`expect(cmd.touches, ...)` assertion would have been green throughout. A pin wakes
`structure | wires` because it feeds `planLowerBound`, which feeds a schedule row, which feeds a
sheet. **Pinning a rack must NOT wake `EpochMask.rack`**, which means heightU, rails and depth, and
that negative is what stops a mask that wakes everything from passing every positive.

**5.9.3.6 REMOVING AN UNDERLAY CASCADES, ON DR-021's REASONING RATHER THAN A NEW ONE.** A pin names
its underlay, so leaving the pins would leave every one of them pointing at nothing, which is the
dangling reference DR-021 §11.20 refuses for a `Location` subtree. The undo puts back the plan **and
the dots on it**, and a pin on a different plan is left alone, which is the discrimination a
clear-everything implementation gets wrong.

**5.9.3.7 THREE CENSUS GATES FIRED AND ALL THREE WERE RIGHT.**
`set_entity_property_command_test.dart` refused two new `@internal` setters with no table row:
`riseAllowance` gets one, masked `structure | wires` for `estimatedRunLengthFromRack`'s reason, and
**`Outlet.planPin` is kept out** on `parentId`'s exemption, because a row's `set` writes and returns
with no way to refuse a pin naming an underlay that does not exist. `location_commands_test.dart` then
refused the new row for having no byte round-trip case, which is CR-117 per table row rather than per
command.

**5.9.3.8 A STALE LITERAL FELL OUT, AND IT IS THIS REPOSITORY'S OWN LESSON.**
`migration_corpus_test.dart` asserted `doc.schemaVersion == 4` beside `== kSchemaVersion`. Right when
written, wrong nine days later: that case is about a v3 file reaching **current**, not about reaching
4, so the literal was a second copy of a moving number and failed while nothing it guarded had
changed. `units_test.dart` keeps ITS literal, because there the whole point is that a bump must be a
deliberate edit with a sentence attached.

**5.9.3.9 THE VERSION IS `v0.6.16`.** The board query for `Done` Chapters under epic 588 returns
**16**; and `v0.6.10` plus this issue's six Chapters is 16. Floors re-measured: core 4152 to 4203.

#### 5.9.4 PLAN-D, three chapters of five, and the two that need a real architectural page · PARTIAL · `v0.6.19` · `9ea401b`, `f71265d`

**`PLAN-D/1`, `/2` and `/4` closed 2026-09-07.** `PLAN-D/3` (PDF rasterisation and the page picker)
and `PLAN-D/5` (what a plan costs a `.rmpj`) are **open and blocked**, and the block is named below
rather than left to be inferred. `#600` stays `Doing`.

**5.9.4.1 THE RASTERISER IS DECIDED: PDFIUM, NOT `Windows.Data.Pdf`.** DR-037 §11.36.8 ruled this a
decision needing the tree read rather than a user, and the tree supplies both halves. **The cost is
already committed**: docs/13 D9 contemplates vendoring pdfium per platform (CR-100) for M8's preview
button, so choosing it here makes the two **one vendoring problem paid once** and moves D9's schedule
earlier rather than adding a second debt. And `Windows.Data.Pdf` **has no macOS answer at all**, which
DR-009 makes a v1 problem rather than a later one.

**THE GRAIN IT RUNS AGAINST IS IN THE RECORD RATHER THAN DISCOVERED AT M8.** This project removed
`file_selector` and the `path_provider` umbrella because they dragged `dartjni.dll` into a Windows
Release build, and `flutter_dependency_test.dart` fails the build if it returns. A multi-megabyte
unsigned native binary in a self-signed portable distribution (DR-006) is the same shape of problem,
and CR-100's answer is the same one docs/03 already applies to `printing`: **vendor the binary, never
fetch it at build time**. **Two things are UNVERIFIED and are said to be**: the Dart wrapper's licence
(PDFium itself is BSD-3-Clause and clean under DR-036; the package around it is a separate question),
and whether its build fetches pdfium or accepts a vendored one. docs/03 §10.1 therefore carries
`pdfrx` as `planned`, and `PLAN-D/3` establishes both before it goes `in use`.

**5.9.4.2 TWO CHAPTERS PULLED AGAINST EACH OTHER AND THE RESOLUTION IS THE DESIGN.** `#624` says the
decode happens in the app layer and only the dimensions cross into core. `#626` says the third
control is a **pixel-dimension cap**, and names the failure it exists for: *a three-kilobyte PNG can
declare 60000 x 60000 and the decode allocates before anything has a chance to object.* A cap in the
app layer **after** the decode runs after the allocation it prevents, which is `checkImportSize`'s own
words one format over: *"a cap that only fires after the allocation it was meant to prevent is
decoration."*

**So the CHECK moved to core and the DECODE did not.** `persistence/image_header.dart` is a header
parser and not a decoder: it decompresses no pixel, allocates nothing proportional to the image and
touches no `dart:ui`. Core stays decoder-free (docs/15 §3.1), and the cap gets to run first.

**5.9.4.3 THE ORDER IS WHAT THE TESTS ARE ABOUT.** Stat before reading; sniff by **content**, because
a dialog filter is a courtesy and *All files* is one click away; read the header and refuse on the
**declared** size; only then decode. Every refusal in `plan_import_test.dart` could also be produced
by a slower, wronger implementation that decoded first, so the cases use inputs a correct order
survives and an incorrect one does not. **And the decode re-checks what the header claimed**, because
the header is a claim BY THE FILE and one that understated itself would slip a cap that trusted it.

**5.9.4.4 THE FLATTEN STAYED WHEN THE SCREENING MOVED.** `#624` is right that these are two
obligations: the screening percentage belongs in the export backend where it can change without
re-importing every underlay a user owns (DR-037 §11.36.3), and an alpha channel in the **stored** bytes
is a hazard either way, because `PdfImage(..., alpha: true)` emits an `/SMask` and docs/08 row 9
forbids alpha absolutely. Composited over **white**, because that is what paper is; the other
plausible default turns an ordinary architectural export into a dark sheet with white lines. An
opaque image is **not** re-encoded: the container holds what the architect sent.

**5.9.4.5 A PDF IS REFUSED BY NAME AND NOT AS AN UNSUPPORTED FORMAT.** DR-029 bought PDF import
deliberately, so *"that is not a supported format"* would tell somebody the product decided something
it has not, and would send them to convert the file by hand in the belief that they must.
`PdfImportNotAvailableError` says *not yet* and names the chapter.

**5.9.4.6 WHAT BLOCKS THE REMAINING TWO, STATED SO IT IS NOT MISTAKEN FOR SLIPPAGE.** `PLAN-D/3` and
`PLAN-D/5` both demand a **real architectural page** in their own words, and `#627` says why in terms
this board should recognise: docs/15 §2 rejected base64 on an ESTIMATE (*"a 2 MB PNG becomes roughly
2.7 MB of inline text"*) and *"the zip path's real number has never been taken"*. `PLAN-D/3`'s
resolution is a three-way trade between legibility at working zoom, AC-006's file-size budget and the
asymmetric PDF cost PLAN-A/3 measured, and `#625` says in capitals that it *"settles it with a
measurement, not a preference"*. **A synthetic fixture would settle it with a preference wearing a
number**, which is `a stated cost is a hypothesis` arriving one chapter early. So both wait on a real
page, and `PLAN-D/3` additionally waits on the pdfium vendoring being executed rather than decided.

**5.9.4.7 THE VERSION IS `v0.6.19`.** The board query for `Done` Chapters under epic 588 returns
**19**; and `v0.6.16` plus this issue's three closed Chapters is 19. Floors re-measured: core 4203 to
4230, app 930 to 945.

#### 5.9.5 The plan set arrived, and it answered PLAN-D/5 and half of PLAN-D/3 · `DR-137` · `v0.6.20`

**The block named in §5.9.4.6 lifted on 2026-09-07.** The user supplied an 18-sheet residential
permit set, ARCH D (36 x 24 inches), and described it as representative of what this trade is
usually given. **It is not in the repository and never will be** (DR-137 §11.136.6): it carries a
licensed engineer's seal and licence number, the firm's name, the builder's mark and a redaction
that covers the address and nothing else, and DR-036's public GPLv3 release would publish every
commit ever made. `.gitignore` refuses `docs/reference/*.pdf` at the top level only, which leaves
`keystone/`'s seven manufacturer drawings tracked.

**5.9.5.1 THE METHOD, SO THE NUMBERS SURVIVE WITHOUT THE FIXTURE.** This is the whole reason the
measurements are written out rather than left in a test. Anybody with their own plan set can
re-derive every figure below:

1. **Structure**, without any PDF library: count `/Type /Page`, `/Subtype /Image` and the filter
   names by regex over the raw bytes, and read `/MediaBox` for the sheet size. Read each image
   XObject's `/Width`, `/Height` and `/Length`.
2. **Carve the pages**: a `DCTDecode` stream with no other filter *is* a JPEG file. Slice from
   after `stream` to `/Length` bytes and check for `FF D8`.
3. **Deflate ratios**: `zlib.compress(page_bytes, level)` per page, timed best-of-N.
4. **Container cost**: `writeContainerBytes(starterBytes, {member: pageBytes})` against a
   checked-in starter, which is in the repository and is not going anywhere.
5. **Legibility**: crop the plan region at 1:1 and *look at it*. There is no substitute and there
   was never going to be one.

**5.9.5.2 WHAT THE SET ACTUALLY IS, AND IT IS NOT WHAT ANYBODY ASSUMED.** Every page is a **single
full-page JPEG**. Eighteen pages, eighteen images, eighteen `DCTDecode` filters, **zero fonts and
zero vector content in the entire file**, 99.9% of the bytes are the images. Each page is
2160 x 1440 px on a 36 x 24 inch sheet, which is **60 dpi**.

**So the office flattened it.** The linework is clean and unskewed, so this is a raster export of a
vector drawing rather than a scan, and somebody's export preset chose 60 dpi. **That is the input
this product receives**, and it is a fact about a workflow rather than about a file format.

**5.9.5.3 PLAN-D/3's RESOLUTION QUESTION IS ANSWERED AND ITS BUILD IS NOT.** `#625` frames the
resolution as a three-way trade. For a raster-backed PDF **there is no trade**, because
rasterising above the source upsamples: 96 dpi costs 1.8x the bytes, 150 dpi 4.0x, 300 dpi
**12.9x**, and every one of them gains **zero** information. The rule is *never rasterise above the
source's own effective resolution*, and for a vector PDF `#625`'s trade is real and stands.

**AND 60 DPI IS ENOUGH, WHICH WAS SETTLED BY LOOKING.** At 1:1 on A-2.1 the room names, the
dimension strings (`15'-8 1/2"`), the window callouts (`3052`), the stair counts (`Up 16R`) and the
annotations (`Pocket Office`, `Drop Zone`, `Bench Coat Hooks`) are all legible. At 1/4 inch = 1
foot, 60 dpi is **15 px per foot**, so **one pixel is 0.8 real inches**. An installer needs the
wall, not the inch.

**`#625` STAYS OPEN** for what it still owes: pdfium vendored, the licence and build behaviour of
the Dart wrapper established, and the page picker built. **A shortcut is visible and is
deliberately not taken**: because every page here is one full-page image, the JPEG could be
extracted without rasterising, losslessly. A vector PDF breaks it and DR-029 bought PDF import
generally, so it is at most an optimisation with pdfium behind it.

**5.9.5.4 PLAN-D/5 IS ANSWERED, AND THE ANSWER INVERTS docs/15 §2.** That section rejected base64
on an estimate (*"a 2 MB PNG becomes roughly 2.7 MB of inline text"*, a 35% inflation) and admitted
*"the zip path's real number has never been taken"*.

| | Bytes |
|---|---|
| `whole_house.rmpj` today, plain JSON | 745,646 |
| the same document plus A-2.1 as an underlay, as a container | **234,165** |
| all 18 sheets as underlays | 8,235,004 |

**A plan makes the project file 69% SMALLER than it was without one.** The underlay flips the
format from plain JSON to a container, and the JSON then deflates **16.3x** (745,646 to 45,734).
AC-006 re-justified plain JSON against a corrected ~600 KB figure; `whole_house` misses that today
at 728 KB and lands far under it the moment a plan is added, which is the opposite of the direction
the budget was braced for.

**THE FIGURES ABOVE WERE FIRST TAKEN UNDER STORE AND RE-TAKEN UNDER DR-137**, because a number
measured under the behaviour you are about to change is a number about the past. Under STORE the
same two rows read 331,776 and 9,769,984, so the ruling is worth **97,611 bytes on the sheet a user
imports** and **1,534,980 across the set**. CR-117 was re-checked on the real member rather than on
a fixture, and holds.

**5.9.5.5 AND THE MEASUREMENT CONTRADICTED THE CODE, WHICH IS WHY IT WAS WORTH TAKING.** PLAN-B's
`container.dart` stored binary members uncompressed behind four confident sentences. Two are false:
every page deflates (7.0% to 34.3%, mean **16.0%**), **the floor plans deflate best** at 34.3%
because line art on white is mostly white, and level 9 costs **6.2 ms** on the sheet a user
actually imports. A third reason argued for nothing, since every zip tool inflates a deflated
entry. DR-137 changes it.

**THE GENERALISATION IS THE ONE TO KEEP.** *"Already-compressed rasters do not deflate"* is true of
**photographs** and false of **line art on white**, and this product receives line art on white. The
rule was imported from the domain where it holds into the domain where it does not, and read as
self-evident in both. Compare `a stated cost is a hypothesis`: this was not a number nobody ran, it
was a **domain assumption nobody noticed making**.

**5.9.5.6 THE SAMPLE IS ONE AND IS SAID TO BE.** The duration note in CLAUDE.md has been wrong
twice in opposite directions from single samples, so: n=1, the user reports it representative, and
that is trade knowledge rather than a census. **Nothing here depends on the generalisation
holding.** Deflate is safe on a member that will not compress, since it simply does not; the
resolution rule is expressed as a bound (never exceed the source) rather than as a number; and the
container-size finding is a property of the format, not of this file.

#### 5.9.6 PLAN-D/3: the rasteriser refused the tree, so the page is lifted instead · `DR-138` · `v0.6.21`

**5.9.6.1 PLAN-D/1'S CHOICE DID NOT SURVIVE ITS OWN UNVERIFIED LIST.** That chapter picked pdfium via
`pdfrx` and recorded two unknowns (§5.9.4.1): the Dart wrapper's licence, and whether its build
fetches pdfium or takes a vendored one. **The licence came back clean and the build did not.**

| | |
|---|---|
| Licence | `pdfrx`, `pdfrx_engine`, `pdfium_dart`, `pdfium_flutter`: **all MIT**, clean under DR-036 |
| pdfium | **Downloaded at build time on every route.** 2.3.0+ via Dart native assets from `bblanchon/pdfium-binaries`; earlier via a CMake download, the mechanism docs/03 already records for `printing` |
| CR-100 | *"vendored into the repo rather than downloaded at build time (a network-fetched binary in a signed release is a supply-chain and reproducibility problem, not just a CI problem)"* |
| Flutter | `pdfrx` 2.x needs **3.47 / Dart 3.13**; this repo is pinned at **3.44.4 / 3.12.2**, and the pin is a gate |

**THE PACKAGE CHOSEN TO MAKE VENDORING "ONE PROBLEM PAID ONCE" CANNOT ACCEPT A VENDORED BINARY.**
Either refusal alone ends it, and the pin bump would not have helped: CR-100 is about where the
binary comes from, not which Flutter builds it.

**5.9.6.2 THE SHORTCUT DR-137 DECLINED IS NOW THE ROUTE, BECAUSE THE FALLBACK GOT PRICED.** DR-137
§11.136.7 saw that every page is one full-page image and called lifting *"at most an optimisation
with a fallback behind it"*. The fallback has since been priced at **a ruling amendment, a pin bump
and a vendored binary**, which is what a shortcut has to be measured against rather than against
zero.

**AND LIFTING IS NOT THE CHEAPER OPTION, IT IS THE BETTER ONE.** Rasterising a page whose only
content is a JPEG decodes that JPEG and re-encodes the result: it loses a generation and cannot gain
a pixel, which §5.9.5.3 already settled. On this input class **the pure-Dart path is the outcome
pdfium would be used to approximate.**

**5.9.6.3 THE DETECTION IS A PARSE.** All 18 pages normalise to one content stream, `q BT N N Td ET
Q q N N N N N N cm /imgN Do Q`. Five rules, all of which must hold: one XObject in `/Resources`; it
is `/Subtype /Image` with `/Filter /DCTDecode`; exactly one `Do` naming it; **no text-showing or
path-painting operator anywhere**; and the `cm` covering at least 90% of the MediaBox.

**RULE 4 IS THE ONE THAT EARNS ITS KEEP AND IT HAS A TEST PER OPERATOR.** Rules 1 to 3 all hold on a
page that ALSO carries a `VOID` stamp, a revision cloud or a redaction box, and a lifter that
dropped those would hand an installer a superseded drawing with nothing downstream able to detect
it. **That asymmetry is why most of the test file is refusals**: a wrong refusal costs one export
from a PDF viewer, a wrong acceptance costs somebody a wall.

The 90% tolerance is measured rather than chosen: the real set places a 2484 pt image on a 2592 pt
sheet, **95.8%**, so a rule demanding exact coverage would refuse every page of the only real file
this project has.

**5.9.6.4 THE REAL FILE CAUGHT THE ONE DEFECT, BEFORE ANY TEST EXISTED.** The lifter was run against
the plan set before a line of test was written, and refused **all 18 pages** with *"has an unreadable
image object"* while the parser was working perfectly. `_body()` read an object from `obj` to
`endobj` inside a 64 KB bound; an image XObject is a dictionary followed by hundreds of kilobytes of
JPEG, so it found neither terminator and returned null. Nothing wants a stream body as text, so
`stream` is a correct terminator and a much nearer one.

**THE FAILURE MODE IS THE LESSON.** A parser bug presented as a *content* refusal, in the one shape
where the refusal is plausible and would have been believed. A synthetic fixture would not have
found it, because a fixture small enough to write by hand has its `endobj` inside the bound.
**After the fix: 18 of 18 lifted, byte counts matching an independent Python carve exactly (727,776 /
311,460 / 286,197), 60.0 dpi computed against a 2592 x 1728 pt sheet.**

**5.9.6.5 THE FIXTURES ARE SYNTHETIC AND ASSEMBLED BY HAND**, since the plan set stays out of git
(§5.9.5 and DR-137 §11.136.6). Hand-assembled rather than produced by a PDF writer: the lifter's
whole job is reading files it did not write, and a fixture built by a writer that agrees with it
would prove nothing about a stranger's.

**5.9.6.6 OBJECT ACCESS IS BY SCAN, DELIBERATELY.** A classic xref table is the correct way to read
a PDF and the scan is **strictly more robust for the one question being asked**: it survives a wrong
offset, a stale xref after an incremental update and a damaged trailer, all ordinary in files that
have been through three offices. Its real weakness is not offsets but **object streams**, where no
scan will find the objects, and that case is detected and refused **by its own name** rather than
guessed at, because *"this PDF hides its objects"* and *"this page has vector content"* are
different sentences with different remedies.

**5.9.6.7 THE PICKER, AND THE TWO READINGS THE RULING ADMITTED.** DR-037 §11.36.2 says *"one click,
one page, one underlay"*, which admits click-to-import and click-to-select. **Put to the user, who
chose click-to-import**: the safety argument is undo, not a prompt, because removing an underlay is
an ordinary command and a confirmation whose consequence is one undo away is the nag that teaches
people to click through prompts.

**A PDF WITH NO LIFTABLE PAGE DOES NOT OPEN THE PICKER**, also the user's call: a grid where every
tile is disabled reads as a broken dialog rather than an unsupported file. It gets
`PdfHasNoLiftablePageError`, which is **separate from `PdfImportNotAvailableError` because the two
say different things** and only one is true. Telling somebody PDF import is unavailable, about a
file this product just parsed eighteen pages of, would be false.

**5.9.6.8 A LIFTED PAGE IS NOT PRIVILEGED.** It re-enters `importFloorplanBytes` like any picked
file, so every control PLAN-D/4 built runs on it: the content sniff, the declared-size caps before
any decode, the decoded-versus-declared re-check and the alpha flatten. **Exempting it because "we
produced it" would be exempting it because we trusted the stranger who sent the PDF**, and there is
a test asserting the pixel cap still fires on the lifted path.

**5.9.6.9 WHAT IS STILL OWED, AND IT IS SMALLER THAN IT WAS.** `PLAN-D/3` closes on its own brief:
the page picker is built and the resolution is settled. **pdfium is not cancelled, only deferred**,
and CR-100's vendoring problem is waiting unchanged for the first PDF that needs a real renderer,
at a price DR-138 does not change. **n is one.** A vector PDF from a different office's export
preset falls through to a refusal and reinstates the manual conversion step for that file, which is
the step DR-029 spent 2 to 3 weeks buying out. That cost is stated rather than hidden, and the
refusal path exists because the sample may be unrepresentative.

#### 5.9.7 PLAN-E/1: the reuse claim, tested at last, and the piece nobody counted · `DR-029` · `v0.6.22`

**Closed 2026-09-08** (`#628`, `PLAN-E`'s first Chapter). **No exit clause moves.** This chapter
builds no product surface by design: it exists to price the rest of `PLAN-E` before the rest of
`PLAN-E` is scheduled, which is the one thing §1's caveat on every decomposition asks for and the
thing that decomposition itself flagged (§5.9's own closing line: the canvas row *"rests on the claim
that the viewport, selection, hit-test and drag-preview machinery are reusable, and that claim has
not been tested by anything except a read"*).

**5.9.7.1 THE CLAIM HOLDS, AND THE ONE PIECE IT NAMED AS A RISK IS NOT THE ONE THAT COSTS.** The
feasibility study named five pieces. Four reuse verbatim, the fifth does not apply at all, and the
two that cost real work were **on nobody's list**.

| Piece | The study said | Measured |
|---|---|---|
| Viewport | already exists | **FREE, verbatim.** `ViewportController` has no rack or schematic term in it and its own header already claimed *"any future editor can reuse"*. The spike pans, zooms about a pivot and maps screen to scene without touching it |
| Selection | already exists | **FREE, verbatim.** `SelectionController` is a `Set<Uuid>` plus a focus. A `PlanPin` has no id of its own (it hangs off a `Placement`, an `Outlet` or a `Rack`), so a plan's selection IS its carrier's selection, which is the shape already stored |
| Hit-test | already exists | **FREE, verbatim.** `hitTest` is pure, lives in core, ranks by nearest, and takes a `List<HitRegion>` |
| Drag preview | already exists | **DOES NOT APPLY, AND THAT IS THE GOOD NEWS.** See §5.9.7.3 |
| Command machinery | already exists | **FREE.** `Command<A>` was made generic at M4-A, and `SetPlanPinCommand` already ships from PLAN-C with its epoch mask, its move-versus-set label and its refusal of a pin naming an absent underlay |
| The render object | **not named** | **A THIRD COPY.** See §5.9.7.4 |
| The image resolver | **not named** | **A TYPEDEF WITH NO IMPLEMENTATION.** See §5.9.7.6 |
| A plan scene builder | **not named** | **ABSENT.** Nothing in this repository emits an `OpImage` outside two test files |

**5.9.7.2 THE SPIKE IS SIX CASES AND IT IS CHECKED IN**, at
`packages/rackpal_ui/test/canvas/plan_canvas_reuse_spike_test.dart`. It stands a third canvas up out
of shipped parts, pans it with the wheel, zooms it with a pinch, hit-tests one rectangle, drags that
rectangle and declines to drag empty space. **It lives in `test/` on DR-091's reasoning**: that
ruling keeps the Plan view out of the tab strip until it is built, and a half-canvas exported from
`lib/` would be the same untruth one layer down. Here it is evidence rather than product, it is
gated, and `PLAN-E/2` deletes it when the real surface arrives.

**WHAT THE FILE DOES NOT DECLARE IS THE MEASUREMENT.** Every line in it that is not a test is a piece
that did not come free, which is why the finding is a diff and not an opinion.

**5.9.7.3 THE DRAG PREVIEW DOES NOT FIT, AND THE ROW SHRINKS RATHER THAN GROWS.** This was the piece
the study flagged, and it is coupled exactly as feared: `DragPreviewController`'s vocabulary is
`deviceH`, `Face`, a hard-snapped `ruIndex` and a blocked verdict carrying an occupant's rect and a
sentence like *"Occupied by AMP-1 (U19-U20)."* Every one of those is a rack rail.

**A PIN HAS NO U, NO FACE, AND NOTHING TO BE BLOCKED BY.** A floorplan is continuous: a pin lands
where the pointer is, and there is no occupancy rule to refuse it. So the plan canvas does not need a
generalised `DragPreviewController`, it needs **no** `DragPreviewController`, and the spike drives its
drag straight off `CanvasIntentHandler`, which already reports scene points. **The estimate's biggest
named risk turns out to be a line item that deletes itself**, and the correct conclusion is not that
the controller should be generalised: it is that two of this product's three canvases have a
snap-and-refuse model and the third does not.

**5.9.7.4 THE PIECE NOBODY COUNTED IS THE RENDER OBJECT, AND IT IS THE THIRD COPY OF THE SAME FORTY
LINES.** `RenderRackCanvas` takes a `DiagramScene` plus a `rackId` and hosts one `RenderDeviceBox`
child per device. `RenderSchematicCanvas` takes a `SchematicPaintPlan`. **Neither will accept "replay
this display list under this viewport"**, so the spike declares a third, and so will `PLAN-E/2`.

This is not an accident and the second copy says so in its own header: it is *"a deliberate copy of
`render_rack_canvas.dart`'s shape"*, made deliberately because the schematic canvas that was deleted
at `b560a50` invented a second pattern and got all three of its load-bearing details wrong. **The
copying was the right call twice and it is now a countable cost**, and the honest read is that the
shared part (clip layer, transform layer, `LayerHandle` lifecycle, the viewport listener, the paint
offset composition) is the same in all three while the typed part (what is replayed, and whether
there are children) is genuinely different in all three. `PLAN-E/2` should copy it a third time
rather than generalise it under deadline; a fourth would be the moment to extract a base.

**5.9.7.5 A WIDGET TEST CANNOT SEE A DROPPED PAINT OFFSET, AND THIS WAS MEASURED RATHER THAN
ASSUMED.** The spike's transform composes the render object's paint offset with the viewport, exactly
as both shipped canvases do. **Deleting that offset term leaves all six cases green.**

That is `b560a50`'s defect reproduced inside the spike on the first attempt: a canvas at the window's
origin makes screen, local and scene coordinates agree, and a widget test does not composite.
`render_schematic_canvas.dart` carries a `debugSceneToScreen` field for precisely this reason and
says so. **`PLAN-E/2`'s render object owes the same escape hatch and a case that places the canvas
below a toolbar**, or the product ships this defect a third time with a green suite over it.

> **THE SECOND HALF OF THAT PRESCRIPTION WAS WRONG, AND `PLAN-E/2` FOUND OUT BY WRITING IT.** The
> toolbar case was written and **it cannot pass**. The reason is structural rather than incidental: a
> render object that is `isRepaintBoundary` is painted at `Offset.zero` **always**, and its on-screen
> position rides on the layer instead. Placing the canvas under a 60 pt toolbar and reading
> `debugSceneToScreen` back gives **0, not 60**, because the offset genuinely is zero. The term is not
> being dropped; there is nothing in it to drop.
>
> So a widget test cannot observe the composition **because at run time there is no composition to
> observe**, which is a stronger statement than "a widget test does not composite" and the one that
> should have been written. The protection that works is the one the schematic already had and this
> paragraph looked straight past: `schematicSceneToScreen` **as a free function**, driven with the
> offset a non-boundary would receive. `planSceneToScreen` is its twin and
> `render_plan_canvas_test.dart`'s first case drives it on both axes with a scaled viewport, so a
> composition written in the wrong order fails there.
>
> **THE ESCAPE HATCH IS STILL OWED AND STILL BUILT**; it simply protects a different thing than this
> paragraph claimed. `debugSceneToScreen` is what lets a widget case assert that the **viewport**
> reaches the matrix a paint actually used, which is the half that moves when a person pans, and
> which a `paints..transform()` matcher cannot check because it compares a `Matrix4` against the raw
> `Float64List` the canvas records and never matches.

**THE SPIKE'S OWN OFFSET CASE COVERS THE INPUT PATH AND NOT THE PAINT PATH**, and the file says so
rather than implying otherwise. A handler reading `event.position` instead of `event.localPosition`
IS caught, because the spike drops its canvas below a 60px toolbar and pans before clicking. That is
the hit-test sibling of the same defect, and it is worth having; it is not the same assertion.

**5.9.7.6 `FlutterImageResolver` IS A TYPEDEF THAT NOTHING IMPLEMENTS, AND A PLAN CANVAS THAT CANNOT
DRAW THE PLAN IS NOT ONE.** PLAN-A added `drawImage` to the interface, both backends draw it, and
`FlutterDiagramCanvas` takes an optional resolver. **No caller anywhere supplies one**, because
nothing yet emits an `OpImage`: the only two construction sites in the tree are in test files.

So `PLAN-E/2` owes two things the brief does not mention: a **plan scene builder** that emits the
underlay's `OpImage` with a destination rect honouring `ImageRef.aspectRatio` (DR-030's rule, since
the canvas deliberately has no fit rule of its own), and a **decode-once cache** turning a container
member into a `ui.Image`. The second is not optional and its shape is already ruled: the resolver is
synchronous *"because painting is"*, so the decode happens at import or at open, and a resolver that
decoded on demand would decode a floorplan on every frame of a pan.

**AND ONE COMMENT IN THAT FILE HAS EXPIRED.** `flutter_canvas.dart` says *"NULL IS THE ORDINARY STATE
and stays so until PLAN-C"*. PLAN-C and PLAN-D have both closed and it is still null, because the
thing that ends it is a scene builder and not a model. Corrected in place.

**5.9.7.7 THE MARQUEE ROW IN docs/15 §6 IS VACUOUS, AND IT WAS CENSUSED BY MECHANISM RATHER THAN BY
ITS NAME.** That table promises the Plan editor pan, zoom and marquee-select *"identical to the other
two canvases"*. **Neither of the other two canvases has a marquee.** CR-102 is normative, rules it
left-drag in every view and specifies the CAD window/cross convention, and nothing implements it.

**Grepping the word finds only comments saying it is deferred. The load-bearing finding is one layer
down: every `SelectMode` call in `lib/` passes exactly one id.** `SelectionController` holds a set and
supports add and subtract, and no gesture in this product has ever put more than one thing into it;
`add` and `subtract` are reachable only by Ctrl+click. **A multi-selection nothing can multi-select
is the shape a census by name would have missed**, and it is the third entry in this board's running
tally of a design document and a ruling agreeing with each other without either having read the
model (§11.36.5's own list).

**SETTLED BY THE USER ON 2026-09-07: BUILD IT ONCE AND ADOPT IT ON ALL THREE.** Not the plan alone,
and not deferred behind a corrected sentence. CR-102's entire content is that the gesture is uniform
across views, and three separate later implementations is how a uniformity ruling stops being one.

**IT IS ITS OWN CHAPTER, `#848` (`PLAN-E/6`), AND NOT PART OF `PLAN-E/2`.** E/2 is *"place, drag and
select pins"* and was estimated as that; cross-canvas work touching two shipped surfaces carries
regression risk of its own, and folding it in would be exactly the invisible growth this chapter
exists to expose. **The growth is real and it is now a line somebody can read**, which is the
difference between an estimate that moved and an estimate that was wrong.

**5.9.7.8 WHAT THIS DOES TO THE 2-3 WEEK ROW, STATED WITHOUT RE-PRICING THE EPIC.** DR-037 §11.36.7
declines to re-estimate at decomposition and this chapter declines for the same reason: a re-price
here would be a scope amendment wearing a task's clothes (§8.3). What can be said is the direction of
each term, which is what a spike is for.

| | Direction | Why |
|---|---|---|
| Drag preview | **down** | Not generalised, not needed (§5.9.7.3) |
| Viewport, selection, hit-test, commands | **unchanged** | Reused verbatim, as claimed |
| Render object | **up, small** | A third copy of forty lines, plus the `debugSceneToScreen` case §5.9.7.5 says is owed |
| Scene builder + image resolver | **up, real** | Neither was in the row's five pieces, and the plan cannot be drawn without both (§5.9.7.6) |
| Marquee | **out of the row entirely** | Moved to `#848` rather than absorbed (§5.9.7.7) |

**THE STUDY'S SENTENCE WAS RIGHT FOR THE WRONG REASON.** It said the row was *"the one most likely to
be wrong in the optimistic direction"*, and it is: not because the shared machinery turned out
coupled, but because the list of shared machinery was **incomplete**. Four of five pieces reused
verbatim on the first attempt, which is a better result than the study expected; and three pieces it
never mentioned have to be built. **Checking the named risks would have cleared the row.** The census
that found the unnamed ones is what a week of E/1 actually bought.

#### 5.9.8 PLAN-E/2: pins are placed, dragged and selected, and the estimate moved in both directions · `DR-140` · `v0.6.23`

**Closed 2026-09-08** (`#629`, four commits). **No exit clause moves**, and the reason is worth
stating rather than assuming: the clause *"rack and every drop pinned"* asks for **a person pinning
every drop of a real rough-in**, which needs `PLAN-E/5`'s shell home and `PLAN-J`'s real project. What
this chapter builds is the machinery that makes the act possible.

**5.9.8.1 THE HOLE THE DECOMPOSITION CHECK FOUND BEFORE ANY CODE WAS WRITTEN.** `Rack.planPin` has
existed since PLAN-C and `SetPlanPinCommand` has accepted `PinCarrier.rack` just as long, so the
model and the writer were both ready. **Nothing in any of `PLAN-E`'s five chapters could press the
button.** The palette places a device, the drop table pins an outlet, the unpinned strip listed
devices, and pan/zoom/marquee select nothing new.

**IT IS A HARD BLOCK ON THE EXIT CRITERION, NOT A POLISH ITEM.** A plan whose rack is unpinned yields
no `planLowerBound` anywhere, so `PLAN-G` derives nothing, `PLAN-H`'s `T1.01` prints callouts with no
lengths behind them, and `PLAN-J` hands a stranger a sheet missing the one measurement it promised.
DR-140 §11.139 routes it through the unpinned strip, which also makes `PLAN-E/4`'s count mean
*"everything this plan still owes"* rather than *"devices only"*. **Each chapter was coherent; the
set had a hole, and it was visible only from outside any one of them** (the fourth instance of
§11.36.5's shape, and the first about a capability rather than a field).

**5.9.8.2 WHAT WAS BUILT, IN FOUR COMMITS.**

| | |
|---|---|
| `buildPlaceOnPlanCommand` | CR-104's third drop target. A device dropped on a floorplan is in no rack, so it is an `OffRackPlacement`, and the pin rides on the placement so **one undo restores both** |
| `buildPlanScene` | The third scene builder. One image pixel is one scene unit, so aspect is preserved by construction and a `PxPt` is clickable at the same numbers |
| `PlanImageCache` | The `FlutterImageResolver` implementation the tree never had. Synchronous lookup, asynchronous load, real `dispose` over native handles |
| `RenderPlanCanvas` | The third copy of the same forty lines, with `planSceneToScreen` as a free function |
| `PlanCanvasScreen` | The two gestures, with **no `DragPreviewController` anywhere in them** |

**5.9.8.3 THE ANALYZER CAUGHT A DESIGN MISTAKE, AND THE LINT WAS THE SYMPTOM RATHER THAN THE
DISEASE.** The first draft added an `onPlan:` argument to `buildPlaceFromCatalogCommand` and relaxed
`targetRack` to `Rack?`, since a plan drop has no rack. That produced **nine
`unnecessary_null_check` infos**, because nine call sites pass `targetRack: doc.racks[id]!`.

Those `!` are load-bearing. `doc.racks[id]!` throws at the line that got it wrong; against a `Rack?`
parameter the same expression without its `!` compiles, passes `null`, and turns an immediate throw
into a refusal string several frames later. **Relaxing a type to serve one new caller would have
charged nine old ones for it.** So the plan drop got its own entry point, both paths still end in one
shared builder (CR-104 is about the insert, not the arity of the function computing its arguments),
and *"called with neither target"* went back to being unrepresentable rather than refused. **A test
asserting that refusal was deleted**, with a comment where it stood: a test for a state the types
forbid is worse than no test.

**5.9.8.4 §5.9.7.5's PRESCRIPTION WAS WRONG AND THIS CHAPTER FOUND OUT BY WRITING IT.** That section
told `PLAN-E/2` it owed *"a case that places the canvas below a toolbar"*. The case was written and
**it cannot pass**: a render object that is `isRepaintBoundary` is painted at `Offset.zero` **always**
and its position rides on the layer, so the assertion reads 0 rather than 60 because the offset
genuinely is zero. **A widget test cannot observe the composition because at run time there is no
composition to observe**, which is a stronger claim than *"a widget test does not composite"* and the
one that should have been made. §5.9.7.5 now carries the correction. The protection that works is the
**free function** the schematic already had and which §5.9.7 quoted while looking straight past it.

**5.9.8.5 A TRAP THAT HANGS RATHER THAN FAILS, AND COST THE MOST TIME IN THIS CHAPTER.**
`Picture.toImage` and `ui.instantiateImageCodec` are real engine work and **never land inside
`testWidgets`' fake-async zone**. Awaiting either there waits forever: the file produces **no output
at all**, which reads exactly like a slow suite rather than like a deadlock, and there is no failure
to diagnose. `tester.runAsync` is the fix and four cases need it. Recorded here because the next
person to put an image in a widget test will lose the same hour.

**5.9.8.6 TWO OF THE CHAPTER'S OWN TESTS WERE WRONG BEFORE THEY WERE RIGHT**, and both say so in
place rather than being quietly corrected. The grab-offset case grabbed 12 scene units off centre,
**missed the marker's hit box entirely** (its radius is the underlay's long side over 110, about 5.5
units on the 600-pixel fixture) and asserted that nothing moved, which it dutifully did: a false pass
wearing a green tick. And three palette cases armed a pointer whose `down` had never reached
`GestureBinding`, so the global route received nothing.

**5.9.8.7 WHAT `PLAN-E/2` DID NOT BUILD, LISTED SO IT IS NOT READ AS DONE.** **No layout**: docs/15
§6's three regions and the view's home in the shell are `PLAN-E/5`'s, so
`PlanCanvasScreenState.armPaletteDrag` is public and no left rail is invented. **No staging-bin
drag**: `StagedPlacement`'s only writer in `lib/` is the JSON decoder, so half of docs/15 §6's first
gesture row has no source, and that row now says so. **No `planLowerBound` recompute**: the enum value
arrives at `PLAN-G`, and that row says so too. **No marquee**: DR-139 moved it to `#848`.

**5.9.8.8 THE DIRECTION OF THE ESTIMATE, WHICH MOVED BOTH WAYS.** §5.9.7.8 predicted drag-preview
down, render object up small, scene builder and image resolver up real. **All four held.** The
unpredicted term is DR-140's rack pin, which is new work nobody had scoped and which exists because
somebody asked what produces each chapter's input. **The row is bigger than the study said and
smaller than the study's own named risk implied**, which is the same finding `PLAN-E/1` reported one
chapter earlier, now with code behind it.

#### 5.9.9 PLAN-E/3: the fast path's mode, and a gate that moved a chapter boundary · `DR-141` · `v0.6.24`

**Closed 2026-09-08** (`#630`). **No exit clause moves**: the clause this serves is *"rack and every
drop pinned"*, which needs a person and a real rough-in.

**5.9.9.1 THE BRIEF SAID WHAT THE GESTURE IS AND NOT WHAT FOLLOWS IT.** docs/15 §6 gives the fast
path as *"click an outlet in the Structure editor's drop table, then click the plan"*, and stops
there. Sixty drops means sixty pins, so the unspecified moment is the whole question. DR-141 settles
it: **one arm, one pin, and the mode stays on with nothing armed**, chip up, `Esc` the only exit.

**AUTO-ADVANCE WAS OFFERED AND DECLINED**, and the reasoning belongs on the record because it is the
more obvious design: pin, advance to the next unpinned outlet, sixty drops in sixty clicks. It was
declined on the failure mode rather than the ergonomics. A mis-click pins the wrong drop **and**
advances, so the recovery is an undo plus a re-arm, and the person going fast is exactly the person
who will not notice which subject the chip moved to. **An auto-advancing queue is a machine for
producing confidently wrong pins on a drawing an installer will trust.**

**5.9.9.2 THE COST OF THAT IS REAL AND IS PAID BY A DIFFERENT CHAPTER.** Two acts per drop, and
across a tab boundary this ruling **is** the sixty round trips `PLAN-E/3`'s own brief cites AC-048
and the tally surface as already refusing. It is not sixty round trips only because **DR-140 already
put the picker in the plan view**: the unpinned strip is right there, so the ordinary loop is pick
from the strip and click the plan, with no view change and a shrinking count for progress.

**SO THE TWO CHAPTERS OVERLAP AND DR-141 SAYS WHICH IS PRIMARY.** `PLAN-E/4`'s strip is **the**
pinning workflow; `PLAN-E/3` is the secondary entry point, for somebody already in the Structure
editor. **The brief's own framing is superseded**, and `PLAN-E/3` shrinks accordingly: no queue, no
ordering rule, no next-subject indicator.

**5.9.9.3 A MODE IS A DIFFERENT TYPE FROM A REQUEST, AND THE ONE PRECEDENT IS THE WRONG ONE.**
`SchematicRevealController` is the existing cross-tab mechanism (CR-105) and it is **one-shot**:
`take()` empties it so one click reveals once. Reusing it was considered and is wrong, because the
mode outlives the pin. Mutation-tested by ending the mode inside `pinned()`, which is precisely the
one-shot design: **five cases fail**. A suite that only ever pinned once could not tell the two
apart, so the cases pin and then look at what is still on screen.

**5.9.9.4 A GATE MOVED THE CHAPTER BOUNDARY, AND IT WAS RIGHT TO.** The drop table's half was built:
`StructureEditorActions.onPinOnPlan`, threaded to a row, opened by a secondary tap, two cases green.
`actions_have_callers_test.dart` refused it, because **nothing in `lib/` supplies one**.

| | |
|---|---|
| What the gate is for | M3-H/5, where `OutletsActions.onRemoveGang` had a command, an app-side implementation, tests for both **and no caller** |
| What it caught | The same shape, in a chapter that had written the callback, the menu item and the tests before noticing nothing could supply it |
| The available cheat | The call site was `pin(row.linkId)` through a local alias, so the scanner's `\.name\s*\(` never matched. **Rewording it until the regex matched would have satisfied the letter and left the gesture unreachable** |

**IT REALLY IS UNREACHABLE.** A menu item that arms a mode whose only surface is a view the shell
does not mount is a control that does nothing, which is DR-091's rule one level down. So the producer
**moves to `PLAN-E/5`**, where the Plan view gets a home and the whole path becomes reachable in one
commit. DR-141 §11.140.7 carries the amendment; that subsection had said `PLAN-E/3` builds *"both
ends"*, and it does not.

**5.9.9.5 THE GENERAL POINT IS ABOUT THE DECOMPOSITION, NOT ABOUT ONE CALLBACK.** `PLAN-E/2`, `/3`
and `/4` all build behaviour for a view that `PLAN-E/5` mounts, so **each ends with code the product
cannot reach**. That is legal, and each chapter says so in its own files rather than implying
otherwise. What it means is that **`PLAN-E/5` is not a small wiring chapter**: it is the one that
makes three chapters' work true, and it should be scheduled as that rather than as a tab and a
keymap.

**5.9.9.6 WHAT `PLAN-E/3` LEAVES BEHIND.** The mode (`PlanPinArmController`), the subject
(`ArmedPin`), the link-to-outlet resolution with worded refusals, the chip, and the plan-side pin.
**The row is not the subject**: the drop table is keyed by `linkId` and a pin hangs on an `Outlet`,
the join being `Link.structureOrigin.outletId`, which `derived/structure_matrix.dart` already walks.
A link with no `StructureOrigin` is a cable that runs to no outlet and is refused by name.

**AND AN ARMED CLICK THAT HIT SOMETHING DOES NOT PIN.** A click landing on an existing pin already
means *"select that"*, and an armed mode silently repurposing it would pin the armed drop on top of
another one at a point the user was pointing at for a different reason. There is a case for it.

#### 5.9.10 PLAN-E/4: the unpinned strip, and a defect its own question found · `DR-142` · `v0.6.25`

Closed `2026-09-08`. Commits `228bc79` (the ruling), `c065cb2` (the fix), `87cc2a5` (the
derivation), `b484117` (the strip and the drag). Four commits, each gated green.

##### 5.9.10.1 One sentence, and a decision hiding in every clause

docs/15 §6 gives the strip as *"everything in this plan's location that could carry a pin and does
not, with a count"*. **The brief predicted the shape of the mistake and could not name its
location.** It warns in terms about *"the count that counts the wrong thing"*, citing the status bar
that read `0 pathways` the keystroke after somebody made one; DR-140 then supplied a second instance
deliberately, since a strip built from `doc.devices` is wrong on any document with an unpinned rack.

**Reading the model turned up three more.** They are DR-142 §11.141 and each is one mutable line in
`derived/unpinned_carriers.dart`:

| Clause | The reading taken | The reading refused, and why |
|---|---|---|
| *"does not"* | No pin **at all** | *"No pin on this underlay"* is not a wrong row, it is a **destructive gesture**: a carrier holds one `planPin`, so dragging that row would MOVE the pin off the other plan while presenting itself as adding something |
| *"this plan's location"*, when the plan has none | No filter, so a site plan lists everything unpinned | *Nothing* reports **zero** on a plan with nothing pinned. *Only carriers whose location is also null* joins unknown to unknown, which is G4's forbidden move |
| *"everything"*, when a carrier's own room is unknown | A **count** beside the rows (`unlocatedCount`) | A **row** invites pinning a second-floor speaker onto `Level 1`. **Silence** is `0 pathways` again |

##### 5.9.10.2 The defect the third question found, which nothing was going to fail on

A device has **two** location fields, and the model says they hold the same value:
`AddStructureCommand` writes both, `RemoveLocationCommand` clears both, *"clearing one would leave
the document disagreeing with itself"*.

`buildPlaceOnPlanCommand` writes one. It hands `AddDeviceCommand` an `OffRackPlacement` carrying the
underlay's room, and `AddDeviceCommand.apply` builds its `DeviceInstance` with no `locationId`,
because that command has never had the parameter.

> **Every device dropped on a plan since `PLAN-E/2` printed no room on the Equipment List**, which
> reads `device.locationId`. There was no later repair either: `locationId` is deliberately not a
> `DeviceField`, so no editing gesture in the product can set one.

Fixed in `AddDeviceCommand` and derived from the placement rather than asked of the caller, because
a parameter is a thing the next call site can forget in exactly the way this one did. **The
load-bearing test asserts the Equipment List cell and not the field**, on house style: two fields
disagreeing is invisible until something reads the one that was not written, and that reader is the
artifact. Starters unchanged, all four byte-identical.

**Asking which of two fields is the room is the whole reason it was found.** A surface that filters
carriers by room cannot avoid the question, and neither answer was safe while the two disagreed.

##### 5.9.10.3 The gesture nothing in five chapters had

`armCarrierDrag` is DR-140 §11.139 in code: `Rack.planPin` shipped at `PLAN-C` and
`SetPlanPinCommand` has accepted `PinCarrier.rack` just as long, and **no gesture in the product
could press the button**. Without a rack pin `PLN-003` fires and no length on the plan derives at
all.

The palette drag and the strip drag share the tracked pointer, the over-the-canvas test and the
pixel conversion, and differ only at the commit, so a **sealed pair** carries what is armed: *armed
with neither* and *armed with both* are unrepresentable rather than merely unlikely, and a third
source stops the build.

`_canCarryPin` guards **before** the command. `SetPlanPinCommand` answers a missing entity by
returning without writing, which is right for the command and wrong for the caller: `run` would push
an entry whose `apply` did nothing and whose `revert` throws, so the next undo fails on a step that
undid nothing. The case asserts the undo stack is untouched, which is the half a refusal message
would hide.

##### 5.9.10.4 Two layout defects, and the case that found both

**A named row is two lines.** The strip was 56 high, which leaves 28 after the list's padding and
the chip's, and it overflowed by 6 pixels the first time a row with a name rendered. Fixing that
exposed the second: **the counts block was unbounded**, so the `Expanded` beside it got negative
width and overflowed by 44 on the right at 220px.

The case pumps **five widths**, because a `RenderFlex` reports an overflow **once per render
object**: one pump measures one layout and reads as clean for every width it did not try. That is
this repo's own finding from `#808`, applied before it bit rather than after.

##### 5.9.10.5 Evidence

Twelve mutations, all twelve killed. Core: a devices-only strip fails 4, dropping outlets as well
(the pre-DR-140 shape exactly) fails 3, joining an unknown location to a named room fails 1,
filtering everything out of a site plan fails 1, no total order fails 2, *"no pin on THIS underlay"*
fails 1, reading a device's room from the instance field fails 1. UI: ignoring the row's carrier
fails 3, dropping the deleted-carrier guard fails 1, committing a release made outside the canvas
fails 2, merging the unknown count into the total fails 1, dropping the unknown line fails 1, and
**giving every row the same key fails 4**, which is the `byType().first` ambiguity this repo has
been bitten by, run as a mutation rather than trusted.

**A thirteenth is recorded as not counted.** `for (final rack in <Rack>[])` reported zero failures
because `Rack` is not imported in that file, so it was a compile error wearing a survivor's clothes.
**A mutation that does not build measures nothing**, and a mutation run that reports SURVIVED
without checking is a green tick over an untested line.

Floors re-measured: `rackpal_core` 4281 to 4296, `rackpal_ui` 1597 to 1611. Two analyzer infos were
introduced and both **removed** rather than pinned; the pin stays at 233.

##### 5.9.10.6 Still not reachable, and that is now three chapters deep

Nothing mounts the strip and nothing supplies `armCarrierDrag` until `PLAN-E/5`. DR-141 §11.140.7
recorded this for `PLAN-E/2`, `/3` and `/4` together, and this chapter is the third instance rather
than a new finding. **The count of unreachable surfaces `PLAN-E/5` has to make true is now: a canvas
with two gestures, an arm mode with a chip, a drop-table producer, and a strip.**

#### 5.9.11 PLAN-E/5: the shell home, and the importer that had no caller · `DR-143` · `v0.6.26`

Closed `2026-09-08`. Commits `b1b3c45` (the ruling), `96126c0` (the importer's caller), `c70b6a4`
(`Esc` and `KeyScope.plan`), `68e9a51` (the tab and the layout), `f3ce8cb` (the drop-table producer
and a widened gate). Five commits, each gated green.

##### 5.9.11.1 The census found a fifth unreachable surface, upstream of the other four

`PLAN-E/5` was scheduled as the chapter that makes three chapters' work reachable, then four.
**Nothing in the product could put a floorplan in a project at all.** Censused by call site, in
`lib/` only, and every count is zero: `pickAndImportFloorplan`, `importFloorplanFrom`,
`importFloorplanBytes`, `readPdfPages`, `importLiftedPdfPage`, `ImportedFloorplan` and
`PdfPagePickerDialog`. The four starters carry no `underlays` key and `PlanCanvasScreen.underlay` is
required and non-null, so the tab would have opened onto content the product cannot create.

**The producer was two pieces.** `DocumentSession._members` is written only by `adopt`, wholesale, so
there was no way to add a member to an open session: a menu item would have had bytes and nowhere to
put them, and the save would have named a member the container does not hold.

**The reachability gate could not see any of it**, because it scans function-typed fields on
`*Actions` **records** in **`rackpal_ui/lib`** and this is **free functions** in **`apps/rackpal/lib`**,
in a file called `plan_import_actions.dart`. DR-143 §11.142.3, and a new practice: **a gate's scope is
part of its claim.**

##### 5.9.11.2 Two rulings read rather than re-derived, and one of them caught an error

**The `Ctrl+n` map is not renumbered here.** A paraphrase in `app_shell.dart` reads as though the
mapping is deferred *"until Plan lands"*; DR-091 §11.90.4 defers it **past M6**, *"when there is
nothing left to insert"*. So Plan gets a tab and **no accelerator**, joining Locations, Device
Manager and Structured Wiring, and `Ctrl+3` stays reserved for CR-071's Rear Panel.

**The tab is at position 6, and the first draft put it at 4.** That draft reasoned its own job order
and placed Plan before the Schematic. §11.90.3 has a table, and its sentence is *"interconnect it,
mark where it physically sits, hand over the paperwork"*. A comment in `shell_tabs_test.dart` said
the same thing while recording Plan's absence. **Only the Schedule's index moves**, 5 to 6.

##### 5.9.11.3 Three regions, not four, and the fourth is named rather than faked

docs/15 §6 gives left the underlay list, centre the plan, right **the standard inspector**.
`InspectorPanel` takes a `required Rack`; a pin's carrier is a rack, an **outlet** or an **off-rack
device**, and two of the three have no rack to hand it.

> **The column is absent rather than invented.** Building a plan-specific inspector would be a
> surface nobody ruled, on the one view whose arrival is DR-091's rule that a tab must open onto
> something built. **It is owed**, and this is where it is written down.

The location tree is not embedded either: `LocationsPanel` has had its own tab since DR-091, and a
second copy is the *"two routes to one surface"* that ruling deleted the `Project` menu to avoid.

##### 5.9.11.4 The gate that refused PLAN-E/3's work now checks it, and had to be widened to do so

`actions_have_callers_test.dart` matched exactly one shape, `.name(`, which is the only shape a
**non-nullable** callback can take. `StructureEditorActions.onPinOnPlan` is the **first nullable
`Function` field on any `*Actions` record in this package**, censused when it was added, and a
nullable callback can only be written `.name!(x)` or `.name?.call(x)`. **The gate reported a fully
wired gesture as uncalled.**

Nullable is what DR-091's *"absent rather than present and inert"* produces for an optional gesture,
so it will recur. Three shapes now, mutation-tested by unwiring the record call: it fails, so this is
a widening rather than a gate reworded until it went quiet. **The call site invokes the record**
rather than copying the callback onto a row and calling it through a local, which is the exact cheat
§11.140.7 records declining.

##### 5.9.11.5 Evidence, including a bug the comment found and a mutation that measured nothing

**Fourteen mutations, all killed.** Import: never adding the member fails 4, never running the
command fails 2, routing by extension fails 1, an `Err` for a cancelled page pick fails 1, the wall
clock fails 1, keeping the extension in the name fails 2, writing the member on a refused file fails
1. `Esc`: an always-open gate fails 1, dismissing and clearing together fails 1, dropping the
autofocus fails 3. Layout: unwiring the strip fails 2, a `ValueKey` for the `GlobalKey` fails 2, an
empty state that stops naming the route fails 1.

**A REAL BUG WAS CAUGHT BY WRITING ITS COMMENT.** The layout held one `GlobalKey` and passed the
canvas a `ValueKey(open.id)`: two jobs given to the wrong object, so the global key was never
attached, `currentState` was always null and **every strip drag was a silent no-op**.

**And one mutation is recorded as not counted.** `false ? null : X` compiles, reported SURVIVED, and
is semantically identical to `X`. That is `PLAN-E/4`'s did-not-build lesson in a new costume: **a
mutation that changes nothing measures nothing**, and the check is the same one, run before the
result is believed.

Two vacuous assertions were replaced rather than kept: the PDF cases used a stub beginning with
`%PDF-` that lifts no pages, so `anyOf(isNull, isA<Err>())` and `pickerSawIt || underlays.isEmpty`
both passed on a document nothing had been imported into.

Floors: `rackpal_app` 954 to 964, `rackpal_ui` 1611 to 1622. Seven analyzer infos introduced across
the chapter and **all seven removed** rather than pinned; the pin stays at 233.

##### 5.9.11.6 What the Plan view can now do, and what it still owes

A person can import a PNG, a JPEG or one page of a PDF; open the Plan tab; drag a device off the
palette onto the plan; drag any pin to move it; drag a rack, an outlet or an off-rack device out of
the unpinned strip to pin it; arm a drop from the Structure table and click the plan; and press `Esc`
to stop. **`PLN-003` can be satisfied for the first time.**

Owed: the inspector column (§5.9.11.3), calibration (`PLAN-F`), `planLowerBound` (`PLAN-G`), `T1.01`
(`PLAN-H`), the `PLN-*` advisories (`PLAN-I`) and the marquee (`PLAN-E/6`).

#### 5.9.12 PLAN-E/6: one marquee, on all three canvases · `DR-139` · `v0.6.27`

Closed `2026-09-08`. Commits `e3e0388` (the geometry), `10cad2f` (the rack and the plan),
`341c84c` (the schematic). Three commits, each gated green.

##### 5.9.12.1 What was actually missing, and how PLAN-E/1 saw it

`CR-102` has ruled a left-drag marquee **in every view** since M0 and nothing implemented it.
docs/15 §6 promised the Plan editor one *"identical to the other two canvases"* and **neither of the
other two had one**. `PLAN-E/1` found that by censusing the MECHANISM rather than the word: grepping
`marquee` returns comments saying it is deferred, while **every `SelectMode` call in `lib/` passes
exactly one id**. `SelectionController` has held a `Set<Uuid>` since M0 and no gesture had ever put
more than one thing in it.

##### 5.9.12.2 The `partKey` filter, which is the finding

A schematic symbol contributes **one `HitRegion` per port**, each carrying the symbol's `entityId`,
plus one for the body. A band tested against every region therefore **selects a whole device because
it clipped one pin**, in WINDOW mode, where that device's body is nowhere near contained.

> The rack elevation and the plan emit one region per entity and no parts, so that bug looks
> perfectly correct on two of the three canvases. Only `partKey == null` counts.

##### 5.9.12.3 Three defects the cases found, and one they could not

**A band from pointer-down.** `begin` set both corners, so `band` was a zero-size box from contact
and `MarqueeBand` painted a rectangle for every click on bare canvas. `_to` stays null until the
first update, and the rule lives in the controller because the rack arms before its 4px slop check.

**A band that outlived its gesture.** The rack's first draft asked `_marquee.isActive` in
`_onUpdateDrag`, which is a question about the CONTROLLER and not about this drag. A second canvas
pointer is DEFERRED rather than killed, so it inherits the route when the first gesture ends, and it
inherited the band too: its move-drag stopped moving the device.
`canvas_exclusivity_test.dart`'s rule 1 caught it, and the marquee is now scoped per gesture.

**An expired premise in that same test.** Its finger A scrubbed empty canvas purely to hold the
pointer claim, chosen because a drag on bare canvas did nothing. It now means something, and a band
catching nothing REPLACES the selection with nothing. A now sweeps a window over the device the next
step needs and the case asserts it, so the precondition is stated rather than assumed.

**And one in the test rather than the code**: the rack numbers bottom-up, so AMP-1 at U4 is ABOVE
UPS-1 at U1 while screen Y runs the other way. A band written as `ups.top` down to `amp.center` is
inverted, catches nothing, and reads as the window rule being broken.

##### 5.9.12.4 What the schematic's tests deliberately do not assert

The band's arrival is asserted there; **the selection is not**. `SchematicCanvasScreen` builds its
own private `SelectionController`, and on that fixture selecting a device changes nothing a widget
test can read: the drawn-scope headline never renders in that harness, and the painted op count is
**identical before and after a plain tap on a symbol, 831 either way, measured**.

An assertion routed through a mechanism that does not report is the class of test this repository has
already been bitten by, so the id count is asserted where it CAN be read (the rack elevation) and the
rule itself in core. **Making it readable on the schematic means letting that screen take an external
`SelectionController`, the way the plan canvas does.** That is a change to its API and is owed rather
than done quietly here.

##### 5.9.12.5 Evidence

Ten mutations killed: seven on the geometry (a zero-width drag becoming a cross, reading Y instead of
X, each convention behaving like the other, dropping the `partKey` filter, dropping the total order,
an off-by-one containment edge) and three on the adoptions.

**Two survived and are recorded rather than papered over.** Dropping `marquee.cancel()` from the
schematic's click path survives **correctly**: `begin` resets `_from` on every press, so nothing can
inherit a stale origin there, and that cancel is defensive. The rack's equivalent WAS load-bearing,
because it consulted `isActive` across gestures. And feeding `update` the start point survives
because the schematic file asserts the band's arrival rather than its extent, which is core's.

Floors: `rackpal_core` 4296 to 4308, `rackpal_ui` 1622 to 1632. One analyzer info introduced and
removed (a barrel export out of alphabetical order); the pin stays at 233.

---

#### 5.9.13 PLAN-F/0: the band swallowed every click, and DR-141's fast path was dead · `DR-141` · `v0.6.28`

Closed `2026-09-08`, `#849`. One commit, gated green. **Not a scheduled chapter**: it was found at
`PLAN-F/1`'s first test run, because a calibration click sits on the branch the defect hid, and it is
filed as its own Chapter rather than folded in so the regression is a line somebody can read.

##### 5.9.13.1 The mechanism, which is one word in one condition

`PlanCanvasScreenState.beginDrag` arms the band on **every press that misses a pin**, which is
`PLAN-E/6`'s own design and correct. `commitDrag` then read:

```dart
if (marquee != null && marquee.isActive) { ...end the sweep...; return; }
```

`isActive` is true from the instant of contact, so **every click on empty plan took the sweep branch
and returned** before the two branches below it could run: the armed-pin branch that DR-141
§11.140's fast path depends on, and the click-to-clear branch that docs/03 §4.4 requires.

**An armed drop could not be pinned at all**, on any mounting that supplies a band. Every mounting in
the product supplies one: `PlanEditorScreen` passes `marquee: _marquee`, and `PLAN-E/5` is what put
that screen in the shell.

##### 5.9.13.2 Why nothing saw it, which is the part worth keeping

Every case in `plan_canvas_screen_test.dart` **predates the band and passes `marquee: null`**, so the
canvas's own arm-mode cases exercise a configuration the app never uses.
`plan_editor_screen_test.dart` mounts the real pairing and has no arm-mode case, because arming is
the canvas's subject. **Each file is coherent and the pair had a hole**, which is DR-140's finding
about `PLAN-E`'s five chapters restated one layer down: the gap is only visible from outside either
file.

##### 5.9.13.3 The other two adoptions were right, and one of them says so in a comment

Three canvases adopted `MarqueeController` at `PLAN-E/6`. The rack asks `if (!_dragMoved)` first and
reaches its marquee branch only on a real drag. The schematic asks `travelled > slopPx` and its click
path carries the comment:

> A CLICK, so the band never had an extent; end it anyway rather than leaving the controller armed
> for the next gesture to inherit, which is the defect the rack canvas's own adoption hit.

**Both ask whether the POINTER MOVED. The plan asked the controller.** Two right, one wrong, and the
wrong one is the canvas whose click branch does the most work.

§5.9.12.5 records that dropping the schematic's `marquee.cancel()` survived mutation *"correctly"*,
with an argument about `begin` resetting `_from`. That argument is sound and it is about the
schematic; **the plan's own click path was never put to the same question**, and that is the shape of
the miss rather than an error in the reasoning that was done.

##### 5.9.13.4 The fix

`_moved` now means the same thing on both drag paths, the pointer travelled during this gesture,
where it previously meant a grabbed pin travelled and was left false by a marquee drag. `commitDrag`
asks `_moved`, and an armed-but-unwidened band is cancelled so the click falls through as a click.

##### 5.9.13.5 Evidence

Four cases added, and **only one is load-bearing against this defect**, measured by restoring it:
with the condition mutated back to `if (true)`, the armed-click case fails and the other three stay
green, because a sweep clears the selection too and `end` clears the band as surely as `cancel` does.
That asymmetry is written into the test file rather than left for the next reader to rediscover.

The load-bearing case is `AN ARMED CLICK STILL PINS WITH A BAND SUPPLIED`, and the probe that found
the defect was the same assertion against `PlanEditorScreen`: `planPin` came back `null`.

Floor: `rackpal_ui` 1632 to 1636. No analyzer movement; the pin stays at 233.

---

#### 5.9.14 PLAN-F/1: the two-point pick, and the model that had neither a reader nor a writer · `DR-144` · `v0.6.29`

Closed `2026-09-08`, `#633`. Commits `e40fcda` (the ruling), `f5e0f46` (the chapter), over
`9538fa1` (`PLAN-F/0`). **No exit clause moves**, and the reason is worth stating: the criterion is a
printed `T1.01` a stranger can use, and calibration is a prerequisite for a length rather than for a
locator. What moves is that `PLAN-G` now has an input it can derive from.

##### 5.9.14.1 The census, which found DR-143's shape one field over

`PLAN-C/2` built `PlanScale`, argued its rounding rule out in its own header, and `PLAN-C/5`
serialized it. Censused by call site, in `lib/` only and excluding the declaring file:

| Built by `PLAN-C` | Call sites in `lib/` |
|---|---|
| `PlanScale.nanometresPerPixel` | **0** |
| `PlanScale.pixelSpan` | **0** |
| `PlanScale.isUsable` | **0** |
| `PlanScale.lengthBetween` | **0** |
| `PlanScale.lengthAlong` | **0** |
| `PlanUnderlay.isCalibrated` | **0** |

**And no writer**: `plan_commands.dart` shipped five classes over six acts and none set a scale, so
`PlanUnderlay.scale` was null in every document this product could produce. Third chapter in a row
(DR-140's rack, DR-143's importer). The finding is now expected rather than surprising, which is why
the census ran before the code rather than after it.

##### 5.9.14.2 The hole in the chapter split, and what "N lengths" became

`#634` requires that a recalibration changing N lengths says N. **At `PLAN-F` there are no derived
lengths at all**: `planLowerBound` is `PLAN-G`'s and docs/15 §6's own pin-drag row already
forward-dates its recompute clause. A report counting schedule rows would print `0` on every
calibration in the product, which is a G4 report whose number is an artifact of what is unbuilt.

DR-144 §11.143.3 rules the count to be of **measurable pins**, producing **no `Len`**, and to name
the unpinned rack when there is one. §11.143.7 moves the writer into `PLAN-F/1`, because a dialog
that parses a distance and has nowhere to put it is `PLAN-D`'s no-caller defect pointed the other
way and could not have been gated green.

##### 5.9.14.3 A bare number is refused, and the divergence is ruled

`36` is 36 inches or 36 feet, the two differ by twelve, and the number they scale is every length the
plan will ever yield. `parseDistanceEntry` therefore refuses it and names both readings back.

**It diverges from `parseLengthCell`**, which reads a bare number as whole feet, and DR-144
§11.143.5 rules the divergence rather than leaving a reader to infer it: that column is whole feet of
cable, and its refusal keeps the stored value equal to the displayed one; this field is a distance on
somebody else's drawing whose magnitude is not known in advance.

`displayUnits` shapes the refusal and not the grammar, so `2.4m` is accepted on an imperial project.
The arithmetic is integer throughout: a magnitude is carried as a rational, so `3.5` is `35/10` and
`6-1/2` is `13/2`, and `Len.fromInches` is avoided precisely because it takes a `num`.

##### 5.9.14.4 Two things the implementation found

**A `ListTile` cannot hold the row DR-144 describes.** The first draft put the state line and the
action in a `Row` inside its `subtitle` and it **overflowed by 126 pixels** in a 240 wide rail: a
`ListTile` hands its subtitle a fixed width, a `TextButton` carries a 64 pixel minimum and a padded
tap target, and the two do not negotiate. A `Wrap` inside a `ListTile` fixes the horizontal half and
leaves the vertical one, because a three-line subtitle is more than `isThreeLine` allots. The row is
laid out by hand, where the widths are visible.

**And a `MouseRegion` is the only source of a hover.** `CanvasIntentHandler` reports drags and never
hovers, so the rubber line between the two clicks had nothing to follow. Wrapping rather than
overlaying is what keeps the clicks working: a `MouseRegion` hit-tests its child first and adds
itself after.

##### 5.9.14.5 Evidence

Floors: `rackpal_core` 4308 to 4341 (+26 on the parser, +7 on the commands), `rackpal_ui` 1636 to
1658. Six analyzer infos were introduced and all six removed, including **the escaped inner quote in
a test name for the fourth time in this repository**; the pin stays at 233.

The parser was **run against real strings and its output printed** before the assertions were
written, on this repository's own practice: `1/3"` reads `0' 0-5/16"`, `2.4m` reads `7' 10-1/2"`, and
`36` reads back the refusal rather than a number.

---

#### 5.9.15 The second real plan set, and it inverts the first · `DR-145` · `v0.6.30`

Closed `2026-09-08`, `#850`. **No exit clause moves**, and no code changes: what this chapter
produces is a measurement, a ruling and a regression fixture. It is filed as a Chapter under
`PLAN-F` rather than under `PLAN-D`, whose story is closed, on `PLAN-F/0`'s precedent one day old:
unscheduled work goes to the open story rather than under a closed one.

**5.9.15.1 THE METHOD, WHICH IS §5.9.5.1's AND IS REUSED RATHER THAN REINVENTED.** The file is not in
the repository (DR-145 §11.144.6), so every figure below is taken by regex over the raw bytes and can
be re-derived from anybody else's CAD plot. The importer figures are taken by running the shipped
`liftPdfPages` and `readPdfPages` against the file, not by reading the code.

**5.9.15.2 WHAT THE FILE IS.**

| | Value |
|---|---|
| Producer | `pdfplot16.hdi`, from **AutoCAD 2022** |
| Pages | **3**, `/MediaBox [0 0 1224 792]`, ANSI B (17 x 11 in) landscape |
| `/XObject` occurrences | **0** |
| `/Image`, `/DCTDecode` | **0** |
| `/Font` occurrences | **39** |
| Cross-reference | classic table; **no `/ObjStm`, no `/XRef` stream** |
| Size | 1,169,090 bytes |

**5.9.15.3 THE IMPORTER REFUSES ALL THREE PAGES, AND IT IS RIGHT FOR THE RIGHT REASON.** Every page
returns `PdfPageNotLiftableError ... draws no image`, and `readPdfPages` turns that into the sentence
a person sees:

> this PDF has 3 pages and none of them can be used as an underlay (PLAN-D/3, DR-138). The first page
> draws no image. Export the page you want as PNG or JPEG for now.

**BEING RIGHT AND BEING RIGHT FOR THE RIGHT REASON ARE TWO CHECKS**, and §5.9.6.4 is why this one is
run: the lifter once refused all 18 pages of the first real set with a plausible content refusal
while the parser was the thing at fault. `draws no image` sits in `liftPage` **after** the MediaBox,
the malformed-box and the Resources checks, so reaching it proves the parser resolved a real AutoCAD
classic xref, walked its page tree, read a usable `/MediaBox` and resolved each page's resource
dictionary before finding nothing to lift. A parse failure would have said
`PdfCompressedCrossReferenceError`, `declares no usable MediaBox` or `has no resources`, by name.

**AND THE SYNTHETIC CASE PREDICTED IT EXACTLY.** `pdf_page_lift_test.dart`'s
*"no XObject at all is refused"* asserts the same string the real file produced, which is the reverse
of §5.9.6.4's experience and is recorded so that practice reads as a rule of thumb rather than a law.
The refusal reaches the user: `_importFloorplan` passes an `Err` straight to `_showRefusal`.

**5.9.15.4 THE TWO REAL SETS SIT AT OPPOSITE ENDS, WHICH NEITHER ALONE COULD SHOW.**

| | 2026-09-07 (§5.9.5, DR-137) | 2026-09-08 (this section) |
|---|---|---|
| Sheets | 18, ARCH D (36 x 24 in) | 3, ANSI B (17 x 11 in) |
| Content | **every page one full-page JPEG**, zero fonts, zero vector | **zero images**, 39 fonts, all vector |
| Origin | an office flattening a drawing at 60 dpi | a plot straight out of AutoCAD |
| The importer | lifts it, losslessly | **refuses every page** |

§5.9.5.3 wrote *"A vector PDF breaks it"* a day before this file arrived, so the mechanism is not the
news. **The population is.** The ordinary path forks, both forks are ordinary, and PDF import covers
one of them. DR-029 is not wrong and **its purchase is half-delivered**, which is a different
sentence: a plot from CAD is vector by construction, and flattening is an extra act somebody chose.

**ONE FILE IS ONE SAMPLE.** This board has generalised from a single run twice, in opposite
directions, on the CI duration note. Nothing here claims a distribution across the trade; it claims
that both classes are real and have now both been seen.

**5.9.15.5 WHAT IS STILL UNPROVEN, STATED SO THE COVERAGE IS NOT READ AS THE SURFACE.** Neither real
set carries an object stream, so `PdfCompressedCrossReferenceError` has still only ever fired against
a hand-assembled fixture, and §5.9.6.6 names that as the scan's real weakness. Neither carries a page
that is *partly* an image, so the picker's mixed grid, where some pages are offered and others greyed
with a reason, has never met a real document. And no vector page has been rasterised at any
resolution, so DR-137 §11.136.4's ceiling rule has no counterpart for this class.

**5.9.15.6 THE FIXTURE IS A SYNTHETIC TWIN, AND IT WAS MEASURED THE SAME WAY THE REAL FILE WAS.**
`cadPlotPdf()` is built to this file's signature rather than to the minimum that exercises the rule.
The existing case passes an **empty** resource dictionary, which is the rule's boundary; a drawing
office emits one **populated with fonts and holding no images**, and that is the shape that will keep
arriving. Put through §5.9.15.1's regex method, the twin reads:

| | real file | twin |
|---|---|---|
| Header | `%PDF-1.7` | `%PDF-1.7` |
| `/Type/Page` | 4 (3 pages plus the tree node) | 4 |
| `/XObject` | 0 | **0** |
| `/Image`, `/DCTDecode` | 0 | **0** |
| `/ObjStm`, `/Type/XRef` | 0 | **0** |
| `/MediaBox` | `[0 0 1224 792]`, one distinct value | same |
| `/Font` | 39 | **6** |

**THE ONE ROW THAT DIFFERS IS SAID RATHER THAN ROUNDED.** A real plot carries 39 `/Font`
occurrences because a plotter subsets and re-declares faces; the twin carries six, from one Type1
resource per page. Nothing the lifter does reads the count, so the difference is an artifact of the
real file rather than a property of the class, and stating it is what stops the twin being read as a
byte-for-byte reproduction.

**5.9.15.7 EVIDENCE.** Floors: `rackpal_core` 4341 to 4343, `rackpal_app` 964 to 965. **The app case
covers something no fixture in that file could**: every other PDF there is ONE page, so
`PdfHasNoLiftablePageError.pageCount` had only ever rendered as `1 page`, and the plural sentence a
person actually sees was untested. No analyzer movement; the pin stays at 233. The measurement is the
deliverable and is reproducible from §5.9.15.1's method.

---

#### 5.9.16 PLAN-F/2: what a calibration bought, and a mask whose consumers do not subscribe to it · `DR-144` · `v0.6.31`

Closed `2026-09-08`, `#634`. **No exit clause moves.** The brief has three clauses and the census
found one of them already discharged, one measurable only in a place the brief does not look, and one
that needed a derivation built first.

##### 5.9.16.1 The count, and why it is of pins

DR-144 §11.143.3 ruled it: `derived/plan_measurability.dart` answers, for one underlay, how many pins
a length could be derived for, **and produces no `Len`**. One per pin would be `planLowerBound`
shipped early under another name, without the rank, the `>=` prefix, the italic, the rollup exclusion
or `LEN-001`'s reading, which are five decisions DR-037 §11.36.4 already took.

**THE TEST FOR THAT BOUNDARY IS A PROPERTY AND NOT A COMMENT.** Moving every pin from one corner of
the raster to the other changes nothing the derivation reports, and so does multiplying the typed
distance by twelve. Those two cases are the only ones in the file that can tell this derivation from
one that computes distances; every counting case passes either way.

**THE BLOCKER IS NAMED RATHER THAN COUNTED AS ZERO.** `PlanBlocker` is ordered by remedy, so a plan
that is uncalibrated *and* rackless *and* empty reports the one act to do now rather than a list of
chores. `Calibrated · 0 measurable` is a true sentence that tells nobody anything;
`Calibrated · no rack pinned` names the act that unblocks every length on the plan, eight inches above
the strip that performs it.

##### 5.9.16.2 Two surfaces, because a recalibration changes nothing standing

The user's call, and the reason is an asymmetry rather than a preference. A **first** calibration
changes the row from `Not calibrated` to a count, so the act is visible. A **recalibration** leaves
that line reading exactly the same, one measurable before and one after, **so nothing on screen would
say the length just moved**, and that is the most consequential edit the feature has.

So the row carries the standing fact, which is the half that still answers tomorrow, and a snack bar
on commit carries the act, which is the only half that can report a recalibration. The wording is one
function per surface so the two cannot drift, and `calibrateActionLabel` already makes the button and
the undo entry agree on the same two words.

**THE PLURAL IS HAND-WRITTEN**, because `1 pins re-derive` is the `0 pathways` status bar this
repository already shipped once. Every sentence the chapter can emit was **printed and read** before
any assertion was written, which is this corpus's own practice and which is how the singular
`1 pin re-derives` was found rather than asserted around.

##### 5.9.16.3 THE MASK CLAUSE WAS ALREADY DISCHARGED, AND THE CENSUS FOUND SOMETHING BETTER

`#634` says the epoch mask *"must reach every consumer of a derived length"* and cites DR-011.4, whose
first implementation silently did nothing. `PLAN-F/1` already tests `SetPlanScaleCommand`'s mask
against a real `DocumentController` listener, so the clause as written was discharged one chapter
early. Censusing who actually subscribes says more:

| Consumer | Channel | Can it show a calibration? |
|---|---|---|
| Rack elevation | `epochs.structure`, `epochs.rack`, `epochs.meta` | **No.** No device moves |
| Schematic | `epochs.structure`, `epochs.wires`, `epochs.meta`, `sheet`, `style` | **No.** No wire changes |
| **Plan editor** | `DocumentController.changes` | **Yes**, and it is the only one |
| Schedule | rebuilt from `session.document` on the shell's own notification | Not yet: `planLowerBound` is `PLAN-G`'s |
| `T1.01` scale bar | does not exist | `PLAN-H` |

**So the mask over-wakes two canvases and under-wakes nothing**, which is the safe direction and
costs one scene rebuild on a gesture performed once per plan. The two surfaces that must refresh do
not read epochs at all. **The mask is not changed**: `structure | wires` matches the pin commands on
the same chain, and a calibration diverging from them would leave two commands feeding one future
consumer disagreeing about their own consequences.

**AND THE OBSERVABLE HALF IS THE ONE WORTH ASSERTING.** `plan_commands_test.dart` asserts the epoch
counters move, which is the mask against a listener one layer up; `plan_calibrate_test.dart` now
asserts the artifact, that the rail really does redraw, by running commands from **outside** the
widget. One of those cases is the finding: **the row moves when a PIN changes and no calibration
happened at all**, because pinning the rack is what turns `no rack pinned` into a count. A row wired
only to a calibration would sit there naming a blocker the user had just cleared.

##### 5.9.16.4 Evidence

Floors: `rackpal_core` 4343 to 4354 (+11), `rackpal_ui` 1658 to 1665 (+7). **Five mutations killed**
on the derivation: dropping the rack gate, counting racks as measurable, ignoring the underlay id,
reading `scale != null` instead of `isCalibrated`, and reordering the blockers. Each was asserted
present in the source before being applied, so none of them is a mutation that did not build. The
analyzer pin stays at 233.

Two `PLAN-F/1` cases were updated rather than deleted: they asserted the bare word `Calibrated`, and
the line is now richer. The updated assertions name the whole string, which is what the row prints.

---

#### 5.9.17 PLAN-F/3: uncalibrated as a fact, and a count nothing read · `DR-146` · `v0.6.32`

Closed `2026-09-08`, `#635`. Commits `ac2c6f6` (the ruling), `7c24d3b` (the derivation), `2ca74c6` (the
row), `fa2a1cb` (the placement proof). **No exit clause moves**, for `PLAN-F/1`'s reason exactly: the
criterion is a printed `T1.01` a stranger can use, and a calibration is a prerequisite for a length
rather than for a locator. What closes is roadmap §2's calibration bullet, whose own text said it
stayed open on this chapter's half.

##### 5.9.17.1 The census: one clause built, one true by accident, one hole

`#635` has three clauses and they came back in three different states.

**CLAUSE ONE WAS ALREADY BUILT**, which is worth recording because it is the clause the brief leads
with. Censused by site rather than read:

| Where a default scale could enter | What is there |
|---|---|
| `PlanUnderlay.scale` | `PlanScale?`, documented *"null does not mean 1:1"* |
| `PlanUnderlay.isCalibrated` | `scale?.isUsable ?? false`, so a stored unusable scale reads as uncalibrated |
| `_encodePlanUnderlay` | `putIfNotNull`, so an uncalibrated plan writes **no `scale` key** |
| `_decodePlanUnderlay` | `json['scale'] == null ? null : …`, with no fallback |
| `SetPlanScaleCommand.scale` | non-nullable, so no gesture can write "unknown" over a scale |
| `planMeasurabilityOf` | gates on `isCalibrated`, so an unusable scale counts nothing |

Six sites, no substitution anywhere, and `plan_serialization_test.dart` already asserts both the
absent key and the null read-back. `PLAN-C/5` and `PLAN-F/1` discharged it between them.

**CLAUSE TWO WAS TRUE AND PROVEN BY ACCIDENT.** Nothing in `lib/` gates a pin on a scale. But every
plan fixture in `rackpal_ui` is built without a `PlanScale`, so **every pin gesture the suite ran was
already a pin on an uncalibrated plan**, passing for a reason nobody had named, and the mirror
direction, a pin on a plan that IS calibrated, appeared in no case in the package. A property that
only ever holds because a fixture's default happens to be the interesting case is a property nobody
would notice losing, which is this board's own standard about numbers applied to a fact.

**CLAUSE THREE WAS THE HOLE, AND IT IS THE FOURTH OF ITS SHAPE IN FOUR CHAPTERS.**
`PlanMeasurability.pinnedCarrierCount` shipped at `PLAN-F/2` carrying a doc comment that named its
own intended caller: *"a surface that had only the first would report a fully pinned plan as
empty"*. **Zero call sites in `lib/`.** That surface is the underlay row, the row printed a bare
`Not calibrated`, and a plan carrying thirty-nine stranded pins therefore read exactly like a plan
with none. DR-140 found a model with no gesture, DR-143 an importer with no caller, DR-144 a whole
derivation API with neither; this one is a *count* with no reader, which is the same defect with a
smaller radius and the same cause.

##### 5.9.17.2 The user's call, and the number that must not move

Four wordings were put with the trade-off each carried. The one chosen is docs/15 §9's own `PLN-001`
sentence:

> Not calibrated · 39 pins carry no measurable position

**AND THE POPULATION IS THE HALF THAT WAS ACTUALLY BEING DECIDED.** The alternative counted every pin
including the rack, which is what `pinnedCarrierCount` held and what a person counts on screen. It
fails across the two states rather than in either one: thirty-nine stranded would become
`Calibrated · 39 measurable` under the chosen reading and **forty would become thirty-nine** under
the other, and a number that drops by one at the moment of a calibration reads as a pin the
calibration ate. The rack is the datum on both sides (DR-144 §11.143.3) and belongs in neither count.

The test for that is the artifact and not a comment: one stranded pin becomes one measurable pin over
a real `SetPlanScaleCommand`, and the refused reading would print two and then one.

##### 5.9.17.3 So a field was replaced rather than kept, and a stored count became a derived one

`subjectPinCount` is what the row wants, and it is now the only count stored. `measurableCount` is a
getter over it and the two booleans, `unmeasurablePinCount` is its complement, and the two always sum
to the subject count so neither can be read as the other's total.

**KEEPING `pinnedCarrierCount` BESIDE THE NEW ONE WAS THE ALTERNATIVE AND IT WAS REFUSED.** It would
have left an unread field beside a read one, one chapter after a census found it unread, which is
this epic's own recurring defect preserved on purpose. Making `measurableCount` derived is the same
argument at a smaller scale: stored, it sat next to the two flags that decide it and a constructor
could be handed a count its own flags forbid.

##### 5.9.17.4 The proof of both directions is a gesture, and the mutation says why

A case that runs `SetPlanPinCommand` against a document proves the command, and **the command was
never where a gate would be added.** A gate is a disabled strip row, a refused drop or a
`Calibrate first` chip, and none of those is visible to a test that talks to the model. So both
directions drag the rack out of the unpinned strip, which is the gesture `PLAN-E/5` already proves,
and differ only in whether the plan under it carries a scale.

Two mutations on `plan_editor_screen.dart` confirm the cases can see one: a strip drag gated on the
plan being calibrated, and one gated on its not being. **Each kills exactly the case written for it**,
which is what tells the pair apart from one case run twice.

##### 5.9.17.5 Evidence

Floors: `rackpal_core` 4354 to 4360 (+6), `rackpal_ui` 1665 to 1672 (+7).
**Ten mutations killed**: seven on the derivation (dropping the complement, dropping the gate,
dropping the rack half of the gate, counting racks as subjects, reading `scale != null` instead of
`isCalibrated`, dropping the hand-written plural, and returning a zero sentence), one on the row
(reverting to the bare label), and two on the strip drag. Each was asserted present in the source
before being applied and the file restored in a `finally`, so none of them is a mutation that did not
build. The analyzer pin stays at 233.

**Every sentence the row can emit was printed and read before an assertion was written**, which is
`PLAN-F/2`'s practice and which is how the singular `1 pin carries no measurable position` was found
rather than asserted around: the plural and its VERB both move, and a plural-only fix leaves
`1 pin carry`.

Two `PLAN-F/2` assertions were updated rather than deleted, on that chapter's own precedent one day
old: they named the bare `Not calibrated` on a fixture that has a pin, and they now name the whole
string the row prints.

#### 5.9.18 PLAN-G: the plan yields a length, and two of its four briefs had expired · `DR-147` · `v0.6.36`

Closed `2026-09-08`, `#603` and all four Chapters `#636`–`#639`. Commits `1f2a97f` (the ruling),
`2b133e8` (`PLAN-G/1`, the tier), `70d03f1` (`PLAN-G/2` and `PLAN-G/4`, the derivation and the
rules), `263bec1` (the DR-050 scope), `2acdfe2` (`PLAN-G/3`, the column and both rollups).
**No exit clause moves**, for `PLAN-F`'s reason exactly: the criterion is a printed `T1.01` a
stranger can use, and a length is not a locator. What closes is roadmap §4's `planLowerBound`
bullet, which was the last unticked line of the length model.

##### 5.9.18.1 The census, which found three things and none was in a ticket

`PLAN-G` was decomposed on 2026-08-10 and started on 2026-09-08. Four briefs, and half of them
describe a tree that has moved since.

| Found | Where | What the brief assumed |
|---|---|---|
| **`LEN-001` and `LEN-002` already ship** | `validation/rules_cable.dart`, M5-E | `#639`: *"M5 owns the rules; this task owns the input and the seam. Do not build the rules here."* Written before M5 built them |
| **Neither rule has ever read the tier ladder** | `knownLengthOf` is `terminatedLength ?? cutLength` | docs/15 §4.1's *"`LEN-001` and `LEN-002` read the bound regardless of which tier printed"* describes a ladder those two functions do not consume |
| **There are two footage rollups** | `cable_footage.dart`'s `_isQuantity` versus `schedule.dart`'s `_footageOf` | `#638` names *"the footage rollup"*, singular |

**The booby trap worked and its scope is smaller than its reputation.** `cable_footage.dart:309`'s
`_isQuantity` is the one place in this tree where a future decision was written into the build, an
exhaustive switch with no default arm whose header says *"the day it is added this file stops
compiling and somebody decides, rather than a bound silently joining a purchase."* Adding the enum
value stopped the build in exactly one place, seventeen months after that comment was written.
**And `_footageOf` is not behind it**: it reads a `Len?` and never asks where the number came from,
and it builds `ScheduleView.footage` and `ScheduleGroup.footage`, which is docs/08 §3.8's
`Σ 11 runs · 601 ft · 3 estimated` footer. A floor would have walked into the second `Σ` with
nothing to stop it. Third instance in this epic of a gate whose name is broader than its scan, after
`actions_have_callers_test.dart` at §5.9.11.4 and the `partKey` filter at §5.9.12.2.

##### 5.9.18.2 The fourth finding needed the canon, and the tree could not have shown it

**DR-050 §11.49.2, dated 2026-08-12, says in terms: *"THEREFORE NO NEW TIER, AND THIS IS THE RULING.
`ScheduleLengthSource` gains nothing."*** That is two days after DR-037 §11.36.4 ruled the fifth
tier and its rank, and two days after this epic was decomposed into a Story titled *"`planLowerBound`,
the fifth tier that must never become an estimate"*. Neither ruling lists the other in canon §12.

**A census against the tree cannot find this, and did not.** The tier did not exist in the tree under
either reading, so its absence is what both predict. It surfaced only when the brief was read against
the canon, one commit after the tier had already been added on DR-037's authority.

Settled scoped (DR-147 §11.146.7): DR-050 answers whether a figure derived from **room vertices**
earns a tier, and it does not. Three things in its own text say it does not reach the pin-to-pin
floor: §11.49.4 preserves `planLowerBound` **by name**, §11.49.1's table lists it as *"not built"*
rather than removed, and §11.49.2's objection is to a **provenance** distinction between figures that
all sum, which a floor is not. **DR-050's own two items are unbuilt and are nobody's**: no `Location`
ceiling height, no computed-versus-typed marker, no vertex gesture. That is why nothing in the tree
had ever made the two rulings disagree out loud.

##### 5.9.18.3 The datum, and the two exclusions that fall out of it

DR-144 §11.143.3 left *"which rack is the datum when two are pinned"* here. The bound is the straight
line from the pin on **the rack this link lands in** to the pin on this run's subject, and **no bound
derives at all** when that rack carries no pin, even when another rack stands pinned on the same
underlay. *Nearest* and *first* were both refused: each yields a bound more often and a wrong one on
any job with a head end and a satellite rack.

**One condition carries most of the design.** Exactly one end in a rack. A jumper has both ends in
one rack and a sub-feed has them in two, so neither has a field end and neither has a subject, and
both fail the gate without being named.

**AND THAT CONDITION IS WHERE A MUTATION SURVIVED.** Relaxing it to *"at least one end in a rack"*
changed nothing for an ordinary jumper or sub-feed, because their far end is a rail-placed device
that carries no pin under either rule: **both tests passed for a reason they do not name.** The
eighteenth case is the document that tells the two apart, a run landing in two racks whose
`structureOrigin` still names a pinned outlet, and it exists because the mutation asked for it.

##### 5.9.18.4 Two fields that were written and cut, which is the same lesson twice

**A `PlanBoundRefusal` enum** naming the six ways a bound fails to derive was written into
`plan_length.dart` and removed before the commit. It would have had zero call sites in `lib/`: the
tests name the case they exercise by building it, and `PLN-003` is the surface that reports a reason,
reads per underlay, and is `PLAN-I`'s.

**A `ScheduleEntry.planLowerBound` sidecar** was the obvious shape for docs/15 §4.1's *"read the bound
regardless of which tier printed"*, and it was cut for the same reason one step further in.
`rules_cable.dart` takes a `RackDocument` and a `Link` and never builds a schedule, so it calls the
derivation. Two callers, one function, and nothing stored that could disagree with it. The enum's own
doc comment promised that field at `PLAN-G/1` and was corrected at `PLAN-G/2`.

DR-140, DR-143, DR-144 and DR-146 each found a modelled thing nothing could reach. **This is the
first chapter of the epic to find two and build neither**, which is what the four notes were for.

##### 5.9.18.5 The rules, and a prediction under test

An unmeasured run whose floor already exceeds the limit is a proven violation:

> `W001` is unmeasured and its floorplan straight line is already 120.0 m, over the 100 m Ethernet
> channel limit. No route is shorter than the straight line.

A floor **under** the limit is unchanged, *"no measured length, so the 100 m channel limit cannot be
verified"*. That is DR-020 §11.19.2(2)'s asymmetry as executable code. `knownLengthOf` is deliberately
not where the floor went: it answers *"the length this run is known to be"*, and a floor admitted
there would report a run under the limit as fine.

**docs/02 §5.3's catalogue had already ruled this for `LEN-002` and not for `LEN-001`.** The
`LEN-002` row reads *"fed by `cutLength`/`terminatedLength` when known, and by a `planLowerBound`
when that alone already exceeds the limit"*; the `LEN-001` row said nothing of the kind. One shared
`_floorViolation` serves both and the `LEN-001` row is corrected to match, which is the corpus
already having it, arriving with one row of the pair missing.

**`rules_cable.dart`'s header carries the M5-H2 forecast** (DR-125) that both rules *"will rarely
fire before the plan view's run estimation exists"* and that the unmeasured limb would do nearly all
the work until then. This is that estimation. The prediction is now testable rather than quotable,
and nothing about it is claimed here: no real document in this tree carries a pin and a scale
together yet, and `PLAN-H`'s printed sheet is the first one that will.

##### 5.9.18.6 Evidence

Floors: `rackpal_core` 4360 to 4392 (+32), `rackpal_ui` 1672 to 1674 (+2). The analyzer pin does not
move.

**Thirteen mutations killed**, in two runs. Seven on the derivation: the datum becoming the first
pinned rack, an unpinned run-rack falling back to any pinned rack, an unpinned named outlet falling
back to the device beyond it, *"exactly one"* relaxed to *"at least one"*, the two pins no longer
needing one underlay, the rise allowance dropped, and the field end taken from the other end. Six on
the presentation and the rollups: the bound joining the sheet footer `Σ`, the `≥` dropped, the floor
ranked above the room estimate, the floor counted as an estimate, the takeoff's count switched off,
and the floor summed into the purchase. Each was asserted present in the source before being applied
and every file restored in a `finally`, so none is a mutation that did not build.

**Every finding message was printed and read before an assertion was written**, which is `PLAN-F/2`'s
practice. The three sentences the two rules can now emit were dumped from the test run and read
whole; the assertions were written against what came out.

**U+2265 was checked against the font binaries before the literal was written.** Both bundled Jost
weights carry it, and it is added to `glyph_coverage_check.py`'s `REQUIRED` set because it now
reaches a printed sheet. An absent codepoint maps to `.notdef` and draws as **nothing** rather than
as a visible box, which has shipped in this repository twice.

The `≥` is composed in `ScheduleEntry.lengthCell` and never in the shared `scheduleLengthCell`, which
`pathway_table.dart` and three `structure_table.dart` columns read and one of which
`parseLengthCell` reads back.

##### 5.9.18.7 What the Plan view can now do, and what it still owes

Import a floorplan, pin a rack, an outlet and an off-rack device, calibrate from a known distance,
report what the calibration bought, and **derive a length from it that reaches the Pull Sheet and the
DRC**. Owed: `T1.01` (`PLAN-H`), the `PLN-*` advisories (`PLAN-I`), and the printed stranger test
(`PLAN-J`).
#### 5.9.19 PLAN-H/1 and PLAN-H/2: the twelfth slot, and the export path that could not reach an underlay · `DR-148`, `DR-149` · `v0.6.38`

Closed `2026-09-09`, `#640` and `#641`. Commits `3c9c458` (the rasteriser review), `9c48af0` (the
sheet's ruling), `a54a216` (the slot, the resolver, the screening and the sheet). **No exit clause
moves**: the `T1.01` clause needs a callout per pinned drop printing its Pull Sheet designator, and
this chapter draws a marker per pin and no designator at all. What it discharges is the slot the
clause sits in.

##### 5.9.19.1 The census: two findings and a scheduled review

**THE EXPORT PATH STRUCTURALLY COULD NOT REACH AN UNDERLAY**, and no ticket says so.

| Piece | State before `PLAN-H` |
|---|---|
| `DiagramCanvas.drawImage`, `ImageRef` | built at `PLAN-A` |
| `PdfDiagramCanvas.drawImage` | built at `PLAN-A`, emits the `cm`/`Do` pair, counter-flips the raster |
| `PdfImageResolver` | a typedef with **zero production call sites**; only `pdf_canvas_image_test.dart` supplies one |
| `ExportRequest.members` | **did not exist** |

`export_controller.dart` builds the request from `session.document` and never touched
`session.members`, which have ridden from open to save since `PLAN-B`. **This is `PLAN-E/1`'s finding
one package over**: that chapter found nothing supplied a `FlutterImageResolver` and wrote
`plan_image_cache.dart`, whose header says *"a typedef with no implementation is a seam, not a
feature."* The export backend has been in that state since `PLAN-A` and nothing noticed, because no
sheet asked for an image. **`T1.01` is the first caller.** Sixth instance of this shape in the epic,
after DR-140, DR-143, DR-144, DR-146 and `PLAN-G`'s pair.

**AND THE THIRD, FOURTH AND FIFTH EXHAUSTIVE SWITCHES FIRED.** `PLAN-G/1` met the deliberate one in
`cable_footage.dart`, whose header says it was left open on purpose. Adding `SheetRole.devicePlan`
stopped the build in three more places, none of them designed as a trap:

- `build_document.dart`'s `switch (sheet.role)`, exhaustive with no default and assigning a
  definitely-assigned `final DiagramScene`;
- `page_sizes.dart`'s `switch (size)`, a switch expression over `SheetSize`;
- two role canaries in the suite, `sheet_def_test.dart`'s `hasLength(3)` and
  `pull_sheet_clause_test.dart`'s ordered list.

The first is what forces this chapter's shape. `#640` reads as though the enum value could land
alone; it cannot, and a `case` drawing a frame over white paper would be the *"title block over white
paper"* docs/15 §7 already names as indistinguishable from a plan with no drops on it. So the slot,
the resolver, the screening and the sheet land together and `#641` keeps the evidence.

##### 5.9.19.2 The rasteriser review, and a reason that did not survive it

DR-145 §11.144.5 booked this review for `PLAN-H` because *"`T1.01` is the first thing in this product
that needs an underlay rendered rather than stored, so the chapter that builds it is the first one
whose own work is blocked by the absence."*

**`T1.01` is not blocked.** `PlanUnderlay.format` is `png | jpeg` by construction and has been since
`PLAN-C`; a PDF page is lifted to one of those at import. The rasteriser is an **import** gap and not
a render gap. The review was held anyway, because skipping a scheduled review on the grounds that its
stated reason was wrong is a deferral with no review date reached from the other side.

Ruled (DR-148 §11.147): the deferral stands **a second time**, and the new trigger is **the exit
criterion** rather than a date. `PLAN-J`'s drill is bound to the CAD plot, so the epic cannot close
until the rasteriser exists. **That adds no scope**: the criterion already says *"an architect's
floorplan PDF is imported without leaving the app"*, a CAD plot is one, and the criterion has been
unmeetable on that input since it was written. The alternative the user was shown, and refused, was a
green drill on the JPEG set standing as evidence about import coverage that it is not.

##### 5.9.19.3 Two presentation calls, and the honest half of the second

**`T1.01` sits after `T0.02` and before the elevations** (DR-149 §11.148.3), because a reader orients
in the building before they open a rack. It was put to the user because the order is a choice: docs/08
§2.2's table is not numeric, `T5.01` sitting last at `n+5`. **And that table had no `T1.01` row at
all**, while docs/15 §8 has carried the slot since 2026-08-10; a derived document was missing a sheet
the design document ships, and it now has one.

**The underlay prints at 25%** (§11.148.4), one constant, integer per-mille so no float reaches a
document `export_determinism_test.dart` compares byte for byte. Over 18%, the legend chip's tint,
because a chip is a swatch behind one rule and a floorplan is line art whose walls and dimension
strings must survive; over 40%, because the callout has to win.

**NO NUMBER CHOSEN HERE IS EVIDENCE**, and the ruling says so rather than leaving it to be found out:
AC-054's standard is a print on a real greyscale laser at ANSI B, `PLAN-J`'s drill is where that
happens, and moving the value afterwards is expected rather than a defect.

##### 5.9.19.4 Three things the tests found that reading did not

**192, NOT 191.** Black carries 255 units of ink and a quarter is 63.75; CR-001's integer arithmetic
truncates the **ink** rather than the result, so the sample is `255 - 63 = 192`. The hand calculation
said 191. The literal now sits in the test with the reason beside it.

**`im.decodeImage` THROWS** on bytes that look like a format it knows and then are not, rather than
returning null as its documentation suggests. A container is on disk and CR-093 rules that reading one
never throws, so both failures collapse into the single answer the resolver may give.

**A MUTATION CORRECTED A COMMENT THAT WAS ALREADY WRITTEN.** Fitting on `underlayBounds` rather than
`scene.bounds` was commented as a defence against a stray pin rescaling the drawing. `buildPlanScene`
sets **both to the same box** and says so in its own header, so the swap survives the case written to
catch it. The line is still right and now says what it is: a statement of what this sheet depends on,
which becomes a defence the day a scene builder starts unioning markers into its bounds. **The test
records that it cannot tell the two spellings apart**, which is cheaper than the next reader assuming
it can.

##### 5.9.19.5 Evidence

Floors: `rackpal_core` 4392 to 4411 (+19), `rackpal_export` 209 to 220 (+11).

**Eleven of twelve mutations killed.** The twelfth is §5.9.19.4's and is recorded as a finding rather
than papered over. Three of the nineteen core cases assert an **absence**, because `AUTO` is what
keeps M6's four byte-verified starters from each growing a plan sheet: a document with no underlay
must resolve the identical set, and an imported underlay nobody pinned anything to must print nothing.

**THE ANALYZER GATE FAILED ONCE AND THE PIN DID NOT MOVE.** 235 against a pin of 233. Both new infos
were mine, a `DIRECTIVES_ORDERING` on the new barrel export and a `SORT_PUB_DEPENDENCIES` on the new
dependency, and both were fixed rather than pinned over. **Per-package `dart analyze` had reported
both files clean**, which is the gate's scope being wider than a file's, one more time.

`image: ^4.9.1` becomes a direct dependency of `rackpal_export`, pinned on `vector_math`'s stated
rule. It was already in the resolved tree transitively via `pdf` and is inside DR-036's licence
census; a vendored pdfium would reopen that census and has not landed.

**The size claim is measured, not argued.** dart_pdf has no embed-this-PNG path, so a screened
underlay is raw RGB plus `/FlateDecode`. A 400 × 300 line-art plan through the real resolver emits a
document under a tenth of its raw 360,000 bytes. *"Already-compressed rasters do not deflate"* is true
of photographs and false of line art, and DR-137 already ruled that a floorplan is line art.
#### 5.9.20 PLAN-H/3: a pin has no domain, and PAL-1's open obligation becomes a number · `DR-150` · `v0.6.39`

Closed `2026-09-09`, `#642`. Commits `7bf4674` (the ruling), `0e3cb78` (the chapter). **No exit clause
moves**, and it is the nearest miss so far: the `T1.01` clause wants *"a callout for every pinned
drop, each printing the designator its Pull Sheet row prints"*, and that is now built. What it still
needs is `PLAN-J`'s stranger holding the print, which is the clause's own second sentence.

##### 5.9.20.1 Neither half of the brief's "reuse" existed

`#642`: *"callouts carry the device designator and reuse the schematic's tag-pill geometry and the
signal domain's colour (CR-078: colour lives on the DOMAIN, never the family)."*

**A PIN CARRIES NO DOMAIN.**

| Carrier | What it knows about signal |
|---|---|
| `Rack` | nothing. It is the datum, not a signal path |
| `Outlet` | `designation`, `tia570Grade`, a `service` string on its gangs. No `SignalFamilyId`, no `SignalDomainId` |
| `OffRackPlacement`'s device | ports across several domains. A television is video **and** network |

`plan_scene.dart` recorded it at `PLAN-E/2`, **one chapter after this brief was filed**: the marker's
kind *"is deliberately NOT a colour decision here: CR-078 puts colour on the signal domain, and a pin
carries no domain."* Third `PLAN-H` brief to describe a tree that has moved, after `#639`'s expired
handoff and `#638`'s singular rollup.

**AND THE PILL IS IN THE WRONG PACKAGE.** `_PillSizer` is private to
`rackpal_ui/src/canvas/schematic/wire_trace.dart` and `rackpal_export` may never import
`rackpal_ui`. The bundle has carried that since 2026-07-28 as *"a violation in waiting"* that leaves
M6's interconnect sheets unbuildable. **This chapter does not move it**: a thousand-line file relocated
to borrow ninety of them is M6's migration inside a chapter about callouts. What is taken is the
reasoning, cited at each of its three sites.

##### 5.9.20.2 What the user ruled

**One uniform callout, opaque, black.** The knock-out is not a contrast device: black on the darkest
sample the screening can leave is 11.5:1. **Dense line work fails by PATTERN**, and a dimension string
crossing a designator is unreadable at any ratio. Carrier kind stays in the marker shape, where DR-140
already put the rack-is-not-a-device distinction.

**The carrier's own designator.** A pinned outlet has **several** Pull Sheet rows, so a cable
designator is not a function of a pin and would put three callouts on one dot.

**A ring of offsets, then a leader, and a callout is never dropped.** Past the ring the pill is drawn
overlapping with a leader, and `build_document.dart` raises a notice naming how many: an absent callout
is a drop the stranger cannot find; an overlapping one is a drop they can read twice.

##### 5.9.20.3 PAL-1's open obligation, discharged by arithmetic

`tools/pal1_check.py` has carried `CALLOUT_OVER_UNDERLAY_IS_CHECKED_AT = 'PLAN-H/3'` since `PLAN-A/5`,
recording that the underlay's exclusion from PAL-1 does **not** cover *"the requirement that callout
glyphs remain separable against a non-white background ... the first background in the corpus."*

**It is decidable because the screening is a constant.** The gate now prints:

> callout over the screened underlay: black on 192 (ink retained 250 per-mille) is 11.54:1, floor 4.5:1

**Proven not vacuous by mutation**, which is the half that matters: 540 per-mille passes, **560 fails
at 4.30:1**, 700 fails at 2.48:1. The break-even is 550 and DR-149's 250 carries a 2.2× margin.

**THE GATE PARSES THE CONSTANT AND NEVER COPIES IT**, on `registry_parity.py`'s precedent for a Python
gate reading Dart source. A second copy of a moving number is a liability this corpus has swept five
times, and a screening value in two places would have gone stale the first time `PLAN-J`'s print moved
it.

**canon §14.1 is why it is a number and not an eye.** PAL-1 shipped collisions three times because the
rule was *"checked by inspection"* and read at the domain level rather than over rendered values. A
legibility claim about a printed sheet, asserted by looking at one, is that mistake in a new place.

##### 5.9.20.4 Three things measurement decided that reading did not

**THE LEADER RULE WAS MEASURING THE WRONG DISTANCE.** The first draft compared pin-centre to
pill-**centre**, and a lone pin with a four-character designator drew a leader to a pill sitting at its
preferred offset: the centre is half a pill-width away and a pill is as wide as its text. Measuring the
centre makes the rule a function of how long a designator happens to be. docs/15 §7 says *"within its
own pin's clearance"*, which is the **near edge**, and that is exactly the ring radius, so no distance
is computed at all now.

**THE RING'S CAPACITY WAS PROBED, NOT GUESSED.** A first case asserted crowding on twelve coincident
pins and the ring solved all twelve, because four radii by eight directions is thirty-two slots.
**Twenty coincident drops all place clear; crowding starts at twenty-four**, well past any real wall,
and those are the numbers the cases use.

**A MUTATION FOUND A TEST THAT PINNED SIZE AND NOT POSITION.** Replacing the page mapping with raw
image pixels moved every callout to the wrong part of the sheet and left every assertion green, because
the case asserted the pill's height and never its location. **A designator printed beside the wrong wall
is the one failure this sheet exists to prevent.** Two mapping cases were added and kill it.

##### 5.9.20.5 Evidence

Floor: `rackpal_core` 4411 to 4431 (+20).

**Eleven mutations killed.** A twelfth would not build, and that is a fact rather than a gap:
`height` must stay `const` for `const Radii.circular(height / 2)` to be legal, so it cannot come from
measured metrics without a change elsewhere. Its buildable variant is killed by two cases.

Six of the twenty new cases are load-bearing and every one is about the two ways a callout fails a
stranger: it covers the thing it labels, or it names the wrong wall.
#### 5.9.21 PLAN-H/4: the drawn bar, and a placeholder that reached a deliverable · `DR-151` · `v0.6.40`

Closed `2026-09-09`, `#643`. Commits `5338190` (the ruling), `c1604e8` (the chapter). **No exit clause
moves.**

##### 5.9.21.1 A placeholder reached a client deliverable

`PLAN-H/1` shipped `kPlanSheetScaleNote = 'PLAN SCALED TO FIT · SEE BAR'` on `T1.01`, and there was
no bar. It was written as a forward pointer to this chapter and it printed as an instruction to a
reader.

**`unbuilt_copy_accuracy_test.dart` exists for exactly this class and could not see it.** Its own
header: *"the app's honest-absence copy is a factual claim about this codebase, so it is tested
against this codebase."* It scans `rackpal_ui` and `apps/rackpal`; a sheet string lives in
`rackpal_core`. **Fifth gate in this epic whose scope is narrower than its subject**, after
`actions_have_callers_test.dart` (§5.9.11.4), the `partKey` filter (§5.9.12.2), `_isQuantity`
(§5.9.18.1) and the three switches that could not see a missing parameter (§5.9.19.1).

**And it is the first where the missed surface is PRINTED.** In-app copy is wrong until somebody
clicks away; a sheet is wrong in a folder on a job site. **Nothing referenced the constant either**,
so removing it broke no test, which is the same absence from the other side.

##### 5.9.21.2 The brief's plan for the uncalibrated case does not reach the reader

`#643`: *"an uncalibrated underlay gets no scale bar at all, not a bar with a guessed figure on it.
G4, and `PLN-001` is what tells the user why."*

`PLN-001` is a **finding**. It reaches the validation drawer and, at M6, `T0.02`. **The person
holding the printed `T1.01` has neither**, and `SheetRole` has four values today, none of them
`T0.02`. The half of the brief that is right is that no bar may be drawn; the half that does not work
is who explains it.

Ruled (§11.150.3): the sheet says it itself, `NOT TO SCALE · PLAN NOT CALIBRATED`. **The full
`PLN-001` sentence was the closest call and was refused for a reason worth keeping**: DR-146
§11.145.6 put that sentence in core precisely so surfaces cannot drift, so reusing it was the
consistent move. But **its count is a designer's number**. `39 pins carry no measurable position`
tells the person at the desk what a calibration would buy; the installer holding the print can
already find all thirty-nine, and a sheet is read by the second person.

##### 5.9.21.3 Three things measurement decided that reading did not

**A TIE GOES TO THE LARGER BAR, AND THE EPSILON IS NOT A FUDGE.** The drawn length is a double all
the way down: a real length in nanometres times a fit factor times a calibration ratio. A bar that
exactly fills its budget lands at `250.00000000000003` and a bare `<=` picked the rung below. The
budget is an **aesthetic** limit and the last ulp is not a decision anybody made, so the comparison
is relative and the direction is chosen.

**A GUARD THE MODEL MAKES UNREACHABLE IS NOT DEFENCE IN DEPTH.** `nmPerPixel <= 0` was written out of
habit beside the null check and **survived being deleted**, because `PlanScale` already refuses a
non-positive span and a non-positive distance and returns null for both. A branch no test can cover
is a branch a reader has to reason about. Removed.

**A MUTATION FOUND EVERY CASE CALIBRATED THE SAME WAY.** Replacing `nanometresPerPixel` with the
literal value the fixture happens to produce passed everything, because nothing could tell a bar that
**reads** the scale from one with it baked in. A second calibration at ten times the pixels per foot
kills it. **A property proven by one fixture's number is not proven**, which is
`a-fixture-default-is-not-a-proof` met at a number rather than at a flag.

##### 5.9.21.4 Evidence

Floor: `rackpal_core` 4431 to 4443 (+12).

**The load-bearing case lays the bar against the drawing**: two pins exactly one bar-length apart in
the building must be exactly `bar.lengthPt` apart on the page. Written that way rather than by
recomputing the implementation's multiplication, which agrees with it whichever direction it is
wrong in.

**Eight mutations killed. Two did not build, and both are facts rather than gaps**: the uncalibrated
return and the sheet's null check are enforced by the **type system** rather than by a case, which is
the strongest form those two refusals could take.

#### 5.9.22 PLAN-H/5: the schedule projects the plan, and a cap drafted at three times its size · `DR-152` · `v0.6.41`

Closed `2026-09-09`, `#644`. Commits `6456064` (the ruling), `dc3b98f` (the amendment), `9b9511a`
(the chapter). **No exit clause moves**, and `T1.01` is complete: the slot and the screening at
`PLAN-H/1`, the callouts at `PLAN-H/3`, the bar at `PLAN-H/4`, the schedule here.

##### 5.9.22.1 The derivation the brief names holds none of the rows

`#644`: *"It is a PROJECTION of the derivation the equipment list already uses, not a second table
builder."*

`EquipmentList` is **one row per `DeviceInstance`** and its own header says so. A plan pins three
carriers (docs/15 §3.4) and **two of them are not devices**: an `Outlet` and a `Rack` appear in that
derivation nowhere at all. On the rough-in the exit criterion describes, outlets are most of what is
pinned, so the named source holds a minority of the rows.

**Fourth of `PLAN-H`'s five briefs to describe a tree that has moved**, after `#640`'s `SheetRole`
switches, `#642`'s callout copy and `#643`'s `PLN-001`. The pattern is now the epic's rather than a
coincidence: these briefs were written at decomposition on 2026-08-10 and the tree they describe is
a month older than the tree they land in (`a-brief-expires`).

**The principle behind the pointer is right and is CR-107's**, which is worth quoting because it is
about this exact table: two entities carrying the same facts *"is guaranteed to diverge within one
week of real use: the drop schedule says 78 ft and the wiring schedule says 90 ft, and nobody knows
which to bill against."* What satisfies it is projecting the derivations the **plan** already has,
which is what `planPinsFor` and `planPinLabelsFor` are, so the reference column is literally the
string the pill prints and one designator cannot resolve to two spellings.

##### 5.9.22.2 A cap drafted at 180 rows held 60, and 60 is the criterion

`DR-152 §11.151.4` ruled the band **three columns** and called the overflow past it *"expected never
to fire"*, on a drafted claim that three columns at the cap held *"roughly 180 rows"*.

**It held sixty.** The arithmetic multiplied rows-per-block by blocks in the wrong direction, and the
number reached a normative clause without being run. Sixty is DR-037 §11.36.1's own rough-in
(AC-048), so the last resort fired on the sixty-first drop of an ordinary house.

| Blocks | Block width | Cap | Plan keeps at 60 rows | DESCRIPTION |
|---|---|---|---|---|
| 3 | 365 pt | 60 rows | 313 pt | 37 characters |
| 4 | 270 pt | 80 rows | 373 pt | 27 characters |

Amended the same day to **four blocks** (§11.151.4a). The band takes what it needs, so four blocks
give the **plan** more of the sheet at every row count and not less: sixty rows is fifteen rows down
rather than twenty.

**IT WAS FOUND BY MUTATION TESTING AND NOT BY REVIEW**, which is the part worth keeping. The number
sat in a ruling, in a file header and in an export comment, three copies agreeing with each other,
and nothing in the tree disagreed until a test was asked to name the row at which the band starts
omitting. CLAUDE.md's own rule, that **a second copy of a moving number is a liability**, has an
instance where the first copy was normative and no copy was ever measured
(`a-normative-number-is-still-a-measurement`).

##### 5.9.22.3 Two branches deleted rather than tested

`PLAN-H/4` wrote `a-guard-the-model-makes-unreachable` and this chapter met the same shape twice.

**`if (row != null) out.add(row)` survived being deleted.** The three row builders returned nullable
because a map lookup does, but `planPinLabelsFor` had already resolved a designator out of those same
three maps under that same key one line earlier: a pin whose entity is absent has no label and left
through the `continue`. The lookups are now non-null, and **deleting the `!` is a compile error**,
which is the strongest form that refusal can take.

**The column cap at `kPlanScheduleHeaders.length` survived being raised to 99.** Four fields and four
blocks was symmetry rather than a reason: a fifth block needs a drawing area 1,356 pt wide and ANSI B
landscape gives 1122. The floor is real, because a caller may hand the band any box, and the ceiling
was arithmetic nobody can reach.

##### 5.9.22.4 Evidence

Floors: `rackpal_core` 4443 to 4464 (+21), `rackpal_export` 220 to 222 (+2).

**The tiebreak case needs forty rows and the count is the whole test.** Dart sorts a list shorter
than about thirty-three by insertion, which happens to preserve order, and longer ones by a
dual-pivot quicksort, which does not. Measured on this machine: ten rows survive a comparator with
no tiebreak at all, forty do not. A two-row case would have proven nothing, which is
`a-fixture-default-is-not-a-proof` met at a list length.

**The export pair asserts the notice through the real entry point with the real font.** Its control
is the load-bearing half: it reads `DEVICE SCHEDULE` and the sixtieth designator off the emitted PDF,
because an absent notice proves nothing about a sheet that was never drawn.

**Fourteen mutations killed, one did not build.** The one that did not build is §5.9.22.3's `!`.

#### 5.9.23 PLAN-K: the CAD plot imports, and a deferral ends on the population all three rulings said they lacked · `DR-153` · `v0.6.45`

Closed `2026-09-10`, `#851` with `#852` to `#855`. Commits `e39676e` (the ruling), `161bdb0` (the
binary and the binding), `7a5d1ff` (the resolution rule), `4156d5a` (the source), `dd19140` (the
flow). **No exit clause moves by itself, and one becomes reachable**: DR-148 §11.147.3 bound
`PLAN-J`'s drill to the DR-145 CAD plot, which the shipped importer refused, so `PLAN-J` could not
run at all until this landed.

##### 5.9.23.1 Three deferrals, one trigger, and the thing none of them had

DR-138 §11.137.5 deferred pdfium *"until a PDF needs it"*. DR-145 §11.144.5 kept the deferral when
one did. DR-148 §11.147.2 kept it a second time and wired the debt into the exit criterion rather
than a date, on the ground that *"two deferrals with one trigger between them is the shape a
permanent omission takes when nobody counts."*

**All three named the same missing thing.** DR-145 §11.144.3: *"nothing here says how the two classes
are distributed across the trade."* DR-138 §11.137.5, in one line: *"n is one."*

The user supplied it: **raster sets are the more common of the two and vector plots are by no means
uncommon**, and many plans arrive as CAD plots. That is trade knowledge rather than a census, which
is what DR-138 said it was waiting for, and it settles what both prior rulings parked. DR-145
§11.144.4's *"half the ordinary path is bought"* stopped being a note about a possibility.

**AND THE SECOND REASON IS ABOUT THE OUTPUT.** Vector scales better on a sheet somebody is presented
with, which would be true even if every plan imported today. It is why §11.152.6 keeps the source
page, and it is not by itself an argument for building a passthrough now.

##### 5.9.23.2 The mechanism was re-checked rather than assumed

Both original refusals still hold. `pdfrx` and its siblings obtain pdfium by **downloading it at
build time**, which CR-100 forbids in its own words, and 2.x requires **Flutter 3.47** against a repo
pinned at 3.44.4 by a gate. `printing` fetches the same way.

**A pure-Dart renderer was refused on the file itself.** DR-145 §11.144.7 put it on the record as
*not costed*; costing it is one measurement and it is in that same ruling's table: the CAD plot
carries **39 fonts**, so a renderer for that page is a font rasteriser plus a path engine plus a
clipping model.

##### 5.9.23.3 What a vendored binary needs that a package does not

7.1 MB of `pdfium.dll` is now by some distance the largest file in this repository, and **nothing
reviews it**. A pub dependency carries a lockfile hash; a committed binary in a diff carries nothing.

So the pin records the release tag and the SHA-256 of both the archive and the DLL, and a test
recomputes the second one. It cannot tell a good binary from a malicious one. What it tells you is
that nobody swapped it after the day it was pinned, which is the question a supply chain actually
asks.

**The vendoring script is run once by a person and never by the build.** That is CR-100's
supply-chain boundary made a fact rather than a policy: on a first run there is no checksum to verify
against, because a checksum invented by the thing doing the downloading proves only that the bytes
survived transit, so it prints what it got and asks a human to check the release page.

##### 5.9.23.4 The resolution rule, and a mutation that found a real hole

DR-145 §11.144.7 left the question owed and named why: DR-137's *"never above the source's own
effective resolution"* is a rule for a raster source and **a vector source has no such ceiling**.

Measured against the sheet rather than chosen: `T1.01` fits the plan into 15.6 x 7.9 in, so ANSI B at
300 dpi is 5100 x 3300 and reaches the paper at **327 dpi**. 600 cannot be the rule for both real
sheet sizes, since ARCH D at 600 is 311 megapixels against a 120 MP cap. The target steps DOWN to a
40 MP budget rather than a large sheet being refused, because a refusal there would reinstate the
manual step for exactly the drawings most likely to be a whole floor.

**A MUTATION FOUND A DEFECT THE CASES WERE BLIND TO.** Deleting the non-positive guard looked
harmless: every other malformed page fell out at the one-pixel floor anyway. But **two negatives
multiply to a positive area**, so a `-1224 x -792` MediaBox passes the budget check untouched, takes
a NEGATIVE dpi off the per-side cap, and comes back as a plausible `30909 x 20000` raster, past the
cap that had just been consulted. Pinned.

**And one arm was deleted rather than tested**, on `PLAN-H/4`'s practice: a second guard for
`kMaxImagePixels` is unreachable by arithmetic, since the budget is 40 MP and that cap is 120. The
invariant is asserted in the test instead.

##### 5.9.23.5 A refusal that carries the page's size

The lifter's job did not change and its answer is still preferred where it has one, because DR-138
§11.137.3 is emphatic that lifting is not a cheaper rasterisation but a better one. **A case asserts
the renderer is never even ASKED about a liftable page**, which is the half that would rot quietly.

What changed is that `PdfPageNotLiftableError` now carries the sheet in points for every refusal
after the `/MediaBox` is read, so the thing that draws it knows how big without re-parsing a file
this parser has already walked. It stays null for the three refusals that are ABOUT the box, and
`hasSheetSize` is what the flow tests rather than a reason string.

##### 5.9.23.6 Two stale sentences, in a file that already carries that scar

`PLAN-E/1` found this file telling somebody to convert by hand a file this product can open, and
`PLAN-H/4` found a placeholder printed on a client deliverable. Both were copy that outlived the
thing it described.

The lifter's own message ended *"cannot be lifted without a renderer ... Export the page as PNG or
JPEG for now"*, and the app's all-refused sentence said *"for now"* too. **A renderer exists now**,
so the first says what the parser found and leaves the remedy to the caller, and the second says that
a page reaching it is one pdfium ALSO declined, where the remedy is a different viewer rather than a
different format.

##### 5.9.23.7 Evidence

Floors: `rackpal_core` 4474 to 4480 (+6), `rackpal_pdfium` 22 (a new suite), `rackpal_ui` 1674 to
1677 (+3), `rackpal_app` 965 to 981 (+16). Gates: 17, since the suite list gained one.

**THE LOAD-BEARING CASE IN THE BINDING IS THAT THE PAGE IS NOT UPSIDE DOWN**, and nothing else could
see it. A vertically flipped render has the same size, the same ink and the same bytes twice, so
every other case passes against an upside-down floorplan; deliberately reversing the rows fails that
case and only that case. **`PLAN-A/3` met the same defect one package over**: a PDF image occupies
the unit square with its top row at `v = 1`, so a flipped placement produces an IDENTICAL bounding
box.

**And the real binding is run end to end.** The flow's own cases hand it a fake returning a PNG of
the size asked for, which proves the sequence and nothing about pdfium.
`plan_import_pdfium_test.dart` imports a well-formed vector PDF through the shipping path with no
fake anywhere and counts DARK PIXELS in the stored member. Its fixture carries a real
cross-reference table, because pdfium falls into a damage-recovery path without one and **a fixture
that exercises the recovery path of the thing under test passes for the wrong reason**.

##### 5.9.23.8 And it shipped a renderer the packaged app could not find

`PLAN-K/5` (`#856`), after the merge, at `v0.6.46`.

`rackpal_pdfium` looks for its library in an environment override, then **beside the executable**,
then the repository copy. pdfium is not a Flutter plugin and not a native asset, so nothing in
`windows/CMakeLists.txt` carried it into the bundle.

**THE THIRD ARM HID THE ABSENCE OF THE SECOND.** Every developer build kept working, because it walks
up the working tree and finds the committed DLL; the first failure would have been on somebody else's
machine, holding a packaged copy that cannot open a PDF. That is the worst shape a defect can have in
this product, and it is the second time this epic has produced one: `PLAN-H/4`'s placeholder was
wrong only on paper somebody was holding.

**Four chapters were green on seventeen gates**, because the two build gates only run without
`-SkipBuild`. CLAUDE.md already names that shape in terms: *"the two build gates are the ones nobody
watches fail."*

**AND TWO GATES REFUSED THE FIX FIRST, BOTH RIGHTLY.** `verify_windows_build.ps1` lists every DLL in
the shipped output and demands a reason for an undeclared one, since each is another unsigned binary
for an enterprise allowlist to refuse. `dependency_table_test.dart` then refused the docs/03 row that
gate asked for, because no pubspec can declare a binary CR-100 rules committed rather than fetched.
Both were widened deliberately: a parenthesised name is a dependency that is not a pub package,
matched by **shape** rather than by its text on the file-dialog row's own precedent, and the
dependency gate gained the sixth workspace pubspec without which `ffi` was governed by nothing.

Floor: `rackpal_app` 981 to 985 (+4).

---

#### 5.9.24 PLAN-I: four rules in their own band, and three sweeps that meant one catalogue · `DR-154` · `v0.6.48`

`PLAN-I/1` (`#645`) and `PLAN-I/2` (`#646`), 2026-09-10.

docs/15 §9's four advisories, built. The interesting part of both chapters is not the rules: it is
that **every claim the epic inherited about them turned out to be asserted by a test whose scope was
narrower than its subject**, and each was found by running something rather than by reading it.

##### 5.9.24.1 The count the chapter was about was already wrong

`#645` opens by naming the trap: *"AC-040 pins v1's catalogue at 27 and DR-020 made it 28 (8 + 6 +
14)"*. It is **29**. DR-132 restored `ELE-005` at `#838`, the table and the test moved with it, and
the prose did not.

Twelve sentences in six documents said 28, including a box in an ASCII diagram. Every one now cites
the tier arithmetic or points at `rule_catalogue_test.dart`, which states it once and checks it
against docs/02 §5. docs/12 is deliberately untouched: its entries record what was true when the work
happened.

**This is the fourth chapter in this epic whose brief described a tree that had moved**, and the
sixth stale count this corpus has swept. The warning against writing a count down was itself
delivered in a paragraph containing a stale count.

##### 5.9.24.2 A shipped surface was wrong underneath `PLN-002`

`unpinnedCarriersFor` compared locations for equality. docs/15 §3.1 says an underlay's location is
*"usually a floor"*, so on a `Level 1` plan an outlet filed in `Great Room` matched neither the scope
nor the unknown branch: it was **dropped by a comparison and appeared in no count at all**. That is
the `0 pathways` failure `unlocatedCount` exists to prevent, arriving through the door beside the one
it was watching, and there was no child-room case in the whole test file.

The ruling had said *"subtree"* from docs/15 alone; the shipped code disagreed twenty minutes later.
The user ruled both onto one scope, and canon §11.153.7a carries the lesson about the order the two
findings arrived in.

##### 5.9.24.3 `PLN-004` cannot be a `DrcRule`, and that is a fact about where bytes live

A `DrcRule` takes a `RackDocument`, which holds no bytes: an underlay names a container member and
the members ride on the session. So the comparison happens where the bytes are, once, through
`persistence/plan_hash.dart`, and `evaluateDocument` takes the answer.

**A hash computed inside the evaluator would be a sha256 over every underlay on every widget build**,
since `rack_canvas_screen.dart` recomputes findings in `build`. The comparator answers `null` rather
than `false` for an unparseable hash, on `templateHashMatches`'s ruled precedent: `false` asserts
*this was edited* and `null` says *there is nothing here to check against*.

##### 5.9.24.4 Three sweeps that say "every rule" and mean one catalogue

`PLAN-I/2`'s whole subject. `#646` asks for two proofs the corpus already believed it had:

| Claim | The test that carried it | What it swept |
|---|---|---|
| Every rule is acknowledgeable (CR-019) | `rule_exception_test.dart` | `kRuleCatalogue` |
| Every rule that files a finding has a severity | `severity_resolution_test.dart` | `kRuleCatalogue` |
| No rule blocks export (CR-022, G3) | `findings_never_block_export_test.dart` | `kRuleCatalogue` |

`kRuleCatalogue` has been one catalogue of two since §11.153.2, so **not one of the three reached a
`PLN-*`**. All three now cover both bands and count what they reached, because a loop over an empty
band passes silently.

**The severity one is not cosmetic.** `projectSeverity` returns null for a rule it cannot find and
`evaluateDocument` DROPS a finding on a null rather than defaulting, which is G4 one layer up. A plan
rule missing from `kRulesById` would not throw and not warn: it would never fire.

##### 5.9.24.5 The fingerprint nobody had thought of as an identifier

Every `PLN-*` message embeds `underlay.name`, and an underlay is renamed by typing in a text field.
Had the name reached the fingerprint, renaming `Level 1` to `First Floor` would leave every
acknowledgement about that plan matching nothing, and **rule 42 would collect them on the next load
and report them as stale**: the exact failure `finding.dart` refuses designators for.

It does not, and that is now asserted with the message changing in the same case, so the test cannot
pass by nothing having happened. `PLN-002`'s fingerprint DOES move when the population moves, on the
contract `PWR-003` and `LNK-020` already wrote out, and the two behaviours are asserted side by side
so they read as a distinction rather than an inconsistency.

##### 5.9.24.6 And the issues panel could not name any of them

The defect `PLAN-I/2` found in `PLAN-I/1`'s own work. `locusLabel` resolves a finding's primary
through four collections and returns null for anything else; every `PLN-*` points at a
`PlanUnderlay`, so **all four grouped under `No single location`**. The panel told a person that the
most locatable object in their document had no location.

**The guard that promised to catch this sat through it.** `findings_view.dart`'s header said a fifth
type would be *"a test failure, not a blank cell"*, and the test carrying that promise asserts
`locusLabel` returns null for a hand-written stranger id: a statement about an id **no** rule
produces, which cannot see a type that rules **do** produce.

**And it was the sixth, not the fifth.** `ELE-005` has pointed at a `Net` since `#838` and had no arm
either. Neither was found by looking. Both were found on the first run of the census that replaced
the sentence, one of them in work this epic had nothing to do with.

##### 5.9.24.7 Evidence

Floors: `rackpal_core` 4480 to 4528 (+48), `rackpal_export` 222 to 227 (+5). Gates: 17.

**Commits** (§8.8). `PLAN-I/1`: `21e2315` the ruling, `2e8f512` the rules and the count sweep.
`PLAN-I/2`: `e3c8f76` the six locus types, `5c8d1f3` the acknowledgement path, `90ae086` the
export proof, `da9501d` the three amendments and this record, `826cfc2` `v0.6.48`.

**A COMPLETE SHEET SET IS READ OFF THE PAGE.** Four blank pages satisfy a `sheetCount` of four, and
`T1.01` is the sheet these four rules are about: a plan whose advisories held it back would still
have exported the elevations and the schedule and reported the same number. The proof parses the PDF
for the sheet number, the role's title and the pinned drop's callout, and mutation-testing
`planUnderlaysWithPins` down to nothing fails it.

**THE `PLN-003` KNOWN-BAD PUTS THE HEAD END IN THE BASEMENT**, which is not a way around the harness
but the rule's own scenario: an unpinned rack on THIS floor is itself a row in the strip `PLN-002`
counts, so that is the only shape in which `PLN-003` fires alone.

**AND ONE ABSENCE NAMES WHAT RETIRES IT**, which is the practice `#646` asks for. `T0.02` is M6's, so
*"the reason prints on the exceptions sheet"* would be vacuous today in the shape `#310` refused for
the `ISSUED FOR CONSTRUCTION` stamp. The guard is that `SheetRole` has no `exceptions` value, so M6
landing one fails the test and whoever lands it writes the real assertion.

---

#### 5.9.25 LEN-A: plan geometry fills the room estimate, and the ruling had priced a tree that was not there · `DR-050` · `v0.6.54`

`#857` to `#862`, 2026-09-10 to 2026-09-11.

DR-050 was settled on 2026-08-12 from the request that *"room dimensions can be derived from the user
placing vertices on the plan view"*, and §11.49.5 priced **two items**: the derivation and the
computed-versus-typed marker. Both were real. The tree they were to land in was not.

##### 5.9.25.1 The census, which corrected the scope before it wrote a line

§11.49.5 says the work lands with the Plan view *"which is where the vertices and the calibration
live"*. The calibration lived there. **There was no polygon, no outline and no room geometry of any
kind** in `rackpal_core` or `rackpal_ui`: the Plan view shipped underlays, calibration, pins and the
unpinned strip, and nothing ever drew a room.

Six items rather than two, and **the one nobody had noticed is not geometry at all**:
`estimatedRunLengthFromRack` had no editor anywhere. `locations_panel.dart` recorded it in its own
comment as *"a table row with no editor here"* and had done since M3-D, so AC-024's one number per
room was the only one of its three a person could not type. `LEN-A/3` met the same gap from the
other side: a derivation proposing a figure had nowhere to propose it and no control to be compared
against.

Two things the ruling left open were already answered. The *"ceiling height if the derivation needs
one"* is `riseAllowance`, shipped at `PLAN-C`. And `parseLengthCell` already existed, with DR-144
§11.143.5 already stating why it and the calibration's parser differ, so the field's grammar was a
citation rather than a decision.

##### 5.9.25.2 The first list this model has had to compare

`RoomOutline` is the first list-bearing value type in `model/`, which is seven of `#857`'s nineteen
cases. Dart compares a `List` by IDENTITY, and the last time a collection entered machinery built for
scalars it broke four sites at once and every one failed silently.

**Order is the shape here, which is where it diverges from `acceptedFamilies`.** That field is read
with `contains`, so re-ticking two families in the other order is not an edit; the same four points
in a different order is a bow tie rather than a rectangle.

##### 5.9.25.3 A brief of mine was wrong about the stamp, and the test says so

`#857`'s own brief said `documentMinReaderVersion` needed no new check, because an outline names an
underlay and `underlays.isNotEmpty` already returns 5. **That holds only while
`RemovePlanUnderlayCommand` clears what it orphans**, which is an invariant of the COMMANDS and not
of the format: CR-093 lets a hand-edited file carry an outline with no underlay, and on that file an
older build opens read-write and deletes the drawing on save. DR-019 §11.18.1's hazard exactly, and
the reason the four existing checks are per-pin rather than one.

##### 5.9.25.4 The datum, and an objection the code refuted

DR-147 §11.146.2 ruled the BOUND measures from *"the rack this link lands in"* and refused both *the
nearest pinned rack* and *the first in document order*. A room estimate has no single run.

The chapter recommended refusing unless exactly one rack was pinned, and **objected to deriving from
the room's runs on the ground that quoting happens before the runs are drawn. That objection was
wrong.** `estimatedRunLengthFromRack` is read PER RUN at `schedule.dart`'s length ladder, so nothing
consumes the estimate until a run exists, and a schedule row IS a run. The user ruled the runs, and
it buys a consistency neither side had named: the estimate and the bound now measure from one rack by
one rule and cannot disagree about a room's head end.

##### 5.9.25.5 A refusal that would have bought zero wire

The two-rack case was drafted as a refusal on DR-147's reasoning and reversed after measuring what
one costs. `_lengthOf` falls through `roomEstimate` to `planLowerBound` to `none`, and
`cable_footage.dart`'s `_isQuantity` is FALSE for both: **a refused estimate means every run in that
room buys zero wire in the takeoff.**

The user's trade ground is that quotes are built conservatively, commonly several hundred feet over
the actual totals, and that trunk lines move without moving the quote much unless a run has to get
around an LVL or structural steel. Against that, a silent zero is the worst available direction of
error, and the larger of two measured figures is conservative the way the quote already leans.

**No margin is folded in.** That conservatism is the estimator's and stays theirs (§11.49.4).

##### 5.9.25.6 Two defects found in machinery this epic does not own

**`#863`: a refused command still lands on the undo stack, and undoing it throws.** Measured on the
shipped `SetPlanPinCommand`, so it has been true since `PLAN-C`: `canUndo` is true after a refusal
and the next undo throws `StateError`. Twenty-nine commands carry an `_applied` bit.

**`#866`: every second-act undo label is unreachable.** `run(c) => transact(c.label, …)` reads the
label BEFORE `apply`, so `movePlanPin`, `recalibratePlan` and `reshapeRoomOutline` never reach the
Edit menu. Nothing caught it because the existing test asserts the COMMAND's getter and the artifact
is what the menu shows, which is house style's own rule read from the wrong side.

Both were filed rather than fixed in flight: each repair changes the `Command` protocol every command
in the product implements, which wants a ruling ID rather than a commit.

##### 5.9.25.7 And a gate of this epic's own failed to fail

`LEN-A/3` left a case asserting `roomEstimateFor` had no production caller, naming `LEN-A/5` as what
would break it. `LEN-A/5` wired the derivation up and **the case stayed green**, because its scan
walked `rackpal_core/lib` while the caller landed in `rackpal_ui`.

A gate whose scope was narrower than its subject, written to guard against exactly that. It is the
eighth instance this corpus has recorded and the first where the author and the victim are the same
chapter.

##### 5.9.25.8 Evidence

Floors: `rackpal_core` 4528 to 4599, `rackpal_ui` 1677 to 1723, `rackpal_export` unchanged.
Gates: 17.

**Commits** (§8.8). `#857` `265ee42`, `67b3bbf`. `#858` `9a4b4e4`, `e371269`. `#859` `d7c8d94`,
`159fbf1`, `e442ce9`. `#860` `610a62b`, `7413225`, `dce5e45`. `#861` `73c1889`, `0eb1806`,
`38047bd`, `c43cf2d`.

**THE LOAD-BEARING TEST IN THE TOOL PRESSES THE REAL BUTTON AND THEN CLICKS THE REAL CANVAS.**
Everything else in `#860` passes against a mode nobody can start, and this epic has shipped that
twice: `PLAN-E/5` found six functions and a dialog with no caller, and `PLAN-E/6` shipped a gesture
dead until `PLAN-F/0` because the canvas tests predated the band and passed null.

**AND THE VERSION DERIVATION WAS RE-RUNNABLE TO THE WRONG ANSWER FOR THREE COMMITS.** `v0.6.49`
through `v0.6.51` each wrote their first derivation as *"Done Chapters whose title carries `PLAN-`"*,
which returns 48: LEN-A's chapters are titled `LEN-A/n` and were never in it. The numbers were right
because the second derivation carried them, which is what a second derivation is for. Corrected at
`dce5e45`, naming both title families and confirmed against the epic's story list.

#### 5.9.26 `#864`: the outline does not print, and the answer was on the architect's drawing · `DR-050` · `v0.6.55`

`LEN-A/7`, 2026-09-11. Deferred by the user at `LEN-A/4`, closed with no code change beyond a
comment, and the interesting part is the method it did not need.

##### 5.9.26.1 The ticket required paper, and the drill could not have supplied it

`#864` said to decide it *"with a printed sheet in hand"*, on AC-054's own standard, and `PLAN-J` was
being arranged at that moment with a real plan and a greyscale laser at ANSI B. That looked like one
trip to the printer answering two questions.

It was not. **An outline is chrome, so the drill's `T1.01` has no outline on it.** Deciding from
paper needed a sheet built for the purpose, which needed the parameter on `buildPlanScene` that the
decision was supposed to authorise. The deferral had priced a method that could not run without the
thing it was deferring.

##### 5.9.26.2 The user answered with a fact about the drawings

*"It does not show up on the plan. Almost all plans have the room names labeled."*

That deletes the question rather than answering it. The chapter was filed on the argument that a
boundary tells an installer which space is which, and that *"on an open plan with no interior walls
drawn it may be the only thing that does"*. **The architect's own room titles do it, on the sheet the
underlay already is.** Recorded as canon §11.49.9, with the fact in it rather than only the outcome,
which is what stops the same case being made again in six months by somebody equally reasonable.

So: no print run, no parameter, and the four byte-verified starter goldens stay shut. The estimate
this chapter carried was a parameter on `buildPlanScene`, a decision at every caller, a weight chosen
against a screened underlay, and four goldens deliberately regenerated. **None of it is owed.**

##### 5.9.26.3 The cost was a trade question asked late

The OKF practice says to put *"how the work happens in the field"* as a question rather than a
finding, and the question **was** put. What was not is that the ticket had already chosen its method
a chapter earlier, and the method was expensive: `#864` was filed at `LEN-A/4` with a print run
priced into its `DONE WHEN`, and nothing in it asked whether the thing it proposed to measure
mattered.

**A trade question asked early can delete the method you were about to pay for.** That is the fifth
instance in the practice and a new shape: the four before it are objections of mine that were
overruled or simply wrong, and this one is a question whose ANSWER was cheap and whose TIMING was
the whole cost.

##### 5.9.26.4 What would reopen it

A plan whose rooms are not labelled, recorded in the clause itself. The question returns then as a
different one, about printing the room's NAME rather than its boundary, and it needs its own ID.

##### 5.9.26.5 Evidence

Floors unchanged, no test added: there is no behaviour here to assert, and a test that pinned *"the
scene has no outline op"* would pin the absence of a parameter nobody wrote. Gates: 17.

**Commits** (§8.8). `#864` `dfe99c9`, `86c4802`.

#### 5.9.27 `#865`: a corner drags, in a mode, and one defect `LEN-A/4` shipped · `DR-050` · `v0.6.56`

`LEN-A/8`, 2026-09-11. Deferred by the user at `LEN-A/4`, and the last of LEN-A's chapters.

##### 5.9.27.1 The mode is the ruling, and the tie is why

Three options were put to the user with their costs. The cheap one, every finished corner draggable
all the time, was refused on two grounds.

**A pin and a corner are both points.** `kPlanMarkerRadiusFraction` puts a marker at roughly 18 scene
units on a 2000 pixel plan, which at a fitted zoom is about seven screen points, against a ten-point
grab radius. They overlap, and whichever way that tie is broken the loser is a gesture sitting in
front of the person who wanted it.

**And a stray drag would reshape a room silently**, which is the one that decided it. §11.49.7 has
the estimate re-derived from the shape on release, so an accidental nudge moves a figure somebody is
about to spend money on. A mode cannot be entered by accident.

So the mode **takes the whole canvas** while it runs. Four cases assert exactly that, and each is a
gesture that does something on this canvas the rest of the time: a click on a pin does not select it,
a pin under a corner does not move when the corner is dragged, no band opens on bare plan, and a
click on bare plan does not clear a selection made before the mode started.

##### 5.9.27.2 `#866` proved in one line, and worked around in another

`SetRoomOutlineCommand` decides between `drawRoomOutline` and `reshapeRoomOutline` inside `apply`,
from what the document held. `DocumentController.run` is `transact(c.label, …)` and reads the label
BEFORE that, so a bare `run` here would put **"Undo Draw Room Outline" in the Edit menu in front of
somebody who drew nothing**.

The canvas names the transaction instead, which is what the menu shows. A case pins the label and a
mutation restoring the bare form kills it, so this chapter carries both the workaround and the
evidence that the defect is real rather than theorised. `#866` is still owed: every second-act label
in this product is unreachable the same way, and the repair changes the `Command` protocol.

##### 5.9.27.3 A defect `LEN-A/4` shipped, found by wiring a fourth mode into the same method

`PlanEditorScreen` holds **one** outline controller for all plans. The field directly above it,
`_calibrate`, carries the reasoning in its own doc: *"A pick describes a distance on ONE raster and
cannot outlive a switch to another; `_openPlan` cancels it for exactly that reason."* The outline
controller was declared on the next line with no doc, and `_openPlan` was not extended.

So: two corners placed on one plan, a switch to another, a third click, and the shape closed with its
first two vertices measured on a different picture. **Nothing refused it**, because vertices are
integers and every raster has those.

Fixed here rather than filed, because it is one line in the method this chapter had to edit anyway,
and a test fails when it is reverted. Recorded in OKF as
[a field added beside a documented one inherits nothing](/practices/a-field-beside-a-documented-one-inherits-nothing.md).

##### 5.9.27.4 Eleven mutations, eleven kills

`#865` asks for the gesture proved *"through the real mounting rather than through a constructor the
product never calls, which is the failure this epic already shipped once at `PLAN-E/6`"*. Every case
went green on its first run, which is exactly when to distrust them, so eleven mutations were run
with the file restored in a `finally`.

The two that matter are the reachability pair: **the canvas handed a null mode**, and **the
`Reshape…` button wired to nothing.** Both killed four cases each. The other nine cover the label,
the `isUsable` guard that avoids `#863`, the no-op guard, nearest-corner selection, the swallow, the
re-derivation, and `planEstimateMayFill`.

One mutation was **skipped rather than counted**, on its first run, because its anchor appeared twice:
the estimate re-derivation reads identically in the draw path and the reshape path. It was re-run with
a unique anchor and killed. A skipped mutation reported as a pass would have been the shape this
corpus already names, which is a measurement that measured nothing.

##### 5.9.27.5 A judgement of the task, flagged as one

**A dragged corner tracks the pointer exactly** and does not keep the offset `_livePin` keeps. The
argument is that a pin is a marker with a body, grabbed anywhere on it, while a corner IS the point,
so a handle trailing the cursor by however far off-centre the press landed would have to be aimed
twice. It is a line to reverse, and §11.49.10 records it as the task's call rather than a ruling.

##### 5.9.27.6 Evidence

Floors: `rackpal_ui` 1723 to 1753, +30. Gates: 17.

**Commits** (§8.8). `#865` `50006b3`, `886b73d`, `61cf595`.

**LEN-A closed with this**, at `v0.6.56`, on its criterion rather than on its children running
out (§8.1): DR-050's deliverable is that plan geometry fills the room estimate, and it does.
Eight chapters rather than the six it was decomposed into, and **no child was re-parented
because none was open.** The Plan view epic has one story left, `PLAN-J`, which is a drill and
needs a person.

#### 5.9.28 `#649` parks on M6: the exit criterion named a sheet that does not exist · `DR-155`

2026-09-11. Not a chapter; a clause moving between two criteria, recorded here because §8.9 makes a
park a thing with a reason rather than a thing with a date.

##### 5.9.28.1 What was found, and when

The Plan view epic's exit criterion reads, in part: *"A person who has never seen the building is
handed the printed `T1.01` and the printed Pull Sheet, and locates every drop without asking a
question."*

**The Pull Sheet does not print.** Measured rather than assumed:

| Where a Pull Sheet would be | What is there |
|---|---|
| `SheetRole` | Four values: `devicePlan`, `rackElevationFront`, `rackElevationRear`, `equipmentList` |
| The rows | `SchedulePreset.pullSheet`, sorted `ScheduleSort.roomThenPathway`, a derivation |
| The renderer | `ScheduleScreen`, on screen |
| `rackpal_export` | Does not reference `ScheduleView` anywhere |
| A tabular export instead | `EXP-A`, DR-049, unstarted |

docs/12 already carried the fact in one sentence, written at DR-027's time: *"The sheet, the initial
boxes and the page are M6's under DR-027."*

**It was surfaced before the drill rather than during it**, which is the only part of this worth
congratulating: the alternative was a person with a printed `T1.01` in one hand discovering there is
nothing to put in the other.

##### 5.9.28.2 Why it is a ruling and not a board move

Roadmap §8.9 makes parking a formal act: **reassigned by ruling ID to a named later milestone, with
the structural reason.** A clause quietly moved on the board would be the deferral that rule exists
to prevent, and §8.1's *"the exit criterion is the unit of truth"* is what makes moving one an
amendment (§8.3).

DR-027 is the precedent the rule itself names, and it fits exactly: it split M3's Pull Sheet clause
on 2026-08-09, giving M6 the sheet and M3 the derivation. **The Plan view's criterion was written a
month after that split and named both printed artifacts anyway**, which is the ordinary way a
criterion goes stale: it was drafted against what the product ought to have, and the seam that said
otherwise lived in a different ruling.

##### 5.9.28.3 Where it differs from its precedent

DR-027 §11.26.3 concluded that *"M6's criterion needs no addition"*, because *"all four starter
projects export a complete set"* already contained the sheet. That reasoning does not carry here. A
**walkthrough is a demonstration, not an export**, and nothing in M6's criterion contains one, so M6
gains a clause rather than inheriting an obligation it already had.

Stating that explicitly is the difference between a park and a deletion. A clause moved to a
milestone whose criterion does not mention it is a clause nobody will run.

##### 5.9.28.4 What did not move

`PLAN-J/1` and `PLAN-J/2` stay, and with them every physical obligation this epic has: a real plan
and a real rough-in rather than a synthetic fixture, a real greyscale laser at ANSI B, and every
callout legible over the screened underlay (AC-054). **The stranger test moves because its second
artifact does not exist, not because it is inconvenient.**

##### 5.9.28.5 Evidence

Board: `#649` re-parented from `PLAN-J` (`#606`) to `M6-J` (`#357`), the story that already holds
this project's physical print tests on real hardware, which keeps the Saga → Epic → Story → Chapter
hierarchy legal and puts the drill beside the three tests it most resembles.

#### 5.9.29 `#863` and `#866`: the command machinery gets its contract · `DR-156` · no version move

`DR-156/1` (`#867`) and `DR-156/2` (`#868`), 2026-09-12. Both were found by `LEN-A`, filed rather
than fixed in flight, and both change the `Command` protocol every command in this product
implements.

**NO VERSION BUMP, AND THAT IS THE RULE RATHER THAN AN OMISSION.** docs/14 §14.0 makes the patch
*"major tasks completed within that epic"*, and the epic under development is the Plan view. These
close under `#786`, the cross-cutting debt epic. The precedent is in the tree: `477bc2e` closed
`PERF-G` under the same epic and touched no `pubspec.yaml` and no `kAppVersion`.

##### 5.9.29.1 The compiler was the census, and that was the point of the choice

Three shapes were put to the user. `bool apply(A)` changes 78 implementations across 40 files and
the compiler finds every one; an abstract `bool get applied` is additive but leaves two members that
can drift; a defaulted `applied` touches only the 24 that refuse and leaves a hole. **The user chose
the return type**, and the run bore the argument out: changing it produced **53 errors in exactly the
24 classes that can refuse**, each decided by reading it.

**19 of the 24 return their own `_applied` bit rather than a literal `true`**, which a regex would
have got wrong: `_writePin` can fail after every guard has passed, so `return true` there is a claim
where `_applied` is a fact.

##### 5.9.29.2 The sweep's first run ate a method

It treated the abstract declaration `void apply(A aggregate);` as an arrow body, walked past the
semicolon to the next `=>` in the file, and consumed `mergeWith`. The tree was reverted whole and the
script taught the case.

**A global rename also reached a commented-out sketch** in `snapshot_command.dart`, which is corrected
rather than reverted: the sketch now returns `true` unconditionally, and the comment says in terms
that this is a question for whoever builds it, because a snapshot whose `after` map equals what is
already there changed nothing.

##### 5.9.29.3 Thirteen analyzer infos fixed rather than pinned

Ten `join_return_with_assignment` became `return _applied = <expr>;`, which reads as *record and
report* and is better than what it replaced. Three `curly_braces_in_flow_control_structures` appeared
only because `return false;` is longer than `return;` and made an `if` wrap onto its own line. The
pin stays at 233.

##### 5.9.29.4 A test came due on a ruling ID

`LEN-A/2` shipped a case asserting the DEFECT, with an instruction: *"when a refusal stops reaching
the stack, this case fails and whoever fixed it inverts it to the assertion it was originally written
as."* It was **the one case in the repository that failed** when the drop landed.

That is the cleanest instance
[a test that asserts an absence names its due date](/practices/a-test-that-asserts-an-absence-names-its-due-date.md)
has: the due date was a ruling ID, and the test failed on the commit that made it wrong rather than
being found by a person reading old comments.

**One case was added beside it**, because an empty undo stack is a weak proof: it says a refusal
added nothing to nothing. The shape that cost somebody their work is a real edit, then a refusal,
then `Ctrl+Z`, which used to throw and take the stack with it.

##### 5.9.29.5 A mutation survived, and it found a rule nothing pinned

Four mutations were run against `#868`. Restoring the early label read killed three cases; ignoring
the caller's label killed one; keeping a refused child killed three. **Reading `children.last`
instead of `children.first` SURVIVED.**

The case meant to pin it had a refusal and one real command, so after the refusal was dropped
`children.first` and `children.last` were **the same object**. Nothing in the repository
distinguished which end of a transaction names it, and the two-child case is real: the rack canvas
stacks a library copy under an add and is named after the add. The case now stacks three children and
the mutation dies.

Recorded against
[a property proven by a fixture's default is not proven](/practices/a-fixture-default-is-not-a-proof.md),
whose scope this widens: it was about a fixture's default VALUE, and this is a fixture's SHAPE.

##### 5.9.29.6 What the tests read, and why it matters

Every existing label case in `plan_commands_test.dart` reads `command.label`, which is **correct
after apply** and is exactly why nothing caught `#866` for three chapters. The artifact a person sees
is `UndoStack.undoLabelKey`, and no case read it for a paired label. House style says assert the
artifact and not the mechanism; here the mechanism was asserted and the artifact was not.

##### 5.9.29.7 What was found that neither ticket named

- **Three more call sites pass a command's own `.label` into `transact`**, so they carry the defect's
  shape. None had the symptom, because the commands they pass have static labels. Two moved to the
  deferred form; `rack_canvas_screen.dart` keeps its explicit label because it names its transaction
  after its **second** child deliberately, and that is now written down where it happens.
- **`_outlineClick` was reporting the wrong act and nobody had filed it.** It passed
  `drawRoomOutline` by hand, so pressing `Redraw…` and closing a new shape said *"Undo Draw Room
  Outline"*. Deferring to the command fixed it as a side effect.
- **docs/14 §14.0's count of where the version lives was stale by one** since `rackpal_pdfium` joined
  the workspace at `PLAN-K`. The paragraph now names the gate instead of the number.

##### 5.9.29.8 Evidence

Floors: `rackpal_core` 4599 to 4605. Gates: 17. Analyzer pin unmoved at 233.

**Commits** (§8.8). The ruling `60fbc99`. `#867` `c4c314d`. `#868` `48b32f7`.

---

#### 5.9.30 `#869` and `#870`: the demo project finds two holes, and one command had been unreachable for four months · `DR-157`, `DR-029` · `v0.6.57`

Both reported by the user on 2026-09-12 while running the `PLAN-J` demo, which is the first time
this product has been driven end to end by somebody building a real project in it. Neither was found
by a test, a sweep or a census.

##### 5.9.30.1 `#869`: a reported success for a device that is not on screen

*"I can't seem to actually see rack devices as I populate a rack. They act as though they are
present, but don't appear to do anything."* Devices they had **authored** failed; seeded ones worked,
which is the fact that made it findable.

A probe built the body the device builder permits, `{frontU: 2, side: none}`, and ran
`buildPlaceFromCatalogCommand`. The result is `CatalogPlacementReady` carrying an
**`OffRackPlacement`**: the placement succeeds, reports success, and puts the device where nobody is
looking. Two surfaces disagreed about one fact, and the disagreement predates `DR-156` entirely.

`DR-157` refuses the body by name, and `§11.156.5` makes the builder derive the side as the height
is typed. **A save gate was tried first and broke `AC-049`'s three-required-fields case, which was
right to break**: a fourth required interaction is the stall that clause exists to prevent. The
attempt is recorded in the ruling rather than only reverted.

##### 5.9.30.2 `#870`: `RemovePlanUnderlayCommand` shipped at `PLAN-C/6` and nothing ever built one

*"I also have no way to delete device templates, or to delete floor plan pages."*

The command is declared, fully implemented, has a real revert, cascades the pins it orphans, clears
the room outlines drawn on it (`LEN-A/2`), carries the right epoch mask, and is constructed **seven
times in `plan_commands_test.dart` and zero times in any `lib/`**. The only way to not have a page
was to never have imported one, which makes a wrong page picked out of a multi-page PDF permanent for
the life of the project.

**THE FOURTH INSTANCE OF THE SHAPE**, after `DR-143`, `#674`, `PLAN-E/5` and `LEN-A/3`. The `#674`
gate (`actions_have_callers_test.dart`) covers function-typed fields on `*Actions` records in
`rackpal_ui/lib`; a `Command` class is neither a callback nor in that package, so nothing could see
it. `#872` is the widening.

`planUnderlayRemoval` is new and the command now clears from it rather than walking the four
collections inline, which is `delete_location_dialog.dart`'s rule: the number the dialog states and
the set the edit removes are one object. The refactor is behaviour-preserving, and all fifty-five
existing plan-command cases pass untouched.

##### 5.9.30.3 Evidence

Floors: `rackpal_core` 4612 to 4615, `rackpal_ui` 1758 to 1764. Gates: 17. Analyzer pin unmoved at
233. Three mutations on `#870`, three kills, the first being the Remove button wired to nothing,
which kills five cases.

**Commits** (§8.8). `#869`'s refusal `1feb958`, its builder half `7e9b662`. `#870` `ff0707e`. The
version `55c837b`.

**THE VERSION RULE NEEDED RESTATING TO COVER `#870`.** `#865`'s bump counted *"Done Chapters under
`#588`"* and got 56, which was correct and is not general: `#870` is a leaf **Story** under the Plan
view epic and counting Chapters alone would have shipped a feature with no version move. docs/14
§14.0's own words are *"major tasks completed within that epic"*, which does not say Chapter. The
re-runnable count is **Done items under `#588` with no children, less the `PLAN-0` decomposition
item**: 57 - 1 = 56 before, 57 after. Both readings reproduce 56 for the previous build, which is the
check that makes this a clarification rather than a change.

---

#### 5.9.31 `#873` and `#871`: two delete counts, one of them already shipped wrong · `DR-013`, `DR-158` · no version move

2026-09-12, the second half of the `PLAN-J` demo report. `#871` is the template half of *"I also have
no way to delete device templates"*; `#873` was found while building it.

**NO VERSION BUMP.** Both close under `#786`, the cross-cutting debt epic, which is not the epic
under development. The precedent is `477bc2e` and the reasoning is §5.9.29's.

##### 5.9.31.1 `#873`: the dialog said six and the delete removed three

`DeleteDeviceDialog._cableTotal` was `plans.fold((sum, plan) => sum + plan.cableCount)` over one
`DeviceRemovalPlan` per selected device. `planDeviceRemoval` asks *"which links land on THIS
device"*, and a `Link` terminating on ports of two selected devices answers yes at each end, so it is
in **both** plans. The transaction removes it once.

**THIS IS THE FAILURE `§11.13.2` NAMES, ARRIVING FROM THE FRIENDLY SIDE.** The ruling: *"a dialog
that said '4 cables' and removed 5 would be worse than no dialog."* Saying 6 and removing 3 is the
same broken promise, and frightening the reader is not better than surprising them. Selecting both
ends of a run is an ordinary gesture: a switch and the access point it feeds, an amplifier and its
speaker.

**PROVEN BEFORE IT WAS CLAIMED.** The widget case was written first and watched fail on the old code,
against a fixture whose three cables run between the two devices under test. The plans were right and
the arithmetic was wrong: `cablesAcrossPlans` is the union and lives in core beside the planner, so
`delete_device_dialog.dart`'s own rule that *"the count is not computed here"* still holds.

The per-device breakdown keeps its honest per-device numbers and gains one sentence, shown only when
there is an overlap: *"2 of them run between devices in this list, and are counted once."*

Three mutations, three kills. The third, a shared count stuck at zero, is killed **only** by the
end-to-end case that presses `Ctrl+click` and `Delete` through the real screen and then asserts the
stated number equals the number the transaction removed. A dialog test alone cannot see that, and it
is the entire content of what the ruling promises.

##### 5.9.31.2 `#871`: nothing existed at all, which is what separates it from `#870`

No `Remove`/`DeleteTemplate` class anywhere in the tree; `doc.templates.remove` appears only inside
revert bodies undoing a save or a fork. So this needed a ruling and not a wire.

`DR-158` settles four things, three of them the user's, and §11.157 carries the arguments. The one
that is mine to state rather than to choose is §11.157.1: docs/06 §7.1's *"library operations are not
undoable"* governs the **shelf**, which is M4-N and does not exist, and a per-project embedded
snapshot is project data, so removing one is a document edit.

**THE CASCADE WAS OFFERED WITH ITS COST AND THE USER TOOK IT.** The recommendation here was a refusal
naming the count; the answer was to remove the devices too. `DeviceInstance.templateRef` is the
**only referent in the entire model**, so the cascade has exactly one edge, and leaving the devices
was never available: CR-054 says a `TemplateRef` always resolves and a device with no snapshot has no
body to draw.

**AND IT ALWAYS ASKS**, which is where this departs from the four removal plans before it.
§11.157.5: authoring a template is minutes of work that exists nowhere else in the project, so
DR-013 §11.13.2's exemption for the consequence-free delete does not reach it. The prompt is shorter
when nothing stands on the template. It is not absent.

##### 5.9.31.3 A fixture's default stood in for a proof, for the fourth time

The browser card's `InkWell` carries `onDoubleTap` whenever `onEdit` is non-null, which puts a
`DoubleTapGestureRecognizer` in the gesture arena and holds it open past a bare `pumpAndSettle`.
`device_browser_screen_test`'s own fixture defaulted `onEdit` to **null**, so it built no such
recognizer, every press in it landed, and the same press through the shipped shell did **nothing**.

That is `#872`'s shape arriving as a false positive from the other side: a control that tests as
wired and behaves as unwired. Both suites now press through the arena the product actually builds,
and the helper that does it carries the reason.

##### 5.9.31.4 And undo turned out to be reachable from one tab (`#874`)

Found when the `#871` shell case pressed `Ctrl+Z` on the Device Manager and nothing happened.
`UndoIntent` and `RedoIntent` each have **exactly one handler in the entire tree**, inside
`RackCanvasScreen`'s own `Shortcuts`, and the application has one menu, `File`, with no Undo item
anywhere. **The strip is SEVEN tabs**; undo works on one. This paragraph said six when it
was written, hours before `#874` was built, which makes it the fourth copy of a tab count to go
stale in this repository and the only one whose subject was tab counts going stale (§5.9.33.2).

**THE CODEBASE ALREADY KNEW AND ITS NOTE IS STALE BY THREE.** `rack_canvas_screen.dart` carries
*"`Ctrl+Z` still reaches nothing at all on the Schematic and Schedule tabs. Widening the scope is a
rebinding and belongs to a ruling; the note exists so it is a decision somebody takes rather than a
fact nobody noticed."* It names two. It has been five since `DR-091` reordered and extended the
strip. A count written in prose went stale exactly the way this corpus keeps finding.

It matters more now than when the note was written, because **every** destructive confirmation in the
product ends by promising undo, and three of the four are reached from tabs where `Ctrl+Z` does
nothing. The promise is true of the stack and unreachable from where the person is standing, which is
worse than either. This is very likely what the user meant on 2026-09-12 by *"undo doesn't appear to
work anywhere across the program currently"*, which was recorded as a side observation during the
`#869` investigation and not followed up.

##### 5.9.31.5 Evidence

Floors: `rackpal_core` 4615 to 4636, `rackpal_ui` 1764 to 1781, `rackpal_app` 985 to 991. Gates: 17.
Analyzer pin unmoved at 233.

Mutations: three on `#873` with three kills, six on `#871` with six kills. `#871`'s first two are the
ones the item exists for: the control wired to nothing kills five cases, and a row that skips the
project-authored check kills four.

**Commits** (§8.8). The ruling `77ff3bc`. `#873` `cd75b69`. `#871` `d81ef0b`.

---

#### 5.9.32 `#872`: the reachability gate, and what it found on its first run · no ruling · no version move

2026-09-12, asked for by the user immediately after `#870`. It closes under `#786` and moves no
number.

##### 5.9.32.1 A gate for a shape that has shipped five times

`DR-143`, `#674`, `PLAN-E/5`, `LEN-A/3`, `#870`. Every one compiles, analyses clean and has green
tests, because the class **is** used: its own suite constructs it. Nothing in Dart can require that a
person can get to it, and every one of the five was found by somebody using the product rather than
by anything in the repository.

##### 5.9.32.2 Three greps were wrong before the graph was right

Each was caught only by checking an answer somebody already knew, which is why the shipped gate
asserts five of them before it reports anything:

| Attempt | What it did | How it was wrong |
|---|---|---|
| 1 | matched `Name(` | missed every **named** constructor; reported `SetRoomEstimateCommand` unreachable on the day it was wired, with six production references |
| 2 | counted any mention in another lib file | a name in a **comment** counted as use, and `RemovePlanUnderlayCommand` fell off the list entirely |
| 3 | counted constructions by name | 24 of 72, still wrong: this codebase builds most commands through `buildXCommand`, so a command built only by its own builder reads as unreachable while the **builder** is what has callers |

The shipped model is a graph: a node is a top-level declaration in any `*/lib/**.dart`, an edge is
"D's body names E" outside comments and strings, roots are every declaration in a UI package, and a
Command is reachable when some declaration that **constructs** it is reachable from a root.
`addTemplateRemoval` is the worked example, and the transitive hop attempt 3 could not make.

##### 5.9.32.3 The prototype's own splitter was wrong, and the COUNT is what caught it

A character class containing a whitespace class let an **indented method** match as a top-level
function. 439 files produced **18,222** "top-level" declarations, 41 per file, and **49 of 73**
commands came back unreachable with **zero** construction sites, `MoveDeviceCommand` among them,
which the rack canvas builds on every drag.

Nothing about the output said "broken". It said "49 unreachable", which is a number somebody in a
hurry would have believed and filed 49 tickets against. The corpus-size band in the shipped file is
that failure written down as an assertion, and it is asserted from **both** directions: too few
declarations means the splitter stopped matching, too many means it is matching methods.

##### 5.9.32.4 Twelve are unreachable, and the largest finding is not a command

Each was verified by hand before it was filed. `#875` through `#881`.

**`#875` is the one worth reading.** `ValidationDrawer` declares `onAcknowledge`, `onWithdraw` and
`onRemedy`, passes all three to `DrcPanel`, and `DrcPanel` renders a button for each when it is
non-null. There is **exactly one mount** of `ValidationDrawer` in the product, at
`rack_canvas_screen.dart:4602`, and it passes **none of the three**. Each is nullable and documented
as *"null shows no button rather than a dead one"*, so the buttons are absent and nothing fails.

What that makes unreachable: `AcknowledgeFindingCommand` and `UnacknowledgeFindingCommand` (M5-B2,
with a real revert and a signed reason), and PWR-003's entire remedy chain. `addOutletsToRack` is
declared in `add_outlets.dart`, **tested in two suites including one in `rackpal_ui`**, and called by
no lib code at all, which takes `AddZeroUChannelCommand` down with it.

The rest: `#876` 0U channels have no surface at all, though AC-044 names the inspector as the only
route; `#877` an outlet and a structure can be added and neither removed; `#878` a plan pin cannot be
cleared and pages cannot be reordered, while `LabelKey.clearPlanPin` exists and argues for its own
value; `#879` `ruleOverrides` rows carry a reason, an author and a date, all persisted, none
writable; `#880` `SnapshotCommand`, the only one of the twelve with **no tests either**, so the first
question is whether it should exist; `#881` `AddLinkCommand`, 21 test constructions and the
hypothesis that it is superseded rather than missing.

**TEN OF THE TWELVE WERE REAL, AND THE LAST TWO WERE THIS GATE'S OWN BUGS** (DR-161, §5.9.37).
`SnapshotCommand` is not declared anywhere: the inventory read raw files while the declaration scan
read stripped ones, so a sketch inside a `//` comment entered the corpus. `AddLinkCommand` is
declared, is used twenty-one times, and is deliberately not for a person. Both were filed as tickets
against the tree on this gate's word, which is the cost of a census that is read as a fact.

##### 5.9.32.5 The gate's scope is stated, because a scope is part of a claim

**Every declaration in a UI package is a root**, which is an over-approximation and a deliberate one:
deciding which widget is actually mounted needs a build graph this scan does not have, and a gate
that guessed would cry wolf.

So a command built by a UI method nothing calls reads as reachable, and so does one behind a callback
parameter no mount supplies. The gate sees `#875`'s commands only because nothing constructs them
anywhere, not because it understood the mount.

That half belongs to `actions_have_callers_test.dart`. **Between them they still leave a hole**: that
gate reads `*Actions` records in `rackpal_ui/lib` only, so a widget taking loose callback parameters
is outside both. `#875`'s second half closes it.

##### 5.9.32.6 The exemption list is the risk, so three cases guard the list rather than the tree

`.okf/practices/a-tests-exemption-list-is-where-the-bug-lives.md`. An exemption whose value is not a
board item fails; an exemption that has become **reachable** fails, so the list cannot rot into a
record of things that were true once; and an exemption for a deleted class fails, because a line
nobody can act on is worse than no line.

##### 5.9.32.7 Evidence

Floor: `rackpal_app` 991 to 996. Gates: 17, unchanged, because this runs inside the `rackpal_app`
suite rather than as its own `Invoke-Gate` step.

Five mutations, five kills. The second is the one the item asked for by name: **the construction site
stays and only the path from a person to the builder is removed**, which is the transitive case. Also
killed: un-wiring `#870` again, a stale exemption, an exemption naming no board item, and the
splitter regaining its indented-method bug.

**Commits** (§8.8). `#872` `5f9f7c9`.

---

#### 5.9.33 `#874`: undo reaches every tab, the Edit menu arrives five milestones late, and a count went stale in four places · `DR-159` · no version move

2026-09-12. Reported by the user while running the `PLAN-J` demo: *"Undo doesn't appear to work
anywhere across the program currently."* It closes under `#786` and moves no number.

##### 5.9.33.1 One handler, seven tabs

`UndoIntent` and `RedoIntent` had **exactly one handler in the entire tree**, inside
`RackCanvasScreen`'s own `Shortcuts`, and the application had one menu, `File`, with no Undo item
anywhere. So the only route to undo in the product was the Rack tab.

**THE INTENT WAS ALWAYS RIGHT AND ONLY THE INSTALLATION POINT WAS WRONG**, which is what makes this a
five-minute fix that took five milestones to reach. That handler's own comment: *"the key is
DOCUMENT-GLOBAL. Undo and redo must keep working from the palette, the inspector and the toolbar;
scoping them to the canvas would reintroduce the exact defect app_shell.dart's header post-mortems
for `Ctrl+S`."* The registry row said the same thing from the other side and named the remedy:
*"promoting it to `KeyScope.global` is a rebinding and belongs to a ruling."*

##### 5.9.33.2 The count that went stale in four places, one of them written today

| Where | What it said | What was true |
|---|---|---|
| `rack_canvas_screen.dart` | *"`Ctrl+Z` still reaches nothing at all on the Schematic and Schedule tabs"* | six of seven |
| the keymap registry's `undo` note | the same sentence | the same |
| `main.dart`'s header | *"THE THREE-TAB STRIP, AND WHY TWO OF ITS TABS ARE INERT"*, with Schematic and Schedule rendering `UnbuiltView` | seven tabs, none inert, both `UnbuiltView`s gone at M2-E |
| this ruling's first draft | six tabs | seven |

All four were true when written. `DR-091 §11.90.3` reordered the strip into job order and added
Locations, Device Manager and Structured Wiring; `PLAN-E/5` added Plan. **No copy moved either time.**

The fourth row is the one worth keeping: a count went stale inside the paragraph being written about
counts going stale. None of the four now carries a number. `ShellView.values` is the list and
`app_shell.dart` builds the strip from it.

##### 5.9.33.3 Two handlers stay, and neither is a duplicate

Flutter resolves an `Action` from the focused context upward, so a nearer one wins and the shell's is
the fallback.

**`RackCanvasScreen`** keeps its own because `undoLast` returns the selection as it was and only that
screen can restore it: without it, undoing a delete leaves somebody staring at an empty inspector.

**`DeviceBuilderScreen`** keeps its own because there are **two undo stacks**. CR-106 scopes the
builder's to the `TemplateBody` and it dies with the window; `KeyScope.builder`'s note already refused
to share a scope with the canvas because *"a scope shared with the document's canvas would say the two
stacks were one thing"*. It had Undo and Redo **buttons** since M4-A/4 and no key binding at all, so
`Ctrl+Z` was dead there too, on a second stack.

**So one key means two things on one tab**, chosen by the user over the alternative of always taking
the document's stack, which would have undone something in the project behind the window. The Edit
menu makes the mode readable: while the builder shows, the menu names a template act.

##### 5.9.33.4 The Edit menu was specified at M0 and never built

docs/03 §13.3: *"The Edit menu shows a localized 'Undo Move device'; the log shows the stable enum
name."*

**`LabelKey` HAS 101 VALUES AND MANY EXIST ONLY BECAUSE OF THIS MENU.** `commitPortSort` is its own
value rather than `reorderPorts` because *"'Undo Reorder' in front of somebody who has just been
through a confirm dialog names the wrong act"*. `clearRoomEstimate` is split from `setRoomEstimate` so
the menu cannot name the opposite act. `drawRoomOutline` and `reshapeRoomOutline` are one command with
two labels chosen at apply time. That is a great deal of careful argument about the wording of a
surface nobody could see.

The map is **explicit and gated** rather than derived. De-camel-casing is one line and produces
*"Remove Template From Project"*; it is worse than useless for precisely the values above, whose whole
point is that the obvious wording names the wrong act. A parity gate fails when a value has no entry,
and there is no fallback, on DR-156 §11.155.1's argument that a default is a hole.

**IT IS NOT LOCALIZED AND THE RULING SAYS SO.** §13.3 also asks for `AppLocalizations` from the first
commit and `l10n.yaml` in CI; neither exists in this tree. A menu built against half a specification
has to record which half, or the built half reads as the whole.

##### 5.9.33.5 The per-tab sweep found the fix incomplete, which is why it is a sweep

The Structured Wiring tab still did nothing. Its `Add drops` box carries `autofocus: true`, because
typing a drop is what somebody comes to that tab to do, and `_submit` refocuses and clears it after
every entry. So a text field held focus permanently, `DefaultTextEditingShortcuts` sits nearer a
focused field than the app's own `Shortcuts` and claimed `Ctrl+Z` for `UndoTextIntent`, and with
nothing typed there was nothing to restore.

**The complaint survived inside its own fix**, on the one tab whose primary verb is bulk data entry.
An empty box now forwards the key; a box with text keeps it. The user chose that over dropping the
autofocus, which would have bought a flat rule by taking away the reason the tab is fast.

**AND THE SHELL'S OWN TEXT-FIELD GUARD WAS REMOVED RATHER THAN WEAKENED.** The first draft of
`undoFromShell` copied `RackCanvasScreen`'s `!_textFieldHasFocus`. It is **redundant**, because a
focused field's nearer binding consumes the key before `UndoIntent` is ever raised, so reaching that
method already proves no field claimed it; and it is **harmful**, because it would have caught the
forward above and thrown it away. A guard that re-asks a question the dispatch has already answered
can only get it wrong.

##### 5.9.33.6 Thirty-nine cases were green in a configuration the product does not ship

They pumped `RackCanvasScreen` under a bare `MaterialApp` and got `Ctrl+Z` from the rack scope, so
they proved undo worked on a screen mounted a way nothing mounts it. `test/app_like.dart` now hands
them the root's shortcut map.

That is the **fourth instance in a week** of a fixture standing in for a proof, and the second this
session: `#871`'s browser card built no double-tap recogniser because the fixture left `onEdit` null,
so every press landed in the test and none in the shell.

##### 5.9.33.7 Two gates caught the move and both were right to

`keymap_arbitration_test`'s per-scope counts moved **10 to 13 and 16 to 13**, in opposite directions
by the same three, which is the shape of a move rather than a growth.

`session_layering_test`'s **RULE 14** failed because a global binding is a decision and adding one
means taking it again. Its own name said *"exactly two complete keybinding groups"* while the comment
beneath it said three, and neither moved when `#847` made it three; the count now lives only in the
list it asserts.

##### 5.9.33.8 Evidence

Floors: `rackpal_ui` 1781 to 1790, `rackpal_app` 996 to 1015. Gates: 17. Analyzer pin unmoved at 233.

Six mutations, six kills. The first is the defect itself put back, the binding returning to
`KeyScope.rack`, and four tabs go red.

**Commits** (§8.8). `#874` `241222a`.

---

#### 5.9.34 `#875`: the validation drawer had three callbacks and one mount that passed none, and the feature had been built three times · `DR-128`, `DR-129`, `CR-019` · no version move

2026-09-12. Found by `#872`'s reachability gate on the day it landed, which is the first thing in this
repository that could see it. It closes under `#786` and moves no number.

##### 5.9.34.1 One mount, three callbacks, none supplied

`ValidationDrawer` declares `onAcknowledge`, `onWithdraw` and `onRemedy`, passes all three to
`DrcPanel`, and `DrcPanel` renders a control for each when it is non-null. There is **exactly one
mount of `ValidationDrawer` in the product** and it supplied none of them.

Each is nullable and documented as *"null shows no button rather than a dead one"*, which is a good
rule and is what made this invisible: the controls were **absent**, not broken. Nothing rendered,
nothing threw, and every suite stayed green.

##### 5.9.34.2 The feature was built three times and reachable none of them

| Round | What was ruled | What shipped |
|---|---|---|
| DR-128 §11.127.5 | the issues panel *"renders it as a button"* | `drc_panel.dart` never read `Finding.remedy` |
| DR-129 §11.128.4 | recorded that, built the button, added `remedy_pairing_test.dart` as the backstop | the button had nothing behind it |
| `#875` | the mount supplies all three | and a gate for the layer above |

**THE BACKSTOP WAS WRITTEN AT THE WRONG LAYER, WHICH IS THE LESSON.**
`remedy_pairing_test.dart` asserts that every `FindingRemedy` value reaches a row a person can press,
and it passes: the row does render the button. What it cannot see is whether the callback behind the
button was ever handed over, because it constructs `DrcPanel` itself and supplies one.

##### 5.9.34.3 What was unreachable

`AcknowledgeFindingCommand` and `UnacknowledgeFindingCommand` (M5-B2), both with real reverts and
their own suites. `showAcknowledgeFindingDialog`, `showWhyRuleDialog` and `showRuleSeverityDialog`,
all three built, exported from the barrel, and called by nothing. And PWR-003's whole remedy chain:
`addOutletsToRack` is tested in **two** suites, one of them in `rackpal_ui`, and called by no lib code
at all, which took `AddZeroUChannelCommand` down with it.

**AND THE TWO FILTERS WERE THE SAME DEFECT AGAIN, IN THE SAME FEATURE.** `DrcPanel` renders the
severity chips and the `Acknowledged` toggle, `groupFindings` already takes `severities` and
`includeAcknowledged`, and the drawer passed neither the state nor the callbacks. Both controls were
drawn and neither could move. `SpringBackChipCard.onWhy` makes six: its viewer and
`RuleMeta.rationale` were built at `#296` against a button nobody supplied.

##### 5.9.34.4 A third gate, and it lands with an empty exemption list

Three questions, three gates, and none of them subsumes another:

| Gate | Asks |
|---|---|
| `actions_have_callers_test.dart` (`#674`) | is a declared callback **invoked**? `*Actions` records in `rackpal_ui/lib` only |
| `commands_have_callers_test.dart` (`#872`) | is a Command **constructed** on a path from a UI package? every UI declaration is a root |
| `callbacks_have_suppliers_test.dart` (`#875`) | is a widget's nullable callback ever **handed over** by a mount? |

`#872`'s own header already named the hole this fills, which is why it took a day rather than a
milestone to find.

**MATCHING BY PARAMETER NAME ALONE WOULD HAVE MISSED THE VERY DEFECT IT IS FOR.** `onRemedy:` *is*
supplied somewhere: the schematic passes one to `SpringBackChipCard`. A gate that grepped the name
would have called the drawer's supplied. So a supplier is a construction **of that widget** whose
argument list names the parameter, taken by counting parentheses, and a case asserts that property
rather than describing it.

The first run found six. **All six were wired rather than exempted**, so the list is empty on the day
it ships, which is the strongest state a new gate can be in: nobody has to be talked out of believing
it.

##### 5.9.34.5 `#872`'s staleness check earned its keep on its first outing

Wiring the drawer made three exempted commands reachable, and the check named all three. Two were the
ones being worked on. The third was **`AddZeroUChannelCommand`, exempted against `#876`**, which
nobody was thinking about: PWR-003's remedy mints a 0U channel.

Its row is gone. `#876`'s two remaining rows now say what is still owed, because a channel minted as a
**remedy** is not AC-044's clause about a person creating one, and the ticket says so rather than
being quietly narrowed.

##### 5.9.34.6 One mutation became a deletion and the other became a case

A re-check of `evaluateAcknowledgement` written into the shell **survived being mutated away**.
`.okf/practices/a-guard-the-model-makes-unreachable.md` is explicit about which way that reads: the
dialog computes the same verdict from the same three inputs and makes its confirm `onPressed` null on
a refusal, so a choice coming back from it is allowed by construction, and that invariant is pinned
where it lives by `acknowledge_finding_dialog_test.dart`'s *"a project-wide mute is refused until a
reason is written"*. The guard is deleted and the invariant is named in its place.

The second survivor read the other way. Dropping the `projectWide ? null` ternary, so a project-wide
mute kept the rack it happened to be raised on, survived because **nothing exercised CR-019's second
scope at all**. That got a case.

##### 5.9.34.7 Evidence

Floors: `rackpal_ui` 1790 to 1799, `rackpal_app` 1015 to 1020. Gates: 17. Analyzer pin unmoved at 233.

Six mutations, six kills. The first is the defect itself put back: the mount stops supplying the three
callbacks and six cases go red across two packages.

**Commits** (§8.8). `#875` `ccde720b`.

---

#### 5.9.35 `#879`: a rule's severity can be overridden, and three mutations wrote three of the tests · `CR-019`, `RJ-006` · no version move

2026-09-12. Found by `#872`'s reachability gate. It closes under `#786` and moves no number.

##### 5.9.35.1 Built at M5-B3, reachable from nowhere

`SetRuleOverrideCommand` shipped with a real revert and eight test constructions.
`showRuleSeverityDialog` shipped with its own suite. `RuleOverride` carries a severity, a reason, an
author and a date, all four persisted and all four printed on `T0.02`. **Nothing opened the dialog.**

That is the fourth capability in three days found complete and unreachable, after `#870`, `#871` and
`#875`. The shape does not vary: the model, the command and the surface are each tested by somebody
who supplied the piece above them.

##### 5.9.35.2 Project settings, and the argument is in the corpus already

Three places were put to the user. `evaluateRuleOverride`'s own comment settles it: *"An override is a
standing decision about a rule for the whole project."*

The issues drawer was the tempting one, because that is where the rule annoys you. It was refused on
a hazard worth naming: `#875` had just made the acknowledge dialog reachable, and that dialog already
offers a **project-wide mute**. Putting a second project-wide hammer one click away invites reaching
for the bigger one, and the two are not the same act. A mute says *this finding is noted*; an
override says *this rule counts as X here*.

The settings dialog is where a reader looks for what the project has decided, and its own header
already says these *"live in the project file, so they travel with it. Every change is undoable."*

##### 5.9.35.3 Three mutations wrote three of the tests

| Mutation | What it exposed |
|---|---|
| the picker stops filtering tier 1 | **the UI test was vacuous.** That list is virtualised, so a tier-1 row below the fold is never built and `findsNothing` passes whether the rule was excluded or merely out of sight |
| the shell hands over no author | **nothing asserted the signature.** The widget test passes its own actor, so the shell's wiring was covered by nobody |
| `use the default` records an override | **the dialog's own distinction was untested.** Its typedef says a severity equal to the default is a different act from choosing the default |

**THE FIRST ONE MOVED CODE RATHER THAN ADDING A CASE.** The question "which rules may carry a
standing decision" is a fact about the catalogue, not about a widget, so `overridableRules` now lives
in `rule_exception.dart` beside `ruleAcceptsAnException` and is tested over every rule **in both
directions**: no tier-1 rule is offered, and every rule that is not tier 1 is. An exclusion check
alone would pass over an empty list.

##### 5.9.35.4 A fourth mutation measured nothing and was repaired rather than counted

It wrote `Severity.info`, which is not a value in that enum. The run failed to **compile** and the
runner reported it as a kill. `.okf/practices/a-mutation-that-did-not-build.md` records the same
hazard pointing the other way, where a non-building mutation reports as SURVIVED; the rule is
direction-independent. It was fixed to use `Severity.off` and re-run.

##### 5.9.35.5 A name collision worth writing down

The row widget's field was called `override`, which **shadows the top-level `override` annotation
inside its own class**, so `@override` on `build` stopped resolving. The analyzer's message is
*"Undefined name 'override' used as an annotation"*, which names the symptom and not the cause, and
points at the annotation rather than at the field twelve lines above it. It is `current` now, matching
`showRuleSeverityDialog`'s own parameter, and the comment says why so nobody renames it back.

##### 5.9.35.6 Evidence

Floors: `rackpal_core` 4636 to 4639, `rackpal_ui` 1799 to 1805, `rackpal_app` 1020 to 1022. Gates: 17.
Analyzer pin unmoved at 233.

Six mutations, six kills. `#872`'s exemption list loses another row, its third retirement in two days.

**Commits** (§8.8). `#879` `56d96565`.

---

## 6. The dependency graph, as it actually stands

### 6.1 What can be worked on now

Entries 1–8, 7a, 10 and 11 need **no milestone's output at all**, and every one of them is a
**mechanism that would have caught a defect this project has already shipped**, which is the
argument for doing them first. **Entry 9 is the exception and is marked as one**: M4's gate is a
hard block that this board's own §3 says is not discharged. It is listed here because its inputs
exist, not because it is ungated, and the *Gated on* column says which.

| # | Work | Gated on | Why it is first |
|---|---|---|---|
| 1 | **Stand up CI at all**: **WRITTEN, NOT RUN** · **scheduled M5** | Nothing blocks it; it is **deferred by choice**, not gated | `azure-pipelines.yml` and `tools/ci/run_local.ps1` are **fourteen gates** in the same order (`DR-017`), so green locally and green on the agent would mean the same thing. **The row does not close**, by this section's own standard: no Azure DevOps service has executed the YAML, so nothing yet rejects a push. **The user scheduled run 1 for M5, 2026-08-03.** Distinguish the two words carefully: this work is *unblocked* and *unscheduled-until-M5*, which is not the same as gated, and it does not belong in §6.2. Closes when a run number can be cited here (§4.1). Board #567 |
| 2 | ~~**Decide the two failing gates** (format the files and clear the infos, **or** amend docs/11 §7~~) **DECIDED 2026-08-03, `DR-017`** | Nothing; it was a **user decision**, not an engineering one | **Both, split by gate.** `dart format` adopted absolutely (`b6ff394` formatted 124 files, `ecdf3b2` gated it); the analyzer kept its ratchet, pin lowered 194 → 173; docs/11 §7 amended, having described a GitHub Actions workflow the project does not use. The predicted failure did not occur: main was never red (§4.1). Board #566 |
| 3 | **First goldens + `flutter_test_config.dart` registering Jost** | Nothing | Makes *"goldens pass"* stop being a clause with nothing behind it (§4.3) |
| 4 | **Mechanise the `sources.md` provenance gate** | Nothing | AC-052 is prose today; `RISK-04`'s early warning is unmeasurable (§4.4) |
| 5 | ~~**Extend `epoch_mask_test.dart` to the derived pipeline**~~ **PAID `38167ec`, 2026-08-27** | Nothing | Was *"live and grows with every derived consumer"*. Closed with M0's clause 5 (`#507`): the derived outputs fold into the same changed-key set, and a source-reading field count stops the projection falling behind the classes it reads |
| 6 | **Propagate the Jost and `kSchemaVersion`-2 drift** into docs/08, docs/11, docs/02, docs/03 and canon; amend CR-080 | Nothing | Roadmap §8.3 requires an amendment for a ruling change; CR-080 has none (§4.6, §4.7) |
| 7 | ~~**Propagate DR-006 into docs/09, docs/11, docs/10 and docs/00**~~, **PAID `e0941f6`** | Nothing | Was **nine** sites, the five signing sites plus four decision-count sites, listed in §4.11 and canon §12.9. The decision-count class recurred within days and was paid again at `69aa82d`, which found six more stale counts including a docs/09 §8.7 sentence listing four already-closed questions as open. **A count in prose is a maintenance liability**, and this is now the second sweep for it |
| 7a | **Delete the three root `test/fixtures/` copies** | Nothing | Five seconds (§4.12) |
| 8 | **Finish M1**: ~~`AddRackCommand` + New-rack dialog~~ (built); ~~keyboard deselect~~ (built) **but time the drill**; ~~print a sheet~~ (done 2026-07-27); the outline tree | Nothing | One exit clause and one goal clause, and the exit clause needs a **person with a stopwatch**, not code (§3.4) |
| 9 | **M4, the device builder** | **M1: a hard block (roadmap §5), DISCHARGED 2026-07-28** | Its inputs were all present long before its gate opened: the arrow's named artifact (*"devices exist"*) is there, and clause 3's keyboard-only drill was never a device-builder input (§5.3). The gate is now clear on the criterion, which is the only thing §8.1 lets a gate depend on. It still sits below M2 here on ordering grounds, not blocking ones |
| 10 | ~~**A perf harness** (`@Tags(['perf'])`, op-count-per-layer)~~, **BUILT** | Nothing | Was: *"M2's exit criterion demands a measurement; there is no instrument"*. `packages/rackpal_core/test/scene/schematic_perf_test.dart` is that instrument, tagged and unexcluded so it runs on every push (§5.1) |
| 11 | **Recruit beta integrators** | Nothing but calendar | `RISK-08` lead time (§5.8) |

**Removed from this list by DR-006:** *"order the Windows OV/EV certificate now"*, which the
pre-DR-006 dependency graph made the twelfth entry here because `RISK-07` prices it in weeks of
external identity verification. Self-signing has no lead time and Microsoft Trusted Signing has no
reputation ramp, so it moves back to M8 where it belongs. **This is the single largest calendar
saving DR-006 buys.**

### 6.2 Gated, and correctly so

```text
 M0 ● CRITERION MET — weakest mark DEMONSTRATED
  │  8 of 8, as of 2026-08-27. `templates.keys` and the
  │  epoch-mask letter were VACUOUS only while their subjects
  │  did not exist; M4-S and the derived pipeline supplied both,
  │  and #513 / #507 closed them (§2.2, §2.4, §4.5 row 5)
  ▼
 M1 ● CRITERION MET — weakest CONFIRMED ────┬────────────────► M4 ○ NOT STARTED
  │  8 of 8 clauses discharged; the GOAL     │                  gate CLEAR (M1 met);
  │  line "ships to real users" is not;      │
  │  outline tree owed to M7                │                  inputs all PRESENT (§5.3);
  ▼                                         │                  DR-003 keeps it in v1
 M2 ○ not started                           │ DiagramCanvas IR + both backends
  │  router deleted b560a50; needs          │ + parity gate GREEN  ──► makes M6 cheap
  │  derivation + router + perf harness     │
  │  BEFORE the canvas                      │
  ├──────────────► M3 ○  (Link + Endpoint in the UI)
  └──────────────► M5 ○  (findings need a wired graph)
                     │
 {M2, M3, M5} ───────┴──────► M6 ○ NOT STARTED — 0 of 5 clauses, a THREE-WAY JOIN
                                   │            3 of 12 slots are built and real; no
                                   │            clause of the criterion is discharged
                                   ▼
                              M7 ○ (surfaces frozen; owed M1's outline tree)
                                   │
                                   ▼
                              M8 ○ (DR-006: no external cert dependency)
                                   │
                                   ▼
                              M9 ○ (nothing installable ⇒ nothing testable)
```

**No milestone on this graph is `COMPLETE`.** M0 is the closest, and it is two vacuous clauses short
of it. §2.4 says what would close them, and the two are not equally cheap: the epoch-mask extension
is a day's work available today, while `templates.keys` cannot become real until a command touches
`doc.templates`, M4, or M1's copy-on-place. **So M0's headline cannot go green on the strength of
this board alone, and ◑ must not be read as ✔.**

**Do not start M3 or M5 early.** M3 needs `Link` + `Endpoint` present in the UI before a drop can
become a home run; M5's findings need a wired graph to have anything to find. **The schematic detour
is the proof**: eighteen commits of out-of-order work that had to be salvaged or deleted (§4.2).

**The honest read of the graph today.** M0 is *nearly* done, six clauses discharged, two vacuous,
one of which can be closed this week (§2.4). M1 is close but has three untested exit clauses and six
unbuilt checklist items. Everything from M2 rightward has **zero** demonstrated exit clauses, **except a tested
symbol renderer sitting in `rackpal_core` with no consumer** (§5.1) and M6's real but unclaimed
M1 slice (§5.5).

---

## 7. The decision the user has to make

Roadmap §6 states the cost deliberately, **44–67 weeks of implementation, 11–18 months to a shipped
v1** (42–65 / 11–17 before M4's decomposition moved it, §5.3), on AC-017's ground that *"a detailed design set with no cost attached reliably stalls at
40%"*. That number was written for a **commercial** v1. **DR-006 (canon §11.6) rules that RackPal
is an internal tool with no commercial release planned**, which changes the calculus on several
milestones and on none of the others. This section lays out what could move to v1.1 and what each
deferral costs. **It does not make the call.**

### 7.1 What has already been spent, and what is left

| | Weeks (roadmap §6) | State |
|---|---|---|
| M0 | 2–3 | `CRITERION MET` 2026-08-27: all 8 clause rows demonstrated. The last two were `VACUOUS` from M0 until their subjects existed (§2.4) |
| M1 | 8–12 | `CRITERION MET` 2026-07-28: all 8 exit clauses discharged. Still open, and NOT exit clauses: "ships to real users" + six checklist items (§3.3) |
| M2 | 4–7 | `CRITERION MET` 2026-08-01: all 5 exit clauses discharged, four by tests and one by a person (§1, §5.1) |
| M3–M9 | 28–43 | `NOT STARTED`: zero demonstrated exit clauses anywhere, though M6 carries a real M1 slice (§5.5) |
| **Remaining** | **28–43**, plus an uncosted M1 tail | The 28–43 is roadmap §6's M3–M9 rows summed exactly (4+5+4+5+4+2+4 = 28; 7+7+6+7+6+3+7 = 43). It excludes the M1 tail, which the roadmap never costed; the cross-cutting work in §6.1 (CI, goldens, provenance gate), which the roadmap never costed either because it assumed CI existed from M0; and **M4's re-costing to `L` 7–9 at its 2026-08-02 decomposition (§5.3, §12.7)**, which roadmap §6's own row predates. Carrying that re-cost forward the band is **30–45** |

> **This table read `M2–M9 | 32–50 | NOT STARTED` until 2026-08-04**, contradicting §1 and §5.1 on
> this same board, both of which had recorded M2 as `CRITERION MET` since 2026-08-01. The row was
> written before M2 closed and was never revisited, which overstated the remaining band by M2's
> whole 4–7 weeks. Recorded rather than silently fixed: §7 is the section a scheduling decision is
> made from, and a reader who quoted its total in the interim quoted a number this board's own
> §1 already contradicted.

### 7.2 What DR-006 changes on its own, before any deferral

These are not deferrals. They are work the internal-tool ruling **removes or shrinks outright**.

| Milestone | Effect of DR-006 | Weeks |
|---|---|---|
| **M6** | The *"Windows OV/EV certificate procurement starts here"* clause is withdrawn. Removes a multi-week **external** dependency and retires `RISK-07`'s mitigation schedule | 0 engineering weeks, but removes the largest calendar risk in the plan |
| **M8** | No certificate purchase, no hardware token, no SmartScreen reputation ramp. Self-signed via `New-SelfSignedCertificate` + `Set-AuthenticodeSignature` + a timestamp server, `.cer` to `LocalMachine\Root` and `\TrustedPublisher` by Group Policy. The licence/EULA question shrinks to an internal-use notice | Perhaps **1 of M8's 2–3** |
| **M9** | *"Three integrators"* becomes three internal users on three real jobs. The judgement the criterion asks for is unchanged; the **recruiting problem** largely disappears | Reduces `RISK-08`, not the weeks |
| **M7** | Unchanged in scope, but the **argument** shifts: WCAG AA and the NVDA matrix are now about the people in this building rather than about an unknown customer base. That is a smaller population and a **known** one (which makes the requirement easier to *scope*, not automatically safe to *cut*) | — |

**What DR-006 does *not* change: DR-005.** DR-005 rules that **the sheet set** is a client
deliverable handed to a client, a GC and a job site. DR-006 rules that **the software** is not
commercially distributed. Those are different artefacts. An internal tool used by an integrator
still emits sheets that go to a job site, so **full sheet furniture stays a v1 requirement** and is
not available as a schedule lever (canon §11.5.2/2). Any option below that trims M6's furniture is
an amendment to DR-005, and must say so.

### 7.3 The deferral options, with their costs

Each row states what moving it to v1.1 buys, what it costs the product, and **which ruling would
have to be amended**, because roadmap §8.3 makes scope movement an amendment, not a conversation.

| Option | Buys | Costs the product | Ruling to amend |
|---|---|---|---|
| **A · Defer M5 (validation) entirely to v1.1** | **4–6 weeks**, and unblocks M6 from a three-way join to a two-way one | The tool never tells the user a run is wrong. `CODE-001`/`CODE-002` (NEC 725.136, 800.154) are the two checks DR-002/4 says *"protect a residential user from a red-tagged job"*, deferring them means a design error reaches a job site with the tool silent. Note the countervailing fact: CR-022/G3 means **no rule ever blocks an export**, so the deliverable is unaffected either way | Roadmap §2.1 *Validation*; AC-040 (the 28-rule count, DR-020); AC-051's fixture gate would move with it |
| **A′ · Defer *most* of M5: ship tier 1 only** | ~**3–4 weeks** | 8 tier-1 rules including `TOP-001..005` and `PLC-001..003` are already model-illegal (CR-017), so this is closer to "finish what the model implies" than to a feature. Loses the 6 tier-2 and 14 tier-3 rules, which are the ones that catch a *design* mistake rather than an *impossible* one | AC-040's count as amended by DR-020 (28 → 8 in v1, 20 to v1.1) |
| **B · Defer M7 (platform + access) to v1.1** | **4–6 weeks** | Tablet read-only is the clause with the clearest internal value, a reviewer reading an elevation on a job site is a real workflow. The a11y half is the risk: roadmap §4 M7 *Risks* says accessibility work discovered late *"tends to surface structural problems in the canvas surfaces"*, and the outline tree that was supposed to mitigate that **already slipped once** (§3.3). Deferring compounds a debt that is already overdue | AC-056 (mobile read-only on three surfaces); AC-058 D11 (keyboard path, WCAG AA, NVDA matrix) |
| **B′ · Defer only the l10n plumbing and the pseudo-locale** | ~**1 week** | An internal English-only tool arguably never needs it. But AC-058 D12 exists because **retrofitting localisation across a shipped UI is the expensive direction**, and the one-locale plumbing is the cheap direction. This is a G5 bet: cheap now, ruinous later | AC-058 (D12) |
| **C · Defer M9 (beta hardening) to v1.1** | **4–7 weeks** | This is the option that **destroys the evidence**. M9's criterion is the only one that asks whether any of this was true. Under DR-006 the beta population is internal and available, so the recruiting risk that justified deferring it is largely gone, which makes this the **cheapest milestone to keep** and the most expensive to skip | Roadmap §4 M9; measure 8 in docs/00 §9 |
| **D · Defer M4 (device builder) to v1.1** | **7–9 weeks** *(was 5–7, re-derived at M4's decomposition, §5.3)*, the single largest saving available, and by a wider margin than before | **Requires superseding DR-003**, which ruled the builder into v1 and explicitly withdrew this as a lever: *"If M4 is ever at risk, the lever is lever 1 or lever 3, not a partial builder."* It also defers **brief requirement 2**, whose builder half is what R2 actually asks for (DR-003/2). Product cost: the long tail is uncoverable, a user who meets a device the 48-template catalog lacks has no path at all | **DR-003.** This is a reversal of a user ruling, not a schedule decision |
| **E · Trim M6's sheet set to what the internal job needs** | Up to ~**3 weeks** of the 5–7 | Requires deciding **which** of the eight missing slots an internal user genuinely needs. `T6.10` pull sheet and `T6.11` termination schedule are the field deliverables; `T0.00`/`T0.01`/`T0.02` are the client-facing ceremony. Cutting the latter is an amendment to DR-005, and DR-005 was a **user reversal** of the record's own recommendation, made deliberately | **DR-005** |
| **F · Pull the catalog lever (cut the catalog to 40 archetypes at full fidelity** | Removes catalog authoring weeks from M1's tail | **No cost to quality**) the provenance gate sets the count and 40 sourced templates beat 80 guessed ones (RJ-007). The catalog already ships at 48, so this lever is arguably **already pulled**. **Numbering caution:** this is **lever 2** as `docs/09-roadmap.md` §6 now reads, but canon §11.3/5 and §12.6 call it **lever 3**: they were written against an earlier §6 in which lever 2 was *"move M4 after M6"*, the lever DR-003 withdrew. One lever, two numbers; cite it by name | None. It is an available lever, stated in roadmap §6 |
| **G · Pull roadmap lever 1: ship M1 as an internal v0.9** | Converts remaining invisible work into evidence, immediately | **None** by the roadmap's own reckoning: *"M1 is a real product."* Under DR-006 this is easier than the roadmap assumed, an internal v0.9 needs a self-signed build on a share, not an installer and a certificate. The blocker is not distribution; it is M1's one open exit clause, clause 3's keyboard drill, which needs a person and a stopwatch (§3.4) | None |

### 7.4 The three shapes those options compose into

Not recommendations. Three coherent points on the same axis, so the trade is visible.

| Shape | Contents | Remaining weeks | What you give up |
|---|---|---|---|
| **Full v1 as written** | Everything, DR-006's savings applied | **33–51** | Nothing. The longest calendar |
| **Requirements-complete v1** | All seven brief requirements met (M2, M3, M4, M6 kept); **A′** tier-1-only validation, **B** M7 to v1.1, keep M9 | **26–41** | Rule coverage and accessibility. Confirmed product decision 4 (*all seven requirements in v1*) is **preserved**, which matters, because it is a constraint, not an input (canon §0.2) |
| **Internal-minimum v1** | M2 + M3 + M6, plus **D** (M4 → v1.1), **A**, **B**, keep M9 | **18–30** | Brief requirement 2. **Requires superseding DR-003 and is the only shape that breaks confirmed product decision 4** |

**The arithmetic, shown so it can be checked rather than believed.** Every figure is roadmap §6's
per-milestone weeks, summed over the milestones each shape keeps, with M8 taken as **1–2** rather
than 2–3 per §7.2, and M5 taken as **1–2** under A′. None of the three includes the M1 tail or
§6.1's cross-cutting work, which the roadmap never costed; add those to every row equally.

| Shape | M2 | M3 | M4 | M5 | M6 | M7 | M8 | M9 | Total |
|---|---|---|---|---|---|---|---|---|---|
| Roadmap §6 | 4–7 | 4–7 | **7–9** | 4–6 | 5–7 | 4–6 | 2–3 | 4–7 | 34–52 |
| **Full v1** | 4–7 | 4–7 | **7–9** | 4–6 | 5–7 | 4–6 | **1–2** | 4–7 | **33–51** |
| **Requirements-complete** | 4–7 | 4–7 | **7–9** | **1–2** | 5–7 | **0** | 1–2 | 4–7 | **26–41** |
| **Internal-minimum** | 4–7 | 4–7 | **0** | **0** | 5–7 | **0** | 1–2 | 4–7 | **18–30** |

**M4's column moved from 5–7 to 7–9 on 2026-08-02**, at that milestone's decomposition (§5.3). Only
the internal-minimum row is unaffected, and only because option **D** zeroes M4 there, which is the
same fact as option D's saving growing, and both are consequences of one number, not two findings.

An earlier draft of this table gave **~31–50 / ~24–39 / ~15–26**. The first and third do not survive
the sum; the internal-minimum shape was understated by three to four weeks, which is the direction
that flatters cutting. Corrected above, with the working shown, a schedule number a reader cannot
re-derive is exactly the kind of claim §0 exists to refuse.

**The one thing every shape shares:** the cross-cutting work in §6.1, CI, the two failing gates,
goldens, the provenance gate, the epoch-mask drift. None of it is a milestone, none of it is gated
on anything, the roadmap never costed it because it assumed CI existed from M0, and **every item on
that list is a mechanism that would have caught a defect this project has already shipped**. It is
not on the deferral table.

### 7.5 What this section deliberately does not say

It does not recommend a shape. Roadmap §8.3 requires that any movement between v1, v1.1, v1.2, v2
and not-doing be **an edit to roadmap §2 with a new ruling ID, in its own commit**. Options D and E
additionally supersede a standing user ruling (DR-003 and DR-005 respectively), which per canon §11
preamble is the user's call and nobody else's.

#### 5.9.36 `#877`: a plate and a panel can be removed, the cascade is asymmetric, and the Outlets tab had never been opened · `DR-160` · no version move

2026-09-13. Found by `#872`'s reachability gate. It closes under `#786` and moves no number.

##### 5.9.36.1 Built at M3-A/1, reachable from nowhere

`RemoveOutletCommand` and `RemoveStructureCommand` were declared in `structure_commands.dart` with
real reverts and eight and nine test constructions between them, and **nothing in `lib/` constructed
either**. `AddStructureCommand` and `AddOutletCommand` are both wired, so the Structured Wiring tab
could create a panel and a wall plate and could never take either back: a wrong drop or a duplicate
panel was permanent for the life of the project unless somebody noticed in time to press `Ctrl+Z`.

Sixth capability in five days found complete and unreachable, after `#674`, `#870`, `#871`, `#875`
and `#879`.

##### 5.9.36.2 The plate's cascade was a decision; the panel's was not

`RemoveOutletCommand`'s own doc comment argues for leaving the cables: *"silently deleting a user's
home runs because they removed a wall plate is a much larger edit than the gesture asked for. A
caller that means both composes a `Transaction`."* Both halves of that sentence stand. This ticket
supplies the caller the second half asks for, and the confirmation is what makes the larger edit
legitimate rather than silent.

**BLANKING THE BOX WAS THE TEMPTING ALTERNATIVE AND IT IS A TRAP.** `StructureOrigin.outletId` is
nullable and DR-046 gives the null a ruled meaning, so a drop whose plate was deleted and whose
`outletId` was cleared would be a legal document saying something true. It would also be
**unrepairable**: `StructureOriginField` lists seven editable properties and `outletId` is not one of
them, `AddHomeRunCommand` sets it at creation, and no surface in the product can move a drop onto a
different plate. The cable would sit on the Structure table with an empty box column forever, and the
only way out would be to delete it and type it again.

**THE PANEL'S CASCADE HAD NO DECISION IN IT.** `Outlet.structureBodyId` and
`StructureOrigin.structureBodyId` are both non-nullable and `final`, so neither an outlet nor a home
run can be repaired to point at a surviving panel or at none. Leaving them behind does not produce a
true document; it produces two classes of entity naming a body that is not there.

So the cascade is asymmetric, and DR-160 §11.159.4 says which clause a later reader may reopen:
make `outletId` editable and §11.159.2 is back open, §11.159.3 is not.

##### 5.9.36.3 The user placed both controls, and refused one on a defect

A **trash icon on the plate's row in the left rail**, matching the shape chosen for `#871`'s template
removal the day before, and an **overflow menu in the editor header** for the panel. A trash icon
beside the body picker was refused on a defect found while writing the question: `_EditorHeader`
builds that picker only when `doc.structures.length > 1`, so a one-panel project would have had no
control at all, and a one-panel project is both the ordinary case and exactly where somebody wants a
wrongly-created panel gone.

##### 5.9.36.4 THE OUTLETS TAB HAD NEVER BEEN OPENED INSIDE THE THING IT LIVES IN

The app-level test would not run: `ListTile background color or ink splashes may be invisible`,
thrown on every row of the plate rail. `StructureEditorScreen._body` wraps the whole editor in a
`ColoredBox(surface)`, and a `ListTile` paints its selected tint and its ink splash on the nearest
`Material` **ancestor**, so every splash and every selected tint on that rail landed under the
background and was invisible. Shipped that way since M3-H/2.

**THE REASON NOTHING SAW IT IS THE PAIRING OF TWO GREEN FILES.**
`outlets_view_test.dart` pumps the tab on its own, with no editor and therefore no `ColoredBox`.
`structure_editor_screen_test.dart` pumps the editor but only ever asserts that `Outlets` is in the
tab strip, never switching to it. So the tab had never been mounted inside its own host, by a test or
by the app, and the first thing that did so found this in its first run.
`.okf/practices/a-null-collaborator-in-a-test-is-a-configuration.md` is the same shape and the
generalisation is now written there.

##### 5.9.36.5 A stale finder, broken by a control it knew nothing about

Three cases in `outlets_view_test.dart` read `find.byType(Tooltip).first`, and the rail is built
before the plate pane, so the moment it grew a trash icon those three started asserting about a
control they were not about. The cell's own `InkWell` already carries `plate-cell-<gang>-<cell>` and
its comment says why, in as many words, about a finder picking the wrong `InkWell`; the tooltip above
it had the identical hole and no such anchor. All three now anchor on the cell they name.

##### 5.9.36.6 And a comment that had become a product claim

`command_roundtrip_test.dart` reads *"A cable that vanished from the schedule because someone deleted
a wall plate is the failure this whole no-cascade rule prevents."* The test is still right about the
COMMAND, which takes exactly what it says. The sentence had become wrong about the PRODUCT, which now
takes the cable and says how many first. The group carries a header saying which of the two it is
about and where the other is proved.

##### 5.9.36.7 Evidence

Floors: `rackpal_core` 4639 to 4667, `rackpal_ui` 1805 to 1824, `rackpal_app` 1022 to 1028.
Gates: 17. Analyzer pin unmoved at 233.

`#872`'s exemption list loses two rows, its fourth and fifth retirements in three days.

**Commits** (§8.8). `#877` `80fd95e0` (DR-160) and `7baabc98` (the feature).

#### 5.9.37 `#880` and `#881`: two of the reachability gate's twelve rows were about the gate · `DR-161` · no version move

2026-09-13. Both close under `#786` and move no number. Neither was a defect in the product.

##### 5.9.37.1 `#880`'s first sentence was false, and reading one file settled it

The ticket opens *"`SnapshotCommand` is declared in `snapshot_command.dart`"*. **It is not.** That
file declares nothing at all, which its own header states as the point: it exists *"per the directory
tree in docs/03-architecture.md §2.2, purely as a marker for where that lands; it deliberately
defines no class so nothing here reads as more built than it is"*. What it holds is an indented
sketch of the class inside a `//` comment, written at M0 to record that building it needs
`RackDocument.restoreEntities` and an encode/decode dispatch table `json_codec.dart` deliberately
does not export.

So the ticket's `DONE WHEN` (*"a ruling says whether snapshots are in scope; the class is either
wired with tests or deleted"*) had no subject. There was never a question, because there is no class.

##### 5.9.37.2 The gate applied its own rule to one half of itself

`#872`'s pipeline has three steps. Step 2, the declaration scan, has always run over `_strip`ped text
with comments and string literals removed. **Step 1, the Command inventory, ran over the raw file.**
So the inventory admitted a name the declaration scan could never match, the name correctly had no
construction site, and it was reported as an unreachable capability.

Measured over the three scan roots when this changed: **73 commands raw, 72 stripped, exactly one
phantom, and nothing is lost by stripping.**

**THE IDENTICAL MISTAKE IS RECORDED IN THAT FILE'S OWN HEADER, POINTING THE OTHER WAY.** Attempt 2 of
the three failed censuses *"let a name in a COMMENT count as reachable"*, and
`RemovePlanUnderlayCommand` fell off the list because of it. That was fixed on the EDGE side. The same
mistake on the NODE side survived the whole life of the gate. **A bug found in one direction of a scan
is a reason to check the other direction, not evidence that the scan is now clean.**

##### 5.9.37.3 `#881` is the opposite: it exists, and it is not for a person

`AddLinkCommand` mints a `Link` with two open ends and an implicit `Net`, needing no device, no port
and no panel. `link_commands.dart`'s M0 header states that as the design: *"usable anywhere in a
command sequence rather than only after a device has been placed."*

The ticket's hypothesis was that `buildConnectPortsCommand` superseded it. **The census says
otherwise.** Four things mint a `Link` in `lib/`: `atomic_connect.dart`, `connect_commands.dart`,
`home_run_commands.dart` and this. The other three attach the cable to something. This one does not,
and nothing in docs/ asks for a gesture that makes an unattached cable: there is no picture of one,
because the schematic draws links between ports and such a link has none, so it would surface only as
a schedule row with both ends unbound.

**AND ITS TWENTY-ONE TEST SITES ARE NOT ALL FIXTURE CONVENIENCE**, which is what the ticket
suspected. Twelve are. The other nine could not be rebuilt cheaply: `allocateNetNameFor`'s two
properties (a revert frees the name, a redo reuses it) have **no other coverage**, and
`command_roundtrip_test`'s thousand-sequence CR-117 sweep has **no other link-creating step** that
works without first building a device.

##### 5.9.37.4 So an exemption may be permanent, in a second map

Settled by the user. `_exempt` held one kind of row and a test refusing any value that did not look
like a board item, *"a list of names is a place to hide; a list of due dates is a debt somebody can
collect."* That is right for a debt and has no room for a command that is deliberately unreachable.

`_infrastructure` is the second map: values are sentences, a test refuses anything shaped like a
board item, another refuses a name appearing in both, and **the staleness check binds it exactly as
hard.** The permanence is in the reason, not in the checking: the day somebody wires one of these the
standing claim is false, and the failure message says to decide in a ruling which of the wiring and
the claim is wrong rather than deleting whichever is cheaper.

##### 5.9.37.5 The new case guards its own vacuity

*"A Command declared only inside a COMMENT is not counted"* asserts `SnapshotCommand` is absent from
the inventory, and then reads `snapshot_command.dart` and asserts the sketch is **still there**. The
first half proves nothing the day somebody deletes the text that made the phantom, and a test that
has quietly stopped testing is the failure this repository has already met twice: in
`a-fixture-default-is-not-a-proof.md`, and in `#879`'s virtualised picker.

##### 5.9.37.6 Evidence

Nine mutations, nine kills, including reverting step 1 to raw and wiring `AddLinkCommand` from the
shell. Floors: `rackpal_app` 1029 to 1031. Gates: 17. Analyzer pin unmoved at 233.

Nothing was deleted. The marker file stays: it names what building the class would need, and that
record is worth more than the tidiness of removing it.

**Commits** (§8.8). `#880` and `#881` `2460d462` (DR-161) and `4878134f` (the gate).

#### 5.9.38 `#878`: the two commands that UNDO a placement, and a canvas that never took focus · `DR-162` · no version move

2026-09-13. Found by `#872`'s reachability gate. It closes under `#786` and moves no number.

##### 5.9.38.1 The missing halves were both the undo of something

`ClearPlanPinCommand` and `ReorderPlanUnderlayCommand` shipped at `PLAN-C` with real reverts, their
own `LabelKey` values and six test constructions between them, and no caller. `SetPlanPinCommand` and
`RemovePlanUnderlayCommand` live in the same file and both had callers, which is the shape worth
naming: **every gesture that PLACED something was wired and neither gesture that took it back was.**
A rack pinned to the wrong room could only be fixed by pinning it somewhere else, and docs/15 §6's
gesture table has a row for every way to create a pin and none for removing one.

##### 5.9.38.2 One key, three canvases, and the cost stated rather than discovered

`Delete` and `Backspace` were the user's choice over a visible control. The keymap's `meaningDrift`
rule forces one label per key across scopes, so this reads *"Delete the selection"* while the rack's
`Delete` removes a device from the project outright, and DR-011.6 had already refused to widen that
rule because *"a keyboard-only user cannot see a scope boundary"*.

**The reason it is right anyway is that the label names the SELECTION**, and the selection is a
different kind of thing on each canvas: devices on the rack, cables on the schematic, pins here. What
makes it SAFE is the strip: a cleared pin puts its carrier straight back into the unpinned rail along
the bottom, so the answer to *"did I just delete my rack"* appears three inches below the pointer in
the same frame, and `unpinned_carriers.dart` makes the frightening state unreachable because
*"unpinned" is no pin AT ALL*.

##### 5.9.38.3 `pinCarrierFor`, and the converter that could not be written

The scene's `PlanPinCarrier` and the command layer's `PinCarrier` have coexisted since `PLAN-C` with
no converter between them, and `plan_scene.dart`'s own header says the duplication is deliberate: one
says which collection a WRITER reaches into, the other which mark to DRAW.

**Nothing had needed to cross between them, and the reason is the interesting half.** Every writer so
far knew its carrier before it started: the palette places a device, the drop table pins an outlet,
the strip row carries its own kind. Clearing a pin is the first gesture that begins from a mark
somebody is LOOKING AT and has to work back to what it hangs on. A converter is exactly what
`draw_source_gate_test.dart` refuses, so `pinCarrierFor` asks the document instead.

##### 5.9.38.4 THE PLAN CANVAS NEVER CALLED `requestFocus`, AND `Esc` HAS NEVER WORKED

`rack_canvas_screen.dart` calls `_canvasFocus.requestFocus()` in **eight** places. This canvas called
it in **none**, relying on `autofocus: true`, which wins only while nothing else has claimed focus:
true in every case in its own test file, where the canvas is the whole tree, and false after one
click anywhere else.

`Shortcuts` sits above the focus node, so **`planCancel` has been dead since `PLAN-E/5`**. It is that
scope's only binding, it is green in its own cases, and it could not fire in the product. The new
case mounts the canvas beside a focusable sibling and **fails without the fix**, which is what the
cases above it could not do.

##### 5.9.38.5 And no pointer gesture reaches the Plan tab at the app mounting

The first app-level test ever to open the Plan tab (`shell_tabs_test.dart` asserts `Plan` is in the
strip and never switches to it, which is `#877`'s index-not-route gap again) found that a tap does
not select a pin, a drag does not move one, and a drag on the rail's grip does not reorder. All three
work in `rackpal_ui`'s own suites; `signposting_test.dart` taps the RACK canvas in the same harness.

**Whether that is the product or the harness is not settled and is not guessed at.** `#882` carries
the measurement and the one-minute check that tells them apart. The two gestures are proved at the
widget level and the app-level proof is recorded as owed, in the test file's own header.

##### 5.9.38.6 The reorder, and what the row's width history decided

A dedicated grip, over whole-row drag and over up/down buttons. Whole-row drag puts tap-to-open and
two buttons inside the drag target; **up/down buttons were refused on a measurement**, since that row
overflowed by 126 pixels at 240 wide holding ONE button and the `Wrap` that fixed it is what two more
would have had to negotiate with.

The drag itself needed `pumpAndSettle` BETWEEN the moves, which `port_grid_test.dart` already knew
and which cost a probe to rediscover: a reorderable list animates the other rows aside and decides
the drop index from where they have got to, so a pointer that keeps moving mid-animation is asking a
list that has not finished answering. A fixed 16ms pump produced a gesture that ran and reordered
nothing, silently.

##### 5.9.38.7 Evidence

Floors: `rackpal_ui` 1824 to 1838, `rackpal_app` 1031 to 1033. Gates: 17. Analyzer pin unmoved at
233. `KeyScope.plan` goes from one binding to three and `kKeymap` from 71 to 73, each with its
reason beside the number.

`#872`'s exemption list loses both rows.

**Commits** (§8.8). `#878` `199131c4` (DR-162) and `fb4544be` (the feature).

#### 5.9.39 `#876`: AC-044's inspector half, a channel that started at U 0, and a surface that could not be opened · `DR-163`, `CR-025` · no version move

2026-09-13. The last of the eight `#872` filed. It closes under `#786` and moves no number.

##### 5.9.39.1 The ruling was explicit and half of it was never built

AC-044: *"In v1 a 0U occupant is created and edited from the inspector (channel, start U, span) and
renders as a plain bar; there is simply no drag gesture."* Neither half existed.
`zero_u_commands.dart` holds three commands with real reverts, three planners with real refusals,
and `occupantsOfZeroUChannel`, whose own doc says it is *"Public because the inspector needs to say
'AMP-1 is in this channel' before offering to delete it"*. **The inspector was anticipated in the
code and never arrived.**

`#875` made one of the three reachable by wiring PWR-003's remedy, which mints a channel so a 0U PDU
has somewhere to sit. `add_outlets.dart` quotes AC-044 while doing it and says why it is not the same
thing: *"this is not a person: it is a remedy the person asked for by name."*

##### 5.9.39.2 THE ONLY CHANNEL THE PRODUCT COULD MAKE STARTED AT A U THAT DOES NOT EXIST

Found before any of the UI. That remedy wrote `startU: 0, endU: heightU - 1`, with the comment
*"`startU` is 0-based (CR-025)"*.

**CR-025 rules the opposite in as many words**: *"1-based, bottom origin. `ruIndex` in [1, heightU]"*,
and it calls itself the contradiction that *"will actually hurt"*. The comment named the ruling that
forbids the line it was defending.

Nothing else in the tree agreed with it. Every shipped starter writes `startU: 1`; every case in
`zero_u_commands_test.dart` does; `placement_rules.dart` derives length as `endU - startU + 1`
(*"from U 1 to U 42 is 42 U of rail, not 41"*); and `rack_shrink.dart` normalises *"an inverted or
SUB-1 channel"* on read, which is this defect described by a file that had never met it.

**AND `planAddZeroUChannel` WOULD HAVE REFUSED IT.** It rejects `startU < 1`. The remedy builds
`AddZeroUChannelCommand` directly, so the guard never ran on the one path that ships. **A validated
planner beside an unvalidated producer protects the callers it does not have**, and `#876` is what
gave it one. The test had pinned the defect as intended behaviour, asserting `endU == heightU - 1`
and nothing about `startU`; it now asserts both.

The length was right either way, since 0..41 and 1..42 are both 42 U, so nothing visible was wrong:
the channel covered a U that does not exist and missed the top one, and a shrink would have moved it
silently through `_atLeastOne`.

##### 5.9.39.3 The occupant fields were built where they could not be reached

The user placed them on the DEVICE inspector, which is where AC-044 puts them and where every other
device property is edited. **A 0U occupant cannot be selected.** `scene_builder.dart` reads
`if (placement is! RailPlacement) continue;`, so it is never in the elevation's scene, never
hit-tested and never selectable.

So AC-044's two clauses depend on each other and only one of them shipped: *"edited from the
inspector"* is unreachable without *"renders as a plain bar"*. A section on the device panel would
have been a surface nothing could open, **which is the exact defect `#872` exists to catch, in the
ticket closing `#872`'s last two rows.**

Put back to the user with the measurement; the fields moved under their channel in the rack panel,
which `Ctrl+Alt+U` reaches with nothing selected. Building the bar first was refused as a separate
body of work rather than as a bad idea, and is `#883`.

##### 5.9.39.4 The form takes the bounds up front, because nothing can edit them

`zero_u_commands.dart` has add and remove and no third command, so a channel whose extent is wrong is
replaced rather than corrected. **Two comments promised otherwise**: the remedy's *"an ordinary one
they can edit or remove afterwards"* and `new_rack_dialog.dart`'s *"0U channels ... All of it is
editable afterwards from the rack inspector"*. Both are corrected; `#876` makes the *remove* half of
each true for the first time.

##### 5.9.39.5 The surface validates nothing, and the planners say so

`planAddZeroUChannel` refuses a duplicate id, an inverted span and a span that does not fit;
`planRemoveZeroUChannel` refuses while occupied and NAMES the occupant; `planSetZeroUPosition`
re-runs `evaluatePlacement` and returns `PLC-003`'s own sentence. The panel collects values and hands
over a `ZeroUResult`; the screen runs it or prints it. The one thing the panel adds is the occupant
name on a channel row, so a Remove button that is about to refuse says why before it is pressed.

##### 5.9.39.6 Two defects the tests found in the new code

**The start-U field committed twice.** `onSubmitted` and the focus listener both fired, so pressing
Enter asked the host to move the device twice. It was invisible in the product, because the first
move updates the document and the already-there guard swallows the second, and it would have come
back the moment an edit was REFUSED: nothing changes, the guard passes, and the refusal prints twice.
Enter now unfocuses and the listener is the one commit.

**And an old case depended on two fields sharing a viewport.** `rack_inspector_panel_test`'s
*"Custom"* case read the Preset dropdown straight off the screen after editing `Rail type`.
`scrollUntilVisible` scrolls ONE WAY and stops as soon as its target appears, so how far it goes
depends on how much list sits BELOW that target; a section at the bottom pushed the scroll further
and `Preset` left the viewport. The case now goes and looks at the field it is about.

##### 5.9.39.7 Evidence

Floors: `rackpal_ui` 1838 to 1857. Gates: 17. Analyzer pin unmoved at 233.

**Six of the nineteen new cases go through the real `RackCanvasScreen`**, because a harness supplying
its own callbacks cannot see whether the screen runs the command, prints the planner's refusal, or
SIGNS the move from the session, which is `#879`'s surviving mutation exactly.

**`#872`'s exemption list is now EMPTY.** Every `Command` in the tree is reachable from a person, for
the first time since that gate filed twelve.

**Commits** (§8.8). `#876` `c95224d2` (the CR-025 fix), `9a0186a1` (DR-163) and `33d7a2b6` (the
inspector). **Twelve mutations, twelve kills.**

#### 5.9.40 `#884` and `#882`: the producer that 0U list never had, and a ticket that measured a harness · `DR-164` · no version move

2026-09-13. Both reported by the user against the previous entry's work, one confirming a gap and
one disproving a filing. Both close under `#786` and move no number.

##### 5.9.40.1 NOTHING IN THE PRODUCT COULD PUT A DEVICE IN A 0U CHANNEL

Reported as *"the rack inspector list doesn't actually show a 0U device at all"*, which is true of
every project a person made and always was.

Censused by call site, in `lib/` only. `buildPlaceFromCatalogCommand` takes a `ZeroUTarget? zeroU`
and the branch behind it is complete: it builds the `ZeroUPlacement`, runs `evaluatePlacement` and
returns `PLC-003`'s refusal by name. **`ZeroUTarget` has one definition, one mention in an
`add_outlets.dart` comment, and zero call sites.** The only reachable writer of a `ZeroUPlacement` in
the whole product is `planSetZeroUPosition`, which MOVES one that already exists.

The three starters that do show a PDU get it from `tool/starters/authoring.dart` writing the
placement directly, which is why the surface looked alive to everything that tested it.

##### 5.9.40.2 THE GAP WAS RECORDED, AND RECORDED AS HANDLED

This is the part worth keeping. §11.162.5, written one ticket earlier, says `#876` *"does not let a
person CREATE a 0U occupant from nothing either: placing a device into a channel is
`catalog_placement.dart`'s, and AC-044's 'created' is satisfied by the palette placing a 0U-capable
device."*

**The file it defers to refuses exactly that**, with *"P01 is a 0U occupant: it mounts in a vertical
channel, not rail holes. Add it from the rack inspector (AC-044)."* So the panel deferred to the
palette, the palette deferred to the panel, and between them nothing could place at all.

**A deferral reads as a decision.** The clause is not a TODO, carries no board id, and names a real
file with a real function in it; everything about its shape says somebody checked. That is the tell,
and the practice is [each surface deferred to the
other](../.okf/practices/each-surface-deferred-to-the-other.md).

##### 5.9.40.3 What shipped, and the two things the ruling decided rather than leaving to the code

An `Add device…` control on each channel row, opening a picker over the document's shelf. Ruled
against a drag from the palette onto the rendered bar, because the bar is `#883`: that gesture would
put the only producer behind the one AC-044 clause already left unbuilt, which is §11.162.1's trap a
second time and inside the same feature.

**The occupant lands at the CHANNEL START**, not at a first free offset. A 0U occupant has no extent
anywhere in the format, which `zero_u_commands.dart` already recorded as a known model gap and the
one shipped 0U archetype confirms with `frontU: 0, rearU: 0`. With no extent there is no overlap, so
"free" has no meaning and an offset search would be arithmetic dressed as a rule.

**The predicate moved rather than being copied.** `isZeroUBody` is public in `catalog_placement.dart`
and both the picker and the placer read it, so the picker cannot come to offer a row the placer
refuses. Same reasoning the same file records for `PLC-001`, which was transcribed by hand into a
planner and had to be given back its rule id.

##### 5.9.40.4 A MUTATION PROVED THE RULING'S OWN REASONING WRONG

§11.163.4 was drafted saying the new occupant is not selected because selecting it would swap the
inspector from the rack panel to a device panel. **It would not.** `_inspectorTarget` is moved by
canvas GESTURES and never by `_selection.apply`, so the panel stays either way.

The case written to defend that clause asserted the rack panel was still on screen, and it **passed
with the mutation applied**. A test that cannot fail is not evidence, and that one was defending a
mechanism rather than an artifact.

**The decision survives with a better reason**, which is the useful outcome. `_finalizeCatalogPlacement`
requests CANVAS FOCUS and selects in one breath, and pairing those aims the keyboard at a device the
elevation never draws. `Delete` is the sharp end: `_deleteSelection` removes an unwired device with
no confirmation at all, because `confirmDeviceRemoval` only builds a dialog when something would
cascade. The case now asserts that, and the mutation that routes the placement through
`_finalizeCatalogPlacement` kills it.

##### 5.9.40.5 `#882` closed as not a defect, and the filing is the lesson

Filed while building `#878`: at the app mounting, a tap on a plan pin does not select it and a drag
does not move it. **The user opened a project with a floorplan and dragged a pin.** It works.

The focus half is answered by reading, and answered the same way. Every pointer-down on a canvas
arrives through `CanvasIntentHandler.beginDrag`, a tap being a begin plus a commit with no movement,
and `#878` put `_canvasFocus.requestFocus()` at the top of that method. **So a plain CLICK on the
plan already takes the keyboard**, and `Delete`, `Backspace` and `Esc` are live after one, not only
after a drag.

The ticket was filed as MEASURED and deliberately not diagnosed, which was the right instinct. What
it measured was a HARNESS, and its title named the tab. It also named the one-minute manual check
that settled it, and that check was the cheaper first move. The measurement is kept in
`plan_tab_route_test.dart`'s header, where it is still true and where it stops the next person
writing a pointer assertion that cannot fail.

##### 5.9.40.6 Evidence

Floors: `rackpal_ui` 1857 to 1866. Gates: 17. Analyzer pin unmoved at 233.

**Five of the nine new cases go through the real `RackCanvasScreen`**, which is the only thing that
can see the designator coming from the allocator rather than the picker, the signature coming from
the session, and what the keystroke after a placement does.

**Seven mutations, seven killed**, one of them only after the case defending it was rewritten to
assert an artifact. **Not covered, and measured rather than omitted**: the `CatalogPlacementFailed`
arm and the stale-channel guard are defensive. With a template the picker offered and an offset of
zero inside a resolved channel, no refusal `PLC-003` can return is reachable through this surface.

**Commits** (§8.8). `#884` `f04392a4` (DR-164) and `d688d0d7` (the producer, carrying §11.163.4's
correction). `#882` `868bbcdf`.

#### 5.9.41 `#885`: the palette moves to the shell, and three findings about hiding a widget · `DR-165` · no version move

2026-09-13. The user's own report, one ticket on from `#884`: *"Device templates are only pulled in
from the rack view ... field devices need to be accessible from the plan view; it improves the UX
workflow significantly."* It closes under `#786` and moves no number.

##### 5.9.41.1 A GESTURE THAT WAS RULED, BUILT, TESTED AND UNMOUNTED

docs/15 §6's gesture table opens with *"drag from the device palette or staging bin onto the plan:
places the device and sets its pin in one command"*, and has since the chapter brief. Both halves
existed. `buildPlaceOnPlanCommand` carries the pin ON the placement so one undo restores both;
`PlanCanvasScreenState.armPaletteDrag` is public with a comment saying exactly why it is public:
*"the host that owns a palette hands the armed pointer down, and `PLAN-E/5` wires the real one."*

**Censused by call site: `armPaletteDrag` had three, and all three were tests.**
`DevicePalettePanel` had exactly one mount in the whole tree, inside `RackCanvasScreen`, as a 280px
column, so the palette was not on screen when the Plan tab was. `PLAN-E/5` shipped the tab and the
layout and did not bring it, which makes it the sixth instance of the no-producer shape after
DR-143, `#674`, `PLAN-E/5`, `LEN-A/3` and `#870`, and the first where the chapter scheduled to close
the gap is the one that left it.

**What it cost is what the user reported.** A field device can only be born in the Rack tab, where
its palette row REFUSES TO DRAG (`mountable = frontU > 0 || rearU > 0`, deliberate, because docs/04
§3.1 is *"drag from palette to RAILS"*). So it is created by double-click, lands as an
`OffRackPlacement`, and is invisible in the view that created it; it reappears only after a tab
change, in the Plan view's unpinned strip.

##### 5.9.41.2 The row, not the key, and a defect that had never been given a real value

`PaletteHost` hands over a resolved `PlaceableTemplate`. A `rowKey` is `source/id@version` and a
template id is not (DR-102 §11.101.4), and **`_placeFromPalette` took a rowKey and passed it straight
to `buildPlaceOnPlanCommand` as a `catalogId`**, which resolves nothing for any real row. Its three
tests all passed a bare id, so that parameter had never once been given the value its own name
promised. The type makes the wrong call unrepresentable now.

**Copy-on-place came with it** (DR-103 §11.102.2). A library row is not in the document, so dragging
one onto a floorplan is a copy AND an add, exactly as it is on the rails: the rule is a property of
PLACEMENT, not of the surface a placement was started from. Without it the Plan view would have had
a palette whose library rows all refused.

##### 5.9.41.3 THREE FINDINGS ABOUT HIDING A WIDGET, AND THEY ARE ONE FINDING

All three came from one afternoon and all three are the same mistake: **treating a layout change as
a visual decision when Flutter reconciles by position and identity.**

**The column cannot be a sibling of the `TabBarView`.** A `TabBarView` is a `PageView`, and a
`PageView` positions by PIXEL OFFSET: `index * viewportWidth`. Hiding a 280px column widens the
viewport by 280, so an offset animated for the old width lands between pages. Tapping `Schematic`
from the Rack tab showed `Structured Wiring`, one page short, on every run.

**A conditional child in a `Row` shifts its siblings.** `if (showColumn) ...[column, divider]` emits
one child on the tabs with no palette and three on the two that have one, so the canvas moved from
slot 2 to slot 0 and its whole subtree was destroyed and rebuilt with every tab change.

**An `InheritedWidget` carrying a `State` OBJECT must notify on every rebuild.** `updateShouldNotify`
as `state != old.state` asks *"was this widget replaced"* and never *"did anything change"*: the
`State` instance is the same for the life of the host, so the column never rebuilt and a template
saved while the canvas was open never reached the palette.

The practice is [hiding a widget is a structural
change](../.okf/practices/hiding-a-widget-is-a-structural-change.md).

##### 5.9.41.4 What the suite was for, and the one case that could not fail

**Nine harnesses in `test/canvas` now pump the composition rather than the screen**, and their ~128
existing cases are the evidence that a wide refactor changed no behaviour. That is the whole
argument for doing it this way: the palette's search keys, its drag arming, its quick-add, the
caret's hand-off and the staging bin overlay were all already pinned, so the move either kept them
or was caught.

**One new case was written twice.** The `/` gate (*"the only thing `/` must never do is fail to type
a slash into a field"*) had never been tested, which a mutation found. The first attempt pressed `/`
with the PALETTE's own field focused and passed with the gate deleted: after the hoist the palette
sits ABOVE the canvas, so a key pressed in its field never reaches the `Shortcuts` that maps `/` at
all. It asserts from an INSPECTOR field now, which is inside the canvas subtree where the binding is
in scope. Same lesson as `#884` §11.163.4, one ticket later: a test that cannot fail is not evidence.

##### 5.9.41.5 Evidence

Floors: `rackpal_ui` 1866 to 1868, `rackpal_app` 1033 to 1037. Gates: 17. Analyzer pin unmoved at
233.

**The four app-level cases are the half `rackpal_ui` cannot prove.** Its palette cases pump
`test/canvas/rack_with_palette.dart`, a helper that composes the column and a canvas the way the
shell does, which shows only that the two agree with each other. Which views carry a column, whether
the state survives a tab change, and whether a row activated on the Plan tab reaches the plan editor
are questions only the real `AppShell` answers.

**Seven mutations, seven killed**, two of them only after the case defending them was rewritten.

**Commits** (§8.8). `#885` `72f22723` (DR-165) and `a1bdc029` (the move, carrying §11.164.1, .3 and
.5's corrections).

#### 5.9.42 `#883`: AC-044's plain bar, the model field it needed, and a field erased by every rebuilder · `DR-166` · no version move

2026-09-13. The last of the three the user reported against this run of tickets. It closes under
`#786` and moves no number.

##### 5.9.42.1 One line made half a ruling unreachable

`scene_builder.dart` read `if (placement is! RailPlacement) continue;`. A 0U device was therefore
never in the elevation's scene, never hit-tested and **never selectable**, which is why `#876` had
to put AC-044's occupant fields on the RACK panel rather than on the device inspector that ruling
names: the device panel could not be opened on a device nothing could click. An installer reading
the drawing could not see the PDU at all.

##### 5.9.42.2 THE MODEL FIELD CAME FIRST, because otherwise the bar's length is invented

AC-044 has named *"channel, start U, span"* as the inspector's three fields since the critique, and
`#876` shipped two. The third had nowhere to go: `ZeroUPlacement` carried a channel, an offset and
an orientation; `TemplateBody` has `bodyDepth` and `chassisWidth` and **no physical length at all**
for a body whose `frontU` and `rearU` are both 0; and `PLC-003` treated the occupant as a POINT,
checking where it starts and asking nothing about what comes after.

Two alternatives were offered and both invent a length the file does not hold. Running the bar *to
the end of its channel* is honest only while one occupant is in a channel, and `#884`'s
`Add device…` puts every occupant at offset 0, so two in one channel would draw two identical bars.
Spanning *the whole channel* makes `#876`'s **Start U** field change nothing visible, which is
docs/04 §3.4's silently-does-nothing defect arriving through the back door.

**Absent is unknown and not zero.** Every document written before this has no span, so it is the
ordinary case rather than an edge: an absent key (CR-114), an empty field hinted `unknown`, and a
one-U **hollow** stub in the elevation rather than a filled bar. That is G4's rule given a shape
instead of a number, and the semantic label says it in words for anybody not looking at the picture.

##### 5.9.42.3 A NEW FIELD ON A REBUILT OBJECT IS ERASED BY EVERY REBUILDER

`planSetZeroUPosition` constructs a fresh `ZeroUPlacement` from the old one to move it. It copied
four fields and knew nothing about the fifth, so **every move silently erased the span**, with no
error and nothing on screen except a bar that quietly went back to being a stub.

This is the cost a value object charges for each new field, and it is paid by whoever adds the
field rather than by whoever wrote the rebuilder. The practice is
[a new field is erased by every rebuilder](../.okf/practices/a-new-field-is-erased-by-every-rebuilder.md);
the census is one grep for the constructor's own name.

##### 5.9.42.4 And a comment that said a fragment was not needed

The first version of the scene wiring recorded no fragment for a bar, on the reasoning that *"a bar
is one absolute rect with no local origin worth having"*. That is a confident sentence and it was
wrong: the canvas builds a `_DeviceBoxLeaf` for every entry in `RackScene.devices` and calls
`fragmentFor(id)`, which **throws** on an id it has no range for. The first run painted an
`ArgumentError` where the elevation should have been. The bar's ops are local and bracketed like any
device's now, and the comment records what it used to claim.

##### 5.9.42.5 PLC-003 widened rather than joined

Its rationale already read *"A device in a channel this rack does not have, **or past the end of
one**, has nothing to screw into"*, and an occupant whose tail hangs off the end is that sentence
exactly. A second, unnumbered refusal beside a numbered rule about one physical fact is the drift
CR-021 exists to stop, and this area paid for it once when `PLC-001` was transcribed into a planner
and had to be given its id back. The AC-051 pair gains the new predicate; an unknown span is not a
refusal, because a rule that refused every document written before today would make an absent key
mean *illegal* when CR-114 says it means *not recorded*.

##### 5.9.42.6 Evidence

Floors: `rackpal_core` 4667 to 4682, `rackpal_ui` 1866 to 1874. Gates: 17. Analyzer pin unmoved at
233.

**The case the ticket asked for by name** is in `zero_u_bar_test.dart`: a rack-mounted and a 0U
device are both in the scene and both hit-testable, which no test asserted. And the one that closes
the ticket is in `rack_inspector_panel_test.dart`, through the real screen: clicking the bar selects
the device, which the inspector shows by swapping off the rack panel.

**Eight mutations, eight killed**, among them the bar drawn in the opening over the rack-mounted
devices, mirroring ignored, an unknown span drawn full height, a move erasing the span, and
`PLC-003` back to treating the occupant as a point.

**Commits** (§8.8). `#883` `6fc22a29` (DR-166) and `6fe267d6` (the bar, the field and the widened
rule).

#### 5.9.43 `#887`: the 0U occupant's fields move to the device inspector, once the reason for moving them away expired · `DR-167` · no version move

2026-09-13. The follow-on `#883` left open, asked for by the user the same day. It closes under
`#786` and moves no number.

##### 5.9.43.1 A placement argued from an obstacle that is gone

AC-044 puts a 0U occupant's *"channel, start U, span"* on the inspector, and every other device
property is edited on the DEVICE inspector. DR-163 §11.162.1 put these three on the RACK panel and
said exactly why: **a 0U device could not be selected**. `#883` drew the bar and made it
hit-testable; DR-166 §11.165.6 recorded that the fields stayed put on a fresh decision and put the
placement back to the user as a live question.

**Both earlier clauses are corrected in place rather than left to read as current**, which is the
part worth keeping. A reader who finds a placement argued from an obstacle that no longer exists
does not conclude "this was re-decided"; they conclude that the obstacle is still there. §11.162.1's
own closing paragraph is about that failure pointed the other way, and it would have become an
example of itself.

##### 5.9.43.2 What did NOT move, and why that is not a compromise

A channel is a rail on a rack. Adding one, removing one, and the occupant count that makes a Remove
about to refuse say so first are all facts about the RACK, and `occupantsOfZeroUChannel`'s own doc
says it is public *"because the inspector needs to say 'AMP-1 is in this channel' before offering to
delete it"*. What moved is the occupant's own three fields, which are facts about the DEVICE.

**Nothing is editable in two places**, which is the point of moving them rather than copying them,
and a case pins both halves: the rack panel no longer offers the start-U field and still names the
occupant, and selecting the bar produces the field exactly once.

##### 5.9.43.3 Two test-harness facts, and the first one is general

`_rack` and `_doc` read their values off `RackInspectorPanel`, which is mounted **only while the
inspector is on the rack**. A case that selects a device in order to edit it swaps that panel away,
so every assertion after the selection died on `Bad state: No element` rather than on anything it
was about. They read `InspectorPanel` now, which is mounted for both targets and carries the same
two fields.

That is worth stating generally: **a test accessor keyed on a widget that only exists in one state
is a test accessor that breaks the moment a case changes state on purpose.** The second is smaller:
`_reveal` scrolls the rack panel, so three cases that used it had to stop, since the device panel
puts these fields with the other placement controls and above the fold.

##### 5.9.43.4 Evidence

Floor: `rackpal_ui` 1874 to 1875. Gates: 17. Analyzer pin unmoved at 233.

**Three existing screen cases changed ROUTE rather than meaning**, reaching the fields by clicking
the bar, which is `#883`'s gesture doing real work in three more places rather than being asserted
once and left alone.

**Commits** (§8.8). `#887` `e077860c`.

#### 5.9.44 `#889` and `#888`: the Location and Plan views become one, and a phrase repeated eighteen times reads as vocabulary · `DR-168` · no version move

2026-09-13. Asked for by the user the same day, in the same message as `#886`: the two views *"do
very similar functions and it would make more sense to have both together"*. Five chapters,
`#890`-`#894`, plus `#888`, which was found while reading for the first of them. It closes under
`#786` and moves no number, on CLAUDE.md's rule that the version tracks the CURRENT milestone
rather than the epic an issue is filed under.

##### 5.9.44.1 The merge was already in the design, and what the design withheld was the editing

docs/15 §6's layout paragraph has said since the chapter brief that the Plan view's left region is
*"the underlay list and the location tree"*. The tree was there from the start. Two things it also
said are why this reads as a merge rather than a rename: the tree was **read-only**, and the route
it named for editing was `Project ▸ Locations…`, a menu the application does not have.

So the question the user asked was not *"should these be one view"* so much as *"why are they
two"*, and the honest answer is that nobody re-read the layout paragraph after DR-091 §11.90
promoted Locations to a tab. **§11.90.4 is what makes the merge legal without re-opening DR-091**:
it declined to freeze the view set before M6, in as many words, and this is the first change to
spend that deferral. The table goes from seven rows to six and is corrected in place, because the
rule it exists for is that the strip is ordered by JOB, and that is untouched.

##### 5.9.44.2 Three strings sent people to a menu that does not exist, and fifteen comments hid them

`Project ▸ Locations…` appeared **eighteen times** across the two UI packages and the app. Fifteen
were comments. **Three were on screen**, and each fired exactly when somebody had no rooms and
needed one: *"This project has no rooms yet. Add one in Project ▸ Locations…"*, *"Rooms are named
in Project ▸ Locations…"*, *"also named in Project ▸ Locations…"*.

docs/04 §3.4's rule is about a control that silently does nothing; **an instruction that cannot be
followed is a step past that**, because the user does the work of hunting for the route before
concluding the software is wrong. The mechanism that hid it is worth naming: **a phrase repeated
eighteen times reads as vocabulary.** Any one of the fifteen comments, read alone, looks like
somebody establishing where locations live, and a reader checking a fourth instance finds three
that agree with it.

The case that now gates this reads the REAL menu bar rather than a list kept beside it, so it
notices a menu being REMOVED, which is precisely what happened. `▸` is how this corpus writes a
menu path and appears in no other context, so its presence in a string is the whole signal.
**Comments are deliberately exempt**: fifteen of the eighteen were history, and a history that may
not name the route it is about is a history that cannot be written.

##### 5.9.44.3 The third region, and why `PLAN-E/5` was right not to invent it

docs/15 §6 gives this view three regions with the standard inspector on the right. `PLAN-E/5` built
two and said why in its own header: *"there is no standard inspector to put there … the column is
absent rather than invented"*, because `InspectorPanel` requires a `Rack` and a pin's carrier may
be an outlet or an off-rack device. That was correct, and it is the same shape §5.9.11 records
one view over: **a thing ruled, built and left with nothing that reaches it**, there an importer
with no caller, here a region with nothing it could honestly show. The deferral was honest both
times, and both times the answer arrived from a change made for another reason.

The merge is what supplies the missing thing, and it is not a workaround: the selected **room** is
a subject both halves of this view are about, it has properties worth a column, and one of those
properties is its outline on the open plan. The outline acts moved there from three buttons on
every row of a read-only room list, on the reasoning that **a room's shape on a plan is one of its
properties**, and the list itself is gone.

##### 5.9.44.4 A decomposition seam the code did not have

`#891` and `#892` landed in one commit. The two panes share one selection, so extracting the tree
without the detail ships a control that selects something nothing shows, and moving the outline
acts without the inspector to put them in ships them unreachable. **Either order ships a dead
control for one commit to satisfy a boundary drawn before reading the file.** Atomic means one
logical change, and this was one.

Neither pane owns the selection, for a structural reason rather than taste: in this view the tree
is in one region and what it selects is drawn in another, so a selection private to the list would
have to be mirrored across the gap.

##### 5.9.44.5 The 800px default surface, which clamps a `SizedBox` and mislays every click

Two harnesses pumped a `SizedBox(width: 900)` inside the default 800px test surface. That CLAMPS:
the canvas came back **238 units wide** and every click aimed at the plan missed the thing it was
aimed at. Three guesses about scene mapping went first, and a probe printing the actual rects
found it in one run. They set a 1600x1000 surface now, which is also the honest window: docs/04
§1 treats anything under 1080 as the tablet-collapse case nobody has built, so 900 was never a
window this product supports.

##### 5.9.44.6 Two private classes that reference each other are not dead to the analyzer

`45d4d058`'s message says *"The `_RoomList` is gone."* **It was not.** The class was still in
`plan_editor_screen.dart`, 183 lines of it with `_RoomRow` and `kPlanNoRoomsDetail`, and nothing
built it: the rail stopped constructing it when `#891` moved the outline acts, and the declaration
stayed.

**`unused_element` could not see it, and the reason generalises.** `_RoomList` builds `_RoomRow`,
and `_RoomRow` keys its buttons off `_RoomList.drawKeyFor`. Each is referenced, so neither is
unused, and **a reference cycle between two private declarations is invisible to a rule that asks
only whether a name is mentioned.** The analyzer was at its pin through both commits and had
nothing to say. So was `dart format`, which formatted it faithfully.

The check that would have caught it is the one this repository already owns for `Command` classes:
**ask what CONSTRUCTS a thing, not what mentions it.** `_RoomList(` returns one hit, its own
constructor. That is the same one-grep census `#884` used on a parameter with no caller, pointed at
a widget instead.

**The deletion changed no test**, which is the proof rather than the convenience: three cases drive
`room-draw-<id>`, `room-reshape-<id>` and `room-clear-<id>`, and they were following
`_OutlineActions`' copies of those keys all along.

##### 5.9.44.7 Evidence

Floors, re-measured in the commit that moved them rather than assumed: `rackpal_ui` 1875 to 1874
(two cases went with the deleted room list, replaced by per-room assertions in both directions),
`rackpal_app` 1037 to 1036 and back up for the new case. **The app floor's fall is DATA rather
than slack**: `global_undo_test.dart` generates one case per `ShellView` value so DR-159
§11.158.3's *"the key works on EVERY tab"* cannot go stale when a view is added, and six tabs make
six cases. Nothing was removed by hand.

`LocationsPanel` and `showLocationsPanel` are both DELETED. The modal had no caller in `lib/` and
none in any test: it was the route CR-112's ellipsis promised, superseded when DR-091 promoted
Locations to a tab, and left standing. Its thirty cases did not go with it; the harness composes
the two extracted panes the way the `Site` view composes them.

No key changed. `kViewKeyToTabIndex` moved the one entry that had to, `4: 6` to `4: 5`, because
the strip lost a tab BEFORE the Schedule. Rack is still `Ctrl+1`, the Schematic still `Ctrl+2`,
and `Ctrl+3` is still bound to nothing (CR-071's Rear Panel).

17 gates green. Analyzer pin unmoved at 233.

**Commits** (§8.8). `#890` `bb39e122`. `#891`, `#892` `45d4d058`. `#893`, `#888` `f00d6c46`.
`#894` `8058825c` and `12f63883`, the second being §5.9.44.6's deletion. Merged as `0264b5e9`.


#### 5.9.45 `#895` and `#896`: a draw that could not cross a pin, and a mark nobody could read · `DR-169` · no version move

2026-09-13 and 14. Four reports in one message from the user, after drawing rooms in the product for
the first time since the Site view merged. Two were defects and two were decisions. Board `#895`
closes under `#786`; `#896` and its six chapters `#897`-`#902` close under it too, and none moves the
version.

##### 5.9.45.1 The draw lost to a pin, and §11.49.10 had already ruled it

*"If the user clicks on a pinned item, the pin is dragged instead of a vertex being placed."* Then:
*"left click will no longer place a vertex or close the outline."*

**Both are one line.** The draw mode outranked the other gestures in `commitDrag`'s dispatch chain
and NOT in `beginDrag`, so the scene hit test ran first and a press landing on a pin grabbed the pin.
§11.49.10 ruled the reshape mode above every other gesture and gave its reason in general terms:
*"a mode that outranked the other gestures only sometimes would put the same tie in a smaller place
where nobody would look for it."* **The draw was that smaller place**, so the fix is a correction
under an existing ruling rather than a new decision.

The second symptom is the same line seen from the other end. Every click inside the marker's hit box
was swallowed identically, and that box was **60 points across on a 3300-unit plan**: a person
drawing the room around their head end was clicking into a dead zone the size of the mark.

**THE THIRD REPORT DID NOT REPRODUCE**, and that is recorded rather than quietly dropped. *"If the
outline is cancelled, clicking Draw will not allow the user to start drawing one again"* was tried
by both cancel routes, `Esc` and the chip's dismiss, at the widget level; the mode restarted cleanly
each time. `plan_tab_route_test.dart` records that no pointer gesture reaches that tab in the app
harness, so the app-level check was not available. The likeliest explanation is the same dead zone
swallowing the restart clicks, and the user has been asked to re-test.

##### 5.9.45.2 "Massive" is a number, and so is the thing next to it

`kPlanMarkerRadiusFraction` sized a marker at 1/110 of the underlay's longer side, in SCENE units,
which are image pixels. That is a 30-unit radius on an architectural sheet, so a 60-point mark at
1:1 and four times that at 400%. **And the plan canvas never called `fitToContent`**, where the rack
editor and the schematic both do, so a plan opened at 100% anchored to its top-left corner showing
about a quarter of the drawing with the marks at their largest. Neither fact was inferred.

**THE SEAM FOR THE FIX ALREADY EXISTED WITH NO PRODUCER.** `buildPlanScene` takes a `markerRadius`
override and no caller anywhere passed it, which is the eighth instance of the shape §11.167.7 lists
seven of. So each caller computes from its own scale and the scene builder never learns what a zoom
is.

##### 5.9.45.3 The census that refused a derivation

The user's answer to telling marks apart was colour by the device's primary signal domain. The
obvious implementation is to read the domains off the ports, and **the census killed it**: of 51
seeded templates, **13 have ports in exactly one domain**. Excluding `pwr`, `ctl` and `str`, which
sit on nearly everything, it rises to 26 and **nine then have none at all**, a control keypad among
them, because the excluded ones were all it had. A television reads as
`(video.digital, audio.analog, net)`.

**A set of port domains answers what can be PLUGGED INTO a device. It does not answer what the
device IS**, and G4 forbids estimating it, so the field is authored.

**The outlet half went the other way and still landed on authoring.** A drop's `service` IS a signal
family, so an outlet's domains can be read off its recipe: five of the nine resolve to one, three to
two, and one is `structure.undetermined`. But the one that breaks it is **the most common outlet in
the trade**: `TV location` is two Cat6 and two RG6, so it reads as `net` and `video.analog` at once.
Deriving would have coloured `Data only` and left the flagship recipe grey.

##### 5.9.45.4 The glyph is not decoration, and the greyscale case caught itself

`plan_sheet.dart` SPLICES the plan scene, so every mark on screen is a mark on `T1.01`, and the
Installer preset exports greyscale. §14 records that the eight hues **collide in greyscale by
design**: analog video against analog audio at L ≈ 0.40, and digital audio, network and control
together at L ≈ 0.22-0.29. PAL-3 resolves that for a LINE with dash class and line weight. **A filled
dot has neither.** So the mark carries the domain's own glyph, which the product already draws.

**The case that proves it caught its own first version.** It compares marks with every colour
stripped out, and it first summarised each path by its COMMAND COUNT: a square and a diamond are
both five commands, so it reported two identical grey dots as distinct. It reads the path geometry
now. A proxy for *"a human can tell these apart"* has to be chosen at the level the reader sees.

##### 5.9.45.5 Three guards fired, and each was doing its job

**`template_change_class.dart` throws rather than defaulting**: `no change class for
"primaryDomain"`, so the field could not reach the Device Builder until somebody decided what class
of change it is. Safe, in the end: it changes a mark's colour and nothing placed, wired, scheduled or
measured.

**`designator` is `@internal` to `rackpal_core`** (AC-013), so a `rackpal_ui` case cannot blank one
to test the no-name path. The fixture builds it that way instead, which is the honest route and one
the analyzer gate insisted on at zero warnings.

**And `plan_scene_test.dart` asserted the MECHANISM.** It read `hasLength(2)` circles, because a
device was a circle plus an inner dot and that dot was how it differed from a drop. The dot is where
the glyph goes now, so the difference moved to the ring's weight. The case asserts the artifact
since: two carriers must not draw the same mark.

##### 5.9.45.6 A guard whose condition did not name everything it hides

The designator bubble was first mounted inside `_withChrome`, which returns the BARE canvas when all
four mode controllers are null and no room has an outline. That is a real mounting and it is what
this file's own tests use, so the bubble was built by nothing and four cases said so at once. It
lives in the always-present layer with the zoom card now. **An early return is an optimisation whose
condition has to name every thing the branch it skips can show**, and this one named four
controllers while the branch had grown a fifth subject.

##### 5.9.45.7 Evidence

Floors: `rackpal_core` 4682 to 4707, `rackpal_ui` 1874 to 1895. 17 gates green throughout. Analyzer
pin unmoved at 233.

**Authoring 48 templates moved 48 content hashes**, exactly as `#899`'s wire test predicted before
`#900` ran into it: the four starters regenerate and `e_three_hundred_links.rmpj.json` gains 16
lines. **The op-count baselines in `schematic_perf_test.dart` did not move**, which is the check that
matters, because a key on a template body is not a drawing op.

**Commits** (§8.8). `#895` `31442e90`. `#896` the ruling `1023e53e`. `#897`, `#898` `8eb783fa`.
`#899` `a47ff9df`. `#900` `392578d`. `#901` `ffc9169`. `#902` `51d9ad32`. `#903` `60893c0`, and see
§5.9.46: `#897`'s clause was not met and this section said it was.

#### 5.9.46 `#903`: the mark still grew with the zoom, and the test that said otherwise · `DR-169` · no version move

2026-09-14. Reported from the product one day after `#896` closed: *"Pin sizes are changing with
zoom; I thought we set them to a fixed size?"* They were, and they were not. **`#896` was reopened**
rather than leaving §5.9.45 standing as a closed record of an unmet clause, and `#903` closes it.

##### 5.9.46.1 A repaint is not a rebuild

`_markerRadius` divides `kPlanMarkerRadiusPt` by the zoom, and it is read in `build`. But
`RenderPlanCanvas` listens to the viewport with **`markNeedsPaint`**, so a zoom REPAINTS the scene
already in the tree under a new transform and never asks for a new one. The mark therefore keeps the
scene radius its last build gave it and grows with the zoom exactly as the proportional rule
§11.168.2 retired did, snapping back to 7 points the next time anything else calls `setState`: a
hover, a selection, a command.

**Measured through the render object's own scene before anything was changed: 7.0 points at 1:1 and
28.0 at 400%.** The same two numbers are what the mutation prints when the listener is removed.

**THE FIX WAS ALREADY IN THE FILE, TWICE.** `PlanOutlineLayer`, the sibling layer in
`plan_outline.dart`, wraps itself in an `AnimatedBuilder` over the viewport, and
`rack_canvas_screen.dart` has carried `_viewport.addListener(_onViewportChanged)` since its LOD work.
The plan canvas now listens too, on **scale only**, so a pan stays a repaint of an unchanged picture
and a case asserts that by object identity on the scene.

##### 5.9.46.2 One place is not the same as one moment

§11.168.2's closing clause is explicit that a hit box disagreeing with the drawn mark *"cannot be
seen"*, and it ruled that **one place computes the radius**. One place did. What the clause does not
say is WHEN: two of the three readers build their scene inside the gesture and the third builds it in
`build`, so at 400% the mark **looked 28 points across and answered clicks over 7**. The gesture path
was right the whole time, which is why nothing felt wrong enough to investigate until somebody
looked at it.

So this is a correction under an existing ruling, not a new decision: §11.168.2's reasoning reaches
the case without its words doing so.

##### 5.9.46.3 The test proved the formula, not the product

The group certifying the clause read the radius from a scene **it built itself**:

```dart
markerRadius: kPlanMarkerRadiusPt / viewport.scale,
```

That is the production expression, retyped into the test. Five green cases over a product drawing the
mark four times too big, and **the defect was structurally invisible to them**: the formula was
right, and what was wrong was the moment it was read. A test that calls the builder itself cannot
fail that way.

**And one case was named `THE HIT BOX FOLLOWS THE MARK AT EVERY ZOOM` and never zoomed.** A name
claiming a range its body never visits is the cheapest audit in the suite.

Every reading now comes off `RenderPlanCanvas.scene` through the live viewport, and the group gained
the two properties nothing had asserted: the screen size survives a zoom, and a pan replaces no
scene.

##### 5.9.46.4 A clause of the ruling is still unbuilt, and it is the sheet's

§11.168.2 says each caller computes the radius from its own scale, *"the canvas from the viewport and
**the sheet from its page mapping**"*. `plan_sheet.dart` passes no `markerRadius` at all, so the
printed mark still takes `kPlanMarkerRadiusFraction`. **It is not visibly wrong today**, because
fitting a plan to a page turns a fraction of the underlay into a roughly fixed fraction of the page:
on a 3300x2550 scan fitted into a 700x450pt area it prints at about a **5.3pt radius**. But the fit
binds on whichever axis is tighter while the fraction reads the longer side, so the printed mark
**varies with the underlay's aspect ratio**, which is the property the clause exists to remove. The
sheet already holds `s = factor.unitsToPoints` three lines above the call.

Left open deliberately: what size a mark should be **on paper** is the user's call, not a number to
infer from the screen's 7 points. Raised with them rather than guessed.

##### 5.9.46.5 Evidence

Floor: `rackpal_ui` 1895 to 1897, net +2 over three cases removed and five added. 17 gates green.
Analyzer pin unmoved at 233.

**Mutation-tested**: removing `widget.viewport.addListener(_onViewportChanged)` puts the new case red
at `Expected: a numeric value within <1e-9> of <7.0> / Actual: <28.0>`, which is the report in two
numbers. The `AND THE CLICKS AGREE AT 400%` case **passes under that mutation**, and that is correct
rather than a weak case: it documents the half that was never broken, and it is what would fail if a
later change moved the gesture path to the built scene.

**Commit** (§8.8): `#903` `60893c0`.

#### 5.9.47 `#904`: a printed mark is the round end of its pill, and the chapter that asked was wrong twice · `DR-169` · no version move

**DEMONSTRATED** by `plan_sheet_test.dart`, group *"the printed mark"*. §11.168.2's sheet half, which
§5.9.46.4 left open, is built, and the size it builds to is the user's decision, recorded as canon
§11.168.10.

##### 5.9.47.1 The question and the answer

`#904` asked what radius, in points, a mark should measure on a printed sheet, and named the callout
pills as the obvious thing to read it against. The user answered by pointing at them. A pill is a
stadium, so its ends have a radius of half its height, and `kPlanMarkPrintRadiusPt` is
`kCalloutHeightPt / 2`. **Derived and not typed**, because `kCalloutTextPt` is itself a starting
value that `PLAN-J`'s print will settle (DR-150 §11.149.7), and the user ruled a relation rather
than a number.

##### 5.9.47.2 Measured before it moved

Off the rendered `T1.01` ops on ANSI B landscape, one outlet and one device per plan, 2026-09-14:

| Underlay | Fit, pt per px | Radius under the fraction, pt | Outline, pt | Device ring, pt |
|---|---|---|---|---|
| 600x450 | 1.2600 | 6.87 | 2.52 | 4.41 |
| 2000x1500 | 0.3780 | 6.87 | 0.76 | 1.32 |
| 1500x2000 | 0.2835 | 5.15 | 0.57 | 0.99 |
| 3300x2550 | 0.2224 | 6.67 | 0.50 | 0.78 |
| 2550x3300 | 0.1718 | 5.15 | 0.50 | 0.60 |
| 4000x1000 | 0.2805 | 10.20 | 0.56 | 0.98 |
| 6600x5100 | 0.1112 | 6.67 | 0.50 | 0.50 |

The outline and ring columns are printed widths with both backends' 0.5-point floor applied, and
`#904` changes neither. The radius column is what it replaced: every row now prints the pill's end.

##### 5.9.47.3 The chapter was a hypothesis, twice

1. **"About 5.3pt."** That figure was computed against a 700x450-point area. The sheet's drawing area
   is larger, and the ordinary 4:3 landscape plan printed at 6.87 points, so matching the pill
   **visibly shrinks the common case**, by about a quarter. That is the decision working, and it is
   written here so nobody files it as a regression.
2. **"The seam is three lines away."** The chapter said `s` was computed *"immediately before the
   `buildPlanScene` call"*. It was computed after it, from `plan.underlayBounds`, so the fit read the
   scene and a radius taken from the fit would have been an argument to the scene it depended on.
   `planUnderlayBounds(underlay)` is now the one answer both read, and the sheet fits before it
   builds.

##### 5.9.47.4 The default went, because the default was the defect

`buildPlanScene`'s `markerRadius` defaulted to 1/110 of the underlay's longer side. The canvas
stopped taking that default at `#897`; the sheet never did, and nothing said so. **The parameter is
required now**, so a surface that forgets to state its scale does not compile, and
`kPlanMarkerRadiusFraction` is deleted.

**A case went with it that had been certifying the retired rule.** `plan_scene_test.dart`'s *"a
4000px plan and a 600px plan get proportionate marks"* asserted exactly the property §11.168.2
retired, and stayed green because the sheet kept the default alive. Deleting the default is what
turns such a case red, so it argued for keeping what the ruling had removed. The OKF practice on
tests that certify a defect records it as a fifth mouth.

##### 5.9.47.5 What did not move: the line weight

The outline is `Stroke(widthPt: 2)` in scene units with `scaleWithGeometry` at its default, so it
still rides the fit, as the table shows. On a 6600x5100 scan a device's ring and an outlet's outline
both print at the floor, and **a device prints exactly like a drop**, which is the distinction `#901`
put in the ring weight.

On screen the same stroke paints at twice the zoom in physical pixels. **That half is read from the
code and not yet measured**: `RenderPlanCanvas` applies the viewport as a layer transform and
`FlutterDiagramCanvas` starts its own stack at identity, so its `_k` is 1. The same reading says
**flipping `scaleWithGeometry` would fix paper and not the screen**, since the zoom never reaches
`_k`. What a mark's line weighs is the user's, and is `#905`, created before this section cites it.

##### 5.9.47.6 Evidence

Floor: `rackpal_core` 4707 to 4708, net +1 over two cases added and one removed. 17 gates green.
Analyzer pin unmoved at 233.

**Mutation-tested.** Restoring the fraction in `plan_sheet.dart` puts both new cases red: *"two plans
of different proportions print the same mark"* at `Expected: 5.1545 / Actual: 6.8727`, and the pill
case at `5.25 / 6.8727`. Replacing the derived constant with a literal `5` puts the pill case red at
`5.25 / 5.0` and leaves the proportions case green, which is correct, since a constant is constant.

**Commit** (§8.8): `#904` `77eab81`.

#### 5.9.48 `#905`: a mark's line weight is the drafting weight, and the zoom was in a layer the canvas could not see · `DR-169` · no version move

**DEMONSTRATED** by `plan_mark_weight_test.dart`, by `plan_sheet_test.dart`'s *"a printed Network
device keeps its ring clear of its glyph"*, and by `plan_canvas_screen_test.dart`'s *"AND ITS OUTLINE
IS THE SAME WEIGHT ON SCREEN AT EVERY ZOOM"*. The weight is the user's decision, recorded as canon
§11.168.11.

##### 5.9.48.1 The question, the options and the answer

`#905` asked what a mark's outline weighs, fixed at every zoom and on every scan. Three were drawn
side by side at one enlargement: **drafting weights** (0.7 and 1.4 points, one and two pixels), **the
pill's hairline** (0.5 and 0.875 points), and **today's look at 100%, frozen** (2 and 3.5 pixels, so
1.5 and 2.6 points). The user chose the drafting weights.

##### 5.9.48.2 Measured before it moved, on both surfaces

On paper the table in §5.9.47.2 already carries it: a drop and a device at 2.52 and 4.41 points on a
600x450 scan and **0.50 and 0.50** on a 6600x5100 one. On screen, painted through
`TestRecordingCanvas` with the real render object:

| Zoom | Drop outline, px | Device ring, px | Mark radius, px |
|---|---|---|---|
| 25% | 0.5 | 0.875 | 7 |
| 100% | 2 | 3.5 | 7 |
| 400% | 8 | 14 | 7 |

**The first probe recorded no stroked circle at all**, because `drawEllipse` fills with `drawOval`
and strokes through `drawPath`. A probe watching the wrong call reports a clean screen, so it was
rewritten to log every call before any reading was believed.

##### 5.9.48.3 The corner that caps the ring

Network's glyph is a filled square (`'■'` in `family_glyph.dart`'s `_shapes`), and a square fills its
box of 1.15 radii, so its corners reach 0.813 of the radius. A ring whose inner edge crosses that
point runs black into black, which puts a ceiling of about 37% of the radius on the ring: 1.96 points
on paper and 2.6 pixels on screen. **The 3.5-pixel ring was already over it at 100%.** The drafting
weights clear it on both surfaces, the pill's hairline clears it, and today's look frozen does not.

##### 5.9.48.4 The obvious fix would have failed on screen

The radius is divided by the zoom, so the obvious weight fix is the same division, and **it would
have painted a one-pixel line at two pixels from 400% up.** The plan, rack and schematic canvases
push the viewport as a `pushTransform` layer so a pan re-projects a cached picture, and
`FlutterDiagramCanvas` starts its own transform stack at identity every paint. Its `_k` therefore
reads 1 at every zoom, and its 0.5 floor, taken against that `_k`, lifts a quarter-unit stroke back to
half a unit. At the viewport's 32x limit, a one-pixel line would have painted at sixteen.

So the marks are `scaleWithGeometry: false`, CR-082's existing spelling of "constant on the surface",
and the canvas gains `outerScale`, which `RenderPlanCanvas` sets to its zoom. The rack and schematic
canvases have the same layer and pass nothing, so nothing of theirs moves. **Whether their own
non-scaling strokes carry the same blind spot is not measured here** and should not be read as
cleared.

##### 5.9.48.5 The weight left the palette

`PlanPalette.marker` was a `Stroke` of width 2, and a palette is shared by every surface, so that
width was in scene units by construction. It is `markerInk` now, a colour. `buildPlanScene` takes a
required `markerWeight` in SURFACE units beside `markerRadius` in SCENE units, and its doc comment
says so in its heading because the two parameters sit side by side. `familyGlyphOp` gains an optional
`hollowScalesWithGeometry`, and `kPlanDeviceRingFactor` is 2, from 1.75. The rack datum's square and
cross take the drop's weight, which is the relation they had before (§11.168.8).

##### 5.9.48.6 Evidence

Floors: `rackpal_core` 4708 to 4709, `rackpal_export` 227 to 229, `rackpal_ui` 1897 to 1898. 17
gates green on the code commit's own tree with this record held aside, and again over this record.
Analyzer pin unmoved at 233.

**Mutation-tested four ways, all killed**, every file restored and checked byte-identical:

| Mutation | What goes red | Reading |
|---|---|---|
| Weights scale with geometry again | both paper cases, the clearance case, the screen case | paper 0.882 against 0.500 and a ratio of 1.0; screen 8.0 against 2.0 |
| The plan canvas is not told its zoom | the screen case | 8.0 against 2.0 |
| Option C on paper, a 1.5-point drop | the clearance case | ring inner edge at 3.75 points inside a corner at 4.27 |
| Ring factor 1 | the paper ratio case, and *"a device reads apart from an outlet"* | 1.0 against 1.4 |

**Commit** (§8.8): `#905` `222cf31`.

#### 5.9.49 `#906`: the rack and the schematic zoomed in the same layer, and their chrome grew with it · `DR-170` · no version move

**DEMONSTRATED** by the chrome-width groups in `render_schematic_canvas_test.dart` and
`port_chip_test.dart`, and by `stroke_scaling_test.dart`'s *"outerScale takes BOTH decisions"*. The
widths and the floor are the user's decisions, ruled as canon §11.169 (DR-170) in `fb63fab` and pushed
ahead of the code to claim the number.

##### 5.9.49.1 Found at `#905`, measured before it was ruled

`#905` found the plan canvas zooming in a `pushTransform` layer above a cached picture, where
`FlutterDiagramCanvas`'s stroke rules read scale 1, and fixed that canvas alone. The rack and the
schematic canvases zoom the same way, and were probed through `TestRecordingCanvas` on the real render
objects before any width was chosen:

| Chrome | Authored | Rack at open, 3.02x | Rack at 12.1x | Schematic at 4x |
|---|---|---|---|---|
| Selection outline | 2 px | 6.0 px | 24.2 px | n/a |
| Hover ring | 1.5 px | 4.5 px | 18.1 px | n/a |
| Port chip | 1 px | 3.0 px | 12.1 px | n/a |
| Caret, source, candidate and selection rings | 2 px | n/a | n/a | 8 px |
| Connect band | 1.5 px | n/a | n/a | 6 px |

**The census by flag could not have found the rack's rings.** Searching for
`scaleWithGeometry: false` found the port chip and the connect overlay; the hover, focus and selection
rings are raw `Paint` strokes, and only the probe found them, because it measured every stroke painted
rather than every stroke flagged. The grid painter and the editing overlay painter already divide by
`viewport.scale` and were right.

##### 5.9.49.2 The two decisions

Chrome at its authored width at every zoom (§11.169.2), which is visibly thinner when a rack first
opens because it opens at about 3x; and no line thinner than half a physical pixel (§11.169.3), which
moves the floor to physical pixels for lines that scale too, so a 0.7-unit wire at 30% zoom goes from
0.21 pixels to 0.5. Both alternatives were put to the user, and the reason each lost is in the canon.

##### 5.9.49.3 The first channel landed on a wrapper

The schematic and rack canvases pass `outerScale: _viewport.scale`. The device box holds no viewport,
so the first build handed it the scale in `RackParentData`, written in the parent's paint loop. **The
new rack case went red at 4.54 against 18.14, which are the pre-fix numbers exactly.**
`RackDevicePlacement` gives its parent data to the rack canvas's DIRECT child, and that child is the
`FocusableActionDetector` which `DeviceBox.build` puts above `RenderDeviceBox`, so the scale was
written to a wrapper and the box read its default of 1. It now walks to its nearest `RenderRackCanvas`
at paint and reads the viewport there. Its ring widths AND insets divide by that scale, because the
inset is half the ring's width and a ring thinned without it would drift inside the body.

##### 5.9.49.4 A selector that picked the right colour and the wrong stroke

The rack case first picked the chip's strokes by `PortChipStyle.strokeArgb` and found a 3.63-pixel
stroke among them: the device body's own 1.2-unit outline, which shares that colour and is right to
scale. It now paints the rack with the chip and again without it, and takes the run of strokes only the
first paint made.

##### 5.9.49.5 Evidence

Floor: `rackpal_ui` 1898 to 1904. 17 gates green on the code commit's own tree, and again over this
record. Analyzer pin unmoved at 233.

**Mutation-tested four ways, all killed**, every file restored and checked byte-identical:

| Mutation | What goes red | Reading |
|---|---|---|
| The schematic canvas is not told its zoom | both schematic cases | band 6.0 against 1.5; thinnest line 0.05 |
| The device box never finds its rack canvas | both rack cases | rings 18.14 against 4.54; thinnest line 0.10 |
| The rack chassis canvas is not told its zoom | the zoomed-out rack case, and nothing else | thinnest line 0.08 |
| `FlutterDiagramCanvas` ignores `outerScale` | both unit cases and both schematic cases | a non-scaling stroke at 0.5 against 2.0; the floor at 0.07 against 0.5 |

**The third row would have survived** without the zoomed-out rack case, which was added for that reason:
the rings and the chip are drawn by the boxes, and no other case looked at the chassis canvas.

**Commits** (§8.8): `#906` `d257104`, with the ruling in `fb63fab`.

#### 5.9.50 `#907`: the gap DR-170 named was already ruled, and the band stays solid · `DR-170` · no version move

**CONFIRMED** by the user's decision, and shown by the corpus itself: no document now gives the band the
source domain's styling, and canon §11.169.6 states that the band is solid. No product change.

##### 5.9.50.1 The claim, and what canon already said

DR-170's own scope note, written at `#906`, called the rubber band's colour, weight and dash an open gap
because docs/05 §7.5 item 5 gives them to the source domain, and `#907` was filed on it. **Canon had
ruled the colour weeks earlier.** DR-114 §11.113.2 names *"the caret ring, the source ring, the rubber
band"* among the cursor chrome that keeps theme roles, and the width is DR-170 §11.169.2's. docs/05 was
the stale sentence, and the note was written without grepping canon for the noun.

##### 5.9.50.2 The citation nearly failed the same day

The clause sits under a heading written `### §11.113 DR-114`. A search for `^### 11\.` skipped the
section sign and reported DR-105, and the clause number 11.113 invites reading it as DR-113. It was
resolved against the heading line itself and against this document's M5-D row, which names DR-114 for
*"a verdict is not a cursor"*.

##### 5.9.50.3 The decision

Three options were put to the user: close as ruled; the family's dash only; and full domain styling,
which would have reversed DR-114 and DR-170. **The user chose to close as ruled, with the band solid**,
recorded as §11.169.6, because a dashed band on this canvas already means a right-to-left marquee: CR-102,
*"right→left selects intersecting (dashed band, `CROSS`)"*.

##### 5.9.50.4 Evidence

Docs only. DR-170's scope note and docs/10's row are corrected in place in `46e3adb`, gated green on its
own tree; docs/05 §7.5 item 5, this section and the OKF follow in the next commit.

**Commit** (§8.8): `#907` `46e3adb`, the ruling and the correction.

#### 5.9.51 `#558`: outlet counts are read off ports and cords, and the stored fields leave every format · `DR-171` · no version move

**DEMONSTRATED** by `device_outlets_test.dart`, by `totals_test.dart`'s outlets group, by
`migration_corpus_test.dart`'s *"v5 -> v6"* group run over a real starter's bytes, and by the four
regenerated starters. Board `#558`'s ruling of 2026-08-03 is recorded as canon DR-171, together with the
two sub-decisions it left open and the chip's presentation, all three the user's.

##### 5.9.51.1 A ruled item that canon never heard of

`#558` carried RULED on the board from 2026-08-03 and had no canon section. docs/06 §3.3 said both counts
were read-only and counted from ports; `derived/device_loads.dart` read two authored `PowerProfile`
integers instead, and the chip strip, `PWR-003` (M5-E) and its remedy (DR-128) were all built on them
afterwards. The item's own text named the unwired design as open.

##### 5.9.51.2 Measured before anything was ruled

Over the tree at `d4479d8`:

| What | Found |
|---|---|
| Seed templates stating `outletsProvided` | 35 of 51, all agreeing with their outlet-role ports |
| Seed templates stating `outletsConsumed` | 35 of 51; 29 agree with their inlet ports, and 6 state 0 against one inlet (`F09`, `F11`, `F12`, `F16`, `V06`, `V07`) |
| Conductors landing on a power inlet in the four starters | none, over five racks and 27 links |
| Links the classifier calls `powerCord` | none can be: `linkClassOf` answers `jumper` or `fieldCable` (`#908`) |

So the ruling as written would have read `outlets 0/N` on every starter rack and left `PWR-003` unable to
fire before somebody drew cords.

##### 5.9.51.3 The decisions

Put to the user with that measurement, and all four answered:

- **Before a cord is drawn**: cords where drawn, else inlet ports, said so (chosen); cords only with the
  rest unknown; or both figures on the chip.
- **How often cords are drawn**: for PDU-fed gear, where sequencing or remote reboot matters. That made
  the rule per device rather than per rack.
- **The stored fields**: delete them now, with migrations.
- **The chip**: the hover sentence only, over a tilde or a dimmed figure.

Recorded as §11.170.2 to §11.170.4 and §11.170.9.

##### 5.9.51.4 What building it found

- **An empty port list would have read as a measured zero.** §11.170.2's "complete description"
  presupposes a described template, and AC-049 lets one be saved with no ports. Ruled on G4 as unknown,
  §11.170.8. The three passive templates have no ports and stay unknown, as they were; a template with
  ports and no power port, such as the patch panel, becomes a measured zero.
- **The census covered the seed templates, not their variants.** The `V06` receiver, whose PoH input is
  clause 2's own case, is a role variant, and the first draft of its test found null.
- **The rollups now depend on the graph.** `epoch_mask_test`'s permissive mapping gains `wires` for them,
  and `computeRackRollups` takes the document's landings as a required argument rather than a default.
- **`drawer_is_wired_test` authored a count and no ports**, which under §11.170.8 is a device nobody
  described, so all nine of its cases failed on the first gate run. Its fixture has a real inlet now.
- **A migration step that decodes is right only while it is the last step.** `.rmdx`'s v1 -> v2 step
  decoded its body to recompute the hash; with v2 -> v3 behind it, that is a newer reading of an older
  map. Every step now hashes its own raw output, and the v5 group asserts on a real starter that this is
  the hash `templateContentHash` takes.
- **`.rmda` had no chain.** It refused every version but its own; v2 now migrates entry by entry.

##### 5.9.51.5 Evidence

Each starter rack's outlet chip, measured through `computeRackRollups` on the regenerated starters:

| Starter rack | Before (authored counts) | After (DR-171) | Counted from ports | `PWR-003` |
|---|---|---|---|---|
| `apartment` RK-1 | `outlets 5/16` ⁽²⁾ | `outlets 5/16` ⁽¹⁾ | 4 devices | none |
| `home_theatre` RK-1 | `outlets 12/40` ⁽⁴⁾ | `outlets 12/40` ⁽³⁾ | 11 devices | none |
| `small_office` RK-1 | `outlets 11/40` ⁽⁵⁾ | `outlets 13/40` ⁽³⁾ | 11 devices | none |
| `small_office` RK-2 | `outlets 3/16` ⁽²⁾ | `outlets 3/16` ⁽¹⁾ | 2 devices | none |
| `whole_house` RK-1 | `outlets 23/74` ⁽⁹⁾ | `outlets 24/74` ⁽⁵⁾ | 21 devices | none |

The superscripts fall because a template with ports and no power port is now a measured zero rather than a silence; the port-less blanks, vents and shelves stay unknown. Consumed rises where a shipped template stated 0 against a real inlet. No starter drew a single cord, so every consumed figure is counted from ports, which the hover now says.

- In each starter, the 35 template bodies that stated counts are re-hashed and the other 16 keep their
  hashes. `v5_outlet_counts.rmpj.json` is `apartment.rmpj` as shipped at `de9a2f7`, captured before the
  regeneration.
- 17 gates green on each of `355d553`, `de9a2f7` and `1f21c1f`, every suite exactly at its floor: rackpal_core 4709 -> 4724 -> 4734, rackpal_ui 1904 -> 1907. Analyzer pin unmoved at 233.

**Commits** (§8.8): `#558` `355d553` (the ruling), `de9a2f7` (the derivation), `1f21c1f` (the
format).

#### 5.9.52 `#560`: the undo depth is a per-machine preference, and a full history says so once · `DR-172` · no version move

**DEMONSTRATED** by `document_controller_test.dart`'s *"undo depth"* group, by
`document_session_test.dart`'s *"undo history on the status line"*, by `preferences_dialog_test.dart`, and
by `preferences_menu_test.dart`, which drives Edit > Preferences through the real shell to the open
document, the status line and `prefs.json`. Canon §10.12(a)'s answer of 2026-08-03 is built as DR-172,
with four decisions the user made and three made while building it.

##### 5.9.52.1 A setting nothing could set

§10.12(a) answered *"keep 200, and make it a setting"*. The 200 was `UndoStack`'s constructor default,
and both stacks, `DocumentController`'s and `TemplateEditSession`'s, were built with no argument, so no
path anywhere could set it. The oldest entry dropped with no signal, which AC-058 D5 had ruled out in
so many words. And the app had no surface for a setting that belongs to the machine: `#805` closed the
project-settings editor under File, because those settings travel in the file.

##### 5.9.52.2 Measured, then asked

The status line never clears itself, docs/03 §11.1 sets 200 entries as the scale target with no hard
cap and no memory figure, and #805's File > Project settings keeps what travels. Four questions went to
the user with those facts, and all four answers were the recommended option: `prefs.json` edited in a
new Edit > Preferences; a whole number from 50 to 1000; immediately; the full notice once per document;
one setting for the document and the Device Builder.

##### 5.9.52.3 What building it found

- **The first document was built before the preferences loaded.** `app_services.dart` constructed the
  session's controller and only then read `prefs.json`, so the starting document would have taken the
  default. The load moved ahead of it.
- **The project dialog's number rows commit when focus leaves them**, and copying that here would drop
  history on a half-typed value. The depth field commits on Enter or Close only.
- **Dropping the entry the save point sits on changes `editsSinceSave`**, so a resize goes through the
  controller, which rings its change notifier when anything went.
- **`SetRackHeightCommand` coalesces inside the 400 ms merge window**, so the session tests count steps
  on a clock that moves between edits. A test that counts undo steps has to check `mergeKey` first.
- **Two appended test groups landed outside `main`.** The inserter took a file's last closing brace as
  `main`'s, and in two files a helper and a fixture class follow `main`: one group declared tests while
  tests ran, the other stopped the file compiling. Both were moved.
- **A new menu item is a decision `session_layering_test` makes you record.** RULE 14 pins the shell's
  `MenuItemButton` and accelerator counts as a dated history, and Edit > Preferences... moved it from
  `[13, 6]` to `[14, 6]`. The rule gained a "13 -> 14 AT DR-172" entry saying why the item is on Edit
  and carries no accelerator, and its reason string now names the Edit menu, which DR-159's entry had
  left out. The same run caught an untyped test constant that raised the analyzer count to 234.

##### 5.9.52.4 Evidence

- 17 gates green on the ruling alone and on the build, every suite exactly at its floor: rackpal_core 4734 -> 4742, rackpal_ui 1907 -> 1916, rackpal_app 1037 -> 1045. Analyzer pin unmoved at 233.

**Commits** (§8.8): `#560` `7d10974` (the ruling), `7151178` (the build).

#### 5.9.53 `#112`: a matrix's zone audio is a stereo pair per zone · `DR-173` · no version move

**DEMONSTRATED** by `matrix_zone_audio_test.dart`, which asserts each of V01's 8 and V03's 16 zones as
an L and an R balanced 3-pin block in one atomic `stereoPair` set, and V02's four S/PDIF outputs as
unchanged; by `port_set_integrity_test.dart`, over the whole seeded catalogue; and by the regenerated
starters and 300-link fixture.

##### 5.9.53.1 Asked, with the trade answer

The measured facts went to the user: V01 declared 8 mono zone ports and V03 16, V02 de-embeds to S/PDIF
on one connector, and V05 already models a stereo output as one 5-pin block. The answer was an L/R pair
per zone, with a qualification: some matrices and amplifiers number their channels without L and R. The
Triad TS-AMS kind cannot split zones and the ELAN EL-IPD-MTX-8CH kind can. Canon §11.172.3 records it as
the ruling's bound.

##### 5.9.53.2 What building it found

- **V03's sets were declared and dropped.** Its `TemplateBody` never passed `portSets: v03.portSets`,
  which V01's did. `port_set_integrity_test` named all 32 ports as dangling, the failure its own reason
  string predicts.
- **The label grammar cannot pad a grouped counter**, so V03's pairs read `AUD OUT 1 L` beside
  `HDMI OUT 01` (§11.172.4).
- **V01's zone bank now collapses**, at 16 ports against `kBankCollapseThreshold`'s 8. A probe of the
  failing DR-128 test found its drag had expanded the bank and drawn no cable.
- **The set gesture never asks tier 2.** Expanded or not, the DR-128 test's CON-001 pair could not
  raise its chip: `_commitSet` runs `planAtomicConnect`, which is tier 1, and commits. The pin connect
  and the bind both call `evaluateSpringBack`, and DR-116 §11.115.3 rules that a rule is about the
  resulting state. Filed as `#909`, not folded in. The test's pair moved to V05's 5-pin output into
  A03's `in.1`, the only same-family audio shape a census over non-atomic ports found. The first sweep,
  with no family filter, counted 119,008 CON-001 pairs and was noise.
- **The 300-link fixture's two amplifier runs now take zones 1 to 4, L and R**, where they took eight
  mono outputs. Eight endpoints moved, and the op counts did not: total 3463, labels 948, symbols 2515.
- **All four starters embed both matrix templates**, so all four regenerate with 48 new pair ports.
  No starter wires a zone output.
- **A saved project keeps its mono matrices, and no cable orphans.** Placement resolves through
  `resolveLatestTemplate`, the project's own newest snapshot, and `SaveTemplateToProjectCommand` writes
  only a key `nextTemplateVersion` proved free. A project already holding V01 at version 1 goes on
  placing its 8-port body, so a seeded port that disappears reaches no existing cable. That is CR-050's
  pinning working as designed, and `renamedFrom` owes nothing until the Update Manager (AC-041, v1.2).
- **A marquee test had stopped proving anything, and a second was about to.** `schematic_marquee_test`
  started its drag 400 scene units above-left of MTX-1. The taller matrix refitted the sheet, and that
  point moved to screen y 49.5, above the canvas's top edge at 61, into the toolbar: the drag raised no
  band and failed. The click test beside it used the same point and kept passing, because a click on the
  toolbar raises no band either. Both now start through `bareStart`, which asserts the point is on the
  canvas, and a control run with the old point failed on that reason.
- **§6.3's worked example moves from 44 port objects to 52**, measured from V01's template in a
  starter before and after.

##### 5.9.53.3 Evidence

- 17 gates green on the ruling alone and on the build, every suite exactly at its floor:
  rackpal_core 4742 -> 4747. Analyzer pin unmoved at 233.

**Commits** (§8.8): `#112` `a7c412b` (the ruling), `1788e3e` (the build).

#### 5.9.54 `#111`: a set on one cable draws one pennant on a bracket · `DR-174` · no version move

**DEMONSTRATED** by `net_label_layer_test.dart`'s DR-174 group: an intact pair draws one pennant per
end, centred between its pins, with a spine at each end; a split set draws a pennant per pin and no
spine; a partly wired two-conductor cable draws none; a top-edge set draws exactly what a one-conductor
cable on its first pin draws; the pennant sits as far out as a split pin's; and the bracket's ink is
inside the scene bounds.

##### 5.9.54.1 A board ruling, recorded, then two questions

The ticket said *"one pennant on a bracket spanning the set pins"*, only when the whole set is one
cable, ruled by the user on 2026-08-01. Canon mentioned `#111` only as DR-014's deferral, so the
ruling was recorded as DR-174 §11.173.2, as `#558`'s was. Two questions went to the user with the
measured geometry, and both answers were the recommended option: the pennant centred on the bracket,
and the bracket in the leader's signal colour.

##### 5.9.54.2 What building it found

- **One NUL byte hid the file from grep.** `_edgeKey` joined its parts with a raw 0x00 inside a
  string, so grep and ripgrep read all 76 KB of `net_label_layer.dart` as binary. The first census for
  "pennant" missed the file that draws them. Fixed first, in its own commit, with the escape `_pinKey`
  already used.
- **The label layer never saw an intact pair's second pin.** `_endsOf` labels a link by
  `conductors.first`, so the bracket test has to read the document, not the drawing.
- **The census's first figure was the default, not the edge.** It put all 70 seeded sets on the left,
  because 155 of 159 banks store the undeclared `left` and `symbolSideForPort` falls through that
  default to direction. Recomputed: 46 right, 24 left, none top or bottom, every set two adjacent pins
  in one bank, 52 in banks that may collapse.
- **The bracket fits inside the leader's room.** The spine sits halfway along the leader and the
  pennant lands as far out as any other, so `netLabelGutterGu` needed no second formula.
  `RenderedNetLabel.pinCentre` stays the first conductor's pin, which the wire trace and the hit tests
  read; only the pennant box moves.
- **No committed drawing moves.** The six multi-conductor links in the starters and fixtures all end
  at field or unterminated endpoints, and the 300-link fixture has none.
- **A dry run of the edit script caught a duplicated anchor.** `_pennantPath` opens with the same
  statement as `emit`'s pennant line, so the script refused on the copy before touching the tree.
- **Two analyzer infos, both copied or written in.** A doc reference to a record field, and a
  redundant default argument copied from the existing fixture builder, whose original already sits
  inside the pin.

##### 5.9.54.3 Evidence

- 17 gates green on the ruling alone, on the NUL fix alone, and on the build, every suite
  exactly at its floor: rackpal_core 4747 -> 4753. Analyzer pin unmoved at 233.

**Commits** (§8.8): `#111` `4550282` (the ruling), `4c08f9c` (the NUL fix), `28e2d35` (the build).

#### 5.9.55 `#81`: registry parity holds the descriptive fields to the specification's family table · `DR-175` · no version move

**DEMONSTRATED** by `python tools/registry_parity.py` at exit 0 on the tree, and by mutation on copies
of its four inputs before it landed. A changed tag, connector, direction or name, a removed row and an
unreadable Dir cell each exit 1 with a named drift, a removed §4.4 heading exits 1 as a parse failure,
and a name wrapped in bold still passes. Every case ran under a cp1252 console encoding.

##### 5.9.55.1 Not ruled, then asked

`#81` was listed in this session's queue as ruled. It was not: the ticket, filed from the DR-010
agent's mutation M13, describes a gap, and the gate's own OKF record calls the blindness deliberate
and the gap open work. Measured before asking: seed-devices §4.4 tabulates all 57 seeded families
with the display name, default connector, direction, topology, tag and glyph, and it agrees with the
seed on every id, every tag and every name once markdown bold is removed. Four options went to the
user; the recommended one was chosen.

##### 5.9.55.2 What building it found

- **The table already agreed.** Nine names differ only by bold and one connector cell is `—`, so the
  gate starts green and its first commit reconciles nothing.
- **The Dir and Topo cells are prose.** *"→ (+ARC ↔)"* and *"BUS, topology-free"* carry a leading
  symbol or word that maps onto the seed on every row, including `⤳`, which §4.4's key calls logical
  flow riding a network and the seed stores as bidirectional.
- **The glyph cannot be compared.** The seed stores none per family (DR-010 §11.10.3); the table's
  Glyph column is the domain's glyph, native or transported.
- **A console encoding decides whether the gate can print.** CI prints to a console that cannot
  encode `→` or `Ω`, so every new message is ASCII and cell text is escaped.
- **The first mutation run tested the harness, not the gate.** It stopped at case three on its own
  anchor, because the seed puts each argument on its own line.
- **The failure advice is conditional.** A drift ending "(section 4.4)" gets the "fix whichever is
  wrong, do not regenerate" advice, and the palette advice prints only when a palette drift is
  present.

##### 5.9.55.3 Evidence

- 17 gates green on the ruling alone and on the build, every suite exactly at its floor, with no
  test floor moved. Analyzer pin unmoved at 233.

**Commits** (§8.8): `#81` `2dac125` (the ruling), `b50412c` (the build).

#### 5.9.56 `#561`: your rack presets are saved from a rack, kept per machine, and sit beside seeded presets you can hide · `DR-016`, `DR-176` · no version move

**DEMONSTRATED** by `user_rack_presets_test.dart` (the file's round trip, what a reader skips and the
merged order), `rack_presets_store_test.dart` (a missing or unreadable file, an atomic write on a
first save and on a second), `save_rack_preset_dialog_test.dart`, and the your-presets groups in
`rack_inspector_panel_test.dart`, `new_rack_dialog_test.dart` and `preferences_dialog_test.dart`.

##### 5.9.56.1 A scope addition nobody built, then three questions

DR-016 was ruled inside canon §10.12(c) on 2026-08-03, with a milestone cell of M1, and named no
surface, store or rule for the seeded presets. Three questions went to the user with the measured
seam, and all three answers were the recommended option: save from a rack in the inspector; a
per-machine `rack_presets.json` beside `prefs.json`; the seeded eleven hidden, never edited. Recorded
as DR-176 §11.175.

##### 5.9.56.2 What building it found

- **Two places build the preset map, not one.** The rack canvas built it for its inspector and its
  New rack dialog, and the app shell built another for the same dialog opened from a project with no
  rack. A draft of DR-176 said one map fed every surface; reading the callers corrected it before it
  reached canon, and the shell now hands both the same merged map.
- **A byte-reader census failed the first storage gate.** `import_hardening_test` lists every lib file
  that reads bytes and whether it is an import path in D8's sense. `RackPresetsStore` reads only this
  machine's own file, so it is listed beside `PrefsStore` as not one.
- **`tracked sources` went red twice for an unstaged new lib file**, on the core and the storage
  commits, with every other gate green. Staging and re-running that check alone cleared both; the UI
  commit was staged before its gate.
- **A custom-width rack is refused with a reason.** A preset keeps a width class and no panel width,
  so it could not bring that rack back.
- **The headings appear only once one of yours exists**, so with none both Preset lists are exactly
  what they were and no existing dropdown test moved. They are asserted from the dropdown's configured
  items, because an open menu builds only the rows that fit.
- **A preset's id is `user:` plus a slug of its name.** No id generator existed to reuse, and names are
  already unique because the dialog refuses a duplicate.
- **Every new parameter is optional.** Tests build the rack canvas 29 times and the inspector panels 6.

##### 5.9.56.3 Evidence

- 17 gates green on the ruling alone and on each of the core, storage and UI commits, every suite
  exactly at its floor: rackpal_core 4753 -> 4762, rackpal_app 1045 -> 1052, rackpal_ui 1916 -> 1932.
  Analyzer pin unmoved at 233.

**Commits** (§8.8): `#561` `e09eda7` (the ruling), `07784cf` (core), `2331c05` (storage), `a1f70f7`
(the UI).

#### 5.9.57 `#843`: a test that asserts a time runs in its own gate step, one test at a time · `DR-178` · no version move

**DEMONSTRATED** by the gates themselves: `run_local.ps1` and `azure-pipelines.yml` run the core
suite with `-Tests untimed` and then `rackpal_core_timed` with `-Tests timed`, after every other
suite. 5 tests ran in the timed step and 4,759 in the core suite, each exactly at its
floor.

##### 5.9.57.1 The false red, and the ruling

On 2026-09-05 a commit touching three markdown files failed the core suite: the text-bound schematic
budget read 20.877 ms against a 16.67 ms frame, and 6.355 ms run alone. The file asserted op counts
and stopwatch readings in one call, under a file-wide `perf` tag that nothing filtered. Measured
before the user was asked: 184 builds since, two failures, both the machine; alone, about 5 ms. The
user ruled the recommended option, recorded as DR-178 §11.177.

##### 5.9.57.2 What building it found

- **The two one-frame budgets asserted both halves in one helper**, `_measure`, so they became four
  tests: two that assert op counts, in the suite, and two that assert the stopwatch, in the timed step.
  The file went from 15 tests to 17, of which 5 are timed.
- **A timed test cannot lean on a shape test it no longer runs beside.** The augmented document's nets
  and the twelve-pod link count are re-asserted inside the timed tests, because a precondition checked
  in another step is not a precondition of this measurement.
- **`paint_budget_test.dart` carried the tag and asserted no time.** It prints its timings and checks
  cache counts, so it lost the tag and stays in the ui suite.
- **Only core is split.** A `perf` tag written in any other package still runs in its own suite: an
  exclusion with no step running what it excludes would drop a test silently, which is what the old
  "no tag filtering" note existed to prevent, and `run_suite.ps1` now says so.
- **The partition was proved by breaking each half.** With nothing broken, the timed run passed 5 and the untimed run 12. Setting the frame budget to 0.001 ms failed 3 of the 5 timed tests, the ratchet and the tier comparison not reading the frame, and left all 12 untimed tests green; putting the symbol-layer op count off by one failed 2 of the 12 untimed tests and left all 5 timed tests green.

##### 5.9.57.3 Evidence

- 17 gates green on the test commit, rackpal_core 4762 -> 4764, and 18 on the step commit, rackpal_core 4764 -> 4759 with rackpal_core_timed at 5, every suite exactly at its floor. Analyzer pin unmoved at 233.
- docs/12 §5.1's M2 rows now cite the timed tests and the op-count tests by their new lines, and say
  where each runs.

**Commits** (§8.8): `#843` `8d97776` (the ruling), `4054b2f` (the tests), `f6f1b22` (the step).

#### 5.9.58 `#92` and `#780`: the clause tables carry marks, and roadmap §8.9 is a gate · `DR-095` · no version move

**DEMONSTRATED** by `tools/milestone_gate.py`, which runs twelve planted cases and then reads this
board: the Plan view is current, and M0 to M5 hold 8, 8, 5, 8, 2 and 3 exit clauses with none owed,
M3's two parked on M6 by DR-027. It runs in `run_local.ps1` and in the pipeline beside registry
parity.

##### 5.9.58.1 What `#92` still held

`#92` was a checkpoint written after M2. By 2026-09-15 most of it had been answered elsewhere, and
the user ruled its remaining scope as unblocking the milestone gate:

- **The full-tree code review** had moved to `#97`, deferred until after the smoke test.
- **`RemoveDeviceCommand`'s orphaned ports and links** were ruled by DR-013 (§11.13, cascade) on
  2026-08-01 and built.
- **`wire_trace.dart` in `rackpal_ui`** is M6's blocker, recorded by DR-150 §11.149.6 and §11.149.7.
- **The documentation re-sweep for M3** became the normalisation DR-095 §11.94.6 made a prerequisite
  of `#780`: every clause table in §0's seven marks.

##### 5.9.58.2 What re-marking the tables found

- **M3's four `BUILT` rows were already demonstrated, by a test the table never cited.**
  `drop_line_planner_test.dart`'s whole-drill test drives docs/16's ten lines through the real planner
  on one document and asserts every field the clauses name, at sixty. The table cited code lines and
  a UI test named for sixty drops that types nine; that test is renamed (`927d935`).
- **M3's clause 1 is `CONFIRMED` on a one-sentence record.** `#89` and `#163` to `#165` closed on
  2026-08-27 on the operator's confirmation that the drill was run and verified, and nothing records
  the run's date, its time or `verify_drill.dart`'s output. Asked on 2026-09-15, the operator does not
  remember the time, so the figure is not recoverable. The mark stands, because a person performed the
  drill and closed it, and the row says what was never written down rather than supplying it.
- **M4 had no clause table,** and its section opened by calling both clauses `DEMONSTRATED` when both
  were drills a person ran. They are `CONFIRMED`, as §5.3.7 and §5.3.30 had already recorded.
- **§0 had no way to write a park.** A park now reads `**NOT BUILT**, parked on M6 by DR-027` and keeps
  the clause's true mark, so a parked clause cannot read as discharged.
- **The gate's first run on the real board failed, on M1's goal line.** docs/12 said three times in
  prose that *"and it ships to real users"* is not an exit clause, and §1 counts M1's clauses as eight,
  while the table carried it as a ninth row marked `NOT BUILT`. The row now says it is not an exit
  clause, and the gate counts such rows and skips them. Board `#66` still describes itself as *"EXIT
  CLAUSE of M1"* and has a comment saying otherwise.
- **M2's keyboard row reads `DEMONSTRATED: at the channel, not with a screen reader`.** The gate accepts
  it by its leading word. Whether that qualifier is a note on scope or §0's *"demonstrated but"* is a
  judgement about the clause; it was put to the user on 2026-09-15 and the row is left as it reads.
- **`run_local.ps1` runs the glyph coverage gate and the pipeline never has.** Found while wiring this
  gate into both lists; filed as its own task rather than folded in.

##### 5.9.58.3 Evidence

- The gate's planted cases: every clause discharged passes; a note after a mark passes; `BELIEVED`
  unparked fails; parked on a later milestone by a real ruling passes; parked on itself fails; parked
  by a ruling canon lacks fails; a word that is not a mark fails; a closed milestone with no table
  fails; a marked goal line passes and an unmarked one fails; the current milestone owing clauses
  passes; a `CLOSED` status counts as closed.
- On the real board it also failed when a closed M5 row was made `BELIEVED`, when M3's park pointed
  at M2, and when M1's goal line lost its marker.
- 18 gates green on the rename and on the marks, and 19 on the gate commit, which is the new gate counting itself. Every suite exactly at its floor: core 4759, text 1, export 229, pdfium 22, ui 1932, app 1052, and the timed step 5. Analyzer pin unmoved at 233.

**Commits** (§8.8): `#92` `927d935` (the rename), `1a48354` (the marks); `#780` `1e75efc` (the
gate).

#### 5.9.59 `#782`: the extensions are `.rppj`, `.rpdx` and `.rpda`, and every spelling a build wrote still opens · `DR-179` · no version move

**DEMONSTRATED** by the suites at their floors with the renamed extensions throughout, by
`generate_starters.dart --check` reporting all four starters unchanged after `git mv`, and by
`save_paths_test.dart`, which now asserts both that `.rmpj` and `.rackmate` still open and that
`.rackpal` is not accepted at all.

##### 5.9.59.1 A deferral whose deadline arrived early

DR-096 §11.95.3 deferred matching the `rm` extensions to RackPal, with M8 as the trigger. Measuring
for the ruling found the trigger nearer than M8: MSIX-7 (`#171`, under the Store alpha `#100`)
registers the extensions in the package manifest, and a registered extension is the thing that makes
a rename expensive. DR-179 §11.178.2 ruled the letters and the timing; this is that change.

##### 5.9.59.2 What the rename found, all of it the product rename's work

- **The legacy project extension was a spelling nothing ever wrote.** DR-015 kept `.rackmate`
  opening; `0e2c5bb` rewrote that constant to `.rackpal`. A project saved before 2026-08-02 was
  therefore missing from the Open dialog's filter, and `Ctrl+S` on one would have written a second
  file beside it. The accepted list is now `.rppj`, `.rmpj`, `.rackmate`.
- **Two "no legacy sibling" claims had expired.** `save_paths.dart` and the native dialog both said a
  device template and a device archive needed no second spelling because no build had ever written
  one. Template export and the library shelf have shipped since, so `.rmdx` and `.rpdx`, and `.rmda`
  and `.rpda`, are accepted in pairs; `library_directory.dart` scans both, since the shelf it reads
  is full of files this app wrote.
- **Comments across the storage and session layer described `.rackpal` files**, in the recovery
  store, the snapshot store, the file picker and `pubspec.yaml`. They meant a project file, which is
  `.rppj` now, or a pre-DR-015 one, which is `.rackmate`.
- **The legacy tests were testing the wrong legacy.** `save_paths_test`, `recovery_store_test` and
  `snapshot_store_test` each proved an older spelling still opens by using `.rackpal`. They use
  `.rmpj` now, which is a spelling that really exists on disk.
- **THE RELEASE-OUTPUT GATE'S STARTER LIST HAD GONE STALE AT BOTH RENAMES, AND ONLY THE PR
  BUILD COULD SEE IT.** `tools/ci/verify_windows_build.ps1` names the four starter files, and
  it runs only when `flutter build windows --release` does, which `run_local.ps1 -SkipBuild`,
  the documented iteration path, skips. So five local runs passed and build 288 reported four
  missing starters that no longer exist, which is exactly what DR-015's rename did to the same
  list (board `#739`). The extension is one constant there now, the script records both
  occurrences, and the fix was proved by running a real release build and the check rather
  than by reading them.
- **A BLUNT COMMENT SWEEP IS A RENAME WITH NO READER.** Replacing every old spelling in the
  library comments also rewrote three deliberate references to the older one, and one of them
  was code: `kLibraryExtensions` lost `.rmda`, so a shelf written before today would have
  stopped being read. The other two were sentences about an older snapshot meeting a newer
  build, which the pass turned into a file meeting itself. They were found by reading every
  non-comment line the pass touched and every line where one spelling had come to appear
  twice; both checks belong to the next sweep as much as to this one.

##### 5.9.59.3 What did not change, and why

- **No byte inside any file.** `kSchemaVersion` does not move and CR-117 is not in play: the codecs
  write `kind: device-template` and `device-library`, never an extension, and the four starters are
  byte-identical after the rename.
- **The test fixtures keep their `.rmpj.json` names.** They are test data rather than files a user
  sees, and renaming eleven of them would touch every test that reads one.
- **Canon and docs/10 keep their historical prose.** They record what was true when written, and
  rewriting a ruling's own words is the failure canon §11.95.8 exists over. Only sentences telling a
  reader what the app writes today were changed.
- **File-type registration is still MSIX-7's**, as DR-179 §11.178 says in terms.

##### 5.9.59.4 Evidence

- 19 gates green on each of the three commits, every suite exactly at its floor, and the four starter goldens byte-identical after the rename: `generate_starters.dart --check` reports all four unchanged.

**Commits** (§8.8): `#782` `04c8eb95` (the app and the native dialog), `2aef2906` (the derived
documents), `05d60281` (these records), `9ce583ee` (the library comments).

#### 5.9.60 `#80`: a project states its wiring standard, and a cable may override it · `DR-180` · no version move

2026-09-16. The fourth and last of the four fields docs/08 §3 names and the model did not have.
`SignalFamilyDef.shortTag` closed at DR-010 §11.10.3, `Pathway.designator` and
`Outlet.nominalRunLength` at DR-026; this one is T568A or T568B. It closes under `#786` and moves no
number.

**DEMONSTRATED** by the suites at their floors, by `wiring_standard_test.dart`'s 36 cases, by the
`WIRING` column's three widget cases in `structure_editor_screen_test.dart`, and by the write path's
two in `structure_editor_route_test.dart`.

##### 5.9.60.1 One entry per job, not one per drop

`ProjectSettings.wiringStandard` holds the job's; `Link.wiringStandard` holds the run that really
differs. Three shapes were offered and refused (§11.179.2): a field per cable with no project value,
a field per END, and not modelling it. The middle one is the interesting refusal, because it could
express a cable wired A at the plate and B at the panel, which is a real defect; the ruling took the
cheaper entry and left that case to `CrossoverKind`'s territory.

**Both fields are nullable and neither defaults.** Unset is unknown, never an assumed `t568b` (G4,
CR-114), and both keys are ABSENT when unset rather than written as an explicit null. That is not
tidiness: an unconditional key would move the bytes of every `.rppj` already on disk the moment it
was opened and saved, which is the CR-117 property M0's exit criterion names. `kSchemaVersion` does
not move.

##### 5.9.60.2 The predicate reads the document, and the first draft did not

§11.179.3 gives two qualifiers: the media is a four-pair twisted-pair type, OR one of the cable's
ends is an RJ45 port or plug. A first draft of `wiring_standard.dart` took only the `Link`, so it
could see the media and the two `StructureOrigin` terminations and nothing else. A port's connector
is a template join, so that draft answers FALSE, silently, for a run on a shop's own media entry
landing on two patch-panel jacks: a cable any installer would expect a standard on. It looked
cheaper and was a narrower rule wearing the ruling's words. `wiringStandardApplies` takes the
`RackDocument`.

**A `punchdown` does not qualify a cable and does qualify an END**, which is the one place this file
holds the same value in two sets on purpose. `kRj45Terminations` answers "is this four-pair data at
all", where a punchdown proves nothing because a 66 block carries voice. `kPairOrderTerminations`
answers "does the standard describe what happens at this end" of a cable already known to be data,
where a punchdown is a 110 block or a patch panel and pair order is exactly what lands. Without the
second set, a four-pair run with a euroblock recorded at one end would print `EUROBLOCK T568B`.

##### 5.9.60.3 Two surfaces, and one of them is a control decision

- **The settings row makes unset an ITEM**, not a blank. Settled by the user from three offers. A
  T568A/T568B pair with a `Clear` beside it reads truest and is a control shape nothing else in that
  dialog uses; a two-item dropdown that starts blank is a ONE-WAY DOOR, since picking a standard
  would leave no way back to unset short of editing the file. "Not stated" can be chosen, chosen
  again, and read off the closed dropdown.
- **The `WIRING` column shows the OVERRIDE and never the resolved value.** Showing the effective
  standard reads better and puts a trap in every row: the control writes what it shows, so picking
  the value already on screen would pin that cable to a standard the project might later be changed
  away from, with nothing to say it had happened. Three states instead: a standard, the dash meaning
  "follows the job", and `— NO RJ45 —` meaning a standard is not a fact about this cable.
- **AND THAT THIRD STATE IS `#711` WAITING TO HAPPEN AGAIN.** The column is editable per COLUMN and
  §11.179.3 is per ROW, so a coax run gets read-only text where a Cat6 run gets a dropdown. `#711`
  shipped an enabled `RACK TERM` dropdown whose every pick the write path refused, on every line;
  the same shape here would have been the same defect. `structureCellChoices` returns no menu for
  such a row, and the app's arm refuses one by designator if anything reaches it anyway.

##### 5.9.60.4 What the printed cell says

The `TERM` cell is the termination type, then the punch position where there is one, then the
standard: `PUNCHDOWN A03 T568B`. The standard goes LAST, behind the position, because `PUNCHDOWN A03`
is one thing an installer reads at the panel and splitting it would serve a literal reading of
"beside the termination type" rather than the person holding the sheet. A test pins both ends of the
cell so a later tidy argues with a case rather than with a habit.

`schedule.dart`'s header has said since 2026-07-28 that a `Link.wiringStandard` was owed. That bullet
now records a gap that CLOSED, and it keeps the half that did not: `Conductor.colorCode` is still
printed exactly as stored and still never re-read to decide it means a standard. docs/02's worked
example, which stored `"colorCode": "T568B"` on a conductor, says `"blue/white"` now: that edit is
named in §11.179's own "what this does not rule" as owed with the build.

##### 5.9.60.5 What is NOT built, and is not hidden

- **`T5.01` stays M6's**, as §11.179.4 says in terms. What exists is its trigger:
  `wiringStandardExceptions(doc)` is the list the sheet will be about, and docs/08 §3's row now
  states the condition against the project rather than against an assumed default.
- **THERE IS NO CABLE INSPECTOR IN THE PRODUCT.** Asked where a cable's override should be typed,
  the user chose an optional column AND an inspector row. The column is built. The row has no host:
  the schematic canvas selects a cable for `Del` and nothing else, and `InspectorPanel` is devices
  and racks. Building one is a new surface rather than a row, and it is reported rather than
  invented.
- **DR-055's `FIELD TERM` / `RACK TERM` split is still unbuilt**, which was true before this and is
  unrelated to it. The standard prints in the `TERM` column that exists.

##### 5.9.60.6 Evidence

- 19 gates green on each commit, every suite exactly at its floor. Floors re-measured twice: core
  4759 → 4791 → 4799, ui 1932 → 1935 → 1938, app 1052 → 1054.
- The file shape is gated in the same file as the rule: an unset project writes no `wiringStandard`
  key anywhere in the document, and a set one survives write, read and write again byte-identically.

**Commits** (§8.8): `#80` `1445d547` (the model, the file, the commands and the settings row),
`5ae8180f` (the printed cell and the `WIRING` column), `6b3ef339` (the derived documents and
these records).

#### 5.9.61 `#82`: a signal family may override its domain's glyph · `DR-181` · no version move

2026-09-16. It closes under `#786` and moves no number.

**DEMONSTRATED** by the suites at their floors, by `registry_parity.py` comparing the glyph column
and failing a planted mutation with exit 1, by `glyph_coverage_check.py` reporting 17 path-backed
codepoints where it reported 15, and by the four starters gaining exactly 26 keys each and nothing
else.

##### 5.9.61.1 The ticket said two families; it was twenty-six

`#82` was filed over `audio.speaker_cv` and `power.bonding`, the two whose shape had nowhere to go
at all: `audio.analog` and `pwr` carry THREE glyphs each against `SignalDomainDef`'s two slots.
Measuring §4.3 against §4.4 found a wider fault with the same root. `signal_style.dart` drew only the
domain's NATIVE glyph, so every family whose §4.4 glyph is another of its own domain's shapes was
drawn with the native one: 2 in digital video, 4 in analog video, 2 in analog audio, 4 in digital
audio, 4 in network, 7 in control, 2 in power, 1 in structure. Twenty-six of fifty-seven, in all
eight domains.

**THE NUMBER WAS ALREADY BEING REPORTED AND NOBODY HAD READ IT.**
`SchematicScene.underGlyphedFamilyIds` has counted every family whose shape the renderer could not
verify since M2, which is a superset of the 26. A count nothing reads is a count nobody has, which is
the half of G4 that is about attention rather than about data.

##### 5.9.61.2 The answer was never a selector

`signal_style.dart`'s header has carried the argument since M2 and it is worth keeping: there is no
`tier` field, and all three candidate proxies contradict docs/05 §6.4's own table. A weight override
would make `video.hdmi.1_4` hollow where §6.4 prints ▲ for all three generations; a dash override
would make `audio.spdif_coax` hollow where §6.4 prints the filled ◆; an id-namespace rule is true of
`video.analog` and says nothing about the other seven. §4.4 gives every family a glyph OUTRIGHT, so
DR-181 made it an authored fact. A fourth heuristic would have failed against the same table.

`glyphIsUnderdetermined` is emptied of its seeded cases rather than retired: a family that states its
shape is not a guess, and one in a multi-glyph domain that states none still inherits the native
shape and is still unverifiable, which is what a registry entry a user adds later can be.

##### 5.9.61.3 `◐` had been drawing as `○`, and that mattered only from today

`family_glyph.dart` mapped U+25D0 CIRCLE WITH LEFT HALF BLACK to the HOLLOW CIRCLE, with a comment
saying so and calling it *"the closest honest reading of not the native tier"*. That was true and
harmless for exactly as long as nothing drew `○`. `audio.speaker_cv` draws `○` now, so seeding the
26 without touching the geometry would have made a constant-voltage speaker run and a low-impedance
one **the same picture** on every sheet. Those two are the pair on a job that must never be confused,
which is the whole reason a glyph channel exists. A near-enough mapping is how a channel goes quiet
with nothing reporting it.

So the fill became three-valued, `◐` is a real half-disc, `○` is the hollow circle, and `⏚` is a new
shape: a stem and three bars, because the trade draws an earth symbol for a bond and no hexagon
variant says that.

##### 5.9.61.4 The half tier is filled and NOT stroked, and that is a constraint

`net_label_layer_test`'s `_isGlyphPath` tells a glyph from a pennant by one property: a pennant is
the only path carrying BOTH a fill and a stroke. A half-disc outlined for crispness reads as a
pennant to three scene tests, which would then count the wrong paths and still pass.
`family_glyph_test` sweeps all three tiers for that property now rather than the two it knew about.

##### 5.9.61.5 Evidence

- The seed's 26 were generated from §4.4 rather than transcribed, under post-conditions that the
  insertions are the ONLY change: taking the inserted lines back out must give the original file
  byte for byte. The first draft of that check was wrong in the safe direction (it popped stale
  indices) and cost a run, which is the direction a post-condition should fail in.
- `registry_parity.py` re-derives the same 26 from the markdown independently and compares them
  through `effectiveGlyph`'s own fallback, so it checks the inheritance rule as well as the values.
- 19 gates green on each commit. Core floor re-measured 4799 → 4801; two tests were rewritten in
  place and move no number, both of which recorded the gap this ruling closed.

##### 5.9.61.6 What did not change

- **`kSchemaVersion` does not move.** The key is absent when unset, so a document written before this
  re-encodes byte for byte (CR-117). The starters changed because a document embeds its own
  registries, which is the ruling's own "what this does not rule": a project saved earlier keeps
  drawing its domain's shape and keeps reporting what it cannot verify.
- **The glyph is still not a per-family discriminator.** docs/05's sentence about there being no set
  of 50 shapes legible at 6 pt stands, and is what limits this: a domain has two or three shapes and
  the family says which one it takes.
- **The logical-flow direction is still owed a field**, and `topologyFree` is still absent from the
  Dart class. Both are named in §11.180.1 and neither is in this.

**Commits** (§8.8): `#82` `adbd07af` (the field, the seed's 26, the geometry and the gate),
`3f7bc1c7` (the derived documents and these records).

#### 5.9.62 `#796`: the roadmap keeps its sizes and retires its week total · `DR-182` · no version move

2026-09-16, with `#799`. It closes under `#786` and moves no number.

**DEMONSTRATED** by roadmap §6 carrying a size for all 20 v1 epics against the board read on
2026-09-16, and by the 19 gates, which is not nothing for a docs-only change: the corpus is under
test and a docs commit has failed this gate set before.

##### 5.9.62.1 Wrong by four to six times, and drifting between three documents

§6 priced M0 through M5 at **29 to 44 weeks cumulative**. They are closed and took **about 7.3
weeks**, 2026-07-18 to M5's close on 2026-09-07. The three offers that kept a number in some form
were refused on that: a full re-cost in weeks, a caveat on 44 to 67, and leaving it alone.

**The total had already drifted between the three places that stated it.** DR-029 added the Plan view
and moved canon §12.7's totals to **53 to 80**; §6 never gained the row and went on saying **44 to
67**; roadmap's own header said **42 to 65** for longer still. Three numbers, one cost, none of them
measured, and this repository's standing rule about a second copy of a moving number had never been
pointed at the cost. A relative ordering cannot drift that way because it has nothing to add up.

##### 5.9.62.2 The durations that are not offered, and why that is a measurement

DR-182 asks a closed milestone to show its actual duration. Five of six do not have a separable one,
and saying so is the honest answer rather than the missing half of the job:

- **These milestones did not run end to end.** M0's last two exit clauses were `VACUOUS` until M4's
  work expired their reasons, so its criterion was met on 2026-08-27, long after its code shipped.
  M3's clause 1 was confirmed by a drill on the same day. M1's two human clauses were discharged on
  2026-07-27 and 2026-07-28, inside the first fortnight.
- **THE BOARD'S OWN `ClosedDate` CANNOT SUPPLY THEM EITHER, AND IT LOOKS LIKE IT CAN.** M0, M1 and
  M3 all carry **2026-08-28**, which is the day every work item migrated from Issue/Task to
  Story/Chapter (§1). That is a migration artefact wearing a date. Reading six durations off that
  column would have produced three confident wrong numbers in a section whose whole point is that a
  confident wrong number is worse than none. M2 (2026-08-01), M4 (2026-09-02) and M5 (2026-09-07)
  agree with their evidence here and are used.

The clean figure is the span, and it is the one that matters. The Plan view is the second data point
and agrees: `L`, opened the day M5 closed, **13 of its 14 stories closed in nine days**.

##### 5.9.62.3 Every v1 epic sized, and what the sizes are not

Twenty epics, each with a size. The Plan view had one in §4 and no row in §6; nine had none anywhere.
Each is argued from its stories, and **the two that are not decomposed say so**: EXP-A and DOC-A are
sized from their rulings' descriptions, which is weaker evidence than stories and should not be able
to hide behind the same letter.

**THE LETTERS ARE NOT A FUNCTION OF ANY COUNT.** M1 is `L` with 9 stories, M5 is `M` with 20. The
counts are printed beside the letters so a reader sees that rather than trusting it, and so a future
re-size argues with evidence. **M6 is left at `M` with 33 stories**, more than either: DR-182
authorises sizing the epics that have none and refuses a re-cost, so the tension goes on the row
rather than into an unruled change.

##### 5.9.62.4 What else the change had to touch

- **`#799`**: §4's M4 heading read `M` against §6's `L`, and had since DR-015. The document sized one
  milestone two ways for a month.
- §4's "how to read it" line carried the week range per letter (`S` ≈ 2–3, and so on) and follows the
  withdrawal; docs/00's cost paragraph follows it too; canon §12.7 gains a note that its week columns
  are withdrawn and keeps the table as the record of what four rulings did to an estimate.
- The two levers are re-read against no total. **Lever 1 was deferred rather than pulled**: M1 closed
  with its goal line *"and it ships to real users"* unmet, and that clause is a story under M8 now.
  **Lever 2 was taken, by the mechanism it named**: AC-052's provenance gate set the catalogue nearer
  40 than 80, which is what its own Cost column predicted.
- One count fixed in passing because it sits inside the paragraph lever 2 is about: docs/09 said "the
  50 seeded templates" against a catalogue of 51, and now names the test that holds the number.

**Commits** (§8.8): `#796` `1f0c5bb1` (roadmap §6, §4's heading and scale, docs/00, the canon §12.7
note), `1a00b064` (these records). `#797`, `#798` and `#799` close with it.

#### 5.9.63 `#91`: the competitive table, re-read against the vendors' own pages · `DR-036`, `DR-011` · no version move

2026-09-16, research gathered 2026-09-15. **No new ruling**: it cites DR-036 (nothing is priced) and
DR-011 §11.11.5. It closes under `#786` and moves no number.

**DEMONSTRATED** by every price in docs/00 §7 carrying the date it was read off the vendor's own
pricing page, and by the two figures the corpus had wrong being corrected in the direction the
evidence says rather than the direction that flatters.

##### 5.9.63.1 A pricing strategy for a product with no price

§7's Price row read *"anchored to Stardraw and free AVSnap, not to D-Tools"*. **DR-036 rules that
nothing is priced**: the application is free and GPLv3. The row says so now and keeps the
competitors' figures, because what a shop pays today is still how a reader parses the rest of the
table.

**AND THE ANCHOR WAS WRONG IN THE FLATTERING DIRECTION.** docs/00 said Stardraw is *"$275–$1,050 yr
1"* in two places. **Those are the renewal prices.** Year one is $550 for Entry and $2,100 for
Professional. The anchor sat at half the real entry cost, which is the error that makes a competitor
look cheaper than it is and a gap look smaller than it is. A wrong number that favours the argument
is worth more attention than a wrong number that does not.

##### 5.9.63.2 What the research found, including what it refused to use

- **D-Tools Cloud**: $99/mo Single to $1,199/mo Enterprise, $89–$1,079 paid annually, **plus setup
  fees of $250 to $2,500** that no summary of this product mentions.
- **XTEN-AV X-DRAW**: $139–$169 per user per month by tier, 25% off annually. **The X-PRO add-on is
  $22.50/mo, double the $11.25** an earlier research note recorded.
- **D-Tools SI's $1,800/user/yr with a five-user minimum is confirmed**, as is AVSnap being free.
- **A SEARCH-ENGINE SUMMARY OF D-TOOLS CLOUD'S TIERS IS NOT USED.** It gave $99/$249/$499/$999
  against a vendor page saying $99/$179/$349/$649/$1,199. The scratchpad note records both so the
  disagreement is visible rather than silently resolved in favour of whichever was read last.
- **A claimed Canny feature request for D-Tools Cloud rack elevations is not cited**: the page
  returns "Company Not Found", so the claim is unverifiable and stays out.
- **RackOnline is confirmed defunct rather than assumed so**: `rackonline.dk` returns NXDOMAIN and
  refuses a connection. Its column stays with every cell `Unknown`, because deleting it would
  quietly improve the field.

##### 5.9.63.3 The complaint that expired, kept with its date

docs/00 §1 cites a verbatim user review of XTEN-AV: *"there is no way to assign unique device names
to devices"*. **X-DRAW's knowledge base now documents how to STOP it appending a number suffix to
identical product names**, and carries articles on assigning, resetting and category-scoping cable
IDs. The complaint was real when written and the product has moved.

It is marked dated rather than deleted. An expired citation is evidence about how fast this market
moves, and a table that silently drops the competitor findings that stop being true is a table that
only ever agrees with itself.

##### 5.9.63.4 Two cells promised an escape a ruling had removed

Found while re-reading, fixed in the same pass. §7's typed-ports cell and §3's `R3` row both said an
illegal connection springs back *"with a reason chip and `[ Connect anyway ]`"*. **DR-011 §11.11.5
refuses a model-illegal drop OUTRIGHT** and says in its own heading that there is no
`[ Connect anyway ]`; the escape belongs to the tier-2 advisories CR-017 describes, which are M5's.
Two cells contradicted the ruling that narrowed them, in the document a reader meets first.

##### 5.9.63.5 Evidence

- 19 gates green. Every `Unknown` in the two new columns is a cell nobody checked, which is not the
  same as "no": the research verified prices and two features, and filling the rest from a product
  page would be the fabrication a competitive table is supposed to be evidence against.
- `docs/research/research-prior-art.md` is **not edited**: `research/README.md` records it as an
  unedited output, and a re-verification belongs beside the claim it corrects rather than inside the
  artifact it corrects.

**Commits** (§8.8): `#91` `4547ad41` (docs/00 §1, §3, §5 and §7).

#### 5.9.64 `#910`: the plan mark sticks at a floor and grows with the plan · `DR-183` · no version move

2026-09-17, reported by the user with a screenshot: *"we need to increase the site view pin size a
bit; I feel like it should 'stick' at a certain size below a certain zoom level ... zooming out it
stays physically this size, zooming in it should grow relatively in size to the room plan underlay."*
**New ruling, DR-183 §11.182**, because it changes what §11.168.2 decided rather than adding a clause
beside it, which is what `#904` and `#905` did. Listed at §12.36. It closes under `#786` and moves no
number.

**DEMONSTRATED** by six cases in `plan_canvas_screen_test.dart`, four of them properties of the rule
and two driving the widget, and by three mutations run against them.

##### 5.9.64.1 Measured first, and the screenshot was not

`plan_canvas_screen.dart` computed `kPlanMarkerRadiusPt / viewport.scale`. That is a **7-point radius
on screen at every zoom in the range, 5% to 3200%**, by construction rather than by measurement, and
it is `#897`'s rule working exactly as ruled.

**THE SCREENSHOT YIELDS NO NUMBER AND THAT IS RECORDED RATHER THAN WORKED AROUND.** It is a crop at an
unknown zoom of a plan whose pixel dimensions are unknown, so nothing in it converts into points. A
figure read off it would have been this repository's own *"a guess wearing a measurement's clothes"*,
and the temptation was real: the request arrived WITH an example, which is usually the thing that
makes a measurement possible. The two numbers came from the user instead, chosen against **four discs
drawn at actual size** and a chart of size against zoom. That method is §11.168.11's, where the user
picked a line weight from three drawn side by side at the same enlargement.

##### 5.9.64.2 The rule is one `max`, and the crossover is a consequence

`max(kPlanMarkerMinRadiusPt / scale, kPlanMarkerPlanFraction * sqrt(w * h))`, in scene units. The
first term is constant on the SCREEN, the second constant on the PLAN, and the larger wins. A third
number for the threshold would be a number to keep in step with the other two.

| | Below the crossover | Above it |
|---|---|---|
| What is fixed | the points on screen | the piece of floor covered |
| Why | a mark is aimed at with a pointer, which `kOutlineCloseRadiusPt` says for the close test in its own words | *"relative in size to the room plan underlay"*, which is the request |
| Which rule | §11.168.2's, kept | the one §11.168.2 retired, returning bounded |

**The floor rose from 7 to 11 points**, chosen by the user from 9, 11 and 14 drawn at actual size.
**No reason is attributed to them**, because none was given and §11.168's closing clause does not ask
for one. What IS recorded is the two measurable consequences: the domain glyph fills a box of
`kPlanGlyphSideFactor` radii and grows from **8.05 points across to 12.65**, and a device's ring,
being a constant 2 logical pixels, **falls from 28.6% of the radius to 18.2%**. The second was
checked rather than assumed, because §11.168.11 sets a ceiling near 37% to keep a ring out of the
corners of Network's square glyph and a bigger mark is exactly the shape of change that could have
crowded it. It moves the other way: the ring does not grow with the mark.

**1/100 WAS OFFERED AND DECLINED, AND THE OPTION SAID WHY BEFORE IT WAS DECLINED.** It is within
rounding of the retired `kPlanMarkerRadiusFraction`'s 1/110, so a mark would reach four times the
floor at four times the fitted zoom, which is the size the original complaint was about. Offering it
without that sentence attached would have been an option the user could not price.

##### 5.9.64.3 The anchor is the geometric mean, on a measurement already in the record

The obvious anchor is the underlay's longer side, because that is what the retired constant used.
**§11.168.10 had already measured it going wrong**, on paper, with a fraction of exactly this shape:
6.87 points on a 2000x1500 plan, 5.15 on 1500x2000 and 10.20 on a 4000x1000 panorama, from one
fraction, because a fit binds on the tighter axis while the fraction reads the longer one. A corridor
scanned in one strip is a real plan.

So `sqrt(w * h)`, which has no cliff and agrees with the longer side on a square scan. This is the
one clause in DR-183 the user did not choose, and it is recorded as an implementation clause: the
option they answered said *"1/200 of the plan"*, and the geometric mean reads 2901 on a 3300x2550
scan against a longer side of 3300, so it moves the crossover **1.14x further in**.

**AND THE CROSSOVER AGAINST THE FITTED ZOOM IS A RANGE, WHICH THE FIRST DRAFT OF THIS SECTION WROTE
AS A NUMBER.** It said *"about 2.7x fit"*. The fit depends on the window, so the honest figure is
**2.3x fit in a 1920-point canvas and 3.4x in an 1100-point one** on this scan, over
`fitToContent`'s own 0.9 margin. The option the user answered carried "about 2x fit" as its own
rough gloss, and that gloss is the same kind of estimate: it orients, and it is not a constant.

##### 5.9.64.4 The consumer that was not a scene

`PlanPinBubble` takes the mark's radius **in screen points** so the hover label clears it, and it was
handed the constant. That was correct while the constant WAS the screen radius, and silently wrong
the moment it stopped being: at 16x on the test fixture the label would have lifted by 37 points off
a mark measuring 39, sitting inside the dot it names, worse the further in somebody zoomed. **No case
in the file read its position**, which is how it would have shipped. The screen radius is now its own
getter beside the scene one.

##### 5.9.64.5 Evidence

- **Six new cases**, and four of them assert a PROPERTY rather than the expression: the mark never
  goes under the floor across a 200-step sweep of the whole zoom range, it grows in step with the
  zoom once it has left the floor, it never steps (non-decreasing, and never outrunning the zoom, two
  bounds that between them forbid a jump in either direction), and it does not care which way up the
  scan is. Retyping `max(floor / scale, fraction * sqrt(w * h))` into a case would have proved that
  Dart's `max` works.
- **Two drive the widget**, both reading the render object's own scene for `#903`'s reason: the drawn
  mark doubles between 8x and 16x while a click twenty points off centre goes from missing to
  hitting, and the hover label clears the grown mark.
- **THREE MUTATIONS, RUN.** Replacing the `max` with the floor term alone reddened two cases;
  swapping `sqrt(w * h)` for the longer side reddened the aspect case and one of the older ones.
  **The aspect case passed the first mutation vacuously**, because two marks both sitting on the
  floor agree for a reason that has nothing to do with the anchor, so it gained a guard asserting the
  anchored term is the one in play. That is the mutation run earning its keep rather than confirming
  a green.
- **The older group is renamed and two of its titles are corrected.** `AND IT NO LONGER DEPENDS ON
  HOW BIG THE PLAN IS` outlived its rule by one ruling and now reads `AND BELOW THE CROSSOVER IT DOES
  NOT DEPEND ...`; `THE MARK IS THE SAME SIZE ON SCREEN AFTER A ZOOM` gained `THAT STAYS UNDER THE
  CROSSOVER`. Both still pass unchanged, because the 600x400 fixture's crossover sits near 4.5x and
  every case in that group runs below it. **A title that overclaims is how a suite ends up asserting
  a defect**, which this repository has found more than once.
- **Test floor**: `rackpal_ui` 1938 to 1944, measured after the change.

**Commits** (§8.8): to follow in this section when they land.



#### 5.9.65 `#911`: a floorplan turns in quarter turns, and a lifted page had been ignoring its `/Rotate` · `DR-184` · `v0.6.58`

2026-09-18, from the user: *"the floorplan view, for example, doesn't allow the rotation of
floorplans."* **New ruling, DR-184 §11.183.** A leaf Story under `#588`, so it moves the number.

**DEMONSTRATED** by cases at four layers, each driven the way the surface is used rather than by
reading the map back: the scene replayed through a `BoundsCanvas`, the sheet's callout against its
own mark, the editor by button, key and drop, and the page picker's tile.

##### 5.9.65.1 The report was the smaller half

The request was a missing control. Measuring it found a defect nobody had reported: `_inherited`
in `pdf_page_lift.dart` carried `/Rotate` down the page tree beside `/MediaBox` and `/Resources`,
and nothing read it. `LiftedPdfPage` had no field that could hold a turn and the picker previewed the
lifted bytes as they stand, while pdfium applies `/Rotate` before it renders. So a scanner's landscape
sheet, which is a portrait page with `/Rotate 90`, came in **sideways by the preferred path and upright
by the fallback**. The field the user asked for is also the lossless fix: the bytes stay the embedded
bytes (DR-138 §11.137.3) and the turn rides beside them.

##### 5.9.65.2 One map, where there had been a dozen spellings of the identity

`plan_scene.dart`'s rule that one image pixel is one scene unit had been written out by hand at about
a dozen sites, as `DPt(p.px.toDouble(), p.py.toDouble())` one way and `PxPt(s.x.round(), s.y.round())`
the other: the scene, the sheet's callouts, and every overlay and gesture on the canvas. Harmless
while there was nothing to agree on. `PlanTurn` is now the only crossing, the identity is its zero
case, and the three overlays take it as a **required** argument on `#904`'s lesson that a defaulted
identity is a retired rule nobody notices.

**AN UNTURNED PLAN EMITS THE DISPLAY LIST IT ALWAYS DID.** The transform bracket appears only when
there is a turn, so no existing op count, digest or exported byte moves, and the matrix is built from
literal entries because `Matrix4.rotationZ(pi / 2)` carries `6.1e-17` where a zero belongs.

##### 5.9.65.3 The host the first question offered did not exist

The user chose buttons *"in the Plan editor's toolbar"* from a menu I wrote. There is no toolbar, and
docs/15 §6 rules there is no fourth region. Found by reading `plan_editor_screen.dart` before writing
the buttons, and the host went back to the user as its own question; the rail row won on DR-144
§11.143.4's precedent. Recorded in canon because a wrong option gets chosen where a wrong claim gets
corrected, which is the second time this repository has paid for that.

##### 5.9.65.4 Evidence

- **Five mutations, five kills.** Pins back on the identity (4 scene cases), the lifter ignoring
  `/Rotate` (3 lift cases), the sheet's callouts on the raw pixel (1), the canvas storing the scene
  point as the pixel (the drop case alone), and the turn not holding the centre (the centre case
  alone). Each of the last two reddens exactly the case written for it.
- **The centre case pans first**, so the canvas centre is not the picture's centre. Without that, a
  view that re-fitted on every turn would also leave the middle of the picture in the middle and the
  case would pass for the option the user declined.
- The keymap grows by two rows in the plan scope, 4 to 6 and 74 to 76, and arbitration is clean.
- **Floors**: `rackpal_core` 4801 to 4835, `rackpal_ui` 1944 to 1950, measured. **Gates**: the full
  local run was 17 of 19, and both reds were this change's own: the new files unstaged, which is the
  tracked-sources gate doing its job, and four analyzer infos, three missing `const`s and one import
  made redundant by another. Both fixed and those two gates re-run alone; the analyzer is back on its
  pin at 233.

**Commits** (§8.8): the ruling `6cbebff1`, the implementation `a3375336`. These records and the
version follow in their own commits.

#### 5.9.66 `#912`: a floorplan page says its name and the place it shows, and a plan is the tenth location carrier · `DR-185` · `v0.6.59`

2026-09-18, found while measuring `#911`. **New ruling, DR-185 §11.184**, and **amends DR-021's census
at §12.37**. A leaf Story under `#588`, so it moves the number.

**DEMONSTRATED** by the editor driven by its own pencil button, the import driven through
`FloorplanIo.import` with a two-page PDF assembled by hand, and the location cascade run against a
fixture holding one of every carrier.

##### 5.9.66.1 Two modelled fields, no writer

`PlanUnderlay.name` was the file's for the life of the project, and `PlanUnderlay.locationId` was
accepted by every import signature and passed by no caller. The consequences were three, and only the
first was visible: three pages of one PDF were three rail rows reading the same words; the rail's
room line (`_UnderlayRow.room`) could never print; and DR-142 §11.141 rules that a plan with no
location lists **every** unpinned carrier, so each floor of a multi-storey job listed the whole
building. The fourth consequence waited for the fix: a device dropped from the palette onto a plan
takes the plan's location, and every plan had none.

##### 5.9.66.2 The writer made a cascade matter

`planLocationRemoval` censused nine fields across seven entities (DR-021 §11.20), and the plan's
`locationId` was not one, because no document could hold one set. **Giving it a writer made the omission
live**: deleting a floor would have left its plans pointing at nothing. It is the tenth carrier now,
cleared and restored on the other nine's terms, and the census test that asserts every
`LocationRefKind` is found went red on the first run, which is the test doing its job: its fixture
needed a plan that shows the room. The delete dialog's reassurance sentence names floorplans among what
survives.

##### 5.9.66.3 Evidence

- **Core +6**: the command's four answers (both fields in one entry, a site plan, a no-op leaves no
  entry, a blank name and an unknown place refused) and the cascade.
- **ui +4**: the pencil on the open row only, a new name and floor landing together with the room line
  printing and one undo taking both back, `Cancel`, and a blank name that cannot be saved.
- **app +6**: a dismissed dialog keeps the proposal and still imports; the answer is stored and the
  import is one undo entry; a page of a two-page PDF is named with its page and a one-page PDF is not;
  a proposed place the document does not hold proposes none; a refused file never asks.
- **One mutation, one kill**: an import that asked and ignored the answer reddens exactly the case
  written for it.
- **Floors**: `rackpal_core` 4835 to 4841, `rackpal_ui` 1950 to 1954, `rackpal_app` 1054 to 1060,
  measured.

**Commits** (§8.8): the ruling `0b43d4d4`, the implementation `64fc85b8`, the amendment to DR-021's
census `201c9ed5`. These records and the version follow in their own commits.

#### 5.9.67 `#913`: `Ctrl+L` locks a rack device and pins a schematic symbol, five milestones after the keymap promised it · `DR-186` · no version move

2026-09-18. **New ruling, DR-186 §11.185.** It closes under `#786`, the cross-cutting debt epic, which
is not the epic under development, so it moves no number (§5.9.29's precedent).

**DEMONSTRATED** by six cases through the real rack canvas (the key, the drag, the nudge, the badge,
the inspector checkbox, one undo), four through the real schematic canvas, two on the shrink dialog
and eighteen in core.

##### 5.9.67.1 Two fields, one reader between them

`Placement.locked` (CR-034) has been in the format since M0 with **no writer but the decoder and one
reader, compaction**. docs/12 §3.3 has said so since M1 and it stayed true through M5. So a drag, a
nudge, the width command and a bottom-trimmed shrink all moved a device somebody had locked, except
that nobody could lock one. `SheetItem.pinned` (CR-068) is the same shape one canvas over: the layout
READS it (`schematic_scene.dart`'s `_pinnedPositions`) and nothing wrote one, and **no document held
the schematic `Sheet` a pin lives on**, though CR-073 says exactly one exists per project. The first
pin creates it.

##### 5.9.67.2 What a lock refuses, and what it does not

Moving: the drag (refused at the 4-pixel threshold, so a locked device never becomes a drag source),
the nudge, the width position, and compaction, which already honoured it. **A bottom-trimmed shrink**,
because rule 5 shifts every surviving rail occupant down, so one lock anywhere in the rack refuses
that direction and the dialog names it; a top trim moves nobody and stays offered, which keeps every
option in that dialog lossless. **Not a delete**, ruled rather than left open: a lock that has to be
undone before a delete is a lock people leave off.

##### 5.9.67.3 A pin freezes the sheet, which is what it is for

The schematic's `Ctrl+L` stores the position the layout just produced, so pinning moves nothing and
the symbol stays where it is when devices are added. `schematic_scene_test.dart` asserts exactly that,
with the control that the same symbol unpinned DOES move under the same edit.

**AND THE `sheet` EPOCH NOW HOLDS THE LAYOUT, FOR A REASON THAT HAD TO BE MEASURED BEFORE IT WAS
TRUE.** It was wired to the structure handler, which re-lays the sheet out from scratch. The ruling's
own commit message and the first draft of this section both said that a pin would therefore have
shifted the pinned symbol's NEIGHBOURS. **Probed on `schematic_scene_test.dart`'s fixture, it does
not**: pinning a symbol at the position it already has moves nothing at all, because a fixed node is
handed the answer the layout was going to give it. That property is a test now.

What the same probe found is why the hold stays: pinning that symbol **24 by 8 grid units away moves
all five of the others**, since a fixed node stops relaxing and the rest re-flows around it. No
gesture writes a pin anywhere but where the symbol stands yet. **The one that will is dragging a
symbol**, which is the soft-glue task, and a relayout on this epoch is exactly what would make that
drag shuffle the sheet. Holding also stops the schematic re-laying itself out for a floorplan
rotation or rename, which bump the same epoch and have nothing to do with that canvas.

##### 5.9.67.4 Evidence

- **Three mutations, three kills**: the move guard, the width planner's refusal, and the drag
  refusal, each reddening the case written for it.
- **The width fixture carried `locked: true`** and had since it was written, because the field was
  free while nothing read it. Every plan in that file refused on the first run. It is unlocked now,
  the field-survival case says why `locked` is no longer on its list, and the lock has two cases of
  its own.
- **THE PLC-002 GATE CALLED A COPY A WRITE, AND IT WAS RIGHT TO.**
  `placement_rules_test.dart` reads `lib/` for the one file that SETS a lateral position rather than
  copying one, and it tells a copy by the field being read back on the right of the colon.
  `RailPlacement.withLocked` wrote `startTwelfth: startTwelfth`, which is a copy that does not look
  like one, and the gate went red. **The fix went in the code and not in the gate**: the real writer
  in `device_width_commands.dart` uses that same bare spelling for a PARAMETER carrying a new value,
  so widening the rule to forgive it would have blinded the gate to the one thing it watches. The
  copy reads off a local now, which is that file's own `_rebuild(base, ...)` shape. `this.` was tried
  first and costs two `unnecessary_this` infos.
- **AND A TEST REACHED PAST `@internal`.** The shrink dialog case set `DeviceInstance.placement` from
  `rackpal_ui`, which AC-013's access control exists to stop; the analyzer gate reported it as a
  warning, and warnings are gated at zero rather than ratcheted. The fixture builds the device locked
  instead, which is what the product does.
- **A CLAIM WAS WITHDRAWN AFTER IT WAS COMMITTED.** `2bbe532a`'s message says a pin would have moved
  its neighbours without the hold. The probe above says it would not, for the gesture that exists
  today; the numbers are in §5.9.67.3 and the corrected reason is in the code. The commit stands as
  written, because a message is a record of what was believed when it was written, and this is where
  the correction lives.
- **WHAT IS NOT ASSERTED, SAID OUT LOUD**: the padlock's and the pin's PIXELS. The cases assert the
  flag that draws them and every locked case paints a frame, so a badge that threw would fail; a badge
  drawn at the wrong size, or at a size that rides the zoom, would not. Both divide by the canvas
  scale the way `#906` requires, and neither has a case that would notice if that stopped.
- **Floors**: `rackpal_core` 4841 to 4863, `rackpal_ui` 1954 to 1966, measured.

**Commits** (§8.8): the ruling `4e944d20`, the implementation `2bbe532a`. These records follow.

#### 5.9.68 `#914` DR-187, the schematic holds its layout

##### 5.9.68.1 Three measurements, and the third changed the plan

Probed on `schematic_scene_test.dart`'s fixture before anything was built:

| Probe | Result |
|---|---|
| Add two devices to a laid-out sheet | **The symbols already on it move.** The report, reproduced. |
| Pin a symbol where it already stands | **Nothing moves.** A fixed node is handed the answer the layout was going to give it. |
| Pin it 24 by 8 grid units away | **All five neighbours move**, because a fixed node stops relaxing. |
| Fix every existing symbol, then add a device | **The newcomer lands exactly on top of one of them.** |

The fourth line is why §11.186.5 is a clause at all: freezing the sheet works, and placing the
newcomer does not come free.

**THE FIRST HYPOTHESIS ABOUT IT WAS WRONG AND A PROBE SAID SO.** The guess was a cross-layer
collision. Both nodes were in layer 2: `_separate` was forcing the newcomer into a gap between two
fixed nodes too small to hold it. `_clearOfFixed` runs at the end of `_assignCoordinates` and moves
each unfixed node clear of every fixed one in its row. It is a no-op when nothing is fixed, so no
existing layout moves.

##### 5.9.68.2 THE RULING'S OWN CLAUSE WAS THE DEFECT

§11.186.2 said the freeze *"lands as its own undo entry beside the edit"*. Built exactly that way it
worked, and the suite went red in two files that have nothing to do with the schematic's layout:

| Test | What it asserts |
|---|---|
| `schematic_remedy_test.dart` | *"ONE undo takes back the device AND the cable"* |
| `schematic_remedy_dr128_test.dart` | *"one undo takes back the converter and both cables"* |

Both predate DR-187 and both are the Edit menu's standing promise. With a freeze pushed on top of
every edit, the first `Ctrl+Z` took back the ARRANGEMENT and left the edit: the sheet visibly
scrambled, the device stayed deleted, and undoing one delete cost two presses. **That is the
behaviour DR-187 exists to abolish, reintroduced by the clause meant to deliver it.**

§11.186.2.1 replaces it. The freeze is a CHILD of the edit's own undo entry, through
`DocumentController.addConsequence`: a hook that runs at the tail of a transaction that changed
something, with the entry still open. **An epoch listener structurally cannot do this**, because
epochs bump inside `_commit` after the entry is sealed, so anything a listener runs is necessarily a
second entry.

One undo now reverts both and lands on exactly the document that existed before either, which
re-flows to the layout that was frozen, so the arrangement is right either way. `_commit` names a
transaction after its FIRST child (DR-156 §11.155.2), so the menu still says "Undo Delete device".

##### 5.9.68.3 Evidence

- **The control is half the UI file's argument.** A test that deletes a device and asserts the
  survivors did not move proves nothing until the same deletion has been measured MOVING them on an
  unfrozen document. `schematic_freeze_layout_test.dart` measures that first and pairs every claim
  against it.
- **Opening the Schematic writes nothing**, which is the half §11.186.2 is strict about, and it has
  its own case.
- **Byte behaviour is asserted twice**: undo takes the sheet away so a document that was never frozen
  is byte-identical to one that froze and undid, and an undo over a sheet that ALREADY EXISTED keeps
  the sheet and removes only what the command added.
- **`TidySheetCommand` WAS BUILT AND REACHABLE FROM NOBODY**, and the `#872` gate caught it within
  the hour. It was exempted against `#920` rather than quietly wired, because WHERE `Tidy sheet` is
  pressed from is a UI question §11.186.6 left open in terms. **The user settled it on 2026-09-22**
  (§11.186.7) and §5.9.68.4 is the row's retirement: the gate went green by the command acquiring a
  route from a person, which is the only way a row on that list is supposed to leave it.
- **`RemoveDeviceCommand.apply` RETURNS `true` WHETHER OR NOT IT REMOVED ANYTHING**, found while
  looking for a command that genuinely refuses. It defeats DR-156's refusal path: deleting a device
  that is not there makes an undo entry. Filed for a census of the rest; a purpose-built
  `_RefusingCommand` stands in for the test that needed one.
- **WHAT IS NOT ASSERTED, SAID OUT LOUD**: the freeze rides on a MOUNTED schematic canvas, because
  only a laid-out canvas knows where the symbols are. An edit made in a session where the Schematic
  was never opened records nothing, and no case covers that path because there is no arrangement yet
  to preserve. The next edit after it has been looked at freezes what was seen.
- **Floors**: `rackpal_core` 4863 to 4884, `rackpal_ui` 1966 to 1972, measured.

##### 5.9.68.4 `Tidy sheet`, and the one document edit on a bar of view toggles

Settled by the user on 2026-09-22 over the two hosts §11.186.6 left open: **the domain filter bar
now, the empty-space context menu when `#918`'s drag lands.** The bar is the schematic's only
existing chrome, so the way OUT of the freeze ships in the same change as the freeze rather than
waiting on a surface nobody has built, and docs/05 §5 already lists `Tidy sheet` on that context
menu, so the move later is a move and not a redesign.

**THE OBJECTION IS REAL AND IS ANSWERED IN THE WIDGET.** Everything else on that strip changes what
is DRAWN; this changes the document and lands on the undo stack. Three things keep them apart, and
all three travel with the button when it moves:

| Worry | What was built |
|---|---|
| It reads as another filter | A divider separates it from `All`/`None` |
| It is the button that did nothing | **DISABLED when `wouldReflow` is 0**, with a tooltip saying the sheet is already laid out rather than one that reads as a failure |
| It quietly destroys an afternoon's arranging | A confirm stating the count, and stating that pinned symbols stay |

**THE CONFIRM IS NOT INCONSISTENT WITH THE PAGE PICKER**, which argues the opposite case one folder
over and is right to: importing the wrong page is one `Ctrl+Z` away, and a prompt whose consequence
is one undo is the nag that teaches people to click through prompts. What this destroys differs in
kind. Twenty symbols moved by hand over an afternoon look exactly like twenty the layout happened to
place, so somebody who presses it by accident **cannot tell from the screen whether they have lost
anything**. That is `delete_device_dialog.dart`'s own test, and docs/05 §10 asks for the confirm in
terms.

**Evidence.** Six cases. The load-bearing one asserts that confirming lands the symbols on THE
CONTROL'S positions, the ones the same deletion produces with nothing frozen, so the tidy has
genuinely handed the sheet back to the layout rather than deleted some rows. A pinned symbol
survives (CR-068), Cancel changes nothing, and one undo restores the arrangement. **Every finder
names the button TYPE as well as the words**, because two controls say `Tidy sheet` once the dialog
is up and a bare `find.text` would tap whichever the tree reached first and pass either way.

**Floor**: `rackpal_ui` 1972 to 1978, measured.

##### 5.9.68.5 The drag, and four defects its own tests found

**The preview was priced before it was offered**, which is the only reason the choice put to the user
was a real one. One frame is 16.7 ms; `schematic_perf_test.dart`, best of five:

| Path | 300 links, 110 devices | 3,600 links, 1,320 devices |
|---|---|---|
| Wires re-routed, symbol tier reused | 0.72 ms | **8.8 ms** |
| Layout reused, wires re-routed | — | **36.3 ms** |
| Cold scene build | 7.7 ms | **76.9 ms** |

Live re-routing is affordable on a house and not on a campus, and a campus sheet is exactly the one
somebody needs to drag symbols around on. A dashed ghost costs one rectangle per frame at any size.
**What it costs is that the wires are not seen until the drop**, which §11.186.8 states rather than
leaves to be discovered.

**THE GESTURE IS THE FOURTH BRANCH OF ONE PRESS**, asked last: a pin sits ON a symbol and a pennant
beside one, so either answering first keeps the gesture it already had. It shares the canvas claim
rather than taking a third `_PointerGesture`, because a drag and a marquee are the two halves of one
branch and the loser never starts.

**Four defects, each found by a test rather than by review**, and each one a thing a person would
have met:

| What was wrong | How it would have shown |
|---|---|
| The grab point read `_lastScenePointer`, fed by `onHover` | A touch never hovers, so the drag worked on a mouse and refused **silently** on a touchscreen |
| The ghost armed at the press | A dashed outline flashed over the symbol on **every selection click**, which the handler's own comment argues against |
| The press selected | A press whose canvas is unmounted under it is CANCELLED, so the selection outlived a gesture the product says did not happen. Caught by case 2c, older than this chapter, on `F` drawing four wires for a device nothing had picked |
| The cancel ran `setState` inside `finalizeTree` | *"Cannot be marked as needing to build because the framework is locked"*, on the same unmount path |

The third is the one worth keeping: **a press is not yet a gesture.** The drop selects now.

##### 5.9.68.6 `Ctrl+Shift+U`, and why it could not wait

docs/05 §10 has ruled *"any manual move pins; `Ctrl+Shift+U` unpins"* since M2 and only the first
half was ever built. §11.186.6 listed the chord under what DR-187 does not rule; §11.186.9 moves it
into the chapter, which is existing scope changing chapters rather than a §8.3 amendment.

**THE DRAG IS WHAT CREATES THE NEED.** Every symbol a person ever nudges is pinned from then on, and
`Tidy sheet` spares a pinned symbol by design (§11.186.3, CR-068). Without an unpin, **the act of
arranging a sheet by hand is what removes it from the reach of the one command that can lay it out
again**, which is a trap a person falls into by doing exactly what the feature invites. `Ctrl+L`
stays as the toggle and is not replaced: a toggle answers *"pin this"* and an explicit unpin answers
*"give this back to the layout"*.

**Evidence.** Ten cases. **Two of the ten guard the gesture this one steals from**, because selecting
is by far the commonest thing anybody does to a symbol and a gesture that gained a move and lost a
click would be a bad trade nobody asked for; a third holds the boundary with the band on empty paper.

**WHAT IS NOT ASSERTED, SAID OUT LOUD**: the selection itself. `SchematicCanvasScreen` builds its own
private `SelectionController` and the painted op count is identical either side of a tap on a symbol
(831 both ways, measured in `schematic_marquee_test.dart`'s header). Those cases therefore assert the
selection through `Ctrl+L`, which reads it and writes to the document. The cost is that such a case
could fail for the chord instead of the selection, and `schematic_pin_selection_test.dart` is what
separates those. **This file re-learnt that the hard way**, on two red tests asserting
`controller.selection`, which on this screen is always empty.

**Keymap**: schematic 26 to 27, total 78 to 79. **Floor**: `rackpal_ui` 1978 to 1988, measured.

##### 5.9.68.7 The nudge, and the second clause of this ruling to be refuted by its own build

§11.186.4 gave the arrows a second job on the words *"the arrows nudge when no connect is in
flight"*. **That reading cannot work, and sixteen tests said so on the first build.** The arrows are
also how a pin is reached BEFORE anything is armed: docs/05 §7's *"arrow to a candidate port"*, and
`schematic_keyboard_connect_test.dart`'s route in its own name, *"arrows reach a pin, W arms it,
Enter commits"*. So *"no wire in flight"* is true for half of the connect route itself.

**§11.186.10, settled by the user from four shapes: a caret on screen is the mode.**

| State | What an arrow does |
|---|---|
| A caret is on screen | Moves the caret, exactly as before. `Esc` hands the arrows back |
| No caret, a symbol selected | Nudges it one grid unit and pins it (CR-068) |
| No caret, nothing selected | Seeds a caret, which is the old behaviour |

**The route to a caret was never taken away**: `W` seeds one and arms from it in a single press, and
always did. The test helper places its caret with `W` then `Esc`, which is **21 call sites left
untouched by one helper edit**, and it leans on that suite's own case that `Esc` cancels the wire
while leaving the caret.

**A RUN OF PRESSES IS ONE UNDO ENTRY.** Five presses costing five `Ctrl+Z` would make the feature
worse than not having it, so the move carries a `mergeKey` on the set of symbols. A pin and an unpin
never merge: those are decisions rather than adjustments, and two in a row are two things somebody
meant.

**A MERGED COMMAND IS NEVER APPLIED BEFORE A POSSIBLE REVERT**, so everything the revert reads has to
be carried across it. A test caught the one field that was not: `_sheetId` was `late final`, so a
redo of a coalesced run created the one schematic `Sheet` under a SECOND id that nothing else
resolved. It is a carried field now and its declaration says why.

##### 5.9.68.8 A GATE CORRECTED THE RELABELLING, AND IT WAS RIGHT TO

§11.186.4 asked for the arrow rows to be *"relabelled to say both"* so the generated table would not
promise one meaning. ↑/↓ already did, sharing a union label with the RACK's caret rows, where the
nudge is real.

←/→ could not. **`Arrow Right` is shared with the Device Builder's `quickAddComplete`, and
`meaningDrift` refused the pair the instant that row gained a schematic-only clause.** The gate is
right and the rule it forced is worth stating: **a shared label may state only what is true in EVERY
scope that shares the chord**, because a keyboard-only user cannot see a scope boundary. A label
promising a nudge the builder does not perform is worse than a note somebody has to open, so those
two rows keep caret-only labels and carry the nudge in their notes.

**The canon clause is corrected to say that**, rather than the sweeping version this chapter assumed.

**Evidence.** Six UI cases and five core ones. **The load-bearing UI case is the control for the
discriminator**: with a caret on screen the arrows must move it and NOT the symbol, and it asserts
both halves, so a rule that nudged unconditionally fails rather than passing quietly. One core case
asserts a run of three merges to one entry, one that a redo reuses the ids, one that a DIFFERENT
symbol does not merge, and one that a pin never merges into a move.

**WHAT IS NOT ASSERTED, SAID OUT LOUD**: the merge WINDOW. `FixedClock` puts every press at one
instant, so these cases prove the key and the carried state and say nothing about what happens when
somebody nudges, pauses for a minute, and nudges again. `clock.dart` owns that window and has its own
coverage.

**Floors**: `rackpal_core` 4884 to 4889, `rackpal_ui` 1988 to 1994, measured.

**Commits** (§8.8): the ruling `1864a8c0`, SG-1 and SG-3 `a414bc73`, the `addConsequence` mechanism
`a4719d4d`, the two commands `5e06d115`, the screen `a9e5f8c2`, the correction `f810d78c`, SG-6
`df86e875`, the drag's ruling `7d5e9114`, its command `546e2eda`, the gesture `58c13b14`, SG-5
`445388de`. **All six chapters are closed.**

---

**Related:** [Roadmap](09-roadmap.md) · [M1 implementation log](m1-implementation-log.md) ·
[Testing and quality](11-testing-and-quality.md) · [Canonical decisions](canonical-decisions.md)
(DR-006 at §11.6) · [Overview](00-overview.md)
