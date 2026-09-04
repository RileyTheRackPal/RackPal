# Riley the RackPal: character reference

**Status: normative for the fixed half, open for the rest.** Ruled at canon §10.12(f) (the mascot),
DR-096 §11.95.4 (Riley's place in the lockup) and DR-117 §11.116 (the lockup ships; the manual's
register).

This document exists to be handed to an artist. It says what is already decided and cannot move,
what is deliberately open, and what to draw.

---

## 1. What is already fixed, and why

These are not preferences. Each is either a ruling or a number some code reads.

| Fixed | Source | Why it cannot move |
|---|---|---|
| Riley is a **Protogen** | canon §10.12(f) | The name and the archetype were ruled together |
| **Neutral warm white with greys** | canon §10.12(f) | *"so the mascot never competes with the eight domain hues"*. PAL-1 gives eight signal colours whose separation three CI gates protect; a coloured mascot on a sheet borrows from that budget |
| The **visor eye is a hole** | `brand.dart` | It is a counter, not a shape drawn on top. Riley is filled **even-odd** where the letterforms are nonzero, and one path cannot carry two fill rules |
| **Ears and jaw teeth survive at small sizes** | `brand.dart` | The trace keeps every turn sharper than 42° as a corner specifically so these read. They are the silhouette |
| **0.806:1**, taller than wide (544 × 675 units) | `brand.dart` | The lockup is 1.876:1 and cannot fill a square slot, so **below about a 48 px icon the mark IS Riley**. The app icon is this shape |
| Stands **cap-high** on row 2, flush right, 268 units clear of `PAL` | `brand.dart` | Placed by measurement rather than by eye. Final art replaces the path data and leaves every one of these constants alone |

**The silhouette test is the real constraint.** At 16 px Riley is the window icon. Fill the shape
solid black and it must still be recognisably Riley: ears, visor, jaw. If the character only reads
because of interior detail, it will not survive the taskbar.

---

## 2. What is open

Everything else, and these are genuinely the artist's calls rather than questions with hidden
answers:

- **Body plan below the head.** Digitigrade or plantigrade, tail or no tail, proportions, whether
  Riley is chunky or lithe. Nothing in the code or the corpus reaches this.
- **The visor's expression vocabulary.** How many glyphs, how abstract, whether the eye shape
  changes or only its contents. §4 proposes a set; treat it as a request rather than a spec.
- **Hands.** Paws, gloves, three fingers or five. They will hold tools constantly, so this is worth
  deciding early and deliberately.
- **Wear and personality.** Whether Riley is factory-fresh or has scuffs, a tool belt, a favourite
  screwdriver.
- **Height relative to a rack.** §3's scenes assume Riley is roughly knee-high to an adult, which
  makes a 42U rack a building. **If that is wrong, say so and the scenes change** — it is the single
  assumption most of the poses below rest on.

---

## 3. Who Riley is, in one paragraph

Riley is the competent one. Not a helper who apologises, not a mascot who mugs at the reader: the
person on site who has done this before and will tell you plainly what is wrong. **Riley never
guesses.** When the product does not know something, Riley does not know it either, and says so —
that is G4/CR-114 given a face, and it is the character's whole spine. Riley is unbothered by a
mistake and specific about it, which is the difference between a rule engine and a nag
(`design-ux-schematic.md §2.1`).

---

## 4. The three tiers are three postures

This is the most useful thing in the document, and it is worth reading before the pose list.

The product refuses in three different ways, and they are already distinct in the code (CR-017,
DR-112). **Give each one a posture and the manual, the app and the artwork share a vocabulary
without anybody having to explain it.**

| Tier | What it means | Proposed posture |
|---|---|---|
| **Tier 1** — the model means nothing | The cable cannot exist. `TOP-001`..`005` | **Arms crossed, flat.** No expression softening. There is nothing to discuss, and docs/02:854 gives the escape as *"None. There is nothing to escape to"* |
| **Tier 2** — the gesture hesitates | The cable would be wrong but you may have it. The six spring-back rules | **Head tilted, one hand raised, palm out.** A pause rather than a block. CR-017's *"the gesture may hesitate; the document may not lie"* is this pose |
| **Tier 3** — the document is described | A finding on a list. Fourteen post-hoc rules | **Clipboard.** Not blocking anything, walking the job and writing it down |

And a fourth that is not a tier and matters as much:

| Not a tier | What it means | Proposed posture |
|---|---|---|
| **Unknown** | The product has no figure and refuses to invent one | **Palms up, shoulders raised, visor showing a dash.** The dash is not decorative: `—` is what G4 prints for an unknown value, and it is already in the product's type system |

---

## 5. Pose and scene catalogue

Numbered so an artist and a writer can refer to the same thing. The first four are the user's;
the rest are proposed.

### Given

1. **Directional pointing.** The workhorse. Needs to exist in four rotations and read at small size.
2. **Installing equipment in a rack.** Riley at the rails with a device half-seated, ears back,
   taking the weight.
3. **Running wire through the attic.** Riley in the whitespace at the top of the page, feeding a
   cable down toward the text. See §6 — this is the idea the whole page furniture grows from.
4. **In a hard hat, talking with a builder.** Riley small beside a full-size human, gesturing at
   something offscreen. The only scene with another character in it.

### Proposed, in rough order of usefulness

5. **Shrugging, palms up, visor showing a dash.** The unknown pose from §4. This will be used more
   than anybody expects: every rollup in the product reports what it could not count.
6. **Arms crossed.** Tier 1. Deadpan.
7. **Head tilted, palm raised.** Tier 2. The spring-back chip's illustration.
8. **With a clipboard.** Tier 3, and the DRC page's header. Riley reading, not alarmed.
9. **Recoiling from a spark at a switch port.** `SIG-001`, the flagship hazard: 100 W of PoH into an
   Ethernet jack. **The one scene allowed to be dramatic**, because the underlying fact is that the
   switch is damaged. Pairs with a warning page.
10. **Toning a pair.** Riley holding a tone probe to a punchdown, ear cocked, listening. Certification
    and the `LEN` rules.
11. **Crouched at a patch panel with a 110 tool.** Terminated pairs behind, a few to go.
12. **Straining under an amplifier.** Knees bent, arms full. `RCK-003` and `RCK-013` — weight is a
    real constraint and this makes it legible.
13. **Measuring rack depth with a tape.** Nose to the rear rail. `RCK-012`, front depth plus rear
    depth plus 50 mm.
14. **On a ladder in a ceiling grid**, holding a cable up into a lifted tile. Plenum space,
    `CODE-002`. Riley is checking the jacket print, not just pulling.
15. **Asleep on a rack shelf**, curled, visor dimmed to a standby glyph. Empty state, first run,
    and the "no cables in this document" panel.
16. **Presenting a finished sheet.** Riley holding up a printed elevation, pleased. Export, and the
    back cover.
17. **With a label maker**, applying a designator to a panel. Naming and CR-042/CR-048.
18. **Emerging from a floor tile.** Pure page furniture — Riley coming up through the bottom margin.
19. **Riding a cable bundle** down the side of a rack like a fireman's pole. Section-break art.
20. **Seated at a tablet**, the in-app assistant pose (`#563`). Riley beside the reader rather than
    in front of them.
21. **Holding two connectors that will not mate**, one in each hand, looking at the reader. `CON-001`.
22. **Pointing at a keyboard diagram.** The controls page. Riley's finger is the callout leader.
23. **Untangling a knot of cable**, patient rather than exasperated. Tidy sheet, and the chapter on
    schematic layout.
24. **Back turned, hands on hips, surveying a finished rack.** Chapter close.

---

## 6. The page is a building

The attic idea (scene 3) is worth generalising, and it is the thing that will make the manual feel
like the era it is borrowing from. **Riley treats the page's own geography as a job site:**

- The **top margin is the attic** — cable comes down from it.
- The **bottom margin is the floor** — Riley comes up through it, and cable disappears into it.
- The **gutter is a wall cavity**. A run entering the gutter on a left page can emerge on the right.
- The **outer margin is a rack side panel**; Riley can stand on the page edge.
- **Page numbers can be rack U labels** in a chapter that is about elevations.
- A **cable can cross a page break** and be picked up overleaf. Vintage manuals did this with
  scrolling levels and it is the single most era-appropriate device available.

**One rule for all of it:** the furniture never crosses a safety sentence. §11.116.3 rules that
`CODE-001`, `CODE-002` and `SIG-001` are quoted verbatim, and Riley may stand beside a warning but
may not decorate it, obscure it or paraphrase it.

---

## 7. Speech bubbles

**Riley's copy is the product's copy.** The app already has a voice and it is specified: a complete
sentence about THIS document, naming real designators, ending in a full stop, with the rule id as a
separate field so the sentence never has to carry it (`Finding.message`, and `ConnectRefused`
before it). *"AVR-1 J03 already carries 1 of 1 connections"* is an explanation; *"TOP-003"* is a log
line.

So bubbles are drawn with real text in them, not lorem, and the text obeys that. Examples, all in
register:

| Scene | Bubble |
|---|---|
| 9, the spark | *"That is HDBaseT. It carries up to 100 W and the switch is not expecting it."* |
| 5, the shrug | *"Nobody has measured this run, so I cannot tell you whether it is too long."* |
| 7, the hesitation | *"Both of those are inputs. Nothing would drive the cable."* |
| 12, the amplifier | *"Sixteen kilos on front ears rated for seven. It wants rear support."* |
| 13, the tape measure | *"Front and rear plus fifty millimetres for the cable. It does not fit."* |
| 15, asleep | *(no bubble)* |
| 22, the keymap | *"W starts a wire. Tab picks the far end. Enter makes it."* |

**Three things Riley never says**, and they are the ones a mascot reaches for by default:

- **An apology.** The product refusing a bad cable is the product working.
- **A guess.** No "about", no "roughly", no number Riley does not have. If the figure is unknown,
  the bubble says it is unknown.
- **A rule id on its own.** That is the log line the voice exists to avoid.

---

## 8. What an artist needs delivered back

For the mark to ship, one asset:

- **Riley, front-facing, at the lockup proportion**, as vector outlines, with the visor eye as a
  separate closed subpath so the even-odd fill still works. This replaces `_rileyD` in
  `brand.dart` and nothing else changes.

For the manual, the poses in §5 as line art. **A silhouette check on each**: fill it solid and
confirm it still reads.

---

## 9. What this document does not decide

- **When any of it is built.** The mascot's three surfaces are `#563`–`#565` and sit in **M8,
  release engineering**, where canon §10.12(f) put them. The **manual is M9, beta hardening**
  (DR-117 §11.116.4), and the two are deliberately apart: an app that draws Riley and a book that
  draws Riley are different deliverables on different clocks.

  M9's exit criterion is why the manual sits there rather than earlier: *"three integrators have
  each produced a sheet set they were willing to send to a client or a job site, and none of the
  three needed to leave the app to fix something."* **A manual written before that beta is guessing
  at what confuses somebody; a manual written for it is read by the three people whose confusion the
  criterion counts.**
- **Riley's pronouns**, beyond the they/them this document uses throughout.
- **Whether Riley speaks in the application at all.** `#563` is an *opt-in* assistant, and canon
  §10.12(f) is explicit about the opt-in. A mascot in a manual and a mascot in a window are two
  decisions, and only the first is made here.
