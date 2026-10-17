# Riley the RackPal: character reference

**Status: normative for the fixed half, open for the rest.** Ruled at canon §10.12(f) (the mascot),
DR-096 §11.95.4 (Riley's place in the lockup), DR-117 §11.116 (the lockup ships; the manual's
register) and DR-118 §11.117 (the visor's registers).

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

## 2. The body: settled, and what is still open

### Settled by the user, 2026-09-03

| Fact | Note for the artist |
|---|---|
| **Roughly 5 feet tall** | Canonically. A 42U rack is about 6'2", so Riley is **rack-height, not knee-height**: they work a rack the way a person does and need a step for the top few U |
| **Rendered CHIBI in the manual** | The manual's illustrations are a stylisation, not the canonical proportion. See the note below, because this is the one place two renderings of Riley coexist and a brief that blurred them would produce inconsistent art |
| **Digitigrade legs** | Which also settles how Riley stands, crouches and kneels at a rack base |
| **A mechanical tail ending in an RJ45 connector** | The single most characterful thing in this list. §5 adds four scenes that only exist because of it |
| **Three fingers and an opposable thumb** | Four digits. They hold tools constantly, so this is worth resolving in the first sketch rather than the tenth |
| **Scuffs** | Riley works. Not battered, not pristine |
| **A tool belt** | Loadout is the artist's; it should look chosen rather than issued |
| **A favourite screwdriver: the classic red flip-shaft** | Reversible shaft, Phillips one end and flat the other, red handle. A specific, real tool a trade reader will recognise instantly, which is worth more than a generic one |
| **Riley is they/them** | Throughout, in the manual, in the app and in this document |
| **No words in the manual: symbols instead** | Riley communicates through posture and glyph on the page. §7.1 gives the vocabulary and it is the product's own |
| **Words in the app** | The opt-in assistant (`#563`) speaks in a text bubble, as Clippy did. §7.2 |
| **Chibi shortens the tail, but not to scale** | Slightly shorter than canonical and **deliberately longer than chibi proportion would give**, so it stays a working limb. §5's four tail scenes depend on that and now have their answer |
| **The visor runs punctuation to full faces** | `?` `!` `&`, grawlixes for expletives, and kaomoji up to `>///<` `>_>` `^_^` `OwO`, plus a classic BSOD and a loading face. §7.3 |

**THE TWO RENDERINGS ARE THE THING TO GET RIGHT.** Riley is 5 feet in the world and chibi on the
page. That is a deliberate split and not a contradiction, but it means **every brief has to say which
rendering it wants**:

- **The mark** (`brand.dart`, the app icon, the window icon) is whatever the supplied art is, at
  0.806:1 and holding up at 16 px.
- **The manual** is chibi throughout.
- **Scale cues stay canonical in both.** A chibi Riley beside a rack is still rack-height relative to
  it. Stylisation changes the proportions of the character, never their size relative to the job.

**AND THE TAIL IS THE PRODUCT'S OWN JOKE, WHICH IS WHY IT WORKS.** RJ45 is the connector at the
centre of `SIG-001`, the flagship rule: docs/05:145 calls RJ45-carrying-HDBaseT and
RJ45-carrying-Ethernet *"the two most dangerous ports in the taxonomy"*, and the whole spring-back
tier exists because 100 W of PoH goes down one of them. **Riley is terminated in the one connector
this product is most careful about.** That is available as a running gag and as a warning-page beat,
and §5 uses it both ways.

### Still open

- **Colouring within the constraint.** §1 fixes neutral warm white and greys. Where the greys fall,
  whether there is a darker chassis against a lighter face, and what the visor's lit colour is are
  all open, provided nothing competes with the eight domain hues.
- **Ear articulation.** They are load-bearing for the silhouette (§1) and for expression, and nothing
  decides how far they move.
- **How far the ears travel.** They are load-bearing for the silhouette (§1) and are Riley's only
  expressive feature outside the visor, so their range is worth deciding alongside §7.3's.

## 3. Who Riley is, in one paragraph

Riley is the competent one. Not a helper who apologises, not a mascot who mugs at the reader: the
person on site who has done this before and will tell you plainly what is wrong. **Riley never
guesses.** When the product does not know something, Riley does not know it either, and says so:
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
| **Tier 1**: the model means nothing | The cable cannot exist. `TOP-001`..`005` | **Arms crossed, flat.** No expression softening. There is nothing to discuss, and docs/02:854 gives the escape as *"None. There is nothing to escape to"* |
| **Tier 2**: the gesture hesitates | The cable would be wrong but you may have it. The six spring-back rules | **Head tilted, one hand raised, palm out.** A pause rather than a block. CR-017's *"the gesture may hesitate; the document may not lie"* is this pose |
| **Tier 3**: the document is described | A finding on a list. Fourteen post-hoc rules | **Clipboard.** Not blocking anything, walking the job and writing it down |

And a fourth that is not a tier and matters as much:

| Not a tier | What it means | Proposed posture |
|---|---|---|
| **Unknown** | The product has no figure and refuses to invent one | **Palms up, shoulders raised, visor showing a dash.** The dash is not decorative: `—` is what G4 prints for an unknown value, and it is already in the product's type system |

---

## 5. Pose and scene catalogue

Numbered so an artist and a writer can refer to the same thing. The first four are the user's; the
rest are proposed. **Scenes 31 onward, and the plate slots in the user guide that use them, are in
[docs/22](22-riley-plate-plan.md).** **Scenes 25 to 30 exist only because the tail and the screwdriver were settled**,
which is the argument for settling §2 before drawing anything: a prop that generates scenes is worth
more than one that fills them.

### Given

1. **Directional pointing.** The workhorse. Needs to exist in four rotations and read at small size.
2. **Installing equipment in a rack.** Riley at the rails with a device half-seated, ears back,
   taking the weight. **At 5 feet this is mid-rack work done standing**, which is the natural
   composition: the device goes in at chest height and the top few U need a step. Tail braced
   against a rail for the lift.
3. **Running wire through the attic.** Riley in the whitespace at the top of the page, feeding a
   cable down toward the text. See §6: this is the idea the whole page furniture grows from.
4. **In a hard hat, talking with a builder.** Riley gesturing at something offscreen. **A head
   shorter than the builder rather than tiny beside them**: the settled 5 feet makes this a
   conversation between two trades, which is a better scene than a mascot addressing a giant. The
   only scene with another character in it.

### Proposed, in rough order of usefulness

5. **Shrugging, palms up, visor showing a dash.** The unknown pose from §4, and the clearest example
   of §7.1's grammar: the posture is the mood and the `—` on the visor is the whole statement. Used
   more than anybody expects, because every rollup in the product reports what it could not count.
6. **Arms crossed.** Tier 1. Deadpan.
7. **Head tilted, palm raised.** Tier 2. The spring-back chip's illustration.
8. **With a clipboard.** Tier 3, and the DRC page's header. Riley reading, not alarmed.
9. **Recoiling from a spark at a switch port.** `SIG-001`, the flagship hazard: 100 W of PoH into an
   Ethernet jack. **The one scene allowed to be dramatic**, because the underlying fact is that the
   switch is damaged. Pairs with a warning page.
10. **Toning a pair.** Riley holding a tone probe to a punchdown, ear cocked, listening. Certification
    and the `LEN` rules.
11. **Crouched at a patch panel with a 110 tool.** Terminated pairs behind, a few to go.
12. **Straining under an amplifier.** Knees bent, arms full. `RCK-003` and `RCK-013`: weight is a
    real constraint and this makes it legible.
13. **Measuring rack depth with a tape.** Nose to the rear rail. `RCK-012`, front depth plus rear
    depth plus 50 mm.
14. **On a ladder in a ceiling grid**, holding a cable up into a lifted tile. Plenum space,
    `CODE-002`. Riley is checking the jacket print, not just pulling.
15. **Asleep sitting on the floor**, back against the rack, legs out, tool belt sagging, visor
    dimmed to a standby glyph. Empty state, first run, and the "no cables in this document" panel.
    **Not curled on a shelf**, which the first draft of this list proposed before the height was
    settled: a 5-foot Riley does not fit on 1U.
16. **Presenting a finished sheet.** Riley holding up a printed elevation, pleased. Export, and the
    back cover.
17. **With a label maker**, applying a designator to a panel. Naming and CR-042/CR-048.
18. **Emerging from a floor tile.** Pure page furniture: Riley coming up through the bottom margin.
19. **Riding a cable bundle** down the side of a rack like a fireman's pole. Section-break art.
20. **Seated at a tablet**, the in-app assistant pose (`#563`). Riley beside the reader rather than
    in front of them.
21. **Holding two connectors that will not mate**, one in each hand, looking at the reader. `CON-001`.
22. **Pointing at a keyboard diagram.** The controls page. Riley's finger is the callout leader.
23. **Untangling a knot of cable**, patient rather than exasperated. Tidy sheet, and the chapter on
    schematic layout.
24. **Back turned, hands on hips, surveying a finished rack.** Chapter close.

### The tail, which earns four of its own

The RJ45 tail is the one piece of the design that generates scenes rather than decorating them.

25. **Riley plugging their own tail into a patch panel port.** The "I will just test it myself"
    pose. Reads instantly, needs no caption, and is the obvious candidate for a chapter opener on
    certification.
26. **Tail reaching a far jack while both hands are busy.** Riley punching down with both hands and
    the tail stretched off to the side holding a connection. Says *competent* rather than *cute*,
    which is the line this character walks.
27. **Tail wrapped around a rail for balance**, both hands overhead, digitigrade legs braced. The
    working pose for anything at the top of a rack.
28. **Riley eyeing their own tail warily beside a PoE switch port.** §2's note made visible:
    RJ45-carrying-HDBaseT and RJ45-carrying-Ethernet are *"the two most dangerous ports in the
    taxonomy"* and 100 W of PoH goes down one of them. **Pairs with the `SIG-001` warning page**,
    and is the one place the running gag and the safety content are the same picture. It must not
    replace the warning's own sentence (DR-117 §11.116.3); it sits beside it, and per §7.1 the
    glyph alone may never carry a safety statement.

### The screwdriver

29. **Flipping the shaft**, Phillips to flat, mid-gesture, looking at the reader. A beat for
    "there is another way to do this": section transitions, and the tips page.
30. **Screwdriver behind the ear**, hands busy elsewhere. Idle art, margin art, and the smallest
    possible way to say Riley has been doing this a while.

---

## 6. The page is a building

The attic idea (scene 3) is worth generalising, and it is the thing that will make the manual feel
like the era it is borrowing from. **Riley treats the page's own geography as a job site:**

- The **top margin is the attic**: cable comes down from it.
- The **bottom margin is the floor**: Riley comes up through it, and cable disappears into it.
- The **gutter is a wall cavity**. A run entering the gutter on a left page can emerge on the right.
- The **outer margin is a rack side panel**; Riley can stand on the page edge.
- **Page numbers can be rack U labels** in a chapter that is about elevations.
- A **cable can cross a page break** and be picked up overleaf. Vintage manuals did this with
  scrolling levels and it is the single most era-appropriate device available.

**One rule for all of it:** the furniture never crosses a safety sentence. §11.116.3 rules that
`CODE-001`, `CODE-002` and `SIG-001` are quoted verbatim, and Riley may stand beside a warning but
may not decorate it, obscure it or paraphrase it.

---

## 7. How Riley communicates

**Riley does not speak in words in the manual. Riley speaks in words in the app.** Two registers,
settled by the user on 2026-09-03, and the split is not arbitrary: a printed page can teach a symbol
once and rely on it forever, and a window cannot.

### 7.1 In the manual: symbols

**The vocabulary is the product's own, and that is the whole idea.** RackPal already has a symbol
language a reader has to learn anyway, canon §6.2.4's fourth encoding channel, the domain glyph
that appears at every run midpoint on every sheet:

| Domain | Native | Transported |
|---|---|---|
| Digital video | ▲ | △ |
| Analog video & RF | ▼ | ▽ |
| Analog audio | ● ◐ | ○ |
| Digital audio | ◆ | ◇ |
| Network | ■ | □ |
| Control | ✚ | ✳ |
| Power | ⬢ | ⬡ ⏚ |
| Structure | ★ | ☆ |

**Shape encodes the domain; fill encodes the tier**: filled is the domain's native carrier, hollow
is the transported or networked variant. So **a reader who learns Riley's speech has learned the
legend on every drawing they will ever open.** That is worth more than any invented icon set could
be, and it costs nothing: the glyphs are already drawn, already gated for legibility at 6 pt, and
already checked under protanopia and deuteranopia simulation (canon §6.7).

**THEY ARE SHAPES, NOT CHARACTERS, AND THIS PAGE PROVED IT THE HARD WAY.** The table above sets them
as text so a reader can see them here, and that is the one thing the manual must not do.
`tools/glyph_coverage_check.py` lists all eight as `PATH_BACKED`: they are registry data drawn as
GEOMETRY by `family_glyph.dart` and `device_glyph_art.dart`, whose advance is computed from the type
size *"so that measurer and emitter cannot disagree"*, and the gate's own comment says requiring them
in a font would be *"requiring a font for something deliberately taken out of the font's hands"*.

That is not theoretical. `device_glyph_art.dart` exists because a signal glyph shipped as a codepoint
returned a near-zero advance from `PdfFontMeasurer` while the screen fell back to a system face and
drew it full width, and `NET-NEN006` printed over a net name. **Both backends emitted identical ops;
only the font behind one differed, so every gate passed.**

And it happened again while this document was being built. The first PDF render of this very table
was checked codepoint by codepoint against the output, and **U+2B22 ⬢, the power domain, did not
resolve**: eight of the nine marks found an outline and the hexagon did not. The other eight
survived only because this machine happened to have fallback faces for them.

**So: the illustrator draws these as shapes.** Riley's visor displays geometry, not a font. The
characters in the table are a description of what to draw and are never the artwork, and any page
furniture that sets them as text carries the same defect the product spent a ruling removing.

Two more marks Riley has available, both already in the product:

- **`—`, the em dash**, for unknown. It is literally what G4 prints for a value nobody has supplied,
  and it is the visor glyph for §4's fourth posture.
- **The severity marks** of docs/05 §8, for the hazard pages.

**GRAMMAR: POSTURE IS THE MOOD, THE GLYPH IS THE SUBJECT.** §4 gives four postures: refusing,
hesitating, reporting, not knowing, and the glyph says what about. Arms crossed with a ■ is *"that
network cable cannot exist"*; head tilted with a ◆ is *"that digital audio run would be wrong, but
you may have it"*. **The two channels together are a sentence**, and neither alone is.

**THE ONE HARD LIMIT, WHICH IS DR-117 §11.116.3 AND NOT NEGOTIABLE.** A symbol may not carry a
safety statement by itself. `CODE-001`, `CODE-002` and `SIG-001` are quoted into the manual verbatim
as text; Riley stands beside them with the matching glyph and posture. **The symbol is emphasis, and
the body text is the information.** A reader who misreads a glyph has misread an ornament; a reader
who cannot find the sentence has been failed by the book.

### 7.2 In the app: a text bubble

Canon §10.12(f) scopes *"an opt-in Clippy-style in-app assistant"* (`#563`), and there Riley uses
words in a bubble, as Clippy did.

**The copy is the product's copy.** The app already has a specified voice: a complete sentence about
THIS document, naming real designators, ending in a full stop, with the rule id as a separate field
so the sentence never has to carry it (`Finding.message`, and `ConnectRefused` before it). *"AVR-1
J03 already carries 1 of 1 connections"* is an explanation; *"TOP-003"* is a log line.

| Situation | Bubble |
|---|---|
| A spring-back on `SIG-001` | *"That is HDBaseT. It carries up to 100 W and the switch is not expecting it."* |
| A rollup with a gap | *"Nobody has measured this run, so I cannot tell you whether it is too long."* |
| `DIR-001` | *"Both of those are inputs. Nothing would drive the cable."* |
| `RCK-013` | *"Sixteen kilos on front ears rated for seven. It wants rear support."* |
| `RCK-012` | *"Front and rear plus fifty millimetres for the cable. It does not fit."* |
| Idle | *(nothing: the assistant is opt-in and silence is its resting state)* |

**Three things Riley never says, in either register**, and they are the ones a mascot reaches for by
default:

- **An apology.** The product refusing a bad cable is the product working.
- **A guess.** No "about", no "roughly", no number Riley does not have. Unknown is said with the em
  dash in the manual and said plainly in the app; it is never rounded into a figure.
- **A bare rule id.** That is the log line the voice exists to avoid, and in the manual it is not
  even available, since a rule id is text and Riley has none.

### 7.3 The visor, which is a display

**Ruled: DR-118 §11.117**, which carries the reasoning; this is the illustrator-facing form.
**Settled by the user on 2026-09-03.** The visor is Riley's face and Riley's screen at once, and it
runs a range rather than a fixed set. Four registers, loosest to tightest:

| Register | Examples | When |
|---|---|---|
| **Product marks** | `—` for unknown, a domain glyph (§7.1), a severity mark | Riley is speaking FOR the product. This is the register §4's postures pair with |
| **Punctuation** | `?` `!` `&` `!?` | Riley is reacting as a character. The smallest and most reusable register, and the one most pages want |
| **Grawlix** | `#$%&!`, a run of marks | The comics obscenity mask, for the moments a trade reader will recognise. **Never on a page carrying a safety sentence** |
| **Faces** | `>///<` `>_>` `^_^` `OwO` | Full kaomoji. The widest register and the one to spend sparingly, because a character who mugs on every page stops being the competent one (§3) |

And two that are their own thing:

- **A classic BSOD.** Riley has crashed. **Manual only**, and it does not appear on pages carrying
  domain glyphs (the user's own rule), and it resolves a collision that would otherwise have needed
  one: `video.digital` is `#0072B2` and a modern `#0078D7` bluescreen sits almost on top of it, so a
  blue visor beside a domain legend could read as a domain marker. **Placement settles it rather
  than palette**, which is the better fix, and the classic 9x/NT `#0000AA` is far enough off
  `#0072B2` to be safe anywhere it does appear.
- **A loading face.** For anything the product is still working out. A progress bar or a spinner
  reads better than an hourglass on a Protogen visor, and it is the natural companion to the
  `—`: **the dash means nobody knows, and loading means not yet.** Those are different statements
  and the product distinguishes them, so Riley should too.

**THE REGISTER IS THE QUESTION AN ILLUSTRATOR SHOULD ASK FIRST: is this panel the product talking,
or Riley reacting?** Product marks for the first, everything else for the second. A page that mixes
them without meaning to is a page where a reader cannot tell whether `?` means *"the value is
unknown"* or *"Riley is puzzled"*, and the first is a `Finding` while the second is a joke.

**AND THE VISOR SPANS BOTH REGISTERS**, unlike everything else in §7. Riley has a face in the manual
and a face in the app, so the vocabulary here is the one piece of the character that has to work
with symbols on a page AND beside a text bubble in a window. The BSOD is the single exception, by
the user's own placement rule.


## 8. What an artist needs delivered back

For the mark to ship, one asset:

- **Riley, front-facing, at the lockup proportion**, as vector outlines, with the visor eye as a
  separate closed subpath so the even-odd fill still works. This replaces `_rileyD` in
  `brand.dart` and nothing else changes.

For the manual, the poses in §5 as line art, **chibi** (§2). **A silhouette check on each**: fill it
solid and confirm it still reads.

**Draw scene 25 early.** Riley plugging their own tail into a panel is the picture that will decide
whether the tail reads as equipment or as decoration, and everything from 26 to 28 depends on that
answer. It is also the fastest way to find out whether the chibi rendering keeps the tail at full
length, which §2 leaves open and which those four scenes need settled.

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
- **How many glyphs the manual's symbol vocabulary actually needs.** §7.1 supplies the eight domain
  marks, the em dash and the severity marks, which is a floor rather than a roster: whether Riley
  also needs a small set of purely conversational marks (assent, "look here", "wait") is the
  illustrator's call once a few pages exist.
- **Whether Riley speaks in the application at all.** `#563` is an *opt-in* assistant, and canon
  §10.12(f) is explicit about the opt-in. A mascot in a manual and a mascot in a window are two
  decisions, and only the first is made here.
