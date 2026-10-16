# Riley in the user guide: the plate plan

**Status: proposed, not ruled.** This document extends [docs/19](19-riley.md), which is
normative for the fixed half of the character. It adds scenes, a size vocabulary for
illustration slots, a budget for how loud the visor may be, and a map of the manual's
old-games structure onto the guide. Nothing here changes a ruling. Where it and docs/19
or DR-117 §11.116 / DR-118 §11.117 disagree, **they win and this is wrong**.

Written to be handed to an artist alongside docs/19, and to be read by whoever lays out
the PDF. The manual is scheduled into M9, beta hardening (DR-117 §11.116.4); the slots in
[docs/21](21-user-guide.md) exist now so the writing and the art can be fitted to each
other before then.

---

## 1. How the guide marks a slot

Two kinds of boxed note in `docs/21-user-guide.md`, both blockquotes whose first words are
bold, so they survive any markdown viewer:

```
> **PLATE 21.5.4-D · HALF** · Scene 44 · Teaching · Visor: product mark
> The brief, in two or three sentences.
```

```
> **SCREEN 21.10-B · FULL** · Rack view, Whole house starter, one device selected
> What to capture, and which callouts to number.
```

| Field | Meaning |
|---|---|
| `PLATE` / `SCREEN` | A drawing of Riley, or a captured screenshot with numbered callouts |
| Id | Section number, then a letter. **Stable**: adding a plate to a section takes the next letter and renumbers nothing |
| Size | One of the six in §2 |
| `Scene` | A scene number in docs/19 §5 (1 to 30) or §4 below (31 onward) |
| `Teaching` / `Reference` | The chapter class, which sets the visor budget (§3) |
| `Visor` | The register from docs/19 §7.3: *product mark*, *punctuation*, *grawlix*, *face*, a named state, or *none* |

**The text of a plate is an art brief and never printed copy.** Riley does not speak in
words in the manual (docs/19 §7.1). In the finished book a plate is replaced by its picture
and the brief is deleted.

`python tools/plate_index.py` lists every slot in the guide, with its page class and
register, and checks the rules in §6. It is a reporting tool and is not wired into
`run_local.ps1`: nothing in the build depends on the art existing.

## 2. Sizes

Measured against the PDF's Letter page, 16 mm side margins, so a text column about 184 mm
wide. The print stylesheet reserves these as dashed frames so the layout can be judged
before any art exists.

| Size | Frame | Used for |
|---|---|---|
| `SPOT` | about 50 x 50 mm, floated beside a paragraph | One beat in a procedure. The workhorse |
| `MARGIN` | about 24 x 70 mm, hanging into the outer margin | Furniture art that has an opinion about the paragraph beside it (DR-118 §11.117.4) |
| `HALF` | full column x about 85 mm | A scene with a prop or a second figure, and most subsection openers |
| `FULL` | the page below the running header | A chapter opener. Spend sparingly |
| `STRIP` | full column x about 45 mm | A wordless sequence of three or four panels carried by the visor alone |
| `SCREEN` | as stated on the slot | A screenshot with numbered callouts, never redrawn |

**Chibi in every size**, canonical scale cues preserved (docs/19 §2): a chibi Riley beside
a rack is still rack-height relative to it, the top few U wants a step, and the tail is
shorter than canon and longer than chibi proportion would give.

## 3. The visor budget

DR-118 §11.117.5 says expressiveness is drawn against the character's authority, and that
the wider the register, the rarer it should be. This makes that checkable.

| Chapter class | Which chapters | Visor |
|---|---|---|
| **Reference** | The Bestiary, the glossary, the controls pages, export and not-built | **Product marks and `none`.** Punctuation sparingly. No grawlix, no faces |
| **Teaching** | The tour, the per-view chapters, field notes, troubleshooting | Punctuation by default. A face roughly once per chapter. Grawlix at most once in the book, in a moment a trade reader will recognise, and **never on a page carrying a safety sentence** |

Two states are their own thing (DR-118 §11.117.3):

- **The dash `—`** means nobody has supplied the value. It is the product speaking, so it
  appears only where the guide is talking about an unknown (the metrics row, an
  uncalibrated plan, a blank field).
- **Loading** means not yet. Use it for imports and anything in progress.
- **The classic bluescreen (`#0000AA`)** means Riley has failed. **Manual only, and never
  on a page carrying domain glyphs.** The guide gives it exactly one section (21.13,
  When something looks wrong) and that section is kept free of cable colours and domain
  marks to deserve it.

A tally of what each chapter currently spends is one command away and is deliberately
not copied here:

```bash
python tools/plate_index.py --tally
```

## 4. Scenes 31 onward

docs/19 §5 numbers thirty scenes. These continue the numbering, and each exists because a
chapter in the guide needed a picture the first thirty do not give. **Scene 25 (the tail
into a panel) should still be drawn first** (docs/19 §8): it decides whether the tail reads
as equipment, and several of these lean on that answer.

| # | Scene | Where it is used | Visor | Notes |
|---|---|---|---|---|
| 31 | **Carrying the portable folder** under one arm like a toolbox | Read this before you install | punctuation `!` | The product is a folder. A USB stick on a lanyard if the arm is full |
| 32 | **A save point.** Kneeling at a glowing pedestal | What protects unsaved work | loading, then done | The most game-manual image on offer. Autosave is exactly this |
| 33 | **Rewinding.** Hauling a cable back onto the reel hand over hand | Undo | `!?` | Undo as a physical act. The reel can be reused for scene 51 |
| 34 | **A bank of DIP switches**, set with the red flip-shaft | Project settings | `&` | The trade's own image of setting conventions before a job |
| 35 | **Stamping a blank sheet** | Sheet set / title block | none | **The stamp face is drawn empty.** Words on a stamp would read as the product's issue stamp |
| 36 | **An original and its clone** held side by side | Signal families | domain glyph | One latch differs. A clone is a copy that keeps the checks working |
| 37 | **A tape stretched across the plan**, Riley kneeling on it | Calibrate | `?` then `!` | Two panels if the room allows: before and after |
| 38 | **The map table.** Plan unrolled, a pin in each hand | Site chapter opener | `—` | The dash is true: not yet calibrated |
| 39 | **Chalk line** along a room's corners, one left open | Outline the rooms | none | The open corner is the one to click twice |
| 40 | **The parts wall.** Labelled bins, one hand on chin | Find a device | `?` | The item shop, in a game manual's terms |
| 41 | **The workbench.** Calipers on a chassis, datasheet pinned up | Author a device | `—` | Dash for the field left blank on purpose |
| 42 | **Typing a Quick Add line**, tail tapping the desk | Add ports | a cursor | A shape, not a character |
| 43 | **Handing a card across** | Share templates | face `^_^` | The other figure is cropped. Docs/19's only two-character scene is scene 4 |
| 44 | **The benched gear.** A tote beside Riley, every device still wired back up to the rack | Staging Bin | product mark | The tangle is the picture: a staged device keeps its wiring |
| 45 | **Closing the gaps.** Sliding a row of devices together like bookends | Compact | `&` | Pairs with the compaction preview |
| 46 | **Feeding a printout into a scanner** | Import a spreadsheet | loading | Loading, not the dash: the data exists and has not arrived |
| 47 | **Pencilling counts into a grid** | The Matrix tab | none | One ear flicked |
| 48 | **A laptop at a switch**, ticking a row | The Devices tab, Verified today | tick shape | A tick drawn as a shape |
| 49 | **Laying a ribbon across a bank of jacks** | Draw many cables at once | `!` | One jack at a time, in a row |
| 50 | **The length ladder.** Riley climbing five rungs | Get a length you can order from | `—` at the foot | Rungs, bottom to top: unknown, plan floor, room estimate, outlet nominal, measured cut |
| 51 | **Spool and tape.** Measuring cable against a wall tape | The takeoff | product mark | Reel from 33 |
| 52 | **The taut string.** Held between two pins, the other palm flat beneath it | Plan floor lengths | `>=` shape | A floor and not an estimate: the palm is the floor |
| 53 | **Ticking the Pull Sheet's boxes** | Field notes | none | Pulled, terminated, tested: three boxes |
| 54 | **Signing the acknowledgement** on a note stuck to a flag | Dealing with a finding | product mark | Part of the strip in the Bestiary |
| 55 | **Walking the findings.** A corridor, the clipboard, a pointing hand | Read the drawer, F8 | product mark | Tier 3 clipboard posture |
| 56 | **Proofing.** Two printed sheets held to the light with a magnifier | The PDF export | product mark | Identical. Same project, same day, same bytes |
| 57 | **Sitting on the closed hatch**, cones around it | What is not built | `—` | A bare numeral 3 on the hatch as a shape. No words, no apology |
| 58 | **Handing over the log folder**, seated on the floor, belt sagging | When something looks wrong | **bluescreen** | The one place the guide allows it |
| 59 | **A chord at a keyboard.** One hand on the modifiers, the tail on a third key | Controls | `!` | The tail as a working limb |
| 60 | **The starter card.** Sliding a card into a slot, console style | Open a starter; getting it running | `!`, and `^_^` at the end of the unblock strip | Also the unblock strip's four panels |
| 61 | **The field naturalist.** Clipboard, ears forward, specimen cards pinned behind | The Bestiary opener | product marks only | See §5 |
| 62 | **Two half-width devices, shoulder to shoulder** | RCK-014 | product mark | The case where no kit is needed |

### Further ideas, not yet placed in the guide

- **A full chord of faces.** One page near the back where Riley runs the whole visor range
  in a grid of small panels, labelled by register in symbols only. This is the only page
  that explains the visor to the reader, and it earns its place the first time somebody
  asks what the `?` means.
- **Level-select contents.** The table of contents drawn as a level-select screen, one
  tile per chapter, Riley standing on the current one. This is a layout change to
  `user_guide_pdf.py`, not an illustration.
- **The hint line.** Old manuals ended with a phone number. Riley holding a handset and
  the diagnostics folder, for §21.9.
- **A back-cover spread.** Scene 24 (back turned, hands on hips, a finished rack) and
  nothing else.
- **A sticker sheet.** Riley's eight domain-glyph speech as a page of cut-out shapes. It
  would also be the best test of whether the glyph vocabulary reads without a font.
- **Photosensitivity-style warning page.** Old manuals opened with a boxed warning before
  the first chapter. The guide's equivalent is the code-adjacent and `SIG-001` text. If
  the manual ever grows a front-matter warning page, **it quotes the three safety
  sentences verbatim and Riley stands beside it in a Tier posture and nothing else**.

## 5. The Bestiary's specimen cards

The Bestiary (docs/21 §21.11) is the chapter that most benefits from art, and the one the
register is the most careful about. docs/19 §7.1's grammar is **posture is the mood, the
glyph is the subject**, and DR-118 says reference chapters should be nearly all product
marks. So: one specimen card per check, in a repeating frame, **Riley in the posture of
the check's tier, the visor showing the glyph of the check's subject**, and nothing else.

| Tier | Posture | Which checks |
|---|---|---|
| Refused | Arms crossed, flat | `TOP-001`..`TOP-005`, `PLC-001`..`PLC-003` |
| Springs back | Head tilted, one palm raised | `SIG-001`, `SIG-002`, `DIR-001`, `DIR-003`, `CON-001`, `ELE-006` |
| A finding | Clipboard | Every post-hoc check, including the site notes |

**Suggested subject glyphs.** These are art direction, not canon, and they are a reading
aid for the legend: use a different domain across neighbouring cards so the reader learns
the eight shapes by seeing them. Draw them as geometry (docs/19 §7.1); never set them as
text.

| Check | Glyph (domain) | Why that one |
|---|---|---|
| `TOP-001` | network, filled | A cable that starts and ends at one jack: a patch cord |
| `TOP-002` | digital audio | Duplicate conductors in one cable |
| `TOP-003` | digital video | Two cables in one HDMI port |
| `TOP-004` | structure | A cable to a device that was deleted |
| `TOP-005`, `PLC-*` | none | No signal is involved. Rack silhouette only |
| `SIG-001` | digital video over network | HDBaseT into a switch. **Two glyphs, one on each half of the visor, is the only two-glyph card** |
| `SIG-002` | digital video, hollow | The signal is not one the input reads |
| `DIR-001` | analog audio | Output to output |
| `DIR-003` | control | An IR emitter into a receiver |
| `CON-001` | digital video | The plug does not fit the jack |
| `ELE-006`, `ELE-003`, `ELE-005` | analog audio | Speakers |
| `NET-001` | network over power | A PoE budget |
| `PWR-001`, `PWR-003` | power | Circuits and outlets |
| `LEN-001`, `LEN-002` | network, then digital video | Run lengths |
| `RCK-*` | none | Rack silhouette |
| `CODE-001` | power | Line voltage in a pathway |
| `CODE-002` | structure | A plenum pathway |
| `LNK-020` | structure, hollow | Home runs not landed |
| `PLN-*` | structure | The plan |

**The three code-adjacent and `SIG-001` pages carry a safety sentence**, which is quoted
verbatim in the guide. On those pages **Riley may stand beside it in the product-mark
register and a section-4 posture, and may not decorate it, obscure it or paraphrase it**
(DR-117 §11.116.3; DR-118 §11.117.5 adds: no grawlix and no face).

## 6. The rules a plate must pass

`tools/plate_index.py` checks the mechanical ones. The rest are for a person.

**Mechanical, checked by the tool:**

1. Every `Scene` number exists (1 to 30 in docs/19, 31 onward in §4 above).
2. A plate whose register is a face or a grawlix is not in a Reference chapter.
3. **No face, grawlix or bluescreen anywhere in the Bestiary (21.11)**, the chapter that
   carries `CODE-001`, `CODE-002` and `SIG-001`. This is stricter than DR-118 §11.117.5
   asks, and deliberately: the chapter is one reference book, and a page-by-page rule
   is one a layout change silently defeats.
4. **The bluescreen appears only in section 21.13**, and 21.13 contains no domain glyph.
5. Ids are unique and each belongs to the section it names.

**For a person, on every drawing:**

- **The silhouette test.** Fill it solid black. If it is not recognisably Riley (ears,
  visor, jaw) it will not survive a small size.
- **Scale.** Riley is rack-height relative to the rack, whatever the chibi proportions.
- **Count the fingers.** Three and an opposable thumb. They hold tools constantly.
- **No words.** No lettering inside the art. A stamp is blank. A tab is blank. A hatch has a
  shape and no label.
- **The glyph is a shape.** Anything from the domain table is drawn as geometry. The
  glyph-coverage gate exists because a codepoint on this machine happened to resolve.
- **The red flip-shaft screwdriver and the tail are the continuity props.** If Riley holds
  a different screwdriver the book has two Rileys.
- **Colour.** Neutral warm white and greys (docs/19 §1). A plate that needs hue to read has
  borrowed from the eight domains.
- **Provenance.** Every mark the product ships traces to a human author, and the file that
  carries it says which (DR-117 §11.116.2).

## 7. The page is a building, chapter by chapter

docs/19 §6 gives the idea: the top margin is the attic, the bottom margin is the floor, the
gutter is a wall cavity, the outer margin is a rack side panel. Where each earns its keep
in the guide:

| Chapter | Furniture |
|---|---|
| Getting it running | A run enters the gutter on the left page and emerges on the right, carrying the unblock strip across the spread |
| The tour | Page numbers as rack U labels, counting up. Riley climbs them |
| Site | Riley comes up through a floor tile in the bottom margin (scene 18) with the plan |
| Device Manager | The outer margin is a parts wall; bins down the edge |
| Rack | Page numbers as U labels again, and the Staging Bin tote in the bottom margin |
| Structured Wiring | The attic run (scene 3) enters at the top of the first page and comes down through the chapter |
| Schematic | A cable crosses the page break and is picked up overleaf: the single most era-appropriate device available |
| Schedule | The length ladder runs down the outer margin, one rung per section |
| Bestiary | Specimen cards pinned along the outer margin, in a row |
| Troubleshooting | A fuse box in the bottom margin. Nothing else |

**One rule overrides all of it:** the furniture never crosses a safety sentence.

## 8. A games manual's parts, and where this guide has them

DR-117 §11.116.3 rules the register. Its parts, mapped:

| Old manual | Here |
|---|---|
| Cover and title page | The PDF cover (the lockup), plus one plate |
| Contents | The contents page. A level-select treatment is a layout idea (§4) |
| *Prologue* | §21.1 and §21.2: what it is, and what you are holding |
| *Getting started / installing* | §21.3 |
| *Controls* | §21.6 and §21.10, plus Appendix A |
| *Main screen, labelled* | §21.10's SCREEN slots with numbered callouts |
| *Level 1* | §21.4, the tour |
| *Items* | The device catalogue, §21.5.3, and `docs/catalog/seed-devices.md`, **the only place a template count is stated** |
| *Enemies* | The Bestiary, §21.11 |
| *Tips and tricks* | §21.12, and the margin screwdriver |
| *Save and continue* | The recovery snapshot, §21.5.1 |
| *Troubleshooting* | §21.13 |
| *Glossary* | §21.14 |
| *Customer support* | §21.9, reporting what you find |
| *Back cover* | Scene 24 |

## 9. What this document does not decide

- **Who draws it, and when.** The manual is M9. The mark is M8 (docs/19 §9).
- **Whether the PDF stays dark.** The PDF is dark on purpose (the user chose it, for
  reading on a screen) and `tools/user_guide_pdf.py` follows the app's palette. A print
  edition would want these plates drawn for white paper. Neutral warm white on dark and on
  white are two renderings of the same character and should be reviewed as such.
- **How many plates.** There is no target. A manual with a picture on every beat is a
  different book from one with a picture on every chapter, and the visor budget (§3) is a
  stronger argument for the second.
- **Anything in docs/19 §2 still open**: the colour greys, ear articulation, ear range.
  Several scenes here (the specimen cards especially) will want an answer before they are
  drawn.
