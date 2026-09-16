# M3-G: the 60-drop rough-in drill

**Board #163, #164, #165. AC-018. M3's exit criterion.**

This is the script, the conditions form and the verdict form for a drill **no agent can run**. It is
a timed act by a person. Everything an agent could do to it has been done: the census that found
three absences before the stopwatch (docs/12 §5.2), DR-040 and the four M3-K tasks that closed them,
and the verifier below that reads the saved file so a verdict is a measurement rather than an
impression.

Read [§4](#4-what-would-refute-it) before you start, not after.

> **THE SAVED FILE IS THE VERDICT. DO NOT CLOSE THE APP UNTIL §3 HAS RUN.**
>
> §3 reads the file, so a run that ends without one produced a stopwatch reading and
> nothing that can be checked. **A clean shutdown deletes the recovery snapshot**
> (`session_controller.dart:694`, on every clean exit), so quitting normally is not a
> second chance: the only survivable states are "still open" and "crashed".
>
> This is not hypothetical. It is what happened on the first run of this drill, and
> §4.1 records it.

---

## 1. Setup, which is NOT on the clock

Do all of this first. It is the state a real job is in when somebody sits down to enter a rough-in,
and timing it would be timing the wrong thing.

1. Launch RackPal. `File ▸ New` for a blank project.
2. The **`Site`** tab, the first one. Create **one telecom room** and set three fields on it:
   - Name `Media Closet`, Code `MC`
   - **Floor** `1`, **Space** `A`
   These two feed `{FLOOR}` and `{SPACE}`. Without them every rack label comes out blank and the
   drill is refuted on clause 2 (this is exactly what the census found).
3. Still on `Site`, create the **ten rooms** in §2's table, each with its Code. Codes are what
   make the by-code line 16% cheaper; the drill uses full names, so the codes are for the label
   only.
4. On the Rack tab, place a **48-port patch panel**, or two 24-port panels. Give it the designator
   **`PP-1`** (a second would be `PP-2`). Set its location to `Media Closet`.
5. `Project ▸ Structured wiring…` to create the Structure device if the editor asks.
6. `File ▸ Save As`, somewhere you can find it. Save again at the end.

**Sanity check before the clock:** type one line, `Attic: 1x Cat6 @panel=PP-1`, press Enter, and
confirm the new row shows a `RACK LBL` of `1A-PP-101`. If it does not, stop and record why: that is
a finding worth more than the drill. Undo it (`Ctrl+Z`) before starting.

---

## 2. The script, which IS on the clock

Sixty drops across ten rooms. **Start a stopwatch, type these ten lines, press Enter after each.**
Do not correct typos by mouse. Do not stop to admire anything.

```
Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4 @panel=PP-1
Kitchen: 2x Cat6, 1x RG6, 1x 16/4, 1x 22/4 @panel=PP-1
Office: 4x Cat6, 1x RG6, 1x 22/4 @panel=PP-1
Primary Bedroom: 2x Cat6, 2x RG6, 1x 16/4, 1x 22/4 @panel=PP-1
Bedroom 2: 2x Cat6, 1x RG6, 1x 22/4 @panel=PP-1
Bedroom 3: 2x Cat6, 1x RG6
Attic: 5x Cat6
Exterior: 6x Cat6
Garage: 4x Cat6, 2x RG6, 1x 22/4 @panel=PP-1
Media Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4 @panel=PP-1
```

**Then, in this order, and do not close the app until step 4 is done:**

1. **Stop the stopwatch.** Write the number down now, on paper, before anything else.
2. **`Ctrl+S`.** This is the artifact. Without it there is no verdict, only an anecdote.
3. Fill in §5's form while it is fresh.
4. **Run §3's verifier** and paste its output into the form.

*Step 2 used to be half of a sentence attached to step 1 (`"Stop the stopwatch. Then
`Ctrl+S`."`), which put the one irreversible action of the whole drill at the moment
of maximum relief, in the smallest type on the page. It was missed on the first run
and the run was lost. Numbering it is the whole fix.*

| Room | Code | Drops | Landed |
|---|---|---|---|
| Living Room | LR | 9 | yes |
| Kitchen | KIT | 5 | yes |
| Office | OFF | 6 | yes |
| Primary Bedroom | MBR | 6 | yes |
| Bedroom 2 | BR2 | 4 | yes |
| Bedroom 3 | BR3 | 3 | **no** |
| Attic | ATT | 5 | **no** |
| Exterior | EXT | 6 | **no** |
| Garage | GAR | 7 | yes |
| Media Room | MED | 9 | yes |
| **Total** | | **60** | **46 landed, 14 open** |

**The counts in that table are the ones the verifier checks, and the first draft of this script had
them wrong.** It left twelve drops open, not fourteen, and the verifier said so on the run that
existed to test the verifier. Recorded because it is the cheap version of the same mistake: an
arithmetic slip in a drill script costs a person fifteen minutes if nothing checks it first.

**This exact script is gated.** `drop_line_planner_test.dart`'s *"THE WHOLE DRILL, MINUS THE HUMAN"*
runs all ten lines through the real planner and asserts AC-018's shape at the artifact: 60 drops, 14
open, 46 landed, every label unique as a SET, and no unbound drop carrying a rack label. If this
document and that test drift apart, a person spends fifteen minutes finding out.

**The cost, measured then pinned in that order.** The ten lines are **433 keystrokes, 7.22 per
drop**. The pre-landing figure was 349 (5.82), so `@panel=` on seven of ten lines buys forty-six
landings for **84 keystrokes, about 1.8 each**, against roughly seven for a hand-typed `RACK LBL`
cell. That ratio is the entire argument for DR-040 §11.39.2 clause 2 being a modifier rather than a
column.

**The three unlanded lines are AC-018's fourteen and they are deliberate.** Bedroom 3, the Attic and
the Exterior are the rooms a real job leaves for later: nobody has decided what lands where. They
carry no `@panel=`, so they stay `OpenEndpoint` and carry no rack label, and every one of them must
still appear on the Pull Sheet with a `W` number. That is the clause, and it is the one M1's drill
teaches us to check rather than assume.

---

## 3. The verdict, measured

From the repo root, against the file you saved:

```bash
cd apps/rackpal && dart run tool/verify_drill.dart "C:\path\to\your\drill.rppj"
```

It prints one line per AC-018 clause with `PASS` or `FAIL` and the number it measured, then an
overall verdict. It does not time you: §4's form does that.

---

## 4. What would refute it

**M1's drill was refuted, the remedy did not discharge it, and the first re-run failed AGAIN for
reasons nothing predicted and 2206 passing tests could not see** (docs/12 §3.5). Both defects were
found by a person opening the app. So:

- **Write the verdict down either way.** #165: *"M1's refutation is the most useful record in the
  board precisely because it was written as a refutation rather than as a to-do."*
- **A refutation is not a failure of the drill.** It is the drill working.
- If the loop breaks, **record what you were doing on the keystroke it broke**, not what you think
  caused it. The M1 post-mortem's value is entirely in that level of detail.

### 4.1 Run 1, 2026-08-13: UNVERIFIABLE, and the procedure is what failed

**Elapsed 7 minutes, no file saved, verifier never ran. Not `MET` and not `REFUTED`: there is no
measurement, so there is no verdict.** Recorded in full because §4's own rule does not exempt the
runs that are embarrassing, and because the failure is in this document rather than in the operator.

| | |
|---|---|
| Who ran it | The tool's author |
| Practice | **Less rehearsed than M1's drill**, stated by the operator unprompted |
| Machine | A laptop, the one intended for eventual field use, not the development machine |
| Elapsed | **7 minutes**, reported as "total"; which of §5's two rows that is was not captured |
| Artifact | **None.** The app was closed without `Ctrl+S` |
| Verifier | Could not run |
| Verdict | **UNVERIFIABLE** |

**What is worth keeping from it.** Seven minutes against a fifteen-minute ceiling is 7 seconds per
drop, under half the budget, on a machine that is not the development box and by an operator who had
deliberately not rehearsed. As an *observation* that is encouraging. It is **not evidence**, because
nothing checked that sixty drops with the right labels and the right fourteen open ends came out the
other end, and the clause about entry speed is the only one of five a stopwatch alone can speak to.

**The operator's stated caveat cuts the opposite way to the one intended.** Being under-rehearsed
makes an entry-speed number more conservative, not less. **The confound that matters is the one §5
names and the run did not mention**: this is the tool's author, who knew `@panel=PP-1` without
looking it up and was reading from a script rather than inventing drops. Seven minutes is a floor
for the population, not a median.

**The finding, which is the actual product of this run.** The single irreversible step of the whole
drill was the tail of a sentence, positioned at the moment of maximum relief, after "Stop the
stopwatch". A person who has just finished a timed exercise stops. **A procedure that loses its
entire artifact to one skipped keystroke is a fragile procedure**, and no amount of care from the
operator fixes that: it is fixed by numbering the step and by saying that closing the app is
irreversible, both of which §2 and the banner now do. A clean shutdown deletes the recovery snapshot
(`session_controller.dart:694`), so there was nothing to recover by design and correctly so, since
CR-096's rule that a recovery file is never a durable archive is worth more than this drill.

**This is exactly what #163 asked for.** *"Run the drill EARLY, on a rough build ... a drill run on a
rough build finds them while the design can still move."* It found a defect on the first run. The
defect was in the script rather than in the software, which is a cheaper place to find one.

**Run 2 carries a condition run 1 did not**: the operator is now rehearsed, and the unrehearsed
7-minute observation cannot be recreated. Record that in §5 rather than quietly comparing the two
numbers as though they were taken under the same conditions.

## 5. The operator's conditions (#164)

**Fifteen minutes for the tool's author is not fifteen minutes for an installer.** A pass with none
of this recorded is unreproducible and a fail is unattributable, which is what makes a re-run cost as
much as the first run. Fill this in **before** you look at the clock, so the number does not colour
the answers.

| | |
|---|---|
| Who ran it | |
| How much of the tool they had seen before | |
| Reading from this script, or inventing drops | |
| Input device (keyboard only? mouse used, and for what?) | |
| Screen size and window size | |
| Where they stopped to think, and for roughly how long | |
| Anything they had to look up | |
| Typos made, and how they were corrected | |
| Elapsed time, setup EXCLUDED | |
| Elapsed time, setup INCLUDED | |
| Verifier output | |
| **Verdict** | `MET` / `REFUTED` |

## 6. What this drill does NOT claim

- **"Prints" is M6's** (#574, DR-027). This drill produces rows, not a sheet. A Pull Sheet PDF does
  not exist and its absence is not a refutation of anything here.
- **The Pull Sheet's initial boxes and page layout are M6's** for the same reason.
- **`LNK-020` is M5's.** After DR-040 it can finally say something true (`14 links have unbound
  endpoints`), and it still is not built.
