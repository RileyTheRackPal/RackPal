# 20 · RackPal user guide

> **This document describes what RackPal DOES. Every other document in `docs/`
> describes what RackPal SHOULD BE.** That distinction is the whole point of
> this file. The design corpus specifies a great deal that is not built, and a
> reader who takes `docs/05` for a feature list will spend an afternoon looking
> for a context menu that does not exist. Nothing is listed here unless it can
> be reached from the running application today.
>
> Written for people trying the software, not for people building it.
> **Audience: AV and low-voltage integrators.** It assumes you know what a rack
> unit, a patch panel, a home run and HDBaseT are, and explains none of them.

---

## 20.1 What it is

**RackPal is CAD-lite for AV and low-voltage work:** to scale where scale earns
its keep, and deliberately representative everywhere else.

You model the job once: the rooms, the racks, the devices, the cables. The rack
elevations, the wiring schematic, the equipment schedule and the PDF sheet set
are all derived from that one model. A device that moves in the rack moves on
the elevation, in the schedule and on every sheet that names it, because there
is only one of it. The elevation and the schedule cannot drift apart the way a
Visio file and a spreadsheet always eventually do.

### Why "lite" is the feature rather than the apology

In this trade a precise drawing is a fiction by the second week on site. A
television shifts because of where the sofa ended up. A run gets re-routed. A
back box moves because the electrician took the stud bay first. Documenting
every one of those to millimetre truth costs far more than it returns, and the
drawing that demanded it gets ignored rather than corrected.

So the precision is spent where it pays and withheld where it does not:

- **Floorplans carry a real-world scale**, calibrated by drawing a line of known
  length across something you can measure, so distance on the plan means
  something.
- **Rack elevations are exact**, because rack units are discrete and a device
  either fits in the space or it does not.
- **Cable footage is a real number you can order from** (§20.5, Schedule), and
  where the software cannot know a length it says so rather than inventing one.
- **Everything else is representative.** Symbol positions, routing paths and
  plan pin placement are there to communicate, not to survey.

### What it is not

It is not a drafting package. There is no DWG, no layer model, no
dimension-driven geometry, and it does not replace the architectural or
electrical set. It is not a proposal or quoting tool, and it talks to no
distributor, PSA or ERP system.

---

## 20.2 Read this before you install anything

RackPal is **pre-release and pre-installer**. It is being handed to you as a
folder, not as a product.

| | |
|---|---|
| Platform | **Windows only.** macOS is planned and not started |
| Delivery | A **portable folder**. There is no installer, no auto-update, no crash reporter |
| Your data | Projects are ordinary files you choose the location of. Nothing is uploaded anywhere. There are no accounts and no telemetry |
| Stability | The core editing paths have been exercised hard. The edges have not |

**§20.8 lists what is not built.** Please read it before you decide something
is broken. A good proportion of "that seems to be missing" is genuinely
missing, and knowing which half you have hit saves everybody's time.

---

## 20.3 Getting it running

You will be given a folder, most likely inside a ZIP.

### If the ZIP arrived over email, Teams, Slack or a browser download

**Unblock the ZIP before you extract it.** Right-click the `.zip` file,
`Properties`, `General`, tick `Unblock`, `OK`. Then extract.

This is not optional and it is not superstition. Windows stamps a
Mark-of-the-Web on anything fetched over HTTP, and modern Explorer copies that
stamp into every file it extracts. If you extract first and unblock afterwards,
every extracted binary keeps the mark and you will get a full-screen SmartScreen
prompt that makes a perfectly well signed application look like malware. The
mark is a function of how the file arrived, not of what is in it, so nothing
about the build can prevent it.

**The same folder copied from a network share or a USB stick carries no mark
and needs no unblocking.**

### Running it

Extract anywhere you can write to, and run `rackpal.exe` from the folder.

It is a portable build, which means it keeps its settings beside itself rather
than in your user profile. You can put it on a stick and carry it between
machines. **Updating is "extract the new folder over the old one"**: your
settings live in a sibling folder and survive that.

### If Windows still says "Unknown publisher"

Two certificate stores have to have the publisher certificate, and having only
one of them produces exactly that message with a valid signature underneath it.
Whoever gave you the build can supply the `.cer` and the two stores it belongs
in. This is a deployment matter rather than something you can fix from inside
the application.

---

## 20.4 Your first fifteen minutes

**Do not start with your own project.** Start with a starter, because you can
tell at a glance whether the application is behaving and you have nothing to
lose if it is not.

### 1. Open a starter

The start screen offers four, a blank project, and a file opener. The starters
are real projects rather than screenshots:

| Starter | What is in it |
|---|---|
| **Home theatre** | 24U rack, 15 rack devices, 14 in the field |
| **Whole house** | 42U rack, 31 rack devices, 27 home runs |
| **Small office** | Two racks, 18U and 6U, front and rear |
| **Apartment** | 9U wall rack, 6 rack devices |

**Whole house** is the one to open if you only open one. It is the only starter
big enough to make the schematic and the schedule interesting, and it is the
one most likely to show you something you disagree with, which is what you are
here for.

### 2. Look at the six views before touching anything

Across the top are six views in three groups. Take one pass through them in
order and do not edit anything yet:

**Site**, **Device Manager** (the project group), **Rack**, **Structured
Wiring**, **Schematic** (the design group), **Schedule** (the deliverable).

`Ctrl+1` is the Rack, `Ctrl+2` the Schematic, `Ctrl+4` the Schedule. (`Ctrl+3`
is deliberately skipped: it is reserved for a Rear Panel view that is not
built, and the digits are view identities rather than positions, so nothing
will shuffle under you when it lands.)

### 3. Move a device in the rack

Go to **Rack**. Click a device. Press the **up arrow**: it moves 1U. Press
`Home`: it drops to its lowest fit. Press `Ctrl+Z`.

Now drag a device onto a space it does not fit. The refusal is the thing to
watch: it should tell you why rather than silently snapping back.

### 4. Draw a cable

Go to **Schematic**. The symbols are laid out automatically.

Click a pin on one device and drag to a pin on another. Two things should
happen: the cable should take the colour of its signal domain, and if the pair
is questionable the gesture should spring back with a chip saying which rule
objected and offering to connect anyway.

**That spring-back is the feature worth attacking.** It is where the product
claims to know something about the trade, so it is where it is most likely to
be wrong and most useful for you to tell us so.

The keyboard route, which is faster once learned: `W` starts a cable from the
pin under the caret, `Tab` cycles the candidate pins, `Enter` commits,
`Shift+Enter` commits and immediately re-arms from the device you just landed
on, so a matrix-to-amplifier run is a rhythm rather than a series of drags.

### 5. Watch the schedule keep up

Go to **Schedule** (`Ctrl+4`). It is derived from the same model, live. Go back
and delete a device, return, and it has changed. You should never have to
regenerate anything.

### 6. Arrange the schematic and see that it stays arranged

Back on the **Schematic**, drag a symbol somewhere you prefer. Add or delete a
device elsewhere.

**The symbols you arranged should not move.** The sheet grows to fit the new
one instead. This is recent work and it is worth a hard look: before it, any
edit re-flowed the whole sheet and threw away your arrangement.

If you want the automatic layout back, **Tidy sheet** at the right-hand end of
the filter bar re-flows everything you have not pinned, and tells you how many
symbols that is before it does it.

### 7. Export

`File`, `Export PDF…`. See §20.7 for exactly which sheets you get, because it
is fewer than the design documents describe.

---

## 20.5 The six views

### Site

Rooms and locations, and the floorplan they sit on. `File`, `Import floorplan…`
takes a PDF and gives you a page picker; one click imports that page as an
underlay. You can then pin racks and devices to where they physically are.

The page picker shows every page with its resolution, and greys out the ones it
cannot use with the reason written on the tile. An 18-sheet permit set will
usually have the first-floor plan at A-2.1, which is page 3, so a first-page
importer would have been useless.

Floorplans can be rotated in quarter turns, which matters more than it sounds:
architectural sets are landscape and a PDF carrying a `/Rotate 90` used to
import sideways.

**Calibrate the plan and it carries a real-world scale.** Draw a line across
something whose length you know, give the length, and distance on that plan
becomes a measurement. That scale is what lets the schedule reason about cable
footage and what lets the length rules catch a run that cannot possibly be
inside its limit. A plan that has not been calibrated is still perfectly usable
for marking where things go; it simply contributes no numbers.

### Device Manager

The catalogue: what devices this project knows about, and the libraries they
came from. You can author a device here, export it as a template, or import
one.

**The device builder is the most finished thing in the application** and the
part most worth an experienced pair of eyes. It has a docked Quick Add bar with
a small typed language for authoring whole banks at once: a 68-port, 6-bank
template was authored in 93 seconds in a timed run, which is the sort of claim
you are welcome to try to beat or to break.

### Rack

The elevation editor. Drag from the palette to place; `/` jumps to the palette
search. Arrow keys nudge by 1U, `Page Up` and `Page Down` by 10U, `Home` and
`End` to the extremes. `Delete` removes. `Ctrl+L` locks a device's position so
that a later shrink or compaction cannot move it. `Ctrl+Alt+N` makes a new
rack, `Ctrl+Alt+U` opens rack settings.

Front and rear are both modelled, and both print.

### Structured Wiring

Home runs, outlets, plates and the structure side of the job: the part that
lives in the walls rather than in the rack. It has a spreadsheet-shaped table,
because the entry path for this data is very often a spreadsheet a contractor
sent you. `Ctrl+V` pastes a block of tab-separated cells straight into it.

### Schematic

One sheet, laid out automatically, showing the devices and the cables between
them.

**The domain filter bar along the top is the main control and not a garnish.**
Sheets get dense fast, so by default the wires are drawn as net labels and you
bring actual drawn wires up by filtering. The digits `1` to `8` solo a domain,
`` ` `` shows everything, and `F` focuses the subgraph of whatever you have
selected. Holding `Alt` over a device shows that device's wires without
changing any mode.

`B` expands or collapses a bank, which matters on a 48-port switch that would
otherwise draw 48 pins.

### Schedule

The equipment schedule, live, derived. This is the deliverable half of the
application.

**Unknown values print as a dash and are counted, never estimated.** If the
schedule cannot tell you the power draw of nine devices, it says so rather than
quietly totalling the ones it knows and presenting that as the answer. When you
are sizing a UPS this is the difference between a number and a guess, and it is
a deliberate rule throughout the product rather than a limitation of the
schedule.

**Cable length resolves per run, through the best source available:**

| Source | What it is |
|---|---|
| Measured cut length | Somebody went and measured it. Beats everything |
| Outlet nominal | The nominal length recorded against that outlet |
| Room estimate | The estimated run length from the rack for that room |
| Plan floor | A straight line on a calibrated plan, printed italic and prefixed `>=` |
| Unknown | Prints a dash, and is counted |

**The plan floor ranks LAST, deliberately, and that is worth understanding
before you judge it.** A straight line between two pins is always shorter than
any real route, because structure decides the route and structure gets
discovered rather than designed. So it is a floor and not an estimate: it can
prove that a run has already blown its length limit, and it can never prove that
one is fine. Ranking it above the room estimate would move every drop on a
calibrated plan out of your purchase quantity and into the unknown column, which
would make **the number you order cable from get worse the more of the job you
planned.** So it sits below, and prints as the bound it is.

---

## 20.6 Keys worth knowing

The complete table is
**[`docs/reference/keymap-windows.md`](reference/keymap-windows.md)**. It is
GENERATED from the application's own keybinding registry and a test fails when
the two disagree, so the copy you are reading cannot drift from the copy the
software dispatches from. Do not edit it by hand.

The handful that pay for themselves immediately:

| Key | Where | What |
|---|---|---|
| `Ctrl+1` / `Ctrl+2` / `Ctrl+4` | Anywhere | Rack, Schematic, Schedule |
| `Ctrl+Z` / `Ctrl+Y` | Anywhere | Undo, redo. 200 steps deep |
| `Ctrl+S` | Anywhere | Save |
| `/` | Rack, Site | Jump to the palette search |
| `Arrow keys` | Rack | Nudge the selection 1U |
| `Ctrl+L` | Rack, Schematic | Lock a position, or pin a symbol |
| `W`, `Tab`, `Enter` | Schematic | Start a cable, pick the far pin, commit |
| `Shift+Enter` | Schematic | Commit and re-arm from the device just reached |
| `1`..`8`, `` ` `` | Schematic | Solo a signal domain, show all |
| `F` | Schematic | Focus the selection's subgraph |
| `Alt` held | Schematic | Show a device's wires without changing mode |
| `Ctrl+Shift+U` | Schematic | Release a pinned symbol back to the layout |
| `F7` / `F8` | Anywhere | Re-check, next issue |

**Undo is document-wide and 200 steps deep.** It covers everything, including
things people do not expect to be undoable such as a floorplan import.

---

## 20.7 What the PDF export actually produces

`File`, `Export PDF…`. **Four kinds of sheet are emitted today:**

| Sheet | When |
|---|---|
| **Device Location Plan** | Automatically, one per floorplan that has at least one device pinned to it |
| **Rack Elevation, Front** | One per rack |
| **Rack Elevation, Rear** | One per rack |
| **Equipment List and Materials** | Always, paginated as needed |

So a two-rack job with one floorplan gives you six sheets.

**Nothing holds the export hostage.** Validation findings do not block it. They
affect whether the drawing can be stamped for construction, and nothing else,
because a heuristic should never stand between you and a deliverable you need
in twenty minutes.

**The interconnect sheets are the notable absence: the schematic you draw on
screen does not print yet.** See below.

---

## 20.8 What is not built

This section is deliberately specific. Everything here is a known gap rather
than a defect, and reporting one as a bug costs you time and tells us nothing.

### Not built at all

- **No installer.** Portable folder only, and no auto-update.
- **No crash reporter.** If it dies, it dies silently, and we only learn about
  it if you tell us.
- **Windows only.** macOS is planned, not begun.
- **No localisation.** English only, and no accessibility work has been done
  beyond keyboard reach.
- **The interconnect sheets do not print.** You can author the schematic in
  full and it will not appear in the PDF. So the cover sheet, the symbol
  legend, the exceptions sheet, the pull sheet, the termination schedule, the
  unused home runs sheet and the pinout details. Eight of the twelve specified
  sheets are absent; §20.7 lists the four you do get.
- **No version number is shown anywhere in the application.** It is stamped
  into every project file you save, but you cannot read it off the screen,
  which is awkward when reporting a problem. Quote the folder you were given.

### Built but narrower than it looks

- **The schematic has no right-click menu.** It is specified in the design
  documents and not built. Everything reachable is on the filter bar or a key.
- **No multi-select drag on the schematic.** You can drag one symbol at a time.
- **No project settings editor.** Several things that are modelled per project,
  including per-family colour overrides, have nowhere to be edited from.
- **One schematic sheet per project**, by design rather than by omission. The
  export partitions it by signal domain; you do not author multiple sheets.
- **`Ctrl+3` does nothing.** Reserved for a Rear Panel view that is v1.1. The
  rear panel prints today; it is just not interactively editable.

### Known rough edges

- **A device that is not there can still be "deleted".** Removing a device that
  does not exist creates an undo entry for a document that did not change. It
  is harmless and it is being fixed.
- **The schematic layout freeze rides on the Schematic view having been
  opened.** If you edit a project without ever looking at the Schematic, there
  is no arrangement yet to preserve, so nothing is recorded. The first edit
  after you have looked at it freezes what you saw.

---

## 20.9 Reporting what you find

What makes a report useful here, in rough order:

1. **The project file**, if you can share it. It is a single file and it
   carries everything, including the version that wrote it.
2. **What you expected**, in trade terms. "The elevation should show the shelf
   occupant" tells us more than "the elevation is wrong".
3. **Whether it is in §20.8.** If you are not sure, say so and report it
   anyway; a gap you hit and could not identify is itself worth knowing about.
4. **Which folder you were given**, since the application does not display its
   own version.

**Disagreements about the trade are the most valuable thing you can send.**
The validation rules encode opinions about what is and is not a sane cable run,
and those opinions came from a small number of people. A rule that fires on
something you do every week, or stays silent on something that would fail an
inspection, is a better find than a crash. Crashes get fixed; a wrong rule gets
shipped to everybody and quietly teaches them the wrong thing.

---

**Related:** [Deployment](14-deployment.md) (how a build is made and handed
over) · [Rack editor](04-rack-editor.md), [Schematic](05-schematic-editor.md),
[Device builder](06-device-builder.md) (design specifications, which describe
more than is built) · [Milestone board](12-milestone-board.md) (what is
demonstrated, and the evidence for it)
