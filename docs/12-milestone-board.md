# Milestone board — M0 → M9 → v1

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
| The schematic canvas works | It rendered a fabricated symbol behind a run of eight consecutive `fix:` commits — ten in the eighteen-commit detour overall — with zero tests; salvaged and reverted at `b560a50`. (`docs/m1-implementation-log.md:824` says *"twelve consecutive"*; over the range this board cites, `git log --oneline e433ae0^..1eec6bf` shows ten `fix:` subjects and a longest unbroken run of eight, `1eec6bf` back to `3965667`, broken by `a66668b`. The figure is corrected here rather than inherited — a table about unmeasured claims drifting is the last place to restate one) |
| The rear elevation renders | It was blank. Nothing in the regression net observed `Face.rear` in emitted bytes until `elevation_true_scale_test.dart` was written for that purpose (`0fa532d`) |
| PAL-1 is verified clear | Asserted three times by reading an eight-row domain table instead of enumerating the 385 family pairs actually drawn. The palette carried **fourteen** collisions (canon §14.3) |
| The registry-claim row is accurate | Wrong four times running; the fix was to state a **bound** rather than a closed list, enforced by `apps/rackmate/test/session/registry_claim_test.dart` |
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
outcome fits a five-mark legend — a human pass is not something a reader can execute, and a
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
here rather than buried. **M0 is `PARTIAL`, not complete** — two of its own exit conjuncts are
`VACUOUS`, and the same `VACUOUS` mark is what unseats M5's clause 3 (§5.4) and the roadmap's
global *"goldens pass"* limb (§4.3); an exemption granted to one milestone and to no other is a
preference, not a finding (§2.3). **M6 is `NOT STARTED`, not partial** — real M1-slice work sits
inside it, but zero of its five exit clauses is demonstrated, and grading "partial" against
work-in-the-milestone rather than against the criterion is precisely the substitution roadmap §8.1
forbids (§5.5). Where a milestone contains real work its headline does not credit, the **short
reason** column says so; the headline still tracks the criterion.

---

## 1. The board at a glance

Verified against the working tree at `0fa532d`, by reading code rather than checkboxes. Suite
counts from that session: `rackmate_core` 886, `rackmate_ui` 351, `apps/rackmate` 651,
`rackmate_export` 183, `rackmate_text` 1 — **2072 passing, 0 failing**. `flutter analyze`: 195
issues, all info-level, **zero errors, zero warnings**. `flutter build windows --release`: exit 0.

**M2's row alone was re-audited at `ea0af6d`** (M2-F) and again after M2-G, against the thirteen
local gates: `rackmate_core` 1380, `rackmate_ui` 592, `apps/rackmate` 690, `rackmate_export` 183,
`rackmate_text` 1 — **2846 passing, 0 failing**, analyzer pinned at exactly 194 infos by
`tools/ci/analyze_info_baseline.txt`. **Every other row is still as of `0fa532d`** and carries
whatever drift the intervening milestones introduced; a row this file has not re-read is a row it
does not vouch for, and saying so is cheaper than a footnote per row that would go stale the same
way. Board item #92 is the scheduled full sweep.

| # | Milestone | Size | Exit clauses demonstrated | Status — weakest mark | The short reason |
|---|---|---|---|---|---|
| **M0** | Foundations | `S` | **6 of 8** clause rows | **PARTIAL** — `VACUOUS` | `dart test` in `rackmate_core`, 886/0, discharges six clauses and they are good work. The `templates.keys` conjunct and the epoch-mask conjunct are true only because their subjects did not exist at M0 (§2.2) |
| **M1** | Elevation release | `L` | **8 of 8** | **CRITERION MET** — `CONFIRMED` | All eight clauses discharged. Two by a person, not a gate: the tape measure on 2026-07-27, the keyboard-only drill on 2026-07-28 at **under three minutes** against a four-minute criterion. The drill's re-run **failed first** — the palette filter could not be edited and the caret was drawn below the canvas, neither of which any remedy had named and neither of which 2206 tests could see (§3.5) — then passed against `616a301`. The three-minute figure is a 140+ wpm operator who knew the keymap; §3.2 records that condition because M7's accessibility criterion rests on this clause. The goal line's *"ships to real users"* is **not** met |
| **M2** | Wiring + live schedule | `M` | **5 of 5** | **CRITERION MET** — `CONFIRMED` | All five clauses discharged. Four by tests; one by a person, not a gate — **the user made sixty connections on 2026-08-01, in roughly 5–7 minutes, without multi-draw, which is still unbuilt (#93)**. The clause carries no time bound, so that figure is a data point rather than a threshold met. M2-G then found the half of clause 4 nobody had measured: the sheet took **64 ms to paint** beside a 3 ms build, and is 10.6 ms now (§5.1). The goal line is met; the roadmap's global *"ends green"* rule is **not**, for the same reason it is not for any milestone — no CI service has ever run (§4.1) |
| **M3** | Structure + field | `M` | **0 of 5** | **NOT STARTED** — `NOT BUILT` | Model only. **Its M2 block has lifted**: the gate was M2 putting `Link` + `Endpoint` in the UI, and M2-F did (§5.1). Row otherwise as of `0fa532d` |
| **M4** | Device builder | `M` | **0 of 2** | **NOT STARTED** — `NOT BUILT` | No builder surface. **Its inputs are all present even though its formal gate is open** — §5.3 |
| **M5** | Validation | `M` | **0 of 3** (one clause passes, but `VACUOUS`ly) | **NOT STARTED** — `NOT BUILT` | 0 of 27 rules. **Its M2 block has lifted** (§5.1); canon §11.12.5 names the seam the six tier-2 rules land on. Row otherwise as of `0fa532d` |
| **M6** | Full sheet set | `M` | **0 of 5** | **NOT STARTED** — `NOT BUILT` | 3 of 11 sheet slots ship and are real work — but the criterion is *all four starters export a complete set*, and no clause of it is demonstrated (§5.5) |
| **M7** | Platform + access | `M` | **0 of 4** | **NOT STARTED** — `NOT BUILT` | Windows-only; no `Intent` registry; no l10n at all |
| **M8** | Release engineering | `S` | **0 of 4** | **NOT STARTED** — `NOT BUILT` | No installer, no signing, no crash reporter. **Re-scoped by DR-006** |
| **M9** | Beta hardening | `M` | **0 of 1** | **NOT STARTED** — `UNPERFORMED` | Nothing is installable, so nothing is testable by anyone outside this machine |

**The global rule the roadmap sets for every milestone** (§4, verbatim):

> **Every milestone ends green**: CI passes, goldens pass, the app opens the four starter projects.
> A milestone that ends with a known-broken build has not ended.

Of its three limbs, exactly one is satisfiable today. **The app opens the four starter projects** —
`apps/rackmate/test/starters/starter_assets_test.dart` opens each of
`apps/rackmate/assets/starters/*.rackmate` through the real `DocumentStore`/`DartIoFileStore` path
and asserts `Ok`, not read-only, no migration on open, 48 templates. **CI passes** is still
unsatisfiable: a pipeline *definition* now exists and no service has ever executed it (§4.1).
**Goldens pass** is vacuous: there are no goldens (§4.3). So the roadmap's
own per-milestone green rule **has never been satisfiable for any milestone, including M0**. That
is the single most consequential finding on this board and it is the subject of §4.

---

## 2. M0 — Foundations · `S` · PARTIAL — weakest mark `VACUOUS`

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
| 1 | `dart test` green in `rackmate_core` | **DEMONSTRATED** | Run this session: **886 passing, 0 failing** |
| 2 | 1/32-inch clearance exact, 45U accumulation exact (CR-001) | **DEMONSTRATED** | `packages/rackmate_core/test/units_test.dart:6` "1/32 inch inter-panel clearance is exact" and `:15` "zero accumulated error across a 45U rack stack" — exact integer nanometre arithmetic, no tolerance |
| 3 | `write(read(bytes)) == bytes` on **three** fixtures | **DEMONSTRATED — exceeded** | `packages/rackmate_core/test/byte_roundtrip_test.dart` writes and re-reads **four** real files under `packages/rackmate_core/test/fixtures/`: `a_empty_project`, `b_rack_and_device`, `c_fuller_project`, `d_templates_and_power` |
| 4 | Command round-trip on 1,000 generated sequences | **DEMONSTRATED** | `packages/rackmate_core/test/command_roundtrip_test.dart:35` `_sequenceCount = 1000`, seeded `Random(20260718 + i)`, byte identity of real `JsonDocumentCodec` output asserted after `apply;revert` **at every step**. The run log shows 1000 discrete cases |
| 4a | *…"including `templates.keys` — AC-015"* | **VACUOUS** | `command_roundtrip_test.dart:18-21` states in its own header that `doc.templates` is never touched by any M0 command, because AC-015 refcounting is deferred. Byte identity of an untouched map proves nothing about refcounting. Honest — and undemonstrated |
| 5 | Epoch-mask coverage for **every command type** | **VACUOUS** | `packages/rackmate_core/test/epoch_mask_test.dart` covers all 8 concrete `Command` subclasses that exist — `AddDevice`, `RemoveDevice`, `MoveDevice`, `RenameEntity`×2, `SetRackHeight`, `SetRackProperty`×4, `AddLink`, `RemoveLink` — verified by grepping `extends Command` across `packages/rackmate_core/lib/src/commands/`, which returns exactly those plus `Transaction` (and a commented-out `SnapshotCommand` at `snapshot_command.dart:7`). The **command-type** limb is genuinely covered. The **epoch-mask** limb is not: its header admits it snapshots **persisted document maps**, not derived outputs, "a coverage test in spirit rather than the letter", because no derived pipeline existed at M0. That is the legend's definition of `VACUOUS` exactly — true, and true for a reason that has since stopped being true. **It has drifted** — see §4.5 |
| 6 | One v0→v1 migration fixture in the golden corpus | **DEMONSTRATED — exceeded** | `packages/rackmate_core/test/migration_corpus_test.dart` covers v0→v1 synthetically **and** a real v1→v2 file fixture, `packages/rackmate_core/test/fixtures/v1_templates_and_power.rackmate.json` |
| 7 | Zero Flutter imports, enforced by a test that fails the build | **DEMONSTRATED** | `packages/rackmate_core/test/no_flutter_import_test.dart` scans whole import/export directives (not a naive prefix match) and carries a **vacuity guard** counting files scanned — the guard is the thing that makes it a real gate rather than a test that passes on an empty glob |

**Package layout** matches CR-083's five-member list exactly: `pubspec.yaml`'s workspace at
`:7-12` lists `rackmate_core`, `rackmate_text`, `rackmate_export`, `rackmate_ui`, `apps/rackmate`.
**The demonstration of the six discharged clauses is recorded in the closing commit** per roadmap
§8.1: `b94bd60`, *"feat(core): implement rackmate_core through M0's command/undo system"*.

### 2.3 Why M0 is `PARTIAL`, and what the unbuilt checklist has to do with it — nothing

The M0 **checklist**'s last line — *"CI: analyze, test, goldens, format, the no-Flutter-import
test, the epoch-mask coverage test"* — is **entirely unbuilt**. There is no `.github` directory
(`ls -a` at the repo root; a maxdepth-3 search for `yml`/`yaml` returns only six pubspecs — the
workspace root and its five members — plus `analysis_options.yaml` and `dart_test.yaml`).

Roadmap §8.1 is explicit that *"a milestone is not 'done' when the checklist is ticked — it is done
when its exit criterion has been demonstrated"*, and the exit criterion above does not name CI. **So
the missing CI is not what unseats M0.** What unseats M0 is inside the criterion: two of its own
conjuncts — `templates.keys` (AC-015) and the epoch-mask letter (AC-014) — are `VACUOUS`, and §0's
rule is that a milestone's status is the weakest mark across its exit clauses.

**An earlier draft of this file marked M0 `COMPLETE — DEMONSTRATED` and argued here that the two
vacuous clauses "neither unseats the criterion". That argument is withdrawn.** It is recorded
rather than deleted because it is the exact failure mode the table at the top of this document
catalogues. The same `VACUOUS` mark unseats M5's clause 3 (§5.4) and the roadmap's global
*"goldens pass"* limb, which §4.3 calls *"vacuous for every milestone to date"* — an exemption
granted to one milestone and to no other is a preference, not a finding. M0's six discharged
clauses are still discharged and the work behind them is still good; `b94bd60` still records their
demonstration. What changed is the headline, which is the only thing a reader skimming §1 sees.

Separately and unchanged: **no gate in this project is mechanical**, and that is a project-level
fact, not an M0 footnote. See §4.1.

### 2.4 What would close the two vacuous clauses — and make M0 `COMPLETE`

- **AC-015 / `templates.keys`** — needs a command that touches `doc.templates` (template
  refcounting, or copy-on-place writing a `DeviceOverrides`), plus its round-trip case. The clause
  becomes real the day M4 or M1's copy-on-place lands, and not before.
- **Epoch-mask letter (AC-014)** — needs `epoch_mask_test.dart` extended to snapshot the derived
  outputs that now exist: `packages/rackmate_core/lib/src/derived/device_loads.dart`,
  `equipment_list.dart`, `totals.dart`. This is **cheap today and gets more expensive with every
  derived consumer added**. §4.5.

---

## 3. M1 — The elevation release · `L` · CRITERION MET — weakest mark `CONFIRMED`

The sole `L`, and the critical path's centre of gravity (canon §11.1.5). **All eight exit clauses
are now discharged.** Two of them by a person rather than by a gate: clause 5 (the physical tape
measure) on 2026-07-27, and clause 3 (the keyboard-only drill) on 2026-07-28. The goal line's
*"and it ships to real users"* is a separate promise and is **not** met — see §3.4.

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

Its **goal** line carries a clause the criterion does not: *"The smallest genuinely useful release
— **and it ships to real users.**"*

### 3.2 Clause by clause

| # | Clause | Mark | Evidence / what is missing |
|---|---|---|---|
| 1 | A user opens the app | **DEMONSTRATED** | `flutter build windows --release` exit 0, `√ Built build\windows\x64\runner\Release\rackmate.exe`; `apps/rackmate/test/starters/starter_assets_test.dart` opens all four starters through the real store |
| 2 | **…creates a 42U rack** | **DEMONSTRATED** | `AddRackCommand` and docs/04 §9's three-field dialog now exist, and the whole path is driven against the real screen: `packages/rackmate_ui/test/canvas/rack_creation_test.dart` presses `Ctrl+Alt+N`, types a name, commits with `Enter`, and asserts the header reads `RK-2` / `42U` — no pointer after the initial focus click. `packages/rackmate_core/test/rack_commands_test.dart` covers the command (designator allocation, order, preset-vs-typed height, undo/redo, byte round trip). **This is the CAPABILITY, not the drill.** The row it discharges is "creates a 42U rack"; the wall-clock, keyboard-only sequence is clause 3, which is **CONFIRMED** as of 2026-07-28 — see there. *Was* **NOT BUILT**, on the grep for `AddRack`/`addRack`/`createRack` returning nothing; that grep now returns `packages/rackmate_core/lib/src/commands/rack_commands.dart:59`. `apps/rackmate/lib/src/session/blank_document.dart` still seeds `kBlankProjectRackHeightU = 42` for `Ctrl+N`, and `apps/rackmate/test/session/blank_document_test.dart` now pins that seeded rack field-for-field against what the dialog builds |
| 3 | 20 devices **in under four minutes, keyboard only** | **CONFIRMED** — by the user, 2026-07-28 | **Performed and passed on 2026-07-28: under three minutes, keyboard only**, against the build carrying `616a301`. A ~25% margin under the criterion, and both halves — the speed and the keyboard-only constraint — now measured in the SAME run, which the 2026-07-27 attempt never managed. **THE OPERATOR'S CONDITIONS ARE PART OF THE MEASUREMENT AND ARE RECORDED RATHER THAN DROPPED:** the user types 140+ wpm and had already learned most of the shortcut names. That is a fast, trained operator, and it is volunteered here because the number means something different without it. The clause says "a user" and is satisfied literally — this reading is not a hedge on the mark. But **it does not establish the time for a first-run or a slower-typing operator**, and clause 3 is load-bearing for M7's accessibility criterion, where exactly that population is the subject. A run by someone who has not memorised the keymap is worth having before M7 leans on this number; see §3.4. **A CONFIRMED mark is not a gate** — no CI job re-runs this, and it does not survive a change to the keymap; the regression net named below is what guards the mechanism between drills. — *Previous mark, kept because REFUTED records a measured fact and deleting it would erase why any of the remedy exists:* **the user timed it on 2026-07-27: under four minutes, but with mouse and keyboard combined, and reported no full keyboard path exists.** So the *speed* half is demonstrated and the *keyboard-only* half is refused — which matters, because the constraint is the point: it is what makes the tool faster than Visio for a populated rack, and it is load-bearing for M7's accessibility criterion. **The named fix has since been built, and building it does not discharge the clause.** REFUTED means the act was performed and failed; only the act being performed again can move it, and no agent can perform it. What landed: `Esc` now clears the selection (docs/04 §8's third limb, `rack_canvas_screen.dart`'s `_onEscape`); a quick-add that the loop itself is repeating keeps caret-targeting live (`_selectionIsLastQuickAdd`); a cycle whose caret lands on an occupied U falls back to lowest-free-U *and says so* rather than jamming; and a refused cycle hands focus back to the canvas instead of stranding it on the modal scope. The regression net is `packages/rackmate_ui/test/canvas/keyboard_only_placement_test.dart` (11 cases, each written to fail if one half of the fix is removed) and `rack_creation_test.dart`'s twenty-device drill, which drives the caret to U5 first so the caret path and the lowest-free-U fallback give different answers. The earlier citation in this row — `rack_canvas_screen.dart:2216-2229` for a gap the code documented *against itself* — is **dead**: that comment was replaced by the fix and no line range holds it any more. The user also reports the interface "feels quite good already though may need a bit of optimization". **THE FIRST ATTEMPT TO RE-RUN THE DRILL FOUND THE PATH STILL IMPOSSIBLE, FOR REASONS NOTHING ABOVE PREDICTED** — see §3.5. Neither of the two blockers was in the remedy list this row had been carrying, and both had been shipped since M1's earliest days; the drill could not have passed on any build before `616a301` |
| 4 | Exports a **three-sheet** PDF | **DEMONSTRATED** | `packages/rackmate_core/lib/src/draw/sheet/sheet_def.dart` declares exactly `SheetRole.rackElevationFront` / `rackElevationRear` / `equipmentList`, and its header names the 2N+1 trap; `packages/rackmate_export/test/scale_notice_test.dart:141` `expect(out.sheetCount, 3)` |
| 5 | Elevations dimensionally correct **against a physical tape measure** at true scale | **CONFIRMED** — by the user, 2026-07-27 | The one clause of this criterion that no test could discharge, because it asks about *paper*. Verified by the user against a printed sheet this session and reported correct. The in-repo evidence remains `packages/rackmate_export/test/elevation_true_scale_test.dart`, which composes real `q`/`Q`/`cm` into PDF user space, derives every expectation from the literals `44_450_000` / `25_400_000` / `72.0` / `482_600_000` / `450_850_000`, regexes the ratio *n* back out of the sheet's own `SCALE` field, and takes its 0.01 pt tolerance from `PdfNum.precision = 5` rather than tuning it — but that test is titled, in `docs/m1-implementation-log.md:1434`, *"how dimensionally correct against a tape measure is proved **without a printer**"*, and the print chain (driver scaling, fit-to-page, media stretch) is exactly what it cannot reach. **Provenance is a human check, not a gate**: it is not re-run by CI and does not survive a change to the fit engine. AC-058 D13's full print matrix — ANSI B laser, ANSI D plotter, photocopy — is still scheduled at M6 and has not run |
| 6 | Equipment list matches rack contents **exactly** | **DEMONSTRATED** | `packages/rackmate_export/test/starters_export_test.dart` asserts a **bijection in both directions** over all four real starter files: designator multiset equality against the document, **plus** every designator recovered as actual text from a `T6.30` content stream |
| 7 | Baseline-y parity within 0.5% on a kerning-heavy string | **DEMONSTRATED** | `apps/rackmate/test/baseline_parity_test.dart`, fixture `AV Wa To Ty`, `tol = 0.005 * m.lineHeight` at line 208. Both backends' baselines are recovered **independently from real output** — PDF `cm`/`Td` operators out of the emitted stream; Flutter's recorded translate + `paintOffset` + `paragraph.alphabeticBaseline` — and it additionally pins Skia's line width to `PdfFont.stringMetrics` within 1%. This is `RISK-01`'s stop-the-line gate and it is genuinely green |
| 8 | Undo restores every operation in that sequence | **DEMONSTRATED** | `command_roundtrip_test.dart` at the core level, plus UI-level coverage in `packages/rackmate_ui/test/canvas/{rack_canvas_screen,rack_compaction,rack_resize_drag}_test.dart` and `test/inspector/{rack_inspector_panel,shrink_rack_dialog}_test.dart` — including *"Preset and Apply lands the preset AND the resize AND every displacement as ONE undo entry"* |
| — | *Goal clause:* **"and it ships to real users"** | **NOT BUILT** | No installer, no signing, no release artefact of any kind. See M8 and DR-006 |

The exporter demonstration is recorded in the closing commit `0fa532d`.

### 3.3 Unbuilt M1 checklist items

Not exit clauses, but every one is scope that a later milestone now inherits.

| Item | State | Citation | Who inherits it |
|---|---|---|---|
| **The outline tree** | **NOT BUILT** | No outline-tree surface anywhere in `lib/`: grep for `TreeView` and `Ctrl+Alt+3` across `packages/*/lib` and `apps/*/lib` returns nothing, and every `outline` hit is a drawing term (`packages/rackmate_core/lib/src/draw/scene/rack_style.dart:45`, `:51`, `:70` — enclosure, rail and device-body outlines) | **M7.** Roadmap §4 M7 *Risks* names "the outline tree shipping in M1" as its mitigation, and docs/04:455 names it as the primary AT surface. Retrofitting canvas accessibility late is precisely the structural risk that line warns about |
| **The Staging Bin** | Model-only | `packages/rackmate_ui/lib/src/canvas/staging_bin_overlay.dart:107` renders the honest text *"Staging Bin — not in this build"*; `rack_canvas_screen.dart:2981` states no command produces a `StagedPlacement` | M1 tail |
| **Shelves with auto-pack** | **NOT BUILT** | No `ShelfPlacement` handling in any UI file; `rack_shrink.dart:276` — *"DEVICES ON A SHELF ARE DELIBERATELY ABSENT"* | M1 tail |
| **0U occupants from the inspector** | **NOT BUILT** | No editing path | M1 tail |
| **Locks** | Half-built | Honoured as immovable anchors by the compaction planner; **no `Ctrl+L`, no way to set `Placement.locked`** (docs/04:195) | M1 tail |
| **Copy-on-place with `DeviceOverrides`** | **NOT BUILT** | Nothing writes one; `inspector_panel.dart:21` defers device-property editing | **M4** will hit this on day one |
| **`sources.md` provenance as a gate** | Prose, not a gate | `assets/catalog/sources.md` exists (166 lines) and the catalog is real (48 templates = 30 rack-side + 18 field, `packages/rackmate_core/test/catalog/seed_catalog_test.dart:19` and `:40`). But **no test anywhere names the file**: `grep -rn "sources\.md"` across all four test trees returns **nothing at all**. Its only references in the repository are three orienting `lib/` comments — `catalog_connectors.dart:15`, `rack_presets.dart:21`, `seed_catalog.dart:6`. Nothing parses the file; nothing cross-references a numeric field to a citation | §4.4 |
| **The connector-footprint CI assertion** | Real test, no CI | `seed_catalog_test.dart:281`, with `:303` and `:316` proving the exempt set is both truly footprint-free and actually reachable. It is a **CI assertion with no CI** | §4.1 |

### 3.4 What would finish M1

In the order that makes each cheaper than the next:

1. ~~**An `AddRackCommand` and the New-rack dialog**~~ — **BUILT.** `packages/rackmate_core/lib/src/commands/rack_commands.dart` and
   `packages/rackmate_ui/lib/src/inspector/new_rack_dialog.dart`, reached by `Ctrl+Alt+N`, by the
   rack header's overflow menu, and by the rack-less panel's own button. **Deleting** a rack is
   still not possible, deliberately: a removal has to answer what happens to the rack's occupants
   and docs/04 settles nothing about it (rack_commands.dart's header states the choice). Multi-rack
   *layout* is still unbuilt — the canvas edits one rack at a time and switches between them.
2. ~~**RUN AND TIME THE 20-DEVICE DRILL AGAIN.**~~ — **DONE, 2026-07-28, by the user.** Clause 3
   is `CONFIRMED`. It took two attempts and the first one failed for reasons this list had never
   named (§3.5). The sentence this item used to end on is worth keeping because it was right
   twice over: **a criterion nobody has stopwatch-tested is a criterion nobody has met**, and
   tests passing is not a person with a stopwatch. On 2026-07-28 the whole suite was green while
   the palette filter could not be edited at all. **Measured: under three minutes, keyboard only.**
3. **Print one sheet and put a tape on it.** Ten minutes of physical work gating the claim the
   whole M1 story rests on. The emitted-byte test is excellent and is *not* the clause.
   *(Performed by the user on 2026-07-27 — see §3.2 clause 5, which is CONFIRMED. Kept here as the
   shape of the work, because AC-058 D13's full print matrix is still M6 and has not run.)*
4. **The outline tree**, because it is M7's named mitigation and it is cheaper now. With clauses 3
   and 5 both closed, this and *"ships to real users"* are what is actually left of M1 — neither
   is an exit clause, and neither gates M2 or M4.
5. **Re-run the drill with an operator who has NOT memorised the keymap.** Not an M1 clause — M1 is
   met — and deliberately not written as one. The 2026-07-28 figure was set by a 140+ wpm typist
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
five `RackInspector` fields are *descendants* of it, while `DefaultTextEditingShortcuts` — the
only thing in Flutter that turns `Backspace` into a character delete — is installed by
`WidgetsApp` at the *root*. Key events dispatch **leaf → root**, so the canvas keymap was
consulted first and text editing last. Eleven keys: `Backspace`, `Delete`, `↑`, `↓`, `Home`,
`End`, `PgUp`, `PgDn`, `Esc`, `/`, `Ctrl+Z`. A mistyped filter could not be corrected or cleared,
which made the palette unusable for the rest of the session — and the drill's inner loop is
`/ query ⏎`, so the drill was not merely slow, it was **impossible**. Worse and unreported:
with a device selected, that same `Backspace` ran a real `RemoveDeviceCommand`.

This was live from `5a2a2b6` (2026-07-18), which added the search field to a tree where `6bc5be0`
had already bound `Backspace` — nine days, spanning every M1 assessment in this document.

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
every caret test asserted `CaretController.active` — a controller state — and none asked whether
the resulting line landed inside the canvas rect.

**What this cost the board, stated plainly.** §3.2 clause 3 spent this period listing a remedy
that was real, was built, was mutation-tested, and **would not have made the drill passable**,
because neither defect was in it. The mark stayed `REFUTED` on the rule that only a person can
move it, and that rule is the only reason the error surfaced at all.

**The gate that now exists.** `packages/rackmate_ui/test/canvas/palette_search_keys_test.dart`,
13 cases, two-sided: gate-always-enabled kills T0/T1/T2/T3, gate-always-disabled (a fix that
merely unbinds the keys) kills T2b/T3b, and removing both caret-visibility mechanisms kills
C2/C2b. Its C2 case carries an **anti-vacuity guard** because the first version of that case
passed with the fix deleted — the harness mounts no tab strip, so its canvas was taller than the
real app's and the 42U rack already fitted. That near-miss is the fifth instance of this
repository's signature defect and is why the guard is written as an assertion rather than a
comment.

---

## 4. Drift — what the documents say that the code does not

Read this section before trusting any other document in `docs/`. Each entry states the drift, the
evidence, and which document sites are stale.

### 4.1 There is a CI *file*. No CI service has ever run it.

**This row was "There is no CI. There has never been any CI.", verified by a maxdepth-3 search for
`yml`/`yaml` returning eight files and no workflow among them. That search now returns a ninth:
`azure-pipelines.yml` at the repository root.** The heading is corrected rather than deleted,
because the thing it was really about has not changed.

**What exists:** an Azure DevOps pipeline definition targeting a Windows agent — Flutter pinned to
3.44.4 *and verified after install*, the analyzer gate, both palette gates, the JUnit converter
self-test, all five suites with non-vacuity floors, `flutter build windows --release`, and a
published release ZIP. Plus `tools/ci/` — `analyze_gate.ps1`, `run_suite.ps1`,
`junit_from_dart_test.py`, `junit_converter_selftest.py`, `ensure_flutter.ps1`,
`verify_windows_build.ps1`, `verify_tracked_sources.ps1` and `run_local.ps1`, all of which run on a
developer machine and were mutation-tested there.

**What does NOT exist, and this is the part that matters for every claim below:** a run. No Azure
DevOps service has parsed the YAML, resolved a task name, fetched the pinned SDK archive, or built
on a hosted image. The file's own header says so in capitals and lists the four things only run 1
can prove. **Until a run number can be cited here, this row stays in section 4** — a pipeline
nobody has executed is a plan, and this document exists to separate plans from measurements.
`docs/11 §7`'s `.github/workflows/ci.yaml` job matrix is still a different, unbuilt thing.

The pre-existing contradictions below are therefore **unchanged in substance**: the gates the
corpus calls mechanical are still not mechanical on any server.

This contradicts, directly:

- **roadmap §8.4** — *"Green means green. CI runs analyze, test, goldens, format, the
  no-Flutter-import test, the epoch-mask coverage test and the connector-footprint assertion."*
- **roadmap §8.6** — *"Fixture gates are enforced by CI, not by review."*
- **roadmap §4, M0 checklist**, last line.
- **docs/11 §7**, which prints a full `.github/workflows/ci.yaml` job matrix.
- **Every sentence in the corpus containing "CI assertion" or "fails the build"** — AC-050's
  footprint gate, AC-052's provenance gate, AC-051's fixture-pair gate, docs/05:171's
  glyph-resolution test.

**What is actually true:** every gate in this project is still *a test somebody must remember to
run* — the somebody now has one command (`pwsh -File tools/ci/run_local.ps1`) instead of six, which
is an improvement in ergonomics and not in enforcement. The tests are real and mostly excellent;
nothing rejects a push. The roadmap's global per-milestone rule — *"EVERY MILESTONE ENDS GREEN: CI
passes"* — has never been satisfiable for any milestone, M0 included, and becomes satisfiable on
the day a pipeline run number can be written into this section.

**Two of the documented gates fail today**, so the CI shape as written in docs/11 §7 would go red
on the first push:

| Gate as documented | Result today |
|---|---|
| `dart analyze --fatal-infos --fatal-warnings .` | **Exits 1.** 195 style infos. (Plain `flutter analyze` is clean of errors and warnings — the failure is entirely `--fatal-infos`) |
| `dart format --output=none --set-exit-if-changed .` | **Exits 1.** *"Formatted 316 files (88 changed)"* — e.g. `packages/rackmate_ui/test/stroke_scaling_test.dart:101`, where the checked-in code splits a `const Stroke(...)` across five lines and the formatter joins it |

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
file. The decision above is still open and still the user's.

### 4.2 The M2 detour is reconciled in code, not in the documents

**Eighteen** commits (`e433ae0` … `1eec6bf`) added a schematic canvas with **zero tests** —
`git rev-list --count e433ae0^..1eec6bf` returns 18. `b560a50`
salvaged the symbol geometry and hit-testing into `rackmate_core`, deleted `sugiyama.dart` outright
— its commit message: *"It was dead (nothing constructed it) AND broken"*, naming a
`ConcurrentModificationError` on any graph with an edge and a divide-by-zero for single-node
layers — and replaced both tabs with an inert `UnbuiltView` whose `heading` getter
(`unbuilt_view.dart:73`) is `'$viewName — not built'`.

`packages/rackmate_ui/lib/src/shell/unbuilt_view.dart`'s header **reconciles the two governing
texts that conflict here**:

- **roadmap §4, M1** *"What M1 deliberately lacks"* — *"an empty Schedule tab that explains it is
  coming is a lie, so the tab does not exist yet"*, versus
- **docs/05 §12, line 780** — *"The v1 tab strip shows three tabs: Rack, Schematic, Schedule."*

It resolves them by keeping three tabs whose first line of copy is *"not built"*, and it makes that
honest mechanically: `packages/rackmate_ui/test/shell/unbuilt_view_test.dart` walks the semantics
subtree and **fails if any node offers `SemanticsAction.tap`**, so the panel provably cannot promise
anything.

**That reconciliation exists only in a source comment.** Neither docs/09 nor docs/05 has been
edited, so the next reader meets the same contradiction the salvage already settled.

### 4.3 There are no goldens

Zero occurrences of `matchesGoldenFile` or `goldenFileComparator` anywhere. No `goldens/`
directory. No `@Tags(['golden'])` on any test. **No `flutter_test_config.dart`** — so rule 1 of the
four rules docs/11 §3.1 gives for removing the system-font variable, *"register the bundled TTFs in
`flutter_test_config.dart` via `FontLoader` before any golden runs"* (docs/11:240), has nowhere to
live, under a heading that calls font strategy *"the thing that actually makes goldens flaky"*.

Meanwhile `dart_test.yaml` declares the `golden`, `slow` and `perf` tags; docs/11 §2's test pyramid
budgets **~150 pixel goldens and ~400 display-list goldens**; and the roadmap's per-milestone rule
says *"goldens pass"*. That clause is **vacuous for every milestone to date**.

One caution about vocabulary: the phrase "golden corpus" **is** satisfied in the sense docs/11 §2.5
uses it — the byte round-trip fixtures and the migration corpus. That is a different sense of the
word and it does not discharge "goldens pass".

### 4.4 AC-052's provenance gate is prose, not a build gate

`assets/catalog/sources.md` exists (166 lines); the catalog is real and asserted at 48 templates
(`seed_catalog_test.dart:19`, `:40`). But **nothing reads the file, and no test so much as names
it**:

```text
$ grep -rn "sources\.md" packages/rackmate_core/test packages/rackmate_ui/test \
      packages/rackmate_export/test apps/rackmate/test
$                     # no output — zero hits across all four test trees
```

Its only references anywhere in the repository are **three orienting comments in `lib/`**, none of
which reads or parses anything:
`packages/rackmate_core/lib/src/catalog/catalog_connectors.dart:15`,
`rack_presets.dart:21` and `seed_catalog.dart:6`.

The nearest thing to a provenance test is a group *name* at `seed_catalog_test.dart:51` —
`group('provenance-adjacent invariants (docs/catalog/seed-devices.md §7.2)', …)`. Note the file it
names: **`docs/catalog/seed-devices.md`, not `assets/catalog/sources.md`.** Those are two different
documents, and the group's own four tests say so — every manufacturer is `Generic`, no `typePrefix`
collides, field devices are 0U, every rack-side template declares a depth and a weight. Those are
invariants about the catalog's **content**. None of them is about its **citations**, which is what
AC-052 gates on. "Provenance-adjacent" is the group's own word for the distance, and it is accurate.

- **docs/11:148** claims *"an uncited template fails the build"*.
- **docs/00:174** makes the catalog's **count** depend on the gate: *"The count is set by the
  provenance gate … not by a target number (CR-061, AC-052)."*
- **`RISK-04`**'s early warning — *"`sources.md` lagging template count by more than ~10 entries"* —
  is **unmeasurable** as things stand.

Contrast the connector-footprint assertion, which **is** real and well-built
(`seed_catalog_test.dart:281`, `:303`, `:316`). The difference between the two is the template for
what mechanising AC-052 looks like.

### 4.5 The epoch-mask coverage test has drifted behind the code

`packages/rackmate_core/test/epoch_mask_test.dart`'s header says it snapshots persisted document
maps rather than derived outputs *"because no derived-data pipeline exists yet in this milestone"*.

`packages/rackmate_core/lib/src/derived/device_loads.dart`, `equipment_list.dart` and `totals.dart`
**now exist** and drive the chip strip, the rollups and the `T6.30` sheet — exactly the outputs
AC-014 wants mask-checked — and the test still does not see them.

This is the same shape as every defect in the table at the top of this document: **an assertion that
was honest when written and quietly stopped covering the thing it names.**

### 4.6 Font — Jost supersedes CR-080's IBM Plex; the docs have not caught up

The code is unambiguous. `apps/rackmate/pubspec.yaml` bundles `assets/fonts/Jost-Regular.ttf`
twice (under `fonts:` at `:135-137` and under `assets:` at `:139`) with the reasoning inline at
`:122-125`; commit `0545090`, *"style: swap the bundled font from IBM Plex Sans to Jost"*, made the
swap; every test fixture uses Jost — `apps/rackmate/test/baseline_parity_test.dart:81-82`
(`const String _kFamily = 'Jost'; const FontRef _kFont = FontRef(_kFamily);`) and a literal
`const FontRef _font = FontRef('Jost')` in eight `packages/rackmate_export/test/` files, including
`elevation_true_scale_test.dart:132` and `starters_export_test.dart:41`.

**Not propagated to:** docs/08 §10.1 (lines 1144–1154, the whole `RackBody`/`RackCond`/`RackMono`
table), docs/11:236, docs/03:146's asset tree, docs/05:171, and canon:1203, :1211, :3299, :4089.
**CR-080 itself carries no amendment**, which roadmap §8.3 requires for a ruling change.

> **The two canon line numbers moved in this commit, and are quoted post-move.** The DR-006 edit to
> `docs/canonical-decisions.md` inserts two lines at 2615 and two at 2924, shifting everything below
> by four: `git show HEAD:docs/canonical-decisions.md | grep -n "IBM Plex"` gives 3295 and 4085,
> and the working tree gives **3299** and **4089**. The figures above are the working-tree ones.
> `:1203` and `:1211` are above the first insertion and did not move.

Two consequences beyond the stale prose: **only Regular is bundled**, so the SemiBold / Condensed /
Mono cuts CR-080 requires do not exist; and the **Noto Sans Symbols 2 fallback does not exist**,
which is what docs/05:171's glyph-resolution test depends on. A tofu box in an exported drawing is
the defect that test exists to prevent, and neither the test nor the fallback is present.

### 4.7 `kSchemaVersion` is 2; the documents still print 1

`packages/rackmate_core/lib/src/units/constants.dart:22` — `const kSchemaVersion = 2` — and `:35`
— `const kMinReaderVersion = 2`, with a real `migrateV1ToV2` in `persistence/migrations.dart` and a
checked-in v1 input fixture (`packages/rackmate_core/test/fixtures/v1_templates_and_power.rackmate.json`)
proving old files still open.

**Stale:** docs/02:142 (the constants block), :167 (`int schemaVersion, minReaderVersion; // 1, 1`),
:948 and :950 (the example document), :1698; docs/03:759 and :775 (both `const kSchemaVersion = 1`
snippets, and the `migrations` map still commented out).

**A semantic change nobody has written down:** raising `kMinReaderVersion` to 2 means a v1 reader now
**refuses** a v2 file rather than opening it read-only. docs/02's own reader-behaviour table —
**:1692-1693**, the `schemaVersion` / `minReaderVersion` rows — is the place that has to say so.

> **Contested — verify before editing.** The brief that produced this board also lists
> **docs/06:320** as stale. It is not obviously stale: that `"schemaVersion": 1` sits inside a
> **`.rmdev`** example (docs/06 §7.3), and `.rmdev` has its **own parallel migration chain and its
> own corpus** per CR-063 and docs/11 §2.5. Its version is independent of `kSchemaVersion` and may
> legitimately still be 1. Do not bump it without checking `packages/rackmate_core`'s `.rmdev`
> codec — which does not exist yet (M4), so today the honest answer is that **nothing in code
> decides this**.

### 4.8 Already closed — `file_selector` / `path_provider`

Listed here because it is frequently re-reported as drift and **is not**. docs/03 §10.1 has been
rewritten: line 845 is a *"(no file-dialog package)"* row explaining the `IFileDialog` /
`FOS_DONTADDTORECENT` trade and stating the residual leak as a **bound** rather than a closed list;
line 847 is the `path_provider_windows` row explaining the umbrella / `dartjni.dll` problem.
docs/08:1085 matches.

The enforcement is real and mechanical:
`apps/rackmate/test/session/session_layering_test.dart` RULE 14d fails if `file_selector` returns;
RULE 7 pins the dialog to one call site; `apps/rackmate/test/session/registry_claim_test.dart`
fails if the doc row restates the bound as a closed list; `apps/rackmate/test/flutter_dependency_test.dart`
asserts no `*_android` or `jni` package is in `pubspec.lock`. The Release directory built this
session — `apps/rackmate/build/windows/x64/runner/Release/` — contains no `dartjni.dll`, and
neither does anywhere else in the tree (`find . -name dartjni.dll` returns nothing).
**Nothing to fix.**

### 4.9 The four starter projects do not do the job the documents assign them

**docs/11:133** requires *"At least one exercises the Structure device and at least one exports a
full sheet set."* Neither is possible yet — Structure is M3, the full sheet set is M6.

Worse, the regression net has a hole on exactly the axis it was built to guard.
`packages/rackmate_export/test/elevation_true_scale_test.dart` states in its own fixture commentary
that *"the four starters contain no `Face.rear` and no partial-width placement whatsoever, so
before this fixture nothing anywhere observed the rear reflection in emitted bytes"* — which is how
the blank-rear-elevation defect named in `0fa532d` survived. It took a purpose-built synthetic
fixture to find it.

All four starters are authored by `apps/rackmate/tool/generate_starters.dart`, so growing them is a
generator edit, not hand-authoring.

### 4.10 The roadmap carries no status at all

Zero ticked checkboxes against fifty-nine unticked ones. Roadmap §8.1 puts the demonstration in the
milestone's **closing commit message**, and that part works — `b94bd60` for M0 and `0fa532d` for
M1's exporter are both detailed and honest. What is missing is the **index from milestone to
commit**, which is what this file is.

### 4.11 Owed — DR-006's propagation into the derived documents

DR-006 (canon §11.6) is recorded, and canon §12.9 indexes what it supersedes. Parts 1–3 of the
canon carry their pointers already (canon §12.8, rows 12–17). **The derived documents do not**, and
canon §12.9 lists the debt explicitly rather than claiming it paid:

| Document | Site | Owed change |
|---|---|---|
| docs/09 §4, M6 | Exit criterion, last sentence | *"Windows OV/EV certificate procurement starts here"* — **deleted** |
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
| docs/09 §8 | Item 7, at **:498** | *"**Five are now answered — `DR-001` through `DR-005`**"*, and *"pricing (§10.3) wants deciding before M6"* | Six are settled — five answered, §10.3 **moot** under DR-006 — and pricing needs deciding neither before M6 nor at all while DR-006 stands (canon §11.6.3/12, §13) |
| docs/10 | **:6** | *"…and Part 4's binding user decisions `DR-001`–`DR-005`"* | `DR-001`–`DR-006` |
| docs/10 | **:11**, and the DR table headed at **:37** with rows **:42-46** | *"the five user decisions `DR-001`–`DR-005`"*, over a five-row table with no DR-006 row | Six decisions; a DR-006 row |
| docs/00 §11 | **:216** | *"…and the binding user decisions `DR-001`–`DR-005`"* | `DR-001`–`DR-006` |

**This board is the index that records the gap in the meantime.** §5.5 and §5.7 quote the roadmap
**verbatim** and state the DR-006 amendment beneath — the same pattern canon §12.8 uses inside the
record — precisely so that a reader who meets the stale sentence first is not misled by it.

### 4.12 Minor — three stale fixture copies at the repo root

`test/fixtures/{a_empty_project,b_rack_and_device,c_fuller_project}.rackmate.json` are **tracked**
(`git ls-files test/`). The real ones live at `packages/rackmate_core/test/fixtures/`, because
`byte_roundtrip_test.dart:443` and `codec_split_test.dart:29` use the package-relative path
`test/fixtures/…`. The root copies are an artefact of running the suite from the wrong directory,
are referenced by nothing, and will rot silently — and
`apps/rackmate/test/gitattributes_byte_exactness_test.dart:66` even lists `test/fixtures` as a path
it cares about.

### 4.13 Closed at `d8aedca` — 678 of 727 seed ports were in the wrong order

**Recorded because it was shipped, not because it is still open.** `PortBuilder._next` emitted
`a0 … a9, a10 …` into a `FracIndex`, which is `extension type const FracIndex(String v)` with **no
comparison operator** — so every consumer sorts it with `a.order.v.compareTo(b.order.v)`, a raw
string compare, and `'a10'.compareTo('a2')` is negative. From the **tenth declaration onward** an
affected template's ports sorted into an order that was neither declaration order nor anything else.

**Measured: 29 of the 45 seed templates with ports, 678 of 727 ports.** Four rules read that field
and all four were wrong on those ports — FIXED_ORDER (docs/05 §3, which is what
`buildSymbolGeometry` DRAWS, so `A01`'s zone speaker outputs were drawn out of sequence on the
sheet), `PORT_SEQ` on the schedule, `chainOutputFor` (DR-012.1), and `portsInBank` (DR-012.2).

**Nothing in the suite compared a template's declared order with its ranked order**, so nothing
could see it. It was found by a measurement taken for something else — #93 printing the fixture's
banks to choose a test target, and reading `A01` as `src.1.l src.3.l src.3.r src.4.l … src.1.r`.
`packages/rackmate_core/test/catalog/catalog_order_test.dart` is now that comparison over the whole
catalog, with a coverage assertion that the catalog still crosses the tenth declaration (**29 of
45**) so the gate cannot become vacuous by the catalog shrinking.

**What it cost to fix, stated because a status document that silently improves is this file's own
failure mode.** One line in `catalog_ports.dart` and two regenerated golden sets — the 300-link perf
fixture (405 changed lines) and the four starter projects (881 each). **Every changed line is an
`"order"` value**: no id, key, link or timestamp moved, which is what makes the regeneration a
data-only change rather than a golden quietly re-baselined. **Existing saved documents are NOT
migrated**, and correctly so: a `TemplateSnapshot` is a snapshot (docs/02 §6), and rewriting the
order values inside one would silently change a device the user placed months ago.

---

## 5. M2 → M9 — the unstarted, and where real work sits inside them

### 5.1 M2 — Wiring and the live schedule · `M` · CRITERION MET — weakest mark `CONFIRMED`

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
| 60 connections without touching a menu | **CONFIRMED** — by the user, 2026-08-01 | **Performed and passed: sixty connections, roughly 5–7 minutes, reported against this clause and therefore under its own menu-free constraint.** THE OPERATOR'S CONDITION IS PART OF THE MEASUREMENT AND IS RECORDED RATHER THAN DROPPED, as M1's clause 3 records its own: *"after a bit of practice"*. **The clause carries no time bound** — it asks for sixty connections without a menu, and 5–7 minutes is a data point rather than a threshold met, so nothing here is graded against a number the criterion does not state. **It was done WITHOUT multi-draw**, which is still unbuilt (#93): the figure is what the pin-to-pin, chain-draw and atomic-set gestures deliver on their own, and it is therefore a floor. **A CONFIRMED mark is not a gate** — no CI job re-runs this and it does not survive a change to the keymap; the regression net named below is what guards the mechanism between drills |
| Schedule shows 60 sorted rows, both labels both ends, conductor colours | **DEMONSTRATED** | `packages/rackmate_core/test/derived/schedule_test.dart:806`, a test named for this clause and asserting it verbatim: sixty rows fed in deliberately out of room order so the sort has to do the work, AC-025's room-then-pathway ordering, both labels on both ends, and `['red', 'black']` off a real speaker pair's conductors |
| Deterministic re-layout ⇒ byte-identical display list | **DEMONSTRATED** | `packages/rackmate_core/test/scene/schematic_perf_test.dart:150` and `:158` — the same 300-link document twice, and **a separately decoded copy of the same bytes**, both through `op_digest.dart`, which is the instrument written for this clause's word *byte-identical*. `sugiyama_test.dart:470` holds the layer beneath it |
| 300-connection fixture within one frame; **label-layer cost measured and recorded** | **DEMONSTRATED — on both halves, as of M2-G** | `schematic_perf_test.dart:173`/`:182` for the COMMIT path (`@Tags(['perf'])` and deliberately not excluded — `run_suite.ps1` does no tag filtering, so the number is defended on every push), and `packages/rackmate_ui/test/draw/paint_budget_test.dart` for the PAINT path. **The paint half was unmeasured when this row was first marked, and measuring it found 64 ms — nearly four frames.** See the note below the table: the mark stood on a scene build of ~3 ms while the thing that put it on screen took twenty times longer, which no reading of "within one frame at commit" survives. It is 10.6 ms now |
| Keyboard path + screen-reader announcements | **DEMONSTRATED — at the channel, not with a screen reader** | `packages/rackmate_ui/test/canvas/schematic/schematic_keyboard_connect_test.dart:151` walks arrows → `W` → `Enter` to one `Link`, and `:639` intercepts `SystemChannels.accessibility` to assert a commit is announced **once** and never as a cancellation. The limit is stated rather than assumed: what is verified is the platform message, not NVDA reading it aloud, and M7's accessibility criterion is where a real reader meets this |

**The paint half of clause 4, and why this row was half-right for a week.**
When M2-F re-audited this section it marked clause 4 `DEMONSTRATED` and cited
`schematic_perf_test.dart`. That test is real and it measures the clause's own words —
*"the label-layer commit cost"* — but `rackmate_core` is a pure-Dart package and **cannot touch a
`ui.Canvas`**, so what was demonstrated was the display list being BUILT, not the display list being
PAINTED. M2-G measured the second half and found the 300-link fixture taking **63.9 ms to replay,
against a 16.7 ms frame** — while the build it was cited beside took about 3 ms. On any reading of
*"within one frame at commit"* that includes getting the sheet onto the screen, the clause was
false and the citation could not see it.

**83 % of that paint was repeated text layout.** `FlutterDiagramCanvas.drawText` built a fresh
`TextPainter` — and a native `ui.Paragraph` — on every call, and a pan re-records the picture, so
the 300-link sheet laid out 2 374 runs per frame over a working set of 703. With M2-G's cache the
same replay is **10.6 ms**, inside the budget. The figures are recorded by
`paint_budget_test.dart`, which states plainly that `flutter test` does not register the shipped
Jost so the absolute milliseconds are the test font's — the RATIO is font-independent and is what
the row now rests on.

**The roadmap's own sizing for that cache did not survive the measurement either.** docs/09's M2
risk paragraph says the cache "must be sized for" ~10,000 runs and warns that "a 2,000-entry LRU
against ~10,000 runs thrashes". The census counts a working set of **703**. The prescribed 2,000 is
a good number for the opposite reason to the one given, and the prescribed KEY —
`(text, styleId, quantisedScale)` — would have caused the thrash it feared, because `sizePt` is in
diagram units and the zoom is applied to the canvas, so scale is not a term at all
(`text_run_cache_test.dart` measures that: the same run at two zooms is one layout).

**What guards clause 1 between drills.** A `CONFIRMED` mark discharges the clause and guards
nothing, so the mechanism it rests on is covered separately: the keyboard route
(`schematic_keyboard_connect_test.dart`), drag-to-connect with the 12 screen-px magnetic snap
(`schematic_drag_connect_test.dart`), chain-draw and DR-012.3's family-weighted magnet, and
`atomicConnect` for the multi-conductor sets (`schematic_atomic_set_test.dart`). ~~**Multi-draw is
the one gesture of RJ-001's four that is not built**~~ — **built at `e078c0b`, board item #93**;
`multi_draw_test.dart`, `pin_selection_test.dart`, `schematic_pin_selection_test.dart` and
`schematic_multi_draw_test.dart` are its four suites, the last of which is one group per claim in
docs/05:484. All four of RJ-001's gestures now exist. **The drill passed WITHOUT it**, which is the
useful thing the run established beyond the mark and which does not change now that it is built:
multi-draw is a throughput improvement on a clause that was already met, not a requirement of it,
and no re-run is owed.

**What the run does NOT establish.** A first-run operator's time — the report says *"after a bit of
practice"*, and M1's clause 3 carries the same caveat for the same reason. This board does not lean
on that figure anywhere, and unlike M1's keyboard-only drill no later milestone's criterion rests on
it, so no follow-up run is owed.

**What was `NOT BUILT` in the previous revision and is not now**, since a status document that
silently improves is the failure mode this file is written against:

- the schedule derivation (`packages/rackmate_core/lib/src/derived/schedule.dart`) and the Schedule
  tab that renders it — CR-105/AC-035's *live from an empty project* is `schedule_test.dart:254`;
- Sugiyama phases 0–3 (`draw/scene/sugiyama.dart`) and the schematic scene builder;
- net labels as the default render (DR-001), the domain filter bar, hue-by-domain styling
  (`signal_style.dart`, PAL-1 gated), and `wire_trace.dart`'s drawn mode;
- the connect commands, tier-1 topology (`TOP-001`…`TOP-005`) and DR-011's pin-to-pin gesture;
- `Ctrl+1..4` — `app_shell.dart`'s `kViewKeyToTabIndex`, with `Ctrl+3` deliberately dead per CR-071;
- **CR-105's signposting and AC-048's coach mark**, which M2-F's last phase landed: a port-count
  chip on every device with unwired pins, clicking it switches to the Schematic with that device
  selected (`packages/rackmate_ui/test/canvas/port_chip_test.dart`,
  `apps/rackmate/test/session/signposting_test.dart`), and the domain-filter coach mark fires on the
  first sheet, persisted per USER in app-support prefs under DR-012.4.

**Two claims in this section that were wrong and are corrected rather than deleted.** The old text
said `AddLinkCommand`/`RemoveLinkCommand` were *"referenced from `lib/` code in exactly two places,
both of them the `UnbuiltView` copy strings"*. That was true and is not: four link-minting commands
now have real callers, and `apps/rackmate/test/unbuilt_copy_accuracy_test.dart` was widened during
M2-F precisely because it scanned for `AddLinkCommand(` alone and would have stayed green while both
copies lied. The old text also called `symbol_layer.dart` *"a symbol renderer and hit-tester that no
screen consumes"* — `schematic_canvas_screen.dart` consumes both.

**What M2 still carries, with its criterion met.** ~~Multi-draw (#93) and the portable build
(#13).~~ **Both are done** — multi-draw at `e078c0b`, the portable build at `bee96bd`. Neither was
named by the exit criterion, which is why neither held the headline — roadmap §8.1: *the exit
criterion is the unit of truth*, and grading a milestone against work-in-the-milestone rather
than against its criterion is the substitution §5.5 refuses for M6. The six tier-2 spring-back rules
are **not** M2's at all — canon defers them to M5 (§11.12.5), and implementing one as a tier-1
refusal would make the product unable to draw a mistake, which CR-017 and G2 exist to prevent.

**#124 is built (`b128a42`), and it exposes a gap in CR-081 worth recording.** The pennant's family
glyph is drawn as GEOMETRY rather than as a character, because as a character it was measured by
`PdfFontMeasurer` over Jost — which carries none of the four Unicode blocks these symbols live in,
so it returned a near-zero advance — and painted on screen by a `TextPainter` that fell back to a
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

**DR-014 is built (#110, `acdae02` + `0e5c568`).** A wire drawn from an already-wired set member to
a **different device** now splits the set automatically — no modifier, no mode letter, no dialog,
because #110's own costing found no free single modifier to bind one to (`Ctrl` is the magnet
suppressor and additive selection, `Alt` is DR-001's hover, `Shift` is multi-draw's run-selection).
It closes the field report *"the Right analog audio channels can't have connections made once the
left channel is made"*, which was `atomicConnect` working correctly against a pair that had already
become one cable. **§11.11.2 is amended, not overturned**: the branch is still decided by the jack,
and what changed is that a set which is already one cable has no legal set gesture left, so a full
member arms the pin-to-pin path. Four conditions keep the split from firing where the gesture could
mean anything else, and the third — never lift the LAST conductor out of a link — is what stops a
split from being a silent delete of a cable the user cannot see. The announcement names the
conductor counts on both cables, per DR-012.2, and the Edit menu says `splitSet`.

**DR-013 is built (#95, `48f1198`), and D7's gate is paid (#94, `7c2ac49`).**
Deleting a wired device now cascades — its cables, its materialised ports and any net no survivor
still carries — after a confirmation naming the count, with an undo that restores every one under
its own id. The `TODO(post-M0)` that DR-011.1 turned from inert into a live defect is closed: a
schedule can no longer print a row citing a device the document does not have (CR-017). Building it
made a **latent defect reachable**, which the property suite caught immediately — a `Link` can now
vanish without `RemoveLinkCommand` doing it, so *"apply ran and found nothing"* became a legal state
that the nullable-capture guard was reporting as *"revert before apply"*, throwing out of undo.
Separately, `keymap_source_ban_test.dart` closes the hole §4's own D7 discussion named: the
`SingleActivator` ban now covers `rackmate_ui`, the package every binding surface except the File
menu lives in, and it landed **before** M3-C rather than after.

**The portable build (#13), and why it is not M8 arriving early.** `docs/14-deployment.md` and
`tools/release/`. **It is a scope edit and is recorded as one**: DR-006 consequence 4 says outright
that a portable output before M8 is *"a scope edit under roadmap §8.3 and not something this
consequence grants"*, and one was wanted early so the team has something to test with. What it
delivers is a signed, timestamped portable folder — nothing else. **M8's four exit clauses are
untouched**: no installer, no crash reporter, no cold-start budget, no documented limits, and §5.7's
marks do not move. The app half needed no code at all: `data_root.dart` has been the portable seam
since M0, and docs/03:847's claim that pinning `path_provider_windows` to one call site *"keeps M2's
portable build a one-function change"* held exactly — **verified by running the staged tree, which
wrote `RackMateData\sessions\<uuid>.lease` beside the executable rather than under AppData**.

**Two findings from building it, both recorded because they are corrections to the corpus and not
to the code.** First, **DR-006 §11.6.2's expiry recipe has an unstated precondition**: run as
written on a normal build machine it is INCONCLUSIVE, because a self-signed root is untrusted there
and the chain engine reports `UntrustedRoot` before it ever reaches the time check — so *both* the
timestamped and the untimestamped copy come back identical and the difference the clause exists to
prove is masked. `verify_signatures.ps1` takes the verdict from `X509Chain` with an explicit
`VerificationTime` instead, and states plainly which half is observed and which is modelled. Second,
**"every artifact a release produces" is not "every file it ships"**: the first signing run replaced
Microsoft's signature on the three redistributable VC++ DLLs with a self-signed one, trading a chain
that validates on every Windows machine for one that validates only where the GPO has landed.
Binaries already signed by another publisher are now skipped.

### 5.2 M3 — Structure and the field · `M` · NOT STARTED — weakest mark `NOT BUILT` · ~~hard-blocked on M2~~ (block lifted at M2-F, §5.1)

> **Exit criterion, verbatim.** A 60-drop whole-house rough-in is entered in under fifteen minutes,
> produces 60 `Link`s each with one `fieldLabel` and one `rackLabel`, and exports a Pull Sheet
> sorted by room and pathway with per-room footage subtotals and initial boxes. **Fourteen of those
> drops have unbound far ends and every one of them still schedules, prints and carries a `W`
> number** (AC-018). Requirement 6 is met.

**Every clause NOT BUILT.** Model only, inherited from M0:
`packages/rackmate_core/lib/src/model/{outlet,structure_body,location,pathway}.dart`, persisted and
byte-round-tripped by the `c_fuller_project` fixture. Grepping `Outlet`/`StructureBody`/`Pathway`/
`Location` across `packages/rackmate_ui/lib` and `apps/rackmate/lib` finds **no Structure UI at
all** — only three **hard-coded demo Locations** at
`packages/rackmate_ui/lib/src/canvas/rack_canvas_screen.dart:4030-4032` (Main House / Media Closet /
Living Room), whose own comment at `:4026-4027` says *"the project Locations panel (CR-112) and the
'+ New…' creation flow remain out of scope, so these are seeded rather than creatable"*, and a
chip-strip `Outlets` label at `rack_metrics_row.dart:136`.

The AC-018 clause is **unreachable by construction**: nothing schedules and nothing prints a `W`
number. That M2 block — `Link` + `Endpoint` reaching the UI — is discharged as of `ea0af6d` (§5.1).

### 5.3 M4 — The device builder · `M` · NOT STARTED — weakest mark `NOT BUILT`

> **Exit criterion, verbatim.** A 16×16 matrix template is authored from scratch **in under three
> minutes by a user who has seen the tool once**, and a template saved with exactly three fields plus
> ports places into a rack and appears correctly in the equipment list with `—` in every unknown
> column and an accurate unknown count in the rollup.

**No builder surface exists.** `ls packages/rackmate_ui/lib/src/` returns exactly five directories —
`canvas/`, `draw/`, `inspector/` (`inspector_panel`, `rack_inspector_panel`, `shrink_rack_dialog`),
`palette/` (one file) and `shell/`. No `builder/`, no port grid, no form. Grep for `rmdev` across
`packages/*/lib` and `apps/*/lib` returns **nothing**, so the single-file `.rmdev` codec and its
`contentHash` warning do not exist. `TemplateBody`/`PortDef`/`TemplateSnapshot` exist in core
(`packages/rackmate_core/lib/src/model/template.dart`, `port.dart`) and are exercised only by the 48
seeded catalog templates.

**One of those five is a starting point, not an absence.** `draw/` holds
`packages/rackmate_ui/lib/src/draw/flutter_canvas.dart:52`, `final class FlutterDiagramCanvas
implements DiagramCanvas` — the on-screen backend of the same IR the PDF side replays. A port grid
is a `DiagramScene` fragment like any other, so the builder's rendering surface is the one part of
M4 that is already built and already parity-tested. That is a narrower claim than "no surface to
build on" and it is the accurate one.

**Note the second half of the criterion is partly pre-satisfied by other work.** The equipment list
already renders `—` per unknown column with an accurate unknown count
(`packages/rackmate_core/lib/src/derived/totals.dart`,
`packages/rackmate_ui/lib/src/canvas/rack_metrics_row.dart`). What is missing is any way to **author
the template** that would exercise it.

**Its gate is now clear, and the reason is worth stating precisely.** Roadmap §5 lists `M1→M4`
among the hard blocks, and §3 of this file now marks M1 **CRITERION MET** — all eight exit
clauses discharged. Under roadmap §8.1 — *the exit criterion is the unit of truth* — the gate is
the criterion and nothing else, so **M4's hard block is discharged.** What is NOT discharged is
M1's goal line, *"and it ships to real users"*, and its six open checklist items (§3.3). Neither
is an exit clause, so neither holds this gate; both are real work and are tracked where they
belong. Sequencing M4 remains a priority judgement, not a blocked move.

What is true is narrower and still useful. The artifact the roadmap's `M1→M4` arrow actually names
is *"devices exist"*, and it does: `TemplateBody`/`PortDef`/`TemplateSnapshot` are in core, 48
templates place into a rack, and the equipment list renders them. **M1 has no open exit
clause left, and the one that was open longest was never an input to a device builder** — clause
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

### 5.4 M5 — Validation · `M` · NOT STARTED — weakest mark `NOT BUILT` · ~~hard-blocked on M2~~ (block lifted at M2-F, §5.1)

> **Exit criterion, verbatim.** Every one of the **27** rules has a known-bad fixture producing
> exactly that finding and a known-good near-miss producing none — **no rule ships without its pair**
> (AC-051). A domain-expert review of the 27 rules and of the catalog data is signed off. No rule, at
> any severity, prevents a PDF from being written to disk.

| Clause | Mark | Why |
|---|---|---|
| 27 rules × fixture pair | **NOT BUILT — 0/27** | No `validation/` or `rules/` directory under `packages/`, no rule registry, no `Finding` type, no severity resolution. No DRC fixture corpus. AC-051's gate is supposed to be *"enforced in CI"* and there is no CI |
| Domain-expert sign-off on the 27 rules and the catalog data | **UNPERFORMED** | Has not happened |
| No rule prevents a PDF being written | **VACUOUS — true, trivially** | True because no rule exists. `packages/rackmate_core/lib/src/draw/sheet/sheet_def.dart:96-98` does correctly encode CR-023/G3 for the one heuristic that exists — a malformed NCS id is a **NOTICE, never a gate** — which is the right shape for when rules arrive |

Two persisted shells survive from M0 — `packages/rackmate_core/lib/src/model/acked_finding.dart` and
`rule_override.dart` — both codec-round-tripped and **never produced by anything**. The rack
editor's Validation drawer and Rack Vitals are both listed *not started* in
`docs/m1-implementation-log.md` §2 §1 — `:47` (*"Rack Vitals stays not-started (§5, needs the
validation engine)"*) and `:56` (*"Validation drawer … not started"*) — for this reason.

### 5.5 M6 — The full sheet set · `M` · NOT STARTED — weakest mark `NOT BUILT` · blocked three ways

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
| All four starters export a **complete sheet set** | **NOT BUILT** | They export **3 of 11 slots**. Missing: `T0.00` cover/index, `T0.01` legend, `T0.02` exceptions, `T6.01+` interconnect, `T6.10` pull sheet, `T6.11` termination schedule, `T6.20` unused home runs, `T5.01` pinout details. `sheet_def.dart:15-20` states this plainly and states **why**: *"most of them need `Link`s, which do not exist until M2. They are absent from `SheetRole` rather than stubbed"* |
| Legend under deuteranopia / protanopia simulation | **UNPERFORMED** | No legend sheet exists to verify |
| Real greyscale laser print (AC-054) | **UNPERFORMED** | Nothing has been printed |
| ANSI B laser / ANSI D plotter / photocopy, physically inspected and signed off (AC-058 D13) | **UNPERFORMED** | Nothing has been printed |
| Requirement 7 met | **NOT BUILT** | Follows from clause 1. (`NOT MET` is not one of §0's seven marks; the mark is the one clause 1 carries. Note this is distinct from `REFUTED`, which requires that somebody actually attempted the act and it failed — nobody has attempted this one) |

**Why this is `NOT STARTED` and not `PARTIAL`.** Real, tested, shipped work sits inside M6 — more
than in any other unstarted milestone — and none of it discharges a clause of M6's criterion, which
is about **complete** sheet sets and **physical** sign-off. §0's rule grades the criterion, not the
work. The work is described next so the headline does not erase it.

**What exists is M1's slice, and it is real.** `packages/rackmate_core/lib/src/draw/sheet/` carries
`sheet_frame.dart` (border, outer/inner rules), `title_block.dart`, `revision_block.dart`,
`sheet_furniture.dart` — which composes them into **one `DiagramScene` fragment so `rackmate_ui`
can replay the identical object**, a deliberate and documented deviation from docs/08 §5's
`PageTheme` mechanism — `drawing_scale.dart` (the honest `1:n` / `NTS` report),
`elevation_sheet.dart` and `equipment_sheet.dart`. All are tested
(`packages/rackmate_core/test/sheet/*.dart`, `packages/rackmate_export/test/sheet_furniture_pdf_test.dart`),
all four starters export real PDF bytes (`packages/rackmate_export/test/starters_export_test.dart`),
and export is wired into the app with a full error surface
(`apps/rackmate/test/session/export_controller_test.dart`).

**Furniture is incomplete against DR-005.** The **zone band and grid are not drawn** —
`packages/rackmate_core/lib/src/draw/sheet/sheet_frame.dart:377` says so verbatim (*"The zone band
between them is NOT drawn — see the file header"*) and `:23-30` records the deviation and the arithmetic behind it (*"THE 6 PT INSET vs §5.1's ZONE BAND, recorded rather than papered over"*). There are no
revision clouds and no `RevisionEntry`-driven lettered triangle. There is no `ISSUED FOR
CONSTRUCTION` stamp (grep across core and export `lib/` returns nothing). Also absent: dry-run sheet
count, the 40-sheet warning, the 2000-sheet cap, export preview, progress/cancel, and the `kIsWeb`
isolate guard.

**Incremental cost from here:** eight sheet roles, the zone band and grid, revision clouds, the IFC
stamp, and the export-dialog apparatus. **Hard-blocked three ways** as a join on M2, M3 and M5 — the
milestone most exposed to slip anywhere upstream (roadmap §5).

### 5.6 M7 — Platform and access · `M` · NOT STARTED — weakest mark `NOT BUILT`

> **Exit criterion, verbatim.** A reviewer opens a `.rackmate` file on a tablet and reads the
> elevation, the schedule and the PDF; the NVDA matrix passes on the elevation, the schedule and the
> connection-creation path; no keybinding is bound twice in the generated table; the pseudo-locale
> build shows no hard-coded English in the primary surfaces.

| Clause | Mark | Why |
|---|---|---|
| Tablet read-only surfaces | **NOT BUILT** | `apps/rackmate` has only a `windows/` platform directory — no `android`/`ios`/`macos`/`linux`, which `apps/rackmate/pubspec.yaml`'s `path_provider_windows` comment states as a deliberate fact. No explicit statement for the two unavailable surfaces either |
| NVDA / VoiceOver matrix | **NOT BUILT** | And the connection-creation path it must pass on does not exist (M2) |
| No keybinding bound twice **in the generated table** | **NOT BUILT — nothing generates a table** | Keybindings are hand-written `SingleActivator` maps in exactly two files: `apps/rackmate/lib/src/session/app_shell.dart:69-76` (`kFileShortcuts`, four file bindings at `:71`, `:72`, `:73` and `:74-75`, asserted at exactly four by `session_layering_test` RULE 14) and `packages/rackmate_ui/lib/src/canvas/rack_canvas_screen.dart:3278-3350` (the canvas `Shortcuts` map, **18** `SingleActivator` entries counted over that range — `Ctrl+Alt+N` for the New-rack dialog is the newest, and `Esc` is now bound to a ladder rather than a single cancel). Nothing generates a table and nothing arbitrates collisions. CR-101's 16 collisions are unfixed because the ~40-binding keymap does not exist |
| Pseudo-locale build shows no hard-coded English | **NOT BUILT** | **No localisation at all**: `apps/rackmate/pubspec.yaml` has no `flutter_localizations` dependency, no `.arb` files, no `AppLocalizations` — so docs/11 §7's `flutter gen-l10n && git diff --exit-code` gate has nothing to run against |

**Inherits an unpaid M1 debt:** roadmap §4 M7 *Risks* names the outline tree shipping in M1 as this
milestone's mitigation, and it did not ship (§3.3).

**Also missing:** WCAG AA verification, raised filtered-wire alpha, non-colour encoding on rack
fills, the in-app glossary, the single-voice error-message catalogue, the eight empty states, and
progress/cancel on every operation over 500 ms.

### 5.7 M8 — Release engineering · `S` · NOT STARTED — weakest mark `NOT BUILT` · **re-scoped by DR-006**

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
| Induced crash ⇒ local report with **no project content** | **NOT BUILT** | No crash reporter exists. The only related artefact is `apps/rackmate/lib/src/storage/storage_log.dart` and `session_layering_test` RULE 13's CR-096 redaction check — **a policy with no reporter behind it** |
| Documented limits behave as documented | **VACUOUS** | No documented limits, no 1.5× soft warning, no 3× open-read-only gate in code |
| *(not an exit clause — M8 checklist)* Licence / EULA, `showLicensePage`, version-check ping | **NOT BUILT** | Listed for completeness. M8's exit criterion has **four** clauses; this row is checklist scope, and it does not enter the weakest-mark arithmetic |

**One thing this milestone inherits cleanly:** the Release build is already lean.
`apps/rackmate/build/windows/x64/runner/Release/` — **not** the repo-root `build/`, which holds only
`native_assets/`, `test_cache/` and `unit_test_assets/` — contains six entries: `rackmate.exe`,
`flutter_windows.dll`, two plugin DLLs (`screen_retriever_windows_plugin.dll`,
`window_manager_plugin.dll`), `data/` and `native_assets.json`. The load-bearing fact is what is
absent: **no `dartjni.dll`**, here or anywhere in the tree, which
`apps/rackmate/test/flutter_dependency_test.dart` asserts and which the `flutter build windows
--release` run this session confirms.

### 5.8 M9 — Beta hardening · `M` · NOT STARTED — weakest mark `UNPERFORMED` · hard-blocked on M8

> **Exit criterion, verbatim.** Three integrators have each produced a sheet set they were willing to
> send to a client or a job site, and none of the three needed to leave the app to fix something.
> **That is the only exit criterion that matters and it is deliberately a judgement, not a metric.**

**Unreachable on two counts.** Nothing is installable, so no integrator can run it (M8); and only 3
of 11 sheets exist, so no sheet set is sendable (M6).

No beta artefacts of any kind exist in the repo: no integrator names, no real-project fixtures
beyond the four synthetic starters (`apps/rackmate/assets/starters/{apartment,home_theatre,small_office,whole_house}.rackmate`,
all authored by `apps/rackmate/tool/generate_starters.dart`), and no performance harness to measure
against recorded budgets — **zero `@Tags(['perf'])` tests exist**.

`RISK-08`'s early warning (*"no named integrator by the end of M6"*) is moot because M6 has not
started — but **the recruiting lead time is already running against the calendar**, and it does not
depend on anything being built. Under DR-006 the population changes — three integrators become three
internal users on three real jobs, §7.2's M9 row — but the lead time does not.

---

## 6. The dependency graph, as it actually stands

### 6.1 What can be worked on now

Entries 1–8, 7a, 10 and 11 need **no milestone's output at all**, and every one of them is a
**mechanism that would have caught a defect this project has already shipped** — which is the
argument for doing them first. **Entry 9 is the exception and is marked as one**: M4's gate is a
hard block that this board's own §3 says is not discharged. It is listed here because its inputs
exist, not because it is ungated, and the *Gated on* column says which.

| # | Work | Gated on | Why it is first |
|---|---|---|---|
| 1 | **Stand up CI at all** | Nothing | There is none (§4.1). Every "CI assertion" in the corpus is currently a test somebody must remember to run |
| 2 | **Decide the two failing gates** — format the 88 files and clear the 195 infos, **or** amend docs/11 §7 | Nothing — but it is a **user decision**, not an engineering one | Standing up CI without deciding produces a permanently red main branch (§4.1) |
| 3 | **First goldens + `flutter_test_config.dart` registering Jost** | Nothing | Makes *"goldens pass"* stop being a clause with nothing behind it (§4.3) |
| 4 | **Mechanise the `sources.md` provenance gate** | Nothing | AC-052 is prose today; `RISK-04`'s early warning is unmeasurable (§4.4) |
| 5 | **Extend `epoch_mask_test.dart` to the derived pipeline** | Nothing | The drift is live and grows with every derived consumer (§4.5) |
| 6 | **Propagate the Jost and `kSchemaVersion`-2 drift** into docs/08, docs/11, docs/02, docs/03 and canon; amend CR-080 | Nothing | Roadmap §8.3 requires an amendment for a ruling change; CR-080 has none (§4.6, §4.7) |
| 7 | **Propagate DR-006 into docs/09, docs/11, docs/10 and docs/00** | Nothing | **Nine** sites — the five signing sites plus four decision-count sites, all listed in §4.11 and in canon §12.9. Until they land, the roadmap tells the next reader to order a certificate and three documents tell them there are five user decisions |
| 7a | **Delete the three root `test/fixtures/` copies** | Nothing | Five seconds (§4.12) |
| 8 | **Finish M1** — ~~`AddRackCommand` + New-rack dialog~~ (built); ~~keyboard deselect~~ (built) **but time the drill**; ~~print a sheet~~ (done 2026-07-27); the outline tree | Nothing | One exit clause and one goal clause, and the exit clause needs a **person with a stopwatch**, not code (§3.4) |
| 9 | **M4, the device builder** | **M1 — a hard block (roadmap §5), DISCHARGED 2026-07-28** | Its inputs were all present long before its gate opened: the arrow's named artifact (*"devices exist"*) is there, and clause 3's keyboard-only drill was never a device-builder input (§5.3). The gate is now clear on the criterion, which is the only thing §8.1 lets a gate depend on. It still sits below M2 here on ordering grounds, not blocking ones |
| 10 | ~~**A perf harness** (`@Tags(['perf'])`, op-count-per-layer)~~ — **BUILT** | Nothing | Was: *"M2's exit criterion demands a measurement; there is no instrument"*. `packages/rackmate_core/test/scene/schematic_perf_test.dart` is that instrument, tagged and unexcluded so it runs on every push (§5.1) |
| 11 | **Recruit beta integrators** | Nothing but calendar | `RISK-08` lead time (§5.8) |

**Removed from this list by DR-006:** *"order the Windows OV/EV certificate now"*, which the
pre-DR-006 dependency graph made the twelfth entry here because `RISK-07` prices it in weeks of
external identity verification. Self-signing has no lead time and Microsoft Trusted Signing has no
reputation ramp, so it moves back to M8 where it belongs. **This is the single largest calendar
saving DR-006 buys.**

### 6.2 Gated, and correctly so

```text
 M0 ◑ PARTIAL — weakest mark VACUOUS
  │  6 of 8 clause rows demonstrated; `templates.keys` and the
  │  epoch-mask letter are true only because their subjects did
  │  not exist at M0 (§2.2, §4.5). One is cheap to close now;
  │  the other waits on M4 or copy-on-place (§2.4)
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
                                   │            3 of 11 slots are built and real; no
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
`doc.templates` — M4, or M1's copy-on-place. **So M0's headline cannot go green on the strength of
this board alone, and ◑ must not be read as ✔.**

**Do not start M3 or M5 early.** M3 needs `Link` + `Endpoint` present in the UI before a drop can
become a home run; M5's findings need a wired graph to have anything to find. **The schematic detour
is the proof**: eighteen commits of out-of-order work that had to be salvaged or deleted (§4.2).

**The honest read of the graph today.** M0 is *nearly* done — six clauses discharged, two vacuous,
one of which can be closed this week (§2.4). M1 is close but has three untested exit clauses and six
unbuilt checklist items. Everything from M2 rightward has **zero** demonstrated exit clauses, **except a tested
symbol renderer sitting in `rackmate_core` with no consumer** (§5.1) and M6's real but unclaimed
M1 slice (§5.5).

---

## 7. The decision the user has to make

Roadmap §3 states the cost deliberately — **42–65 weeks of implementation, 11–17 months to a shipped
v1** — on AC-017's ground that *"a detailed design set with no cost attached reliably stalls at
40%"*. That number was written for a **commercial** v1. **DR-006 (canon §11.6) rules that RackMate
is an internal tool with no commercial release planned**, which changes the calculus on several
milestones and on none of the others. This section lays out what could move to v1.1 and what each
deferral costs. **It does not make the call.**

### 7.1 What has already been spent, and what is left

| | Weeks (roadmap §6) | State |
|---|---|---|
| M0 | 2–3 | `PARTIAL` — 6 of 8 clause rows demonstrated; two vacuous clauses open (§2.4) |
| M1 | 8–12 | `CRITERION MET` 2026-07-28 — all 8 exit clauses discharged. Still open, and NOT exit clauses: "ships to real users" + six checklist items (§3.3) |
| M2–M9 | 32–50 | `NOT STARTED` — zero demonstrated exit clauses anywhere, though M6 carries a real M1 slice (§5.5) |
| **Remaining** | **32–50**, plus an uncosted M1 tail | The 32–50 is roadmap §6's M2–M9 rows summed exactly (4+4+5+4+5+4+2+4 = 32; 7+7+7+6+7+6+3+7 = 50). It excludes the M1 tail, which the roadmap never costed, and the cross-cutting work in §6.1 (CI, goldens, provenance gate), which the roadmap never costed either because it assumed CI existed from M0 |

### 7.2 What DR-006 changes on its own, before any deferral

These are not deferrals. They are work the internal-tool ruling **removes or shrinks outright**.

| Milestone | Effect of DR-006 | Weeks |
|---|---|---|
| **M6** | The *"Windows OV/EV certificate procurement starts here"* clause is withdrawn. Removes a multi-week **external** dependency and retires `RISK-07`'s mitigation schedule | 0 engineering weeks, but removes the largest calendar risk in the plan |
| **M8** | No certificate purchase, no hardware token, no SmartScreen reputation ramp. Self-signed via `New-SelfSignedCertificate` + `Set-AuthenticodeSignature` + a timestamp server, `.cer` to `LocalMachine\Root` and `\TrustedPublisher` by Group Policy. The licence/EULA question shrinks to an internal-use notice | Perhaps **1 of M8's 2–3** |
| **M9** | *"Three integrators"* becomes three internal users on three real jobs. The judgement the criterion asks for is unchanged; the **recruiting problem** largely disappears | Reduces `RISK-08`, not the weeks |
| **M7** | Unchanged in scope, but the **argument** shifts: WCAG AA and the NVDA matrix are now about the people in this building rather than about an unknown customer base. That is a smaller population and a **known** one — which makes the requirement easier to *scope*, not automatically safe to *cut* | — |

**What DR-006 does *not* change: DR-005.** DR-005 rules that **the sheet set** is a client
deliverable handed to a client, a GC and a job site. DR-006 rules that **the software** is not
commercially distributed. Those are different artefacts. An internal tool used by an integrator
still emits sheets that go to a job site, so **full sheet furniture stays a v1 requirement** and is
not available as a schedule lever (canon §11.5.2/2). Any option below that trims M6's furniture is
an amendment to DR-005, and must say so.

### 7.3 The deferral options, with their costs

Each row states what moving it to v1.1 buys, what it costs the product, and **which ruling would
have to be amended** — because roadmap §8.3 makes scope movement an amendment, not a conversation.

| Option | Buys | Costs the product | Ruling to amend |
|---|---|---|---|
| **A · Defer M5 (validation) entirely to v1.1** | **4–6 weeks**, and unblocks M6 from a three-way join to a two-way one | The tool never tells the user a run is wrong. `CODE-001`/`CODE-002` (NEC 725.136, 800.154) are the two checks DR-002/4 says *"protect a residential user from a red-tagged job"* — deferring them means a design error reaches a job site with the tool silent. Note the countervailing fact: CR-022/G3 means **no rule ever blocks an export**, so the deliverable is unaffected either way | Roadmap §2.1 *Validation*; AC-040 (the 27-rule count); AC-051's fixture gate would move with it |
| **A′ · Defer *most* of M5 — ship tier 1 only** | ~**3–4 weeks** | 8 tier-1 rules including `TOP-001..005` and `PLC-001..003` are already model-illegal (CR-017), so this is closer to "finish what the model implies" than to a feature. Loses the 6 tier-2 and 13 tier-3 rules, which are the ones that catch a *design* mistake rather than an *impossible* one | AC-040's count (27 → 8 in v1, 19 to v1.1) |
| **B · Defer M7 (platform + access) to v1.1** | **4–6 weeks** | Tablet read-only is the clause with the clearest internal value — a reviewer reading an elevation on a job site is a real workflow. The a11y half is the risk: roadmap §4 M7 *Risks* says accessibility work discovered late *"tends to surface structural problems in the canvas surfaces"*, and the outline tree that was supposed to mitigate that **already slipped once** (§3.3). Deferring compounds a debt that is already overdue | AC-056 (mobile read-only on three surfaces); AC-058 D11 (keyboard path, WCAG AA, NVDA matrix) |
| **B′ · Defer only the l10n plumbing and the pseudo-locale** | ~**1 week** | An internal English-only tool arguably never needs it. But AC-058 D12 exists because **retrofitting localisation across a shipped UI is the expensive direction**, and the one-locale plumbing is the cheap direction. This is a G5 bet: cheap now, ruinous later | AC-058 (D12) |
| **C · Defer M9 (beta hardening) to v1.1** | **4–7 weeks** | This is the option that **destroys the evidence**. M9's criterion is the only one that asks whether any of this was true. Under DR-006 the beta population is internal and available, so the recruiting risk that justified deferring it is largely gone — which makes this the **cheapest milestone to keep** and the most expensive to skip | Roadmap §4 M9; measure 8 in docs/00 §9 |
| **D · Defer M4 (device builder) to v1.1** | **5–7 weeks** — the single largest saving available | **Requires superseding DR-003**, which ruled the builder into v1 and explicitly withdrew this as a lever: *"If M4 is ever at risk, the lever is lever 1 or lever 3, not a partial builder."* It also defers **brief requirement 2**, whose builder half is what R2 actually asks for (DR-003/2). Product cost: the long tail is uncoverable — a user who meets a device the 48-template catalog lacks has no path at all | **DR-003.** This is a reversal of a user ruling, not a schedule decision |
| **E · Trim M6's sheet set to what the internal job needs** | Up to ~**3 weeks** of the 5–7 | Requires deciding **which** of the eight missing slots an internal user genuinely needs. `T6.10` pull sheet and `T6.11` termination schedule are the field deliverables; `T0.00`/`T0.01`/`T0.02` are the client-facing ceremony. Cutting the latter is an amendment to DR-005 — and DR-005 was a **user reversal** of the record's own recommendation, made deliberately | **DR-005** |
| **F · Pull the catalog lever — cut the catalog to 40 archetypes at full fidelity** | Removes catalog authoring weeks from M1's tail | **No cost to quality** — the provenance gate sets the count and 40 sourced templates beat 80 guessed ones (RJ-007). The catalog already ships at 48, so this lever is arguably **already pulled**. **Numbering caution:** this is **lever 2** as `docs/09-roadmap.md` §6 now reads, but canon §11.3/5 and §12.6 call it **lever 3** — they were written against an earlier §6 in which lever 2 was *"move M4 after M6"*, the lever DR-003 withdrew. One lever, two numbers; cite it by name | None. It is an available lever, stated in roadmap §6 |
| **G · Pull roadmap lever 1 — ship M1 as an internal v0.9** | Converts remaining invisible work into evidence, immediately | **None** by the roadmap's own reckoning: *"M1 is a real product."* Under DR-006 this is easier than the roadmap assumed — an internal v0.9 needs a self-signed build on a share, not an installer and a certificate. The blocker is not distribution; it is M1's one open exit clause — clause 3's keyboard drill, which needs a person and a stopwatch (§3.4) | None |

### 7.4 The three shapes those options compose into

Not recommendations. Three coherent points on the same axis, so the trade is visible.

| Shape | Contents | Remaining weeks | What you give up |
|---|---|---|---|
| **Full v1 as written** | Everything, DR-006's savings applied | **31–49** | Nothing. The longest calendar |
| **Requirements-complete v1** | All seven brief requirements met (M2, M3, M4, M6 kept); **A′** tier-1-only validation, **B** M7 to v1.1, keep M9 | **24–39** | Rule coverage and accessibility. Confirmed product decision 4 (*all seven requirements in v1*) is **preserved** — which matters, because it is a constraint, not an input (canon §0.2) |
| **Internal-minimum v1** | M2 + M3 + M6, plus **D** (M4 → v1.1), **A**, **B**, keep M9 | **18–30** | Brief requirement 2. **Requires superseding DR-003 and is the only shape that breaks confirmed product decision 4** |

**The arithmetic, shown so it can be checked rather than believed.** Every figure is roadmap §6's
per-milestone weeks, summed over the milestones each shape keeps, with M8 taken as **1–2** rather
than 2–3 per §7.2, and M5 taken as **1–2** under A′. None of the three includes the M1 tail or
§6.1's cross-cutting work, which the roadmap never costed; add those to every row equally.

| Shape | M2 | M3 | M4 | M5 | M6 | M7 | M8 | M9 | Total |
|---|---|---|---|---|---|---|---|---|---|
| Roadmap §6 | 4–7 | 4–7 | 5–7 | 4–6 | 5–7 | 4–6 | 2–3 | 4–7 | 32–50 |
| **Full v1** | 4–7 | 4–7 | 5–7 | 4–6 | 5–7 | 4–6 | **1–2** | 4–7 | **31–49** |
| **Requirements-complete** | 4–7 | 4–7 | 5–7 | **1–2** | 5–7 | **0** | 1–2 | 4–7 | **24–39** |
| **Internal-minimum** | 4–7 | 4–7 | **0** | **0** | 5–7 | **0** | 1–2 | 4–7 | **18–30** |

An earlier draft of this table gave **~31–50 / ~24–39 / ~15–26**. The first and third do not survive
the sum; the internal-minimum shape was understated by three to four weeks, which is the direction
that flatters cutting. Corrected above, with the working shown — a schedule number a reader cannot
re-derive is exactly the kind of claim §0 exists to refuse.

**The one thing every shape shares:** the cross-cutting work in §6.1 — CI, the two failing gates,
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
