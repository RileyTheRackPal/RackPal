# M4-Q3: the clause 2 drill, a template that reaches a rack

**Board `#251` (M4-Q3), unblocked by `#701` (M4-S). AC-041, CR-050, G4/CR-114. M4's exit criterion,
second clause.**

This is the script and the verdict form for the half of M4's criterion that is not a stopwatch.
Clause 1 is timed and was confirmed on 2026-08-15 at 93 seconds (docs/12 §5.3.7). **Clause 2 is not
timed.** It asks whether the thing a person authored is real: whether it places, and whether the
document tells the truth about what it does not know.

> **Clause 2, verbatim.** *A template saved with exactly three fields plus ports **places into a
> rack** and appears correctly in the equipment list with `—` in every unknown column and an
> accurate unknown count in the rollup.*

**It could not be performed at all until 2026-08-19**, because a template authored in the builder
saved into the project and no surface offered it for placement (docs/12 §5.3.8, closed by §5.3.13).

---

## 0. What "three fields" means, and where the equipment list is

**Two readings had to be settled before this drill could be written**, and both are DR-077
(canon §11.76).

**The three fields are the three `Save` requires**, and they are not chosen by this drill: the
builder enables `[Save]` on a display name, a designator prefix, and a meant occupancy (an RU
height, or the 0U spelling). That is exactly *"three fields plus ports"*. **`Manufacturer` arrives
pre-filled with `Generic` and is not a fourth field you typed**: DR-056 ruled that `Generic` is the
trade's own word for *unspecified*, so it prints as itself and is not an unknown. `Model` is not
pre-filled, by the same ruling, and **it is one of the unknowns this drill goes looking for.**

**The equipment list is a sheet, and that is where you read it** (DR-077 §11.76.4). `T6.30 EQUIPMENT
LIST AND MATERIALS` prints from `File ▸ Export PDF…`. There is no on-screen equipment list, none is
owed, and this step is the criterion's own reading rather than a workaround: M1's exit criterion
already reads the equipment list through an exported PDF in the same words.

---

## 1. Setup, which is not on the clock because nothing here is

1. Launch RackPal. `File ▸ New` for a blank project. It opens with one rack.
2. Nothing else. **Do not** set a project location, a client name or a device location: the blank
   fields are the point, and filling one in removes an unknown this drill is here to see.

---

## 2. Author the template

`Project ▸ New device template…`, then, in the metadata form:

1. **Display name** `Drill Matrix 24x24`
2. **Designator prefix** `DMX`
3. **RU height (front)** `3`

**Type nothing else.** Leave `Model` blank. Leave `Category` blank if the form lets you: an
uncategorised template is a case M4-S built a home for (a trailing `Uncategorised` group), and
leaving it blank exercises it. Leave `Weight` blank.

4. `Ctrl+Enter` to jump to Ports, then type one Quick Add line and press Enter:

```
4 hdmi in
```

**NO `x` AFTER THE NUMBER.** This line read `4x HDMI in` until 2026-08-29 and Quick Add
**refuses** it: quantity is the one positional token in the grammar and `4x` does not parse as
one, so the bar answers *"A command starts with how many ports to add, such as 16."* Nothing was
wrong with the product; the script had invented a form the DSL never had. It is corrected here and
`clause2_drill_expectations_test.dart` now asserts both the working line and the refusal, so this
cannot drift again without a red test.

5. `[Save & Close]`.

**Sanity check before going on**: the footer said how many ports it made. If it says anything other
than 4, stop and record that: it is a finding worth more than the drill.

---

## 3. Place it, which is the first half of the clause

1. Look at the palette. **A group titled `This project` is pinned at the top**, above the nine
   catalog categories, and `Drill Matrix 24x24` is in it, badged `PROJECT`.
2. Scroll down. It is **also** filed under its own category, or under `Uncategorised` if you left
   the category blank. Both rows are the same template; that is DR-077 §11.76.2 and is deliberate.
3. Type `/`, type `Drill`, press `Enter`.
   - It should appear **once** in the filtered list, still badged. A row appearing twice in a search
     is a defect (§11.76.2), not a feature.
   - The status line should read `Placed DMX-1 at RK-1 U1-U3, front.`

**If instead it reads `Unknown catalog template "…"`, stop.** That sentence means the palette and
the placement machinery are looking at two different lists, which is the exact defect M4-S closed.

4. `Ctrl+S`. Save the project somewhere you can find it.

---

## 4. Read the sheet, which is the second half

`File ▸ Export PDF…`, save it, open it, and go to the sheet titled **`EQUIPMENT LIST AND
MATERIALS`** (`T6.30`).

Find the row whose `DESIGNATOR` is `DMX-1` and check it against this table. **The thirteen columns
are in the sheet's own order.**

| Column | What it must print | Why |
|---|---|---|
| `QTY` | `1` | One row per device instance in this build; the quantity collapse is deliberately not built |
| `DESIGNATOR` | `DMX-1` | Allocated from the prefix you typed |
| `MANUFACTURER` | `Generic` | **Not a dash.** DR-056: the trade's word for unspecified, pre-filled and meant |
| `MODEL` | `—` | You left it blank, and blank is unknown (G4) |
| `DESCRIPTION` | `Drill Matrix 24x24` | The device's name, falling back to the template's |
| `RU` | `3U · 1–3` | An en dash in the range, and the U it actually landed on |
| `RACK` | `RK-1` | |
| `LOCATION` | `—` | You set none |
| `FACE` | `FRONT` | **Not a dash and not blank.** A mounted device's face is a fact the model states |
| `MASS` | `—` | You left the weight blank |
| `DRAW` | `—` | Never `0`: a zero would read as a measurement |
| `LIFECYCLE` | `NEW` | |
| `NOTES` | **nothing at all** | **Not a dash**, and this is the one column that differs from its neighbours. `_scheduleRow` builds every other nullable cell with `?? kUnknownCell` and builds this one with `?? ''`, because a missing note is a KNOWN absence: nobody wrote one. A dash would claim the sheet does not know whether a note exists. This row said `—` until 2026-08-29 and would have been recorded as a refutation of correct behaviour |

Then find the **subtotal band** below the rack's rows. It reads, verbatim:

```
RK-1 SUBTOTAL   1 DEVICE   — (1 unknown)   — (1 unknown)
```

**That line is the clause's second half and it is the whole of G4 in one sentence.** The mass column
has no total, because there is nothing to total; it says how many contributors could supply nothing.
A `0.0 lb` there would be a fabricated measurement, and an empty cell would read as "nobody filled
this in".

---

## 5. What would refute it

Read this before you start, not after.

| Symptom | What it would mean |
|---|---|
| The template is not in the palette at all | The palette is not reading the document (§11.76.1) |
| It is in the palette and placing it refuses with `Unknown catalog template` | The palette and placement are on different shelves |
| It appears **twice** in the `/` search results | The pinned group leaked into the search state (§11.76.2) |
| A blank `Category` template appears nowhere | The `Uncategorised` group is missing (§11.76.2) |
| `MANUFACTURER` prints `—` | DR-056's pre-fill is gone; the template was saved with no manufacturer |
| `MASS` prints `0.0` or is blank | G4 is broken on the sheet: a fabricated measurement, or an unknown wearing an empty cell |
| The subtotal prints a mass with no unknown count | CR-114's rollup rule is broken: a total that silently skips its unknowns |
| Two rows named `Drill Matrix 24x24` in the palette after a second `Save` | The session forgot the id it minted and made a second template (§11.76.3) |

---

## 6. The verdict form

**THE EXPECTATION TABLE ABOVE IS ASSERTED IN CODE**, by
`packages/rackpal_core/test/sheet/clause2_drill_expectations_test.dart`, which runs the same
commands this script tells you to type and pins every cell of the row plus the subtotal band
verbatim. It exists because two steps of this script had rotted unnoticed between being written
on 2026-08-19 and being run: a Quick Add line the parser refuses, and a NOTES cell that would
have been recorded as a refutation of correct behaviour.

**It does not discharge the clause and must not be read as doing so.** The clause asks whether a
template a PERSON authored in the builder reaches a rack and prints correctly. The test drives
core and cannot see the builder, the palette, the export dialog or the PDF. It makes this drill
worth running; it does not replace it. M1's clause 3 is the precedent, where 2,206 green tests sat
over two defects one run found.

Fill this in while it is fresh, then paste it into docs/12 §5.3.13.

```
Date:
Build (commit):
Ports the footer reported after Quick Add:
Status line on placement (verbatim):
Palette: pinned group present?           yes / no
Palette: also filed under a category?    yes / no  (which:            )
Search showed the row exactly once?      yes / no
T6.30 row matched section 4's table?     yes / no  (deviations:                     )
Subtotal line (verbatim):
VERDICT:  CONFIRMED / REFUTED
If refuted, the first thing that was wrong:
```

**A refuted run is worth more than a confirmed one and must not be tidied.** M1's drill was refuted
on its first run by two defects 2,206 tests could not see, and M4-Q1's found a keystroke the
specification promised and nobody had built. Record what happened, not what was supposed to.
