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
| **M5** | Validation | `M` | **0 of 3** (one clause passes, but `VACUOUS`ly) | **NOT STARTED**: `NOT BUILT` | 0 of 28 rules (DR-020 added `LEN-002`). **Its M2 block has lifted** (§5.1); canon §11.12.5 names the seam the six tier-2 rules land on. Row otherwise as of `0fa532d` |
| **Plan view** | *an epic, no number* | **`L`** | **0 of 7** | **NOT STARTED**: `NOT BUILT` | Added to v1 by DR-029 on 2026-08-09 and **sequenced before M6**. `SheetRole` has 3 values, `DiagramCanvas` has no `drawImage`, `DocumentCodec` has one implementation and `looksLikeZip` still refuses. **Decomposed 2026-08-10**, exit criterion at DR-037 §11.36.1 (§5.9) |
| **M6** | Full sheet set | `M` | **0 of 5** | **NOT STARTED**, `NOT BUILT` | 3 of 12 sheet slots ship and are real work, but the criterion is *all four starters export a complete set*, and no clause of it is demonstrated (§5.5). **The set became 12 slots at DR-048**, which moved `T6.50` Network/IP Schedule into v1, and **becomes 13** when `T1.01` lands ahead of it |
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
| — | *Goal clause:* **"and it ships to real users"** | **NOT BUILT** | No installer, no signing, no release artefact of any kind. See M8 and DR-006 |

The exporter demonstration is recorded in the closing commit `0fa532d`.

### 3.3 Unbuilt M1 checklist items

Not exit clauses, but every one is scope that a later milestone now inherits.

| Item | State | Citation | Who inherits it |
|---|---|---|---|
| **The outline tree** | **NOT BUILT** | No outline-tree surface anywhere in `lib/`: grep for `TreeView` and `Ctrl+Alt+3` across `packages/*/lib` and `apps/*/lib` returns nothing, and every `outline` hit is a drawing term (`packages/rackpal_core/lib/src/draw/scene/rack_style.dart:45`, `:51`, `:70`, enclosure, rail and device-body outlines) | **M7.** Roadmap §4 M7 *Risks* names "the outline tree shipping in M1" as its mitigation, and docs/04:455 names it as the primary AT surface. Retrofitting canvas accessibility late is precisely the structural risk that line warns about |
| **The Staging Bin** | Model-only | `packages/rackpal_ui/lib/src/canvas/staging_bin_overlay.dart:107` renders the honest text *"Staging Bin, not in this build"*; `rack_canvas_screen.dart:2981` states no command produces a `StagedPlacement` | M1 tail |
| **Shelves with auto-pack** | **NOT BUILT** | No `ShelfPlacement` handling in any UI file; `rack_shrink.dart:276`, *"DEVICES ON A SHELF ARE DELIBERATELY ABSENT"* | M1 tail |
| **0U occupants from the inspector** | **NOT BUILT** | No editing path | M1 tail |
| **Locks** | Half-built | Honoured as immovable anchors by the compaction planner; **no `Ctrl+L`, no way to set `Placement.locked`** (docs/04:195) | M1 tail |
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
| Deterministic re-layout ⇒ byte-identical display list | **DEMONSTRATED** | `packages/rackpal_core/test/scene/schematic_perf_test.dart:150` and `:158`, the same 300-link document twice, and **a separately decoded copy of the same bytes**, both through `op_digest.dart`, which is the instrument written for this clause's word *byte-identical*. `sugiyama_test.dart:470` holds the layer beneath it |
| 300-connection fixture within one frame; **label-layer cost measured and recorded** | **DEMONSTRATED, on both halves, as of M2-G** | `schematic_perf_test.dart:173`/`:182` for the COMMIT path (`@Tags(['perf'])` and deliberately not excluded, `run_suite.ps1` does no tag filtering, so the number is defended on every push), and `packages/rackpal_ui/test/draw/paint_budget_test.dart` for the PAINT path. **The paint half was unmeasured when this row was first marked, and measuring it found 64 ms: nearly four frames.** See the note below the table: the mark stood on a scene build of ~3 ms while the thing that put it on screen took twenty times longer, which no reading of "within one frame at commit" survives. It is 10.6 ms now |
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
at all** — `SheetRole` has three values and none is a cable schedule, which is #574.

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
room on `Enter` and CR-112 puts the second path in `Project ▸ Locations…`; a third would be a third
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

| # | Clause | State | Evidence |
|---|---|---|---|
| 1 | 60 drops entered in under fifteen minutes | **needs a person** | 349 keystrokes, 5.82 per drop, gated in `drop_entry_panel_test.dart:293`. The surface cannot make it impossible; only a clock can say whether a human is on pace |
| 2 | 60 `Link`s each with one `fieldLabel` | **BUILT** | `drop_build.dart:124` allocates every one through `allocateOutletFieldLabel` |
| 2b | ...and one `rackLabel` | **BUILT** *(was `NOTHING ALLOCATES ONE`)* | **DR-040 §11.39, shipped as M3-K `#661` with `#663`–`#666` Done, 2026-08-11.** The allocator's callers are now `bind_endpoint_command.dart` and `home_run_commands.dart`, not only its own test |
| 3 | Pull Sheet sorted by room then pathway, per-room footage subtotals | **BUILT as derivation** | `SchedulePreset.pullSheet`, `ScheduleSort.roomThenPathway`, `ScheduleGrouping.room` (`schedule.dart:1239`). The sheet, the initial boxes and the page are M6's under DR-027 |
| 4 | fourteen of them have unbound far ends | **REACHABLE** *(was `sixty of sixty are unbound`)* | **DR-040 §11.39 / M3-K.** `@panel=` on the drop line lands forty-six and leaves fourteen open, which is what the clause asks. The unlanded path in `drop_build.dart` is now the fourteen case rather than the only case |
| 4b | ...and each still schedules and carries a `W` number | **BUILT** | gated at `drop_entry_panel_test.dart:420`, asserted as a set |
| 4c | ...and prints | **M6's** | #574, parked there by DR-027 |

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
~20 ms. **On the shipped 300-link fixture — a house with one rack, which is what M2's criterion was
written against — a wires-only rebuild is 0.913 ms against a 16.7 ms frame**, and that case now
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

**M4 IS CLOSED. BOTH CLAUSES OF THE CRITERION ARE DEMONSTRATED**, the second of them on
2026-09-01, and §5.3.1 through §5.3.30 below are the record. **95 chapters are Done under this
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
registries and asserts there are still exactly two IR families, because the hazard IS that they are
two.

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

### 5.4 M5, Validation · `M` · IN PROGRESS, weakest mark `NOT BUILT` · ~~hard-blocked on M2~~ (block lifted at M2-F, §5.1)

> **Exit criterion, verbatim.** Every one of the **28** rules has a known-bad fixture producing
> exactly that finding and a known-good near-miss producing none — **no rule ships without its pair**
> (AC-051). A domain-expert review of the 28 rules and of the catalog data is signed off. No rule, at
> any severity, prevents a PDF from being written to disk.

| Clause | Mark | Why |
|---|---|---|
| 28 rules × fixture pair | **NOT BUILT: 0/28** | The COUNT is unchanged and everything the old text said about why is now false, which is worth separating rather than editing over. `packages/rackpal_core/lib/src/validation/` exists and holds the catalogue, `Finding`, the acknowledgement and the severity resolution (§5.4.2); CI has existed since 2026-08-27 (§4.1). What is still absent is the thing this clause counts: **no tier-2 or tier-3 rule has a predicate, and no rule of any tier has a fixture pair**. `TOP-001` to `TOP-005` are enforced by `derived/connect_rules.dart` and are still not counted here, because AC-051 asks for the PAIR and no DRC fixture corpus exists |
| Domain-expert sign-off on the 28 rules and the catalog data | **UNPERFORMED** | Has not happened |
| No rule prevents a PDF being written | **VACUOUS: true, trivially** | True because no rule exists. `packages/rackpal_core/lib/src/draw/sheet/sheet_def.dart:96-98` does correctly encode CR-023/G3 for the one heuristic that exists (a malformed NCS id is a **NOTICE, never a gate**) which is the right shape for when rules arrive |

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

#### 5.4.2 M5-A and M5-B, the whole mechanism and not one rule · CLOSED · `11028a8`, `bd158a1`, `d17d614`, `d6500b8`, `d6356db`

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

### 5.9 The Plan view · `L` · NOT STARTED, weakest mark `NOT BUILT` · decomposed 2026-08-10

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

| Clause | Mark | Why |
|---|---|---|
| PDF imported without leaving the app | **NOT BUILT** | No import path of any kind. `pdf ^3.13.0` **writes** documents and does not import pages (docs/08 §1.1); no rasteriser is in any pubspec in this tree (docs/13 D9) |
| Calibrated from a known dimension | **NOT BUILT** | `PlanScale`, `PxPt` and the two-point pick do not exist |
| Rack and every drop pinned | **NOT BUILT** | `PlanPin` does not exist; `OffRackPlacement` decodes as exactly `locationId` and `mountNote`. **The M3-I passthrough that protects a pin against an older build DOES ship** (#568, `Placement` and `Outlet` both carry the reserved `unknown` map), so that dependency is discharged |
| `T1.01` with a callout per pin | **NOT BUILT** | `SheetRole` has **exactly three values** (`rackElevationFront`, `rackElevationRear`, `equipmentList`), and `DiagramCanvas` has no `drawImage` |
| The stranger locates every drop | **UNPERFORMED** | Nothing to print, and nobody has been asked |
| Greyscale laser at ANSI B | **UNPERFORMED** | Same as M6's row: nothing has been printed on hardware |
| CR-117 on the zip path | **NOT BUILT** | `looksLikeZip` returns `UnsupportedZipContainerError` today, by design. `DocumentCodec` still has exactly one implementation |

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

#### 5.4.4 ARCH-A, a question that had two answers, and the third recorded number to stop tracking · CLOSED · `962dfa7`, `63e5850`, `33f4708`, `789cfec`

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

---

**Related:** [Roadmap](09-roadmap.md) · [M1 implementation log](m1-implementation-log.md) ·
[Testing and quality](11-testing-and-quality.md) · [Canonical decisions](canonical-decisions.md)
(DR-006 at §11.6) · [Overview](00-overview.md)
