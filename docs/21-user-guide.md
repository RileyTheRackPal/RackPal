# 21 · RackPal user guide

> **This document describes what RackPal DOES. Every other document in `docs/`
> describes what RackPal SHOULD BE.** That distinction is the whole point of
> this file. The design corpus specifies a great deal that is not built, and a
> reader who takes `docs/05` for a feature list will spend an afternoon looking
> for a context menu that does not exist. Nothing is listed here unless it can
> be reached from the running application today.
>
> Written for people doing a job with the software, not for people building it.
> **Audience: AV and low-voltage integrators.** It assumes you know what a rack
> unit, a patch panel, a home run and HDBaseT are, and explains none of them.
>
> **How to read it.** §21.4 is a fifteen-minute tour of a sample project. §21.5
> is the manual: one chapter per view, in the order a job moves through them,
> each written as the tasks you do there rather than as a list of controls.
> Read §21.5.1 before you start a real project; read the rest as you reach each
> view.

---

## 21.1 What it is

**RackPal is CAD-lite for AV and low-voltage work:** to scale where scale earns
its keep, and deliberately representative everywhere else.

You model the job once: the rooms, the racks, the devices, the cables. The rack
elevations, the wiring schematic, the cable schedule and the PDF sheet set
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
- **Cable footage is a real number you can order from** (§21.5.7), and where
  the software cannot know a length it says so rather than inventing one.
- **Everything else is representative.** Symbol positions, routing paths and
  plan pin placement are there to communicate, not to survey.

### What it is not

It is not a drafting package. There is no DWG, no layer model, no
dimension-driven geometry, and it does not replace the architectural or
electrical set. It is not a proposal or quoting tool, and it talks to no
distributor, PSA or ERP system.

---

## 21.2 Read this before you install anything

RackPal is **pre-release and pre-installer**. It is being handed to you as a
folder, not as a product.

| | |
|---|---|
| Platform | **Windows only.** macOS is planned and not started |
| Delivery | A **portable folder**. There is no installer, no auto-update, no crash reporter |
| Your data | Projects are ordinary files you choose the location of. Nothing is uploaded anywhere. There are no accounts and no telemetry |
| Licence | **AGPLv3 or later**, with the device catalog under CC0. The output exception, under which the drawings you produce are your own work, is drafted and **not yet in force** pending legal review. `Help` ▸ `About RackPal…` says so too |
| Stability | The core editing paths have been exercised hard. The edges have not |

**§21.8 lists what is not built.** Please read it before you decide something
is broken. A good proportion of "that seems to be missing" is genuinely
missing, and knowing which half you have hit saves everybody's time.

---

## 21.3 Getting it running

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
`Help` ▸ `About RackPal…` tells you which build you have, and is worth
noting before you start so a report can carry it.

It is a portable build, which means it keeps its settings beside itself rather
than in your user profile. You can put it on a stick and carry it between
machines. **Updating is "extract the new folder over the old one"**: your
settings live in a sibling folder and survive that.

If that folder cannot be written to (a read-only stick, a locked-down profile),
RackPal still runs, and a banner says that autosave and the recent-files list
are off for the session.

### If Windows still says "Unknown publisher"

Two certificate stores have to have the publisher certificate, and having only
one of them produces exactly that message with a valid signature underneath it.
Whoever gave you the build can supply the `.cer` and the two stores it belongs
in. This is a deployment matter rather than something you can fix from inside
the application.

---

## 21.4 Your first fifteen minutes

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
one most likely to show you something you disagree with.

A starter opens as a new, unsaved project. Nothing you do to it touches the
copy inside the application, and `Save As` is how you keep it.

### 2. Look at the six views before touching anything

Across the top are six views in three groups. Take one pass through them in
order and do not edit anything yet:

**Site**, **Device Manager** (the project group), **Rack**, **Structured
Wiring**, **Schematic** (the design group), **Schedule** (the deliverable).

`Ctrl+1` is the Rack, `Ctrl+2` the Schematic, `Ctrl+4` the Schedule. (`Ctrl+3`
is deliberately skipped: it is reserved for a Rear Panel view that is not
built, and the digits are view identities rather than positions, so nothing
will shuffle under you when it lands.) The other three views are reached by
clicking their tab.

### 3. Move a device in the rack

Go to **Rack**. Click a device. Press the **up arrow**: it moves 1U. Press
`Home`: it drops to its lowest fit. Press `Ctrl+Z`.

Now drag a device onto a space it does not fit. The refusal is the thing to
watch: it tells you why rather than silently snapping back.

### 4. Draw a cable

Go to **Schematic**. The symbols are laid out automatically.

Press on a pin of one device and drag to a pin on another. Two things should
happen: the cable takes the colour of its signal domain, and if the pair is
questionable the gesture springs back with a card saying which rule objected
and offering to connect anyway.

**That spring-back is where the product claims to know something about the
trade**, so it is where it is most likely to be wrong and most useful for you
to tell us so.

The keyboard route, which is faster once learned: arrow keys put a caret on a
pin, `W` starts a cable from it, `Tab` cycles the candidate pins, `Enter`
commits, and `Shift+Enter` commits and immediately re-arms from the device you
just landed on, so a matrix-to-amplifier run is a rhythm rather than a series
of drags.

### 5. Watch the schedule keep up

Go to **Schedule** (`Ctrl+4`). It is the **cable** schedule, derived from the
same model, live. Go back to the Schematic, delete the cable you drew, return,
and its row has gone. You never regenerate anything.

### 6. Arrange the schematic and see that it stays arranged

Back on the **Schematic**, drag a symbol somewhere you prefer. Add or delete a
device elsewhere.

**The symbols you arranged do not move.** The sheet grows to fit the new one
instead. If you want the automatic layout back, **Tidy sheet** at the
right-hand end of the filter bar re-flows everything you have not pinned, and
tells you how many symbols that is before it does it.

### 7. Export

`File` ▸ `Export PDF…`. See §21.7 for exactly which sheets you get, because it
is fewer than the design documents describe.

---

## 21.5 Running a job, view by view

The view strip is in the order a job usually moves through it, and this
section follows the same order. You will go back and forth; nothing forces a
sequence, and every view reads the same model, so work done in one is already
in all the others.

| Step | View | What you do there | What it gives you |
|---|---|---|---|
| 0 | `File` menu | Start the project, save it, set the project conventions | A file, designators and units that suit the job |
| 1 | **Site** | Name the rooms, import and calibrate floorplans | Where cable goes, and a plan that measures |
| 2 | **Device Manager** | Find the equipment, author anything missing | The devices this job can place |
| 3 | **Rack** | Build the racks and place the equipment | Front and rear elevations, weight and power rollups |
| 4 | **Structured Wiring** | Enter home runs, outlets, plates and pathways | The in-wall half of the job, landed at the rack |
| 1 again | **Site** | Pin the rack, outlets and field devices; outline the rooms | The Device Location Plan, a run length per room, length floors |
| 5 | **Schematic** | Draw the cables between devices | The interconnect, checked as you draw it |
| 6 | **Schedule** | Read the pull sheet and the termination schedule | Footage you can order from |
| 7 | Validation drawer | Clear or acknowledge what the checks found | A job you can stand behind |
| 8 | `File` ▸ `Export PDF…` | Export the sheet set | The PDF |

### 21.5.1 Before you start: files, settings and safety nets

#### Starting a project

The start screen offers the four starters (§21.4), **Blank project** (one empty
42U rack and the full device catalogue) and **Open a project…**. `File` ▸
`New` (`Ctrl+N`) gets you back to a blank project later.

**Save As straight away** (`Ctrl+Shift+S`). A new project, and a starter, is
not saved anywhere until you name it. A project is **one `.rppj` file** that
carries everything, including imported floorplans. The window title carries a
`*` while there is unsaved work.

`File` ▸ `Open Recent` lists recent projects and says which are not currently
reachable (a disconnected share, a stick that is not plugged in).

#### What protects unsaved work

- **Autosave never writes over your file.** Only `Save` and `Save As` write the
  `.rppj`. Every 30 seconds while you work, and whenever the window loses
  focus, RackPal writes a recovery snapshot into its own folder instead.
- **If RackPal closes unexpectedly**, the next start says *Unsaved work was
  found* and offers **Recover**, **Keep for later** or **Discard**. Recover
  opens the snapshot as unsaved work; save it to keep it.
- **Closing or opening another project with unsaved work** asks first, and says
  how many changes are at stake.
- **A file saved by a newer version of RackPal** opens read-only, under a
  banner that cannot be dismissed. You can still edit and export; `Save a
  copy…` keeps your changes in a new file and leaves the original untouched.

#### Undo

**Undo is document-wide.** `Ctrl+Z` undoes, `Ctrl+Y` or `Ctrl+Shift+Z` redoes,
from any view, and the `Edit` menu names the step it is about to undo. It
covers everything, including things people do not expect to be undoable, such
as a floorplan import or a whole CSV import. The depth defaults to 200 steps;
`Edit` ▸ `Preferences…` sets it anywhere from 50 to 1000.

While the Device Builder is showing (§21.5.3), `Ctrl+Z` and the `Edit` menu
act on the template you are editing instead, and hand back to the project the
moment you leave it.

#### Sheet set: the title block your PDF prints

`File` ▸ `Sheet set…` holds what the drawing set prints about the job rather than
how it is modelled. **Title block**: project name and number, drawing number, the
client and site address, your company, contact and licence number, and who drew,
checked and approved the set. These print in the title block on every sheet
(approved by prints on the cover). **Cover**: one paragraph saying what the job is.
**Legend**: the abbreviations and general notes (§21.7). A field saves when you
leave it or press Enter, and each change can be undone from `Edit`. Leave a field
empty and its line is left off the sheet; the project name is the exception, and
clearing it is refused, because it heads every sheet.

**Your logo.** Under the company lines, `Choose logo…` takes a PNG, JPEG, PDF or
SVG. A PDF gives its first page, and a transparent background becomes white. The
preview shows it as it will print, at the top right of the title block on every
sheet except the A-size equipment list, which has no room. `Replace logo…` and
`Remove logo` do what they say, and both can be undone. Your company's name and
contact still print as text, so a photocopy that loses the logo keeps the firm.
An SVG that uses effects the PDF cannot draw may preview wrong: check it before
you issue.

#### Project settings: set these before you place anything

`File` ▸ `Project settings…` holds the conventions that travel with the file.
Every change is undoable. **Set them first**, because designators are allocated
as you place devices and draw cables, and a pattern changed afterwards applies
to what you create next.

| Setting | What it decides |
|---|---|
| Display units | Imperial or metric, everywhere, including what a bare number in a length cell means |
| Device designator, Designator separator, Designator padding | How placed devices are numbered: `MTX-1`, `MTX1`, `MTX-01` |
| Port designator, Cable designator, Net name | The patterns for ports (`J{PORT_SEQ:2}`), cables (`W{SEQ:3}`) and net labels |
| Outlet label, field end / rack end | What gets printed on the wall plate, and what the rack end is called |
| Default rack height, Default RU numbering, Mirror rear elevations by default | What a new rack starts with. Existing racks keep what they were made with |
| Default line voltage, Wiring standard, Default network media | Job-wide defaults. One cable can take its own wiring standard in the WIRING column (§21.5.5) |
| Cable waste factor | The margin added to each cable type's footage in the Schedule's takeoff (§21.5.7). No length is ever inflated |
| Sheet numbering | What each title block prints as the sheet's number: **Simple** prints `SHEET 5 OF 14`, **National CAD Standard** prints the sheet's id, `T2.01`. Every sheet keeps its id either way, and the drawing index and every `SEE SHEET` reference use the id. A project made from the Small Office starter starts on the National CAD Standard; the rest start on Simple |
| Designator block size | Reserves blocks of numbers for commercial port numbering |

Two more sections live in the same dialog:

- **Signal colours.** Colour comes from a signal's *domain* (digital video,
  audio, network and so on). Here you can override the colour of one
  *family* inside a domain for this project; `Clear` returns it to the domain
  colour.
- **Rule severities.** What a check counts as in this project, or off. **Every
  override needs a written reason**, because it is a decision somebody reading
  the drawings is entitled to see. See §21.5.8.

`Edit` ▸ `Preferences…` is the other settings dialog, and it holds what stays on
**this computer** rather than in the file: the undo depth, and the rack presets
you have saved (rename, delete, and which of the shipped presets the Preset
list shows).

---

### 21.5.2 Site: rooms, floorplans and where things are

**What it is for.** The rooms are the project's vocabulary: every home run goes
to a room, the pull sheet sorts by room, and outlet labels are built from room
codes. The floorplans are optional, and when you have them they turn "Living
Room" into a place with a measured distance from the rack.

**What is on screen.**

- **Left rail.** The floorplan pages, when the project has any, above the room
  tree. `Add room` sits under the tree.
- **Centre.** The open floorplan, and under it a strip of everything not yet
  pinned on it. With no floorplan it says how to import one.
- **Right.** The selected room: its details, and its outline on the open plan.
- The device palette runs down the far left, as on the Rack view.

#### Build the room list

1. Click **Add room**. With a room selected, the button reads **Add room under
   selection** and nests the new one inside it, so `House` ▸ `Level 1` ▸
   `Living Room` is three clicks.
2. Fill in the room on the right:

   | Field | What it feeds |
   |---|---|
   | Name | Everything that names the room |
   | Code | `{ROOM_ABBR}` in labels |
   | Floor | `{FLOOR}` in labels. Blank is unknown |
   | Space | `{SPACE}` in labels. A telecom room is often `1A` |
   | Run length from rack | One figure per room, in whole feet or metres. Blank is unknown. The helper line says whether you typed it or the plan worked it out |
   | Kind | A label only. Any kind may sit under any other |
   | Inside | Moves the room somewhere else in the tree |

3. **Delete location** removes a room and anything nested in it, after saying
   how many items lose their room. Nothing else is deleted: cables, racks,
   outlets and floorplans stay, with no room recorded.

You can do this with no floorplan at all. Plenty of jobs never have one, and
nothing downstream requires it.

#### Import a floorplan

1. `File` ▸ `Import floorplan…` takes a PNG, a JPEG, or one page of a PDF.
2. **A PDF opens a page picker** showing every page with its size and
   resolution. Pages that cannot be used are greyed out with the reason written
   on the tile. An 18-sheet permit set usually has the first-floor plan several
   pages in, so pick the page, not the file.
3. A **New floorplan page** box asks for a name and which room or floor it
   **Shows** (or none, for a site plan). If a room is selected in the tree when
   you import, that is the suggestion. `Esc` accepts the suggestion; `Ctrl+Z`
   removes the page.

#### Manage the pages

Click a page in the rail to open it. The open page's row carries its controls:

- **Edit plan…** (the pencil) renames it or changes what it shows.
- **Calibrate…** (below).
- **Rotate left / right**, also `Ctrl+Shift+-` and `Ctrl+Shift+=`, in quarter
  turns. Architectural sets are usually landscape, and a PDF that declares its
  own rotation imports the way it declares.
- **Remove…** says how many pins and room outlines go with it first.
- Drag the grip to reorder pages.

Pan with the scroll wheel or a middle-button drag, zoom with `Ctrl+scroll`, and
use the zoom readout in the corner to fit the plan or return to 100%.

#### Calibrate the plan

A plan that has not been calibrated is still perfectly usable for marking where
things go; it simply contributes no numbers. Calibrating it is what lets the
schedule reason about footage.

1. On the open page, click **Calibrate…**.
2. Click one end of a distance you know, then the other end.
3. Type the real distance **with its unit**: `3' 6"` or `2.4 m`. A bare number
   is refused, because 36 inches and 36 feet differ by twelve.

A dimensioned wall is the best thing to measure; failing that, a door is almost
always 32 or 36 inches. The row then reads `Calibrated`, followed by what the
calibration can measure (or the one thing still stopping it, usually `no rack
pinned`). **Recalibrate…** replaces it. `Esc` abandons a pick.

#### Pin things on the plan

Come back here once the racks, outlets and field devices exist (steps 3 and
4). A pinned item appears on the Device Location Plan sheet, and **a pinned
rack is what every length on that plan is measured from**, so pin the rack
first.

- **Drag a device from the palette onto the plan.** That places the device and
  pins it in one step, and one `Ctrl+Z` undoes both. A double-click in the
  palette is refused here, because a plan has no default spot.
- **Drag from the strip under the plan.** It lists what exists and is not
  pinned yet: racks, outlets and devices that do not sit in a rack.
- **From the Structured Wiring table**, a row's **Pin on plan** switches to
  this view with the outlet in hand: click where it goes. `Esc` drops it.
- Drag a pin to move it. Click a pin to select it, or drag across empty plan
  to select a group. **`Delete` takes the selected pins off the plan; the
  devices, racks and outlets stay in the project.**

#### Outline the rooms

An outline is what turns a room into a run length. The figure is worked out,
and kept up to date, whenever all of these are true:

- the plan is calibrated;
- the room has at least one home run landed in a rack (§21.5.5);
- that rack is pinned **on the same plan** as the outline.

The order you do them in does not matter: the moment the last one is in place,
the figure appears, and moving the rack or reshaping the room moves it. Until
then the room's helper line says which of the three is missing.

1. Select the room in the tree. The right-hand panel shows it **On** the open
   plan, with **Draw…**.
2. Click each corner of the room. Right-click takes back the last corner.
   Click the first corner again to close the shape. `Esc` stops.
3. **Reshape…** lets you drag corners to correct it (nothing else on the plan
   responds while you do). **Redraw…** starts again. **Clear** removes the
   outline.

The room's **Run length from rack** then reads the straight line from the rack
to the room's farthest corner, and its helper line says it was worked out from
the plan. It adds no margin; the margin is yours to add when you quote.

- **A figure you typed yourself is never overwritten.** Clear the field to hand
  the room back to the plan.
- **If a plan-derived figure's inputs go away** (the rack is unpinned, the
  outline cleared), the figure is cleared too rather than left standing as a
  guess.
- **A basement head end cannot measure to a room on Level 1.** Two pages are
  unrelated pictures, and nothing records how they line up. The helper line
  says so; type those rooms' run lengths instead.

---

### 21.5.3 Device Manager: the equipment this job can use

**What it is for.** Every device you place is made from a **template**: its
size, its ports, its power and its look. The Device Manager is where you find
templates, and where you author the ones that do not exist yet.

It has two screens: the **browser**, which it opens on, and the **builder**,
which it switches to when you create or edit a template.

#### Find a device

- **Search** matches the name, the model, and the port types, so `hdbaset`
  finds an extender whose name does not say so.
- **Filters** narrow by what a device has or is (HDMI, PoE, passthrough panel,
  shelf or drawer, used in this project, unsaved drafts) and by **Source**:
  authored in this project, the shipped catalogue, or an imported library.
- Switch between **Grid** and **List**. The star adds a device to favourites,
  which the palette gathers under **Favourites**.
- Each entry says how many times it is used in this project.

You do not have to visit this view to place a shipped device: the palette on the
Rack and Site views searches the same list.

#### Author a device that is not there

1. Click **New device template…**.
2. Fill in **Identity**: Display name, Manufacturer (`Generic` is filled in, and
   is the trade's own word for unspecified), Model, **Designator prefix** (two
   to four letters: `MTX` gives `MTX-1`, `MTX-2`), then **Size and mounting**:
   how it mounts, **RU height (front)** and width. The rear height copies the
   front until you type in it (put `0` for a front-only device), and
   **Occupies** is worked out for you. Gear that takes no rack units (on a
   shelf, 0U, hosted in another device, side mounted, in furniture, not in a
   rack) asks for no height at all.
   Category is optional and suggests a prefix and an elevation mark; Signal
   domain is optional and colours the device on a floorplan.
3. **Save** now if you like. **A name, a prefix and a height is a finished
   template**: it will place and print like any other. `Save` stays disabled,
   with a tooltip saying why, until those three exist.
4. Add the ports (next section), then the rest as you have the information.

The builder's sections:

| Section | What it holds |
|---|---|
| Identity | Name, manufacturer, model, prefix, category, domain, tags, and **Size and mounting**: how it mounts, front and rear height, width |
| Ports | Every connector, in a grid, with previews of the elevation, the schematic symbol and the rear panel. **Passthrough** on its toolbar makes a patch panel, and **Pair front to rear** then pairs it |
| Panel | Where the cutouts sit on the panel. Derived from connector footprints; **Customize panel layout** lets you move them, align and distribute them, and **Reset to auto** puts them back |
| Physical | Depth, chassis width, weight, clearances, thermal class and the container flag |
| Power | Nameplate, typical and standby watts, volts, VA, power factor, PoE budget, inlet. **Nothing is guessed**: typical draw is never worked out from the nameplate |
| Appearance | Accent colour and the mark drawn on the elevation, so devices stay tellable apart on a greyscale print |

**Leave a field blank when you do not know it.** Blank prints as a dash and is
counted as unknown in every rollup; a made-up figure is worse than a blank one.

The footer has **Save**, **Save & Close** (back to the browser) and **Close**.
**Close asks first when there are unsaved changes**: Save, Don't Save or
Cancel, the same question RackPal asks when you close a project. The builder
has its own undo and redo, in the footer and on `Ctrl+Z`, for as long as it
is open.

#### Add ports

**Quick Add** is the bar across the top of the Ports section and the fastest
route. Type one line and press `Enter`; focus stays in the bar for the next.

```
16 hdmi in "HDMI IN {n:2}"
16 rj45 hdbaset out
24 rj45 pass both
2 xlr out @Line Outs
```

A line is a quantity and a port type, then any of: a direction (`in`, `out`,
`bi`, `bus`, `pass`), a face (`front`, `rear`, `both`; rear if you say
nothing), a quoted label pattern, and `@bank`. The order of everything after
the quantity does not matter. The line above the grid previews what it will
create before you press `Enter`, and underlines anything it cannot read.
`Right arrow` accepts a suggestion.

The grid's toolbar has three generators for the common shapes:

- **Matrix I/O…**: inputs, outputs, mirrored outputs, per-output audio
  de-embed and IR, control ports and an AC inlet, in one dialog.
- **Switch ports…**: access ports with speed and PoE class, uplinks,
  management, console and power supplies.
- **Paste…**: copy a block of cells in a spreadsheet, **including its header
  row**, and map its columns to port fields.

Then **Add port**, **Delete**, **Pair front to rear** (for a passthrough
panel), **Columns** and **Show/Hide previews**. The grid is keyboard-driven
the way a spreadsheet is:

| Key | What it does |
|---|---|
| `Ctrl+D` / `Ctrl+Shift+D` | Fill down / fill a series down the selection |
| `Ctrl+C` / `Ctrl+V` | Copy rows out (with a header row) / paste cells in |
| `Alt+Up` / `Alt+Down` | Move the selected rows within their bank |
| `Ctrl+J` | Duplicate the selected rows |
| `Ctrl+R` | Renumber the selected rows from a pattern |
| `Ctrl+M` | Move the selected rows to another bank |
| `Ctrl+T` | Change the type of the selected rows |
| `Ctrl+H` | Find and replace in the selected rows |
| `Ctrl+G` / `Ctrl+Shift+G` | Group rows into a multi-conductor port set / ungroup them |

Ports live in **banks** (`HDMI Outputs`, abbreviated `OUT`), which is what the
schematic collapses a 48-port switch into. Each bank's menu renames it or
mirrors it.

#### Edit an existing template

Open it from the browser, or right-click a placed device on the Rack view and
choose **Edit the template…**. Saving writes a **new version**, and a chip
beside `Save` says whether the change is **Safe**, **Additive** or
**Breaking** for devices already placed from it. If you have an unsaved draft
open, RackPal takes you to it rather than throwing it away.

**Remove from this project…** in the browser removes a template and every
device placed from it, after counting them and the cables they take with them.

#### Share templates between jobs

- `File` ▸ `Export device template…` writes one template as a `.rpdx` file.
  `Import device template…` reads one in, and if the project already has one
  by that name, asks whether to import it separately or as a new version.
- `File` ▸ `Export device library…` packs this project's own templates (all, or
  the ones you choose) into a named `.rpda` library. **Import device
  library…** copies a library onto this computer's library shelf, and its
  devices appear in every project's palette. Placing one copies it into the
  project, so the project file never depends on the library being there.

---

### 21.5.4 Rack: building the elevations

**What it is for.** The racks, what is in them, and where. The elevations here
are exact: a device either fits or it does not, and the Rack view says which
and why.

**What is on screen.**

- **Left: the palette.** Search it with `/`. It lists this project's devices,
  your favourites, the shipped catalogue and any imported libraries, by
  category.
- **Centre: the rack.** Across the top: the zoom readout (left), the rack
  header (centre) and the **Front / Rear** switch (right). The header shows the
  rack's designator and name, a `-` / `+` height stepper, a rack switcher when
  there is more than one rack, and a `⋮` menu. Under it, the **metrics row**.
  A help line along the bottom turns into a status line whenever something has
  just happened.
- **Right: the inspector.** The selected device or devices, or the rack itself.
- **Bottom: the validation drawer** (§21.5.8).

If the project has no rack, the view says so and offers **New rack…**.

#### Create and set up racks

1. **New rack…** is in the header's `⋮` menu, and on `Ctrl+Alt+N`. It asks for
   a Name, a **Preset** and a Height, and says what designator the rack will
   get.
2. **Rack settings** open in the inspector when you click the rack header or
   press `Ctrl+Alt+U`:

   | Group | Fields |
   |---|---|
   | Identity | Name, Designator |
   | Form factor | Height, width (EIA 19", EIA 23", ETSI, custom), usable depth, rail type, weight capacity, own weight, swing frame and hinge side, ground bar |
   | Display | Mirror rear elevation |
   | Location | Which room it is in; floor or wall mount |
   | RU numbering | Bottom-up or top-down |
   | Preset | Apply a preset's rails, depth, capacity and swing-frame settings |
   | 0U channels | Vertical channels for PDUs and cable managers (below) |
   | Circuits | Listed, not yet created here (§21.8) |

3. **Save as preset…** in the inspector keeps a rack's form factor for reuse
   on this computer. Name and location are not saved with it.
4. With more than one rack, the switcher icon in the header picks which one is
   on screen.

#### Place equipment

Three ways, and they all end the same: the new device selected, and a status
line saying where it went (`Placed AMP-1 at RK-1 U12-U13, front.`).

- **Drag a palette row onto the rails.** A ghost follows the pointer, snaps to
  whole units and shows the U range it would take. Over a space it cannot
  take, it turns red and says why (`Occupied by SW-1 (U4-U5)`, or `Needs 2U,
  only 1U free at top`), and releasing there places nothing. Releasing outside
  the rack also places nothing.
- **Double-click a palette row, or select it and press `Enter`.** With nothing
  selected in the rack, it goes at the **caret**: the highlighted U, which the
  arrow keys move when nothing is selected. If that U cannot take it, you are
  told why and nothing is placed. With a device selected, it goes in the
  lowest space that fits. `Esc` clears the selection and brings the caret
  back.
- **Type in the palette search and press `Enter`**, repeatedly. The caret
  advances past each device, so filling a rack is a typing loop: `/`, `amp`,
  `Enter`, `/`, `switch`, `Enter`. Inside the loop, a device the caret's U
  cannot take goes in the lowest space that fits instead, and the status line
  says both.

A device from an imported library is copied into the project on first use, and
the status line says so once.

**Devices that do not sit in a rack** (speakers, displays, keypads: anything
whose template says it is not rack-mounted) are marked `Field` in the palette.
They cannot be dragged onto rails; **double-click** places them in the project
with no rack position. Pin them on the Site plan, and wire them on the
Schematic.

#### Select, move and remove

- Click to select; `Ctrl+click` adds or removes; drag across empty space to
  select a group.
- Drag a selected device to move it. The same ghost and refusals apply.
- **Arrow keys** nudge the selection 1U; `Page Up` / `Page Down` 10U; `Home` /
  `End` to its lowest or highest fit.
- **`Ctrl+L` locks** the selection, so a later shrink or compaction cannot move
  it. The inspector has the same switch.
- **`Delete`** removes the selection. If cables would go with it, a dialog
  counts them first.
- `Esc` cancels whatever is in flight, then clears the selection.
- Pan with the scroll wheel or a middle-button drag, zoom with `Ctrl+scroll`.

#### Change the rack's height, or close the gaps

- The header's **`-` / `+`** step 1U, and repeat while held. You can also drag
  the rack's top edge, or type a height in Rack settings.
- **Shrinking below a device** opens a dialog instead of evicting it. It lists
  who would lose their position and offers the ways out: trim from the top or
  the bottom, **compact first, then shrink**, or keep the rack at the smallest
  height that fits.
- **Compact Down** and **Compact Up** in the `⋮` menu close the gaps on the
  face you are looking at. They show a preview first; **Apply** (`Enter`) or
  **Cancel** (`Esc`). Locked devices stay put.

#### Front and rear

The **Front / Rear** switch flips the face. Each face shows what occupies it,
which the template decides: a patch panel takes both faces, a rear lacing bar
only the rear. The metrics row follows the face on screen. Both faces print.

#### 0U channels

In Rack settings, **0U channels** ▸ **Add channel…** asks for a side (front or
rear, left or right), a start and end U, and an optional name. A channel's
span cannot be changed afterwards; remove it and add it again. **Add a device
to this channel** lists the project's 0U templates. **A 0U device is listed
under its channel and is not drawn in the elevation yet.**

#### The inspector, for a device

- **With several devices selected:** their lifecycle status, width position
  (for half-width gear) and lock, set for all of them at once.
- **With one selected**, as well:
  - **This device only**: mass, typical draw, body depth and accent colour.
    Each shows what the template says, and lets this one device say something
    else, or say it is unknown.
  - **Ports**: corrections for this device only (connector, signal family,
    label, and a 70 V tap setting where that applies), without touching the
    template.
  - **Mount note**, free text for the installer (`AV closet, top shelf,
    sideways`).

**Right-click a device** for the three ways to change it: **Edit this device
only** (the inspector, above), **Edit the template…** (every device placed from
it, in the Device Manager) and **Fork to a new template** (this device gets a
template of its own).

A device with unconnected ports carries a small **ports chip**. Clicking it
switches to the Schematic with that device selected.

#### The metrics row

Under the header, for the face on screen: **rack units used** of the capacity,
**total weight**, **total draw** in VA, and power **outlets** used of those
provided. **A device that does not state a figure is counted, never guessed**:
a small superscript says how many devices a total could not include, and
pointing at it names the gap, rather than the row quietly totalling the ones
it knows. When you are sizing a UPS that is the difference between a
number and a guess.

---

### 21.5.5 Structured Wiring: the part in the walls

**What it is for.** Home runs, outlets, wall plates and pathways: everything
between the rack and the rooms. It is a table first, because the entry path
for this data is very often a spreadsheet a contractor sent you.

The home runs belong to a **Structure device**, which stands for the panel or
enclosure they run back to (`STR-1 · Media Panel`). You do not create it by
hand: the first drop you enter creates one.

**What is on screen.**

- **Header:** a Structure picker (only when the project has more than one),
  **Import CSV…**, **Manage media types…**, **Connector words…**, and a `⋮`
  menu holding **Remove this Structure…**.
- **Tabs:** **Table**, **Matrix**, **Outlets**, **Pathways**.
- **Left:** the rooms, read-only here (rooms are named on the Site view), with
  a drop count each.
- **The entry line**, then a filter bar (room, media, **Unconnected only**, and
  **Columns**), then the table, then a footer with counts and **Add drop** /
  **Add outlet**.

#### Enter the drops

Type one room per line into the entry line and press `Enter`:

```
Living Room: 4x Cat6, 2x RG6
Attic: 3x Cat6 @service=wifi-ap
Exterior: 6x Cat6 @service=camera @status=planned
Kitchen: 2x Cat6, 1x RG6 @outlet="KIT-TV-1"
```

Each line creates the drops, their outlet, and **their field and rack labels,
already allocated**. A room that does not exist yet is created with them, and
the line says so before you press `Enter`. The first line in a project creates
the Structure device.

The optional `@` modifiers:

| Modifier | What it does |
|---|---|
| `@service=` | What the drop is for (`wifi-ap`, `camera`, `tv`) |
| `@signal=` | The signal the run carries |
| `@status=` | Where it is in the job (`planned`, and so on) |
| `@outlet=` | Put the drops on one named outlet, creating it or joining it |
| `@pathway=` | The conduit or tray they run through |
| `@panel=` | The patch panel the rack end lands on |
| `@nobox` | No outlet at all, for a ceiling speaker or anything else with no low-voltage box |

A conduit typed on the line (`Living Room: 1x ENT`) becomes a **pathway**
rather than a cable.

#### Edit the table

The default columns are FIELD LABEL, RACK LBL, OUTLET, MEDIA, SERVICE,
PATHWAY, FIELD TERM, RACK TERM and ROUGH-IN. **Columns** adds the rest,
including the as-built set: ROUTED and **CUT** length, TERM. LEN, SPLICES,
TEST, CERT ID, INSTALLED BY, TERMINATED, JACKET and PULLED colour, CLASS,
**LANDS ON**, PORT, WIRING and NOTES.

- Click a cell and type, or pick. **Length cells take a whole number** of feet
  (or metres, on a metric project) and nothing else, because that is how the
  column prints. An empty cell means unknown.
- **`Ctrl+D`** fills the cell from the row above. **`Ctrl+V`** pastes a block
  of tab-separated cells from a spreadsheet, starting at the cell you are in.
  A paste fills existing rows and never creates drops: add the drops first.
- **Tick rows** to set an as-built column on all of them at once, or to copy
  the field termination to the rack end (`Rack term: same as field`).
- A label you typed stays yours when the drop moves; clear the cell to let
  RackPal name it again.
- A row's menu has **Pin on plan** (§21.5.2).

#### Land the runs at the rack

A home run is not finished until its rack end lands on something: a patch
panel port, a switch port. Three ways:

- **LANDS ON** (from **Columns**): pick a panel and the drop is punched down on
  its next free position. **PORT** overrides which position.
- **`@panel=`** on the entry line lands a whole line as it is created.
- **On the Schematic**, drag the run's loose end onto a free jack (§21.5.6).

The Schematic's status strip counts the home runs not yet landed.

#### The Matrix tab

Rooms down the side, media across the top, a count in each cell. **Typing a
count creates or removes drops** to match, as one undo step. It refuses to
remove a run that is already patched into a panel, and says which.

#### The Outlets tab

One card per outlet: its plate, gang by gang, and what sits in each cell.

- **Arrange** sizes the plate from the drops that land there, replacing the
  whole plate. **+ Add gang** adds one by hand; each gang picks its strap size
  or a brush or bull-nose pass-through.
- Click a cell to choose a keystone for a run, a **blank insert** (which goes
  on the materials list), or nothing.
- The card says when a drop's field termination is unrecorded, and when a
  plate is short of cells.
- **Remove this plate and its cables** removes an outlet, after counting the
  cables that go with it.

**Add outlet**, in the footer, adds an outlet from a recipe: pick the room,
pick a recipe (TV location, AP, Keypad, Ceiling speaker pair, Camera, Data
only, or a TIA-570-D grade under **Standards presets**), read the labels it
will create, and press **Add outlet** as many times as you need. **Done**
closes it.

#### The Pathways tab

Conduits, J-hooks and trays: kind, length and the runs that go through each.
The header counts pathways, lengths still unknown and runs through no pathway.
**Add pathway** adds one; the delete button on a row says how many runs lose
their recorded route. Runs are assigned to a pathway with `@pathway=` when they
are entered, or through a CSV import.

#### Import a spreadsheet

**Import CSV…** reads a contractor's drop list.

1. Choose **One row per drop** or **One row per room** (a row with counts).
2. Map the columns. A column you do not map can be kept as extra data.
3. Read the preview: how many drops it will create, update, leave unchanged and
   skip. If it changes drops already in the project, it asks first.
4. **Import**. The whole import is one undo step.

An unrecognised media value becomes a new media type rather than a rejected
row, so a typo in row 40 becomes a second cable type. **Manage media types…**
is beside the import button for exactly that: **Edit** a type's name and trade
tag, or **Merge into…** another type, which repoints every use and keeps the
spelling so the same sheet re-imports cleanly. **Connector words…** teaches the
project the words your crew uses for connectors, and Quick Add, pasted columns
and the entry line all accept them.

**Remove this Structure…** removes the panel, every plate on it and every home
run out of it, after counting all three.

---

### 21.5.6 Schematic: drawing the cables

**What it is for.** The interconnect: which port on which device connects to
which. It is also where the product checks your work as you draw.

There is **one sheet per project**, laid out automatically from the model. A
device appears when its template has at least one port; blank panels, vents
and shelves do not.

**What is on screen.**

- **The filter bar:** one chip per signal domain, each with its cable count,
  then **All**, **None**, and **Tidy sheet** at the right-hand end.
- **The sheet.**
- **The status strip** along the bottom: how many devices are drawn, and
  what cannot be (devices with no ports, home runs not landed at the rack,
  cables that could not be routed, domains hidden by the filter).

#### Read the sheet

**By default a cable is drawn as a pair of net labels**, one at each end,
rather than a wire. Sheets get dense fast, and a sheet of forty crossing wires
is not a drawing anybody can read. Bring the wires up when you need them:

| To see | Do this |
|---|---|
| One domain's wires | Click its chip, or press `1` to `8` |
| Several domains | `Ctrl+click` chips to add or remove them |
| Everything | **All**, or `` ` `` |
| One device's wires, briefly | Hold `Alt` and point at it |
| What the selection connects to | Press `F` to focus on it; `F` again to leave |
| A collapsed bank's pins | Click the bank's pin, or put the caret on it and press `B` |

A 48-port switch is drawn with its banks collapsed, so it does not draw 48
pins until you ask it to.

#### Draw a cable with the mouse

Press on a pin and drag. The pins that can take this cable light up as
candidates; release on one. Releasing anywhere else cancels, and so does `Esc`.

#### Draw a cable with the keyboard

1. Arrow keys put a caret on a pin.
2. **`W`** starts a cable from it.
3. **`Tab`** / **`Shift+Tab`** cycle the candidates, or arrow to one.
4. **`Enter`** commits. **`Shift+Enter`** commits and immediately starts the
   next cable from the device you just reached, so a chain of sources, matrix
   and amplifier is one rhythm.
5. `Esc` cancels.

The status line says what is in hand and how many candidates there are at every
step.

#### When a cable springs back

If a connection is questionable, the cable does not simply fail. It springs
back and a card appears beside the pin: the rule, what it objects to, and why
it matters, in trade terms.

- **A remedy button**, when the rule has one, fixes the cause: inserting an
  HDBaseT receiver between an HDBaseT output and a switch port, declaring an
  adapter on the cable, or inserting a converter. It places what it needs and
  says what it did.
- **Pick a different port** puts you back to aiming, with the cable still in
  hand.
- **Connect anyway** makes the cable as drawn. The rule then shows as a finding
  in the validation drawer (§21.5.8), where you can acknowledge it with a
  reason.
- **Why?** opens what the rule checks and why it exists.

**The rules encode opinions**, and they came from a small number of people. If
one fires on something you do every week, that is exactly what we want to hear
(§21.9).

#### Draw many cables at once

1. **Shift+click** a second pin in the same bank to select the run between
   them (or `Shift+Up` / `Shift+Down` from the caret).
2. Drag the selection onto another bank. Each jack pairs with a free one, and
   the status line says how many connected and how many found no partner.
3. Release, or press `Enter`. It is one undo step.

Ports declared as a **set** in their template (a balanced audio pair, a
speaker pair) draw as **one cable with several conductors** instead.

#### Select, move and delete cables

- **Click a net label** to select its cable. **`Delete`** removes it, and the
  status line says `Ctrl+Z` puts it back.
- **Drag a net label** onto a free jack to move that end of the cable. For a
  home run whose rack end has not landed, this is how you land it.

#### Arrange the sheet

- **Drag a symbol** to move it. Moving it **pins** it: the automatic layout
  leaves it where you put it from then on, and a new device takes a free place
  rather than shoving it aside.
- With a symbol selected and no caret showing, the arrow keys nudge it one grid
  step, and a run of presses is one undo step.
- **`Ctrl+L`** pins the selection where it is; **`Ctrl+Shift+U`** releases it
  back to the layout.
- **Tidy sheet** re-lays-out every unpinned symbol, after saying how many.
  Pinned symbols stay put.

---

### 21.5.7 Schedule: footage you can order from

**What it is for.** The cable schedule: one row per cable, derived live from the
model. **It is read-only.** You change what it says by changing the model, in
the view the schedule points you back to.

**What is on screen.**

- **Two presets** of one schedule, on a switch at the top:
  - **Pull Sheet**: field cables grouped by room, then pathway, with a footage
    subtotal per room. What the crew pulls from.
  - **Termination Schedule**: every cable landing in a rack, by rack, panel and
    port. What the tech terminates from.
- **Sort**: cable ID, room then pathway, rack then panel then port, domain,
  from-device, longest first, or rough-in status.
- **Show jumpers and power cords**, off by default, and the button says how
  many it is hiding.
- **A summary line**: rows, **total footage**, and how much of it is
  estimated, bound or unknown, with counts for anything else worth your
  attention (a disputed cable class, a jacket pulled in the wrong colour).
- **The takeoff**: *Field cable to order, with 10% waste*, then one line per
  cable type with its known footage and the same figure with your waste
  factor added (`Cat6A 1240 ft, 1364 ft with waste`). It counts field cable
  only, whichever preset is showing, because jumpers and cords are bought
  differently. A line some runs could not contribute to says how many are
  missing. There is deliberately **no grand total**: feet of Cat6 plus feet of
  RG6 is not something anybody orders. Set the percentage in `File` ▸
  `Project settings...`.

If the document has no cables, the Schedule says so and says where cables are
drawn. That is a statement about the file, not an error.

#### Where each length comes from

**Unknown values print as a dash and are counted, never estimated.** For
length, every run resolves through the best source available:

| Source | What it is | Where you set it |
|---|---|---|
| Measured cut length | Somebody measured it. Beats everything | **CUT** column, Structured Wiring table |
| Outlet nominal | A nominal length recorded against that outlet | Carried by imported and sample projects; there is no field to type it in this build |
| Room estimate | The room's run length from the rack | **Run length from rack** on the Site view, typed or worked out from an outline |
| Plan floor | A straight line on a calibrated plan, printed italic and prefixed `>=` | Calibrate the plan and pin both ends |
| Unknown | Prints a dash, and is counted | |

**The plan floor ranks last, deliberately.** A straight line between two pins
is always shorter than any real route, because structure decides the route and
structure gets discovered rather than designed. So it is a floor and not an
estimate: it can prove that a run has already blown its length limit, and it
can never prove that one is fine. Ranking it above the room estimate would move
every drop on a calibrated plan out of your purchase quantity and into the
unknown column, which would make **the number you order cable from get worse
the more of the job you planned.** So it sits below, and prints as the bound it
is.

**To tighten the total**, work up the ladder: give every room a run length
(outline it, or type it), and record cut lengths as the job is pulled.

**The Pull Sheet and Termination Schedule do not print yet** (§21.8). What is on
screen is what you have.

---

### 21.5.8 Checking the job: the validation drawer

**What it is for.** RackPal runs its checks continuously: power, placement,
cabling, labelling. What they find is listed in the **validation drawer**, the
band along the bottom of the Rack view.

**Findings never block anything.** They do not stop an export, a save or an
edit. A heuristic should never stand between you and a deliverable you need in
twenty minutes.

#### Read the drawer

- **Collapsed**, it reads `No issues`, or counts errors, warnings and
  advisories. It opens by itself the first time an error appears in a session,
  and you can drag it taller.
- **Re-check** runs the checks again.
- **Group by** Severity, Rule or Location. The severity chips filter the list;
  **Acknowledged** shows or hides what you have already dealt with.
- **Click a finding** to select the device it is about.
- **`F8`** and **`Shift+F8`** step through every finding, from any view, and
  take you to the view where it can be fixed, with its subject selected:

  | The finding is about | `F8` takes you to |
  |---|---|
  | A device in a rack, or a rack | **Rack**, switched to that rack |
  | A device not in a rack, or a cable | **Schematic** |
  | A floorplan | **Site**, with that plan open |
  | Anything else (a net, a circuit) | **Rack**, where the drawer is |

  A notice names the rule and where you are in the list (`LEN-001 (3 of
  39)`). A cable whose rack end has not landed yet has no end on the sheet,
  and the Schematic says so instead of selecting it.
- **`F7`** re-checks from any view and says the counts.

#### Deal with a finding

Each row offers what applies to it:

- **A remedy**, when there is one. The missing-outlets finding, for example,
  offers to add a power strip on a shelf or a vertical rack PDU.
- **Acknowledge**: **Just this one**, or **Every** such finding in the project,
  with a reason (required for the project-wide choice), and what to treat it as
  from then on, down to hidden from the list. **Withdraw** takes an
  acknowledgement back.
- **Why?** explains the rule, and **Verify against** names the standard or
  source it comes from.

To change what a rule counts as for the whole project, use **Rule severities**
in `File` ▸ `Project settings…` (§21.5.1). It needs a reason too.

---

## 21.6 Keys worth knowing

The complete table is
**[`docs/reference/keymap-windows.md`](reference/keymap-windows.md)**. It is
GENERATED from the application's own keybinding registry and a test fails when
the two disagree, so the copy you are reading cannot drift from the copy the
software dispatches from. Do not edit it by hand.

The handful that pay for themselves immediately:

| Key | Where | What |
|---|---|---|
| `Ctrl+1` / `Ctrl+2` / `Ctrl+4` | Anywhere | Rack, Schematic, Schedule |
| `Ctrl+Z` / `Ctrl+Y` | Anywhere | Undo, redo |
| `Ctrl+S` / `Ctrl+Shift+S` | Anywhere | Save, Save As |
| `F7` / `F8` / `Shift+F8` | Anywhere | Re-check, next issue, previous issue. `F8` goes to the view that can fix it |
| `/` | Rack, Site | Jump to the palette search |
| Arrow keys | Rack | Nudge the selection 1U, or move the caret |
| `Ctrl+L` | Rack, Schematic | Lock a position, or pin a symbol |
| `Ctrl+Alt+N` / `Ctrl+Alt+U` | Rack | New rack, rack settings |
| `W`, `Tab`, `Enter` | Schematic | Start a cable, pick the far pin, commit |
| `Shift+Enter` | Schematic | Commit and re-arm from the device just reached |
| `1`..`8`, `` ` `` | Schematic | Solo a signal domain, show all |
| `F` | Schematic | Focus the selection's subgraph |
| `Alt` held | Schematic | Show a device's wires without changing mode |
| `Ctrl+Shift+U` | Schematic | Release a pinned symbol back to the layout |
| `Ctrl+D` / `Ctrl+V` | Structured Wiring, Device Builder | Fill down, paste cells |

**Undo is document-wide and 200 steps deep by default** (§21.5.1). It covers
everything, including things people do not expect to be undoable such as a
floorplan import.

---

## 21.7 What the PDF export actually produces

`File` ▸ `Export PDF…`. **These sheets are emitted today:**

| Sheet | When |
|---|---|
| **Cover** (`T0.00`) | Always, first. The project name, client and site, drawing number, revision and issue date, your scope paragraph, your company, and who drew, checked and approved the set, all from `File` ▸ `Sheet set…`. Along the foot, one line per rack: its size, how many active devices (blanks, vents, shelves and other passives are not counted), the rack units used on the front and the rear, weight, VA and BTU/hr, with how many devices are missing a value. Down the right, the drawing index: every sheet in the file, with both its number in the set and its sheet number, and a schedule that runs to several pages as one line. A very large set flows into two or three narrower columns |
| **Exceptions and Acknowledgements** (`T0.02`) | Always, third, on as many pages as it needs. First, any rule you have switched off or muted for the whole project, with its reason. Then every open finding from the validation drawer, errors first, each with its rule, where it is, and what it says. Then every finding you acknowledged, with your reason, who and when, including any acknowledgement whose problem has since gone away, marked so. A section with nothing in it says so in words |
| **Symbol Legend** (`T0.01`) | Always, second. Every cable type in colour and in greyscale side by side (the ten named types every time, then any other type your cables use); the device marks and plan markers in your set; an annotated device block; the border and hatch conventions; your ID formats worked through; abbreviations and general notes, which you can change in `File` ▸ `Sheet set…`. Every other sheet says `SYMBOL LEGEND: SEE SHEET T0.01` |
| **Device Location Plan** | Automatically, one per floorplan that has at least one item pinned to it |
| **Rack Elevation, Front** | One per rack |
| **Rack Elevation, Rear** | One per rack |
| **Equipment List and Materials** | Always, paginated as needed. One row per device, grouped by rack. Blanks, vents, shelves and other passives are not equipment rows: they are listed once each by item under **MATERIALS** at the end, with how many and which racks they are in. Each rack's subtotal still includes them, and says so |

**Your own abbreviations and notes.** `File` ▸ `Sheet set…` lists the legend's
abbreviations and general notes as rows. Change a row, add one with `Add
abbreviation` or `Add note`, or remove one with its `×`; each change can be undone
from `Edit`. Until you change anything the legend prints RackPal's standard list,
and `Restore defaults` puts it back. The signal tag prefixes (`AUD`, `NET` and so
on) always follow your abbreviations and are not edited here. A long note wraps
on the sheet.

**Zones on the drawings.** Floor plans and rack elevations carry a lettered and numbered border, so someone on the phone can say "the patch panel at B2". Zone A1 is the lower-right corner, numbers run right to left and letters bottom to top, so a large sheet folded into a binder still shows them. The cover, legend, exceptions and equipment list have a plain border.

So a two-rack job with one floorplan gives you at least nine sheets, more if the exceptions or the equipment list run to a second page. The status line says
how many sheets were written and how large the file is.

**A project with no rack cannot be exported**: there is no elevation to draw
and no equipment to list, and RackPal says so rather than writing an empty
file.

**Nothing else holds the export hostage.** Validation findings do not block it.
They affect whether the drawing can be stamped for construction, and nothing
else.

**Issuing for construction.** `File` ▸ `Export for construction…` is the same
export with every sheet stamped `ISSUED FOR CONSTRUCTION` and the date, in a box
above the revision history. It stamps only when the validation drawer has no
open error. If it has any, you still get the file, unstamped, and the status
line says how many errors are open and which sheet lists them. Acknowledging an
error counts as dealing with it. Nothing is remembered: the next `Export PDF…`
is unstamped.

**The interconnect sheets are the notable absence: the schematic you draw on
screen does not print yet**, and neither do the schedules. See below.

---

## 21.8 What is not built

This section is deliberately specific. Everything here is a known gap rather
than a defect, and reporting one as a bug costs you time and tells us nothing.

### Not built at all

- **No installer.** Portable folder only, and no auto-update.
- **No crash reporter.** If it dies, it dies silently, and we only learn about
  it if you tell us. (Your work is still protected: §21.5.1.)
- **Windows only.** macOS is planned, not begun.
- **No localisation.** English only, and no accessibility work has been done
  beyond keyboard reach.
- **The interconnect sheets do not print.** You can author the schematic in
  full and it will not appear in the PDF. Nor do the pull sheet, the
  termination schedule, the unused home runs sheet or the pinout details;
  §21.7 lists the sheets you do get.
- **No DXF or DWG export.** DXF is planned for a later release.
- **No Rear Panel view.** `Ctrl+3` does nothing; it is reserved for it. The
  rear panel prints on the rear elevation today; it is just not interactively
  editable.
- **No staging area.** Dragging a device out of the rack and releasing it
  anywhere else places nothing, and the shrink dialog's option to move devices
  aside says it is not available.
- **Circuits cannot be created.** The rack inspector lists a rack's circuits
  and says creation arrives with the power stage.

### Built but narrower than it looks

- **The schematic has no right-click menu, and the rack has one only on a
  device.** An empty rack unit has no menu. Everything else is on a bar, a menu
  or a key.
- **No multi-select drag on the schematic.** You can drag one symbol at a time;
  the arrow keys nudge a selection of several.
- **One schematic sheet per project**, by design rather than by omission. The
  export will partition it by signal domain; you do not author multiple sheets.
- **A 0U device is not drawn on the elevation.** It is listed under its channel
  in the rack inspector.
- **An outlet's nominal run length cannot be typed.** It is read when a file
  carries one, and ranks in the length ladder (§21.5.7).
- **A run's pathway is set when the run is entered** (`@pathway=`, or a CSV
  column), not afterwards in the table.
- **A device outside a rack has no room field.** Its place is its pin on the
  Site plan.

### Known rough edges

- **A device that is not there can still be "deleted".** Removing a device that
  does not exist creates an undo entry for a document that did not change. It
  is harmless and it is being fixed.
- **The schematic layout freeze rides on the Schematic view having been
  opened.** If you edit a project without ever looking at the Schematic, there
  is no arrangement yet to preserve, so nothing is recorded. The first edit
  after you have looked at it freezes what you saw.
- **Some on-screen text still speaks the design documents' dialect**: a helper
  line that cites a rule number, a Device Builder note saying a shared library
  is not built when `File` ▸ `Import device library…` is. Where the screen and
  this guide disagree, this guide was checked against the running code.

---

## 21.9 Reporting what you find

What makes a report useful here, in rough order:

1. **The project file**, if you can share it. It is a single file and it
   carries everything, including the version that wrote it.
2. **What you expected**, in trade terms. "The elevation should show the shelf
   occupant" tells us more than "the elevation is wrong".
3. **Whether it is in §21.8.** If you are not sure, say so and report it
   anyway; a gap you hit and could not identify is itself worth knowing about.
4. **The version**, from `Help` ▸ `About RackPal…`. It is the same number
   stamped into every project file you save, so it identifies the build
   exactly.
5. **The diagnostic log**, if something crashed or would not save.
   `Help` ▸ `Open diagnostics folder…` opens the folder holding it:
   `rackpal.log` is this session and `rackpal.previous.log` the one before,
   which is the one you want if RackPal closed on you. It records what kind
   of error happened and where in the code, and never a project name, a file
   name or a path (DR-194). If RackPal could not start at all, the window
   that says so shows the same folder.

**Disagreements about the trade are the most valuable thing you can send.**
The validation rules encode opinions about what is and is not a sane cable run,
and those opinions came from a small number of people. A rule that fires on
something you do every week, or stays silent on something that would fail an
inspection, is a better find than a crash. Crashes get fixed; a wrong rule gets
shipped to everybody and quietly teaches them the wrong thing.

---

**Related:** [Keyboard reference](reference/keymap-windows.md) (generated) ·
[Deployment](14-deployment.md) (how a build is made and handed over) ·
[Rack editor](04-rack-editor.md), [Schematic](05-schematic-editor.md),
[Device builder](06-device-builder.md), [Structure](07-structure-device.md),
[Plan view](15-plan-view.md) (design specifications, which describe more than
is built) · [Milestone board](12-milestone-board.md) (what is demonstrated, and
the evidence for it)
